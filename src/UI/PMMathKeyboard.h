#import <UIKit/UIKit.h>

@interface PMMathKeyboard : UIViewController

@property (nonatomic, copy) NSString *currentLatex;
@property (nonatomic, copy) void (^onSolveRequested)(NSString *latex);
@property (nonatomic, getter=isSolving) BOOL solving;

- (instancetype)initWithInitialLatex:(NSString *)initialLatex;

@end
