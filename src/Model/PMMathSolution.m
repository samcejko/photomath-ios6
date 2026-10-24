#import <UIKit/UIKit.h>
#import "PMLegacyCollections.h"
#import "PMCommon.h"
#import "PMMathSolution.h"
#import "PMUtils.h"

@implementation PMStep

+ (instancetype)stepWithJSON:(NSDictionary *)json index:(NSInteger)index
{
    if (![json isKindOfClass:[NSDictionary class]]) return nil;
    PMStep *s = [[PMStep alloc] init];
    NSNumber *num = [json objectForKey:@"step_number"] ?: [json objectForKey:@"step"];
    s.stepNumber = [num isKindOfClass:[NSNumber class]] ? [num integerValue] : index;
    s.title = [json objectForKey:@"title"] ?: [NSString stringWithFormat:@"Step %ld", (long)s.stepNumber];
    s.latex = [json objectForKey:@"latex"] ?: [json objectForKey:@"expression"] ?: @"";
    s.explanation = [json objectForKey:@"explanation"] ?: [json objectForKey:@"description"] ?: @"";
    return s;
}

- (NSDictionary *)toJSON
{
    return @{
        @"step_number": @(self.stepNumber),
        @"title": self.title ?: @"",
        @"latex": self.latex ?: @"",
        @"explanation": self.explanation ?: @"",
    };
}

@end

@implementation PMMathSolution

+ (instancetype)solutionFromJSON:(NSDictionary *)json modelUsed:(NSString *)model image:(UIImage *)image
{
    if (![json isKindOfClass:[NSDictionary class]]) return nil;
    PMMathSolution *sol = [[PMMathSolution alloc] init];
    sol.solutionId = [PMUtils base64EncodeData:[PMUniqueIdentifier() dataUsingEncoding:NSUTF8StringEncoding]];
    sol.date = [NSDate date];
    sol.modelUsed = model ?: @"";

    sol.problemLatex = [json objectForKey:@"problem_latex"] ?: [json objectForKey:@"problem"] ?: [json objectForKey:@"equation"] ?: @"";
    sol.solutionLatex = [json objectForKey:@"solution_latex"] ?: [json objectForKey:@"solution"] ?: [json objectForKey:@"result"] ?: [json objectForKey:@"answer"] ?: @"";
    sol.summary = [json objectForKey:@"summary"] ?: @"";

    NSArray *rawSteps = [json objectForKey:@"steps"];
    NSMutableArray *steps = [NSMutableArray array];
    if ([rawSteps isKindOfClass:[NSArray class]]) {
        NSInteger idx = 1;
        for (id st in rawSteps) {
            PMStep *step = [PMStep stepWithJSON:st index:idx++];
            if (step) [steps addObject:step];
        }
    }
    sol.steps = steps;

    if (image) {
        NSString *filename = [NSString stringWithFormat:@"img_%@.jpg", @([sol.date timeIntervalSince1970])];
        NSString *fullPath = [[PMUtils historyPath] stringByAppendingPathComponent:filename];
        NSData *jpg = [PMUtils jpegDataForImage:image maxDimension:800 quality:0.75f];
        [jpg writeToFile:fullPath atomically:YES];
        sol.imagePath = filename;
    }

    return sol;
}

+ (instancetype)solutionFromDictionary:(NSDictionary *)dict
{
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;
    PMMathSolution *sol = [[PMMathSolution alloc] init];
    sol.solutionId = [dict objectForKey:@"id"] ?: @"";
    NSNumber *ts = [dict objectForKey:@"date"];
    sol.date = [ts isKindOfClass:[NSNumber class]] ? [NSDate dateWithTimeIntervalSince1970:[ts doubleValue]] : [NSDate date];
    sol.problemLatex = [dict objectForKey:@"problem_latex"] ?: @"";
    sol.solutionLatex = [dict objectForKey:@"solution_latex"] ?: @"";
    sol.summary = [dict objectForKey:@"summary"] ?: @"";
    sol.modelUsed = [dict objectForKey:@"model_used"] ?: @"";
    sol.imagePath = [dict objectForKey:@"image_path"];

    NSArray *rawSteps = [dict objectForKey:@"steps"];
    NSMutableArray *steps = [NSMutableArray array];
    if ([rawSteps isKindOfClass:[NSArray class]]) {
        NSInteger idx = 1;
        for (id st in rawSteps) {
            PMStep *step = [PMStep stepWithJSON:st index:idx++];
            if (step) [steps addObject:step];
        }
    }
    sol.steps = steps;
    return sol;
}

- (NSDictionary *)toDictionary
{
    NSMutableArray *arr = [NSMutableArray array];
    for (PMStep *s in self.steps) {
        [arr addObject:[s toJSON]];
    }
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    PMSetDictionaryObject(d, @"id", self.solutionId ?: @"");
    PMSetDictionaryObject(d, @"date", @([self.date timeIntervalSince1970]));
    PMSetDictionaryObject(d, @"problem_latex", self.problemLatex ?: @"");
    PMSetDictionaryObject(d, @"solution_latex", self.solutionLatex ?: @"");
    PMSetDictionaryObject(d, @"summary", self.summary ?: @"");
    PMSetDictionaryObject(d, @"model_used", self.modelUsed ?: @"");
    if (self.imagePath) PMSetDictionaryObject(d, @"image_path", self.imagePath);
    PMSetDictionaryObject(d, @"steps", arr);
    return d;
}

- (UIImage *)loadImage
{
    if (!self.imagePath.length) return nil;
    NSString *full = [[PMUtils historyPath] stringByAppendingPathComponent:self.imagePath];
    return [UIImage imageWithContentsOfFile:full];
}

@end
