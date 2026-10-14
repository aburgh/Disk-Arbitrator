//
//  AuditLog.h
//  DiskArbitrator
//
//  Append-only JSON Lines log of disk events.

#import <Foundation/Foundation.h>

@class Disk;

extern NSString * const DAAuditEventAppeared;
extern NSString * const DAAuditEventDisappeared;
extern NSString * const DAAuditEventBlocked;
extern NSString * const DAAuditEventMountedReadOnly;
extern NSString * const DAAuditEventMountedReadWrite;
extern NSString * const DAAuditEventUnmounted;
extern NSString * const DAAuditEventEjected;
extern NSString * const DAAuditEventError;
extern NSString * const DAAuditEventRuleMatched;
extern NSString * const DAAuditEventModeChanged;

/* Stable string for a Disk Arbitration description value (string, UUID, or number). */
NSString *DAStringFromDescriptionValue(id value);
NSString *DAVolumeUUIDForDisk(Disk *disk);
NSString *DAMediaUUIDForDisk(Disk *disk);

@interface AuditLog : NSObject

+ (AuditLog *)sharedLog;

@property (readonly, copy) NSURL *logFileURL;

- (void)recordEvent:(NSString *)event disk:(Disk *)disk action:(NSString *)action message:(NSString *)message;

/* Blocking, read-only, and activation changes. The line is timestamped like every other event.
 * The macOS user name (NSUserName()) is stored on the entry. state is the new mode, for example
 * "blocking on", "read-only off", "activated", or "deactivated".
 */
- (void)recordModeChange:(NSString *)state;

/* Newest first. limit 0 reads the whole file. */
- (NSArray<NSDictionary *> *)entriesWithLimit:(NSUInteger)limit;

- (BOOL)exportJSONToURL:(NSURL *)url error:(NSError **)error;
- (BOOL)exportCSVToURL:(NSURL *)url error:(NSError **)error;
- (void)revealInFinder;

@end

@interface AuditLogWindowController : NSWindowController

+ (AuditLogWindowController *)sharedController;

@end
