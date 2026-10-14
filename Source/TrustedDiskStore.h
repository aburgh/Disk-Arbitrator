//
//  TrustedDiskStore.h
//  DiskArbitrator
//
//  Disks the user has marked trusted mount normally. Block and read-only
//  mode still apply to everything else.

#import <Foundation/Foundation.h>

@class Disk;

extern NSString * const TrustedDiskStoreDidChangeNotification;

@interface TrustedDiskRule : NSObject

@property (copy) NSString *identifier;
@property (copy) NSString *kind; // "volume" or "media"
@property (copy) NSString *displayName;
@property (copy) NSString *bsdName;
@property (copy) NSString *fileSystem;
@property (copy) NSString *addedAt;

@end

@interface TrustedDiskStore : NSObject

+ (TrustedDiskStore *)sharedStore;

@property (readonly, copy) NSArray<TrustedDiskRule *> *rules;

- (TrustedDiskRule *)ruleMatchingDisk:(Disk *)disk;
- (TrustedDiskRule *)trustDisk:(Disk *)disk error:(NSError **)error;
- (BOOL)removeRulesAtIndexes:(NSIndexSet *)indexes error:(NSError **)error;

@end

@interface TrustedDisksWindowController : NSWindowController

+ (TrustedDisksWindowController *)sharedController;

@end
