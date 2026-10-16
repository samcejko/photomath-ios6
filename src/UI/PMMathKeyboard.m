#import "PMMathKeyboard.h"
#import "PMTheme.h"
#import "PMCommon.h"
#import "PMSettings.h"
#import "PMUtils.h"
#import "PMModern.h"
#import "MTMathUILabel.h"
#import <QuartzCore/QuartzCore.h>

@interface PMMathKeyboard ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *previewCard;
@property (nonatomic, strong) UITextField *rawTextField;
@property (nonatomic, strong) MTMathUILabel *mathPreviewLabel;
@property (nonatomic, strong) UISegmentedControl *modeSegment;
@property (nonatomic, strong) UIView *keypadContainer;
@property (nonatomic, strong) UIButton *solveButton;
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

    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.alwaysBounceVertical = YES;
    PMModernKeepScrollViewInsets(self.scrollView);
    [self.view addSubview:self.scrollView];

    [self setupPreviewCard];
    [self setupModeSegment];
    [self setupKeypad];
    [self updateMathPreview];
}

- (void)setupPreviewCard
{
    BOOL isDark = [PMSettings shared].darkTheme;

    self.previewCard = [[UIView alloc] initWithFrame:CGRectZero];
    self.previewCard.backgroundColor = isDark ? [UIColor colorWithWhite:0.18f alpha:1.0f] : [UIColor whiteColor];
    self.previewCard.layer.cornerRadius = 8.0f;
    self.previewCard.layer.borderWidth = 1.0f;
    self.previewCard.layer.borderColor = isDark ? [UIColor colorWithWhite:0.28f alpha:1.0f].CGColor : [UIColor colorWithRed:0.86f green:0.88f blue:0.92f alpha:1.0f].CGColor;
    [self.scrollView addSubview:self.previewCard];

    self.rawTextField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.rawTextField.font = [UIFont systemFontOfSize:13.0f];
    self.rawTextField.textColor = isDark ? [UIColor colorWithWhite:0.7f alpha:1.0f] : [UIColor colorWithWhite:0.4f alpha:1.0f];
    self.rawTextField.text = self.currentLatex;
    self.rawTextField.placeholder = L(@"Enter equation (e.g. 2x + 5 = 15)...");
    self.rawTextField.userInteractionEnabled = NO;
    [self.previewCard addSubview:self.rawTextField];

    self.mathPreviewLabel = [[MTMathUILabel alloc] initWithFrame:CGRectZero];
    self.mathPreviewLabel.labelMode = kMTMathUILabelModeDisplay;
    self.mathPreviewLabel.fontSize = 22.0f;
    self.mathPreviewLabel.textColor = isDark ? [UIColor whiteColor] : [UIColor colorWithRed:0.10f green:0.12f blue:0.18f alpha:1.0f];
    self.mathPreviewLabel.latex = self.currentLatex.length ? self.currentLatex : @"";
    [self.previewCard addSubview:self.mathPreviewLabel];
}

