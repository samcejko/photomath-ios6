#import "PMAPIKeyViewController.h"
#import "PMOpenRouterClient.h"
#import "PMSettings.h"
#import "PMTheme.h"
#import "PMCommon.h"
#import "PMUtils.h"

@interface PMAPIKeyViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *keyField;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *verifyButton;
@property (nonatomic, strong) UIButton *pasteButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation PMAPIKeyViewController

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.title = L(@"OpenRouter Key");
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[PMTheme shared] applyToNavigationBar:self.navigationController.navigationBar];
    self.view.backgroundColor = [[PMTheme shared] backgroundColor];

    CGFloat w = self.view.bounds.size.width;

    UILabel *intro = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, w - 40, 48)];
    intro.text = L(@"Enter your OpenRouter API key. It is saved in the device Keychain and used to solve equations.");
    intro.font = [UIFont systemFontOfSize:13.0f];
    intro.textColor = [UIColor grayColor];
    intro.numberOfLines = 3;
    intro.backgroundColor = [UIColor clearColor];
    [self.view addSubview:intro];

    self.keyField = [[UITextField alloc] initWithFrame:CGRectMake(20, 75, w - 40, 38)];
    self.keyField.borderStyle = UITextBorderStyleRoundedRect;
    self.keyField.placeholder = @"sk-or-v1-…";
    self.keyField.font = [UIFont systemFontOfSize:14.0f];
    self.keyField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.keyField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.keyField.secureTextEntry = YES;
    self.keyField.text = [PMSettings shared].apiKey;
    self.keyField.delegate = self;
    [self.view addSubview:self.keyField];

    self.pasteButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.pasteButton.frame = CGRectMake(20, 125, (w - 50) / 2.0f, 38);
    [self.pasteButton setTitle:L(@"Paste from Clipboard") forState:UIControlStateNormal];
    [self.pasteButton addTarget:self action:@selector(pasteTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.pasteButton];

    self.verifyButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.verifyButton.frame = CGRectMake(CGRectGetMaxX(self.pasteButton.frame) + 10, 125, (w - 50) / 2.0f, 38);
    [self.verifyButton setTitle:L(@"Verify & Save") forState:UIControlStateNormal];
    [self.verifyButton addTarget:self action:@selector(verifyTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.verifyButton];

    UIButton *importBtn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    importBtn.frame = CGRectMake(20, 170, w - 40, 38);
    [importBtn setTitle:L(@"Import from AI Chat") forState:UIControlStateNormal];
    [importBtn addTarget:self action:@selector(importAIChatTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:importBtn];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.center = CGPointMake(w / 2.0f, 225);
    [self.view addSubview:self.spinner];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 245, w - 40, 60)];
    self.statusLabel.font = [UIFont systemFontOfSize:13.0f];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.statusLabel];

    if ([PMSettings shared].hasAPIKey) {
        [self checkCurrentKey];
    } else if ([PMSettings hasAIChatAPIKey]) {
        self.statusLabel.textColor = [UIColor darkGrayColor];
        self.statusLabel.text = L(@"OpenRouter key detected in AI Chat app. Tap 'Import from AI Chat' to use it.");
    }
}

- (void)importAIChatTapped:(id)sender
{
    NSString *chatKey = [PMSettings availableAIChatAPIKey];
    if (chatKey.length) {
        self.keyField.text = chatKey;
        self.statusLabel.textColor = [UIColor darkGrayColor];
        self.statusLabel.text = L(@"Key imported from AI Chat. Verifying...");
        [self verifyTapped:nil];
    } else {
        self.statusLabel.textColor = [UIColor redColor];
        self.statusLabel.text = L(@"No API key found in AI Chat.");
    }
}

- (void)pasteTapped:(id)sender
{
    NSString *p = [UIPasteboard generalPasteboard].string;
    if (p.length) {
        self.keyField.text = [p stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
}

- (void)verifyTapped:(id)sender
{
    NSString *k = [self.keyField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!k.length) {
        [PMSettings shared].apiKey = nil;
        self.statusLabel.textColor = [UIColor grayColor];
        self.statusLabel.text = L(@"API key cleared.");
        return;
    }

    [self.spinner startAnimating];
    self.verifyButton.enabled = NO;
    self.statusLabel.text = L(@"Verifying key...");

    [[PMOpenRouterClient shared] fetchKeyInfoWithKey:k completion:^(NSDictionary *info, NSError *error) {
        PMMain(^{
            [self.spinner stopAnimating];
            self.verifyButton.enabled = YES;
            if (error || !info) {
                self.statusLabel.textColor = [UIColor redColor];
                self.statusLabel.text = [NSString stringWithFormat:L(@"Invalid key: %@"), error.localizedDescription];
            } else {
                [PMSettings shared].apiKey = k;
                NSNumber *limit = info[@"limit"];
                NSNumber *usage = info[@"usage"];
                self.statusLabel.textColor = [UIColor colorWithRed:0.2f green:0.6f blue:0.2f alpha:1.0f];
                if (limit && usage) {
                    double rem = [limit doubleValue] - [usage doubleValue];
                    self.statusLabel.text = [NSString stringWithFormat:L(@"Valid key! Remaining credits: $%.2f"), rem];
                } else {
                    self.statusLabel.text = L(@"Valid OpenRouter API key saved!");
                }
            }
        });
    }];
}

- (void)checkCurrentKey
{
    NSString *k = [PMSettings shared].apiKey;
    if (!k.length) return;
    [[PMOpenRouterClient shared] fetchKeyInfoWithKey:k completion:^(NSDictionary *info, NSError *error) {
        PMMain(^{
            if (!error && info) {
                NSNumber *limit = info[@"limit"];
                NSNumber *usage = info[@"usage"];
                if (limit && usage) {
                    double rem = [limit doubleValue] - [usage doubleValue];
                    self.statusLabel.textColor = [UIColor colorWithRed:0.2f green:0.6f blue:0.2f alpha:1.0f];
                    self.statusLabel.text = [NSString stringWithFormat:L(@"Active key. Credits: $%.2f"), rem];
                }
            }
        });
    }];
}

@end
