#import "PMUtils.h"
#import "PMCommon.h"
#import <ImageIO/ImageIO.h>
#include <string.h>

static const char kBase64Table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

@implementation PMUtils

#pragma mark - Base64

+ (NSString *)base64EncodeData:(NSData *)data
{
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    NSUInteger len = data.length;
    if (len == 0) return @"";
    NSUInteger outLen = ((len + 2) / 3) * 4;
    char *out = (char *)malloc(outLen + 1);
    if (!out) return @"";
    NSUInteger i = 0, j = 0;
    while (i + 2 < len) {
        uint32_t v = ((uint32_t)bytes[i] << 16) | ((uint32_t)bytes[i + 1] << 8) | (uint32_t)bytes[i + 2];
        out[j++] = kBase64Table[(v >> 18) & 63];
        out[j++] = kBase64Table[(v >> 12) & 63];
        out[j++] = kBase64Table[(v >> 6) & 63];
        out[j++] = kBase64Table[v & 63];
        i += 3;
    }
    if (i < len) {
        uint32_t v = (uint32_t)bytes[i] << 16;
        if (i + 1 < len) v |= (uint32_t)bytes[i + 1] << 8;
        out[j++] = kBase64Table[(v >> 18) & 63];
        out[j++] = kBase64Table[(v >> 12) & 63];
        out[j++] = (i + 1 < len) ? kBase64Table[(v >> 6) & 63] : '=';
        out[j++] = '=';
    }
    out[j] = 0;
    return [[NSString alloc] initWithBytesNoCopy:out length:j encoding:NSASCIIStringEncoding freeWhenDone:YES];
}

+ (NSData *)base64DecodeString:(NSString *)string
{
    if (!string.length) return nil;
    static int8_t table[256];
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        memset(table, -1, sizeof(table));
        for (int i = 0; i < 64; i++) table[(uint8_t)kBase64Table[i]] = (int8_t)i;
        table[(uint8_t)'-'] = 62;
        table[(uint8_t)'_'] = 63;
    });
    NSData *ascii = [string dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    const uint8_t *in = (const uint8_t *)ascii.bytes;
    NSUInteger len = ascii.length;
    NSMutableData *out = [NSMutableData dataWithCapacity:len * 3 / 4 + 3];
    uint32_t acc = 0;
    int bits = 0;
    for (NSUInteger i = 0; i < len; i++) {
        uint8_t c = in[i];
        if (c == '=') break;
        int8_t v = table[c];
        if (v < 0) continue;
        acc = (acc << 6) | (uint32_t)v;
        bits += 6;
        if (bits >= 8) {
            bits -= 8;
            uint8_t b = (uint8_t)((acc >> bits) & 0xFF);
            [out appendBytes:&b length:1];
        }
    }
    return out;
}

+ (NSString *)dataURLWithMime:(NSString *)mime data:(NSData *)data
{
    return [NSString stringWithFormat:@"data:%@;base64,%@", mime ?: @"image/jpeg", [self base64EncodeData:data]];
}

#pragma mark - Images

