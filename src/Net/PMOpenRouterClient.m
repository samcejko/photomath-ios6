#import "PMOpenRouterClient.h"
#import "PMSettings.h"
#import "PMUtils.h"
#import "PMCommon.h"

static NSString * const kHost = @"openrouter.ai";
static NSString * const kAppReferer = @"https://github.com/samcejko/shuttercalc-ios6";
static NSString * const kAppTitle = @"ShutterCalc for iOS 6";

@implementation PMOpenRouterClient

+ (instancetype)shared
{
    static PMOpenRouterClient *c = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [[PMOpenRouterClient alloc] init]; });
    return c;
}

- (NSDictionary *)headersWithKey:(NSString *)key accept:(NSString *)accept
{
    NSMutableDictionary *h = [NSMutableDictionary dictionary];
    if (key.length) h[@"Authorization"] = [@"Bearer " stringByAppendingString:key];
    h[@"Accept"] = accept ?: @"application/json";
    h[@"HTTP-Referer"] = kAppReferer;
    h[@"X-Title"] = kAppTitle;
    return h;
}

+ (NSString *)hintForHTTPStatus:(NSInteger)status
{
    switch (status) {
        case 401: return L(@"The API key was rejected. Check it in Settings.");
        case 402: return L(@"Not enough credits on your OpenRouter account.");
        case 403: return L(@"The request was blocked by moderation or permissions.");
        case 404: return L(@"Model not found. Try refreshing the model catalog.");
        case 408: return L(@"The request timed out. Try again.");
        case 413: return L(@"The image is too large. Viewfinder automatically crops.");
        case 429: return L(@"Rate limited. Free models allow 20 req/min; falling back to next model.");
        case 502: return L(@"Model provider returned an invalid response.");
        case 503: return L(@"No provider is available for this model right now.");
        default: return nil;
    }
}

+ (NSError *)errorFromResponseJSON:(id)json status:(NSInteger)status
{
    NSString *message = nil;
    NSInteger code = status;
    if ([json isKindOfClass:[NSDictionary class]]) {
        id err = json[@"error"];
        if ([err isKindOfClass:[NSDictionary class]]) {
            id msg = err[@"message"];
            if ([msg isKindOfClass:[NSString class]]) message = msg;
            id c = err[@"code"];
            if ([c isKindOfClass:[NSNumber class]]) code = [c integerValue];
            else if ([c isKindOfClass:[NSString class]] && [c integerValue] > 0) code = [c integerValue];
        } else if ([err isKindOfClass:[NSString class]]) {
            message = err;
        }
    }
    if (!message) message = [NSString stringWithFormat:L(@"Request failed (HTTP %ld)."), (long)status];
    NSString *hint = [self hintForHTTPStatus:code];
    if (hint) message = [NSString stringWithFormat:@"%@\n%@", message, hint];
    return PMMakeError(code > 0 ? code : PMErrorBadResponse, message);
}

#pragma mark - Models

- (PMHTTPRequest *)fetchModels:(void (^)(NSArray *, NSError *))completion
{
    PMHTTPRequest *req = [PMHTTPRequest requestWithMethod:@"GET" host:kHost path:@"/api/v1/models"];
    req.headers = [self headersWithKey:[PMSettings shared].apiKey accept:@"application/json"];
    req.readTimeout = 45;
    req.onComplete = ^(NSInteger status, NSData *body, NSError *error) {
        if (error) { completion(nil, error); return; }
        id json = [PMUtils JSONObjectFromData:body];
        if (status != 200) { completion(nil, [PMOpenRouterClient errorFromResponseJSON:json status:status]); return; }
        NSArray *data = [json isKindOfClass:[NSDictionary class]] ? json[@"data"] : nil;
        if (![data isKindOfClass:[NSArray class]]) {
            completion(nil, PMMakeError(PMErrorBadResponse, L(@"Unexpected model list format.")));
            return;
        }
        completion(data, nil);
    };
    [req start];
    return req;
}

#pragma mark - Key info

- (PMHTTPRequest *)fetchKeyInfoWithKey:(NSString *)apiKey completion:(PMJSONCompletion)completion
{
    PMHTTPRequest *req = [PMHTTPRequest requestWithMethod:@"GET" host:kHost path:@"/api/v1/key"];
    req.headers = [self headersWithKey:apiKey accept:@"application/json"];
    req.readTimeout = 30;
    req.onComplete = ^(NSInteger status, NSData *body, NSError *error) {
        if (error) { completion(nil, error); return; }
        id json = [PMUtils JSONObjectFromData:body];
        if (status != 200) { completion(nil, [PMOpenRouterClient errorFromResponseJSON:json status:status]); return; }
        NSDictionary *data = [json isKindOfClass:[NSDictionary class]] ? json[@"data"] : nil;
        if (![data isKindOfClass:[NSDictionary class]]) {
            completion(nil, PMMakeError(PMErrorBadResponse, L(@"Unexpected response format.")));
            return;
        }
        completion(data, nil);
    };
    [req start];
    return req;
}

