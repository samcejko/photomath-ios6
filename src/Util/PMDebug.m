#import "PMDebug.h"
#import "PMAppDelegate.h"
#import "PMMathKeyboard.h"
#import "PMScannerViewController.h"
#import "PMGraphViewController.h"
#import "PMOfflineSolver.h"
#import "PMSettings.h"
#import "PMUtils.h"
#import "PMCommon.h"
#import <math.h>

@interface PMMathKeyboard (PMDeviceChecks)
- (void)insertKeyOrCommand:(NSString *)key;
- (void)updateMathPreview;
- (void)solveTapped:(id)sender;
- (void)nextField:(id)sender;
@end

static UIViewController *PMDebugTop(PMAppDelegate *app)
{
    UIViewController *top=app.navigationController;
    while(YES) {
        if(top.presentedViewController){top=top.presentedViewController;continue;}
        if([top isKindOfClass:[UINavigationController class]]){top=[(UINavigationController *)top topViewController];continue;}
        return top;
    }
}

BOOL PMHandleDebugCommand(PMAppDelegate *app,NSString *target,NSString *query)
{
    if(![[NSFileManager defaultManager] fileExistsAtPath:[[PMUtils documentsPath] stringByAppendingPathComponent:@"debug"]])return NO;
    NSMutableDictionary *params=[NSMutableDictionary dictionary];
    for(NSString *pair in [query componentsSeparatedByString:@"&"]) {
        NSRange equal=[pair rangeOfString:@"="];if(equal.location==NSNotFound)continue;
        NSString *key=[[pair substringToIndex:equal.location] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *value=[[[pair substringFromIndex:equal.location+1] stringByReplacingOccurrencesOfString:@"+" withString:@" "] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        if(key && value)[params setObject:value forKey:key];
    }
    UIViewController *top=PMDebugTop(app);
    if([target isEqualToString:@"diagnostics"]) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        [result setObject:NSStringFromClass(top.class) forKey:@"screen"];
        [result setObject:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"" forKey:@"version"];
        [result setObject:@([PMSettings shared].hasAPIKey) forKey:@"hasAPIKey"];
        [result setObject:@([PMSettings shared].preferOfflineSolver) forKey:@"preferOffline"];
        NSMutableArray *views=[NSMutableArray arrayWithObject:top.view],*labels=[NSMutableArray array];
        for(NSUInteger i=0;i<views.count;i++) {
            UIView *view=[views objectAtIndex:i];[views addObjectsFromArray:view.subviews];
            if(!view.hidden && [view isKindOfClass:[UILabel class]] && [(UILabel *)view text].length)[labels addObject:[(UILabel *)view text]];
        }
        [result setObject:labels forKey:@"labels"];
        if([top isKindOfClass:[PMMathKeyboard class]]) {
            PMMathKeyboard *editor=(PMMathKeyboard *)top;UITextField *field=[editor valueForKey:@"rawTextField"];
            [result setObject:editor.currentLatex ?: @"" forKey:@"latex"];
            [result setObject:[editor valueForKey:@"cursorPosition"] forKey:@"cursor"];
            [result setObject:@(field.isFirstResponder && field.selectedTextRange!=nil) forKey:@"caretVisible"];
            [result setObject:@(editor.solving) forKey:@"solving"];
            id preview=[editor valueForKey:@"mathPreviewLabel"];
            [result setObject:[preview valueForKey:@"latex"] ?: @"" forKey:@"previewLatex"];
            NSError *error=[preview valueForKey:@"error"];[result setObject:error.localizedDescription ?: @"" forKey:@"previewError"];
        } else if([top isKindOfClass:[PMGraphViewController class]]) {
            PMGraphFunction *function=[top valueForKey:@"function"];[result setObject:function.expression forKey:@"expression"];
            NSMutableArray *samples=[NSMutableArray array];for(NSNumber *x in @[@-2,@0,@2]){double y=[function valueAtX:x.doubleValue];[samples addObject:@{@"x":x,@"y":isfinite(y)?(id)@(y):(id)[NSNull null]}];}[result setObject:samples forKey:@"samples"];
            [result setObject:[[top valueForKey:@"canvas"] valueForKey:@"halfRange"] forKey:@"halfRange"];
        } else if([NSStringFromClass(top.class) isEqualToString:@"PMSolutionViewController"]) {
            PMMathSolution *solution=[top valueForKey:@"solution"];[result setObject:solution.problemLatex ?: @"" forKey:@"problem"];[result setObject:solution.solutionLatex ?: @"" forKey:@"result"];[result setObject:@(solution.steps.count) forKey:@"steps"];
        }
        [[NSJSONSerialization dataWithJSONObject:result options:0 error:NULL] writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"shuttercalc-check.json"] atomically:YES];return YES;
    }
    if([target isEqualToString:@"input"] && [top isKindOfClass:[PMMathKeyboard class]]) {
        PMMathKeyboard *editor=(PMMathKeyboard *)top;NSString *text=[params objectForKey:@"latex"] ?: @"";
        if(text.length<=1024){editor.currentLatex=text;[editor setValue:@(text.length) forKey:@"cursorPosition"];[editor updateMathPreview];}return YES;
    }
    if([target isEqualToString:@"key"] && [top isKindOfClass:[PMMathKeyboard class]]){[(PMMathKeyboard *)top insertKeyOrCommand:[params objectForKey:@"value"]];return YES;}
    if([target isEqualToString:@"solve"] && [top isKindOfClass:[PMMathKeyboard class]]){[(PMMathKeyboard *)top solveTapped:nil];return YES;}
    if([target isEqualToString:@"nextfield"] && [top isKindOfClass:[PMMathKeyboard class]]){[(PMMathKeyboard *)top nextField:nil];return YES;}
    if([target isEqualToString:@"press"]) {
        NSString *title=[params objectForKey:@"title"] ?: @"";NSMutableArray *views=[NSMutableArray array];
        for(UIWindow *window in [UIApplication sharedApplication].windows)if(!window.hidden)[views addObject:window];
        for(NSUInteger i=0;i<views.count;i++) {
            UIView *view=[views objectAtIndex:i];[views addObjectsFromArray:view.subviews];
            if([view isKindOfClass:[UIButton class]]) {
                UIButton *button=(UIButton *)view;
                if([button.currentTitle isEqualToString:title] || [button.accessibilityLabel isEqualToString:title]){[button sendActionsForControlEvents:UIControlEventTouchUpInside];break;}
            }
        }return YES;
    }
    if([target isEqualToString:@"back"]){if(app.navigationController.presentedViewController)[app.navigationController dismissViewControllerAnimated:NO completion:nil];else[app.navigationController popViewControllerAnimated:NO];return YES;}
    return NO;
}
