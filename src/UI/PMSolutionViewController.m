#import "PMSolutionViewController.h"
#import "PMStepCell.h"
#import "PMTheme.h"
#import "PMCommon.h"
#import "PMSettings.h"
#import "PMUtils.h"
#import "MTMathUILabel.h"
#import <QuartzCore/QuartzCore.h>

@interface PMSolutionViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) PMMathSolution *solution;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) MTMathUILabel *problemMathLabel;
@property (nonatomic, strong) MTMathUILabel *resultMathLabel;
@property (nonatomic, strong) UILabel *summaryLabel;
@property (nonatomic, strong) UIImageView *thumbnailView;
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
    [[PMTheme shared] applyToTableView:self.tableView];

    [self setupHeaderView];
    [self setupFooterView];
    [self.view addSubview:self.tableView];

    // Right bar button: Copy
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
    UIView *problemCard = [[UIView alloc] initWithFrame:CGRectMake(10, 10, w - 20, 85)];
    problemCard.backgroundColor = isDark ? [UIColor colorWithWhite:0.18f alpha:1.0f] : [UIColor whiteColor];
    problemCard.layer.cornerRadius = 8.0f;
    problemCard.layer.borderWidth = 1.0f;
    problemCard.layer.borderColor = isDark ? [UIColor colorWithWhite:0.28f alpha:1.0f].CGColor : [UIColor colorWithRed:0.86f green:0.88f blue:0.92f alpha:1.0f].CGColor;
    [header addSubview:problemCard];

    UILabel *probHeader = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, 120, 18)];
    probHeader.text = [L(@"PROBLEM") uppercaseString];
    probHeader.font = [UIFont boldSystemFontOfSize:11.0f];
    probHeader.textColor = isDark ? [UIColor colorWithWhite:0.6f alpha:1.0f] : [UIColor colorWithWhite:0.45f alpha:1.0f];
    probHeader.backgroundColor = [UIColor clearColor];
    [problemCard addSubview:probHeader];

    UIButton *editBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    editBtn.frame = CGRectMake(w - 20 - 75, 6, 65, 22);
    [editBtn setTitle:L(@"Edit") forState:UIControlStateNormal];
    [editBtn setTitleColor:[[PMTheme shared] accentColor] forState:UIControlStateNormal];
    editBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13.0f];
    [editBtn addTarget:self action:@selector(editProblemTapped:) forControlEvents:UIControlEventTouchUpInside];
    [problemCard addSubview:editBtn];

    self.problemMathLabel = [[MTMathUILabel alloc] initWithFrame:CGRectMake(12, 30, w - 44, 45)];
    self.problemMathLabel.labelMode = kMTMathUILabelModeDisplay;
    self.problemMathLabel.fontSize = 20.0f;
    self.problemMathLabel.textColor = isDark ? [UIColor whiteColor] : [UIColor colorWithRed:0.10f green:0.12f blue:0.18f alpha:1.0f];
    self.problemMathLabel.latex = self.solution.problemLatex.length ? self.solution.problemLatex : @"?";
    [problemCard addSubview:self.problemMathLabel];

    // Bottom Card: Result banner
    UIView *resultCard = [[UIView alloc] initWithFrame:CGRectMake(10, 105, w - 20, 85)];
    resultCard.backgroundColor = isDark ? [UIColor colorWithRed:0.15f green:0.28f blue:0.18f alpha:1.0f] : [UIColor colorWithRed:0.92f green:0.98f blue:0.92f alpha:1.0f];
    resultCard.layer.cornerRadius = 8.0f;
    resultCard.layer.borderWidth = 1.0f;
    resultCard.layer.borderColor = [UIColor colorWithRed:0.35f green:0.75f blue:0.40f alpha:0.7f].CGColor;
    [header addSubview:resultCard];

    UILabel *resHeader = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, 120, 18)];
    resHeader.text = [L(@"RESULT") uppercaseString];
    resHeader.font = [UIFont boldSystemFontOfSize:11.0f];
    resHeader.textColor = [UIColor colorWithRed:0.20f green:0.60f blue:0.25f alpha:1.0f];
    resHeader.backgroundColor = [UIColor clearColor];
    [resultCard addSubview:resHeader];

    self.resultMathLabel = [[MTMathUILabel alloc] initWithFrame:CGRectMake(12, 28, w - 44, 48)];
    self.resultMathLabel.labelMode = kMTMathUILabelModeDisplay;
    self.resultMathLabel.fontSize = 24.0f;
    self.resultMathLabel.textColor = [UIColor colorWithRed:0.12f green:0.55f blue:0.20f alpha:1.0f];
    self.resultMathLabel.latex = self.solution.solutionLatex.length ? self.solution.solutionLatex : @"";
    [resultCard addSubview:self.resultMathLabel];

    // Steps Section Header Label
    UILabel *stepsTitle = [[UILabel alloc] initWithFrame:CGRectMake(14, 202, w - 28, 26)];
    stepsTitle.text = [NSString stringWithFormat:@"%@ (%lu)", L(@"Step-by-Step Solution"), (unsigned long)self.solution.steps.count];
    stepsTitle.font = [UIFont boldSystemFontOfSize:15.0f];
    stepsTitle.textColor = isDark ? [UIColor whiteColor] : [UIColor colorWithRed:0.20f green:0.22f blue:0.28f alpha:1.0f];
    stepsTitle.backgroundColor = [UIColor clearColor];
    [header addSubview:stepsTitle];

    self.headerView = header;
    self.tableView.tableHeaderView = header;
}

- (void)setupFooterView
{
    CGFloat w = self.view.bounds.size.width;
    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 110)];
    footer.backgroundColor = [UIColor clearColor];

    BOOL isDark = [PMSettings shared].darkTheme;

    // Model used info
    UILabel *modelLbl = [[UILabel alloc] initWithFrame:CGRectMake(14, 8, w - 28, 20)];
    modelLbl.font = [UIFont systemFontOfSize:11.0f];
    modelLbl.textColor = isDark ? [UIColor colorWithWhite:0.5f alpha:1.0f] : [UIColor colorWithWhite:0.45f alpha:1.0f];
    modelLbl.text = [NSString stringWithFormat:@"%@: %@", L(@"Solved by model"), self.solution.modelUsed.length ? self.solution.modelUsed : @"OpenRouter"];
    modelLbl.backgroundColor = [UIColor clearColor];
    modelLbl.textAlignment = NSTextAlignmentCenter;
    [footer addSubview:modelLbl];

    // Copy Button
    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    copyBtn.frame = CGRectMake(15, 34, w - 30, 40);
    UIImage *btnBg = [[PMTheme shared] glossyButtonImageWithColor:[[PMTheme shared] accentColor] highlighted:NO];
    [copyBtn setBackgroundImage:btnBg forState:UIControlStateNormal];
    [copyBtn setTitle:L(@"Copy Solution to Clipboard") forState:UIControlStateNormal];
    [copyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    copyBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15.0f];
    copyBtn.titleLabel.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.4f];
    copyBtn.titleLabel.shadowOffset = CGSizeMake(0, -1);
    [copyBtn addTarget:self action:@selector(copyAction:) forControlEvents:UIControlEventTouchUpInside];
    [footer addSubview:copyBtn];

    self.tableView.tableFooterView = footer;
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
    PMStep *step = self.solution.steps[indexPath.row];
    return [PMStepCell heightForStep:step width:self.view.bounds.size.width isDark:[PMSettings shared].darkTheme];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellId = @"PMStepCell";
    PMStepCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[PMStepCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellId];
    }
    PMStep *step = self.solution.steps[indexPath.row];
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
