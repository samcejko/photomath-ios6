#import "PMScannerViewController.h"
#import "PMViewfinderView.h"
#import "PMSolutionViewController.h"
#import "PMMathKeyboard.h"
#import "PMHistoryViewController.h"
#import "PMSettingsViewController.h"
#import "PMOpenRouterClient.h"
#import "PMModelCatalog.h"
#import "PMSettings.h"
#import "PMHistoryStore.h"
#import "PMOfflineSolver.h"
#import "PMTheme.h"
#import "PMModern.h"
#import "PMUtils.h"
#import "PMCommon.h"
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>

@interface PMScannerViewController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) AVCaptureStillImageOutput *stillImageOutput;
@property (nonatomic, strong) AVCaptureDevice *videoDevice;

@property (nonatomic, strong) PMViewfinderView *viewfinderView;
@property (nonatomic, strong) UIView *topBar;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UIButton *shutterButton;
@property (nonatomic, strong) UIButton *torchButton;
@property (nonatomic, strong) UIButton *galleryButton;
@property (nonatomic, strong) UIButton *keyboardButton;
@property (nonatomic, strong) UIButton *historyButton;
@property (nonatomic, strong) UIButton *settingsButton;

// Loading HUD
@property (nonatomic, strong) UIView *hudView;
@property (nonatomic, strong) UIActivityIndicatorView *hudSpinner;
@property (nonatomic, strong) UILabel *hudLabel;
@property (nonatomic) BOOL isSolving;

@end

@implementation PMScannerViewController

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.title = L(@"Scanner");
        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:L(@"Scanner")
                                                                                 style:UIBarButtonItemStyleBordered
                                                                                target:nil
                                                                                action:nil];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    [self.navigationController setNavigationBarHidden:YES animated:NO];

    [self setupCamera];
    [self setupViewfinder];
    [self setupUIOverlays];
    [self setupHUD];

    // Refresh model catalog in background
    [[PMModelCatalog shared] refreshIfStale];

    // Tap to focus gesture
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapToFocus:)];
    [self.viewfinderView addGestureRecognizer:tap];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    if (self.captureSession && !self.captureSession.isRunning) {
        [self.captureSession startRunning];
    }
    [self.viewfinderView startScanningAnimation];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    [self.viewfinderView stopScanningAnimation];
    if (self.captureSession && self.captureSession.isRunning) {
        [self.captureSession stopRunning];
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    CGRect bounds = self.view.bounds;
    CGFloat w = bounds.size.width;
    CGFloat h = bounds.size.height;
    if (w <= 0 || h <= 0) return;

    if (self.previewLayer) {
        self.previewLayer.frame = bounds;
    }
    self.viewfinderView.frame = bounds;

    UIEdgeInsets insets = PMSafeAreaInsets(self.view);

    // Top Bar layout: extends under status bar / notch
    CGFloat statusH = [UIApplication sharedApplication].statusBarHidden ? 0.0f : [UIApplication sharedApplication].statusBarFrame.size.height;
    if (statusH <= 0 || statusH > 50.0f) statusH = 20.0f;
    CGFloat topInset = MAX(insets.top, statusH);
    CGFloat topBarH = topInset + 44.0f;
    self.topBar.frame = CGRectMake(0, 0, w, topBarH);

    CGFloat buttonY = topInset + (44.0f - 34.0f) / 2.0f;
    self.torchButton.frame = CGRectMake(10, buttonY, 42, 34);
    self.settingsButton.frame = CGRectMake(w - 48, buttonY, 40, 34);
    self.historyButton.frame = CGRectMake(w - 95, buttonY, 40, 34);

    CGFloat titleX = (self.videoDevice && self.videoDevice.hasTorch) ? 58.0f : 16.0f;
    CGFloat titleW = MAX(80.0f, (w - 105.0f) - titleX);
    self.titleLabel.frame = CGRectMake(titleX, buttonY, titleW, 34);

    // Bottom Bar layout: extends under home indicator on modern iPhones
    CGFloat botInset = insets.bottom;
    CGFloat botBarContentH = 88.0f;
    CGFloat botBarH = botBarContentH + botInset;
    self.bottomBar.frame = CGRectMake(0, h - botBarH, w, botBarH);

    // Center shutter button
    CGFloat shutterSize = 68.0f;
    self.shutterButton.frame = CGRectMake((w - shutterSize) / 2.0f, 10.0f, shutterSize, shutterSize);
    self.shutterButton.layer.cornerRadius = shutterSize / 2.0f;

    // Gallery button on left, Keyboard button on right with balanced spacing
    CGFloat sideBtnSize = 48.0f;
    CGFloat sideBtnY = 20.0f;
    CGFloat leftCenter = ((w - shutterSize) / 2.0f) / 2.0f;
    CGFloat rightCenter = w - leftCenter;
    self.galleryButton.frame = CGRectMake(floorf(leftCenter - sideBtnSize / 2.0f), sideBtnY, sideBtnSize, sideBtnSize);
    self.keyboardButton.frame = CGRectMake(floorf(rightCenter - sideBtnSize / 2.0f), sideBtnY, sideBtnSize, sideBtnSize);

    // Center HUD
    self.hudView.center = CGPointMake(w / 2.0f, h / 2.0f);

    // Adjust crop rect in viewfinder between top and bottom bars
    CGFloat availTop = topBarH;
    CGFloat availBot = h - botBarH;
    CGFloat availH = availBot - availTop;
    CGFloat defaultCropW = MIN(w - 32.0f, 320.0f);
    CGFloat defaultCropH = MIN(130.0f, MAX(90.0f, availH * 0.40f));
    CGFloat cropX = floorf((w - defaultCropW) / 2.0f);
    CGFloat cropY = floorf(availTop + (availH - defaultCropH) / 2.0f - 10.0f);
    [self.viewfinderView setDefaultCropRect:CGRectMake(cropX, cropY, defaultCropW, defaultCropH)];
}

