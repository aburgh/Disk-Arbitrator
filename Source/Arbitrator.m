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
				[self dealloc];
				return nil;
			}
		}
	}
	return self;
}

- (void)dealloc
{
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

	if (self.isActivated && self.mountMode == MM_READONLY && disk.isMountable && !disk.isMounted) {

		CFDictionaryRef desc = disk.diskDescription;
		NSString *volumeKindRef = (NSString *)CFDictionaryGetValue(desc, kDADiskDescriptionVolumeKindKey);

		// Arguments will be passed via the -o flag of mount. If the file system specific mount, e.g. mount_hfs,
		// supports additional flags that mount(8) doesn't, they can be passed to -o.  That feature is used to
		// pass -j to mount_hfs, which instructs HFS to ignore journal.  Normally, an HFS volume that
		// has a dirty journal will fail to mount read-only because the file system is inconsistent.  "-j" is
		// a work-around.

		NSArray *args;
		if ([volumeKindRef isEqual:@"hfs"])
			args = [NSArray arrayWithObjects:@"-j", @"rdonly", nil];
		else
			args = [NSArray arrayWithObjects:@"rdonly", nil];

		[disk mountAtPath:nil withArguments:args];
	}
}

- (void)diskDidDisappear:(NSNotification *)notif
{
	[self removeDisksObject:notif.object];
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
		CFRelease(approvalSession);
		approvalSession = NULL;
	}
}

- (BOOL)activate
{
	BOOL success;
	
	[self willChangeValueForKey:@"isActivated"];
	success = [self registerApprovalSession];
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:ArbitratorIsEnabled];
	[self didChangeValueForKey:@"isActivated"];	
	
	return success;
}

- (void)deactivate
{
	[self willChangeValueForKey:@"isActivated"];
	[self unregisterApprovalSession];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:ArbitratorIsEnabled];
	[self didChangeValueForKey:@"isActivated"];	
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

- (void)setMountMode:(NSInteger)mountMode {
	NSInteger currentMode = [[NSUserDefaults standardUserDefaults] integerForKey:ArbitratorMountMode];
	if (currentMode != mountMode) {
		[self willChangeValueForKey:@"mountMode"];
		[[NSUserDefaults standardUserDefaults] setInteger:mountMode forKey:ArbitratorMountMode];
		[self didChangeValueForKey:@"mountMode"];
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
    [disks removeObject:anObject];
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

	DADissenterRef dissenter;

	if (disk.isMounting) {
		disk.isMounting = NO;
		dissenter = NULL;
	}
	else {
		 dissenter = DADissenterCreate(kCFAllocatorDefault,
									   kDAReturnNotPermitted, 
									   CFSTR("Disk Arbitrator is in charge"));
	}

	Log(LOG_DEBUG, @"Mount allowed: %s", dissenter ? "No" : "Yes");
	return dissenter;
}

void DiskClaimCallback(DADiskRef disk, DADissenterRef dissenter, void *arbitrator)
{
	Log(LOG_DEBUG, @"%s called: %p %s", __func__, disk, DADiskGetBSDName(disk));
	Log(LOG_DEBUG, @"\t claimed: %s", DADiskIsClaimed(disk) ? "Yes" : "No");
	
	if (dissenter)
		CFShow(dissenter);
}

DADissenterRef DiskClaimReleaseCallback(DADiskRef disk, void *arbitrator)
{
	Log(LOG_DEBUG, @"%s called: %p %s", __func__, disk, DADiskGetBSDName(disk));
	Log(LOG_DEBUG, @"\t claimed: %s\n", DADiskIsClaimed(disk) ? "Yes" : "No");

	return NULL;

	DADissenterRef dissenter = DADissenterCreate(kCFAllocatorDefault,
												 kDAReturnNotPermitted, 
												 CFSTR("DiskArbitrator is in charge"));
	
	return dissenter;
}

NSString * const ArbitratorIsEnabled = @"ArbitratorIsEnabled";
NSString * const ArbitratorMountMode = @"ArbitratorMountMode";

