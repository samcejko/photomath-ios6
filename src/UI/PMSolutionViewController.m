#import "PMSolutionViewController.h"
#import "PMStepCell.h"
#import "PMTheme.h"
#import "PMCommon.h"
#import "PMSettings.h"
#import "PMUtils.h"
#import "PMModern.h"
#import "MTMathUILabel.h"
#import <QuartzCore/QuartzCore.h>

@interface PMSolutionViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) PMMathSolution *solution;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UIView *problemCard;
@property (nonatomic, strong) UIButton *editButton;
@property (nonatomic, strong) MTMathUILabel *problemMathLabel;
@property (nonatomic, strong) UIView *resultCard;
@property (nonatomic, strong) MTMathUILabel *resultMathLabel;
@property (nonatomic, strong) UILabel *stepsTitle;
@property (nonatomic, strong) UIView *footerView;
@property (nonatomic, strong) UILabel *modelLabel;
@property (nonatomic, strong) UIButton *clipboardButton;
@end

@implementation PMSolutionViewController

- (instancetype)initWithSolution:(PMMathSolution *)solution
{
    self = [super init];
    if (self) {
        _solution = solution;
        self.title = L(@"Solution");
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[PMTheme shared] applyToNavigationBar:self.navigationController.navigationBar];

    self.view.backgroundColor = [[PMTheme shared] backgroundColor];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    PMModernKeepScrollViewInsets(self.tableView);
    [[PMTheme shared] applyToTableView:self.tableView];

    [self setupHeaderView];
    [self setupFooterView];
    [self.view addSubview:self.tableView];

    UIBarButtonItem *copyBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                             target:self
                                                                             action:@selector(copyAction:)];
    self.navigationItem.rightBarButtonItem = copyBtn;
}

- (void)setupHeaderView
{
    CGFloat w = self.view.bounds.size.width;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 240)];
    header.backgroundColor = [UIColor clearColor];

    BOOL isDark = [PMSettings shared].darkTheme;

    // Top Card: Problem
    self.problemCard = [[UIView alloc] initWithFrame:CGRectMake(10, 10, w - 20, 85)];
    self.problemCard.backgroundColor = isDark ? [UIColor colorWithWhite:0.18f alpha:1.0f] : [UIColor whiteColor];
    self.problemCard.layer.cornerRadius = 8.0f;
    self.problemCard.layer.borderWidth = 1.0f;
    self.problemCard.layer.borderColor = isDark ? [UIColor colorWithWhite:0.28f alpha:1.0f].CGColor : [UIColor colorWithRed:0.86f green:0.88f blue:0.92f alpha:1.0f].CGColor;
    [header addSubview:self.problemCard];

    UILabel *probHeader = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, 120, 18)];
    probHeader.text = [L(@"PROBLEM") uppercaseString];
    probHeader.font = [UIFont boldSystemFontOfSize:11.0f];
    probHeader.textColor = isDark ? [UIColor colorWithWhite:0.6f alpha:1.0f] : [UIColor colorWithWhite:0.45f alpha:1.0f];
    probHeader.backgroundColor = [UIColor clearColor];
    [self.problemCard addSubview:probHeader];

    self.editButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.editButton.frame = CGRectMake(w - 20 - 75, 6, 65, 22);
    [self.editButton setTitle:L(@"Edit") forState:UIControlStateNormal];
    [self.editButton setTitleColor:[[PMTheme shared] accentColor] forState:UIControlStateNormal];
    self.editButton.titleLabel.font = [UIFont boldSystemFontOfSize:13.0f];
    [self.editButton addTarget:self action:@selector(editProblemTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.problemCard addSubview:self.editButton];

    self.problemMathLabel = [[MTMathUILabel alloc] initWithFrame:CGRectMake(12, 30, w - 44, 45)];
    self.problemMathLabel.labelMode = kMTMathUILabelModeDisplay;
    self.problemMathLabel.fontSize = 20.0f;
    self.problemMathLabel.textColor = isDark ? [UIColor whiteColor] : [UIColor colorWithRed:0.10f green:0.12f blue:0.18f alpha:1.0f];
    self.problemMathLabel.latex = self.solution.problemLatex.length ? self.solution.problemLatex : @"?";
    [self.problemCard addSubview:self.problemMathLabel];

    // Bottom Card: Result banner
    self.resultCard = [[UIView alloc] initWithFrame:CGRectMake(10, 105, w - 20, 85)];
    self.resultCard.backgroundColor = isDark ? [UIColor colorWithRed:0.15f green:0.28f blue:0.18f alpha:1.0f] : [UIColor colorWithRed:0.92f green:0.98f blue:0.92f alpha:1.0f];
    self.resultCard.layer.cornerRadius = 8.0f;
    self.resultCard.layer.borderWidth = 1.0f;
    self.resultCard.layer.borderColor = [UIColor colorWithRed:0.35f green:0.75f blue:0.40f alpha:0.7f].CGColor;
    [header addSubview:self.resultCard];

    UILabel *resHeader = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, 120, 18)];
    resHeader.text = [L(@"RESULT") uppercaseString];
    resHeader.font = [UIFont boldSystemFontOfSize:11.0f];
    resHeader.textColor = [UIColor colorWithRed:0.20f green:0.60f blue:0.25f alpha:1.0f];
    resHeader.backgroundColor = [UIColor clearColor];
    [self.resultCard addSubview:resHeader];

    self.resultMathLabel = [[MTMathUILabel alloc] initWithFrame:CGRectMake(12, 28, w - 44, 48)];
    self.resultMathLabel.labelMode = kMTMathUILabelModeDisplay;
    self.resultMathLabel.fontSize = 24.0f;
    self.resultMathLabel.textColor = [UIColor colorWithRed:0.12f green:0.55f blue:0.20f alpha:1.0f];
    self.resultMathLabel.latex = self.solution.solutionLatex.length ? self.solution.solutionLatex : @"";
    [self.resultCard addSubview:self.resultMathLabel];

    // Steps Section Header Label
    self.stepsTitle = [[UILabel alloc] initWithFrame:CGRectMake(14, 202, w - 28, 26)];
    self.stepsTitle.text = [NSString stringWithFormat:@"%@ (%lu)", L(@"Step-by-Step Solution"), (unsigned long)self.solution.steps.count];
    self.stepsTitle.font = [UIFont boldSystemFontOfSize:15.0f];
    self.stepsTitle.textColor = isDark ? [UIColor whiteColor] : [UIColor colorWithRed:0.20f green:0.22f blue:0.28f alpha:1.0f];
    self.stepsTitle.backgroundColor = [UIColor clearColor];
    [header addSubview:self.stepsTitle];

    self.headerView = header;
    self.tableView.tableHeaderView = header;
}

