#import "PMAppDelegate.h"
#import "PMScannerViewController.h"
#import "PMTheme.h"
#import "PMModern.h"
#import "PMSettings.h"
#import "PMModelCatalog.h"
#import "PMCommon.h"
#import "PMMathSolution.h"
#import "PMSolutionViewController.h"

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

- (BOOL)handleCommandURL:(NSURL *)url
{
    NSString *target = [url.absoluteString substringFromIndex:@"shuttercalc:".length];
    while ([target hasPrefix:@"/"]) target = [target substringFromIndex:1];
    NSString *query = nil;
    NSRange q = [target rangeOfString:@"?"];
    if (q.location != NSNotFound) {
        query = [target substringFromIndex:q.location + 1];
        target = [target substringToIndex:q.location];
    }

    if ([target isEqualToString:@"snapshot"] || [target isEqualToString:@"screen"]) {
        CGSize size = [UIScreen mainScreen].bounds.size;
        UIGraphicsBeginImageContextWithOptions(size, YES, 0.0);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.hidden || w.alpha <= 0) continue;
            CGContextSaveGState(ctx);
            CGContextTranslateCTM(ctx, w.frame.origin.x, w.frame.origin.y);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
            if ([w respondsToSelector:@selector(drawViewHierarchyInRect:afterScreenUpdates:)]) {
                [w drawViewHierarchyInRect:w.bounds afterScreenUpdates:NO];
            } else {
                [w.layer renderInContext:ctx];
            }
#pragma clang diagnostic pop
            CGContextRestoreGState(ctx);
        }
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        NSString *tmpDir = NSTemporaryDirectory();
        NSString *path = [tmpDir stringByAppendingPathComponent:@"screen.png"];
        BOOL ok = [UIImagePNGRepresentation(image) writeToFile:path atomically:YES];
        PMLog(@"Snapshot %@: %@", ok ? @"written to" : @"failed for", path);

        // Write view hierarchy description
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        if ([self.window respondsToSelector:NSSelectorFromString(@"recursiveDescription")]) {
            NSString *desc = [self.window performSelector:NSSelectorFromString(@"recursiveDescription")];
            NSString *uiPath = [tmpDir stringByAppendingPathComponent:@"ui.txt"];
            [desc writeToFile:uiPath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        }
#pragma clang diagnostic pop
        return YES;
    }

    if (self.navigationController.presentedViewController) {
        [self.navigationController dismissViewControllerAnimated:NO completion:nil];
    }

    PMScannerViewController *scannerVC = nil;
    if ([self.navigationController.viewControllers.firstObject isKindOfClass:[PMScannerViewController class]]) {
        scannerVC = (PMScannerViewController *)self.navigationController.viewControllers.firstObject;
    }

    if ([target isEqualToString:@"scanner"]) {
        [self.navigationController popToRootViewControllerAnimated:NO];
        return YES;
    }

    if ([target isEqualToString:@"keyboard"]) {
        [self.navigationController popToRootViewControllerAnimated:NO];
        if (scannerVC) [scannerVC openKeyboard:nil];
        return YES;
    }

    if ([target isEqualToString:@"settings"]) {
        [self.navigationController popToRootViewControllerAnimated:NO];
        if (scannerVC) [scannerVC openSettings:nil];
        return YES;
    }

    if ([target isEqualToString:@"history"]) {
        [self.navigationController popToRootViewControllerAnimated:NO];
        if (scannerVC) [scannerVC openHistory:nil];
        return YES;
    }

    if ([target isEqualToString:@"solution"] || [target isEqualToString:@"demo_solution"]) {
        [self.navigationController popToRootViewControllerAnimated:NO];
        NSDictionary *json = @{
            @"problem_latex": @"2x + 5 = 15",
            @"solution_latex": @"x = 5",
            @"summary": @"Solve linear equation for x",
            @"steps": @[
                @{
                    @"step_number": @1,
                    @"title": @"Subtract 5 from both sides",
                    @"latex": @"2x = 15 - 5",
                    @"explanation": @"Isolate the variable term on the left side by subtracting 5."
                },
                @{
                    @"step_number": @2,
                    @"title": @"Simplify right side",
                    @"latex": @"2x = 10",
                    @"explanation": @"15 minus 5 gives 10."
                },
                @{
                    @"step_number": @3,
                    @"title": @"Divide both sides by 2",
                    @"latex": @"x = \\frac{10}{2} = 5",
                    @"explanation": @"Divide both sides by the coefficient 2 to solve for x."
                }
            ]
        };
        PMMathSolution *sol = [PMMathSolution solutionFromJSON:json modelUsed:@"google/gemini-flash-1.5" image:nil];
        PMSolutionViewController *svc = [[PMSolutionViewController alloc] initWithSolution:sol];
        svc.onEditProblemRequested = ^(NSString *prob) {
            if (scannerVC) [scannerVC openKeyboardWithLatex:prob];
        };
        [self.navigationController pushViewController:svc animated:NO];
        return YES;
    }

    return NO;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    if ([[url.scheme lowercaseString] isEqualToString:@"shuttercalc"]) {
        return [self handleCommandURL:url];
    }
    return NO;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString *, id> *)options
{
    if ([[url.scheme lowercaseString] isEqualToString:@"shuttercalc"]) {
        return [self handleCommandURL:url];
    }
    return NO;
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
    PMLog(@"Application received memory warning - clearing image caches");
}

@end
