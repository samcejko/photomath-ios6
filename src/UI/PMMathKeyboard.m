#import "PMMathKeyboard.h"
#import "PMTheme.h"
#import "PMCommon.h"
#import "PMSettings.h"
#import "PMUtils.h"
#import "MTMathUILabel.h"
#import <QuartzCore/QuartzCore.h>

@interface PMMathKeyboard ()
@property (nonatomic, strong) UIView *previewCard;
@property (nonatomic, strong) UITextField *rawTextField;
@property (nonatomic, strong) MTMathUILabel *mathPreviewLabel;
@property (nonatomic, strong) UIView *keypadContainer;
@property (nonatomic, strong) UISegmentedControl *modeSegment;
@property (nonatomic, strong) NSMutableArray *currentButtons;
@end

@implementation PMMathKeyboard

- (instancetype)initWithInitialLatex:(NSString *)initialLatex
{
    self = [super init];
    if (self) {
        _currentLatex = initialLatex.length ? [initialLatex copy] : @"";
        self.title = L(@"Math Editor");
        _currentButtons = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[PMTheme shared] applyToNavigationBar:self.navigationController.navigationBar];
    self.view.backgroundColor = [[PMTheme shared] backgroundColor];

    [self setupPreviewCard];
    [self setupKeypad];
    [self updateMathPreview];
}

- (void)setupPreviewCard
{
    CGFloat w = self.view.bounds.size.width;
    BOOL isDark = [PMSettings shared].darkTheme;

    self.previewCard = [[UIView alloc] initWithFrame:CGRectMake(10, 10, w - 20, 120)];
    self.previewCard.backgroundColor = isDark ? [UIColor colorWithWhite:0.18f alpha:1.0f] : [UIColor whiteColor];
    self.previewCard.layer.cornerRadius = 8.0f;
    self.previewCard.layer.borderWidth = 1.0f;
    self.previewCard.layer.borderColor = isDark ? [UIColor colorWithWhite:0.28f alpha:1.0f].CGColor : [UIColor colorWithRed:0.86f green:0.88f blue:0.92f alpha:1.0f].CGColor;
    [self.view addSubview:self.previewCard];

    // Raw input text
    self.rawTextField = [[UITextField alloc] initWithFrame:CGRectMake(12, 8, w - 44, 28)];
    self.rawTextField.font = [UIFont systemFontOfSize:14.0f];
    self.rawTextField.textColor = isDark ? [UIColor colorWithWhite:0.7f alpha:1.0f] : [UIColor colorWithWhite:0.4f alpha:1.0f];
    self.rawTextField.text = self.currentLatex;
    self.rawTextField.placeholder = L(@"Enter equation (e.g. 2x + 5 = 15)...");
    self.rawTextField.userInteractionEnabled = NO; // Edited via math keypad
    [self.previewCard addSubview:self.rawTextField];

    // Live LaTeX preview
    self.mathPreviewLabel = [[MTMathUILabel alloc] initWithFrame:CGRectMake(12, 40, w - 44, 70)];
    self.mathPreviewLabel.labelMode = kMTMathUILabelModeDisplay;
    self.mathPreviewLabel.fontSize = 24.0f;
    self.mathPreviewLabel.textColor = isDark ? [UIColor whiteColor] : [UIColor colorWithRed:0.10f green:0.12f blue:0.18f alpha:1.0f];
    self.mathPreviewLabel.latex = self.currentLatex.length ? self.currentLatex : @"";
    [self.previewCard addSubview:self.mathPreviewLabel];
}

