#import <Foundation/Foundation.h>

@interface PMModelInfo : NSObject

+ (instancetype)modelWithJSON:(NSDictionary *)json;

@property (nonatomic, copy) NSString *modelId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *modelDescription;
@property (nonatomic, strong) NSNumber *promptPrice;
@property (nonatomic, strong) NSNumber *completionPrice;
@property (nonatomic) NSInteger contextLength;
@property (nonatomic) BOOL supportsImages;
@property (nonatomic) BOOL isContentSafetyModel;

- (BOOL)isFree;
- (NSString *)displayName;
- (NSDictionary *)toJSON;

@end