+ (NSData *)jpegDataForImage:(UIImage *)image maxDimension:(CGFloat)maxDim quality:(CGFloat)quality
{
    if (!image) return nil;
    CGSize orig = image.size;
    if (orig.width <= 0 || orig.height <= 0) return nil;

    CGFloat scale = 1.0f;
    CGFloat maxSide = MAX(orig.width, orig.height);
    if (maxSide > maxDim && maxDim > 0) {
        scale = maxDim / maxSide;
    }

    CGSize targetSize = CGSizeMake(floorf(orig.width * scale), floorf(orig.height * scale));
    UIGraphicsBeginImageContextWithOptions(targetSize, YES, 1.0f);
    [image drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
    UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return UIImageJPEGRepresentation(scaled ?: image, quality);
}

+ (UIImage *)normalizedUprightImage:(UIImage *)image
{
    if (!image) return nil;
    if (image.imageOrientation == UIImageOrientationUp) return image;

    UIGraphicsBeginImageContextWithOptions(image.size, NO, 1.0f);
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    UIImage *normalized = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return normalized ?: image;
}

+ (UIImage *)cropImage:(UIImage *)image fromViewBounds:(CGRect)viewBounds cropRect:(CGRect)cropRect
{
    if (!image || image.size.width <= 0 || image.size.height <= 0) return image;
    if (viewBounds.size.width <= 0 || viewBounds.size.height <= 0) return image;

    // 1. Normalize orientation so image is strictly upright
    UIImage *upright = [self normalizedUprightImage:image];
    if (!upright) upright = image;

    CGFloat imgW = upright.size.width;
    CGFloat imgH = upright.size.height;
    CGFloat viewW = viewBounds.size.width;
    CGFloat viewH = viewBounds.size.height;

    // 2. Map AVLayerVideoGravityResizeAspectFill:
    // Scale factor that fills the camera preview view:
    CGFloat scale = MAX(viewW / imgW, viewH / imgH);
    CGFloat dispW = imgW * scale;
    CGFloat dispH = imgH * scale;

    // Video preview is centered inside view bounds:
    CGFloat originX = (viewW - dispW) / 2.0f;
    CGFloat originY = (viewH - dispH) / 2.0f;

    // Convert cropRect from view coordinates to upright image coordinates:
    CGFloat cropX = (cropRect.origin.x - originX) / scale;
    CGFloat cropY = (cropRect.origin.y - originY) / scale;
    CGFloat cropW = cropRect.size.width / scale;
    CGFloat cropH = cropRect.size.height / scale;

    // Add 15% horizontal and 20% vertical padding so equations are never clipped at the edges
    CGFloat padX = cropW * 0.15f;
    CGFloat padY = cropH * 0.20f;
    cropX = MAX(0.0f, cropX - padX);
    cropY = MAX(0.0f, cropY - padY);
    cropW = MIN(imgW - cropX, cropW + padX * 2.0f);
    cropH = MIN(imgH - cropY, cropH + padY * 2.0f);

    CGRect pixelCrop = CGRectMake(floorf(cropX), floorf(cropY), floorf(cropW), floorf(cropH));
    CGImageRef cgRef = CGImageCreateWithImageInRect(upright.CGImage, pixelCrop);
    if (!cgRef) return upright;

    UIImage *cropped = [UIImage imageWithCGImage:cgRef scale:1.0f orientation:UIImageOrientationUp];
    CGImageRelease(cgRef);
    return cropped;
}

+ (UIImage *)cropImage:(UIImage *)image toNormalizedRect:(CGRect)normalizedRect
{
    if (!image || image.size.width <= 0 || image.size.height <= 0) return image;
    UIImage *upright = [self normalizedUprightImage:image];
    if (!upright) upright = image;

    CGFloat w = upright.size.width;
    CGFloat h = upright.size.height;

    // Clamp normalized coords [0..1]
    CGFloat rx = MAX(0.0f, MIN(1.0f, normalizedRect.origin.x));
    CGFloat ry = MAX(0.0f, MIN(1.0f, normalizedRect.origin.y));
    CGFloat rw = MAX(0.01f, MIN(1.0f - rx, normalizedRect.size.width));
    CGFloat rh = MAX(0.01f, MIN(1.0f - ry, normalizedRect.size.height));

    CGRect pixelCrop = CGRectMake(floorf(rx * w), floorf(ry * h), floorf(rw * w), floorf(rh * h));
    CGImageRef croppedRef = CGImageCreateWithImageInRect(upright.CGImage, pixelCrop);
    if (!croppedRef) return upright;

    UIImage *cropped = [UIImage imageWithCGImage:croppedRef scale:1.0f orientation:UIImageOrientationUp];
    CGImageRelease(croppedRef);
    return cropped;
}

+ (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size
{
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
    [color setFill];
    UIRectFill(CGRectMake(0, 0, size.width, size.height));
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

#pragma mark - Paths

+ (NSString *)documentsPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return paths.count ? [paths objectAtIndex:0] : NSTemporaryDirectory();
}

+ (NSString *)cachesPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *p = paths.count ? [paths objectAtIndex:0] : [self documentsPath];
    [[NSFileManager defaultManager] createDirectoryAtPath:p withIntermediateDirectories:YES attributes:nil error:NULL];
    return p;
}

+ (NSString *)historyPath
{
    NSString *p = [[self documentsPath] stringByAppendingPathComponent:@"PhotomathHistory"];
    [[NSFileManager defaultManager] createDirectoryAtPath:p withIntermediateDirectories:YES attributes:nil error:NULL];
    return p;
}

#pragma mark - Formatting

+ (NSString *)shortDateString:(NSDate *)date
{
    if (!date) return @"";
    static NSDateFormatter *df = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        df = [[NSDateFormatter alloc] init];
        df.dateStyle = NSDateFormatterShortStyle;
        df.timeStyle = NSDateFormatterShortStyle;
    });
    return [df stringFromDate:date];
}

#pragma mark - JSON

+ (id)JSONObjectFromData:(NSData *)data
{
    if (!data.length) return nil;
    NSError *err = nil;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&err];
    if (err) PMLog(@"JSON parse error: %@", err.localizedDescription);
    return obj;
}

+ (NSData *)JSONDataFromObject:(id)object
{
    if (!object) return nil;
    NSError *err = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:object options:0 error:&err];
    if (err) PMLog(@"JSON serialize error: %@", err.localizedDescription);
    return data;
}

#pragma mark - UI

+ (void)alertWithTitle:(NSString *)title message:(NSString *)message
{
    PMMain(^{
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:title
                                                     message:message
                                                    delegate:nil
                                           cancelButtonTitle:L(@"OK")
                                           otherButtonTitles:nil];
        [av show];
    });
}

@end
