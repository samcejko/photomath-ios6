#import <Foundation/Foundation.h>
#import "PMMathSolution.h"

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

@end
