// PMCommon.h - Shared macros, constants and notifications for ShutterCalc iOS 6.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#pragma clang diagnostic error "-Wunguarded-availability"

#define L(key) NSLocalizedString((key), nil)
#define PMIsPad() (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
#define PMLog(fmt, ...) NSLog((@"[ShutterCalc] " fmt), ##__VA_ARGS__)

static inline void PMMain(dispatch_block_t block)
{
    if ([NSThread isMainThread]) block();
    else dispatch_async(dispatch_get_main_queue(), block);
}

extern NSString * const PMThemeDidChangeNotification;
extern NSString * const PMModelsDidUpdateNotification;
extern NSString * const PMAPIKeyDidChangeNotification;
extern NSString * const PMSettingsDidChangeNotification;
extern NSString * const PMHistoryDidChangeNotification;
extern NSString * const PMErrorDomain;

enum {
    PMErrorNetwork       = -1,
    PMErrorTLS           = -2,
    PMErrorCertificate   = -3,
    PMErrorTimeout       = -4,
    PMErrorCancelled     = -5,
    PMErrorBadResponse   = -6,
    PMErrorNoAPIKey      = -7,
    PMErrorNoModel       = -8,
    PMErrorAllModelsFailed = -9,
};

NSError *PMMakeError(NSInteger code, NSString *message);
