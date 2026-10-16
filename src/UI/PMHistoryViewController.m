#import "PMHistoryViewController.h"
#import "PMSolutionViewController.h"
#import "PMHistoryStore.h"
#import "PMTheme.h"
#import "PMCommon.h"
#import "PMUtils.h"
#import "PMSettings.h"

@interface PMHistoryViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
@end

@implementation PMHistoryViewController

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.title = L(@"History");
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    [self.tableView reloadData];
    [self updateEmptyState];
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
    [[PMTheme shared] applyToTableView:self.tableView];
    [self.view addSubview:self.tableView];

    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 120, self.view.bounds.size.width - 40, 60)];
    self.emptyLabel.text = L(@"No solved problems yet.\nScan an equation with the camera or use the math editor.");
    self.emptyLabel.numberOfLines = 2;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.textColor = [UIColor grayColor];
    self.emptyLabel.font = [UIFont systemFontOfSize:14.0f];
    self.emptyLabel.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.emptyLabel];

    self.navigationItem.rightBarButtonItem = self.editButtonItem;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(historyChanged:)
                                                 name:PMHistoryDidChangeNotification
                                               object:nil];
    [self updateEmptyState];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)historyChanged:(NSNotification *)note
{
    [self.tableView reloadData];
    [self updateEmptyState];
}

- (void)updateEmptyState
{
    BOOL empty = [PMHistoryStore shared].solutions.count == 0;
    self.emptyLabel.hidden = !empty;
    self.tableView.hidden = empty;
    self.navigationItem.rightBarButtonItem.enabled = !empty;
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    [self.tableView setEditing:editing animated:animated];
}

#pragma mark - Table View Data Source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [PMHistoryStore shared].solutions.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 66.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellId = @"PMHistoryCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellId];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    PMMathSolution *sol = [PMHistoryStore shared].solutions[indexPath.row];
    BOOL isDark = [PMSettings shared].darkTheme;

    cell.textLabel.text = sol.problemLatex.length ? sol.problemLatex : @"(Equation)";
    cell.textLabel.font = [UIFont boldSystemFontOfSize:15.0f];
    cell.textLabel.textColor = isDark ? [UIColor whiteColor] : [UIColor colorWithRed:0.15f green:0.18f blue:0.24f alpha:1.0f];

    NSString *sub = [NSString stringWithFormat:@"%@ = %@  •  %@", L(@"Result"), sol.solutionLatex ?: @"?", [PMUtils shortDateString:sol.date]];
    cell.detailTextLabel.text = sub;
    cell.detailTextLabel.textColor = isDark ? [UIColor colorWithWhite:0.65f alpha:1.0f] : [UIColor colorWithRed:0.45f green:0.48f blue:0.55f alpha:1.0f];

    UIImage *thumb = [sol loadImage];
    if (thumb) {
        cell.imageView.image = thumb;
        cell.imageView.layer.cornerRadius = 4.0f;
        cell.imageView.layer.masksToBounds = YES;
    } else {
        cell.imageView.image = [[PMTheme shared] circleBadgeImageWithNumber:(indexPath.row + 1) size:32.0f];
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    PMMathSolution *sol = [PMHistoryStore shared].solutions[indexPath.row];
    PMSolutionViewController *svc = [[PMSolutionViewController alloc] initWithSolution:sol];
    [self.navigationController pushViewController:svc animated:YES];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        PMMathSolution *sol = [PMHistoryStore shared].solutions[indexPath.row];
        [[PMHistoryStore shared] removeSolution:sol];
    }
}

@end
