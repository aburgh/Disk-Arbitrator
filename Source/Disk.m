//
//  Disk.m
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 1/10/10.
//  Copyright 2010 Aaron Burghardt. All rights reserved.
//

#import "Disk.h"
#import "AppError.h"
#import <DiskArbitration/DiskArbitration.h>
#import "DiskArbitrationPrivateFunctions.h"
#import <IOKit/kext/KextManager.h>


@implementation Disk

@synthesize BSDName;
@synthesize isMounting;
@synthesize icon;
@synthesize parent;
@synthesize children;

+ (void)initialize
{
	InitializeDiskArbitration();
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
	if ([key isEqual:@"isMountable"])
		return [NSSet setWithObject:@"diskDescription"];

	if ([key isEqual:@"isMounted"])
		return [NSSet setWithObject:@"diskDescription"];

	if ([key isEqual:@"isEjectable"])
		return [NSSet setWithObject:@"diskDescription"];

	if ([key isEqual:@"isWritable"])
		return [NSSet setWithObject:@"diskDescription"];

	if ([key isEqual:@"isRemovable"])
		return [NSSet setWithObject:@"diskDescription"];
	
	if ([key isEqual:@"icon"])
		return [NSSet setWithObject:@"diskDescription"];

	return [super keyPathsForValuesAffectingValueForKey:key];
}

+ (id)diskWithDiskRef:(DADiskRef)diskRef
{
	return [[[self.class alloc] initWithDiskRef:diskRef] autorelease];
}

