/*
 *  DiskArbitrationPrivateFunctions.m
 *  DiskArbitrator
 *
 *  Created by Aaron Burghardt on 1/28/10.
 *  Copyright 2010 Aaron Burghardt. All rights reserved.
 *
 */

#import "DiskArbitrationPrivateFunctions.h"
#import "AppError.h"

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
	
	NSMutableDictionary *matching = [NSMutableDictionary dictionary];
	[matching setObject:[NSNumber numberWithBool:NO] 
				 forKey:(NSString *) kDADiskDescriptionVolumeNetworkKey];
	
	DARegisterDiskAppearedCallback(session, (CFDictionaryRef) matching, DiskAppearedCallback, [Disk class]);
	DARegisterDiskDisappearedCallback(session, (CFDictionaryRef) matching, DiskDisappearedCallback, [Disk class]);
	DARegisterDiskDescriptionChangedCallback(session, (CFDictionaryRef) matching, NULL, DiskDescriptionChangedCallback, [Disk class]);
}

BOOL DADiskValidate(DADiskRef diskRef)
{
	//
	// Reject certain disk media
	//
	
	BOOL isOK = YES;
	
	// Reject if no BSDName
	if (DADiskGetBSDName(diskRef) == NULL) 
		[NSException raise:NSInternalInconsistencyException format:@"Disk without BSDName"];
//		return NO;
	
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
	
	Log(LOG_DEBUG, @"%s <%p> %s", __FUNCTION__, diskRef, DADiskGetBSDName(diskRef));
	
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
	
	Log(LOG_DEBUG, @"%s <%p> %s", __FUNCTION__, diskRef, DADiskGetBSDName(diskRef));
	
	Disk *tmpDisk = [[Disk alloc] initWithDiskRef:diskRef];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:DADiskDidDisappearNotification object:tmpDisk];
	
	[tmpDisk diskDidDisappear];
	[uniqueDisks removeObject:tmpDisk];
	[tmpDisk release];
}

void DiskDescriptionChangedCallback(DADiskRef diskRef, CFArrayRef keys, void *context)
{
	if (context != [Disk class]) return;
	
	Log(LOG_DEBUG, @"%s <%p> %s, keys changed:", __FUNCTION__, diskRef, DADiskGetBSDName(diskRef));
	CFShow(keys);
	
	for (Disk *disk in uniqueDisks) {
		if (DADiskHash(diskRef)	== [disk hash]) {
			CFDictionaryRef desc = DADiskCopyDescription(diskRef);
			disk.diskDescription = desc;
			CFRelease(desc);
			
			[[NSNotificationCenter defaultCenter] postNotificationName:DADiskDidChangeNotification object:disk];
		}
	}
}

void DiskMountCallback(DADiskRef diskRef, DADissenterRef dissenter, void *context)
{
//	Disk *disk = (Disk *)context;
	
	Log(LOG_DEBUG, @"%s <%p> dissenter <%p>", __FUNCTION__, diskRef, dissenter);
	
	if (dissenter) {
		NSString *errorString = (NSString *) DADissenterGetStatusString(dissenter);
		if (!errorString)
			errorString = @"Unknown Disk Arbitration Mount error";

		DAReturn code = DADissenterGetStatus(dissenter);
		
		NSMutableDictionary *info = [NSMutableDictionary dictionary];
		[info setObject:errorString forKey:NSLocalizedDescriptionKey];
		[info setObject:[NSString stringWithFormat:@"Error code: %d", code] forKey:NSLocalizedFailureReasonErrorKey];
		NSError *error = [NSError errorWithDomain:AppErrorDomain code:code userInfo:info];

		Log(LOG_DEBUG, @"%@", error);
//		[NSApp presentError:error];
	}
}

void DiskUnmountCallback(DADiskRef diskRef, DADissenterRef dissenter, void *context)
{
	NSDictionary *info = nil;
	
	if (dissenter) {
		DAReturn status = DADissenterGetStatus(dissenter);

		NSString *statusString = (NSString *) DADissenterGetStatusString(dissenter);
		if (!statusString)
			statusString = [NSString stringWithFormat:@"Error code: %d", status];

		Log(LOG_DEBUG, @"%s disk %@ dissenter: (%d) %@", __FUNCTION__, context, status, statusString);

		info = [NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:status], DAStatusErrorKey,
				statusString, NSLocalizedFailureReasonErrorKey,
				statusString, NSLocalizedRecoverySuggestionErrorKey,
				nil];
	}
	else {
		Log(LOG_DEBUG, @"%s disk %@ unmounted", __FUNCTION__, context);
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:DADiskDidAttemptUnmountNotification object:context userInfo:info];
}

void DiskEjectCallback(DADiskRef diskRef, DADissenterRef dissenter, void *context)
{
	NSDictionary *info = nil;
	
	if (dissenter) {
		DAReturn status = DADissenterGetStatus(dissenter);
		
		NSString *statusString = (NSString *) DADissenterGetStatusString(dissenter);
		if (!statusString)
			statusString = [NSString stringWithFormat:@"Error code: %d", status];
		
		Log(LOG_INFO, @"%s disk: %@ dissenter: (%d) %@", __FUNCTION__, context, status, statusString);
		
		info = [NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:status], DAStatusErrorKey,
				statusString, NSLocalizedFailureReasonErrorKey,
				statusString, NSLocalizedRecoverySuggestionErrorKey,
				nil];
	}
	else {
		Log(LOG_DEBUG, @"%s disk ejected: %@ ", __FUNCTION__, context);
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:DADiskDidAttemptEjectNotification object:context userInfo:info];
}


NSString * const DADiskDidAppearNotification = @"DADiskDidAppearNotification";
NSString * const DADiskDidDisappearNotification = @"DADiskDidDisppearNotification";
NSString * const DADiskDidChangeNotification = @"DADiskDidChangeNotification";
NSString * const DADiskDidAttemptUnmountNotification = @"DADiskDidAttemptUnmountNotification";
NSString * const DADiskDidAttemptEjectNotification = @"DADiskDidAttemptEjectNotification";

NSString * const DAStatusErrorKey = @"DAStatusErrorKey";
