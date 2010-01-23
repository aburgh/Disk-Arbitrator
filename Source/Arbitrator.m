//
//  Arbitrator.m
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 1/10/10.
//  Copyright 2010 . All rights reserved.
//

#import "Arbitrator.h"
#import "Disk.h"


@implementation Arbitrator

@synthesize disks;
@synthesize isActivated;

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
		disks = [NSMutableArray new];
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

- (NSArray *)wholeDisks
{
	NSMutableArray *wholeDisks = [NSMutableArray new];
	for (Disk *disk in disks)
		if ([disk isWholeDisk])
			[wholeDisks addObject:disk];
	
	return wholeDisks;
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
	fprintf(stderr, "disk appeared: %s\n", DADiskGetBSDName(diskRef));

	//
	// Reject certain disk media
	//
	
	// Reject if no BSDName
	if (DADiskGetBSDName(diskRef) == NULL)
		return;
	
	CFDictionaryRef desc = DADiskCopyDescription(diskRef);
	
	// Reject if no key-value for Whole Media
	CFBooleanRef wholeMediaValue = CFDictionaryGetValue(desc, kDADiskDescriptionMediaWholeKey);
	if (!wholeMediaValue)
		return;
	
	// If not a whole disk, then must be a media leaf
	if (CFBooleanGetValue(wholeMediaValue) == false)
	{
		CFBooleanRef mediaLeafValue = CFDictionaryGetValue(desc, kDADiskDescriptionMediaLeafKey);
		if (!mediaLeafValue || CFBooleanGetValue(mediaLeafValue) == false)
			return;
	}
		
	//
	// Disk accepted
	//
	Arbitrator *arb = (Arbitrator *)arbitrator;
	Disk *disk = [Disk diskWithDiskRef:diskRef];

	NSMutableArray *disks = [arb mutableArrayValueForKey:@"disks"];
	
	if ([disks containsObject:disk])
		return;
	
	[disks addObject:disk];
	
	if ([disk isWholeDisk] == NO) {
		Disk *parentDisk = [Disk diskWithDiskRef:DADiskCopyWholeDisk(diskRef)];
	
		// We are going to add the new disk to its parent, so we need the actual parent disk object
		// from the disks array, not just a disk that matches isEqual:.  For efficiency, the algorithm 
		// enumerates the disks only once

		NSUInteger parentIndex = [disks indexOfObject:parentDisk];
		if (parentIndex == NSNotFound)
			[disks addObject:parentDisk];
		else 
			parentDisk = [disks objectAtIndex:parentIndex];

		[[parentDisk mutableArrayValueForKey:@"children"] addObject:disk];
	}
}

void DiskDisappearedCallback(DADiskRef diskRef, void *arbitrator)
{
	fprintf(stderr, "disk disappeared: %s\n", DADiskGetBSDName(diskRef));

	Arbitrator *arb = (Arbitrator *)arbitrator;
	NSMutableArray *disks = [arb mutableArrayValueForKey:@"wholeDisks"];

	Disk *tmpDisk = [Disk diskWithDiskRef:diskRef];
	
	if ([tmpDisk isWholeDisk]) {
		[disks removeObject:tmpDisk];
	}
	else {
		Disk *parentDisk = [Disk diskWithDiskRef:DADiskCopyWholeDisk(diskRef)];
		for (Disk *potentialParent in disks) {
			if ([potentialParent isEqual:parentDisk])
				[[potentialParent mutableArrayValueForKey:@"children"] removeObject:tmpDisk];
		}
	}
}

void DiskDescriptionChangedCallback(DADiskRef diskRef, CFArrayRef keys, void *arbitrator)
{
	fprintf(stderr, "disk description changed: %s\n", DADiskGetBSDName(diskRef));
	CFShow(keys);

	Disk *tmpDisk = [Disk diskWithDiskRef:diskRef];
	NSMutableArray *disks = [(Arbitrator *)arbitrator mutableArrayValueForKey:@"disks"];
	Disk *disk = [disks objectAtIndex:[disks indexOfObject:tmpDisk]];
	[disk setDescription:[tmpDisk description]];
}

DADissenterRef DiskMountApprovalCallback(DADiskRef disk, void *arbitrator)
{
	fprintf(stderr, "%s called: %s\n", __FUNCTION__, DADiskGetBSDName(disk));
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
	fprintf(stderr, "%s called: %s\n", __FUNCTION__, DADiskGetBSDName(disk));
	fprintf(stderr, "\t claimed: %s\n\n", DADiskIsClaimed(disk) ? "Yes" : "No");
	
	CFShow(dissenter);
	
}

DADissenterRef DiskClaimReleaseCallback(DADiskRef disk, void *arbitrator)
{
	fprintf(stderr, "%s called: %s\n", __FUNCTION__, DADiskGetBSDName(disk));
	fprintf(stderr, "\t claimed: %s\n\n", DADiskIsClaimed(disk) ? "Yes" : "No");

	return NULL;

	DADissenterRef dissenter = DADissenterCreate(kCFAllocatorDefault,
												 kDAReturnNotPermitted, 
												 CFSTR("DiskArbitrator is in charge"));
	
	return dissenter;
}

