#import "PMAPIKeyViewController.h"
#import "PMOpenRouterClient.h"
#import "PMSettings.h"
#import "PMTheme.h"
#import "PMCommon.h"
#import "PMUtils.h"
#import "PMModern.h"

@interface PMAPIKeyViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UILabel *introLabel;
@property (nonatomic, strong) UITextField *keyField;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *verifyButton;
@property (nonatomic, strong) UIButton *pasteButton;
@property (nonatomic, strong) UIButton *importButton;
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

    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.alwaysBounceVertical = YES;
    PMModernKeepScrollViewInsets(self.scrollView);
    [self.view addSubview:self.scrollView];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard:)];
    [self.scrollView addGestureRecognizer:tap];

    self.introLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.introLabel.text = L(@"Enter your OpenRouter API key. It is saved in the device Keychain and used to solve equations.");
    self.introLabel.font = [UIFont systemFontOfSize:13.0f];
    self.introLabel.textColor = [UIColor grayColor];
    self.introLabel.numberOfLines = 0;
    self.introLabel.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:self.introLabel];

    self.keyField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.keyField.borderStyle = UITextBorderStyleRoundedRect;
    self.keyField.placeholder = @"sk-or-v1-…";
    self.keyField.font = [UIFont systemFontOfSize:14.0f];
    self.keyField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.keyField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.keyField.secureTextEntry = YES;
    self.keyField.text = [PMSettings shared].apiKey;
    self.keyField.delegate = self;
    [self.scrollView addSubview:self.keyField];

    self.pasteButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [self.pasteButton setTitle:L(@"Paste from Clipboard") forState:UIControlStateNormal];
    [self.pasteButton addTarget:self action:@selector(pasteTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:self.pasteButton];

    self.verifyButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [self.verifyButton setTitle:L(@"Verify & Save") forState:UIControlStateNormal];
    [self.verifyButton addTarget:self action:@selector(verifyTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:self.verifyButton];

    self.importButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [self.importButton setTitle:L(@"Import from AI Chat") forState:UIControlStateNormal];
    [self.importButton addTarget:self action:@selector(importAIChatTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:self.importButton];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [self.scrollView addSubview:self.spinner];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.statusLabel.font = [UIFont systemFontOfSize:13.0f];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:self.statusLabel];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];

    if ([PMSettings shared].hasAPIKey) {
        [self checkCurrentKey];
    } else if ([PMSettings hasAIChatAPIKey]) {
        self.statusLabel.textColor = [UIColor darkGrayColor];
        self.statusLabel.text = L(@"OpenRouter key detected in AI Chat app. Tap 'Import from AI Chat' to use it.");
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    if (w <= 0 || h <= 0) return;

    self.scrollView.frame = self.view.bounds;

    CGFloat margin = 16.0f;
    CGFloat fieldW = w - margin * 2;

    CGSize introSz = [self.introLabel.text sizeWithFont:self.introLabel.font
                                      constrainedToSize:CGSizeMake(fieldW, CGFLOAT_MAX)
                                          lineBreakMode:NSLineBreakByWordWrapping];
    self.introLabel.frame = CGRectMake(margin, 16.0f, fieldW, MAX(36.0f, introSz.height));

    CGFloat curY = CGRectGetMaxY(self.introLabel.frame) + 12.0f;
    self.keyField.frame = CGRectMake(margin, curY, fieldW, 36.0f);
    curY = CGRectGetMaxY(self.keyField.frame) + 14.0f;

    CGFloat btnH = 38.0f;
    if (fieldW > 340.0f) {
        // Two columns for buttons on wider screens (iPad or Plus)
        CGFloat colW = floorf((fieldW - 10.0f) / 2.0f);
        self.pasteButton.frame = CGRectMake(margin, curY, colW, btnH);
        self.verifyButton.frame = CGRectMake(margin + colW + 10.0f, curY, colW, btnH);
        curY = CGRectGetMaxY(self.pasteButton.frame) + 10.0f;
        self.importButton.frame = CGRectMake(margin, curY, fieldW, btnH);
        curY = CGRectGetMaxY(self.importButton.frame) + 16.0f;
    } else {
        // Stack buttons vertically on standard 320pt iPhone screen so text never truncates
        self.pasteButton.frame = CGRectMake(margin, curY, fieldW, btnH);
        curY = CGRectGetMaxY(self.pasteButton.frame) + 10.0f;
        self.verifyButton.frame = CGRectMake(margin, curY, fieldW, btnH);
        curY = CGRectGetMaxY(self.verifyButton.frame) + 10.0f;
        self.importButton.frame = CGRectMake(margin, curY, fieldW, btnH);
        curY = CGRectGetMaxY(self.importButton.frame) + 16.0f;
    }

    self.spinner.center = CGPointMake(w / 2.0f, curY + 12.0f);
    curY = CGRectGetMaxY(self.spinner.frame) + 12.0f;

    CGSize statusSz = [self.statusLabel.text sizeWithFont:self.statusLabel.font
                                        constrainedToSize:CGSizeMake(fieldW, CGFLOAT_MAX)
                                            lineBreakMode:NSLineBreakByWordWrapping];
    self.statusLabel.frame = CGRectMake(margin, curY, fieldW, MAX(44.0f, statusSz.height));
    curY = CGRectGetMaxY(self.statusLabel.frame) + 20.0f;

    self.scrollView.contentSize = CGSizeMake(w, MAX(curY, h + 1.0f));
}

- (void)dismissKeyboard:(id)sender
{
    [self.view endEditing:YES];
}

- (void)keyboardWillShow:(NSNotification *)note
{
    NSDictionary *userInfo = note.userInfo;
    CGRect kbFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect kbWindow = [self.view.window convertRect:kbFrame fromWindow:nil];
    CGRect kbView = [self.view convertRect:kbWindow fromView:nil];
    CGFloat overlap = CGRectGetMaxY(self.view.bounds) - kbView.origin.y;
    if (overlap > 0) {
        UIEdgeInsets insets = UIEdgeInsetsMake(0, 0, overlap + 10.0f, 0);
        self.scrollView.contentInset = insets;
        self.scrollView.scrollIndicatorInsets = insets;
    }
}

- (void)keyboardWillHide:(NSNotification *)note
{
    self.scrollView.contentInset = UIEdgeInsetsZero;
    self.scrollView.scrollIndicatorInsets = UIEdgeInsetsZero;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    [self verifyTapped:nil];
    return YES;
}

- (void)importAIChatTapped:(id)sender
{
    NSString *chatKey = [PMSettings availableAIChatAPIKey];
    if (chatKey.length) {
        self.keyField.text = chatKey;
        self.statusLabel.textColor = [UIColor darkGrayColor];
        self.statusLabel.text = L(@"Key imported from AI Chat. Verifying...");
        [self.view setNeedsLayout];
        [self verifyTapped:nil];
    } else {
        self.statusLabel.textColor = [UIColor redColor];
        self.statusLabel.text = L(@"No API key found in AI Chat.");
        [self.view setNeedsLayout];
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
    [self.view endEditing:YES];
    NSString *k = [self.keyField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!k.length) {
        [PMSettings shared].apiKey = nil;
        self.statusLabel.textColor = [UIColor grayColor];
        self.statusLabel.text = L(@"API key cleared.");
        [self.view setNeedsLayout];
        return;
    }

    [self.spinner startAnimating];
    self.verifyButton.enabled = NO;
    self.statusLabel.text = L(@"Verifying key...");
    [self.view setNeedsLayout];

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
            [self.view setNeedsLayout];
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
                    [self.view setNeedsLayout];
                }
            }
        });
    }];
}

@end