#pragma mark - Camera Setup

- (void)setupCamera
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *d in devices) {
        if (d.position == AVCaptureDevicePositionBack) {
            self.videoDevice = d;
            break;
        }
    }
    if (!self.videoDevice && devices.count) {
        self.videoDevice = [devices objectAtIndex:0];
    }

    if (!self.videoDevice) {
        PMLog(@"No camera device found (simulator or legacy device)");
        return;
    }

    NSError *err = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:self.videoDevice error:&err];
    if (err || !input) {
        PMLog(@"Failed to create camera input: %@", err.localizedDescription);
        return;
    }

    self.captureSession = [[AVCaptureSession alloc] init];
    if ([self.captureSession canSetSessionPreset:AVCaptureSessionPresetHigh]) {
        self.captureSession.sessionPreset = AVCaptureSessionPresetHigh;
    }

    [self.captureSession addInput:input];

    self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    self.stillImageOutput.outputSettings = @{ (id)AVVideoCodecKey: AVVideoCodecJPEG };
    [self.captureSession addOutput:self.stillImageOutput];

    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    if ([self.previewLayer respondsToSelector:@selector(connection)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
        if ([self.previewLayer.connection isVideoOrientationSupported]) {
            self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
        }
#pragma clang diagnostic pop
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 60000
    } else if ([self.previewLayer isOrientationSupported]) {
        self.previewLayer.orientation = AVCaptureVideoOrientationPortrait;
#endif
    }
    self.previewLayer.frame = self.view.bounds;
    [self.view.layer addSublayer:self.previewLayer];

    // Set autofocus
    if ([self.videoDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
        if ([self.videoDevice lockForConfiguration:nil]) {
            self.videoDevice.focusMode = AVCaptureFocusModeContinuousAutoFocus;
            [self.videoDevice unlockForConfiguration];
        }
    }
}

- (void)setupViewfinder
{
    self.viewfinderView = [[PMViewfinderView alloc] initWithFrame:self.view.bounds];
    self.viewfinderView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.viewfinderView];
}

