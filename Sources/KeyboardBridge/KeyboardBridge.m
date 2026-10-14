#import "KeyboardBridge.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <sqlite3.h>

static NSError *RPError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:@"Replacements.KeyboardServices" code:code userInfo:@{NSLocalizedDescriptionKey:message}];
}
/// These private selectors are checked at runtime. No private headers or third-party code are linked.
@interface RPKeyboardBridge ()
@property (strong) id store;
@property Class entryClass;
@end
@implementation RPKeyboardBridge
- (instancetype)init {
    if ((self = [super init])) {
        dlopen("/System/Library/PrivateFrameworks/KeyboardServices.framework/KeyboardServices", RTLD_NOW | RTLD_LOCAL);
        Class storeClass = NSClassFromString(@"_KSTextReplacementClientStore");
        _entryClass = NSClassFromString(@"_KSTextReplacementEntry");
        if (storeClass && _entryClass) _store = [storeClass new];
    }
    return self;
}
- (BOOL)available {
    for (NSString *name in @[@"queryTextReplacementsWithCallback:", @"addEntries:removeEntries:withCompletionHandler:", @"modifyEntry:toEntry:withCompletionHandler:"])
        if (![_store respondsToSelector:NSSelectorFromString(name)]) return NO;
    for (NSString *name in @[@"shortcut", @"phrase", @"setShortcut:", @"setPhrase:", @"setNeedsSaveToCloud:"])
        if (![_entryClass instancesRespondToSelector:NSSelectorFromString(name)]) return NO;
    // Fail closed if a future OS changes the calling convention.
    for (NSString *name in @[@"addEntries:removeEntries:withCompletionHandler:", @"modifyEntry:toEntry:withCompletionHandler:"]) {
        NSMethodSignature *s = [_store methodSignatureForSelector:NSSelectorFromString(name)];
        if (s.numberOfArguments != 5 || strcmp(s.methodReturnType, "v")) return NO;
        for (NSUInteger i=2; i<5; i++) if ([s getArgumentTypeAtIndex:i][0] != '@') return NO;
    }
    return YES;
}
- (void)queryWithCompletion:(void (^)(NSArray<NSDictionary<NSString *, id> *> * _Nullable, NSError * _Nullable))completion {
    if (!self.available) { completion(nil, RPError(1, @"KeyboardServices is unavailable on this macOS version.")); return; }
    NSLock *lock = [NSLock new]; __block BOOL finished = NO;
    void (^finish)(NSArray *, NSError *) = ^(NSArray *rows, NSError *error) {
        [lock lock]; BOOL shouldFinish = !finished; finished = YES; [lock unlock];
        if (shouldFinish) completion(rows, error);
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4*NSEC_PER_SEC), dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0), ^{
        finish(nil, RPError(2, @"The native read timed out."));
    });
    // On the tested OS the reply is (NSArray *, BOOL). Only the first argument is consumed,
    // avoiding any dependency on the private trailing flag's meaning or width.
    void (^reply)(NSArray *) = ^(NSArray *objects) {
        @try {
            if (![objects isKindOfClass:NSArray.class]) { finish(nil, RPError(3,@"Unexpected native read response.")); return; }
            NSMutableArray *rows = [NSMutableArray new];
            for (id entry in objects) {
                if (![entry isKindOfClass:self.entryClass]) { finish(nil, RPError(3,@"Unexpected native entry type.")); return; }
                NSString *shortcut = ((id(*)(id,SEL))objc_msgSend)(entry, NSSelectorFromString(@"shortcut"));
                NSString *phrase = ((id(*)(id,SEL))objc_msgSend)(entry, NSSelectorFromString(@"phrase"));
                if ([entry respondsToSelector:NSSelectorFromString(@"wasDeleted")] && ((BOOL(*)(id,SEL))objc_msgSend)(entry,NSSelectorFromString(@"wasDeleted"))) continue;
                if (shortcut && ![shortcut isKindOfClass:NSString.class]) { finish(nil,RPError(3,@"Invalid shortcut type."));return; }
                if (![phrase isKindOfClass:NSString.class]) { finish(nil,RPError(3,@"Invalid phrase type."));return; }
                id identifier = [entry respondsToSelector:NSSelectorFromString(@"uniqueRecordName")] ? ((id(*)(id,SEL))objc_msgSend)(entry,NSSelectorFromString(@"uniqueRecordName")) : nil;
                [rows addObject:@{@"id": [identifier isKindOfClass:NSString.class] ? identifier : NSUUID.UUID.UUIDString,
                                  @"shortcut": shortcut ?: @"", @"phrase": phrase}];
            }
            finish(rows,nil);
        } @catch (NSException *exception) { finish(nil,RPError(3,@"KeyboardServices returned an incompatible entry.")); }
    };
    @try { ((void(*)(id,SEL,id))objc_msgSend)(_store,NSSelectorFromString(@"queryTextReplacementsWithCallback:"),reply); }
    @catch (NSException *exception) { finish(nil,RPError(3,@"The native query failed.")); }
}
- (id)entryWithShortcut:(NSString *)shortcut phrase:(NSString *)phrase {
    id entry = [_entryClass new];
    ((void(*)(id,SEL,id))objc_msgSend)(entry,NSSelectorFromString(@"setShortcut:"),shortcut);
    ((void(*)(id,SEL,id))objc_msgSend)(entry,NSSelectorFromString(@"setPhrase:"),phrase);
    return entry;
}
- (void)performWrite:(void (^)(void (^)(NSError *)))operation completion:(void (^)(NSError *))completion {
    if (!self.available) { completion(RPError(1,@"Native writes are unavailable. Your replacements have not been changed.")); return; }
    NSLock *lock=[NSLock new]; __block BOOL finished=NO;
    void (^finish)(NSError *) = ^(NSError *error) {
        [lock lock]; BOOL shouldFinish=!finished; finished=YES; [lock unlock];
        if (shouldFinish) completion(error);
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 8*NSEC_PER_SEC),dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        finish(RPError(4,@"Native write timed out. It may still complete. Refresh before making another change; do not retry blindly."));
    });
    @try { operation(finish); }
    @catch (NSException *exception) { finish(RPError(5,@"KeyboardServices rejected this operation.")); }
}
- (void)addShortcut:(NSString *)shortcut phrase:(NSString *)phrase completion:(void (^)(NSError *))completion {
    [self performWrite:^(void (^reply)(NSError *)) {
        id entry=[self entryWithShortcut:shortcut phrase:phrase];
        ((void(*)(id,SEL,BOOL))objc_msgSend)(entry,NSSelectorFromString(@"setNeedsSaveToCloud:"),YES);
        ((void(*)(id,SEL,id,id,id))objc_msgSend)(self.store,NSSelectorFromString(@"addEntries:removeEntries:withCompletionHandler:"),@[entry],@[],reply);
    } completion:completion];
}
- (void)removeShortcut:(NSString *)shortcut phrase:(NSString *)phrase completion:(void (^)(NSError *))completion {
    [self performWrite:^(void (^reply)(NSError *)) {
        id entry=[self entryWithShortcut:shortcut phrase:phrase];
        ((void(*)(id,SEL,id,id,id))objc_msgSend)(self.store,NSSelectorFromString(@"addEntries:removeEntries:withCompletionHandler:"),@[],@[entry],reply);
    } completion:completion];
}
- (void)modifyShortcut:(NSString *)shortcut phrase:(NSString *)phrase toShortcut:(NSString *)newShortcut phrase:(NSString *)newPhrase completion:(void (^)(NSError *))completion {
    [self performWrite:^(void (^reply)(NSError *)) {
        id old=[self entryWithShortcut:shortcut phrase:phrase], fresh=[self entryWithShortcut:newShortcut phrase:newPhrase];
        ((void(*)(id,SEL,BOOL))objc_msgSend)(fresh,NSSelectorFromString(@"setNeedsSaveToCloud:"),YES);
        ((void(*)(id,SEL,id,id,id))objc_msgSend)(self.store,NSSelectorFromString(@"modifyEntry:toEntry:withCompletionHandler:"),old,fresh,reply);
    } completion:completion];
}
- (NSArray *)readDatabaseAtPath:(NSString *)path error:(NSError **)error {
    sqlite3 *db=NULL;
    if (sqlite3_open_v2(path.fileSystemRepresentation,&db,SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX,NULL)!=SQLITE_OK) {
        if(error)*error=RPError(10,@"Cannot read the native database. No database has been created or changed.");
        if(db)sqlite3_close(db);return nil;
    }
    sqlite3_busy_timeout(db,1500);
    sqlite3_stmt *stmt=NULL;
    const char *sql="SELECT Z_PK,ZUNIQUENAME,ZSHORTCUT,ZPHRASE FROM ZTEXTREPLACEMENTENTRY WHERE COALESCE(ZWASDELETED,0)=0 ORDER BY Z_PK";
    if(sqlite3_prepare_v2(db,sql,-1,&stmt,NULL)!=SQLITE_OK) {
        if(error)*error=RPError(11,@"The native database schema is unsupported. Writes are disabled.");sqlite3_close(db);return nil;
    }
    NSMutableArray *rows=[NSMutableArray new]; int status;
    while((status=sqlite3_step(stmt))==SQLITE_ROW) {
        NSString *(^str)(int)=^NSString *(int col){const unsigned char *p=sqlite3_column_text(stmt,col);return p?[[NSString alloc] initWithUTF8String:(const char *)p]:nil;};
        NSString *phrase=str(3), *shortcut=str(2);
        if(!phrase) { if(error)*error=RPError(12,@"A native row cannot be decoded safely.");sqlite3_finalize(stmt);sqlite3_close(db);return nil; }
        [rows addObject:@{@"id":str(1) ?: [NSString stringWithFormat:@"db:%lld",sqlite3_column_int64(stmt,0)],@"shortcut":shortcut?:@"",@"phrase":phrase}];
    }
    sqlite3_finalize(stmt);sqlite3_close(db);
    if(status!=SQLITE_DONE) { if(error)*error=RPError(13,@"The native database read did not complete.");return nil; }
    return rows;
}
@end
