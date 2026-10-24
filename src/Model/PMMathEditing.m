#import "PMMathEditing.h"
@implementation PMMathEditing
+ (NSString *)previewForLatex:(NSString *)latex
{
    if(![latex isKindOfClass:[NSString class]] || latex.length>1024)return @"";
    NSMutableString *preview=[latex mutableCopy];
    NSInteger balance=0;
    for(NSUInteger i=0;i<latex.length;i++) {
        unichar c=[latex characterAtIndex:i];
        if(c=='{')balance++;
        else if(c=='}')balance--;
        if(balance<0)return latex;
    }
    for(NSInteger i=0;i<balance;i++)[preview appendString:@"}"];
    [preview replaceOccurrencesOfString:@"{}" withString:@"{\\square}" options:0 range:NSMakeRange(0,preview.length)];
    [preview replaceOccurrencesOfString:@"[]" withString:@"[\\square]" options:0 range:NSMakeRange(0,preview.length)];
    [preview replaceOccurrencesOfString:@"()" withString:@"(\\square)" options:0 range:NSMakeRange(0,preview.length)];
    [preview replaceOccurrencesOfString:@"| |" withString:@"|\\square|" options:0 range:NSMakeRange(0,preview.length)];
    return preview;
}
@end
