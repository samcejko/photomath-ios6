#import <Foundation/Foundation.h>

@interface PMSettings : NSObject

+ (instancetype)shared;

// API Key (stored in Keychain with NSUserDefaults fallback)
@property (nonatomic, copy) NSString *apiKey;
@property (nonatomic, copy) NSString *apiKeyLabel;
- (BOOL)hasAPIKey;

// Import from AIChat (com.samcejko.aichat)
+ (NSString *)availableAIChatAPIKey;
+ (BOOL)hasAIChatAPIKey;

// Model & Fallback
@property (nonatomic, copy) NSString *preferredModelId; // nil = auto (use top dynamic vision model)
@property (nonatomic) BOOL autoFallback;                 // default YES
@property (nonatomic) BOOL freeOnly;                     // default NO (only use $0 vision models)
@property (nonatomic, strong) NSDate *lastModelsRefresh;

// Solver preferences
@property (nonatomic) BOOL preferOfflineSolver;          // default YES (instant on-device solver)
@property (nonatomic) BOOL showStepByStep;              // default YES
@property (nonatomic, copy) NSString *solutionLanguage; // @"auto", @"cs", @"en"

// Appearance & Feedback
@property (nonatomic) BOOL darkTheme;                   // default NO
@property (nonatomic) BOOL verifyTLS;                   // default YES
@property (nonatomic) BOOL hapticFeedback;              // default YES

@end
