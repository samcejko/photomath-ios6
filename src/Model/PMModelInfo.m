#import "PMLegacyCollections.h"
#import "PMModelInfo.h"

@implementation PMModelInfo

+ (instancetype)modelWithJSON:(NSDictionary *)json
{
    if (![json isKindOfClass:[NSDictionary class]]) return nil;
    NSString *mid = [json objectForKey:@"id"];
    if (![mid isKindOfClass:[NSString class]] || !mid.length) return nil;

    PMModelInfo *m = [[PMModelInfo alloc] init];
    m.modelId = mid;
    m.name = [[json objectForKey:@"name"] isKindOfClass:[NSString class]] ? [json objectForKey:@"name"] : mid;
    m.modelDescription = [[json objectForKey:@"description"] isKindOfClass:[NSString class]] ? [json objectForKey:@"description"] : @"";

    NSDictionary *pricing = [json objectForKey:@"pricing"];
    if ([pricing isKindOfClass:[NSDictionary class]]) {
        m.promptPrice = [pricing objectForKey:@"prompt"];
        m.completionPrice = [pricing objectForKey:@"completion"];
    }

    NSNumber *ctx = [json objectForKey:@"context_length"];
    m.contextLength = [ctx isKindOfClass:[NSNumber class]] ? [ctx integerValue] : 4096;

    // Detect image input support (multimodal vision)
    BOOL hasImages = NO;
    NSDictionary *arch = [json objectForKey:@"architecture"];
    if ([arch isKindOfClass:[NSDictionary class]]) {
        NSString *modality = [arch objectForKey:@"modality"];
        if ([modality isKindOfClass:[NSString class]] &&
            ([modality rangeOfString:@"image" options:NSCaseInsensitiveSearch].location != NSNotFound ||
             [modality rangeOfString:@"multimodal" options:NSCaseInsensitiveSearch].location != NSNotFound)) {
            hasImages = YES;
        }
        NSArray *inMods = [arch objectForKey:@"input_modalities"];
        if ([inMods isKindOfClass:[NSArray class]]) {
            for (id item in inMods) {
                if ([item isKindOfClass:[NSString class]] &&
                    ([item rangeOfString:@"image" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                     [item rangeOfString:@"vision" options:NSCaseInsensitiveSearch].location != NSNotFound)) {
                    hasImages = YES;
                    break;
                }
            }
        }
    }
    // Fallback detection from id / name if architecture was omitted
    if (!hasImages) {
        NSString *lower = [mid lowercaseString];
        if ([lower rangeOfString:@"-vl"].location != NSNotFound ||
            [lower rangeOfString:@"vision"].location != NSNotFound ||
            [lower rangeOfString:@"gemini"].location != NSNotFound ||
            [lower rangeOfString:@"gpt-4o"].location != NSNotFound ||
            [lower rangeOfString:@"claude-3"].location != NSNotFound ||
            [lower rangeOfString:@"pixtral"].location != NSNotFound) {
            hasImages = YES;
        }
    }
    m.supportsImages = hasImages;

    // Content safety / moderation detection
    // Exclude models designed as safety/guardrail classifiers or heavy censorship filters
    BOOL isSafety = NO;
    NSString *lowerId = [mid lowercaseString];
    NSString *lowerName = [m.name lowercaseString];
    NSString *lowerDesc = [m.modelDescription lowercaseString];

    NSArray *safetyKeywords = @[
        @"guard", @"safety", @"moderation", @"shield",
        @"llamaguard", @"omni-moderation", @"shieldgemma",
        @"content-filter", @"audit", @"censored"
    ];

    for (NSString *kw in safetyKeywords) {
        if ([lowerId rangeOfString:kw].location != NSNotFound ||
            [lowerName rangeOfString:kw].location != NSNotFound ||
            [lowerDesc rangeOfString:kw].location != NSNotFound) {
            isSafety = YES;
            break;
        }
    }
    m.isContentSafetyModel = isSafety;

    return m;
}

- (BOOL)isFree
{
    double p = [self.promptPrice doubleValue];
    double c = [self.completionPrice doubleValue];
    return (p <= 0.0 && c <= 0.0) || [self.modelId hasSuffix:@":free"];
}

- (NSString *)displayName
{
    if (self.name.length && ![self.name isEqualToString:self.modelId]) {
        return self.name;
    }
    NSArray *parts = [self.modelId componentsSeparatedByString:@"/"];
    return parts.lastObject ?: self.modelId;
}

- (NSDictionary *)toJSON
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    PMSetDictionaryObject(dict, @"id", self.modelId ?: @"");
    PMSetDictionaryObject(dict, @"name", self.name ?: @"");
    PMSetDictionaryObject(dict, @"description", self.modelDescription ?: @"");
    if (self.promptPrice) PMSetDictionaryObject(dict, @"pricing", @{ @"prompt": self.promptPrice, @"completion": self.completionPrice ?: @0 });
    PMSetDictionaryObject(dict, @"context_length", @(self.contextLength));
    PMSetDictionaryObject(dict, @"architecture", @{ @"modality": self.supportsImages ? @"text+image->text" : @"text->text" });
    return dict;
}

@end
