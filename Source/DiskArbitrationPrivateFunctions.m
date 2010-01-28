/*
 *  DiskArbitrationPrivateFunctions.m
 *  DiskArbitrator
 *
 *  Created by Aaron Burghardt on 1/28/10.
 *  Copyright 2010 . All rights reserved.
 *
 */

#import "DiskArbitrationPrivateFunctions.h"

// Globals
NSMutableSet *uniqueDisks;
DASessionRef session;


void InitializeDiskArbitration(void)
{
	static BOOL isInitialized = NO;
	
	if (isInitialized) return;
	
	isInitialized = YES;
	
	uniqueDisks = [NSMutableSet new];
	
	session = DASessionCreate(kCFAllocatorDefault);
	if (!session) {
		[NSException raise:NSInternalInconsistencyException format:@"Failed to create Disk Arbitration session."];
		return;
	}
	
	DASessionScheduleWithRunLoop(session, CFRunLoopGetMain(), kCFRunLoopCommonModes);
	
	//	NSDictionary *matching = [NSDictionary dictionaryWithObjectsAndKeys:nil];
	
	DARegisterDiskAppearedCallback(session, NULL, DiskAppearedCallback, [Disk class]);
	DARegisterDiskDisappearedCallback(session, NULL, DiskDisappearedCallback, [Disk class]);
	DARegisterDiskDescriptionChangedCallback(session, NULL, NULL, DiskDescriptionChangedCallback, [Disk class]);
}

BOOL DADiskValidate(DADiskRef diskRef)
{
	//
	// Reject certain disk media
	//
	
	BOOL isOK = YES;
	
	// Reject if no BSDName
	if (DADiskGetBSDName(diskRef) == NULL) 
		return NO;
	
	CFDictionaryRef desc = DADiskCopyDescription(diskRef);
	//	CFShow(desc);
	
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
	
	return isOK;
}

NSUInteger DADiskHash(DADiskRef disk)
{
	NSInteger hash;
	const char *bsdname;
	NSString *BSDName;
	
	bsdname = DADiskGetBSDName(disk);
	if (bsdname) {
		BSDName = [[NSString alloc] initWithUTF8String:bsdname];
		hash = [BSDName hash];
		[BSDName release];
	}
	return hash;
}

BOOL DADiskEqual(DADiskRef disk1, DADiskRef disk2)
{
	return DADiskHash(disk1) == DADiskHash(disk2);	
}

void DiskAppearedCallback(DADiskRef diskRef, void *context)
{
	if (context != [Disk class]) return;
	
	fprintf(stderr, "disk %p appeared: %s\n", diskRef, DADiskGetBSDName(diskRef));
	
	if (DADiskValidate(diskRef)) 
	{
		Disk *disk = [[Disk alloc] initWithDiskRef:diskRef];
		[[NSNotificationCenter defaultCenter] postNotificationName:DADiskDidAppearNotification object:disk];
		[disk release];
	}
}

void DiskDisappearedCallback(DADiskRef diskRef, void *context)
{
	if (context != [Disk class]) return;
	
	fprintf(stderr, "disk %p disappeared: %s\n", diskRef, DADiskGetBSDName(diskRef));
	
	Disk *tmpDisk = [[Disk alloc] initWithDiskRef:diskRef];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:DADiskDidDisappearNotification object:tmpDisk];
	
	[tmpDisk diskDidDisappear];
	[uniqueDisks removeObject:tmpDisk];
	[tmpDisk release];
}

void DiskDescriptionChangedCallback(DADiskRef diskRef, CFArrayRef keys, void *context)
{
	if (context != [Disk class]) return;
	
	fprintf(stderr, "disk %p description changed: %s\n", diskRef, DADiskGetBSDName(diskRef));
	CFShow(keys);
	
	for (Disk *disk in uniqueDisks) {
		if (DADiskHash(diskRef)	== [disk hash]) {
			CFDictionaryRef desc = DADiskCopyDescription(diskRef);
			disk.description = desc;
			CFRelease(desc);
			
			[[NSNotificationCenter defaultCenter] postNotificationName:DADiskDidChangeNotification object:disk];
		}
	}
}

NSString * const DADiskDidAppearNotification = @"DADiskDidAppearNotification";
NSString * const DADiskDidDisappearNotification = @"DADiskDidDisppearNotification";
NSString * const DADiskDidChangeNotification = @"DADiskDidChangeNotification";
