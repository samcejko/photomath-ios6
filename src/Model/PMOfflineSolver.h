#import <Foundation/Foundation.h>
#import "PMMathSolution.h"

// Parsed once, evaluated repeatedly without network access or generated code.
@interface PMGraphFunction : NSObject
@property(nonatomic, copy, readonly) NSString *expression;
- (double)valueAtX:(double)x;
@end

@interface PMOfflineSolver : NSObject

/**
 * Checks if the given LaTeX or plain math expression can be solved offline.
 */
+ (BOOL)canSolveProblem:(NSString *)problemLatex;

/**
 * Solves the equation or expression offline and returns a complete PMMathSolution
 * with step-by-step explanations, or nil with an error if unsolvable.
 */
+ (PMMathSolution *)solveProblem:(NSString *)problemLatex error:(NSError **)error;

+ (PMGraphFunction *)graphFunctionForProblem:(NSString *)problemLatex;

@end
