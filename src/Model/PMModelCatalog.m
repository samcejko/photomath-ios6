#import "PMModelCatalog.h"
#import "PMOpenRouterClient.h"
#import "PMSettings.h"
#import "PMUtils.h"
#import "PMCommon.h"

static const NSTimeInterval kStaleInterval = 12 * 60 * 60; // 12 hours

@interface PMModelCatalog ()
@property (nonatomic, strong) NSArray *models;
@property (nonatomic, strong) NSDictionary *byId;
@property (nonatomic, strong) NSDate *lastUpdated;
@property (nonatomic) BOOL isRefreshing;
@property (nonatomic, strong) NSMutableArray *pendingCompletions;
@end

@implementation PMModelCatalog

+ (instancetype)shared
{
    static PMModelCatalog *c = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [[PMModelCatalog alloc] init]; });
    return c;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _models = @[];
        _byId = @{};
        _pendingCompletions = [NSMutableArray array];
        [self loadCache];
    }
    return self;
}

- (NSString *)cacheFile
{
    return [[PMUtils cachesPath] stringByAppendingPathComponent:@"models.json"];
}

- (BOOL)hasModels
{
    return self.models.count > 0;
}

- (void)setModelsFromJSONArray:(NSArray *)array
{
    NSMutableArray *list = [NSMutableArray arrayWithCapacity:array.count];
    NSMutableDictionary *map = [NSMutableDictionary dictionaryWithCapacity:array.count];
    for (id item in array) {
        PMModelInfo *m = [PMModelInfo modelWithJSON:item];
        if (!m) continue;
        [list addObject:m];
        map[m.modelId] = m;
    }
    [list sortUsingComparator:^NSComparisonResult(PMModelInfo *a, PMModelInfo *b) {
        return [[a displayName] compare:[b displayName] options:NSCaseInsensitiveSearch];
    }];
    self.models = list;
    self.byId = map;
}

- (void)loadCache
{
    NSData *data = [NSData dataWithContentsOfFile:[self cacheFile]];
    id json = [PMUtils JSONObjectFromData:data];
    if ([json isKindOfClass:[NSDictionary class]]) {
        NSArray *arr = json[@"data"];
        if ([arr isKindOfClass:[NSArray class]]) {
            [self setModelsFromJSONArray:arr];
            NSNumber *ts = json[@"updated"];
            if ([ts isKindOfClass:[NSNumber class]]) {
                self.lastUpdated = [NSDate dateWithTimeIntervalSince1970:[ts doubleValue]];
            }
            PMLog(@"Loaded %lu models from cache", (unsigned long)self.models.count);
        }
    }
}

- (void)writeCache
{
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:self.models.count];
    for (PMModelInfo *m in self.models) {
        [arr addObject:[m toJSON]];
    }
    NSDictionary *doc = @{
        @"data": arr,
        @"updated": @([self.lastUpdated timeIntervalSince1970])
    };
    NSData *data = [PMUtils JSONDataFromObject:doc];
    NSString *file = [self cacheFile];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [data writeToFile:file atomically:YES];
    });
}

- (void)refreshIfStale
{
    if (self.isRefreshing) return;
    if (!self.hasModels || !self.lastUpdated || -[self.lastUpdated timeIntervalSinceNow] > kStaleInterval) {
        [self refreshWithCompletion:nil];
    }
}

- (void)refreshWithCompletion:(void (^)(NSError *))completion
{
    if (completion) [self.pendingCompletions addObject:[completion copy]];
    if (self.isRefreshing) return;
    self.isRefreshing = YES;

    [[PMOpenRouterClient shared] fetchModels:^(NSArray *modelsJSON, NSError *error) {
        self.isRefreshing = NO;
        if (!error && modelsJSON.count > 0) {
            [self setModelsFromJSONArray:modelsJSON];
            self.lastUpdated = [NSDate date];
            [PMSettings shared].lastModelsRefresh = self.lastUpdated;
            [self writeCache];
            [[NSNotificationCenter defaultCenter] postNotificationName:PMModelsDidUpdateNotification object:self];
        } else if (!error) {
            error = PMMakeError(PMErrorBadResponse, L(@"Model catalog was empty."));
        }
        NSArray *pending = [self.pendingCompletions copy];
        [self.pendingCompletions removeAllObjects];
        for (void (^cb)(NSError *) in pending) cb(error);
    }];
}

- (PMModelInfo *)modelWithId:(NSString *)modelId
{
    if (!modelId.length) return nil;
    return self.byId[modelId];
}

- (NSArray *)validVisionModels
{
    NSMutableArray *freeVision = [NSMutableArray array];
    NSMutableArray *paidVision = [NSMutableArray array];

    for (PMModelInfo *m in self.models) {
        // Must support vision/images
        if (!m.supportsImages) continue;
        // Strictly avoid content safety / moderation models as requested
        if (m.isContentSafetyModel) continue;

        if ([m isFree]) {
            [freeVision addObject:m];
        } else {
            [paidVision addObject:m];
        }
    }

    // Sort free vision models by context length descending (longer context usually higher quality)
    [freeVision sortUsingComparator:^NSComparisonResult(PMModelInfo *a, PMModelInfo *b) {
        if (a.contextLength == b.contextLength) {
            return [[a displayName] compare:[b displayName] options:NSCaseInsensitiveSearch];
        }
        return a.contextLength > b.contextLength ? NSOrderedAscending : NSOrderedDescending;
    }];

    // Sort paid vision models by prompt price ascending
    [paidVision sortUsingComparator:^NSComparisonResult(PMModelInfo *a, PMModelInfo *b) {
        double pa = [a.promptPrice doubleValue];
        double pb = [b.promptPrice doubleValue];
        if (pa == pb) {
            return [[a displayName] compare:[b displayName] options:NSCaseInsensitiveSearch];
        }
        return pa < pb ? NSOrderedAscending : NSOrderedDescending;
    }];

    NSMutableArray *combined = [NSMutableArray arrayWithCapacity:freeVision.count + paidVision.count];
    [combined addObjectsFromArray:freeVision];
    [combined addObjectsFromArray:paidVision];
    return combined;
}

- (NSArray *)fallbackChainStartingWithModelId:(NSString *)preferredId
{
    NSArray *allVision = [self validVisionModels];
    if (!allVision.count) return @[];

    NSMutableArray *chain = [NSMutableArray array];
    PMModelInfo *first = nil;

    if (preferredId.length) {
        PMModelInfo *match = [self modelWithId:preferredId];
        if (match && match.supportsImages && !match.isContentSafetyModel) {
            first = match;
            [chain addObject:first];
        }
    }

    if (!first && allVision.count > 0) {
        first = allVision[0];
        [chain addObject:first];
    }

    // Append other distinct live vision models from catalog up to 6 models
    for (PMModelInfo *m in allVision) {
        if (chain.count >= 6) break;
        if (![m.modelId isEqualToString:first.modelId]) {
            [chain addObject:m];
        }
    }

    return chain;
}

- (PMModelInfo *)bestVisionModel
{
    NSArray *models = [self validVisionModels];
    return models.count ? models[0] : nil;
}

@end
