#import "PMTheme.h"
#import "PMSettings.h"
#import "PMModern.h"
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
    UIRectFillUsingBlendMode(glossRect, kCGBlendModeNormal);

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

- (UIImage *)darkBarButtonImageHighlighted:(BOOL)highlighted
{
    CGSize size = CGSizeMake(24.0f, 32.0f);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    CGRect rect = CGRectMake(0.5f, 0.5f, 23.0f, 31.0f);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:5.0f];
    CGContextSaveGState(ctx);
    [path addClip];

    CGFloat r = highlighted ? 0.35f : 0.20f;
    CGFloat alphaTop = highlighted ? 0.45f : 0.28f;
    CGFloat alphaBot = highlighted ? 0.20f : 0.08f;

    CGFloat comp[8] = {
        r, r, r, alphaTop,
        r * 0.7f, r * 0.7f, r * 0.7f, alphaBot
    };
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGGradientRef grad = CGGradientCreateWithColorComponents(cs, comp, NULL, 2);
    CGContextDrawLinearGradient(ctx, grad, CGPointMake(0, 0), CGPointMake(0, size.height), 0);
    CGGradientRelease(grad);
    CGColorSpaceRelease(cs);

    CGContextRestoreGState(ctx);

    [[UIColor colorWithWhite:1.0f alpha:highlighted ? 0.45f : 0.25f] setStroke];
    path.lineWidth = 1.0f;
    [path stroke];

    UIImage *raw = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [raw resizableImageWithCapInsets:UIEdgeInsetsMake(10, 10, 10, 10) resizingMode:UIImageResizingModeStretch];
}

- (UIImage *)torchIconActive:(BOOL)active
{
    CGSize size = CGSizeMake(22.0f, 22.0f);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);

    UIBezierPath *p = [UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake(12.5f, 2.0f)];
    [p addLineToPoint:CGPointMake(5.0f, 11.5f)];
    [p addLineToPoint:CGPointMake(10.5f, 11.5f)];
    [p addLineToPoint:CGPointMake(8.0f, 20.0f)];
    [p addLineToPoint:CGPointMake(17.0f, 9.5f)];
    [p addLineToPoint:CGPointMake(11.5f, 9.5f)];
    [p closePath];
    p.lineJoinStyle = kCGLineJoinRound;
    p.lineCapStyle = kCGLineCapRound;

    if (active) {
        [[UIColor colorWithRed:1.0f green:0.84f blue:0.0f alpha:1.0f] setFill];
        [p fill];
        [[UIColor whiteColor] setStroke];
        p.lineWidth = 1.2f;
        [p stroke];
    } else {
        [[UIColor colorWithWhite:1.0f alpha:0.25f] setFill];
        [p fill];
        [[UIColor whiteColor] setStroke];
        p.lineWidth = 1.8f;
        [p stroke];
    }

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)historyIcon
{
    CGSize size = CGSizeMake(22.0f, 22.0f);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);

    UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(2.0f, 2.0f, 18.0f, 18.0f)];
    circle.lineWidth = 1.8f;
    [[UIColor whiteColor] setStroke];
    [circle stroke];

    UIBezierPath *hands = [UIBezierPath bezierPath];
    [hands moveToPoint:CGPointMake(11.0f, 6.0f)];
    [hands addLineToPoint:CGPointMake(11.0f, 11.0f)];
    [hands addLineToPoint:CGPointMake(15.5f, 11.0f)];
    hands.lineWidth = 2.0f;
    hands.lineCapStyle = kCGLineCapRound;
    hands.lineJoinStyle = kCGLineJoinRound;
    [[UIColor whiteColor] setStroke];
    [hands stroke];

    UIBezierPath *dot = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(9.5f, 9.5f, 3.0f, 3.0f)];
    [[UIColor whiteColor] setFill];
    [dot fill];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)settingsIcon
{
    CGSize size = CGSizeMake(22.0f, 22.0f);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);

    UIBezierPath *gear = [UIBezierPath bezierPath];
    CGFloat cx = 11.0f, cy = 11.0f;
    CGFloat rIn = 6.8f, rOut = 9.8f;
    int teeth = 8;
    for (int i = 0; i < teeth; i++) {
        CGFloat a0 = (i * 2.0f * M_PI) / teeth;
        CGFloat a1 = a0 + (M_PI / (teeth * 2.5f));
        CGFloat a2 = a1 + (M_PI / (teeth * 2.5f));
        CGFloat a3 = a0 + (2.0f * M_PI / teeth);
        CGPoint p0 = CGPointMake(cx + rIn * cosf(a0), cy + rIn * sinf(a0));
        CGPoint p1 = CGPointMake(cx + rOut * cosf(a1), cy + rOut * sinf(a1));
        CGPoint p2 = CGPointMake(cx + rOut * cosf(a2), cy + rOut * sinf(a2));
        CGPoint p3 = CGPointMake(cx + rIn * cosf(a3), cy + rIn * sinf(a3));
        if (i == 0) [gear moveToPoint:p0];
        else [gear addLineToPoint:p0];
        [gear addLineToPoint:p1];
        [gear addLineToPoint:p2];
        [gear addLineToPoint:p3];
    }
    [gear closePath];

    UIBezierPath *hole = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(cx - 3.5f, cy - 3.5f, 7.0f, 7.0f)];
    [gear appendPath:hole];
    gear.usesEvenOddFillRule = YES;

    [[UIColor whiteColor] setFill];
    [gear fill];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)galleryIcon
{
    CGSize size = CGSizeMake(24.0f, 24.0f);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);

    CGRect cardRect = CGRectMake(2.0f, 3.5f, 20.0f, 17.0f);
    UIBezierPath *card = [UIBezierPath bezierPathWithRoundedRect:cardRect cornerRadius:3.0f];
    card.lineWidth = 1.8f;
    [[UIColor whiteColor] setStroke];
    [card stroke];

    UIBezierPath *sun = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(5.5f, 6.5f, 4.0f, 4.0f)];
    [[UIColor whiteColor] setFill];
    [sun fill];

    UIBezierPath *peaks = [UIBezierPath bezierPath];
    [peaks moveToPoint:CGPointMake(3.5f, 18.0f)];
    [peaks addLineToPoint:CGPointMake(9.5f, 11.5f)];
    [peaks addLineToPoint:CGPointMake(14.5f, 17.0f)];
    [peaks addLineToPoint:CGPointMake(17.5f, 13.5f)];
    [peaks addLineToPoint:CGPointMake(20.5f, 17.5f)];
    peaks.lineWidth = 1.6f;
    peaks.lineCapStyle = kCGLineCapRound;
    peaks.lineJoinStyle = kCGLineJoinRound;
    [[UIColor whiteColor] setStroke];
    [peaks stroke];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)keyboardIcon
{
    CGSize size = CGSizeMake(24.0f, 24.0f);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);

    CGRect frame = CGRectMake(2.0f, 4.0f, 20.0f, 16.0f);
    UIBezierPath *kb = [UIBezierPath bezierPathWithRoundedRect:frame cornerRadius:3.0f];
    kb.lineWidth = 1.8f;
    [[UIColor whiteColor] setStroke];
    [kb stroke];

    UIBezierPath *keys = [UIBezierPath bezierPath];
    for (int i = 0; i < 4; i++) {
        CGFloat x = 5.5f + i * 3.8f;
        [keys appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(x, 7.0f, 2.2f, 2.0f) cornerRadius:0.5f]];
        [keys appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(x, 11.0f, 2.2f, 2.0f) cornerRadius:0.5f]];
    }
    [[UIColor whiteColor] setFill];
    [keys fill];

    UIBezierPath *space = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(6.5f, 15.0f, 11.0f, 1.8f) cornerRadius:0.8f];
    [space fill];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)shutterIcon
{
    CGSize size = CGSizeMake(34.0f, 34.0f);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);

    UIBezierPath *xPath = [UIBezierPath bezierPath];
    [xPath moveToPoint:CGPointMake(10.0f, 10.0f)];
    [xPath addLineToPoint:CGPointMake(24.0f, 24.0f)];
    [xPath moveToPoint:CGPointMake(24.0f, 10.0f)];
    [xPath addLineToPoint:CGPointMake(10.0f, 24.0f)];
    xPath.lineWidth = 3.6f;
    xPath.lineCapStyle = kCGLineCapRound;
    [[UIColor whiteColor] setStroke];
    [xPath stroke];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