- (void)setupKeypad
{
    CGFloat w = self.view.bounds.size.width;
    CGFloat topY = CGRectGetMaxY(self.previewCard.frame) + 8.0f;
    CGFloat availH = self.view.bounds.size.height - topY - 10.0f;

    // Mode switch: Basic Algebra vs Functions
    self.modeSegment = [[UISegmentedControl alloc] initWithItems:@[ L(@"Basic & Algebra"), L(@"Functions & Trig") ]];
    self.modeSegment.frame = CGRectMake(10, topY, w - 20, 32);
    self.modeSegment.segmentedControlStyle = UISegmentedControlStyleBar;
    self.modeSegment.tintColor = [[PMTheme shared] accentColor];
    self.modeSegment.selectedSegmentIndex = 0;
    [self.modeSegment addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.modeSegment];

    self.keypadContainer = [[UIView alloc] initWithFrame:CGRectMake(10, topY + 38.0f, w - 20, availH - 44.0f)];
    self.keypadContainer.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.keypadContainer];

    [self rebuildKeypadButtons];
}

- (void)modeChanged:(id)sender
{
    [self rebuildKeypadButtons];
}

- (void)rebuildKeypadButtons
{
    for (UIView *v in self.currentButtons) [v removeFromSuperview];
    [self.currentButtons removeAllObjects];

    NSArray *keys;
    if (self.modeSegment.selectedSegmentIndex == 0) {
        keys = @[
            @[ @"x", @"y", @"z", @"(", @")", @"=", @"C", @"⌫" ],
            @[ @"7", @"8", @"9", @"+", @"-", @"x^2", @"x^y", @"\\sqrt{}" ],
            @[ @"4", @"5", @"6", @"*", @"/", @"\\frac{}{}", @"<", @">" ],
            @[ @"1", @"2", @"3", @"0", @".", @"\\le", @"\\ge", @"\\pm" ]
        ];
    } else {
        keys = @[
            @[ @"\\sin", @"\\cos", @"\\tan", @"\\pi", @"e", @"|x|", @"C", @"⌫" ],
            @[ @"\\arcsin", @"\\arccos", @"\\arctan", @"\\log", @"\\ln", @"!", @"\\infty", @"=" ],
            @[ @"\\alpha", @"\\beta", @"\\theta", @"\\sum", @"\\int", @"\\lim", @"[", @"]" ],
            @[ @"1", @"2", @"3", @"0", @"+", @"-", @"*", @"/" ]
        ];
    }

    CGFloat totalW = self.keypadContainer.bounds.size.width;
    CGFloat totalH = self.keypadContainer.bounds.size.height;
    CGFloat solveBtnH = 44.0f;
    CGFloat gridH = totalH - solveBtnH - 8.0f;

    NSInteger rows = 4;
    NSInteger cols = 8;
    CGFloat spacing = 4.0f;
    CGFloat btnW = floorf((totalW - (cols - 1) * spacing) / cols);
    CGFloat btnH = floorf((gridH - (rows - 1) * spacing) / rows);

    for (NSInteger r = 0; r < rows; r++) {
        NSArray *rowKeys = keys[r];
        for (NSInteger c = 0; c < cols; c++) {
            NSString *key = rowKeys[c];
            CGFloat x = c * (btnW + spacing);
            CGFloat y = r * (btnH + spacing);

            UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
            btn.frame = CGRectMake(x, y, btnW, btnH);
            btn.titleLabel.font = [UIFont boldSystemFontOfSize:14.0f];

            BOOL isSpecial = [key isEqualToString:@"C"] || [key isEqualToString:@"⌫"];
            UIColor *bgCol = isSpecial ? [UIColor colorWithRed:0.75f green:0.25f blue:0.25f alpha:1.0f] : [UIColor colorWithWhite:0.88f alpha:1.0f];
            UIColor *txtCol = isSpecial ? [UIColor whiteColor] : [UIColor colorWithWhite:0.15f alpha:1.0f];

            UIImage *bg = [[PMTheme shared] glossyButtonImageWithColor:bgCol highlighted:NO];
            [btn setBackgroundImage:bg forState:UIControlStateNormal];
            [btn setTitle:[self displayTitleForKey:key] forState:UIControlStateNormal];
            [btn setTitleColor:txtCol forState:UIControlStateNormal];

            btn.accessibilityValue = key;
            [btn addTarget:self action:@selector(keyTapped:) forControlEvents:UIControlEventTouchUpInside];

            [self.keypadContainer addSubview:btn];
            [self.currentButtons addObject:btn];
        }
    }

    // Solve button at the bottom
    UIButton *solveBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    solveBtn.frame = CGRectMake(0, gridH + 8.0f, totalW, solveBtnH);
    UIImage *solveBg = [[PMTheme shared] glossyButtonImageWithColor:[[PMTheme shared] accentColor] highlighted:NO];
    [solveBtn setBackgroundImage:solveBg forState:UIControlStateNormal];
    [solveBtn setTitle:L(@"Solve Problem") forState:UIControlStateNormal];
    [solveBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    solveBtn.titleLabel.font = [UIFont boldSystemFontOfSize:17.0f];
    solveBtn.titleLabel.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.4f];
    solveBtn.titleLabel.shadowOffset = CGSizeMake(0, -1);
    [solveBtn addTarget:self action:@selector(solveTapped:) forControlEvents:UIControlEventTouchUpInside];

    [self.keypadContainer addSubview:solveBtn];
    [self.currentButtons addObject:solveBtn];
}

