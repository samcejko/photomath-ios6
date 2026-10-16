#import "PMHistoryStore.h"
#import "PMUtils.h"
#import "PMCommon.h"

static const NSUInteger kMaxHistoryItems = 100;

@interface PMHistoryStore ()
@property (nonatomic, strong) NSMutableArray *items;
@end

@implementation PMHistoryStore

+ (instancetype)shared
{
    static PMHistoryStore *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[PMHistoryStore alloc] init]; });
    return s;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _items = [NSMutableArray array];
        [self loadHistory];
    }
    return self;
}

- (NSString *)historyFile
{
    return [[PMUtils historyPath] stringByAppendingPathComponent:@"history.json"];
}

- (NSArray *)solutions
{
    return [self.items copy];
}

- (void)loadHistory
{
    NSData *data = [NSData dataWithContentsOfFile:[self historyFile]];
    id json = [PMUtils JSONObjectFromData:data];
    if ([json isKindOfClass:[NSArray class]]) {
        NSMutableArray *arr = [NSMutableArray array];
        for (id obj in json) {
            PMMathSolution *sol = [PMMathSolution solutionFromDictionary:obj];
            if (sol) [arr addObject:sol];
        }
        self.items = arr;
    }
}

- (void)saveHistory
{
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:self.items.count];
    for (PMMathSolution *sol in self.items) {
        [arr addObject:[sol toDictionary]];
    }
    NSData *data = [PMUtils JSONDataFromObject:arr];
    NSString *file = [self historyFile];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [data writeToFile:file atomically:YES];
    });
}

- (void)addSolution:(PMMathSolution *)solution
{
    if (!solution) return;
    [self.items insertObject:solution atIndex:0];
    if (self.items.count > kMaxHistoryItems) {
        [self.items removeObjectsInRange:NSMakeRange(kMaxHistoryItems, self.items.count - kMaxHistoryItems)];
    }
    [self saveHistory];
    [[NSNotificationCenter defaultCenter] postNotificationName:PMHistoryDidChangeNotification object:self];
}

- (void)removeSolution:(PMMathSolution *)solution
{
    if (!solution) return;
    [self.items removeObject:solution];
    if (solution.imagePath.length) {
        NSString *full = [[PMUtils historyPath] stringByAppendingPathComponent:solution.imagePath];
        [[NSFileManager defaultManager] removeItemAtPath:full error:NULL];
    }
    [self saveHistory];
    [[NSNotificationCenter defaultCenter] postNotificationName:PMHistoryDidChangeNotification object:self];
}

- (void)clearHistory
{
    [self.items removeAllObjects];
    [[NSFileManager defaultManager] removeItemAtPath:[self historyFile] error:NULL];
    [self saveHistory];
    [[NSNotificationCenter defaultCenter] postNotificationName:PMHistoryDidChangeNotification object:self];
}

@end