#pragma mark - UI Overlays

- (void)setupUIOverlays
{
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;

    // Top Bar (semi-transparent glossy black)
    self.topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 54)];
    self.topBar.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.65f];
    [self.view addSubview:self.topBar];

    // Torch button (if supported)
    self.torchButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.torchButton.frame = CGRectMake(10, 10, 42, 34);
    [self.torchButton setImage:[[PMTheme shared] torchIconActive:NO] forState:UIControlStateNormal];
    [self.torchButton setImage:[[PMTheme shared] torchIconActive:YES] forState:UIControlStateSelected];
    [self.torchButton setBackgroundImage:[[PMTheme shared] darkBarButtonImageHighlighted:NO] forState:UIControlStateNormal];
    [self.torchButton setBackgroundImage:[[PMTheme shared] darkBarButtonImageHighlighted:YES] forState:UIControlStateHighlighted];
    [self.torchButton addTarget:self action:@selector(toggleTorch:) forControlEvents:UIControlEventTouchUpInside];
    self.torchButton.hidden = !self.videoDevice.hasTorch;
    [self.topBar addSubview:self.torchButton];

    // App title
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(58, 10, w - 165, 34)];
    self.titleLabel.text = L(@"ShutterCalc");
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:18.0f];
    self.titleLabel.backgroundColor = [UIColor clearColor];
    [self.topBar addSubview:self.titleLabel];

    // History button
    self.historyButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.historyButton.frame = CGRectMake(w - 95, 10, 40, 34);
    [self.historyButton setImage:[[PMTheme shared] historyIcon] forState:UIControlStateNormal];
    [self.historyButton setBackgroundImage:[[PMTheme shared] darkBarButtonImageHighlighted:NO] forState:UIControlStateNormal];
    [self.historyButton setBackgroundImage:[[PMTheme shared] darkBarButtonImageHighlighted:YES] forState:UIControlStateHighlighted];
    [self.historyButton addTarget:self action:@selector(openHistory:) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.historyButton];

    // Settings button
    self.settingsButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.settingsButton.frame = CGRectMake(w - 48, 10, 40, 34);
    [self.settingsButton setImage:[[PMTheme shared] settingsIcon] forState:UIControlStateNormal];
    [self.settingsButton setBackgroundImage:[[PMTheme shared] darkBarButtonImageHighlighted:NO] forState:UIControlStateNormal];
    [self.settingsButton setBackgroundImage:[[PMTheme shared] darkBarButtonImageHighlighted:YES] forState:UIControlStateHighlighted];
    [self.settingsButton addTarget:self action:@selector(openSettings:) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.settingsButton];

    // Bottom Bar (controls)
    self.bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, h - 90, w, 90)];
    self.bottomBar.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.75f];
    [self.view addSubview:self.bottomBar];

    // Gallery button
    self.galleryButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.galleryButton.frame = CGRectMake(25, 20, 50, 50);
    [self.galleryButton setImage:[[PMTheme shared] galleryIcon] forState:UIControlStateNormal];
    [self.galleryButton setBackgroundImage:[[PMTheme shared] darkBarButtonImageHighlighted:NO] forState:UIControlStateNormal];
    [self.galleryButton setBackgroundImage:[[PMTheme shared] darkBarButtonImageHighlighted:YES] forState:UIControlStateHighlighted];
    [self.galleryButton addTarget:self action:@selector(openGallery:) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:self.galleryButton];

    // Big Shutter Button (Classic Photomath Red / Coral circle with drawn shutter target)
    self.shutterButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.shutterButton.frame = CGRectMake((w - 70) / 2.0f, 10, 70, 70);
    self.shutterButton.layer.cornerRadius = 35.0f;
    self.shutterButton.layer.borderWidth = 3.5f;
    self.shutterButton.layer.borderColor = [UIColor whiteColor].CGColor;
    self.shutterButton.backgroundColor = [[PMTheme shared] accentColor];
    [self.shutterButton setImage:[[PMTheme shared] shutterIcon] forState:UIControlStateNormal];
    [self.shutterButton addTarget:self action:@selector(shutterTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:self.shutterButton];

    // Manual Math Keyboard button
    self.keyboardButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.keyboardButton.frame = CGRectMake(w - 75, 20, 50, 50);
    [self.keyboardButton setImage:[[PMTheme shared] keyboardIcon] forState:UIControlStateNormal];
    [self.keyboardButton setBackgroundImage:[[PMTheme shared] darkBarButtonImageHighlighted:NO] forState:UIControlStateNormal];
    [self.keyboardButton setBackgroundImage:[[PMTheme shared] darkBarButtonImageHighlighted:YES] forState:UIControlStateHighlighted];
    [self.keyboardButton addTarget:self action:@selector(openKeyboard:) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:self.keyboardButton];
}