- (NSString *)displayTitleForKey:(NSString *)key
{
    if ([key isEqualToString:@"\\sqrt{}"]) return @"√";
    if ([key isEqualToString:@"\\frac{}{}"]) return @"a/b";
    if ([key isEqualToString:@"\\pi"]) return @"π";
    if ([key isEqualToString:@"\\sin"]) return @"sin";
    if ([key isEqualToString:@"\\cos"]) return @"cos";
    if ([key isEqualToString:@"\\tan"]) return @"tan";
    if ([key isEqualToString:@"\\log"]) return @"log";
    if ([key isEqualToString:@"\\ln"]) return @"ln";
    if ([key isEqualToString:@"\\le"]) return @"≤";
    if ([key isEqualToString:@"\\ge"]) return @"≥";
    if ([key isEqualToString:@"\\pm"]) return @"±";
    if ([key isEqualToString:@"\\alpha"]) return @"α";
    if ([key isEqualToString:@"\\beta"]) return @"β";
    if ([key isEqualToString:@"\\theta"]) return @"θ";
    if ([key isEqualToString:@"\\sum"]) return @"∑";
    if ([key isEqualToString:@"\\int"]) return @"∫";
    if ([key isEqualToString:@"\\lim"]) return @"lim";
    if ([key isEqualToString:@"\\infty"]) return @"∞";
    return key;
}

- (void)keyTapped:(UIButton *)sender
{
    NSString *key = sender.accessibilityValue;
    if ([key isEqualToString:@"C"]) {
        self.currentLatex = @"";
    } else if ([key isEqualToString:@"⌫"]) {
        if (self.currentLatex.length > 0) {
            self.currentLatex = [self.currentLatex substringToIndex:self.currentLatex.length - 1];
        }
    } else if ([key isEqualToString:@"x^2"]) {
        self.currentLatex = [self.currentLatex stringByAppendingString:@"^2"];
    } else if ([key isEqualToString:@"x^y"]) {
        self.currentLatex = [self.currentLatex stringByAppendingString:@"^{}"];
    } else if ([key isEqualToString:@"\\sqrt{}"]) {
        self.currentLatex = [self.currentLatex stringByAppendingString:@"\\sqrt{}"];
    } else if ([key isEqualToString:@"\\frac{}{}"]) {
        self.currentLatex = [self.currentLatex stringByAppendingString:@"\\frac{}{}"];
    } else {
        self.currentLatex = [self.currentLatex stringByAppendingString:key];
    }

    [self updateMathPreview];
}

- (void)updateMathPreview
{
    self.rawTextField.text = self.currentLatex;
    self.mathPreviewLabel.latex = self.currentLatex.length ? self.currentLatex : @"";
}

- (void)solveTapped:(id)sender
{
    if (!self.currentLatex.length) {
        [PMUtils alertWithTitle:L(@"Empty Problem") message:L(@"Please type a mathematical problem first.")];
        return;
    }
    if (self.onSolveRequested) {
        self.onSolveRequested(self.currentLatex);
        [self.navigationController popViewControllerAnimated:YES];
    }
}

@end
