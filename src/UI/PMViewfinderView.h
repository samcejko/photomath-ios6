#import <UIKit/UIKit.h>

@interface PMViewfinderView : UIView

@property (nonatomic, readonly) CGRect cropRect; // In view coordinates
- (CGRect)normalizedCropRectInBounds:(CGRect)bounds;

- (void)startScanningAnimation;
- (void)stopScanningAnimation;
- (void)showFocusIndicatorAtPoint:(CGPoint)point;
- (void)setDefaultCropRect:(CGRect)rect;

@end
