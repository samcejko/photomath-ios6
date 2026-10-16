#import "PMAppDelegate.h"
#import "PMScannerViewController.h"
#import "PMTheme.h"
#import "PMModern.h"
#import "PMSettings.h"
#import "PMModelCatalog.h"
#import "PMCommon.h"

@implementation PMAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Modern iOS appearance shim (iOS 14-17 TrollStore / rootless)
    PMModernSetUp(UIBarStyleBlackOpaque);

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    PMScannerViewController *scannerVC = [[PMScannerViewController alloc] init];
    self.navigationController = [[UINavigationController alloc] initWithRootViewController:scannerVC];
    self.navigationController.navigationBarHidden = YES;

    self.window.rootViewController = self.navigationController;
    [self.window makeKeyAndVisible];

    // Warm up model catalog and history
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [[PMModelCatalog shared] loadCache];
        [[PMModelCatalog shared] refreshIfStale];
    });

    return YES;
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
    PMLog(@"Application received memory warning - clearing image caches");
}

@end