#pragma mark - UIKit Styling

- (void)applyToNavigationBar:(UINavigationBar *)bar
{
    if (!bar) return;
    UIImage *bg = [self navigationBarBackgroundImage];
    [bar setBackgroundImage:bg forBarMetrics:UIBarMetricsDefault];
    bar.barStyle = UIBarStyleBlack;
    bar.tintColor = [UIColor whiteColor];

    NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
    attrs[UITextAttributeTextColor] = [UIColor whiteColor];
    attrs[UITextAttributeTextShadowColor] = [UIColor colorWithWhite:0.0f alpha:0.45f];
    attrs[UITextAttributeTextShadowOffset] = [NSValue valueWithUIOffset:UIOffsetMake(0, -1)];

    NSMutableDictionary *btnAttrs = [NSMutableDictionary dictionary];
    btnAttrs[UITextAttributeTextColor] = [UIColor whiteColor];
    btnAttrs[UITextAttributeTextShadowColor] = [UIColor colorWithWhite:0.0f alpha:0.45f];
    btnAttrs[UITextAttributeTextShadowOffset] = [NSValue valueWithUIOffset:UIOffsetMake(0, -1)];

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    if (PMModernIOS()) {
        NSShadow *sh = [[NSShadow alloc] init];
        sh.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.5f];
        sh.shadowOffset = CGSizeMake(0, -1);

        attrs[NSForegroundColorAttributeName] = [UIColor whiteColor];
        attrs[NSShadowAttributeName] = sh;
        attrs[NSFontAttributeName] = [UIFont boldSystemFontOfSize:18.0f];

        btnAttrs[NSForegroundColorAttributeName] = [UIColor whiteColor];
        btnAttrs[NSShadowAttributeName] = sh;
        btnAttrs[NSFontAttributeName] = [UIFont boldSystemFontOfSize:13.0f];
    }
#endif

    bar.titleTextAttributes = attrs;

    PMModernApplyNavigationBarBackground(bar, bg, attrs, nil, nil, btnAttrs);
}

- (void)applyToTableView:(UITableView *)tableView
{
    tableView.backgroundColor = [self backgroundColor];
    tableView.separatorColor = [self separatorColor];
}

@end
