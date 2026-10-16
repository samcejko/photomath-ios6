#import "PMModelPickerViewController.h"
#import "PMModelCatalog.h"
#import "PMSettings.h"
#import "PMTheme.h"
#import "PMCommon.h"

@interface PMModelPickerViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSArray *filteredModels;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation PMModelPickerViewController

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.title = L(@"Vision Models");
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[PMTheme shared] applyToNavigationBar:self.navigationController.navigationBar];
    self.view.backgroundColor = [[PMTheme shared] backgroundColor];

    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = L(@"Search models...");
    self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.tableHeaderView = self.searchBar;
    [[PMTheme shared] applyToTableView:self.tableView];
    [self.view addSubview:self.tableView];

    UIBarButtonItem *refreshBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                 target:self
                                                                                 action:@selector(refreshTapped:)];
    self.navigationItem.rightBarButtonItem = refreshBtn;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(modelsUpdated:)
                                                 name:PMModelsDidUpdateNotification
                                               object:nil];

    [self reloadFilteredList];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)modelsUpdated:(NSNotification *)note
{
    [self.spinner stopAnimating];
    self.navigationItem.rightBarButtonItem.enabled = YES;
    [self reloadFilteredList];
}

- (void)reloadFilteredList
{
    NSArray *all = [[PMModelCatalog shared] validVisionModels];
    NSString *q = [self.searchBar.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (q.length) {
        NSMutableArray *res = [NSMutableArray array];
        for (PMModelInfo *m in all) {
            if ([m.name rangeOfString:q options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [m.modelId rangeOfString:q options:NSCaseInsensitiveSearch].location != NSNotFound) {
                [res addObject:m];
            }
        }
        self.filteredModels = res;
    } else {
        self.filteredModels = all;
    }
    [self.tableView reloadData];
}

- (void)refreshTapped:(id)sender
{
    self.navigationItem.rightBarButtonItem.enabled = NO;
    if (!self.spinner) {
        self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.spinner];
    }
    [self.spinner startAnimating];
    [[PMModelCatalog shared] refreshWithCompletion:^(NSError *error) {
        PMMain(^{
            [self.spinner stopAnimating];
            UIBarButtonItem *btn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                 target:self
                                                                                 action:@selector(refreshTapped:)];
            self.navigationItem.rightBarButtonItem = btn;
            [self reloadFilteredList];
        });
    }];
}

#pragma mark - Search Bar

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self reloadFilteredList];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) return 1; // Automatic
    return self.filteredModels.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0) return L(@"Default");
    return [NSString stringWithFormat:L(@"Available Vision Models (%lu)"), (unsigned long)self.filteredModels.count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellId = @"PMModelCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellId];
    }

    NSString *selectedId = [PMSettings shared].preferredModelId;

    if (indexPath.section == 0) {
        cell.textLabel.text = L(@"Automatic (Recommended)");
        PMModelInfo *best = [[PMModelCatalog shared] bestVisionModel];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@: %@", L(@"Uses best live model"), best ? best.displayName : L(@"Auto")];
        cell.accessoryType = (!selectedId.length) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        return cell;
    }

    PMModelInfo *m = self.filteredModels[indexPath.row];
    cell.textLabel.text = [m displayName];
    NSString *price = [m isFree] ? L(@"FREE") : [NSString stringWithFormat:@"$%@ / 1M", m.promptPrice ?: @"?"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@  •  %@  •  %ldk ctx", m.modelId, price, (long)(m.contextLength / 1024)];
    cell.accessoryType = [selectedId isEqualToString:m.modelId] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) {
        [PMSettings shared].preferredModelId = nil;
    } else {
        PMModelInfo *m = self.filteredModels[indexPath.row];
        [PMSettings shared].preferredModelId = m.modelId;
    }
    [self.tableView reloadData];
    [self.navigationController popViewControllerAnimated:YES];
}

@end
