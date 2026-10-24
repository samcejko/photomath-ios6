#import "PMMathEditing.h"
#import "PMMathKeyboard.h"
#import "PMTheme.h"
#import "PMCommon.h"
#import "PMSettings.h"
#import "PMUtils.h"
#import "PMModern.h"
#import "MTMathUILabel.h"
#import <QuartzCore/QuartzCore.h>
#import <ctype.h>

static BOOL PMMathBaseCharacter(unichar c) { return (c>='a'&&c<='z') || (c>='A'&&c<='Z') || (c>='0'&&c<='9') || c==0x03c0 || c==')' || c==']' || c=='}'; }

#pragma mark - Callout View


static UIImage *AuditDirectionIcon(NSString *direction, UIColor *color)
{
    if (![@[@"left", @"right", @"up", @"down"] containsObject:direction]) return nil;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(18, 18), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(ctx, 9, 9);
    CGFloat angle = [direction isEqualToString:@"left"] ? 3.14159265 :
        ([direction isEqualToString:@"up"] ? -1.57079633 : ([direction isEqualToString:@"down"] ? 1.57079633 : 0));
    CGContextRotateCTM(ctx, angle);
    CGContextSetStrokeColorWithColor(ctx, color.CGColor);
    CGContextSetLineWidth(ctx, 2);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    CGContextMoveToPoint(ctx, -6, 0);
    CGContextAddLineToPoint(ctx, 6, 0);
    CGContextMoveToPoint(ctx, 1, -5);
    CGContextAddLineToPoint(ctx, 6, 0);
    CGContextAddLineToPoint(ctx, 1, 5);
    CGContextStrokePath(ctx);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@interface PMKeyCalloutView : UIView <UIGestureRecognizerDelegate>
@property (nonatomic, copy) void (^onOptionSelected)(NSString *key);
@property (nonatomic, strong) UIView *bubbleView;
@property (nonatomic, strong) CAShapeLayer *pointerLayer;
@property (nonatomic, strong) NSMutableArray *optionButtons;
@property (nonatomic, weak) UIView *targetContainer;

- (instancetype)initWithButton:(UIButton *)sourceButton
                       options:(NSArray *)options
                        titles:(NSArray *)titles
                        inView:(UIView *)containerView;
- (void)showAnimated;
- (void)dismissAnimated;
@end

@implementation PMKeyCalloutView

- (instancetype)initWithButton:(UIButton *)sourceButton
                       options:(NSArray *)options
                        titles:(NSArray *)titles
                        inView:(UIView *)containerView
{
    self = [super initWithFrame:containerView.bounds];
    if (self) {
        _targetContainer = containerView;
        _optionButtons = [NSMutableArray array];
        self.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.01f]; // Transparent touch interceptor

        // Measure options (arrange in 2 rows if > 5 items to fit 320pt iPhone screen)
        NSInteger count = options.count;
        CGFloat btnW = 44.0f;
        CGFloat btnH = 44.0f;
        CGFloat spacing = 4.0f;
        CGFloat padding = 8.0f;

        NSInteger cols = (count <= 5) ? count : (count + 1) / 2;
        NSInteger rows = (count + cols - 1) / cols;
        CGFloat bubbleW = padding * 2 + cols * btnW + (cols - 1) * spacing;
        CGFloat bubbleH = padding * 2 + rows * btnH + (rows - 1) * spacing;
        CGFloat pointerH = 9.0f;
        CGFloat totalH = bubbleH + pointerH;

        // Source button rect in container view
        CGRect btnRect = [sourceButton convertRect:sourceButton.bounds toView:containerView];
        CGFloat btnCenterX = CGRectGetMidX(btnRect);
        CGFloat bubbleX = btnCenterX - bubbleW / 2.0f;

        // Clamp to screen bounds
        CGFloat minX = 8.0f;
        CGFloat maxX = containerView.bounds.size.width - bubbleW - 8.0f;
        if (bubbleX < minX) bubbleX = minX;
        if (bubbleX > maxX) bubbleX = maxX;

        CGFloat bubbleY = btnRect.origin.y - totalH - 4.0f;
        BOOL pointerAtBottom = YES;
        if (bubbleY < 10.0f) {
            // Flip to below button if no space above
            bubbleY = CGRectGetMaxY(btnRect) + 6.0f;
            pointerAtBottom = NO;
        }

        // Bubble View
        self.bubbleView = [[UIView alloc] initWithFrame:CGRectMake(bubbleX, bubbleY, bubbleW, bubbleH)];
        self.bubbleView.backgroundColor = [UIColor colorWithWhite:0.12f alpha:0.96f];
        self.bubbleView.layer.cornerRadius = 9.0f;
        self.bubbleView.layer.borderWidth = 1.0f;
        self.bubbleView.layer.borderColor = [UIColor colorWithWhite:1.0f alpha:0.35f].CGColor;
        self.bubbleView.layer.shadowColor = [UIColor blackColor].CGColor;
        self.bubbleView.layer.shadowOffset = CGSizeMake(0, 3);
        self.bubbleView.layer.shadowRadius = 6.0f;
        self.bubbleView.layer.shadowOpacity = 0.6f;
        [self addSubview:self.bubbleView];

        // Pointer triangle
        UIBezierPath *path = [UIBezierPath bezierPath];
        CGFloat ptrW = 14.0f;
        CGFloat tipX = btnCenterX;
        if (tipX < bubbleX + 16.0f) tipX = bubbleX + 16.0f;
        if (tipX > bubbleX + bubbleW - 16.0f) tipX = bubbleX + bubbleW - 16.0f;

        if (pointerAtBottom) {
            [path moveToPoint:CGPointMake(tipX - ptrW / 2.0f, bubbleY + bubbleH)];
            [path addLineToPoint:CGPointMake(tipX, bubbleY + bubbleH + pointerH)];
            [path addLineToPoint:CGPointMake(tipX + ptrW / 2.0f, bubbleY + bubbleH)];
        } else {
            [path moveToPoint:CGPointMake(tipX - ptrW / 2.0f, bubbleY)];
            [path addLineToPoint:CGPointMake(tipX, bubbleY - pointerH)];
            [path addLineToPoint:CGPointMake(tipX + ptrW / 2.0f, bubbleY)];
        }
        [path closePath];

        self.pointerLayer = [CAShapeLayer layer];
        self.pointerLayer.path = path.CGPath;
        self.pointerLayer.fillColor = [UIColor colorWithWhite:0.12f alpha:0.96f].CGColor;
        self.pointerLayer.strokeColor = [UIColor colorWithWhite:1.0f alpha:0.35f].CGColor;
        self.pointerLayer.lineWidth = 1.0f;
        [self.layer addSublayer:self.pointerLayer];

        // Option Buttons
        for (NSInteger i = 0; i < count; i++) {
            NSString *key = [options objectAtIndex:i];
            NSString *title = (i < titles.count) ? [titles objectAtIndex:i] : key;

            NSInteger r = i / cols;
            NSInteger c = i % cols;
            CGFloat bx = padding + c * (btnW + spacing);
            CGFloat by = padding + r * (btnH + spacing);

            UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
            btn.frame = CGRectMake(bx, by, btnW, btnH);
            btn.backgroundColor = [UIColor colorWithWhite:0.25f alpha:1.0f];
            btn.layer.cornerRadius = 6.0f;
            btn.layer.borderWidth = 0.5f;
            btn.layer.borderColor = [UIColor colorWithWhite:1.0f alpha:0.2f].CGColor;

            [btn setTitle:title forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont boldSystemFontOfSize:16.0f];
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [btn setTitleColor:[UIColor colorWithRed:1.0f green:0.8f blue:0.4f alpha:1.0f] forState:UIControlStateHighlighted];

            btn.accessibilityValue = key;
            [btn addTarget:self action:@selector(optionTapped:) forControlEvents:UIControlEventTouchUpInside];
            [self.bubbleView addSubview:btn];
            [self.optionButtons addObject:btn];
        }

        // Tap outside to dismiss
        UITapGestureRecognizer *outsideTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissAnimated)];
        outsideTap.delegate = self;
        [self addGestureRecognizer:outsideTap];
    }
    return self;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if ([touch.view isDescendantOfView:self.bubbleView]) {
        return NO;
    }
    return YES;
}

