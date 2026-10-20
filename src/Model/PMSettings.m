#import "PMSettings.h"
#import "PMCommon.h"
#import <Security/Security.h>

static NSString * const kKeychainService = @"com.samcejko.shuttercalc";
static NSString * const kKeychainServiceOld = @"com.samcejko.photomath";
static NSString * const kKeychainAccount = @"openrouter-api-key";
static NSString * const kFallbackKey     = @"apiKey.fallback";

#define DEF [NSUserDefaults standardUserDefaults]

@interface PMSettings ()
@property (nonatomic, copy) NSString *cachedKey;
@property (nonatomic) BOOL keyLoaded;
@end

@implementation PMSettings

+ (instancetype)shared
{
    static PMSettings *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[PMSettings alloc] init]; });
    return s;
}

+ (NSString *)availableAIChatAPIKey
{
    // 1. Try com.samcejko.aichat Keychain
    NSDictionary *q = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: @"com.samcejko.aichat",
        (__bridge id)kSecAttrAccount: @"openrouter-api-key",
        (__bridge id)kSecReturnData: (__bridge id)kCFBooleanTrue,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne,
    };
    CFTypeRef result = NULL;
    OSStatus st = SecItemCopyMatching((__bridge CFDictionaryRef)q, &result);
    if (st == errSecSuccess && result) {
        NSData *d = (__bridge_transfer NSData *)result;
        NSString *k = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
        k = [k stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (k.length > 0) return k;
    }

    // 2. Try preferences plist files of com.samcejko.aichat
    NSArray *paths = @[
        @"/var/mobile/Library/Preferences/com.samcejko.aichat.plist",
        @"/var/jb/var/mobile/Library/Preferences/com.samcejko.aichat.plist"
    ];
    for (NSString *p in paths) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:p]) {
            NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:p];
            id k = [dict objectForKey:@"apiKey.fallback"] ?: [dict objectForKey:@"apiKey"];
            if ([k isKindOfClass:[NSString class]]) {
                NSString *clean = [k stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (clean.length > 0) return clean;
            }
        }
    }
    return nil;
}

+ (BOOL)hasAIChatAPIKey
{
    return [self availableAIChatAPIKey].length > 0;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [DEF registerDefaults:@{
            @"autoFallback": @YES,
            @"freeOnly": @NO,
            @"preferOfflineSolver": @YES,
            @"showStepByStep": @YES,
            @"solutionLanguage": @"auto",
            @"darkTheme": @NO,
            @"verifyTLS": @YES,
            @"hapticFeedback": @YES,
        }];
    }
    return self;
}

- (void)save
{
    [DEF synchronize];
}

- (void)notify
{
    [[NSNotificationCenter defaultCenter] postNotificationName:PMSettingsDidChangeNotification object:self];
}

#pragma mark - Keychain

- (NSDictionary *)keychainQuery
{
    return @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kKeychainService,
        (__bridge id)kSecAttrAccount: kKeychainAccount,
    };
}

