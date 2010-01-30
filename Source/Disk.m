//
//  Disk.m
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 1/10/10.
//  Copyright 2010 . All rights reserved.
//

#import "Disk.h"
#import <DiskArbitration/DiskArbitration.h>
#import "DiskArbitrationPrivateFunctions.h"
#import <IOKit/kext/KextManager.h>


@implementation Disk

@synthesize BSDName;
@synthesize mountable;
@synthesize mounted;
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