#pragma mark - HUD

- (void)setupHUD
{
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;

    self.hudView = [[UIView alloc] initWithFrame:CGRectMake((w - 240) / 2.0f, (h - 130) / 2.0f, 240, 130)];
    self.hudView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.85f];
    self.hudView.layer.cornerRadius = 12.0f;
    self.hudView.layer.borderWidth = 1.0f;
    self.hudView.layer.borderColor = [UIColor colorWithWhite:1.0f alpha:0.3f].CGColor;
    self.hudView.hidden = YES;
    [self.view addSubview:self.hudView];

    self.hudSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.hudSpinner.center = CGPointMake(120, 42);
    [self.hudView addSubview:self.hudSpinner];

    self.hudLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 75, 220, 45)];
    self.hudLabel.textColor = [UIColor whiteColor];
    self.hudLabel.font = [UIFont boldSystemFontOfSize:13.0f];
    self.hudLabel.textAlignment = UITextAlignmentCenter;
    self.hudLabel.numberOfLines = 2;
    self.hudLabel.backgroundColor = [UIColor clearColor];
    [self.hudView addSubview:self.hudLabel];
}

- (void)showHUDWithText:(NSString *)text
{
    self.isSolving = YES;
    self.hudLabel.text = text;
    [self.hudSpinner startAnimating];
    self.hudView.hidden = NO;
    self.shutterButton.enabled = NO;
}

- (void)hideHUD
{
    self.isSolving = NO;
    [self.hudSpinner stopAnimating];
    self.hudView.hidden = YES;
    self.shutterButton.enabled = YES;
}

#pragma mark - Camera Actions

- (void)toggleTorch:(id)sender
{
    if (!self.videoDevice.hasTorch) return;
    NSError *err = nil;
    if ([self.videoDevice lockForConfiguration:&err]) {
        if (self.videoDevice.torchMode == AVCaptureTorchModeOn) {
            self.videoDevice.torchMode = AVCaptureTorchModeOff;
            self.torchButton.selected = NO;
        } else {
            self.videoDevice.torchMode = AVCaptureTorchModeOn;
            self.torchButton.selected = YES;
        }
        [self.videoDevice unlockForConfiguration];
    }
}