- (void)optionTapped:(UIButton *)btn
{
    NSString *key = btn.accessibilityValue;
    if (self.onOptionSelected) {
        self.onOptionSelected(key);
    }
    [self dismissAnimated];
}

- (void)showAnimated
{
    self.alpha = 0.0f;
    self.bubbleView.transform = CGAffineTransformMakeScale(0.85f, 0.85f);
    [UIView animateWithDuration:0.18 animations:^{
        self.alpha = 1.0f;
        self.bubbleView.transform = CGAffineTransformIdentity;
    }];
}

- (void)dismissAnimated
{
    [UIView animateWithDuration:0.15 animations:^{
        self.alpha = 0.0f;
        self.bubbleView.transform = CGAffineTransformMakeScale(0.85f, 0.85f);
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

@end

#pragma mark - PMMathKeyboard

@interface PMMathKeyboard () <UIScrollViewDelegate, UITextFieldDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *previewCard;
@property (nonatomic, strong) UITextField *rawTextField;
@property (nonatomic, strong) MTMathUILabel *mathPreviewLabel;
@property (nonatomic, strong) UILabel *previewHint;
@property (nonatomic) NSInteger selectedLength;
@property (nonatomic, strong) UIButton *cursorLeftBtn;
@property (nonatomic, strong) UIButton *cursorRightBtn;
@property (nonatomic, strong) UISegmentedControl *modeSegment;
@property (nonatomic, strong) UIView *keypadContainer;
@property (nonatomic, strong) UIButton *solveButton;
@property (nonatomic, strong) NSMutableArray *currentButtons;
@property (nonatomic) NSInteger cursorPosition;
@property (nonatomic, strong) PMKeyCalloutView *activeCallout;
@end

@implementation PMMathKeyboard

- (instancetype)initWithInitialLatex:(NSString *)initialLatex
{
    self = [super init];
    if (self) {
        NSString *draft=[NSString stringWithContentsOfFile:[[PMUtils historyPath] stringByAppendingPathComponent:@"draft.txt"] encoding:NSUTF8StringEncoding error:NULL] ?: [[NSUserDefaults standardUserDefaults] stringForKey:@"PMMathDraftLatex"];
        _currentLatex = initialLatex.length ? [initialLatex copy] : (draft ?: @"");
        _cursorPosition = _currentLatex.length;
        self.title = L(@"Math Editor");
        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:L(@"Math Editor") style:UIBarButtonItemStyleBordered target:nil action:nil];
        _currentButtons = [NSMutableArray array];
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.rawTextField becomeFirstResponder];
    [self updateMathPreview];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.rawTextField resignFirstResponder];
    [self.activeCallout removeFromSuperview];self.activeCallout=nil;
}

- (void)setSolving:(BOOL)solving
{
    _solving=solving;self.solveButton.enabled=!solving;
    self.keypadContainer.userInteractionEnabled=!solving;
    self.rawTextField.enabled=!solving;
    if(!solving && self.isViewLoaded && self.view.window)[self.rawTextField becomeFirstResponder];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[PMTheme shared] applyToNavigationBar:self.navigationController.navigationBar];
    self.view.backgroundColor = [[PMTheme shared] backgroundColor];

    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.delegate = self;
    PMModernKeepScrollViewInsets(self.scrollView);
    [self.view addSubview:self.scrollView];

    [self setupPreviewCard];
    [self setupModeSegment];
    [self setupKeypad];
    [self updateMathPreview];
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:L(@"Next Field") style:UIBarButtonItemStyleBordered target:self action:@selector(nextField:)];
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
    self.rawTextField.delegate=self;
    self.rawTextField.accessibilityIdentifier=@"MathInput";
    self.rawTextField.placeholder = L(@"Enter equation (e.g. 2x + 5 = 15)...");
    self.rawTextField.inputView = [[UIView alloc] initWithFrame:CGRectZero]; // Suppress system keyboard
    self.rawTextField.userInteractionEnabled = YES;
    self.rawTextField.autocorrectionType=UITextAutocorrectionTypeNo;
    self.rawTextField.autocapitalizationType=UITextAutocapitalizationTypeNone;
    [self.rawTextField addTarget:self action:@selector(textFieldCursorChanged:) forControlEvents:UIControlEventEditingChanged];
    [self.previewCard addSubview:self.rawTextField];

    // Drawn cursor navigation buttons
    self.cursorLeftBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.cursorLeftBtn.accessibilityLabel=L(@"Move cursor left");
    [self.cursorLeftBtn setImage:AuditDirectionIcon(@"left", [UIColor darkGrayColor]) forState:UIControlStateNormal];
    [self.cursorLeftBtn setTitleColor:[UIColor colorWithWhite:0.3f alpha:1.0f] forState:UIControlStateNormal];
    [self.cursorLeftBtn setTitleColor:[[PMTheme shared] accentColor] forState:UIControlStateHighlighted];
    self.cursorLeftBtn.titleLabel.font = [UIFont systemFontOfSize:12.0f];
    self.cursorLeftBtn.backgroundColor = [UIColor colorWithWhite:0.92f alpha:1.0f];
    self.cursorLeftBtn.layer.cornerRadius = 4.0f;
    self.cursorLeftBtn.layer.borderWidth = 0.5f;
    self.cursorLeftBtn.layer.borderColor = [UIColor colorWithWhite:0.75f alpha:1.0f].CGColor;
    [self.cursorLeftBtn addTarget:self action:@selector(stepCursorLeft:) forControlEvents:UIControlEventTouchUpInside];
    [self.previewCard addSubview:self.cursorLeftBtn];

    self.cursorRightBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.cursorRightBtn.accessibilityLabel=L(@"Move cursor right");
    [self.cursorRightBtn setImage:AuditDirectionIcon(@"right", [UIColor darkGrayColor]) forState:UIControlStateNormal];
    [self.cursorRightBtn setTitleColor:[UIColor colorWithWhite:0.3f alpha:1.0f] forState:UIControlStateNormal];
    [self.cursorRightBtn setTitleColor:[[PMTheme shared] accentColor] forState:UIControlStateHighlighted];
    self.cursorRightBtn.titleLabel.font = [UIFont systemFontOfSize:12.0f];
    self.cursorRightBtn.backgroundColor = [UIColor colorWithWhite:0.92f alpha:1.0f];
    self.cursorRightBtn.layer.cornerRadius = 4.0f;
    self.cursorRightBtn.layer.borderWidth = 0.5f;
    self.cursorRightBtn.layer.borderColor = [UIColor colorWithWhite:0.75f alpha:1.0f].CGColor;
    [self.cursorRightBtn addTarget:self action:@selector(stepCursorRight:) forControlEvents:UIControlEventTouchUpInside];
    [self.previewCard addSubview:self.cursorRightBtn];

    self.mathPreviewLabel = [[MTMathUILabel alloc] initWithFrame:CGRectZero];
    self.mathPreviewLabel.labelMode = kMTMathUILabelModeDisplay;
    self.mathPreviewLabel.fontSize = 22.0f;
    self.mathPreviewLabel.textColor = isDark ? [UIColor whiteColor] : [UIColor colorWithRed:0.10f green:0.12f blue:0.18f alpha:1.0f];
    self.mathPreviewLabel.latex = self.currentLatex.length ? self.currentLatex : @"";
    self.mathPreviewLabel.displayErrorInline=NO;
    [self.previewCard addSubview:self.mathPreviewLabel];
    self.previewHint=[[UILabel alloc] initWithFrame:CGRectZero];self.previewHint.backgroundColor=[UIColor clearColor];self.previewHint.font=[UIFont systemFontOfSize:13];self.previewHint.textColor=self.rawTextField.textColor;self.previewHint.text=L(@"Complete the formula to preview it.");self.previewHint.numberOfLines=2;self.previewHint.hidden=YES;[self.previewCard addSubview:self.previewHint];
}

