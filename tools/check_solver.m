#import <Foundation/Foundation.h>
#import <math.h>
#import "PMOfflineSolver.h"
#import "PMSettings.h"
#import "PMMathEditing.h"

// The solver uses only these data objects and the language preference. Network,
// image persistence and UIKit are deliberately absent from this native test.
@implementation PMStep @end
@implementation PMMathSolution @end
@implementation PMSettings
+ (instancetype)shared { static PMSettings *settings; if(!settings){settings=[PMSettings new];settings.solutionLanguage=@"en";}return settings; }
@end
NSString *PMUniqueIdentifier(void) { return [[NSUUID UUID] UUIDString]; }

static NSUInteger checks;
static void Check(BOOL condition, NSString *message) {
    checks++;if(!condition){fprintf(stderr,"FAIL: %s\n",message.UTF8String);exit(1);}
}
static void Value(NSString *input,double x,double expected) {
    printf("Expression: %s\n",input.UTF8String);fflush(stdout);
    PMGraphFunction *graph=[PMOfflineSolver graphFunctionForProblem:input];
    Check(graph!=nil,[input stringByAppendingString:@" should parse"]);
    double result=[graph valueAtX:x];
    Check(isfinite(result) && fabs(result-expected)<=1e-10*MAX(1.0,fabs(expected)),[NSString stringWithFormat:@"%@ at %.3g -> %.12g (expected %.12g)",input,x,result,expected]);
}
int main(void) { @autoreleasepool {
    NSArray *numeric=@[@[@"2+3*4",@14],@[@"(2+3)*4",@20],@[@"-2^2",@-4],@[@"(-2)^2",@4],@[@"2^-3",@.125],@[@"2^3^2",@512],@[@"0!",@1],@[@"5!",@120],@[@"3,5+0,5",@4],@[@"1e3+2E-2",@1000.02],@[@"1e-8",@1e-8],@[@"1e-12",@1e-12],@[@"1/10000000000000",@1e-13],@[@"\\frac{1}{\\frac{2}{3}}",@1.5],@[@"\\sqrt{81}",@9],@[@"\\sqrt[3]{-8}",@-2],@[@"\\sin(\\pi/2)",@1],@[@"ln(e)",@1],@[@"abs(-3)",@3],@[@"| -3 |",@3],@[@"2(3+4)",@14],@[@"(2+3)4",@20],@[@"2| -3 |",@6]];
    for(NSArray *fixture in numeric) {
        NSString *input=[fixture objectAtIndex:0];double expected=[[fixture objectAtIndex:1] doubleValue];
        Value(input,0,expected);
        NSError *error=nil;PMMathSolution *solution=[PMOfflineSolver solveProblem:input error:&error];
        Check(solution && !error && solution.steps.count>0,[input stringByAppendingString:@" numeric solution"]);
        Check([PMOfflineSolver canSolveProblem:input],[input stringByAppendingString:@" capability"]);
    }
    for(NSString *input in @[@"2+3=",@"2+3=?",@"2x+5=15",@"x^2-5x+6=0",@"x^2-5x+6",@"x^3=-8",@"1e-12*x=1",@"x^4=16",@"5+3=8",@"5+3=9",@"y=sin(x)",@"sin(x)",@"1/x",@"f(x)=x^2+1"]) {
        NSError *error=nil;PMMathSolution *solution=[PMOfflineSolver solveProblem:input error:&error];
        Check(solution && !error && solution.solutionLatex.length,[input stringByAppendingString:@" solved"]);
    }
    Value(@"y=x^2+1",3,10);Value(@"x^2=4",2,0);Value(@"x^2=4",0,-4);Value(@"sin(x)",M_PI/2,1);Value(@"x(2+x)",3,15);Value(@"x2",3,6);
    for(NSString *input in @[@"",@".",@"2+",@"=2",@"2==3",@"()",@"(2+3",@"2+3)",@"1..2",@"2/**3",@"\\frac{}{}",@"\\sqrt{}",@"x+y=2",@"sin()",@"2e+",@"1e999",@"0/0",@"1/0",@"1%0",@"sqrt(-1)",@"ln(0)",@"asin(2)",@"(-1)!",@"171!",@"1e308*1e308",@"1e-320*x=1",@"x^5=2",@"1e-12*x^5=2",@"0.0000001!",@"\\int x dx"]) {
        NSError *error=nil;PMMathSolution *solution=[PMOfflineSolver solveProblem:input error:&error];
        Check(!solution && error!=nil,[input stringByAppendingString:@" rejected with explanation"]);
        Check(![PMOfflineSolver canSolveProblem:input],[input stringByAppendingString:@" unsupported capability"]);
    }
    PMGraphFunction *pole=[PMOfflineSolver graphFunctionForProblem:@"1/x"];
    Check(isnan([pole valueAtX:0]),@"division pole is a graph gap");
    PMGraphFunction *root=[PMOfflineSolver graphFunctionForProblem:@"sqrt(x)"];
    Check(isnan([root valueAtX:-1]),@"negative square root is a graph gap");
    for(NSString *input in @[@"x+y",@"y=",@"x=1=2",@"sin()",@"\\frac{}{}"])Check(![PMOfflineSolver graphFunctionForProblem:input],@"invalid graph rejected");
    for(NSString *input in @[[[@"(" stringByPaddingToLength:200 withString:@"(" startingAtIndex:0] stringByAppendingString:@"1"],[@"-" stringByPaddingToLength:1000 withString:@"-" startingAtIndex:0],[@"1+" stringByPaddingToLength:3000 withString:@"1+" startingAtIndex:0]]) {
        puts("Checking bounded input");fflush(stdout);NSError *error=nil;Check(![PMOfflineSolver solveProblem:input error:&error] && error!=nil,@"bounded input/depth");
    }
    Check([[PMMathEditing previewForLatex:@"\\frac{}{}"] isEqualToString:@"\\frac{\\square}{\\square}"],@"empty fraction is visible immediately");
    Check([[PMMathEditing previewForLatex:@"x^{}"] isEqualToString:@"x^{\\square}"],@"empty power is visible immediately");
    Check([[PMMathEditing previewForLatex:@"\\sqrt{"] isEqualToString:@"\\sqrt{\\square}"],@"unfinished root has preview placeholder");
    Check(![[PMOfflineSolver solveProblem:@"1e-12" error:NULL].solutionLatex isEqualToString:@"0"],@"1e-12 is not rounded to zero");
    Check([[PMOfflineSolver solveProblem:@"1e-12*x=1" error:NULL].solutionLatex rangeOfString:@"1000000000000"].location!=NSNotFound,@"small coefficient is retained");
    Check([[PMOfflineSolver solveProblem:@"1e-12=0" error:NULL].summary rangeOfString:@"false"].location!=NSNotFound,@"small unequal numbers are unequal");
    Check([[PMOfflineSolver solveProblem:@"0.1x+0.2x=0.3x" error:NULL].solutionLatex rangeOfString:@"mathbb"].location!=NSNotFound,@"cancellation preserves polynomial identities");
    unichar embeddedNUL[]={'1',0,'+','2'};NSError *nulError=nil;NSString *nulInput=[NSString stringWithCharacters:embeddedNUL length:4];
    Check(![PMOfflineSolver solveProblem:nulInput error:&nulError] && nulError!=nil,@"embedded NUL cannot truncate an expression");
    PMMathSolution *tiny=[PMOfflineSolver solveProblem:@"1e-8" error:NULL];Check(![tiny.solutionLatex isEqualToString:@"0"],@"small results retain significant digits");
    [PMSettings shared].solutionLanguage=@"cs";Check([[PMOfflineSolver solveProblem:@"2+2" error:NULL].summary rangeOfString:@"hodnota"].location!=NSNotFound,@"Czech solution");
    printf("Solver and graph checks passed: %lu\n",(unsigned long)checks);
} return 0; }
