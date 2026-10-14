//
//  Arbitrator.m
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 1/10/10.
//  Copyright 2010 Aaron Burghardt. All rights reserved.
//

#import "Arbitrator.h"
#import "AppError.h"
#import "Disk.h"
#import "DiskArbitrationPrivateFunctions.h"
#import "AuditLog.h"
#import "TrustedDiskStore.h"

////////////////////////////////////////////////////////////////////////////////

@interface Arbitrator ()
{
	DAApprovalSessionRef approvalSession;
}

@end

////////////////////////////////////////////////////////////////////////////////

@implementation Arbitrator

@synthesize disks;

+ (void)initialize
{
	InitializeDiskArbitration();
	
	NSMutableDictionary *defaults = [NSMutableDictionary dictionary];
	[defaults setObject:[NSNumber numberWithBool:YES] forKey:ArbitratorIsEnabled];
	[defaults setObject:[NSNumber numberWithInteger:0] forKey:ArbitratorMountMode];
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
	if ([key isEqual:@"wholeDisks"])
		return [NSSet setWithObject:@"disks"];
	
	return [super keyPathsForValuesAffectingValueForKey:key];
}

- (id)init
{
	self = [super init];
	if (self)
	{
		disks = [NSMutableSet new];
		[self registerSession];

		if ([[NSUserDefaults standardUserDefaults] boolForKey:ArbitratorIsEnabled]) {
			if ([self activate] == NO) {
				[self release];
				return nil;
			}
		}
	}
	return self;
}

- (void)dealloc
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];

	if (approvalSession)
		[self deactivate];
	
	[self unregisterSession];
	
	[disks release];
	[super dealloc];	
}

- (BOOL)registerSession
{
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	
	[nc addObserver:self selector:@selector(diskDidAppear:) name:DADiskDidAppearNotification object:nil];
	[nc addObserver:self selector:@selector(diskDidDisappear:) name:DADiskDidDisappearNotification object:nil];
	[nc addObserver:self selector:@selector(diskDidChange:) name:DADiskDidChangeNotification object:nil];

	return YES;
}

- (void)unregisterSession
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)diskDidAppear:(NSNotification *)notif
{
	Disk *disk = notif.object;

	Log(LOG_DEBUG, @"%s disk: %@", __func__, disk.BSDName);

	[self addDisksObject:disk];
	[[AuditLog sharedLog] recordEvent:DAAuditEventAppeared disk:disk action:@"observed" message:nil];
}

- (void)diskDidDisappear:(NSNotification *)notif
{
	Disk *disk = notif.object;
	[[AuditLog sharedLog] recordEvent:DAAuditEventDisappeared disk:disk action:@"observed" message:nil];
	[self removeDisksObject:disk];
}

- (void)diskDidChange:(NSNotification *)notif
{
	Log(LOG_DEBUG, @"Changed disk notification: %@", notif.description);
}

- (BOOL)registerApprovalSession
{
	approvalSession = DAApprovalSessionCreate(kCFAllocatorDefault);
	if (!approvalSession) {
		Log(LOG_CRIT, @"Failed to create Disk Arbitration approval session.");
		return NO;
	}
	
	DAApprovalSessionScheduleWithRunLoop(approvalSession, CFRunLoopGetMain(), kCFRunLoopCommonModes);

	DARegisterDiskMountApprovalCallback(approvalSession, NULL, DiskMountApprovalCallback, self);
	
	return YES;
}

- (void)unregisterApprovalSession
{
	if (approvalSession) {
		DAUnregisterApprovalCallback(approvalSession, DiskMountApprovalCallback, self);

		DAApprovalSessionUnscheduleFromRunLoop(approvalSession, CFRunLoopGetMain(), kCFRunLoopCommonModes);
		SafeCFRelease(approvalSession);
		approvalSession = NULL;
	}
}

- (void)mountApprovedDisk:(Disk *)disk
{
	// Only the read-only mode replaces a blocked system mount. Block mode leaves the volume unmounted.
	// Always request rdonly here. Reusing mountArgs from an earlier manual mount could remount read-write.
	if (!self.isActivated || self.mountMode != MM_READONLY)
		return;
	if (!disk.isAttached || !disk.isMountable || disk.isMounted || disk.isMounting)
		return;

	// Arguments are passed via mount -o. "-j" is mount_hfs's ignore-journal flag, so a dirty HFS
	// volume can still be mounted read-only. APFS, FAT, and exFAT do not take that flag.
	NSArray *args = disk.isHFS ? [NSArray arrayWithObjects:@"-j", @"rdonly", nil] : [NSArray arrayWithObjects:@"rdonly", nil];
	[disk mountAtPath:nil withArguments:args];
}

- (NSString *)dissenterMessage
{
	return @"Disk Arbitrator is in charge";
}

- (DADissenterRef)defaultDissenter __attribute__((cf_returns_retained))
{
	return DADissenterCreate(kCFAllocatorDefault, kDAReturnNotPermitted, (CFStringRef)self.dissenterMessage);
}

