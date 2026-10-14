#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/// All completion handlers fire exactly once; timeouts do not cancel native writes.
@interface RPKeyboardBridge : NSObject
@property (readonly) BOOL available;
- (void)queryWithCompletion:(void (^)(NSArray<NSDictionary<NSString *, id> *> * _Nullable, NSError * _Nullable))completion;
- (void)addShortcut:(NSString *)shortcut phrase:(NSString *)phrase completion:(void (^)(NSError * _Nullable))completion;
- (void)removeShortcut:(NSString *)shortcut phrase:(NSString *)phrase completion:(void (^)(NSError * _Nullable))completion;
- (void)modifyShortcut:(NSString *)shortcut phrase:(NSString *)phrase toShortcut:(NSString *)newShortcut phrase:(NSString *)newPhrase completion:(void (^)(NSError * _Nullable))completion;
/// Opens SQLite with SQLITE_OPEN_READONLY, never creates or changes the native database.
- (nullable NSArray<NSDictionary<NSString *, id> *> *)readDatabaseAtPath:(NSString *)path error:(NSError **)error;
@end
NS_ASSUME_NONNULL_END
