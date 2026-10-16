#import "PMCommon.h"

NSString * const PMThemeDidChangeNotification    = @"PMThemeDidChangeNotification";
NSString * const PMModelsDidUpdateNotification   = @"PMModelsDidUpdateNotification";
NSString * const PMAPIKeyDidChangeNotification   = @"PMAPIKeyDidChangeNotification";
NSString * const PMSettingsDidChangeNotification = @"PMSettingsDidChangeNotification";
NSString * const PMHistoryDidChangeNotification  = @"PMHistoryDidChangeNotification";
NSString * const PMErrorDomain                   = @"com.samcejko.photomath";

NSError *PMMakeError(NSInteger code, NSString *message)
{
    if (!message) message = @"Unknown error";
    return [NSError errorWithDomain:PMErrorDomain code:code userInfo:@{ NSLocalizedDescriptionKey: message }];
}
