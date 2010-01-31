/*
 *  DiskArbitrationPrivateFunctions.h
 *  DiskArbitrator
 *
 *  Created by Aaron Burghardt on 1/28/10.
 *  Copyright 2010 Aaron Burghardt. All rights reserved.
 *
 */

#import <DiskArbitration/DiskArbitration.h>
#import "Disk.h"

void InitializeDiskArbitration(void);
BOOL DADiskValidate(DADiskRef diskRef);
NSUInteger DADiskHash(DADiskRef disk);
void DiskAppearedCallback(DADiskRef diskRef, void *context);
void DiskDisappearedCallback(DADiskRef diskRef, void *context);
void DiskDescriptionChangedCallback(DADiskRef diskRef, CFArrayRef keys, void *context);
void DiskMountCallback(DADiskRef diskRef, DADissenterRef dissenter, void *context);


@interface Disk (DiskPrivate)
- (id)initWithDiskRef:(DADiskRef)diskRef;
- (void)refreshFromDescription;
- (void)diskDidDisappear;
@end

extern NSMutableSet *uniqueDisks;
