#import "PMOfflineSolver.h"
#import "PMSettings.h"
#import "PMCommon.h"
#import <math.h>
#import <ctype.h>

#pragma mark - Exact Fractions

typedef struct {
    long long num;
    long long den;
} PMFraction;

static long long gcd64(long long a, long long b) {
    if (a < 0) a = -a;
    if (b < 0) b = -b;
    while (b != 0) {
        long long t = b;
        b = a % b;
        a = t;
    }
    return a;
}

static PMFraction PMFractionMake(long long n, long long d) {
    if (d == 0) return (PMFraction){ 0, 0 };
    if (d < 0) { n = -n; d = -d; }
    long long g = gcd64(n, d);
    if (g > 1) { n /= g; d /= g; }
    return (PMFraction){ n, d };
}

static PMFraction PMFractionAdd(PMFraction a, PMFraction b) {
    if (a.den == 0 || b.den == 0) return (PMFraction){ 0, 0 };
    long long g = gcd64(a.den, b.den);
    long long l = (a.den / g) * b.den;
    long long num = a.num * (b.den / g) + b.num * (a.den / g);
    return PMFractionMake(num, l);
}

static PMFraction PMFractionSub(PMFraction a, PMFraction b) {
    return PMFractionAdd(a, (PMFraction){ -b.num, b.den });
}

static PMFraction PMFractionMul(PMFraction a, PMFraction b) {
    if (a.den == 0 || b.den == 0) return (PMFraction){ 0, 0 };
    return PMFractionMake(a.num * b.num, a.den * b.den);
}

static PMFraction PMFractionDiv(PMFraction a, PMFraction b) {
    if (b.num == 0) return (PMFraction){ 0, 0 };
    return PMFractionMake(a.num * b.den, a.den * b.num);
}

static PMFraction doubleToFraction(double val) {
    double eps = 1e-6;
    if (fabs(val - round(val)) < eps) {
        return PMFractionMake((long long)round(val), 1);
    }
    // Continued fraction expansion
    double x = val;
    long long m[2][2] = { {1, 0}, {0, 1} };
    while (m[1][0] * (m[1][0] + m[1][1]) <= 10000) {
        long long a = (long long)floor(x);
        long long t = m[0][0] * a + m[0][1];
        m[0][1] = m[0][0]; m[0][0] = t;
        t = m[1][0] * a + m[1][1];
        m[1][1] = m[1][0]; m[1][0] = t;
        if (fabs(x - (double)a) < eps) break;
        x = 1.0 / (x - (double)a);
        if (x > 1e7) break;
    }
    double approx = (double)m[0][0] / (double)m[1][0];
    if (fabs(val - approx) < 1e-4) {
        return PMFractionMake(m[0][0], m[1][0]);
    }
    return (PMFraction){ 0, 0 };
}

static NSString *formatFractionOrDouble(double val) {
    if (fabs(val - round(val)) < 1e-9) {
        return [NSString stringWithFormat:@"%lld", (long long)round(val)];
    }
    PMFraction f = doubleToFraction(val);
    if (f.den > 1 && f.den <= 1000) {
        return [NSString stringWithFormat:@"\\frac{%lld}{%lld}", f.num, f.den];
    }
    // Format double cleanly
    NSString *s = [NSString stringWithFormat:@"%.4f", val];
    while ([s hasSuffix:@"0"] && [s rangeOfString:@"."].location != NSNotFound) {
        s = [s substringToIndex:s.length - 1];
    }
    if ([s hasSuffix:@"."]) s = [s substringToIndex:s.length - 1];
    return s;
}

#pragma mark - Polynomial Representation

typedef struct {
    double c0; // constant
    double c1; // x
    double c2; // x^2
    BOOL valid;
} PMPoly;

static PMPoly PMPolyMakeConst(double c) {
    return (PMPoly){ c, 0, 0, YES };
}

static PMPoly PMPolyMakeVar(void) {
    return (PMPoly){ 0, 1.0, 0, YES };
}

static PMPoly PMPolyAdd(PMPoly a, PMPoly b) {
    if (!a.valid || !b.valid) return (PMPoly){0,0,0,NO};
    return (PMPoly){ a.c0 + b.c0, a.c1 + b.c1, a.c2 + b.c2, YES };
}

static PMPoly PMPolySub(PMPoly a, PMPoly b) {
    if (!a.valid || !b.valid) return (PMPoly){0,0,0,NO};
    return (PMPoly){ a.c0 - b.c0, a.c1 - b.c1, a.c2 - b.c2, YES };
}

static PMPoly PMPolyMul(PMPoly a, PMPoly b) {
    if (!a.valid || !b.valid) return (PMPoly){0,0,0,NO};
    // If degree would exceed 2, invalid for quadratic
    if (fabs(a.c2) > 1e-9 && (fabs(b.c1) > 1e-9 || fabs(b.c2) > 1e-9)) return (PMPoly){0,0,0,NO};
    if (fabs(b.c2) > 1e-9 && (fabs(a.c1) > 1e-9 || fabs(a.c2) > 1e-9)) return (PMPoly){0,0,0,NO};
    if (fabs(a.c1) > 1e-9 && fabs(b.c1) > 1e-9 && (fabs(a.c2) > 1e-9 || fabs(b.c2) > 1e-9)) return (PMPoly){0,0,0,NO};

    double c0 = a.c0 * b.c0;
    double c1 = a.c0 * b.c1 + a.c1 * b.c0;
    double c2 = a.c0 * b.c2 + a.c1 * b.c1 + a.c2 * b.c0;
    return (PMPoly){ c0, c1, c2, YES };
}

