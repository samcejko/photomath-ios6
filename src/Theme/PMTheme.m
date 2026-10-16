#import "PMTheme.h"
#import "PMSettings.h"
#import "PMCommon.h"

@implementation PMTheme

+ (instancetype)shared
{
    static PMTheme *t = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ t = [[PMTheme alloc] init]; });
    return t;
}

- (BOOL)isDark
{
    return [PMSettings shared].darkTheme;
}

- (void)setDark:(BOOL)dark
{
    [PMSettings shared].darkTheme = dark;
}

#pragma mark - Colors

- (UIColor *)accentColor
{
    return [UIColor colorWithRed:0.91f green:0.24f blue:0.24f alpha:1.0f]; // #E83D3D
}

- (UIColor *)backgroundColor
{
    if (self.isDark) {
        return [UIColor colorWithWhite:0.12f alpha:1.0f];
    }
    return [UIColor colorWithRed:0.93f green:0.94f blue:0.96f alpha:1.0f];
}

- (UIColor *)cardBackgroundColor
{
    if (self.isDark) {
        return [UIColor colorWithWhite:0.18f alpha:1.0f];
    }
    return [UIColor whiteColor];
}

- (UIColor *)primaryTextColor
{
    if (self.isDark) {
        return [UIColor colorWithWhite:0.95f alpha:1.0f];
    }
    return [UIColor colorWithRed:0.15f green:0.17f blue:0.20f alpha:1.0f];
}

- (UIColor *)secondaryTextColor
{
    if (self.isDark) {
        return [UIColor colorWithWhite:0.65f alpha:1.0f];
    }
    return [UIColor colorWithRed:0.45f green:0.48f blue:0.55f alpha:1.0f];
}

- (UIColor *)separatorColor
{
    if (self.isDark) {
        return [UIColor colorWithWhite:0.25f alpha:1.0f];
    }
    return [UIColor colorWithRed:0.82f green:0.84f blue:0.88f alpha:1.0f];
}

- (UIColor *)stepBadgeColor
{
    return [UIColor colorWithRed:0.88f green:0.20f blue:0.20f alpha:1.0f];
}

#pragma mark - Fonts

- (UIFont *)titleFont
{
    return [UIFont boldSystemFontOfSize:17.0f];
}

- (UIFont *)bodyFont
{
    return [UIFont systemFontOfSize:15.0f];
}

- (UIFont *)boldBodyFont
{
    return [UIFont boldSystemFontOfSize:15.0f];
}

- (UIFont *)smallFont
{
    return [UIFont systemFontOfSize:12.0f];
}

- (UIFont *)keyboardFont
{
    return [UIFont boldSystemFontOfSize:19.0f];
}

#pragma mark - Procedural Artwork

- (UIImage *)navigationBarBackgroundImage
{
    CGSize size = CGSizeMake(1.0f, 44.0f);
    UIGraphicsBeginImageContextWithOptions(size, YES, 0.0f);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGFloat components[8];
    if (self.isDark) {
        components[0] = 0.22f; components[1] = 0.22f; components[2] = 0.24f; components[3] = 1.0f;
        components[4] = 0.12f; components[5] = 0.12f; components[6] = 0.13f; components[7] = 1.0f;
    } else {
        // Photomath glossy coral/red navigation bar
        components[0] = 0.94f; components[1] = 0.28f; components[2] = 0.28f; components[3] = 1.0f;
        components[4] = 0.80f; components[5] = 0.14f; components[6] = 0.14f; components[7] = 1.0f;
    }

    CGGradientRef grad = CGGradientCreateWithColorComponents(cs, components, NULL, 2);
    CGContextDrawLinearGradient(ctx, grad, CGPointMake(0, 0), CGPointMake(0, 44), 0);
    CGGradientRelease(grad);
    CGColorSpaceRelease(cs);

    // Top subtle highlight line
    [[UIColor colorWithWhite:1.0f alpha:0.35f] setStroke];
    CGContextSetLineWidth(ctx, 1.0f);
    CGContextMoveToPoint(ctx, 0, 0.5f);
    CGContextAddLineToPoint(ctx, 1, 0.5f);
    CGContextStrokePath(ctx);

    // Bottom dark border
    [[UIColor colorWithWhite:0.0f alpha:0.35f] setStroke];
    CGContextMoveToPoint(ctx, 0, 43.5f);
    CGContextAddLineToPoint(ctx, 1, 43.5f);
    CGContextStrokePath(ctx);

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [img resizableImageWithCapInsets:UIEdgeInsetsMake(0, 0, 0, 0) resizingMode:UIImageResizingModeTile];
}