- (void)stepCursorLeft:(id)sender
{
    [self syncSelection];
    if (self.cursorPosition > 0) {
        self.cursorPosition--;
        [self updateMathPreview];
    }
}

- (void)stepCursorRight:(id)sender
{
    [self syncSelection];
    if (self.cursorPosition < self.currentLatex.length) {
        self.cursorPosition++;
        [self updateMathPreview];
    }
}

- (void)syncSelection
{
    UITextRange *range=self.rawTextField.selectedTextRange;
    if(range) {
        self.cursorPosition=MAX(0,MIN((NSInteger)self.currentLatex.length,[self.rawTextField offsetFromPosition:self.rawTextField.beginningOfDocument toPosition:range.start]));
        self.selectedLength=MAX(0,[self.rawTextField offsetFromPosition:range.start toPosition:range.end]);
    }
}
- (void)textFieldCursorChanged:(UITextField *)field
{
    self.currentLatex=field.text ?: @"";[self syncSelection];[self updateMathPreview];
}
- (BOOL)textField:(UITextField *)field shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    return range.location<=field.text.length && range.length<=field.text.length-range.location && field.text.length-range.length+string.length<=1024;
}
- (void)nextField:(id)sender
{
    [self syncSelection];
    NSRange remaining=NSMakeRange(self.cursorPosition,self.currentLatex.length-self.cursorPosition);
    NSRange empty=[self.currentLatex rangeOfString:@"{}" options:0 range:remaining];
    if(empty.location!=NSNotFound)self.cursorPosition=empty.location+1;
    else {
        NSRange close=[self.currentLatex rangeOfString:@"}" options:0 range:remaining];
        self.cursorPosition=close.location!=NSNotFound?close.location+1:self.currentLatex.length;
    }
    self.selectedLength=0;[self updateMathPreview];
}