- (id)initWithDiskRef:(DADiskRef)diskRef
{
	NSAssert(diskRef, @"No Disk Arbitration disk provided to initializer.");
	
	// Return unique instance
	for (Disk *uniqueDisk in uniqueDisks) {
		if (uniqueDisk.hash == CFHash(diskRef)) {
			[super dealloc];
			return [uniqueDisk retain];
		}
	}
	
	self = [super init];
	if (self) 
	{
		BSDName = [[NSString alloc] initWithUTF8String:DADiskGetBSDName(diskRef)];
		CFRetain(diskRef);
		disk = diskRef;
		children = [NSMutableSet new];
		diskDescription = DADiskCopyDescription(diskRef);
		
//		CFShow(description);
		
		[uniqueDisks addObject:self];
		
		if (self.isWholeDisk == NO)
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
	if (diskDescription) CFRelease(diskDescription);
	[BSDName release];
	[icon release];
	parent = nil;
	[children release];
	[super dealloc];
}

- (NSUInteger)hash
{
	return CFHash(disk);
}

- (BOOL)isEqual:(id)object
{
	return (CFHash(disk) == [object hash]);
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ 0x%p %@>", self.class, self, BSDName];
}

- (void)mount
{
	[self mountAtPath:nil withArguments:[NSArray array]];
}

- (void)mountAtPath:(NSString *)path withArguments:(NSArray *)args
{
	NSAssert(self.isMountable, @"Disk isn't mountable.");
	NSAssert(self.isMounted == NO, @"Disk is already mounted.");

	self.isMounting = YES;

	Log(LOG_DEBUG, @"%s mount %@ at mountpoint: %@ arguments: %@", __func__, BSDName, path, [args description]);

	// ensure arg list is NULL terminated
	id *argv = calloc([args count] + 1, sizeof(id));

	[args getObjects:argv range:NSMakeRange(0, [args count])];

	NSURL *url = path ? [NSURL fileURLWithPath:[path stringByExpandingTildeInPath]] : NULL;
	
	DADiskMountWithArguments((DADiskRef) disk, (CFURLRef) url, kDADiskMountOptionDefault,
							 DiskMountCallback, self, (CFStringRef *)argv);

	free(argv);
}

- (void)unmountWithOptions:(NSUInteger)options
{
	NSAssert(self.isMountable, @"Disk isn't mountable.");
	NSAssert(self.isMounted, @"Disk isn't mounted.");
	
	DADiskUnmount((DADiskRef) disk, options, DiskUnmountCallback, self);
}

- (void)eject
{
	NSAssert1(self.isEjectable, @"Disk is not ejectable: %@", self);
	
	DADiskEject((DADiskRef) disk, kDADiskEjectOptionDefault, DiskEjectCallback, self);
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

- (BOOL)isMountable
{
	CFBooleanRef value = diskDescription ? CFDictionaryGetValue(diskDescription, kDADiskDescriptionVolumeMountableKey) : NULL;
	
	return value ? CFBooleanGetValue(value) : NO;
}

- (BOOL)isMounted
{
	CFStringRef value = diskDescription ? CFDictionaryGetValue(diskDescription, kDADiskDescriptionVolumePathKey) : NULL;
	
	return value ? YES : NO;
}

- (BOOL)isWholeDisk
{
	CFBooleanRef value = diskDescription ? CFDictionaryGetValue(diskDescription, kDADiskDescriptionMediaWholeKey) : NULL;
	
	return value ? CFBooleanGetValue(value) : NO;
}

- (BOOL)isLeaf
{
	CFBooleanRef value = diskDescription ? CFDictionaryGetValue(diskDescription, kDADiskDescriptionMediaLeafKey) : NULL;
	
	return value ? CFBooleanGetValue(value) : NO;
}

- (BOOL)isNetworkVolume
{
	CFBooleanRef value = diskDescription ? CFDictionaryGetValue(diskDescription, kDADiskDescriptionVolumeNetworkKey) : NULL;
	
	return value ? CFBooleanGetValue(value) : NO;
}

- (BOOL)isWritable
{
	CFBooleanRef value = diskDescription ? CFDictionaryGetValue(diskDescription, kDADiskDescriptionMediaWritableKey) : NULL;
	
	return value ? CFBooleanGetValue(value) : NO;
}

- (BOOL)isEjectable
{
	CFBooleanRef value = diskDescription ? CFDictionaryGetValue(diskDescription, kDADiskDescriptionMediaEjectableKey) : NULL;
	
	return value ? CFBooleanGetValue(value) : NO;
}

- (BOOL)isRemovable
{
	CFBooleanRef value = diskDescription ? CFDictionaryGetValue(diskDescription, kDADiskDescriptionMediaRemovableKey) : NULL;
	
	return value ? CFBooleanGetValue(value) : NO;
}

- (void)setDiskDescription:(CFDictionaryRef)desc
{
	NSAssert(desc, @"A NULL disk description is not allowed.");
	
	if (desc != diskDescription) {
		[self willChangeValueForKey:@"diskDescription"];

		CFRelease(diskDescription);
		diskDescription = CFRetain(desc);

		[self didChangeValueForKey:@"diskDescription"];
	}
}

- (CFDictionaryRef)diskDescription
{
	return diskDescription;	
}

- (NSImage *)icon
{
	if (!icon) {
		if (diskDescription) {
			CFDictionaryRef iconRef = CFDictionaryGetValue(diskDescription, kDADiskDescriptionMediaIconKey);
			if (iconRef) {
				
				CFStringRef identifier = CFDictionaryGetValue(iconRef, CFSTR("CFBundleIdentifier"));
				CFURLRef url = KextManagerCreateURLForBundleIdentifier(kCFAllocatorDefault, identifier);
				if (url) {
					NSString *bundlePath = [(NSURL *)url path];
					CFRelease(url);

					NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
					if (bundle) {
						NSString *filename = (NSString *) CFDictionaryGetValue(iconRef, CFSTR("IOBundleResourceFile"));
						NSString *basename = [filename stringByDeletingPathExtension];
						NSString *fileext =  [filename pathExtension];

						NSString *path = [bundle pathForResource:basename ofType:fileext];
						if (path) {
							icon = [[NSImage alloc] initWithContentsOfFile:path];
						}
					}
					else {
						Log(LOG_WARNING, @"Failed to load bundle with URL: %@", [(NSURL *) url absoluteString]);
						CFShow(diskDescription);
					}
				}
				else {
					Log(LOG_WARNING, @"Failed to create URL for bundle identifier: %@", (NSString *)identifier);
					CFShow(diskDescription);
				}
			}
		}
	}
	
	return icon;
}

@end
