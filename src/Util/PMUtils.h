#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface PMUtils : NSObject

// Base64 & Data URLs
+ (NSString *)base64EncodeData:(NSData *)data;
+ (NSData *)base64DecodeString:(NSString *)string;
+ (NSString *)dataURLWithMime:(NSString *)mime data:(NSData *)data;

// Images
+ (NSData *)jpegDataForImage:(UIImage *)image maxDimension:(CGFloat)maxDim quality:(CGFloat)quality;
+ (UIImage *)cropImage:(UIImage *)image toNormalizedRect:(CGRect)normalizedRect;
+ (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size;

// Paths
+ (NSString *)documentsPath;
+ (NSString *)cachesPath;
+ (NSString *)historyPath;

// Formatting
+ (NSString *)shortDateString:(NSDate *)date;

// JSON
+ (id)JSONObjectFromData:(NSData *)data;
+ (NSData *)JSONDataFromObject:(id)object;

// UI
+ (void)alertWithTitle:(NSString *)title message:(NSString *)message;

@end