- (void)setupModeSegment
{
    self.modeSegment = [[UISegmentedControl alloc] initWithItems:@[
        L(@"123 & Basic"),
        L(@"Algebra"),
        L(@"Trig & Calc")
    ]];
    self.modeSegment.segmentedControlStyle = UISegmentedControlStyleBar;
    self.modeSegment.tintColor = [UIColor colorWithWhite:.5 alpha:1];
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
    self.rawTextField.frame = CGRectMake(10, 6, cardW - 80, 22);
    self.cursorLeftBtn.frame = CGRectMake(cardW - 68, 5, 28, 22);
    self.cursorRightBtn.frame = CGRectMake(cardW - 36, 5, 28, 22);

    self.mathPreviewLabel.frame = CGRectMake(10, 30, cardW - 20, cardH - 36);
    self.mathPreviewLabel.fontSize = compact ? 18.0f : 22.0f;
    self.previewHint.frame=self.mathPreviewLabel.frame;

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

    UIEdgeInsets insets = PMSafeAreaInsets(self.view);
    CGFloat contentH = CGRectGetMaxY(self.solveButton.frame) + margin + insets.bottom + 12.0f;
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
            UIButton *btn = [self.currentButtons objectAtIndex:btnIdx++];
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
        NSArray *rowKeys = [keys objectAtIndex:r];
        for (NSInteger c = 0; c < 5; c++) {
            NSString *key = [rowKeys objectAtIndex:c];

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

            // Add Long-Press Gesture Recognizer for popup alternatives (Photomath signature feature)
            UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(keyLongPressed:)];
            lp.minimumPressDuration = 0.35;
            [btn addGestureRecognizer:lp];

            [self.keypadContainer addSubview:btn];
            [self.currentButtons addObject:btn];
        }
    }

    [self.view setNeedsLayout];
}

#pragma mark - Long Press Alternatives

- (void)keyLongPressed:(UILongPressGestureRecognizer *)gesture
{
    if (gesture.state != UIGestureRecognizerStateBegan) return;

    UIButton *btn = (UIButton *)gesture.view;
    NSString *key = btn.accessibilityValue;
    if (!key.length) return;

    NSArray *alts = [self alternativesForKey:key];
    if (alts.count <= 1) return;

    NSMutableArray *titles = [NSMutableArray array];
    for (NSString *alt in alts) {
        [titles addObject:[self displayTitleForKey:alt]];
    }

    if (self.activeCallout) {
        [self.activeCallout dismissAnimated];
        self.activeCallout = nil;
    }

    self.activeCallout = [[PMKeyCalloutView alloc] initWithButton:btn
                                                          options:alts
                                                           titles:titles
                                                           inView:self.view];
    __weak typeof(self) weakSelf = self;
    self.activeCallout.onOptionSelected = ^(NSString *selectedKey) {
        [weakSelf insertKeyOrCommand:selectedKey];
    };
    [self.view addSubview:self.activeCallout];
    [self.activeCallout showAnimated];
}

