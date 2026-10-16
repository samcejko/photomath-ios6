#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface PMStep : NSObject

@property (nonatomic) NSInteger stepNumber;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *latex;
@property (nonatomic, copy) NSString *explanation;

+ (instancetype)stepWithJSON:(NSDictionary *)json index:(NSInteger)index;
- (NSDictionary *)toJSON;

@end

@interface PMMathSolution : NSObject

@property (nonatomic, copy) NSString *solutionId;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, copy) NSString *problemLatex;
@property (nonatomic, copy) NSString *solutionLatex;
@property (nonatomic, copy) NSString *summary;
@property (nonatomic, strong) NSArray *steps; // Array of PMStep
@property (nonatomic, copy) NSString *modelUsed;
@property (nonatomic, copy) NSString *imagePath;

+ (instancetype)solutionFromJSON:(NSDictionary *)json modelUsed:(NSString *)model image:(UIImage *)image;
+ (instancetype)solutionFromDictionary:(NSDictionary *)dict;

- (NSDictionary *)toDictionary;
- (UIImage *)loadImage;

@end
