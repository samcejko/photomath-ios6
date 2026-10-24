#import <Foundation/Foundation.h>

@interface PMMathEditing : NSObject
// Preview-only placeholders never become part of the saved or solved expression.
+ (NSString *)previewForLatex:(NSString *)latex;
@end