- (NSArray *)alternativesForKey:(NSString *)key
{
    if ([key isEqualToString:@"\\sqrt{}"]) return @[ @"\\sqrt{}", @"\\sqrt[3]{}", @"\\sqrt[]{}" ];
    if ([key isEqualToString:@"x^2"]) return @[ @"x^2", @"x^3", @"x^4", @"x^{-1}", @"x^y" ];
    if ([key isEqualToString:@"x^y"]) return @[ @"x^y", @"x^2", @"x^3", @"x_y" ];
    if ([key isEqualToString:@"+"]) return @[ @"+", @"\\pm", @"\\mp" ];
    if ([key isEqualToString:@"-"]) return @[ @"-", @"\\pm", @"\\mp" ];
    if ([key isEqualToString:@"*"]) return @[ @"*", @"\\cdot", @"\\times" ];
    if ([key isEqualToString:@"/"]) return @[ @"/", @"\\frac{}{}", @"\\div" ];
    if ([key isEqualToString:@"="]) return @[ @"=", @"\\ne", @"\\approx", @"<", @">", @"\\le", @"\\ge" ];
    if ([key isEqualToString:@"<"]) return @[ @"<", @"\\le", @"\\ll" ];
    if ([key isEqualToString:@">"]) return @[ @">", @"\\ge", @"\\gg" ];
    if ([key isEqualToString:@"("]) return @[ @"(", @"[", @"\\{", @"|" ];
    if ([key isEqualToString:@")"]) return @[ @")", @"]", @"\\}", @"|" ];
    if ([key isEqualToString:@"x"]) return @[ @"x", @"y", @"z", @"a", @"b", @"c", @"t", @"n" ];
    if ([key isEqualToString:@"y"]) return @[ @"y", @"x", @"z", @"k" ];
    if ([key isEqualToString:@"z"]) return @[ @"z", @"x", @"y", @"w" ];
    if ([key isEqualToString:@"\\frac{}{}"]) return @[ @"\\frac{}{}", @"/", @"\\div" ];
    if ([key isEqualToString:@"|x|"]) return @[ @"|x|", @"\\lfloor x \\rfloor", @"\\lceil x \\rceil" ];
    if ([key isEqualToString:@"\\le"]) return @[ @"\\le", @"<", @"=" ];
    if ([key isEqualToString:@"\\ge"]) return @[ @"\\ge", @">", @"=" ];
    if ([key isEqualToString:@"\\pm"]) return @[ @"\\pm", @"+", @"-", @"\\mp" ];
    if ([key isEqualToString:@"\\pi"]) return @[ @"\\pi", @"e", @"i", @"\\infty" ];
    if ([key isEqualToString:@"e"]) return @[ @"e", @"e^x", @"\\pi" ];
    if ([key isEqualToString:@"["]) return @[ @"[", @"(", @"\\{", @"|" ];
    if ([key isEqualToString:@"]"]) return @[ @"]", @")", @"\\}", @"|" ];
    if ([key isEqualToString:@"\\sin"]) return @[ @"\\sin", @"\\arcsin", @"\\sinh" ];
    if ([key isEqualToString:@"\\cos"]) return @[ @"\\cos", @"\\arccos", @"\\cosh" ];
    if ([key isEqualToString:@"\\tan"]) return @[ @"\\tan", @"\\arctan", @"\\tanh" ];
    if ([key isEqualToString:@"\\arcsin"]) return @[ @"\\arcsin", @"\\sin", @"\\sinh" ];
    if ([key isEqualToString:@"\\arccos"]) return @[ @"\\arccos", @"\\cos", @"\\cosh" ];
    if ([key isEqualToString:@"\\arctan"]) return @[ @"\\arctan", @"\\tan", @"\\tanh" ];
    if ([key isEqualToString:@"\\log"]) return @[ @"\\log", @"\\log_{10}", @"\\log_2", @"\\ln" ];
    if ([key isEqualToString:@"\\ln"]) return @[ @"\\ln", @"\\log", @"e^x" ];
    if ([key isEqualToString:@"!"]) return @[ @"!", @"%", @"\\pmod" ];
    if ([key isEqualToString:@"\\infty"]) return @[ @"\\infty", @"\\pi", @"e" ];
    if ([key isEqualToString:@"\\int"]) return @[ @"\\int", @"\\int_{}^{}", @"\\iint" ];
    if ([key isEqualToString:@"\\sum"]) return @[ @"\\sum", @"\\sum_{}^{}", @"\\prod" ];
    if ([key isEqualToString:@"\\lim"]) return @[ @"\\lim", @"\\lim_{x \\to 0}", @"\\lim_{x \\to \\infty}" ];
    if ([key isEqualToString:@"\\frac{d}{dx}"]) return @[ @"\\frac{d}{dx}", @"\\frac{\\partial}{\\partial x}", @"\\int" ];
    if ([key isEqualToString:@"\\alpha"]) return @[ @"\\alpha", @"\\beta", @"\\gamma", @"\\theta", @"\\lambda", @"\\Delta" ];
    if ([key isEqualToString:@"\\beta"]) return @[ @"\\beta", @"\\alpha", @"\\theta" ];
    if ([key isEqualToString:@"\\theta"]) return @[ @"\\theta", @"\\phi", @"\\omega", @"\\alpha", @"\\beta" ];
    if ([key isEqualToString:@"."]) return @[ @".", @"," ];
    if ([key isEqualToString:@"0"]) return @[ @"0", @"^0", @"_0" ];
    if ([key isEqualToString:@"1"]) return @[ @"1", @"^1", @"_1", @"\\frac{1}{2}", @"\\frac{1}{4}" ];
    if ([key isEqualToString:@"2"]) return @[ @"2", @"^2", @"_2", @"\\frac{1}{2}" ];
    if ([key isEqualToString:@"3"]) return @[ @"3", @"^3", @"_3", @"\\frac{1}{3}" ];
    if ([key isEqualToString:@"4"]) return @[ @"4", @"^4", @"_4", @"\\frac{3}{4}" ];
    if ([key isEqualToString:@"5"]) return @[ @"5", @"^5", @"_5" ];
    if ([key isEqualToString:@"6"]) return @[ @"6", @"^6", @"_6" ];
    if ([key isEqualToString:@"7"]) return @[ @"7", @"^7", @"_7" ];
    if ([key isEqualToString:@"8"]) return @[ @"8", @"^8", @"_8" ];
    if ([key isEqualToString:@"9"]) return @[ @"9", @"^9", @"_9" ];
    if ([key isEqualToString:@"⌫"]) return @[ @"⌫", @"CLEAR_ALL" ];
    if ([key isEqualToString:@"C"]) return @[ @"C", @"CLEAR_ALL" ];
    return @[ key ];
}

