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
@synthesize mountable;
@synthesize mounted;
@synthesize mounting;
@synthesize ejectable;
@synthesize icon;
@synthesize parent;
@synthesize children;

+ (void)initialize
{
	InitializeDiskArbitration();
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
	if ([key isEqual:@"isWholeDisk"])
		return [NSSet setWithObject:@"diskDescription"];
	
	if ([key isEqual:@"mountable"])
		return [NSSet setWithObject:@"diskDescription"];

	if ([key isEqual:@"mounted"])
		return [NSSet setWithObject:@"diskDescription"];
	
	if ([key isEqual:@"ejectable"])
		return [NSSet setWithObject:@"diskDescription"];

	if ([key isEqual:@"icon"])
		return [NSSet setWithObject:@"diskDescription"];

	return [super keyPathsForValuesAffectingValueForKey:key];
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
		diskDescription = DADiskCopyDescription(diskRef);
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
	if (diskDescription) CFRelease(diskDescription);
	[BSDName release];
	[icon release];
	parent = nil;
	[children release];
	[super dealloc];
}

- (NSUInteger)hash
{
	if (!hash) 
		hash = DADiskHash((DADiskRef) disk);
	
	return hash;
}

- (BOOL)isEqual:(id)object
{
	return ([BSDName hash] == [object hash]);
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ 0x%p> BSD Name: = %@", [self class], self, BSDName];
}

- (void)mount
{
	[self mountAtPath:nil withArguments:[NSArray array]];
}

- (void)mountAtPath:(NSString *)path withArguments:(NSArray *)args
{
	NSAssert(self.mountable, @"Disk isn't mountable.");
	NSAssert(self.mounted == NO, @"Disk is already mounted.");

	self.mounting = YES;

	Log(LOG_INFO, @"%s mount %@ at mountpoint: %@ arguments: %@", __FUNCTION__, BSDName, path, [args description]);

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
	NSAssert(self.mountable, @"Disk isn't mountable.");
	NSAssert(self.mounted, @"Disk isn't mounted.");
	
	DADiskUnmount((DADiskRef) disk, options, DiskUnmountCallback, self);
}

- (void)eject
{
	NSAssert(ejectable, @"Disk is not ejectable: %@", self);
	
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


- (BOOL)isWholeDisk
{
	if (!diskDescription)
		return NO;

	CFBooleanRef value = CFDictionaryGetValue(diskDescription, kDADiskDescriptionMediaWholeKey);
	if (!value)
		return YES;
	
	return CFBooleanGetValue(value);
}

- (void)refreshFromDescription
{
	// BSDName cannot change so do not refresh it

	self.icon = nil;
	if (diskDescription) {
		CFBooleanRef flagRef = CFDictionaryGetValue(diskDescription, kDADiskDescriptionVolumeMountableKey);
		mountable = flagRef ? CFBooleanGetValue(flagRef) : NO;
		mounted = CFDictionaryGetValue(diskDescription, kDADiskDescriptionVolumePathKey) ? YES : NO;
		
		flagRef = CFDictionaryGetValue(diskDescription, kDADiskDescriptionMediaEjectableKey);
		ejectable = flagRef ? CFBooleanGetValue(flagRef) : NO;
	}
}

- (void)setDiskDescription:(CFDictionaryRef)desc
{
	if (desc != diskDescription) {
		[self willChangeValueForKey:@"diskDescription"];

		CFRelease(diskDescription);
		diskDescription = desc ? CFRetain(desc) : NULL;
		[self refreshFromDescription];

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