- (void)handleTapToFocus:(UITapGestureRecognizer *)tap
{
    CGPoint point = [tap locationInView:self.viewfinderView];
    [self.viewfinderView showFocusIndicatorAtPoint:point];

    if (!self.videoDevice || ![self.videoDevice isFocusPointOfInterestSupported]) return;

    CGPoint focusPoint = CGPointMake(point.y / self.view.bounds.size.height, 1.0f - (point.x / self.view.bounds.size.width));
    if ([self.videoDevice lockForConfiguration:nil]) {
        self.videoDevice.focusPointOfInterest = focusPoint;
        if ([self.videoDevice isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            self.videoDevice.focusMode = AVCaptureFocusModeAutoFocus;
        }
        [self.videoDevice unlockForConfiguration];
    }
}

#pragma mark - Solve Flow

- (void)shutterTapped:(id)sender
{
    if (self.isSolving) return;

    // Check API Key first
    if (![PMSettings shared].hasAPIKey) {
        [self openSettings:nil];
        [PMUtils alertWithTitle:L(@"API Key Required")
                        message:L(@"Please enter your OpenRouter API key to solve mathematical problems.")];
        return;
    }

    if (!self.captureSession || !self.stillImageOutput) {
        // Fallback for simulator
        [self openKeyboard:nil];
        return;
    }

    AVCaptureConnection *conn = nil;
    for (AVCaptureConnection *c in self.stillImageOutput.connections) {
        for (AVCaptureInputPort *port in [c inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
                conn = c;
                break;
            }
        }
        if (conn) break;
    }

    if (!conn) {
        [PMUtils alertWithTitle:L(@"Camera Error") message:L(@"Could not capture frame from video device.")];
        return;
    }

    if ([conn isVideoOrientationSupported]) {
        conn.videoOrientation = AVCaptureVideoOrientationPortrait;
    }

    [self showHUDWithText:L(@"Scanning equation...")];

    [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:conn
                                                       completionHandler:^(CMSampleBufferRef sampleBuffer, NSError *error) {
        if (error || !sampleBuffer) {
            PMMain(^{
                [self hideHUD];
                [PMUtils alertWithTitle:L(@"Capture Failed") message:error.localizedDescription];
            });
            return;
        }

        NSData *jpeg = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:sampleBuffer];
        UIImage *rawImage = [UIImage imageWithData:jpeg];

        // Crop to the viewfinder box using exact aspect fill coordinates and upright orientation
        CGRect cropRect = [self.viewfinderView cropRect];
        UIImage *cropped = [PMUtils cropImage:rawImage fromViewBounds:self.view.bounds cropRect:cropRect];

        [self processEquationWithImage:cropped manualLatex:nil];
    }];
}

- (void)processEquationWithImage:(UIImage *)image manualLatex:(NSString *)manualLatex
{
    // If entered via keyboard and preferOfflineSolver is enabled, try offline solver first (100% offline & instant)
    if (manualLatex.length > 0 && [PMSettings shared].preferOfflineSolver && [PMOfflineSolver canSolveProblem:manualLatex]) {
        NSError *offlineErr = nil;
        PMMathSolution *sol = [PMOfflineSolver solveProblem:manualLatex error:&offlineErr];
        if (sol) {
            [self hideHUD];
            [[PMHistoryStore shared] addSolution:sol];
            PMSolutionViewController *svc = [[PMSolutionViewController alloc] initWithSolution:sol];
            svc.onEditProblemRequested = ^(NSString *problemLatex) {
                [self openKeyboardWithLatex:problemLatex];
            };
            [self.navigationController pushViewController:svc animated:YES];
            return;
        }
    }

    // Generate dynamic fallback chain from live catalog (no static models hardcoded)
    NSString *pref = [PMSettings shared].preferredModelId;
    NSArray *chain = [[PMModelCatalog shared] fallbackChainStartingWithModelId:pref];

    if (!chain.count) {
        // If catalog is still downloading, trigger immediate refresh
        [[PMModelCatalog shared] refreshWithCompletion:^(NSError *err) {
            NSArray *newChain = [[PMModelCatalog shared] fallbackChainStartingWithModelId:pref];
            if (!newChain.count) {
                [self hideHUD];
                // If offline and problem was typed, attempt offline solver before giving up
                if (manualLatex.length > 0) {
                    NSError *offErr = nil;
                    PMMathSolution *offSol = [PMOfflineSolver solveProblem:manualLatex error:&offErr];
                    if (offSol) {
                        [[PMHistoryStore shared] addSolution:offSol];
                        PMSolutionViewController *svc = [[PMSolutionViewController alloc] initWithSolution:offSol];
                        svc.onEditProblemRequested = ^(NSString *problemLatex) {
                            [self openKeyboardWithLatex:problemLatex];
                        };
                        [self.navigationController pushViewController:svc animated:YES];
                        return;
                    }
                }
                [PMUtils alertWithTitle:L(@"No Models Available")
                                message:L(@"Could not find vision models in OpenRouter catalog. Check your connection.")];
                return;
            }
            [self executeSolveWithChain:newChain image:image manualLatex:manualLatex];
        }];
        return;
    }

    [self executeSolveWithChain:chain image:image manualLatex:manualLatex];
}