#pragma mark - Solve Math Problem

static NSDictionary *PMExtractJSON(NSString *rawText)
{
    if (!rawText.length) return nil;
    NSString *cleaned = rawText;

    // Remove markdown code fences ```json ... ```
    NSRange fence = [cleaned rangeOfString:@"```json"];
    if (fence.location != NSNotFound) {
        cleaned = [cleaned substringFromIndex:fence.location + 7];
        NSRange endFence = [cleaned rangeOfString:@"```"];
        if (endFence.location != NSNotFound) {
            cleaned = [cleaned substringToIndex:endFence.location];
        }
    } else {
        fence = [cleaned rangeOfString:@"```"];
        if (fence.location != NSNotFound) {
            cleaned = [cleaned substringFromIndex:fence.location + 3];
            NSRange endFence = [cleaned rangeOfString:@"```"];
            if (endFence.location != NSNotFound) {
                cleaned = [cleaned substringToIndex:endFence.location];
            }
        }
    }

    // Isolate outer { ... }
    NSRange firstBrace = [cleaned rangeOfString:@"{"];
    NSRange lastBrace = [cleaned rangeOfString:@"}" options:NSBackwardsSearch];
    if (firstBrace.location != NSNotFound && lastBrace.location != NSNotFound && lastBrace.location > firstBrace.location) {
        cleaned = [cleaned substringWithRange:NSMakeRange(firstBrace.location, lastBrace.location - firstBrace.location + 1)];
    }

    NSData *data = [cleaned dataUsingEncoding:NSUTF8StringEncoding];
    id json = [PMUtils JSONObjectFromData:data];
    return [json isKindOfClass:[NSDictionary class]] ? (NSDictionary *)json : nil;
}

- (PMHTTPRequest *)solveProblemWithImage:(UIImage *)image
                             manualLatex:(NSString *)manualLatex
                                 modelId:(NSString *)modelId
                                language:(NSString *)language
                              completion:(PMJSONCompletion)completion
{
    if (!modelId.length) {
        completion(nil, PMMakeError(PMErrorNoModel, L(@"No model selected for solving.")));
        return nil;
    }

    NSString *apiKey = [PMSettings shared].apiKey;
    if (!apiKey.length) {
        completion(nil, PMMakeError(PMErrorNoAPIKey, L(@"Please enter your OpenRouter API key in Settings.")));
        return nil;
    }

    NSString *langPrompt = @"English";
    if ([language isEqualToString:@"cs"] || ([language isEqualToString:@"auto"] && [[[NSLocale preferredLanguages] firstObject] hasPrefix:@"cs"])) {
        langPrompt = @"Czech (čeština)";
    }

    NSString *systemPrompt = [NSString stringWithFormat:
        @"You are an expert mathematical problem solver and OCR system for students.\n"
        @"Recognize and solve the math problem with highest precision.\n"
        @"Output ONLY a raw, valid JSON object (no markdown, no backticks, no text before or after), with this schema:\n"
        @"{\n"
        @"  \"problem_latex\": \"original problem in standard LaTeX (e.g. 2x + 5 = 15 or \\\\frac{3}{4} + \\\\frac{1}{2})\",\n"
        @"  \"solution_latex\": \"final answer or result in LaTeX (e.g. x = 5)\",\n"
        @"  \"summary\": \"concise 1-sentence summary of the result in %@\",\n"
        @"  \"steps\": [\n"
        @"    {\n"
        @"      \"step_number\": 1,\n"
        @"      \"title\": \"Title of step in %@\",\n"
        @"      \"latex\": \"Mathematical transformation in LaTeX\",\n"
        @"      \"explanation\": \"Clear educational explanation of why this step was taken in %@\"\n"
        @"    }\n"
        @"  ]\n"
        @"}\n"
        @"Always escape backslashes in JSON (e.g. \\\\frac, \\\\sqrt). Write explanations in %@.",
        langPrompt, langPrompt, langPrompt, langPrompt];

    NSMutableArray *userContent = [NSMutableArray array];
    if (manualLatex.length) {
        [userContent addObject:@{
            @"type": @"text",
            @"text": [NSString stringWithFormat:@"Please solve this equation step by step: %@", manualLatex]
        }];
    } else {
        [userContent addObject:@{
            @"type": @"text",
            @"text": @"Please read and solve the mathematical problem shown in this image step by step."
        }];
    }

    if (image) {
        NSData *jpg = [PMUtils jpegDataForImage:image maxDimension:960 quality:0.75f];
        if (jpg) {
            NSString *dataUrl = [PMUtils dataURLWithMime:@"image/jpeg" data:jpg];
            [userContent addObject:@{
                @"type": @"image_url",
                @"image_url": @{ @"url": dataUrl }
            }];
        }
    }

    NSArray *messages = @[
        @{ @"role": @"system", @"content": systemPrompt },
        @{ @"role": @"user", @"content": userContent }
    ];

    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    body[@"model"] = modelId;
    body[@"messages"] = messages;
    body[@"temperature"] = @(0.1);
    body[@"max_tokens"] = @(2048);

    NSData *bodyData = [PMUtils JSONDataFromObject:body];
    PMHTTPRequest *req = [PMHTTPRequest requestWithMethod:@"POST" host:kHost path:@"/api/v1/chat/completions"];
    req.headers = [self headersWithKey:apiKey accept:@"application/json"];
    req.body = bodyData;
    req.readTimeout = 75;

    req.onComplete = ^(NSInteger status, NSData *respBody, NSError *error) {
        if (error) { completion(nil, error); return; }
        id json = [PMUtils JSONObjectFromData:respBody];
        if (status != 200) {
            completion(nil, [PMOpenRouterClient errorFromResponseJSON:json status:status]);
            return;
        }

        NSArray *choices = [json isKindOfClass:[NSDictionary class]] ? json[@"choices"] : nil;
        NSDictionary *firstChoice = choices.count ? choices[0] : nil;
        NSDictionary *msg = firstChoice[@"message"];
        NSString *rawContent = msg[@"content"];

        if (!rawContent.length) {
            completion(nil, PMMakeError(PMErrorBadResponse, L(@"The model returned an empty response.")));
            return;
        }

        NSDictionary *solution = PMExtractJSON(rawContent);
        if (!solution || (!solution[@"solution_latex"] && !solution[@"solution"])) {
            PMLog(@"Failed to parse math JSON from:\n%@", rawContent);
            completion(nil, PMMakeError(PMErrorBadResponse, L(@"Could not parse mathematical solution from model output.")));
            return;
        }

        completion(solution, nil);
    };

    [req start];
    return req;
}

