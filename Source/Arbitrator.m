//
//  Arbitrator.m
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 1/10/10.
//  Copyright 2010 . All rights reserved.
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
	[[self mutableSetValueForKey:@"disks"] addObject:[notif object]];
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

DADissenterRef DiskMountApprovalCallback(DADiskRef disk, void *arbitrator)
{
	fprintf(stderr, "%s called: %p %s\n", __FUNCTION__, disk, DADiskGetBSDName(disk));
	fprintf(stderr, "\t claimed: %s\n\n", DADiskIsClaimed(disk) ? "Yes" : "No");

//	DADiskClaim(disk, kDADiskClaimOptionDefault, DiskClaimReleaseCallback, arbitrator, DiskClaimCallback, arbitrator);
	
//	return NULL;
	DADissenterRef dissenter = DADissenterCreate(kCFAllocatorDefault,
												 kDAReturnNotPermitted, 
												 CFSTR("DiskArbitrator is in charge"));
	
	return dissenter;
}

void DiskClaimCallback(DADiskRef disk, DADissenterRef dissenter, void *arbitrator)
{
	fprintf(stderr, "%s called: %p %s\n", __FUNCTION__, disk, DADiskGetBSDName(disk));
	fprintf(stderr, "\t claimed: %s\n\n", DADiskIsClaimed(disk) ? "Yes" : "No");
	
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