- (void)setupModeSegment
{
    self.modeSegment = [[UISegmentedControl alloc] initWithItems:@[
        L(@"123 & Basic"),
        L(@"Algebra"),
        L(@"Trig & Calc")
    ]];
    self.modeSegment.segmentedControlStyle = UISegmentedControlStyleBar;
    self.modeSegment.tintColor = [[PMTheme shared] accentColor];
    self.modeSegment.selectedSegmentIndex = 0;
    [self.modeSegment addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
    [self.scrollView addSubview:self.modeSegment];
}

- (void)setupKeypad
{
    self.keypadContainer = [[UIView alloc] initWithFrame:CGRectZero];
    self.keypadContainer.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:self.keypadContainer];

    self.solveButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *solveBg = [[PMTheme shared] glossyButtonImageWithColor:[[PMTheme shared] accentColor] highlighted:NO];
    [self.solveButton setBackgroundImage:solveBg forState:UIControlStateNormal];
    [self.solveButton setTitle:L(@"Solve Problem") forState:UIControlStateNormal];
    [self.solveButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.solveButton.titleLabel.font = [UIFont boldSystemFontOfSize:16.0f];
    self.solveButton.titleLabel.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.4f];
    self.solveButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
    [self.solveButton addTarget:self action:@selector(solveTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:self.solveButton];

    [self rebuildKeypadButtons];
}

- (void)modeChanged:(id)sender
{
    [self rebuildKeypadButtons];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    if (w <= 0 || h <= 0) return;

    self.scrollView.frame = self.view.bounds;

    CGFloat margin = 10.0f;
    CGFloat cardW = w - margin * 2;
    BOOL compact = (h <= 480.0f);

    CGFloat cardH = compact ? 76.0f : 92.0f;
    self.previewCard.frame = CGRectMake(margin, margin, cardW, cardH);
    self.rawTextField.frame = CGRectMake(10, 6, cardW - 20, 22);
    self.mathPreviewLabel.frame = CGRectMake(10, 30, cardW - 20, cardH - 36);
    self.mathPreviewLabel.fontSize = compact ? 18.0f : 22.0f;

    CGFloat segH = compact ? 28.0f : 32.0f;
    CGFloat segY = CGRectGetMaxY(self.previewCard.frame) + 8.0f;
    self.modeSegment.frame = CGRectMake(margin, segY, cardW, segH);

    CGFloat keyY = CGRectGetMaxY(self.modeSegment.frame) + 8.0f;
    CGFloat btnH = compact ? 40.0f : 44.0f;
    CGFloat spacing = 5.0f;
    NSInteger rows = 4;
    CGFloat gridH = rows * btnH + (rows - 1) * spacing;
    self.keypadContainer.frame = CGRectMake(margin, keyY, cardW, gridH);

    [self layoutButtonsInWidth:cardW height:gridH btnHeight:btnH spacing:spacing];

    CGFloat solveH = 42.0f;
    CGFloat solveY = CGRectGetMaxY(self.keypadContainer.frame) + 10.0f;
    self.solveButton.frame = CGRectMake(margin, solveY, cardW, solveH);

    CGFloat contentH = CGRectGetMaxY(self.solveButton.frame) + margin + 10.0f;
    self.scrollView.contentSize = CGSizeMake(w, MAX(contentH, h + 1.0f));
}

- (void)layoutButtonsInWidth:(CGFloat)totalW height:(CGFloat)totalH btnHeight:(CGFloat)btnH spacing:(CGFloat)spacing
{
    NSInteger cols = 5;
    CGFloat btnW = floorf((totalW - (cols - 1) * spacing) / cols);

    NSInteger btnIdx = 0;
    for (NSInteger r = 0; r < 4; r++) {
        for (NSInteger c = 0; c < cols; c++) {
            if (btnIdx >= self.currentButtons.count) break;
            UIButton *btn = self.currentButtons[btnIdx++];
            CGFloat x = c * (btnW + spacing);
            CGFloat y = r * (btnH + spacing);
            btn.frame = CGRectMake(x, y, btnW, btnH);
        }
    }
}

- (void)rebuildKeypadButtons
{
    for (UIView *v in self.currentButtons) [v removeFromSuperview];
    [self.currentButtons removeAllObjects];

    NSArray *keys;
    NSInteger mode = self.modeSegment.selectedSegmentIndex;
    if (mode == 0) {
        // 123 & Basic (5 cols x 4 rows)
        keys = @[
            @[ @"7", @"8", @"9", @"/", @"C" ],
            @[ @"4", @"5", @"6", @"*", @"⌫" ],
            @[ @"1", @"2", @"3", @"-", @"(" ],
            @[ @"0", @".", @"=", @"+", @")" ]
        ];
    } else if (mode == 1) {
        // Algebra (5 cols x 4 rows)
        keys = @[
            @[ @"x", @"y", @"z", @"x^2", @"x^y" ],
            @[ @"\\sqrt{}", @"\\frac{}{}", @"|x|", @"<", @">" ],
            @[ @"\\le", @"\\ge", @"\\pm", @"\\pi", @"e" ],
            @[ @"[", @"]", @"C", @"=", @"⌫" ]
        ];
    } else {
        // Trig & Functions (5 cols x 4 rows)
        keys = @[
            @[ @"\\sin", @"\\cos", @"\\tan", @"\\log", @"\\ln" ],
            @[ @"\\arcsin", @"\\arccos", @"\\arctan", @"!", @"\\infty" ],
            @[ @"\\int", @"\\sum", @"\\lim", @"\\frac{d}{dx}", @"\\sqrt{}" ],
            @[ @"\\alpha", @"\\beta", @"\\theta", @"=", @"⌫" ]
        ];
    }

    for (NSInteger r = 0; r < 4; r++) {
        NSArray *rowKeys = keys[r];
        for (NSInteger c = 0; c < 5; c++) {
            NSString *key = rowKeys[c];

            UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
            btn.titleLabel.font = [UIFont boldSystemFontOfSize:16.0f];

            BOOL isClear = [key isEqualToString:@"C"];
            BOOL isDelete = [key isEqualToString:@"⌫"];
            BOOL isOperator = [key isEqualToString:@"+"] || [key isEqualToString:@"-"] ||
                              [key isEqualToString:@"*"] || [key isEqualToString:@"/"] ||
                              [key isEqualToString:@"="];

            UIColor *bgCol;
            UIColor *txtCol;

            if (isClear) {
                bgCol = [UIColor colorWithRed:0.82f green:0.25f blue:0.25f alpha:1.0f];
                txtCol = [UIColor whiteColor];
            } else if (isDelete) {
                bgCol = [UIColor colorWithRed:0.45f green:0.48f blue:0.55f alpha:1.0f];
                txtCol = [UIColor whiteColor];
            } else if (isOperator) {
                bgCol = [UIColor colorWithRed:0.96f green:0.86f blue:0.75f alpha:1.0f];
                txtCol = [UIColor colorWithRed:0.35f green:0.18f blue:0.05f alpha:1.0f];
            } else {
                bgCol = [UIColor colorWithWhite:0.92f alpha:1.0f];
                txtCol = [UIColor colorWithWhite:0.12f alpha:1.0f];
            }

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

    [self.view setNeedsLayout];
}

- (NSString *)displayTitleForKey:(NSString *)key
{
    if ([key isEqualToString:@"*"]) return @"×";
    if ([key isEqualToString:@"/"]) return @"÷";
    if ([key isEqualToString:@"\\sqrt{}"]) return @"√";
    if ([key isEqualToString:@"\\frac{}{}"]) return @"a/b";
    if ([key isEqualToString:@"x^2"]) return @"x²";
    if ([key isEqualToString:@"x^y"]) return @"xʸ";
    if ([key isEqualToString:@"|x|"]) return @"|x|";
    if ([key isEqualToString:@"\\pi"]) return @"π";
    if ([key isEqualToString:@"\\sin"]) return @"sin";
    if ([key isEqualToString:@"\\cos"]) return @"cos";
    if ([key isEqualToString:@"\\tan"]) return @"tan";
    if ([key isEqualToString:@"\\arcsin"]) return @"sin⁻¹";
    if ([key isEqualToString:@"\\arccos"]) return @"cos⁻¹";
    if ([key isEqualToString:@"\\arctan"]) return @"tan⁻¹";
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
    if ([key isEqualToString:@"\\frac{d}{dx}"]) return @"d/dx";
    return key;
}

- (void)keyTapped:(UIButton *)sender
{
    NSString *key = sender.accessibilityValue;
    if ([key isEqualToString:@"C"]) {
        self.currentLatex = @"";
    } else if ([key isEqualToString:@"⌫"]) {
        if (self.currentLatex.length > 0) {
            // Delete backslash command or single character
            if ([self.currentLatex hasSuffix:@"{}"]) {
                self.currentLatex = [self.currentLatex substringToIndex:self.currentLatex.length - 2];
            } else {
                self.currentLatex = [self.currentLatex substringToIndex:self.currentLatex.length - 1];
            }
        }
    } else if ([key isEqualToString:@"x^2"]) {
        self.currentLatex = [self.currentLatex stringByAppendingString:@"^2"];
    } else if ([key isEqualToString:@"x^y"]) {
        self.currentLatex = [self.currentLatex stringByAppendingString:@"^{}"];
    } else if ([key isEqualToString:@"\\sqrt{}"]) {
        self.currentLatex = [self.currentLatex stringByAppendingString:@"\\sqrt{}"];
    } else if ([key isEqualToString:@"\\frac{}{}"]) {
        self.currentLatex = [self.currentLatex stringByAppendingString:@"\\frac{}{}"];
    } else if ([key isEqualToString:@"|x|"]) {
        self.currentLatex = [self.currentLatex stringByAppendingString:@"| |"];
    } else if ([key isEqualToString:@"\\sin"] || [key isEqualToString:@"\\cos"] || [key isEqualToString:@"\\tan"] ||
               [key isEqualToString:@"\\arcsin"] || [key isEqualToString:@"\\arccos"] || [key isEqualToString:@"\\arctan"] ||
               [key isEqualToString:@"\\log"] || [key isEqualToString:@"\\ln"]) {
        self.currentLatex = [self.currentLatex stringByAppendingFormat:@"%@(", key];
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
