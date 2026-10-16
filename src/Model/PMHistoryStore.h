#import <Foundation/Foundation.h>
#import "PMMathSolution.h"

@interface PMHistoryStore : NSObject

+ (instancetype)shared;

@property (nonatomic, strong, readonly) NSArray *solutions; // Array of PMMathSolution, newest first

- (void)loadHistory;
- (void)addSolution:(PMMathSolution *)solution;
- (void)removeSolution:(PMMathSolution *)solution;
- (void)clearHistory;

@end