static PMPoly PMPolyDivConst(PMPoly a, double d) {
    if (!a.valid || fabs(d) < 1e-12) return (PMPoly){0,0,0,NO};
    return (PMPoly){ a.c0 / d, a.c1 / d, a.c2 / d, YES };
}

#pragma mark - AST Node

typedef NS_ENUM(NSInteger, PMNodeType) {
    PMNodeNumber,
    PMNodeVariable,
    PMNodeBinaryOp,
    PMNodeUnaryOp,
    PMNodeFunction
};

@interface PMNode : NSObject
@property (nonatomic) PMNodeType type;
@property (nonatomic) double numberValue;
@property (nonatomic, copy) NSString *stringValue;
@property (nonatomic, strong) PMNode *left;
@property (nonatomic, strong) PMNode *right;
@property (nonatomic, strong) NSArray *children;

- (double)evaluateNumericWithError:(NSError **)error;
- (PMPoly)evaluatePolyForVar:(NSString *)varName error:(NSError **)error;
@end

@implementation PMNode

- (double)evaluateNumericWithError:(NSError **)error
{
    switch (self.type) {
        case PMNodeNumber:
            return self.numberValue;
        case PMNodeVariable: {
            if ([self.stringValue isEqualToString:@"pi"] || [self.stringValue isEqualToString:@"π"]) return M_PI;
            if ([self.stringValue isEqualToString:@"e"]) return M_E;
            if (error) *error = [NSError errorWithDomain:@"PMOfflineSolver" code:1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Unknown numeric constant: %@", self.stringValue]}];
            return NAN;
        }
        case PMNodeUnaryOp: {
            double v = [self.left evaluateNumericWithError:error];
            if (isnan(v)) return NAN;
            if ([self.stringValue isEqualToString:@"-"]) return -v;
            if ([self.stringValue isEqualToString:@"+"]) return v;
            if ([self.stringValue isEqualToString:@"!"]) {
                if (v < 0 || v > 170 || fabs(v - round(v)) > 1e-6) {
                    if (error) *error = [NSError errorWithDomain:@"PMOfflineSolver" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Factorial only defined for non-negative integers"}];
                    return NAN;
                }
                double res = 1.0;
                for (int i = 2; i <= (int)round(v); i++) res *= i;
                return res;
            }
            return NAN;
        }
        case PMNodeBinaryOp: {
            double l = [self.left evaluateNumericWithError:error];
            if (isnan(l)) return NAN;
            double r = [self.right evaluateNumericWithError:error];
            if (isnan(r)) return NAN;

            if ([self.stringValue isEqualToString:@"+"]) return l + r;
            if ([self.stringValue isEqualToString:@"-"]) return l - r;
            if ([self.stringValue isEqualToString:@"*"]) return l * r;
            if ([self.stringValue isEqualToString:@"/"]) {
                if (fabs(r) < 1e-12) {
                    if (error) *error = [NSError errorWithDomain:@"PMOfflineSolver" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Division by zero"}];
                    return NAN;
                }
                return l / r;
            }
            if ([self.stringValue isEqualToString:@"^"]) return pow(l, r);
            if ([self.stringValue isEqualToString:@"%"]) return fmod(l, r);
            return NAN;
        }
        case PMNodeFunction: {
            double arg = [self.left evaluateNumericWithError:error];
            if (isnan(arg)) return NAN;
            NSString *fn = [self.stringValue lowercaseString];
            if ([fn isEqualToString:@"sqrt"]) {
                if (arg < 0) {
                    if (error) *error = [NSError errorWithDomain:@"PMOfflineSolver" code:4 userInfo:@{NSLocalizedDescriptionKey: @"Square root of negative number"}];
                    return NAN;
                }
                return sqrt(arg);
            }
            if ([fn isEqualToString:@"cbrt"]) return cbrt(arg);
            if ([fn isEqualToString:@"sin"]) return sin(arg);
            if ([fn isEqualToString:@"cos"]) return cos(arg);
            if ([fn isEqualToString:@"tan"]) return tan(arg);
            if ([fn isEqualToString:@"arcsin"] || [fn isEqualToString:@"asin"]) return asin(arg);
            if ([fn isEqualToString:@"arccos"] || [fn isEqualToString:@"acos"]) return acos(arg);
            if ([fn isEqualToString:@"arctan"] || [fn isEqualToString:@"atan"]) return atan(arg);
            if ([fn isEqualToString:@"log"] || [fn isEqualToString:@"log10"]) return log10(arg);
            if ([fn isEqualToString:@"ln"]) return log(arg);
            if ([fn isEqualToString:@"abs"]) return fabs(arg);
            return NAN;
        }
    }
    return NAN;
}

- (PMPoly)evaluatePolyForVar:(NSString *)varName error:(NSError **)error
{
    switch (self.type) {
        case PMNodeNumber:
            return PMPolyMakeConst(self.numberValue);
        case PMNodeVariable: {
            if ([self.stringValue isEqualToString:varName]) {
                return PMPolyMakeVar();
            }
            if ([self.stringValue isEqualToString:@"pi"] || [self.stringValue isEqualToString:@"π"]) {
                return PMPolyMakeConst(M_PI);
            }
            if ([self.stringValue isEqualToString:@"e"]) {
                return PMPolyMakeConst(M_E);
            }
            if (error) *error = [NSError errorWithDomain:@"PMOfflineSolver" code:5 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Multiple or unknown variable: %@", self.stringValue]}];
            return (PMPoly){0,0,0,NO};
        }
        case PMNodeUnaryOp: {
            PMPoly p = [self.left evaluatePolyForVar:varName error:error];
            if (!p.valid) return p;
            if ([self.stringValue isEqualToString:@"-"]) {
                return (PMPoly){ -p.c0, -p.c1, -p.c2, YES };
            }
            if ([self.stringValue isEqualToString:@"+"]) return p;
            return (PMPoly){0,0,0,NO};
        }
        case PMNodeBinaryOp: {
            PMPoly l = [self.left evaluatePolyForVar:varName error:error];
            if (!l.valid) return l;
            PMPoly r = [self.right evaluatePolyForVar:varName error:error];
            if (!r.valid) return r;

            if ([self.stringValue isEqualToString:@"+"]) return PMPolyAdd(l, r);
            if ([self.stringValue isEqualToString:@"-"]) return PMPolySub(l, r);
            if ([self.stringValue isEqualToString:@"*"]) return PMPolyMul(l, r);
            if ([self.stringValue isEqualToString:@"/"]) {
                // Denominator must be a constant
                if (fabs(r.c1) > 1e-9 || fabs(r.c2) > 1e-9) {
                    if (error) *error = [NSError errorWithDomain:@"PMOfflineSolver" code:6 userInfo:@{NSLocalizedDescriptionKey: @"Rational polynomials with variable denominator not supported offline"}];
                    return (PMPoly){0,0,0,NO};
                }
                return PMPolyDivConst(l, r.c0);
            }
            if ([self.stringValue isEqualToString:@"^"]) {
                // If power is constant 2 or 1
                if (fabs(r.c1) > 1e-9 || fabs(r.c2) > 1e-9) return (PMPoly){0,0,0,NO};
                if (fabs(r.c0 - 2.0) < 1e-9) {
                    return PMPolyMul(l, l);
                }
                if (fabs(r.c0 - 1.0) < 1e-9) {
                    return l;
                }
                if (fabs(r.c0) < 1e-9) {
                    return PMPolyMakeConst(1.0);
                }
                // If base is a constant
                if (fabs(l.c1) < 1e-9 && fabs(l.c2) < 1e-9) {
                    return PMPolyMakeConst(pow(l.c0, r.c0));
                }
                return (PMPoly){0,0,0,NO};
            }
            return (PMPoly){0,0,0,NO};
        }
        case PMNodeFunction: {
            // Function of variable not algebraic
            PMPoly arg = [self.left evaluatePolyForVar:varName error:error];
            if (!arg.valid) return arg;
            if (fabs(arg.c1) < 1e-9 && fabs(arg.c2) < 1e-9) {
                double val = [self evaluateNumericWithError:error];
                return PMPolyMakeConst(val);
            }
            return (PMPoly){0,0,0,NO};
        }
    }
    return (PMPoly){0,0,0,NO};
}

@end

#pragma mark - Tokenizer & Parser

@interface PMParser : NSObject
@property (nonatomic, copy) NSString *input;
@property (nonatomic) NSInteger pos;
@property (nonatomic) unichar currentChar;

- (instancetype)initWithString:(NSString *)str;
- (PMNode *)parseExpression;
@end

@implementation PMParser

- (instancetype)initWithString:(NSString *)str
{
    self = [super init];
    if (self) {
        _input = [str copy];
        _pos = 0;
        _currentChar = _input.length > 0 ? [_input characterAtIndex:0] : 0;
    }
    return self;
}

- (void)advance
{
    self.pos++;
    if (self.pos < self.input.length) {
        self.currentChar = [self.input characterAtIndex:self.pos];
    } else {
        self.currentChar = 0;
    }
}

- (void)skipWhitespace
{
    while (self.currentChar != 0 && (self.currentChar == ' ' || self.currentChar == '\t' || self.currentChar == '\n' || self.currentChar == '\r')) {
        [self advance];
    }
}

- (PMNode *)parseExpression
{
    PMNode *node = [self parseTerm];
    [self skipWhitespace];
    while (self.currentChar == '+' || self.currentChar == '-') {
        NSString *op = [NSString stringWithCharacters:&_currentChar length:1];
        [self advance];
        PMNode *right = [self parseTerm];
        PMNode *parent = [[PMNode alloc] init];
        parent.type = PMNodeBinaryOp;
        parent.stringValue = op;
        parent.left = node;
        parent.right = right;
        node = parent;
        [self skipWhitespace];
    }
    return node;
}

- (PMNode *)parseTerm
{
    PMNode *node = [self parseFactor];
    [self skipWhitespace];
    while (self.currentChar == '*' || self.currentChar == '/' || self.currentChar == '%') {
        NSString *op = [NSString stringWithCharacters:&_currentChar length:1];
        [self advance];
        PMNode *right = [self parseFactor];
        PMNode *parent = [[PMNode alloc] init];
        parent.type = PMNodeBinaryOp;
        parent.stringValue = op;
        parent.left = node;
        parent.right = right;
        node = parent;
        [self skipWhitespace];
    }
    return node;
}

- (PMNode *)parseFactor
{
    PMNode *node = [self parsePower];
    return node;
}

- (PMNode *)parsePower
{
    PMNode *node = [self parseUnary];
    [self skipWhitespace];
    if (self.currentChar == '^') {
        [self advance];
        PMNode *right = [self parsePower]; // Right-associative
        PMNode *parent = [[PMNode alloc] init];
        parent.type = PMNodeBinaryOp;
        parent.stringValue = @"^";
        parent.left = node;
        parent.right = right;
        return parent;
    }
    return node;
}

- (PMNode *)parseUnary
{
    [self skipWhitespace];
    if (self.currentChar == '+' || self.currentChar == '-') {
        NSString *op = [NSString stringWithCharacters:&_currentChar length:1];
        [self advance];
        PMNode *child = [self parseUnary];
        PMNode *node = [[PMNode alloc] init];
        node.type = PMNodeUnaryOp;
        node.stringValue = op;
        node.left = child;
        return node;
    }
    PMNode *node = [self parsePrimary];
    [self skipWhitespace];
    if (self.currentChar == '!') {
        [self advance];
        PMNode *fac = [[PMNode alloc] init];
        fac.type = PMNodeUnaryOp;
        fac.stringValue = @"!";
        fac.left = node;
        return fac;
    }
    return node;
}

- (PMNode *)parsePrimary
{
    [self skipWhitespace];

    // Parentheses or Brackets
    if (self.currentChar == '(' || self.currentChar == '[' || self.currentChar == '{') {
        unichar close = (self.currentChar == '(' ? ')' : (self.currentChar == '[' ? ']' : '}'));
        [self advance];
        PMNode *node = [self parseExpression];
        [self skipWhitespace];
        if (self.currentChar == close) [self advance];
        return node;
    }

    // Absolute value: | expr |
    if (self.currentChar == '|') {
        [self advance];
        PMNode *node = [self parseExpression];
        [self skipWhitespace];
        if (self.currentChar == '|') [self advance];
        PMNode *fn = [[PMNode alloc] init];
        fn.type = PMNodeFunction;
        fn.stringValue = @"abs";
        fn.left = node;
        return fn;
    }

    // Number
    if ((self.currentChar >= '0' && self.currentChar <= '9') || self.currentChar == '.') {
        NSMutableString *numStr = [NSMutableString string];
        while ((self.currentChar >= '0' && self.currentChar <= '9') || self.currentChar == '.') {
            [numStr appendFormat:@"%C", self.currentChar];
            [self advance];
        }
        PMNode *node = [[PMNode alloc] init];
        node.type = PMNodeNumber;
        node.numberValue = [numStr doubleValue];
        return node;
    }

    // Identifier: variable or function name
    if ((self.currentChar >= 'a' && self.currentChar <= 'z') ||
        (self.currentChar >= 'A' && self.currentChar <= 'Z') ||
        self.currentChar == '\\' || self.currentChar == 0x03C0 /* π */) {
        NSMutableString *idStr = [NSMutableString string];
        if (self.currentChar == '\\') [self advance];
        while ((self.currentChar >= 'a' && self.currentChar <= 'z') ||
               (self.currentChar >= 'A' && self.currentChar <= 'Z') ||
               (self.currentChar >= '0' && self.currentChar <= '9') ||
               self.currentChar == 0x03C0) {
            [idStr appendFormat:@"%C", self.currentChar];
            [self advance];
        }
        [self skipWhitespace];

        // Is function call? E.g. sin(...)
        if (self.currentChar == '(') {
            [self advance];
            PMNode *arg = [self parseExpression];
            [self skipWhitespace];
            if (self.currentChar == ')') [self advance];
            PMNode *fn = [[PMNode alloc] init];
            fn.type = PMNodeFunction;
            fn.stringValue = idStr;
            fn.left = arg;
            return fn;
        }

        // Variable or named constant
        PMNode *node = [[PMNode alloc] init];
        node.type = PMNodeVariable;
        node.stringValue = idStr;
        return node;
    }

    // Fallback: zero
    PMNode *zero = [[PMNode alloc] init];
    zero.type = PMNodeNumber;
    zero.numberValue = 0.0;
    return zero;
}

@end

#pragma mark - PMOfflineSolver Implementation

@implementation PMOfflineSolver

+ (NSString *)cleanLatexToMath:(NSString *)latex
{
    if (!latex.length) return @"";
    NSMutableString *s = [latex mutableCopy];

    // Remove text tags and spacing
    [s replaceOccurrencesOfString:@"\\," withString:@"" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"\\;" withString:@"" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"\\quad" withString:@"" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"\\qquad" withString:@"" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"\\left" withString:@"" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"\\right" withString:@"" options:0 range:NSMakeRange(0, s.length)];

    // Operators
    [s replaceOccurrencesOfString:@"\\times" withString:@"*" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"\\cdot" withString:@"*" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"\\div" withString:@"/" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"×" withString:@"*" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"÷" withString:@"/" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"−" withString:@"-" options:0 range:NSMakeRange(0, s.length)];

    // Convert \frac{a}{b} -> ((a)/(b))
    NSRegularExpression *fracRegex = [NSRegularExpression regularExpressionWithPattern:@"\\\\frac\\{([^\\{\\}]+)\\}\\{([^\\{\\}]+)\\}" options:0 error:nil];
    while (YES) {
        NSTextCheckingResult *m = [fracRegex firstMatchInString:s options:0 range:NSMakeRange(0, s.length)];
        if (!m) break;
        NSString *num = [s substringWithRange:[m rangeAtIndex:1]];
        NSString *den = [s substringWithRange:[m rangeAtIndex:2]];
        NSString *repl = [NSString stringWithFormat:@"((%@)/(%@))", num, den];
        [s replaceCharactersInRange:m.range withString:repl];
    }

    // Convert \sqrt[n]{x} -> ((x)^(1/(n)))
    NSRegularExpression *nrootRegex = [NSRegularExpression regularExpressionWithPattern:@"\\\\sqrt\\[([^\\(\\)\\[\\]]+)\\]\\{([^\\{\\}]+)\\}" options:0 error:nil];
    while (YES) {
        NSTextCheckingResult *m = [nrootRegex firstMatchInString:s options:0 range:NSMakeRange(0, s.length)];
        if (!m) break;
        NSString *n = [s substringWithRange:[m rangeAtIndex:1]];
        NSString *x = [s substringWithRange:[m rangeAtIndex:2]];
        NSString *repl = [NSString stringWithFormat:@"((%@)^(1/(%@)))", x, n];
        [s replaceCharactersInRange:m.range withString:repl];
    }

    // Convert \sqrt{x} -> sqrt(x)
    NSRegularExpression *sqrtRegex = [NSRegularExpression regularExpressionWithPattern:@"\\\\sqrt\\{([^\\{\\}]+)\\}" options:0 error:nil];
    while (YES) {
        NSTextCheckingResult *m = [sqrtRegex firstMatchInString:s options:0 range:NSMakeRange(0, s.length)];
        if (!m) break;
        NSString *arg = [s substringWithRange:[m rangeAtIndex:1]];
        NSString *repl = [NSString stringWithFormat:@"sqrt(%@)", arg];
        [s replaceCharactersInRange:m.range withString:repl];
    }

    // Functions
    [s replaceOccurrencesOfString:@"\\sin" withString:@"sin" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"\\cos" withString:@"cos" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"\\tan" withString:@"tan" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"\\arcsin" withString:@"arcsin" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"\\arccos" withString:@"arccos" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"\\arctan" withString:@"arctan" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"\\log" withString:@"log" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"\\ln" withString:@"ln" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"\\pi" withString:@"pi" options:0 range:NSMakeRange(0, s.length)];

    // Exponents: ^{2} -> ^(2)
    NSRegularExpression *expRegex = [NSRegularExpression regularExpressionWithPattern:@"\\^\\{([^\\{\\}]+)\\}" options:0 error:nil];
    while (YES) {
        NSTextCheckingResult *m = [expRegex firstMatchInString:s options:0 range:NSMakeRange(0, s.length)];
        if (!m) break;
        NSString *exp = [s substringWithRange:[m rangeAtIndex:1]];
        NSString *repl = [NSString stringWithFormat:@"^(%@)", exp];
        [s replaceCharactersInRange:m.range withString:repl];
    }

    // Superscript unicode
    [s replaceOccurrencesOfString:@"²" withString:@"^2" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"³" withString:@"^3" options:0 range:NSMakeRange(0, s.length)];

    // Insert implicit multiplications: e.g. 2x -> 2*x, 3( -> 3*(, )x -> )*x, )( -> )*(
    NSMutableString *res = [NSMutableString string];
    for (NSInteger i = 0; i < s.length; i++) {
        unichar c = [s characterAtIndex:i];
        [res appendFormat:@"%C", c];
        if (i + 1 < s.length) {
            unichar next = [s characterAtIndex:i + 1];
            BOOL isNum = (c >= '0' && c <= '9');
            BOOL isLetter = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
            BOOL isClose = (c == ')' || c == ']' || c == '}');

            BOOL nextLetter = (next >= 'a' && next <= 'z') || (next >= 'A' && next <= 'Z');
            BOOL nextOpen = (next == '(' || next == '[' || next == '{');

            if ((isNum && (nextLetter || nextOpen)) ||
                (isClose && (nextLetter || nextOpen || (next >= '0' && next <= '9')))) {
                // Check that it's not a function name like 'sqrt', 'sin'
                [res appendString:@"*"];
            }
        }
    }

    return res;
}

+ (NSString *)detectVariableInString:(NSString *)str
{
    // Search for single letters x, y, z, t, n, a, b, etc. (excluding e, pi, sin, cos, tan, log, ln, sqrt, abs)
    NSSet *reserved = [NSSet setWithObjects:@"e", @"pi", @"sin", @"cos", @"tan", @"log", @"ln", @"sqrt", @"cbrt", @"abs", @"arcsin", @"arccos", @"arctan", nil];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[a-zA-Z]" options:0 error:nil];
    NSArray *matches = [regex matchesInString:str options:0 range:NSMakeRange(0, str.length)];
    for (NSTextCheckingResult *m in matches) {
        NSString *letter = [str substringWithRange:m.range];
        // Check if part of a word
        NSInteger start = m.range.location;
        while (start > 0 && isalpha([str characterAtIndex:start - 1])) start--;
        NSInteger end = m.range.location + m.range.length;
        while (end < str.length && isalpha([str characterAtIndex:end])) end++;
        NSString *word = [str substringWithRange:NSMakeRange(start, end - start)];
        if (![reserved containsObject:[word lowercaseString]]) {
            return letter;
        }
    }
    return nil;
}

+ (BOOL)canSolveProblem:(NSString *)problemLatex
{
    if (!problemLatex.length) return NO;
    NSString *clean = [self cleanLatexToMath:problemLatex];
    if (!clean.length) return NO;

    // Check if it's an equation or expression
    NSArray *parts = [clean componentsSeparatedByString:@"="];
    if (parts.count <= 2) {
        return YES;
    }
    return NO;
}

+ (PMMathSolution *)solveProblem:(NSString *)problemLatex error:(NSError **)error
{
    NSString *clean = [self cleanLatexToMath:problemLatex];
    BOOL isCzech = [[PMSettings shared].solutionLanguage isEqualToString:@"cs"];

    NSArray *sides = [clean componentsSeparatedByString:@"="];
    NSString *varName = [self detectVariableInString:clean];

    if (sides.count == 2) {
        NSString *lhsStr = [sides[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *rhsStr = [sides[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        // If RHS is empty or just '?', it's an evaluation request
        if (!rhsStr.length || [rhsStr isEqualToString:@"?"]) {
            return [self solveNumericExpression:lhsStr originalLatex:problemLatex isCzech:isCzech error:error];
        }

        // Equation with variable
        if (varName) {
            return [self solveEquationWithLHS:lhsStr rhs:rhsStr varName:varName originalLatex:problemLatex isCzech:isCzech error:error];
        } else {
            // Identity check or comparison: e.g. 5 + 3 = 8
            PMParser *lp = [[PMParser alloc] initWithString:lhsStr];
            PMParser *rp = [[PMParser alloc] initWithString:rhsStr];
            double lVal = [[lp parseExpression] evaluateNumericWithError:error];
            double rVal = [[rp parseExpression] evaluateNumericWithError:error];
            if (!isnan(lVal) && !isnan(rVal)) {
                BOOL eq = fabs(lVal - rVal) < 1e-9;
                PMMathSolution *sol = [[PMMathSolution alloc] init];
                sol.solutionId = [[NSUUID UUID] UUIDString];
                sol.date = [NSDate date];
                sol.problemLatex = problemLatex;
                sol.solutionLatex = eq ? (isCzech ? @"\\text{Pravdivá rovnost (True)}" : @"\\text{True}") : (isCzech ? @"\\text{Nepravdivá rovnost (False)}" : @"\\text{False}");
                sol.summary = eq ? (isCzech ? @"Rovnost platí" : @"Equation holds true") : (isCzech ? @"Rovnost neplatí" : @"Equation is false");
                sol.modelUsed = @"Offline Engine";

                PMStep *s1 = [[PMStep alloc] init];
                s1.stepNumber = 1;
                s1.title = isCzech ? @"Vyhodnocení levé strany" : @"Evaluate Left-Hand Side";
                s1.latex = [NSString stringWithFormat:@"%@ = %@", lhsStr, formatFractionOrDouble(lVal)];
                s1.explanation = isCzech ? @"Spočítáme hodnotu levé strany rovnice." : @"Compute the value of the left expression.";

                PMStep *s2 = [[PMStep alloc] init];
                s2.stepNumber = 2;
                s2.title = isCzech ? @"Vyhodnocení pravé strany" : @"Evaluate Right-Hand Side";
                s2.latex = [NSString stringWithFormat:@"%@ = %@", rhsStr, formatFractionOrDouble(rVal)];
                s2.explanation = isCzech ? @"Spočítáme hodnotu pravé strany rovnice." : @"Compute the value of the right expression.";

                sol.steps = @[ s1, s2 ];
                return sol;
            }
        }
    }

    // Pure numeric expression evaluation
    return [self solveNumericExpression:clean originalLatex:problemLatex isCzech:isCzech error:error];
}

+ (PMMathSolution *)solveNumericExpression:(NSString *)expr
                             originalLatex:(NSString *)problemLatex
                                   isCzech:(BOOL)isCzech
                                     error:(NSError **)error
{
    PMParser *p = [[PMParser alloc] initWithString:expr];
    PMNode *root = [p parseExpression];
    double result = [root evaluateNumericWithError:error];
    if (isnan(result)) return nil;

    PMMathSolution *sol = [[PMMathSolution alloc] init];
    sol.solutionId = [[NSUUID UUID] UUIDString];
    sol.date = [NSDate date];
    sol.problemLatex = problemLatex;
    sol.modelUsed = @"Offline Engine";
    sol.summary = isCzech ? @"Vypočítaná hodnota výrazu" : @"Calculated expression value";

    NSString *solLatex = formatFractionOrDouble(result);
    // If fraction, also append decimal if useful
    PMFraction f = doubleToFraction(result);
    if (f.den > 1 && fabs(result - round(result)) > 1e-9) {
        sol.solutionLatex = [NSString stringWithFormat:@"%@ = %.4f", solLatex, result];
    } else {
        sol.solutionLatex = solLatex;
    }

    NSMutableArray *steps = [NSMutableArray array];

    // Step 1: Order of operations
    PMStep *s1 = [[PMStep alloc] init];
    s1.stepNumber = 1;
    s1.title = isCzech ? @"Pořadí početních operací" : @"Order of Operations";
    s1.latex = problemLatex;
    s1.explanation = isCzech ? @"Vyhodnotíme závorky, mocniny/odmocniny, násobení/dělení a sčítání/odčítání zleva doprava." :
                               @"Evaluate parentheses, powers/roots, multiplication/division, and addition/subtraction.";
    [steps addObject:s1];

    // Step 2: Final evaluated answer
    PMStep *s2 = [[PMStep alloc] init];
    s2.stepNumber = 2;
    s2.title = isCzech ? @"Konečný výsledek" : @"Final Result";
    s2.latex = sol.solutionLatex;
    s2.explanation = isCzech ? [NSString stringWithFormat:@"Hodnota výrazu je %@.", sol.solutionLatex] :
                               [NSString stringWithFormat:@"The evaluated value is %@.", sol.solutionLatex];
    [steps addObject:s2];

    sol.steps = steps;
    return sol;
}

+ (PMMathSolution *)solveEquationWithLHS:(NSString *)lhsStr
                                     rhs:(NSString *)rhsStr
                                 varName:(NSString *)varName
                           originalLatex:(NSString *)problemLatex
                                 isCzech:(BOOL)isCzech
                                   error:(NSError **)error
{
    PMParser *lp = [[PMParser alloc] initWithString:lhsStr];
    PMParser *rp = [[PMParser alloc] initWithString:rhsStr];
    PMNode *lNode = [lp parseExpression];
    PMNode *rNode = [rp parseExpression];

    PMPoly lPoly = [lNode evaluatePolyForVar:varName error:error];
    PMPoly rPoly = [rNode evaluatePolyForVar:varName error:error];

    if (!lPoly.valid || !rPoly.valid) {
        if (error) *error = [NSError errorWithDomain:@"PMOfflineSolver" code:7 userInfo:@{NSLocalizedDescriptionKey: @"Equation could not be reduced algebraically"}];
        return nil;
    }

    // P(x) = LHS - RHS = 0 => c2*x^2 + c1*x + c0 = 0
    PMPoly poly = PMPolySub(lPoly, rPoly);

    double a = poly.c2;
    double b = poly.c1;
    double c = poly.c0;

    PMMathSolution *sol = [[PMMathSolution alloc] init];
    sol.solutionId = [[NSUUID UUID] UUIDString];
    sol.date = [NSDate date];
    sol.problemLatex = problemLatex;
    sol.modelUsed = @"Offline Engine";
    NSMutableArray *steps = [NSMutableArray array];

    if (fabs(a) < 1e-9) {
        // Linear Equation: b*x + c = 0 => b*x = -c
        sol.summary = isCzech ? [NSString stringWithFormat:@"Lineární rovnice pro %@", varName] :
                                [NSString stringWithFormat:@"Linear equation solved for %@", varName];

        // Step 1: Write equation
        PMStep *s1 = [[PMStep alloc] init];
        s1.stepNumber = 1;
        s1.title = isCzech ? @"Zadání rovnice" : @"Original Equation";
        s1.latex = problemLatex;
        s1.explanation = isCzech ? @"Vyřešíme lineární rovnici osamostatněním neznámé." :
                                   [NSString stringWithFormat:@"Solve the linear equation for %@ by isolating terms.", varName];
        [steps addObject:s1];

        if (fabs(b) < 1e-9) {
            if (fabs(c) < 1e-9) {
                // 0 = 0 -> All real numbers
                sol.solutionLatex = isCzech ? [NSString stringWithFormat:@"%@ \\in \\mathbb{R}", varName] :
                                              [NSString stringWithFormat:@"%@ \\in \\mathbb{R} \\text{ (All real numbers)}", varName];
                PMStep *s2 = [[PMStep alloc] init];
                s2.stepNumber = 2;
                s2.title = isCzech ? @"Nekonečně mnoho řešení" : @"Infinite Solutions";
                s2.latex = @"0 = 0";
                s2.explanation = isCzech ? @"Rovnost platí pro jakékoli reálné číslo." : @"The equation holds for all real numbers.";
                [steps addObject:s2];
            } else {
                // 0 = c -> No solution
                sol.solutionLatex = isCzech ? @"\\text{Nemá řešení } (\\emptyset)" : @"\\text{No solution } (\\emptyset)";
                PMStep *s2 = [[PMStep alloc] init];
                s2.stepNumber = 2;
                s2.title = isCzech ? @"Spor" : @"Contradiction";
                s2.latex = [NSString stringWithFormat:@"%@ = 0", formatFractionOrDouble(c)];
                s2.explanation = isCzech ? @"Rovnice vede ke sporu, nemá žádné řešení." : @"The equation leads to a contradiction; there is no solution.";
                [steps addObject:s2];
            }
        } else {
            // b*x + c = 0 => b*x = -c => x = -c/b
            double root = -c / b;
            NSString *bStr = formatFractionOrDouble(b);
            NSString *negCStr = formatFractionOrDouble(-c);
            NSString *ansStr = formatFractionOrDouble(root);

            // Step 2: Move constant term to RHS
            PMStep *s2 = [[PMStep alloc] init];
            s2.stepNumber = 2;
            s2.title = isCzech ? @"Převod konstanty na pravou stranu" : @"Move Constant to Right Side";
            s2.latex = [NSString stringWithFormat:@"%@%@ = %@", bStr, varName, negCStr];
            s2.explanation = isCzech ? [NSString stringWithFormat:@"Odečteme nebo přičteme konstantu k oběma stranám: %@%@ = %@.", bStr, varName, negCStr] :
                                       [NSString stringWithFormat:@"Isolate the variable term on the left side: %@%@ = %@.", bStr, varName, negCStr];
            [steps addObject:s2];

            // Step 3: Divide by coefficient of x
            PMStep *s3 = [[PMStep alloc] init];
            s3.stepNumber = 3;
            s3.title = isCzech ? @"Vydělení koeficientem" : @"Divide by Coefficient";
            s3.latex = [NSString stringWithFormat:@"%@ = \\frac{%@}{%@} = %@", varName, negCStr, bStr, ansStr];
            s3.explanation = isCzech ? [NSString stringWithFormat:@"Vydělíme obě strany koeficientem %@.", bStr] :
                                       [NSString stringWithFormat:@"Divide both sides by %@ to find %@.", bStr, varName];
            [steps addObject:s3];

            sol.solutionLatex = [NSString stringWithFormat:@"%@ = %@", varName, ansStr];
        }
    } else {
        // Quadratic Equation: a*x^2 + b*x + c = 0
        sol.summary = isCzech ? [NSString stringWithFormat:@"Kvadratická rovnice pro %@", varName] :
                                [NSString stringWithFormat:@"Quadratic equation solved for %@", varName];

        // Step 1: Standard form
        PMStep *s1 = [[PMStep alloc] init];
        s1.stepNumber = 1;
        s1.title = isCzech ? @"Základní tvar kvadratické rovnice" : @"Standard Quadratic Form";
        s1.latex = [NSString stringWithFormat:@"%@%@^2 %@ %@%@ %@ %@ = 0",
                    formatFractionOrDouble(a), varName,
                    b >= 0 ? @"+" : @"-", formatFractionOrDouble(fabs(b)), varName,
                    c >= 0 ? @"+" : @"-", formatFractionOrDouble(fabs(c))];
        s1.explanation = isCzech ? [NSString stringWithFormat:@"Převedeme rovnici do tvaru ax² + bx + c = 0: a = %@, b = %@, c = %@.", formatFractionOrDouble(a), formatFractionOrDouble(b), formatFractionOrDouble(c)] :
                                   [NSString stringWithFormat:@"Write in standard form ax² + bx + c = 0: a = %@, b = %@, c = %@.", formatFractionOrDouble(a), formatFractionOrDouble(b), formatFractionOrDouble(c)];
        [steps addObject:s1];

        // Step 2: Discriminant D = b^2 - 4ac
        double D = b * b - 4.0 * a * c;
        PMStep *s2 = [[PMStep alloc] init];
        s2.stepNumber = 2;
        s2.title = isCzech ? @"Výpočet diskriminantu D" : @"Calculate Discriminant D";
        s2.latex = [NSString stringWithFormat:@"D = b^2 - 4ac = (%@)^2 - 4(%@)(%@) = %@",
                    formatFractionOrDouble(b), formatFractionOrDouble(a), formatFractionOrDouble(c),
                    formatFractionOrDouble(D)];
        s2.explanation = isCzech ? [NSString stringWithFormat:@"Dosadíme do vzorce pro diskriminant: D = %@.", formatFractionOrDouble(D)] :
                                   [NSString stringWithFormat:@"Substitute into D = b² - 4ac: D = %@.", formatFractionOrDouble(D)];
        [steps addObject:s2];

        // Step 3: Roots
        if (D > 1e-9) {
            double sqrtD = sqrt(D);
            double x1 = (-b + sqrtD) / (2.0 * a);
            double x2 = (-b - sqrtD) / (2.0 * a);
            NSString *x1Str = formatFractionOrDouble(x1);
            NSString *x2Str = formatFractionOrDouble(x2);

            PMStep *s3 = [[PMStep alloc] init];
            s3.stepNumber = 3;
            s3.title = isCzech ? @"Kvadratický vzorec (D > 0)" : @"Quadratic Formula (D > 0)";
            s3.latex = [NSString stringWithFormat:@"%@ = \\frac{-b \\pm \\sqrt{D}}{2a} = \\frac{-(%@) \\pm \\sqrt{%@}}{2(%@)}",
                        varName, formatFractionOrDouble(b), formatFractionOrDouble(D), formatFractionOrDouble(a)];
            s3.explanation = isCzech ? @"Jelikož D > 0, rovnice má 2 různé reálné kořeny." : @"Since D > 0, the equation has two distinct real roots.";
            [steps addObject:s3];

            PMStep *s4 = [[PMStep alloc] init];
            s4.stepNumber = 4;
            s4.title = isCzech ? @"Kořeny rovnice" : @"Calculated Roots";
            s4.latex = [NSString stringWithFormat:@"%@_1 = %@, \\quad %@_2 = %@", varName, x1Str, varName, x2Str];
            s4.explanation = isCzech ? [NSString stringWithFormat:@"Řešením jsou kořeny %@₁ = %@ a %@₂ = %@.", varName, x1Str, varName, x2Str] :
                                       [NSString stringWithFormat:@"The solutions are %@₁ = %@ and %@₂ = %@.", varName, x1Str, varName, x2Str];
            [steps addObject:s4];

            sol.solutionLatex = [NSString stringWithFormat:@"%@_1 = %@, \\quad %@_2 = %@", varName, x1Str, varName, x2Str];
        } else if (fabs(D) <= 1e-9) {
            double x = -b / (2.0 * a);
            NSString *xStr = formatFractionOrDouble(x);

            PMStep *s3 = [[PMStep alloc] init];
            s3.stepNumber = 3;
            s3.title = isCzech ? @"Dvojnásobný kořen (D = 0)" : @"Repeated Root (D = 0)";
            s3.latex = [NSString stringWithFormat:@"%@ = \\frac{-b}{2a} = \\frac{-(%@)}{2(%@)} = %@",
                        varName, formatFractionOrDouble(b), formatFractionOrDouble(a), xStr];
            s3.explanation = isCzech ? @"Jelikož D = 0, rovnice má jeden dvojnásobný reálný kořen." : @"Since D = 0, the equation has one repeated real root.";
            [steps addObject:s3];

            sol.solutionLatex = [NSString stringWithFormat:@"%@ = %@", varName, xStr];
        } else {
            // D < 0 => Complex roots
            double realPart = -b / (2.0 * a);
            double imagPart = sqrt(-D) / (2.0 * a);
            NSString *realStr = formatFractionOrDouble(realPart);
            NSString *imagStr = formatFractionOrDouble(fabs(imagPart));

            PMStep *s3 = [[PMStep alloc] init];
            s3.stepNumber = 3;
            s3.title = isCzech ? @"Komplexní kořeny (D < 0)" : @"Complex Conjugate Roots (D < 0)";
            s3.latex = [NSString stringWithFormat:@"%@ = \\frac{-b \\pm i\\sqrt{|D|}}{2a} = %@ \\pm %@i",
                        varName, realStr, imagStr];
            s3.explanation = isCzech ? @"Jelikož D < 0, rovnice nemá reálné řešení, ale má dva komplexně sdružené kořeny." :
                                       @"Since D < 0, the equation has no real roots, but two complex conjugate roots.";
            [steps addObject:s3];

            sol.solutionLatex = [NSString stringWithFormat:@"%@ = %@ \\pm %@i", varName, realStr, imagStr];
        }
    }

    sol.steps = steps;
    return sol;
}

@end
