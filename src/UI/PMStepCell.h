#import <UIKit/UIKit.h>
#import "PMMathSolution.h"

@interface PMStepCell : UITableViewCell

- (void)configureWithStep:(PMStep *)step isDark:(BOOL)isDark;
+ (CGFloat)heightForStep:(PMStep *)step width:(CGFloat)width isDark:(BOOL)isDark;

@end
