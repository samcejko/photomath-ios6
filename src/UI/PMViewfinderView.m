#import "PMViewfinderView.h"
#import "PMTheme.h"
#import <QuartzCore/QuartzCore.h>

@interface PMViewfinderView ()
@property (nonatomic, strong) UIView *laserLine;
@property (nonatomic, strong) UIView *focusBox;
@property (nonatomic) CGRect currentCropRect;
@property (nonatomic, strong) UIPanGestureRecognizer *resizePan;
@property (nonatomic) CGPoint initialTouch;
@property (nonatomic) CGRect initialRect;
@end

@implementation PMViewfinderView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;

        // Default crop box (centered, proportional)
        CGFloat w = floorf(frame.size.width * 0.88f);
        CGFloat h = 130.0f;
        CGFloat x = floorf((frame.size.width - w) / 2.0f);
        CGFloat y = floorf((frame.size.height - h) / 2.0f) - 30.0f;
        _currentCropRect = CGRectMake(x, y, w, h);

        // Animated scanning laser line
        _laserLine = [[UIView alloc] initWithFrame:CGRectMake(x + 4, y + 4, w - 8, 2.0f)];
        _laserLine.backgroundColor = [UIColor colorWithRed:1.0f green:0.25f blue:0.25f alpha:0.9f];
        _laserLine.layer.shadowColor = [UIColor redColor].CGColor;
        _laserLine.layer.shadowOffset = CGSizeZero;
        _laserLine.layer.shadowRadius = 4.0f;
        _laserLine.layer.shadowOpacity = 0.9f;
        [self addSubview:_laserLine];

        // Focus indicator box
        _focusBox = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 60, 60)];
        _focusBox.layer.borderColor = [UIColor yellowColor].CGColor;
        _focusBox.layer.borderWidth = 1.5f;
        _focusBox.backgroundColor = [UIColor clearColor];
        _focusBox.alpha = 0.0f;
        [self addSubview:_focusBox];

        // Pan to resize the bottom/sides
        _resizePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleResizePan:)];
        [self addGestureRecognizer:_resizePan];
    }
    return self;
}

- (CGRect)cropRect
{
    return self.currentCropRect;
}

- (CGRect)normalizedCropRectInBounds:(CGRect)bounds
{
    if (bounds.size.width <= 0 || bounds.size.height <= 0) return CGRectMake(0, 0, 1, 1);
    CGFloat nx = self.currentCropRect.origin.x / bounds.size.width;
    CGFloat ny = self.currentCropRect.origin.y / bounds.size.height;
    CGFloat nw = self.currentCropRect.size.width / bounds.size.width;
    CGFloat nh = self.currentCropRect.size.height / bounds.size.height;
    return CGRectMake(nx, ny, nw, nh);
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    // Dark semi-transparent mask outside crop rect
    [[UIColor colorWithWhite:0.0f alpha:0.50f] setFill];
    UIRectFill(rect);

    // Clear the center cutout
    CGContextClearRect(ctx, self.currentCropRect);

    // Subtle white inner border around cutout
    [[UIColor colorWithWhite:1.0f alpha:0.25f] setStroke];
    CGContextStrokeRectWithWidth(ctx, self.currentCropRect, 1.0f);

    // 4 Corner Brackets (Classic Photomath Red / Coral)
    [[UIColor colorWithRed:0.95f green:0.25f blue:0.25f alpha:1.0f] setFill];
    CGFloat rLen = 24.0f;
    CGFloat rThick = 4.0f;
    CGRect r = self.currentCropRect;

    // Top-Left
    UIRectFill(CGRectMake(r.origin.x, r.origin.y, rLen, rThick));
    UIRectFill(CGRectMake(r.origin.x, r.origin.y, rThick, rLen));

    // Top-Right
    UIRectFill(CGRectMake(CGRectGetMaxX(r) - rLen, r.origin.y, rLen, rThick));
    UIRectFill(CGRectMake(CGRectGetMaxX(r) - rThick, r.origin.y, rThick, rLen));

    // Bottom-Left
    UIRectFill(CGRectMake(r.origin.x, CGRectGetMaxY(r) - rThick, rLen, rThick));
    UIRectFill(CGRectMake(r.origin.x, CGRectGetMaxY(r) - rLen, rThick, rLen));

    // Bottom-Right
    UIRectFill(CGRectMake(CGRectGetMaxX(r) - rLen, CGRectGetMaxY(r) - rThick, rLen, rThick));
    UIRectFill(CGRectMake(CGRectGetMaxX(r) - rThick, CGRectGetMaxY(r) - rLen, rThick, rLen));

    // Resize handle hint on bottom-right corner
    [[UIColor colorWithWhite:1.0f alpha:0.6f] setFill];
    CGFloat brx = CGRectGetMaxX(r) - 10.0f;
    CGFloat bry = CGRectGetMaxY(r) - 10.0f;
    UIRectFill(CGRectMake(brx, bry, 6.0f, 6.0f));
}

- (void)startScanningAnimation
{
    self.laserLine.hidden = NO;
    CGRect topPos = CGRectMake(self.currentCropRect.origin.x + 4, self.currentCropRect.origin.y + 4, self.currentCropRect.size.width - 8, 2.0f);
    CGRect botPos = CGRectMake(self.currentCropRect.origin.x + 4, CGRectGetMaxY(self.currentCropRect) - 6, self.currentCropRect.size.width - 8, 2.0f);

    self.laserLine.frame = topPos;
    [UIView animateWithDuration:1.4
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat
                     animations:^{
        self.laserLine.frame = botPos;
    } completion:nil];
}

- (void)stopScanningAnimation
{
    [self.laserLine.layer removeAllAnimations];
    self.laserLine.hidden = YES;
}

- (void)showFocusIndicatorAtPoint:(CGPoint)point
{
    self.focusBox.center = point;
    self.focusBox.transform = CGAffineTransformMakeScale(1.4f, 1.4f);
    self.focusBox.alpha = 1.0f;

    [UIView animateWithDuration:0.35f animations:^{
        self.focusBox.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.4f delay:0.4f options:0 animations:^{
            self.focusBox.alpha = 0.0f;
        } completion:nil];
    }];
}

- (void)handleResizePan:(UIPanGestureRecognizer *)pan
{
    CGPoint loc = [pan locationInView:self];
    if (pan.state == UIGestureRecognizerStateBegan) {
        self.initialTouch = loc;
        self.initialRect = self.currentCropRect;
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGFloat dx = loc.x - self.initialTouch.x;
        CGFloat dy = loc.y - self.initialTouch.y;

        CGFloat newW = MAX(140.0f, MIN(self.bounds.size.width - 20.0f, self.initialRect.size.width + dx));
        CGFloat newH = MAX(80.0f, MIN(self.bounds.size.height - 100.0f, self.initialRect.size.height + dy));

        CGFloat newX = floorf((self.bounds.size.width - newW) / 2.0f);
        CGFloat newY = MAX(40.0f, self.initialRect.origin.y + dy * 0.3f);

        self.currentCropRect = CGRectMake(newX, newY, newW, newH);
        [self setNeedsDisplay];

        CGRect topPos = CGRectMake(self.currentCropRect.origin.x + 4, self.currentCropRect.origin.y + 4, self.currentCropRect.size.width - 8, 2.0f);
        self.laserLine.frame = topPos;
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        [self startScanningAnimation];
    }
}

@end
