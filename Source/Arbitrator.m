//
//  Arbitrator.m
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 1/10/10.
//  Copyright 2010 . All rights reserved.
//

#import "Arbitrator.h"
#import "Disk.h"

@interface Disk (DiskPrivate)
- (void)diskDidDisappear;
@end

@implementation Arbitrator

@synthesize disks;
@synthesize isActivated;
@synthesize mountMode;

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
	
	if (session)
		[self unregisterSession];
	
	[disks release];
	[super dealloc];	
}

- (BOOL)registerSession
{
	session = DASessionCreate(kCFAllocatorDefault);
	if (!session) {
		fprintf(stderr, "Failed to create Disk Arbitration session.\n");
		return NO;
	}
	
	runLoop = CFRunLoopGetCurrent();
	DASessionScheduleWithRunLoop(session, runLoop, kCFRunLoopCommonModes);
	
//	NSDictionary *matching = [NSDictionary dictionaryWithObjectsAndKeys:nil];
	
	DARegisterDiskAppearedCallback(session, NULL, DiskAppearedCallback, self);
	DARegisterDiskDisappearedCallback(session, NULL, DiskDisappearedCallback, self);
	DARegisterDiskDescriptionChangedCallback(session, NULL, NULL, DiskDescriptionChangedCallback, self);
	
	return YES;
}

- (void)unregisterSession
{
	if (session) {
		DAUnregisterCallback(session, DiskAppearedCallback, self);
		DAUnregisterCallback(session, DiskDisappearedCallback, self);
		DAUnregisterCallback(session, DiskDescriptionChangedCallback, self);

		DASessionUnscheduleFromRunLoop(session, runLoop, kCFRunLoopCommonModes);
		session = NULL;
	}
}

- (BOOL)registerApprovalSession
{
	approvalSession = DAApprovalSessionCreate(kCFAllocatorDefault);
	if (!approvalSession) {
		fprintf(stderr, "Failed to create Disk Arbitration approval session.\n");
		return NO;
	}
	
	DAApprovalSessionScheduleWithRunLoop(approvalSession, runLoop, kCFRunLoopCommonModes);

	DARegisterDiskMountApprovalCallback(approvalSession, NULL, DiskMountApprovalCallback, self);
	
	return YES;
}

- (void)unregisterApprovalSession
{
	if (approvalSession) {
		DAUnregisterApprovalCallback(approvalSession, DiskMountApprovalCallback, self);

		DAApprovalSessionUnscheduleFromRunLoop(approvalSession, runLoop, kCFRunLoopCommonModes);
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

NSString * BSDNameFromDADisk(DADiskRef disk)
{
	const char *name = DADiskGetBSDName(disk);
	
	return name ? [NSString stringWithUTF8String:name] : nil;
}

#pragma mark Callbacks

void DiskAppearedCallback(DADiskRef diskRef, void *arbitrator)
{
	fprintf(stderr, "disk %p appeared: %s\n", diskRef, DADiskGetBSDName(diskRef));
	
	//
	// Reject certain disk media
	//

	BOOL isOK = YES;
	
	CFDictionaryRef desc = DADiskCopyDescription(diskRef);
//	CFShow(desc);
	
	// Reject if no BSDName
	if (DADiskGetBSDName(diskRef) == NULL) isOK = NO;
	
	// Reject if no key-value for Whole Media
	CFBooleanRef wholeMediaValue = CFDictionaryGetValue(desc, kDADiskDescriptionMediaWholeKey);
	if (isOK && !wholeMediaValue) isOK = NO;
	
	// If not a whole disk, then must be a media leaf
	if (isOK && CFBooleanGetValue(wholeMediaValue) == false)
	{
		CFBooleanRef mediaLeafValue = CFDictionaryGetValue(desc, kDADiskDescriptionMediaLeafKey);
		if (!mediaLeafValue || CFBooleanGetValue(mediaLeafValue) == false) isOK = NO;
	}
	CFRelease(desc);
	if (!isOK) return;
	
	//
	// Disk accepted
	//
	Disk *disk = [Disk diskWithDiskRef:diskRef];

	Arbitrator *arb = (Arbitrator *)arbitrator;
	NSMutableSet *disks = [arb mutableSetValueForKey:@"disks"];

	if ([disks containsObject:disk] == NO)
		[disks addObject:disk];
}	

void DiskDisappearedCallback(DADiskRef diskRef, void *arbitrator)
{
	fprintf(stderr, "disk %p disappeared: %s\n", diskRef, DADiskGetBSDName(diskRef));
	
	Arbitrator *arb = (Arbitrator *)arbitrator;
	NSMutableSet *disks = [arb mutableSetValueForKey:@"disks"];
	
	Disk *tmpDisk = [Disk diskWithDiskRef:diskRef];

	[tmpDisk diskDidDisappear];
	[disks removeObject:tmpDisk];
}

void DiskDescriptionChangedCallback(DADiskRef diskRef, CFArrayRef keys, void *arbitrator)
{
	fprintf(stderr, "disk %p description changed: %s\n", diskRef, DADiskGetBSDName(diskRef));
	CFShow(keys);

	Disk *disk = [Disk diskWithDiskRef:diskRef];
	CFDictionaryRef desc = DADiskCopyDescription(diskRef);
	disk.description = desc;
	CFRelease(desc);
}

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