- (void)setupFooterView
{
    CGFloat w = self.view.bounds.size.width;
    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 110)];
    footer.backgroundColor = [UIColor clearColor];

    BOOL isDark = [PMSettings shared].darkTheme;

    self.modelLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 8, w - 28, 20)];
    self.modelLabel.font = [UIFont systemFontOfSize:11.0f];
    self.modelLabel.textColor = isDark ? [UIColor colorWithWhite:0.5f alpha:1.0f] : [UIColor colorWithWhite:0.45f alpha:1.0f];
    self.modelLabel.text = [NSString stringWithFormat:@"%@: %@", L(@"Solved by model"), self.solution.modelUsed.length ? self.solution.modelUsed : @"OpenRouter"];
    self.modelLabel.backgroundColor = [UIColor clearColor];
    self.modelLabel.textAlignment = UITextAlignmentCenter;
    [footer addSubview:self.modelLabel];

    self.clipboardButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.clipboardButton.frame = CGRectMake(15, 34, w - 30, 40);
    UIImage *btnBg = [[PMTheme shared] glossyButtonImageWithColor:[[PMTheme shared] accentColor] highlighted:NO];
    [self.clipboardButton setBackgroundImage:btnBg forState:UIControlStateNormal];
    [self.clipboardButton setTitle:L(@"Copy Solution to Clipboard") forState:UIControlStateNormal];
    [self.clipboardButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.clipboardButton.titleLabel.font = [UIFont boldSystemFontOfSize:15.0f];
    self.clipboardButton.titleLabel.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.4f];
    self.clipboardButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
    [self.clipboardButton addTarget:self action:@selector(copyAction:) forControlEvents:UIControlEventTouchUpInside];
    [footer addSubview:self.clipboardButton];

    self.footerView = footer;
    self.tableView.tableFooterView = footer;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    CGFloat w = self.tableView.bounds.size.width;
    if (w <= 0) return;

    if (self.headerView && fabs(self.headerView.frame.size.width - w) > 1.0f) {
        self.headerView.frame = CGRectMake(0, 0, w, 240);
        self.problemCard.frame = CGRectMake(10, 10, w - 20, 85);
        self.editButton.frame = CGRectMake(w - 20 - 75, 6, 65, 22);
        self.problemMathLabel.frame = CGRectMake(12, 30, w - 44, 45);

        self.resultCard.frame = CGRectMake(10, 105, w - 20, 85);
        self.resultMathLabel.frame = CGRectMake(12, 28, w - 44, 48);

        self.stepsTitle.frame = CGRectMake(14, 202, w - 28, 26);
        self.tableView.tableHeaderView = self.headerView;
    }

    if (self.footerView && fabs(self.footerView.frame.size.width - w) > 1.0f) {
        self.footerView.frame = CGRectMake(0, 0, w, 110);
        self.modelLabel.frame = CGRectMake(14, 8, w - 28, 20);
        self.clipboardButton.frame = CGRectMake(15, 34, w - 30, 40);
        self.tableView.tableFooterView = self.footerView;
    }
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.solution.steps.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PMStep *step = [self.solution.steps objectAtIndex:indexPath.row];
    CGFloat w = tableView.bounds.size.width;
    if (w <= 0) w = self.view.bounds.size.width;
    if (w <= 0) w = 320.0f;
    return [PMStepCell heightForStep:step width:w isDark:[PMSettings shared].darkTheme];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellId = @"PMStepCell";
    PMStepCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[PMStepCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellId];
    }
    PMStep *step = [self.solution.steps objectAtIndex:indexPath.row];
    [cell configureWithStep:step isDark:[PMSettings shared].darkTheme];
    return cell;
}

#pragma mark - Actions

- (void)editProblemTapped:(id)sender
{
    if (self.onEditProblemRequested) {
        self.onEditProblemRequested(self.solution.problemLatex);
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)copyAction:(id)sender
{
    NSMutableString *fullText = [NSMutableString string];
    [fullText appendFormat:@"Problem: %@\n", self.solution.problemLatex ?: @""];
    [fullText appendFormat:@"Result: %@\n\n", self.solution.solutionLatex ?: @""];
    [fullText appendString:@"Steps:\n"];

    for (PMStep *s in self.solution.steps) {
        [fullText appendFormat:@"%ld. %@\n   LaTeX: %@\n   %@\n\n", (long)s.stepNumber, s.title, s.latex, s.explanation];
    }

    [UIPasteboard generalPasteboard].string = fullText;
    [PMUtils alertWithTitle:L(@"Copied") message:L(@"Solution and steps copied to clipboard.")];
}

@end
