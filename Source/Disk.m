//
//  Disk.m
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 1/10/10.
//  Copyright 2010 . All rights reserved.
//

#import "Disk.h"
#import <IOKit/kext/KextManager.h>

@implementation Disk

@synthesize BSDName;
@synthesize mounted;
@synthesize icon;
@synthesize children;

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
	if ([key isEqual:@"isWholeDisk"])
		return [NSSet setWithObject:@"description"];
	
	if ([key isEqual:@"mounted"])
		return [NSSet setWithObject:@"description"];
	
	if ([key isEqual:@"icon"])
		return [NSSet setWithObject:@"description"];
	
	return [super keyPathsForValuesAffectingValueForKey:key];
}

+ (id)diskWithDiskRef:(DADiskRef)diskRef
{
	return [[[[self class] alloc] initWithDiskRef:diskRef] autorelease];
}

- (id)initWithDiskRef:(DADiskRef)diskRef
{
	if (self = [super init]) 
	{
		children = [NSMutableArray new];
		description = DADiskCopyDescription(diskRef);
		CFRetain(description);

		BSDName = (NSString *) CFDictionaryGetValue(description, kDADiskDescriptionMediaBSDNameKey);
		[self refreshFromDescription];
		
//		CFShow(description);
	}

	return self;
}

- (void)dealloc
{
	CFRelease(description);
	[BSDName release];
	[icon release];
	[children release];
	[super dealloc];
}

- (BOOL)isEqual:(id)object
{
	if ([object isKindOfClass:[Disk class]] == NO)
		return NO;
	
	NSString *name = [object BSDName];
	if (name)
		return [name isEqual:BSDName];
	
	NSDictionary *desc = (NSDictionary *)[object description];
	if (desc)
		return [desc isEqualToDictionary:(NSDictionary *) description];
	
	fprintf(stderr, "Failed to compare Disk objects: %p, %p\n", self, object);
	
	return NO;
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
	mounted = CFDictionaryGetValue(description, kDADiskDescriptionVolumePathKey) ? YES : NO;
}

- (void)setDescription:(CFDictionaryRef)desc
{
	if (desc != description) {
		[self willChangeValueForKey:@"description"];
		CFRelease(description);
		description = CFRetain(desc);
		[self didChangeValueForKey:@"description"];
		
		[self refreshFromDescription];
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
