//
//  Arbitrator.h
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 1/10/10.
//  Copyright 2010 . All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <DiskArbitration/DiskArbitration.h>


@interface Arbitrator : NSObject 
{
	CFRunLoopRef runLoop;
	DASessionRef session;
	DAApprovalSessionRef approvalSession;
	
	NSMutableArray *disks;
	
	BOOL activated;
}

@property (retain) NSMutableArray *disks;
@property (readonly) NSArray *wholeDisks;
@property (readonly) BOOL isActivated;

- (BOOL)registerSession;
- (void)unregisterSession;
- (BOOL)registerApprovalSession;
- (void)unregisterApprovalSession;

- (BOOL)activate;
- (void)deactivate;

@end

NSString * BSDNameFromDADisk(DADiskRef disk);

void DiskAppearedCallback(DADiskRef disk, void *arbitrator);
void DiskDisappearedCallback(DADiskRef disk, void *arbitrator);
void DiskDescriptionChangedCallback(DADiskRef disk, CFArrayRef keys, void *arbitrator);
DADissenterRef DiskMountApprovalCallback(DADiskRef disk, void *arbitrator);
void DiskClaimCallback(DADiskRef disk, DADissenterRef dissenter, void *arbitrator);
DADissenterRef DiskClaimReleaseCallback(DADiskRef disk, void *arbitrator);