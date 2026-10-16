#import "PMSettingsViewController.h"
#import "PMAPIKeyViewController.h"
#import "PMModelPickerViewController.h"
#import "PMSettings.h"
#import "PMModelCatalog.h"
#import "PMTheme.h"
#import "PMCommon.h"
#import "PMUtils.h"

enum {
    PMSectionAccount = 0,
    PMSectionSolver,
    PMSectionAppearance,
    PMSectionAbout,
    PMSectionCount
};

@interface PMSettingsViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation PMSettingsViewController

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.title = L(@"Settings");
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[PMTheme shared] applyToNavigationBar:self.navigationController.navigationBar];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];

    UIBarButtonItem *doneBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                             target:self
                                                                             action:@selector(doneTapped:)];
    self.navigationItem.rightBarButtonItem = doneBtn;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(settingsChanged:)
                                                 name:PMSettingsDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(settingsChanged:)
                                                 name:PMAPIKeyDidChangeNotification
                                               object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (void)doneTapped:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)settingsChanged:(NSNotification *)note
{
    [self.tableView reloadData];
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return PMSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case PMSectionAccount: return [PMSettings hasAIChatAPIKey] ? 2 : 1;
        case PMSectionSolver: return 4;
        case PMSectionAppearance: return 2;
        case PMSectionAbout: return 3;
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case PMSectionAccount: return L(@"OpenRouter Account");
        case PMSectionSolver: return L(@"Math Solver & Models");
        case PMSectionAppearance: return L(@"Appearance & Security");
        case PMSectionAbout: return L(@"About ShutterCalc");
        default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == PMSectionSolver) {
        return L(@"Dynamic fallback automatically tries the next available vision model in the OpenRouter catalog if a model fails or hits rate limits, strictly avoiding content-safety models.");
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellVal1 = @"CellVal1";
    static NSString *CellDefault = @"CellDefault";

    if (indexPath.section == PMSectionAccount) {
        if (indexPath.row == 0) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellVal1];
            if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellVal1];
            cell.textLabel.text = L(@"API Key");
            NSString *k = [PMSettings shared].apiKey;
            if (k.length > 8) {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@…%@", [k substringToIndex:6], [k substringFromIndex:k.length - 4]];
            } else if (k.length) {
                cell.detailTextLabel.text = L(@"Configured");
            } else {
                cell.detailTextLabel.text = L(@"Not Set");
            }
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return cell;
        } else {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellVal1];
            if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellVal1];
            cell.textLabel.text = L(@"Import from AI Chat");
            cell.detailTextLabel.text = L(@"Found");
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return cell;
        }
    }

    if (indexPath.section == PMSectionSolver) {
        if (indexPath.row == 0) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellVal1];
            if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellVal1];
            cell.textLabel.text = L(@"Primary Model");
            NSString *pref = [PMSettings shared].preferredModelId;
            PMModelInfo *m = [[PMModelCatalog shared] modelWithId:pref];
            cell.detailTextLabel.text = m ? m.displayName : (pref.length ? pref : L(@"Auto (Live)"));
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return cell;
        } else if (indexPath.row == 1) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellDefault];
            if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellDefault];
            cell.textLabel.text = L(@"Auto Fallback on Error");
            UISwitch *sw = [[UISwitch alloc] init];
            sw.on = [PMSettings shared].autoFallback;
            [sw addTarget:self action:@selector(fallbackSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        } else if (indexPath.row == 2) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellDefault];
            if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellDefault];
            cell.textLabel.text = L(@"Only Free Models");
            UISwitch *sw = [[UISwitch alloc] init];
            sw.on = [PMSettings shared].freeOnly;
            [sw addTarget:self action:@selector(freeOnlySwitchChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        } else if (indexPath.row == 3) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellDefault];
            if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellDefault];
            cell.textLabel.text = L(@"Show Steps by Default");
            UISwitch *sw = [[UISwitch alloc] init];
            sw.on = [PMSettings shared].showStepByStep;
            [sw addTarget:self action:@selector(stepsSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        }
    }

    if (indexPath.section == PMSectionAppearance) {
        if (indexPath.row == 0) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellDefault];
            if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellDefault];
            cell.textLabel.text = L(@"Dark Theme");
            UISwitch *sw = [[UISwitch alloc] init];
            sw.on = [PMSettings shared].darkTheme;
            [sw addTarget:self action:@selector(darkThemeSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        } else if (indexPath.row == 1) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellDefault];
            if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellDefault];
            cell.textLabel.text = L(@"Verify TLS Certificates");
            UISwitch *sw = [[UISwitch alloc] init];
            sw.on = [PMSettings shared].verifyTLS;
            [sw addTarget:self action:@selector(tlsSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        }
    }

    if (indexPath.section == PMSectionAbout) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellVal1];
        if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellVal1];
        if (indexPath.row == 0) {
            cell.textLabel.text = L(@"Version");
            cell.detailTextLabel.text = @"1.0.0 (iOS 6)";
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;
        } else if (indexPath.row == 1) {
            cell.textLabel.text = L(@"Developer");
            cell.detailTextLabel.text = @"samcejko";
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;
        } else if (indexPath.row == 2) {
            cell.textLabel.text = L(@"Cydia Repository");
            cell.detailTextLabel.text = @"repo.samcejko.eu";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        return cell;
    }

    return [[UITableViewCell alloc] init];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == PMSectionAccount) {
        if (indexPath.row == 0) {
            PMAPIKeyViewController *kvc = [[PMAPIKeyViewController alloc] init];
            [self.navigationController pushViewController:kvc animated:YES];
        } else if (indexPath.row == 1) {
            NSString *k = [PMSettings availableAIChatAPIKey];
            if (k.length) {
                [PMSettings shared].apiKey = k;
                [tableView reloadData];
                [PMUtils alertWithTitle:L(@"API Key") message:L(@"Key imported from AI Chat and verified!")];
            } else {
                [PMUtils alertWithTitle:L(@"API Key") message:L(@"No API key found in AI Chat.")];
            }
        }
    } else if (indexPath.section == PMSectionSolver && indexPath.row == 0) {
        PMModelPickerViewController *mpvc = [[PMModelPickerViewController alloc] init];
        [self.navigationController pushViewController:mpvc animated:YES];
    } else if (indexPath.section == PMSectionAbout && indexPath.row == 2) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://repo.samcejko.eu/"]];
    }
}

#pragma mark - Switches

- (void)fallbackSwitchChanged:(UISwitch *)sw
{
    [PMSettings shared].autoFallback = sw.on;
}

- (void)freeOnlySwitchChanged:(UISwitch *)sw
{
    [PMSettings shared].freeOnly = sw.on;
}

- (void)stepsSwitchChanged:(UISwitch *)sw
{
    [PMSettings shared].showStepByStep = sw.on;
}

- (void)darkThemeSwitchChanged:(UISwitch *)sw
{
    [PMSettings shared].darkTheme = sw.on;
}

- (void)tlsSwitchChanged:(UISwitch *)sw
{
    [PMSettings shared].verifyTLS = sw.on;
}

@end
