//
//  Arbitrator.m
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 1/10/10.
//  Copyright 2010 Aaron Burghardt. All rights reserved.
//

#import "Arbitrator.h"
#import "Disk.h"
#import "DiskArbitrationPrivateFunctions.h"


@implementation Arbitrator

@synthesize disks;
@synthesize isActivated;
@synthesize mountMode;

+ (void)initialize
{
	InitializeDiskArbitration();
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
	if ([key isEqual:@"wholeDisks"])
		return [NSSet setWithObject:@"disks"];
	
	return [super keyPathsForValuesAffectingValueForKey:key];
}

- (id)init
{
	if (self = [super init]) 
	{
		disks = [NSMutableSet new];
		[self registerSession];
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
	Disk *disk = [notif object];

	fprintf(stderr, "%s disk: %s\n", __FUNCTION__, [disk.BSDName UTF8String]);

	[[self mutableSetValueForKey:@"disks"] addObject:disk];

	if (self.isActivated && mountMode == MM_READONLY && disk.mountable && !disk.mounted) {

		CFDictionaryRef desc = disk.diskDescription;
		CFStringRef volumeKindRef = CFDictionaryGetValue(desc, kDADiskDescriptionVolumeKindKey);

		// Arguments will be passed via the -o flag of mount. If the file system specific mount, e.g. mount_hfs,
		// supports additional flags that mount(8) doesn't, they can be passed to -o.  That feature is used to
		// pass -j to mount_hfs, which instructs HFS to ignore journal.  Normally, an HFS volume that
		// has a dirty journal will fail to mount read-only because the file system is inconsistent.  "-j" is
		// a work-around.

		NSArray *args;
		if ([@"hfs" isEqual:(NSString *)volumeKindRef])
			args = [NSArray arrayWithObjects:@"-j", @"rdonly", nil];
		else
			args = [NSArray arrayWithObjects:@"rdonly", nil];

		[disk performSelector:@selector(mountWithArguments:) withObject:args afterDelay:0.0];
	}
}

- (void)diskDidDisappear:(NSNotification *)notif
{
	[[self mutableSetValueForKey:@"disks"] removeObject:[notif object]];
}

- (void)diskDidChange:(NSNotification *)notif
{
	fprintf(stderr, "Changed disk notification: %s\n", [[notif description] UTF8String]);
}

- (BOOL)registerApprovalSession
{
	approvalSession = DAApprovalSessionCreate(kCFAllocatorDefault);
	if (!approvalSession) {
		fprintf(stderr, "Failed to create Disk Arbitration approval session.\n");
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
		approvalSession = NULL;
	}
}

- (BOOL)activate
{
	BOOL success;
	
	[self willChangeValueForKey:@"isActivated"];
	success = [self registerApprovalSession];
	[self didChangeValueForKey:@"isActivated"];	
	
	return success;
}

- (void)deactivate
{
	[self willChangeValueForKey:@"isActivated"];
	[self unregisterApprovalSession];	
	[self didChangeValueForKey:@"isActivated"];	
}

- (BOOL)isActivated
{
	return approvalSession ? YES : NO;
}

- (NSSet *)wholeDisks
{
	NSMutableSet *wholeDisks = [NSMutableSet new];

	for (Disk *disk in disks)
		if ([disk isWholeDisk])
			[wholeDisks addObject:disk];
	
	return [wholeDisks autorelease];
}

#pragma mark Disks KVC Methods

- (NSUInteger)countOfDisks
{
	return [disks count];
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

DADissenterRef DiskMountApprovalCallback(DADiskRef diskRef, void *arbitrator)
{
	fprintf(stderr, "%s called: %p %s\n", __FUNCTION__, diskRef, DADiskGetBSDName(diskRef));
	fprintf(stderr, "\t claimed: %s\n\n", DADiskIsClaimed(diskRef) ? "Yes" : "No");

	Disk *disk = [[Disk alloc] initWithDiskRef:diskRef];
	
	DADissenterRef dissenter;

	if (disk.mounting) {
		disk.mounting = NO;
		dissenter = NULL;
	}
	else {
		 dissenter = DADissenterCreate(kCFAllocatorDefault,
												 kDAReturnNotPermitted, 
												 CFSTR("Disk Arbitrator is in charge"));
	}
	[disk release];

	return dissenter;
}

void DiskClaimCallback(DADiskRef disk, DADissenterRef dissenter, void *arbitrator)
{
	fprintf(stderr, "%s called: %p %s\n", __FUNCTION__, disk, DADiskGetBSDName(disk));
	fprintf(stderr, "\t claimed: %s\n\n", DADiskIsClaimed(disk) ? "Yes" : "No");
	
	if (dissenter)
		CFShow(dissenter);
}

DADissenterRef DiskClaimReleaseCallback(DADiskRef disk, void *arbitrator)
{
	fprintf(stderr, "%s called: %p %s\n", __FUNCTION__, disk, DADiskGetBSDName(disk));
	fprintf(stderr, "\t claimed: %s\n\n", DADiskIsClaimed(disk) ? "Yes" : "No");

	return NULL;

	DADissenterRef dissenter = DADissenterCreate(kCFAllocatorDefault,
												 kDAReturnNotPermitted, 
												 CFSTR("DiskArbitrator is in charge"));
	
	return dissenter;
}