- (NSString *)displayTitleForKey:(NSString *)key
{
    if ([key isEqualToString:@"*"]) return @"×";
    if ([key isEqualToString:@"/"]) return @"÷";
    if ([key isEqualToString:@"\\sqrt{}"]) return @"√";
    if ([key isEqualToString:@"\\sqrt[3]{}"]) return @"∛";
    if ([key isEqualToString:@"\\sqrt[]{}"]) return @"ⁿ√";
    if ([key isEqualToString:@"\\frac{}{}"]) return @"a/b";
    if ([key isEqualToString:@"x^2"]) return @"x²";
    if ([key isEqualToString:@"x^3"]) return @"x³";
    if ([key isEqualToString:@"x^4"]) return @"x⁴";
    if ([key isEqualToString:@"x^{-1}"]) return @"x⁻¹";
    if ([key isEqualToString:@"x^y"]) return @"xʸ";
    if ([key isEqualToString:@"x_y"]) return @"x_y";
    if ([key isEqualToString:@"|x|"]) return @"|x|";
    if ([key isEqualToString:@"\\lfloor x \\rfloor"]) return @"⌊x⌋";
    if ([key isEqualToString:@"\\lceil x \\rceil"]) return @"⌈x⌉";
    if ([key isEqualToString:@"\\pi"]) return @"π";
    if ([key isEqualToString:@"\\sin"]) return @"sin";
    if ([key isEqualToString:@"\\cos"]) return @"cos";
    if ([key isEqualToString:@"\\tan"]) return @"tan";
    if ([key isEqualToString:@"\\arcsin"]) return @"sin⁻¹";
    if ([key isEqualToString:@"\\arccos"]) return @"cos⁻¹";
    if ([key isEqualToString:@"\\arctan"]) return @"tan⁻¹";
    if ([key isEqualToString:@"\\sinh"]) return @"sinh";
    if ([key isEqualToString:@"\\cosh"]) return @"cosh";
    if ([key isEqualToString:@"\\tanh"]) return @"tanh";
    if ([key isEqualToString:@"\\log"]) return @"log";
    if ([key isEqualToString:@"\\log_{10}"]) return @"log₁₀";
    if ([key isEqualToString:@"\\log_2"]) return @"log₂";
    if ([key isEqualToString:@"\\ln"]) return @"ln";
    if ([key isEqualToString:@"e^x"]) return @"eˣ";
    if ([key isEqualToString:@"\\le"]) return @"≤";
    if ([key isEqualToString:@"\\ge"]) return @"≥";
    if ([key isEqualToString:@"\\ll"]) return @"≪";
    if ([key isEqualToString:@"\\gg"]) return @"≫";
    if ([key isEqualToString:@"\\ne"]) return @"≠";
    if ([key isEqualToString:@"\\approx"]) return @"≈";
    if ([key isEqualToString:@"\\pm"]) return @"±";
    if ([key isEqualToString:@"\\mp"]) return @"∓";
    if ([key isEqualToString:@"\\alpha"]) return @"α";
    if ([key isEqualToString:@"\\beta"]) return @"β";
    if ([key isEqualToString:@"\\theta"]) return @"θ";
    if ([key isEqualToString:@"\\phi"]) return @"φ";
    if ([key isEqualToString:@"\\omega"]) return @"ω";
    if ([key isEqualToString:@"\\Delta"]) return @"Δ";
    if ([key isEqualToString:@"\\lambda"]) return @"λ";
    if ([key isEqualToString:@"\\gamma"]) return @"γ";
    if ([key isEqualToString:@"\\sum"]) return @"∑";
    if ([key isEqualToString:@"\\int"]) return @"∫";
    if ([key isEqualToString:@"\\iint"]) return @"∬";
    if ([key isEqualToString:@"\\prod"]) return @"∏";
    if ([key isEqualToString:@"\\lim"]) return @"lim";
    if ([key isEqualToString:@"\\infty"]) return @"∞";
    if ([key isEqualToString:@"\\frac{d}{dx}"]) return @"d/dx";
    if ([key isEqualToString:@"CLEAR_ALL"]) return @"Clear All";
    if ([key isEqualToString:@"\\frac{1}{2}"]) return @"½";
    if ([key isEqualToString:@"\\frac{1}{4}"]) return @"¼";
    if ([key isEqualToString:@"\\frac{1}{3}"]) return @"⅓";
    if ([key isEqualToString:@"\\frac{3}{4}"]) return @"¾";
    if ([key isEqualToString:@"^0"]) return @"⁰";
    if ([key isEqualToString:@"^1"]) return @"¹";
    if ([key isEqualToString:@"^2"]) return @"²";
    if ([key isEqualToString:@"^3"]) return @"³";
    if ([key isEqualToString:@"_0"]) return @"₀";
    if ([key isEqualToString:@"_1"]) return @"₁";
    if ([key isEqualToString:@"_2"]) return @"₂";
    return key;
}

