#import "PMCommon.h"
#import "PMMathSolution.h"
#import "PMUtils.h"

@implementation PMStep

+ (instancetype)stepWithJSON:(NSDictionary *)json index:(NSInteger)index
{
    if (![json isKindOfClass:[NSDictionary class]]) return nil;
    PMStep *s = [[PMStep alloc] init];
    NSNumber *num = json[@"step_number"] ?: json[@"step"];
    s.stepNumber = [num isKindOfClass:[NSNumber class]] ? [num integerValue] : index;
    s.title = json[@"title"] ?: [NSString stringWithFormat:@"Step %ld", (long)s.stepNumber];
    s.latex = json[@"latex"] ?: json[@"expression"] ?: @"";
    s.explanation = json[@"explanation"] ?: json[@"description"] ?: @"";
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

    sol.problemLatex = json[@"problem_latex"] ?: json[@"problem"] ?: json[@"equation"] ?: @"";
    sol.solutionLatex = json[@"solution_latex"] ?: json[@"solution"] ?: json[@"result"] ?: json[@"answer"] ?: @"";
    sol.summary = json[@"summary"] ?: @"";

    NSArray *rawSteps = json[@"steps"];
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
    sol.solutionId = dict[@"id"] ?: @"";
    NSNumber *ts = dict[@"date"];
    sol.date = [ts isKindOfClass:[NSNumber class]] ? [NSDate dateWithTimeIntervalSince1970:[ts doubleValue]] : [NSDate date];
    sol.problemLatex = dict[@"problem_latex"] ?: @"";
    sol.solutionLatex = dict[@"solution_latex"] ?: @"";
    sol.summary = dict[@"summary"] ?: @"";
    sol.modelUsed = dict[@"model_used"] ?: @"";
    sol.imagePath = dict[@"image_path"];

    NSArray *rawSteps = dict[@"steps"];
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
    d[@"id"] = self.solutionId ?: @"";
    d[@"date"] = @([self.date timeIntervalSince1970]);
    d[@"problem_latex"] = self.problemLatex ?: @"";
    d[@"solution_latex"] = self.solutionLatex ?: @"";
    d[@"summary"] = self.summary ?: @"";
    d[@"model_used"] = self.modelUsed ?: @"";
    if (self.imagePath) d[@"image_path"] = self.imagePath;
    d[@"steps"] = arr;
    return d;
}

- (UIImage *)loadImage
{
    if (!self.imagePath.length) return nil;
    NSString *full = [[PMUtils historyPath] stringByAppendingPathComponent:self.imagePath];
    return [UIImage imageWithContentsOfFile:full];
}

@end