- (UIImage *)glossyButtonImageWithColor:(UIColor *)baseColor highlighted:(BOOL)highlighted
{
    CGSize size = CGSizeMake(30.0f, 36.0f);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    CGRect rect = CGRectMake(0.5f, 0.5f, 29.0f, 35.0f);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:6.0f];
    CGContextSaveGState(ctx);
    [path addClip];

    // Background gradient
    CGFloat r, g, b, a;
    if (![baseColor getRed:&r green:&g blue:&b alpha:&a]) {
        r = 0.88f; g = 0.20f; b = 0.20f; a = 1.0f;
    }
    if (highlighted) {
        r *= 0.8f; g *= 0.8f; b *= 0.8f;
    }

    CGFloat comp[8] = {
        MIN(1.0f, r + 0.15f), MIN(1.0f, g + 0.15f), MIN(1.0f, b + 0.15f), 1.0f,
        MAX(0.0f, r - 0.15f), MAX(0.0f, g - 0.15f), MAX(0.0f, b - 0.15f), 1.0f
    };
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGGradientRef grad = CGGradientCreateWithColorComponents(cs, comp, NULL, 2);
    CGContextDrawLinearGradient(ctx, grad, CGPointMake(0, 0), CGPointMake(0, size.height), 0);
    CGGradientRelease(grad);
    CGColorSpaceRelease(cs);

    // Top gloss reflection (iOS 6 glossy dome)
    CGRect glossRect = CGRectMake(0, 0, size.width, size.height * 0.45f);
    [[UIColor colorWithWhite:1.0f alpha:highlighted ? 0.05f : 0.25f] setFill];
    UIRectFillUsingBlendMode(glossRect, kCGBlendModeSourceOver);

    CGContextRestoreGState(ctx);

    // Border
    [[UIColor colorWithWhite:0.0f alpha:0.3f] setStroke];
    path.lineWidth = 1.0f;
    [path stroke];

    UIImage *raw = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [raw resizableImageWithCapInsets:UIEdgeInsetsMake(12, 12, 12, 12) resizingMode:UIImageResizingModeStretch];
}

- (UIImage *)reticleCornerImageWithColor:(UIColor *)color stroke:(CGFloat)stroke length:(CGFloat)len
{
    CGSize size = CGSizeMake(len, len);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    [color setFill];
    // Top-Left corner
    UIRectFill(CGRectMake(0, 0, len, stroke));
    UIRectFill(CGRectMake(0, 0, stroke, len));

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)circleBadgeImageWithNumber:(NSInteger)num size:(CGFloat)size
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0f);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    // Circle background
    [[self stepBadgeColor] setFill];
    CGContextFillEllipseInRect(ctx, CGRectMake(0, 0, size, size));

    // Number text
    NSString *str = [NSString stringWithFormat:@"%ld", (long)num];
    UIFont *fnt = [UIFont boldSystemFontOfSize:size * 0.55f];
    CGSize txtSize = [str sizeWithFont:fnt];
    CGRect txtRect = CGRectMake((size - txtSize.width) / 2.0f, (size - txtSize.height) / 2.0f, txtSize.width, txtSize.height);

    [[UIColor whiteColor] set];
    [str drawInRect:txtRect withFont:fnt];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

#pragma mark - UIKit Styling

- (void)applyToNavigationBar:(UINavigationBar *)bar
{
    [bar setBackgroundImage:[self navigationBarBackgroundImage] forBarMetrics:UIBarMetricsDefault];
    bar.tintColor = [UIColor colorWithRed:0.75f green:0.18f blue:0.18f alpha:1.0f];
    bar.titleTextAttributes = @{
        UITextAttributeTextColor: [UIColor whiteColor],
        UITextAttributeTextShadowColor: [UIColor colorWithWhite:0.0f alpha:0.45f],
        UITextAttributeTextShadowOffset: [NSValue valueWithUIOffset:UIOffsetMake(0, -1)]
    };
}

- (void)applyToTableView:(UITableView *)tableView
{
    tableView.backgroundColor = [self backgroundColor];
    tableView.separatorColor = [self separatorColor];
}

@end
