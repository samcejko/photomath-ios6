#import <Foundation/Foundation.h>

// Match keyed subscript assignment, including removing a key when value is nil.
static inline void PMSetDictionaryObject(NSMutableDictionary *dictionary, id<NSCopying> key, id value)
{
    if (value) [dictionary setObject:value forKey:key];
    else [dictionary removeObjectForKey:key];
}
