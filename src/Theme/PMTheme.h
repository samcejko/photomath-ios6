#import <UIKit/UIKit.h>

@interface PMTheme : NSObject

+ (instancetype)shared;

@property (nonatomic, readonly) BOOL isDark;
- (void)setDark:(BOOL)dark;

// Colors
- (UIColor *)accentColor;         // Photomath red/coral (#E84545)
- (UIColor *)backgroundColor;       // Linen/grouped gray
- (UIColor *)cardBackgroundColor;   // White or dark card
- (UIColor *)primaryTextColor;
- (UIColor *)secondaryTextColor;
- (UIColor *)separatorColor;
- (UIColor *)stepBadgeColor;

// Fonts
- (UIFont *)titleFont;
- (UIFont *)bodyFont;
- (UIFont *)boldBodyFont;
- (UIFont *)smallFont;
- (UIFont *)keyboardFont;

// Procedural Artwork
- (UIImage *)navigationBarBackgroundImage;
- (UIImage *)glossyButtonImageWithColor:(UIColor *)baseColor highlighted:(BOOL)highlighted;
- (UIImage *)reticleCornerImageWithColor:(UIColor *)color stroke:(CGFloat)stroke length:(CGFloat)len;
- (UIImage *)circleBadgeImageWithNumber:(NSInteger)num size:(CGFloat)size;

// UIKit Styling
- (void)applyToNavigationBar:(UINavigationBar *)bar;
- (void)applyToTableView:(UITableView *)tableView;

@end