- (NSString *)loadKeyFromKeychain
{
    NSMutableDictionary *q = [[self keychainQuery] mutableCopy];
    [q setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
    [q setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];
    CFTypeRef result = NULL;
    OSStatus st = SecItemCopyMatching((__bridge CFDictionaryRef)q, &result);
    if (st == errSecSuccess && result) {
        NSData *d = (__bridge_transfer NSData *)result;
        return [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    }
    // Also check older service name if upgraded
    NSMutableDictionary *qOld = [q mutableCopy];
    [qOld setObject:kKeychainServiceOld forKey:(__bridge id)kSecAttrService];
    st = SecItemCopyMatching((__bridge CFDictionaryRef)qOld, &result);
    if (st == errSecSuccess && result) {
        NSData *d = (__bridge_transfer NSData *)result;
        return [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    }
    return nil;
}

- (BOOL)saveKeyToKeychain:(NSString *)key
{
    SecItemDelete((__bridge CFDictionaryRef)[self keychainQuery]);
    if (!key.length) return YES;
    NSMutableDictionary *q = [[self keychainQuery] mutableCopy];
    [q setObject:[key dataUsingEncoding:NSUTF8StringEncoding] forKey:(__bridge id)kSecValueData];
    OSStatus st = SecItemAdd((__bridge CFDictionaryRef)q, NULL);
    return st == errSecSuccess;
}

#pragma mark - Properties

- (NSString *)apiKey
{
    if (self.keyLoaded) return self.cachedKey;
    self.keyLoaded = YES;
    NSString *k = [self loadKeyFromKeychain];
    if (!k.length) k = [DEF stringForKey:kFallbackKey];
    self.cachedKey = k;
    return k;
}

- (void)setApiKey:(NSString *)apiKey
{
    NSString *clean = [apiKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.cachedKey = clean.length ? clean : nil;
    self.keyLoaded = YES;
    BOOL ok = [self saveKeyToKeychain:self.cachedKey];
    if (!ok || !self.cachedKey.length) {
        if (self.cachedKey.length) [DEF setObject:self.cachedKey forKey:kFallbackKey];
        else [DEF removeObjectForKey:kFallbackKey];
        [self save];
    } else {
        [DEF removeObjectForKey:kFallbackKey];
        [self save];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:PMAPIKeyDidChangeNotification object:self];
}

- (NSString *)apiKeyLabel
{
    return [DEF stringForKey:@"apiKeyLabel"] ?: @"";
}

- (void)setApiKeyLabel:(NSString *)apiKeyLabel
{
    [DEF setObject:apiKeyLabel ?: @"" forKey:@"apiKeyLabel"];
    [self save];
}

- (BOOL)hasAPIKey
{
    return self.apiKey.length > 0;
}

- (NSString *)preferredModelId
{
    return [DEF stringForKey:@"preferredModelId"];
}

- (void)setPreferredModelId:(NSString *)preferredModelId
{
    if (preferredModelId.length) [DEF setObject:preferredModelId forKey:@"preferredModelId"];
    else [DEF removeObjectForKey:@"preferredModelId"];
    [self save];
    [self notify];
}

- (BOOL)autoFallback
{
    return [DEF boolForKey:@"autoFallback"];
}

- (void)setAutoFallback:(BOOL)autoFallback
{
    [DEF setBool:autoFallback forKey:@"autoFallback"];
    [self save];
    [self notify];
}

- (BOOL)freeOnly
{
    return [DEF boolForKey:@"freeOnly"];
}

- (void)setFreeOnly:(BOOL)freeOnly
{
    [DEF setBool:freeOnly forKey:@"freeOnly"];
    [self save];
    [self notify];
}

- (NSDate *)lastModelsRefresh
{
    return [DEF objectForKey:@"lastModelsRefresh"];
}

- (void)setLastModelsRefresh:(NSDate *)lastModelsRefresh
{
    [DEF setObject:lastModelsRefresh forKey:@"lastModelsRefresh"];
    [self save];
}

- (BOOL)preferOfflineSolver
{
    return [DEF boolForKey:@"preferOfflineSolver"];
}

- (void)setPreferOfflineSolver:(BOOL)preferOfflineSolver
{
    [DEF setBool:preferOfflineSolver forKey:@"preferOfflineSolver"];
    [self save];
    [self notify];
}

- (BOOL)showStepByStep
{
    return [DEF boolForKey:@"showStepByStep"];
}

- (void)setShowStepByStep:(BOOL)showStepByStep
{
    [DEF setBool:showStepByStep forKey:@"showStepByStep"];
    [self save];
    [self notify];
}

- (NSString *)solutionLanguage
{
    return [DEF stringForKey:@"solutionLanguage"] ?: @"auto";
}

- (void)setSolutionLanguage:(NSString *)solutionLanguage
{
    [DEF setObject:solutionLanguage ?: @"auto" forKey:@"solutionLanguage"];
    [self save];
    [self notify];
}

- (BOOL)darkTheme
{
    return [DEF boolForKey:@"darkTheme"];
}

- (void)setDarkTheme:(BOOL)darkTheme
{
    [DEF setBool:darkTheme forKey:@"darkTheme"];
    [self save];
    [[NSNotificationCenter defaultCenter] postNotificationName:PMThemeDidChangeNotification object:self];
}

- (BOOL)verifyTLS
{
    return [DEF boolForKey:@"verifyTLS"];
}

- (void)setVerifyTLS:(BOOL)verifyTLS
{
    [DEF setBool:verifyTLS forKey:@"verifyTLS"];
    [self save];
}

- (BOOL)hapticFeedback
{
    return [DEF boolForKey:@"hapticFeedback"];
}

- (void)setHapticFeedback:(BOOL)hapticFeedback
{
    [DEF setBool:hapticFeedback forKey:@"hapticFeedback"];
    [self save];
}

@end