#pragma mark - Smart Math Text Insertion

- (void)keyTapped:(UIButton *)sender
{
    NSString *key = sender.accessibilityValue;
    [self insertKeyOrCommand:key];
}

- (void)insertKeyOrCommand:(NSString *)key
{
    if (!key.length || self.solving) return;
    [self syncSelection];

    if ([key isEqualToString:@"C"] || [key isEqualToString:@"CLEAR_ALL"]) {
        self.currentLatex = @"";
        self.cursorPosition = 0;
        [self updateMathPreview];
        return;
    }

    if ([key isEqualToString:@"⌫"]) {
        [self handleDelete];
        [self updateMathPreview];
        return;
    }

    // Exponentiation x^y
    if ([key isEqualToString:@"x^y"]) {
        BOOL hasBase = NO;
        if (self.cursorPosition > 0) {
            unichar prevC = [self.currentLatex characterAtIndex:self.cursorPosition - 1];
            if (PMMathBaseCharacter(prevC)) {
                hasBase = YES;
            }
        }
        if (hasBase) {
            [self insertText:@"^{}" cursorOffset:2];
        } else {
            [self insertText:@"x^{}" cursorOffset:3];
        }
        [self updateMathPreview];
        return;
    }

    if ([key isEqualToString:@"x_y"]) {
        [self insertText:@"_{}" cursorOffset:2];
        [self updateMathPreview];
        return;
    }

    // x^2
    if ([key isEqualToString:@"x^2"]) {
        BOOL hasBase = NO;
        if (self.cursorPosition > 0) {
            unichar prevC = [self.currentLatex characterAtIndex:self.cursorPosition - 1];
            if (PMMathBaseCharacter(prevC)) {
                hasBase = YES;
            }
        }
        if (hasBase) {
            [self insertText:@"^2" cursorOffset:2];
        } else {
            [self insertText:@"x^2" cursorOffset:3];
        }
        [self updateMathPreview];
        return;
    }

    // x^3
    if ([key isEqualToString:@"x^3"]) {
        BOOL hasBase = NO;
        if (self.cursorPosition > 0) {
            unichar prevC = [self.currentLatex characterAtIndex:self.cursorPosition - 1];
            if (PMMathBaseCharacter(prevC)) {
                hasBase = YES;
            }
        }
        if (hasBase) {
            [self insertText:@"^3" cursorOffset:2];
        } else {
            [self insertText:@"x^3" cursorOffset:3];
        }
        [self updateMathPreview];
        return;
    }

    // x^4
    if ([key isEqualToString:@"x^4"]) {
        BOOL hasBase = NO;
        if (self.cursorPosition > 0) {
            unichar prevC = [self.currentLatex characterAtIndex:self.cursorPosition - 1];
            if (PMMathBaseCharacter(prevC)) {
                hasBase = YES;
            }
        }
        if (hasBase) {
            [self insertText:@"^4" cursorOffset:2];
        } else {
            [self insertText:@"x^4" cursorOffset:3];
        }
        [self updateMathPreview];
        return;
    }

    // Square Root \sqrt{}
    if ([key isEqualToString:@"\\sqrt{}"]) {
        [self insertText:@"\\sqrt{}" cursorOffset:6];
        [self updateMathPreview];
        return;
    }

    // Cube Root \sqrt[3]{}
    if ([key isEqualToString:@"\\sqrt[3]{}"]) {
        [self insertText:@"\\sqrt[3]{}" cursorOffset:9];
        [self updateMathPreview];
        return;
    }

    // Nth Root \sqrt[]{}
    if ([key isEqualToString:@"\\sqrt[]{}"]) {
        [self insertText:@"\\sqrt[]{}" cursorOffset:6]; // Place cursor inside []
        [self updateMathPreview];
        return;
    }

    // Fraction \frac{}{}
    if ([key isEqualToString:@"\\frac{}{}"]) {
        [self insertText:@"\\frac{}{}" cursorOffset:6]; // Place cursor inside numerator
        [self updateMathPreview];
        return;
    }

    // Absolute value |x|
    if ([key isEqualToString:@"|x|"]) {
        [self insertText:@"| |" cursorOffset:1];
        [self updateMathPreview];
        return;
    }

    // Math Functions sin, cos, tan, log, ln
    if ([key isEqualToString:@"\\sin"] || [key isEqualToString:@"\\cos"] || [key isEqualToString:@"\\tan"] ||
        [key isEqualToString:@"\\arcsin"] || [key isEqualToString:@"\\arccos"] || [key isEqualToString:@"\\arctan"] ||
        [key isEqualToString:@"\\sinh"] || [key isEqualToString:@"\\cosh"] || [key isEqualToString:@"\\tanh"] ||
        [key isEqualToString:@"\\log"] || [key isEqualToString:@"\\ln"]) {
        NSString *cmd = [NSString stringWithFormat:@"%@()", key];
        [self insertText:cmd cursorOffset:cmd.length - 1]; // Place cursor inside ()
        [self updateMathPreview];
        return;
    }

    // Generic character insertion
    [self insertText:key cursorOffset:key.length];
    [self updateMathPreview];
}

