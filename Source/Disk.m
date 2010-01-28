//
//  Disk.m
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 1/10/10.
//  Copyright 2010 . All rights reserved.
//

#import "Disk.h"
#import <IOKit/kext/KextManager.h>


NSMutableSet *uniqueDisks;
DASessionRef session;
CFRunLoopRef runLoop;

NSUInteger DADiskHash(DADiskRef disk);
void DiskAppearedCallback(DADiskRef diskRef, void *context);
void DiskDisappearedCallback(DADiskRef diskRef, void *context);
void DiskDescriptionChangedCallback(DADiskRef diskRef, CFArrayRef keys, void *context);


@implementation Disk

@synthesize BSDName;
@synthesize mountable;
@synthesize mounted;
@synthesize icon;
@synthesize parent;
@synthesize children;


+ (void)initialize
{
	uniqueDisks = [NSMutableSet new];

	session = DASessionCreate(kCFAllocatorDefault);
	if (!session) {
		[NSException raise:NSInternalInconsistencyException format:@"Failed to create Disk Arbitration session."];
		return;
	}
	
	runLoop = CFRunLoopGetCurrent();
	DASessionScheduleWithRunLoop(session, runLoop, kCFRunLoopCommonModes);
	
	//	NSDictionary *matching = [NSDictionary dictionaryWithObjectsAndKeys:nil];
	
	DARegisterDiskAppearedCallback(session, NULL, DiskAppearedCallback, [Disk class]);
	DARegisterDiskDisappearedCallback(session, NULL, DiskDisappearedCallback, [Disk class]);
	DARegisterDiskDescriptionChangedCallback(session, NULL, NULL, DiskDescriptionChangedCallback, [Disk class]);
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
	if ([key isEqual:@"isWholeDisk"])
		return [NSSet setWithObject:@"description"];
	
	if ([key isEqual:@"mountable"])
		return [NSSet setWithObject:@"description"];

	if ([key isEqual:@"mounted"])
		return [NSSet setWithObject:@"description"];
	
	if ([key isEqual:@"icon"])
		return [NSSet setWithObject:@"description"];
	
	return [super keyPathsForValuesAffectingValueForKey:key];
}

+ (BOOL)validateDADisk:(DADiskRef)diskRef
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

+ (id)diskWithDiskRef:(DADiskRef)diskRef
{
	return [[[[self class] alloc] initWithDiskRef:diskRef] autorelease];
}

- (id)initWithDiskRef:(DADiskRef)diskRef
{
	NSAssert(diskRef, @"No Disk Arbitration disk provided to initializer.");
	
	// Return unique instance 
	NSString *bsdname  = [NSString stringWithUTF8String:DADiskGetBSDName(diskRef)];
	
	for (Disk *uniqueDisk in uniqueDisks) {
		if ([uniqueDisk hash] == [bsdname hash]) {
			[super dealloc];
			return [uniqueDisk retain];
		}
	}
	
	if (self = [super init]) 
	{
		CFRetain(diskRef);
		disk = diskRef;
		children = [NSMutableSet new];
		description = DADiskCopyDescription(diskRef);
		BSDName = [[NSString alloc] initWithUTF8String:DADiskGetBSDName(diskRef)];
		[self refreshFromDescription];
		
//		CFShow(description);
		
		[uniqueDisks addObject:self];
		
		if ([self isWholeDisk] == NO) 
		{
			DADiskRef parentRef = DADiskCopyWholeDisk(diskRef);
			if (parentRef && parentRef != diskRef) {
				Disk *parentDisk = [Disk diskWithDiskRef:parentRef];
				parent = parentDisk; // weak reference
				[[parent mutableSetValueForKey:@"children"] addObject:self];
				CFRelease(parentRef);
			}
		}
	}

	return self;
}

- (void)dealloc
{
	if (disk) CFRelease(disk);
	if (description) CFRelease(description);
	[BSDName release];
	[icon release];
	parent = nil;
	[children release];
	[super dealloc];
}

- (NSUInteger)hash
{
	if (!hash) 
		hash = DADiskHash(disk);
	
	return hash;
}

- (BOOL)isEqual:(id)object
{
	return ([BSDName hash] == [object hash]);
}

- (void)diskDidDisappear
{
	[uniqueDisks removeObject:self];
	[[parent mutableSetValueForKey:@"children"] removeObject:self];

	CFRelease(disk);
	disk = NULL;

	self.parent = nil;
	[children removeAllObjects];
}


- (BOOL)isWholeDisk
{
	if (!description)
		return NO;

	CFBooleanRef value = CFDictionaryGetValue(description, kDADiskDescriptionMediaWholeKey);
	if (!value)
		return YES;
	
	return CFBooleanGetValue(value);
}

- (void)refreshFromDescription
{
	// BSDName cannot change so do not refresh it

	self.icon = nil;
	if (description) {
		CFBooleanRef flagRef = CFDictionaryGetValue(description, kDADiskDescriptionVolumeMountableKey);
		mountable = flagRef ? CFBooleanGetValue(flagRef) : NO;
		mounted = CFDictionaryGetValue(description, kDADiskDescriptionVolumePathKey) ? YES : NO;
	}
}

- (void)setDescription:(CFDictionaryRef)desc
{
	if (desc != description) {
		[self willChangeValueForKey:@"description"];

		CFRelease(description);
		description = desc ? CFRetain(desc) : NULL;
		[self refreshFromDescription];

		[self didChangeValueForKey:@"description"];
	}
}

- (CFDictionaryRef)description
{
	return description;	
}

- (NSImage *)icon
{
	if (!icon) {
		if (description) {
			CFDictionaryRef iconRef = CFDictionaryGetValue(description, kDADiskDescriptionMediaIconKey);
			if (iconRef) {
				
				CFStringRef identifier = CFDictionaryGetValue(iconRef, CFSTR("CFBundleIdentifier"));
				CFURLRef url = KextManagerCreateURLForBundleIdentifier(kCFAllocatorDefault, identifier);
				if (url) {
					NSBundle *bundle = [NSBundle bundleWithURL:(NSURL *)url];
					CFRelease(url);

					NSString *filename = (NSString *) CFDictionaryGetValue(iconRef, CFSTR("IOBundleResourceFile"));
					NSString *basename = [filename stringByDeletingPathExtension];
					NSString *fileext =  [filename pathExtension];
					NSString *path = [bundle pathForResource:basename ofType:fileext];

					icon = [[NSImage alloc] initWithContentsOfFile:path];
				}
				
			}
		}	
	}
	
	return icon;
}

@end

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

	if ([Disk validateDADisk:diskRef]) 
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