#pragma mark - Dynamic Fallback Resolver

- (void)solveProblemWithImage:(UIImage *)image
                  manualLatex:(NSString *)manualLatex
                fallbackChain:(NSArray *)modelChain
                     language:(NSString *)language
                   onFallback:(void (^)(PMModelInfo *, NSError *, PMModelInfo *))onFallback
                   completion:(void (^)(NSDictionary *, PMModelInfo *, NSError *))completion
{
    if (!modelChain.count) {
        completion(nil, nil, PMMakeError(PMErrorNoModel, L(@"No suitable vision models available in catalog.")));
        return;
    }

    [self trySolveWithChain:modelChain
                      index:0
                      image:image
                manualLatex:manualLatex
                   language:language
                 onFallback:onFallback
                 completion:completion];
}

- (void)trySolveWithChain:(NSArray *)chain
                    index:(NSUInteger)index
                    image:(UIImage *)image
              manualLatex:(NSString *)manualLatex
                 language:(NSString *)language
               onFallback:(void (^)(PMModelInfo *, NSError *, PMModelInfo *))onFallback
               completion:(void (^)(NSDictionary *, PMModelInfo *, NSError *))completion
{
    if (index >= chain.count) {
        completion(nil, nil, PMMakeError(PMErrorAllModelsFailed, L(@"All attempted vision models failed. Check your network or OpenRouter account.")));
        return;
    }

    PMModelInfo *currentModel = chain[index];
    PMLog(@"Attempting solution with model [%lu/%lu]: %@", (unsigned long)(index + 1), (unsigned long)chain.count, currentModel.modelId);

    [self solveProblemWithImage:image
                    manualLatex:manualLatex
                        modelId:currentModel.modelId
                       language:language
                     completion:^(NSDictionary *json, NSError *error) {
        if (!error && json) {
            PMLog(@"Model %@ succeeded!", currentModel.modelId);
            completion(json, currentModel, nil);
        } else {
            PMLog(@"Model %@ failed: %@", currentModel.modelId, error.localizedDescription);
            if (index + 1 < chain.count && [PMSettings shared].autoFallback) {
                PMModelInfo *nextModel = chain[index + 1];
                if (onFallback) {
                    onFallback(currentModel, error, nextModel);
                }
                // Try next model in dynamic chain
                [self trySolveWithChain:chain
                                  index:index + 1
                                  image:image
                            manualLatex:manualLatex
                               language:language
                             onFallback:onFallback
                             completion:completion];
            } else {
                completion(nil, currentModel, error);
            }
        }
    }];
}

@end
