#import <UIKit/UIKit.h>
#import "PMMathSolution.h"

@interface PMSolutionViewController : UIViewController

- (instancetype)initWithSolution:(PMMathSolution *)solution;

@property (nonatomic, copy) void (^onEditProblemRequested)(NSString *problemLatex);

@end