- (void)executeSolveWithChain:(NSArray *)chain image:(UIImage *)image manualLatex:(NSString *)manualLatex
{
    PMModelInfo *first = [chain objectAtIndex:0];
    [self showHUDWithText:[NSString stringWithFormat:@"%@\n(%@)", L(@"Solving equation..."), first.displayName]];

    [[PMOpenRouterClient shared] solveProblemWithImage:image
                                           manualLatex:manualLatex
                                         fallbackChain:chain
                                              language:[PMSettings shared].solutionLanguage
                                            onFallback:^(PMModelInfo *failedModel, NSError *error, PMModelInfo *nextModel) {
        PMMain(^{
            self.hudLabel.text = [NSString stringWithFormat:L(@"%@ rate-limited.\nTrying %@..."), failedModel.displayName, nextModel.displayName];
        });
    } completion:^(NSDictionary *solutionJSON, PMModelInfo *succeededModel, NSError *error) {
        PMMain(^{
            [self hideHUD];
            if (error || !solutionJSON) {
                // If keyboard equation and network failed, try offline engine
                if (manualLatex.length > 0) {
                    NSError *offErr = nil;
                    PMMathSolution *offSol = [PMOfflineSolver solveProblem:manualLatex error:&offErr];
                    if (offSol) {
                        [[PMHistoryStore shared] addSolution:offSol];
                        PMSolutionViewController *svc = [[PMSolutionViewController alloc] initWithSolution:offSol];
                        svc.onEditProblemRequested = ^(NSString *problemLatex) {
                            [self openKeyboardWithLatex:problemLatex];
                        };
                        [self.navigationController pushViewController:svc animated:YES];
                        return;
                    }
                }
                [PMUtils alertWithTitle:L(@"Solving Failed") message:error.localizedDescription];
                return;
            }

            PMMathSolution *sol = [PMMathSolution solutionFromJSON:solutionJSON
                                                         modelUsed:succeededModel.modelId
                                                             image:image];
            [[PMHistoryStore shared] addSolution:sol];

            PMSolutionViewController *svc = [[PMSolutionViewController alloc] initWithSolution:sol];
            svc.onEditProblemRequested = ^(NSString *problemLatex) {
                [self openKeyboardWithLatex:problemLatex];
            };
            [self.navigationController pushViewController:svc animated:YES];
        });
    }];
}

#pragma mark - Navigation Actions

- (void)openGallery:(id)sender
{
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        [PMUtils alertWithTitle:L(@"Photo Library") message:L(@"Photo library is not available on this device.")];
        return;
    }
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *img = [info objectForKey:UIImagePickerControllerEditedImage] ?: [info objectForKey:UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:^{
        if (img) {
            [self showHUDWithText:L(@"Analyzing photo...")];
            [self processEquationWithImage:img manualLatex:nil];
        }
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)openKeyboard:(id)sender
{
    [self openKeyboardWithLatex:@""];
}

- (void)openKeyboardWithLatex:(NSString *)latex
{
    PMMathKeyboard *kb = [[PMMathKeyboard alloc] initWithInitialLatex:latex];
    kb.onSolveRequested = ^(NSString *enteredLatex) {
        [self showHUDWithText:L(@"Solving equation...")];
        [self processEquationWithImage:nil manualLatex:enteredLatex];
    };
    [self.navigationController pushViewController:kb animated:YES];
}

- (void)openHistory:(id)sender
{
    PMHistoryViewController *hvc = [[PMHistoryViewController alloc] init];
    [self.navigationController pushViewController:hvc animated:YES];
}

- (void)openSettings:(id)sender
{
    PMSettingsViewController *svc = [[PMSettingsViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:svc];
    [self presentViewController:nav animated:YES completion:nil];
}

@end
