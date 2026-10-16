#import <Foundation/Foundation.h>
#import "PMModelInfo.h"

@interface PMModelCatalog : NSObject

+ (instancetype)shared;

- (void)loadCache;
- (void)refreshIfStale;
- (void)refreshWithCompletion:(void (^)(NSError *error))completion;

@property (nonatomic, readonly) BOOL hasModels;
@property (nonatomic, strong, readonly) NSDate *lastUpdated;

// Filtered models: vision capable and strictly excluding content-safety models
- (NSArray *)validVisionModels;

// Dynamic fallback chain: generates an ordered sequence of live models to try,
// beginning with preferredId (or top vision model), avoiding content-safety models.
// No static models are hardcoded.
- (NSArray *)fallbackChainStartingWithModelId:(NSString *)preferredId;

- (PMModelInfo *)bestVisionModel;
- (PMModelInfo *)modelWithId:(NSString *)modelId;

@end