- (void)insertText:(NSString *)text cursorOffset:(NSInteger)offset
{
    if (self.cursorPosition < 0) self.cursorPosition = 0;
    if (self.cursorPosition > self.currentLatex.length) self.cursorPosition = self.currentLatex.length;

    NSString *left = [self.currentLatex substringToIndex:self.cursorPosition];
    NSInteger length=MIN(self.selectedLength,(NSInteger)self.currentLatex.length-self.cursorPosition);
    NSString *right = [self.currentLatex substringFromIndex:self.cursorPosition+length];
    if(left.length+text.length+right.length>1024)return;
    self.selectedLength=0;
    self.currentLatex = [NSString stringWithFormat:@"%@%@%@", left, text, right];
    self.cursorPosition += offset;
}

- (void)handleDelete
{
    if(self.selectedLength>0) { [self insertText:@"" cursorOffset:0];return; }
    if (self.cursorPosition <= 0 || self.currentLatex.length == 0) return;

    NSString *left = [self.currentLatex substringToIndex:self.cursorPosition];
    NSString *right = [self.currentLatex substringFromIndex:self.cursorPosition];

    if([left hasSuffix:@"\\frac{"] && [right hasPrefix:@"}{}"]) {
        self.currentLatex=[[left substringToIndex:left.length-6] stringByAppendingString:[right substringFromIndex:3]];self.cursorPosition-=6;return;
    }
    // Check if cursor is right after ^{ and followed by }
    if ([left hasSuffix:@"^{"] && [right hasPrefix:@"}"]) {
        left = [left substringToIndex:left.length - 2];
        right = [right substringFromIndex:1];
        self.cursorPosition -= 2;
        self.currentLatex = [left stringByAppendingString:right];
        return;
    }

    // Check if cursor is right after \sqrt{ and followed by }
    if ([left hasSuffix:@"\\sqrt{"] && [right hasPrefix:@"}"]) {
        left = [left substringToIndex:left.length - 6];
        right = [right substringFromIndex:1];
        self.cursorPosition -= 6;
        self.currentLatex = [left stringByAppendingString:right];
        return;
    }

    // Single character deletion
    left = [left substringToIndex:left.length - 1];
    self.cursorPosition--;
    self.currentLatex = [left stringByAppendingString:right];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (self.activeCallout) {
        [self.activeCallout dismissAnimated];
        self.activeCallout = nil;
    }
}

- (void)updateMathPreview
{
    if (self.cursorPosition < 0) self.cursorPosition = 0;
    if (self.cursorPosition > self.currentLatex.length) self.cursorPosition = self.currentLatex.length;

    self.rawTextField.text = self.currentLatex;

    // Set cursor position in rawTextField
    UITextPosition *pos = [self.rawTextField positionFromPosition:self.rawTextField.beginningOfDocument offset:self.cursorPosition];
    if (pos) {
        self.rawTextField.selectedTextRange = [self.rawTextField textRangeFromPosition:pos toPosition:pos];
    }

    self.selectedLength=0;
    // A small atomic file survives immediate process exit; preferences may defer disk writes on iOS 5/6.
    [(self.currentLatex ?: @"") writeToFile:[[PMUtils historyPath] stringByAppendingPathComponent:@"draft.txt"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    NSString *preview=[PMMathEditing previewForLatex:self.currentLatex];
    @try { self.mathPreviewLabel.latex=preview; }
    @catch(NSException *exception) { self.mathPreviewLabel.latex=@""; }
    self.previewHint.hidden=!self.mathPreviewLabel.error;
    self.mathPreviewLabel.hidden=!self.previewHint.hidden;
    [self.mathPreviewLabel setNeedsLayout];[self.mathPreviewLabel setNeedsDisplay];
}

- (void)solveTapped:(id)sender
{
    if(self.solving)return;
    if (!self.currentLatex.length) {
        [PMUtils alertWithTitle:L(@"Empty Problem") message:L(@"Please type a mathematical problem first.")];
        return;
    }
    if (self.onSolveRequested) {
        [self.rawTextField resignFirstResponder];
        self.onSolveRequested(self.currentLatex);
    }
}

@end
