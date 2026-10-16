#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "PMHTTPRequest.h"
#import "PMModelInfo.h"

typedef void (^PMJSONCompletion)(NSDictionary *json, NSError *error);

@interface PMOpenRouterClient : NSObject

+ (instancetype)shared;

// Fetch models catalog
- (PMHTTPRequest *)fetchModels:(void (^)(NSArray *models, NSError *error))completion;

// Validate API key and get credit balance
- (PMHTTPRequest *)fetchKeyInfoWithKey:(NSString *)apiKey completion:(PMJSONCompletion)completion;

// Single-model solve request
- (PMHTTPRequest *)solveProblemWithImage:(UIImage *)image
                             manualLatex:(NSString *)manualLatex
                                 modelId:(NSString *)modelId
                                language:(NSString *)language
                              completion:(PMJSONCompletion)completion;

// Dynamic model fallback solver: executes the request, trying models from the
// dynamically supplied fallbackChain in order until one succeeds or all fail.
- (void)solveProblemWithImage:(UIImage *)image
                  manualLatex:(NSString *)manualLatex
                fallbackChain:(NSArray *)modelChain
                     language:(NSString *)language
                   onFallback:(void (^)(PMModelInfo *failedModel, NSError *error, PMModelInfo *nextModel))onFallback
                   completion:(void (^)(NSDictionary *solutionJSON, PMModelInfo *succeededModel, NSError *error))completion;

+ (NSError *)errorFromResponseJSON:(id)json status:(NSInteger)status;
+ (NSString *)hintForHTTPStatus:(NSInteger)status;

@end