- (DADissenterRef)approveMount:(Disk *)disk __attribute__((cf_returns_retained))
{
	if (!self.isActivated)
		return NULL;

	// mountAtPath: sets this immediately before DADiskMountWithArguments. That call does not
	// spin the run loop, so the next approval delivered for this disk is the one we just issued
	// (a manual mount, or the read-only remount below). A system retry that arrives before that
	// flag is set must keep being rejected — allowing it was a read-write hole.
	if (disk.allowNextMount) {
		disk.allowNextMount = NO;
		disk.rejectedMount = NO;
		return NULL;
	}

	// A trusted disk mounts the way the system asked. Block and read-only still apply to every other disk.
	TrustedDiskRule *trusted = [[TrustedDiskStore sharedStore] ruleMatchingDisk:disk];
	if (trusted) {
		NSString *message = [NSString stringWithFormat:@"%@ %@", trusted.kind, trusted.identifier];
		[[AuditLog sharedLog] recordEvent:DAAuditEventRuleMatched disk:disk action:@"allowed_normal_mount" message:message];
		return NULL;
	}

	// Read-only mode dissents, then mounts again with rdonly. Block mode dissents and leaves it unmounted.
	BOOL scheduleReadOnly = (self.mountMode == MM_READONLY && !disk.rejectedMount && disk.isMountable && disk.isAttached);
	if (scheduleReadOnly) {
		disk.rejectedMount = YES;
		// Let diskarbitrationd finish the dissented mount before we submit our own.
		[self performSelector:@selector(mountApprovedDisk:) withObject:disk afterDelay:0.25];
	}

	[[AuditLog sharedLog] recordEvent:DAAuditEventBlocked
								  disk:disk
								action:(scheduleReadOnly ? @"dissented_read_only_remount" : @"dissented")
							   message:self.dissenterMessage];

	return [self defaultDissenter];
}

- (BOOL)activate
{
	BOOL success;
	BOOL wasActivated = self.isActivated;
	
	[self willChangeValueForKey:@"isActivated"];
	success = [self registerApprovalSession];
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:ArbitratorIsEnabled];
	[self didChangeValueForKey:@"isActivated"];

	// Log the transition only. A second activate while the session is already up is not a new mode.
	if (success && !wasActivated)
		[[AuditLog sharedLog] recordModeChange:@"activated"];
	
	return success;
}

- (void)deactivate
{
	BOOL wasActivated = self.isActivated;

	for (Disk *disk in disks)
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(mountApprovedDisk:) object:disk];

	[self willChangeValueForKey:@"isActivated"];
	[self unregisterApprovalSession];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:ArbitratorIsEnabled];
	[self didChangeValueForKey:@"isActivated"];

	if (wasActivated)
		[[AuditLog sharedLog] recordModeChange:@"deactivated"];
}

- (BOOL)isActivated
{
	return approvalSession ? YES : NO;
}

- (void)setIsActivated:(BOOL)shouldActivate
{
	if (shouldActivate && !self.isActivated)
		[self activate];

	else if (!shouldActivate && self.isActivated)
		[self deactivate];
}

- (NSInteger)mountMode {
	return [[NSUserDefaults standardUserDefaults] integerForKey:ArbitratorMountMode];
}

- (void)recordMountModeChangeFrom:(NSInteger)previous to:(NSInteger)mountMode
{
	// One entry for each mode that actually flipped. Switching block to read-only is
	// "blocking off" and "read-only on", not a refresh of the window.
	if (previous == MM_BLOCK && mountMode != MM_BLOCK)
		[[AuditLog sharedLog] recordModeChange:@"blocking off"];
	else if (previous != MM_BLOCK && mountMode == MM_BLOCK)
		[[AuditLog sharedLog] recordModeChange:@"blocking on"];

	if (previous == MM_READONLY && mountMode != MM_READONLY)
		[[AuditLog sharedLog] recordModeChange:@"read-only off"];
	else if (previous != MM_READONLY && mountMode == MM_READONLY)
		[[AuditLog sharedLog] recordModeChange:@"read-only on"];
}

- (void)setMountMode:(NSInteger)mountMode {
	NSInteger currentMode = [[NSUserDefaults standardUserDefaults] integerForKey:ArbitratorMountMode];
	if (currentMode != mountMode) {
		[self willChangeValueForKey:@"mountMode"];
		[[NSUserDefaults standardUserDefaults] setInteger:mountMode forKey:ArbitratorMountMode];
		[self didChangeValueForKey:@"mountMode"];
		[self recordMountModeChangeFrom:currentMode to:mountMode];
	}
}

- (NSSet *)wholeDisks
{
	NSMutableSet *wholeDisks = [NSMutableSet new];

	for (Disk *disk in disks)
		if (disk.isWholeDisk)
			[wholeDisks addObject:disk];
	
	return [wholeDisks autorelease];
}

#pragma mark Disks KVC Methods

- (NSUInteger)countOfDisks
{
	return disks.count;
}

- (NSEnumerator *)enumeratorOfDisks
{
    return [disks objectEnumerator];
}

- (Disk *)memberOfDisks:(Disk *)anObject
{
    return [disks member:anObject];
}

- (void)addDisksObject:(Disk *)object
{
	[disks addObject:object];
}

- (void)addDisks:(NSSet *)objects
{
    [disks unionSet:objects];
}

- (void)removeDisksObject:(Disk *)anObject
{
	if (anObject) {
		[disks removeObject:anObject];
	}
}

- (void)removeDisks:(NSSet *)objects
{
    [disks minusSet:objects];
}

@end

#pragma mark Callbacks

DADissenterRef __attribute__((cf_returns_retained)) DiskMountApprovalCallback(DADiskRef diskRef, void *arbitrator)
{
	Log(LOG_DEBUG, @"%s called: %p %s", __func__, diskRef, DADiskGetBSDName(diskRef));
	Log(LOG_DEBUG, @"\t claimed: %s", DADiskIsClaimed(diskRef) ? "Yes" : "No");

	Disk *disk = [Disk uniqueDiskForDADisk:diskRef create:YES];
	
	Log(LOG_DEBUG, @"%@", disk.diskDescription);

	DADissenterRef dissenter = [(Arbitrator*)arbitrator approveMount:disk];

	Log(LOG_DEBUG, @"Mount allowed: %s", dissenter ? "No" : "Yes");
	return dissenter;
}

NSString * const ArbitratorIsEnabled = @"ArbitratorIsEnabled";
NSString * const ArbitratorMountMode = @"ArbitratorMountMode";

