//
//  Arbitrator.h
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 1/10/10.
//  Copyright 2010 Aaron Burghardt. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <DiskArbitration/DiskArbitration.h>

// Mount Modes
#define MM_BLOCK	0
#define MM_READONLY	1


@interface Arbitrator : NSObject 
{
	DAApprovalSessionRef approvalSession;
	NSMutableSet *disks;
}

@property (retain) NSMutableSet *disks;
@property (readonly) NSSet *wholeDisks;
@property BOOL isActivated;
@property NSInteger mountMode;

- (BOOL)registerSession;
- (void)unregisterSession;
- (BOOL)registerApprovalSession;
- (void)unregisterApprovalSession;

- (BOOL)activate;
- (void)deactivate;

@end

DADissenterRef DiskMountApprovalCallback(DADiskRef disk, void *arbitrator);
void DiskClaimCallback(DADiskRef disk, DADissenterRef dissenter, void *arbitrator);
DADissenterRef DiskClaimReleaseCallback(DADiskRef disk, void *arbitrator);

extern NSString * const ArbitratorIsEnabled;
extern NSString * const ArbitratorMountMode;
