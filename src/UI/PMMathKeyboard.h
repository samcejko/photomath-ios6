#import <UIKit/UIKit.h>

@interface PMMathKeyboard : UIViewController

@property (nonatomic, copy) NSString *currentLatex;
@property (nonatomic, copy) void (^onSolveRequested)(NSString *latex);

- (instancetype)initWithInitialLatex:(NSString *)initialLatex;

@end
