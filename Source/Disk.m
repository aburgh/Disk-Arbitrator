//
//  Disk.m
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 1/10/10.
//  Copyright 2010 Aaron Burghardt. All rights reserved.
//

#import "Disk.h"
#import "AppError.h"
#import "AuditLog.h"
#import <DiskArbitration/DiskArbitration.h>
#import "DiskArbitrationPrivateFunctions.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <sys/param.h>
#include <sys/mount.h>

////////////////////////////////////////////////////////////////////////////////

enum {
	DAAuditMountUnmounted = 0,
	DAAuditMountReadOnly = 1,
	DAAuditMountReadWrite = 2
};

@interface Disk ()
{
	CFTypeRef disk;
	NSInteger auditMountState;
	BOOL auditStateKnown;
}

- (NSInteger)currentAuditMountState;
- (void)recordAuditMountTransition;

@end

////////////////////////////////////////////////////////////////////////////////

@implementation Disk

@synthesize diskDescription = _diskDescription;
@synthesize BSDName;
@synthesize isMounting;
@synthesize rejectedMount;
@synthesize allowNextMount;
@synthesize icon;
@synthesize parent;
@synthesize children;
@synthesize mountArgs;
@synthesize mountPath;

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

	if ([key isEqual:@"isFileSystemWritable"])
		return [NSSet setWithObject:@"diskDescription"];

	if ([key isEqual:@"icon"])
		return [NSSet setWithObject:@"diskDescription"];

	return [super keyPathsForValuesAffectingValueForKey:key];
}

+ (id)uniqueDiskForDADisk:(DADiskRef)diskRef create:(BOOL)create
{
	for (Disk *disk in uniqueDisks) {
		if (disk.hash == CFHash(diskRef))
			return disk;
	}

	return create ? [[[self.class alloc] initWithDADisk:diskRef shouldCreateParent:YES] autorelease] : nil;
}

- (id)initWithDADisk:(DADiskRef)diskRef shouldCreateParent:(BOOL)shouldCreateParent
{
	NSAssert(diskRef, @"No Disk Arbitration disk provided to initializer.");
	
	self = [super init];

	// Return unique instance
	Disk *uniqueDisk = [Disk uniqueDiskForDADisk:diskRef create:NO];
	if (uniqueDisk)
	{
		[self release];
		return [uniqueDisk retain];
	}
	
	if (self)
	{
		disk = CFRetain(diskRef);
		const char *bsdName = DADiskGetBSDName(diskRef);
		BSDName = [[NSString alloc] initWithUTF8String:bsdName ? bsdName : ""];
		children = [NSMutableSet new];
		_diskDescription = (NSDictionary *)DADiskCopyDescription(diskRef);

//		CFShow(description);

		if (self.isWholeDisk == NO)
		{
			DADiskRef parentRef = DADiskCopyWholeDisk(diskRef);
			if (parentRef)
			{
				Disk *parentDisk = [Disk uniqueDiskForDADisk:parentRef create:shouldCreateParent];
				if (parentDisk)
				{
					parent = parentDisk; // weak reference
					[[parent mutableSetValueForKey:@"children"] addObject:self];
				}
				SafeCFRelease(parentRef);
			}
		}
		[uniqueDisks addObject:self];
		auditMountState = [self currentAuditMountState];
		auditStateKnown = YES;
	}
	return self;
}

- (void)dealloc
{
	SafeCFRelease(disk);
	[_diskDescription release];
	[BSDName release];
	[icon release];
	parent = nil;
	[children release];
	[mountArgs release];
	[mountPath release];
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

- (BOOL)isAttached
{
	return disk != NULL;
}

- (void)mountAtPath:(NSString *)path withArguments:(NSArray *)args
{
	if (disk == NULL || !self.isMountable || self.isMounted) {
		Log(LOG_ERR, @"Not mounting %@ (attached=%d mountable=%d mounted=%d)", BSDName, disk != NULL, self.isMountable, self.isMounted);
		self.isMounting = NO;
		self.allowNextMount = NO;
		return;
	}

	self.isMounting = YES;
	self.mountArgs = args;
	self.mountPath = path;

	Log(LOG_DEBUG, @"%s mount %@ at mountpoint: %@ arguments: %@", __func__, BSDName, path, args.description);

	// ensure arg list is NULL terminated
	id __unsafe_unretained *argv = calloc(args.count + 1, sizeof(id));
	if (args.count > 0)
		[args getObjects:argv range:NSMakeRange(0, args.count)];

	NSURL *url = path ? [NSURL fileURLWithPath:path.stringByExpandingTildeInPath] : NULL;

	// Consumed by the mount-approval callback. Set immediately before the call; that call
	// returns without spinning the run loop, so this is not cleared by an unrelated callback.
	self.allowNextMount = YES;

	DADiskMountWithArguments((DADiskRef) disk, (CFURLRef) url, kDADiskMountOptionDefault,
		DiskMountCallback, self, (CFStringRef *)argv);

	free(argv);
}

- (void)unmountWithOptions:(NSUInteger)options
{
	if (disk == NULL || !self.isMountable || !self.isMounted) {
		Log(LOG_ERR, @"Not unmounting %@ (attached=%d mountable=%d mounted=%d)", BSDName, disk != NULL, self.isMountable, self.isMounted);
		return;
	}
	
	DADiskUnmount((DADiskRef) disk, (DADiskUnmountOptions)options, DiskUnmountCallback, self);
}

- (void)eject
{
	if (disk == NULL || !self.isEjectable) {
		Log(LOG_ERR, @"Not ejecting %@ (attached=%d ejectable=%d)", BSDName, disk != NULL, self.isEjectable);
		return;
	}
	
	DADiskEject((DADiskRef) disk, kDADiskEjectOptionDefault, DiskEjectCallback, [self retain]); // self is released in DiskEjectCallback
}

- (void)diskDidDisappear
{
	[uniqueDisks removeObject:self];
	[[parent mutableSetValueForKey:@"children"] removeObject:self];

	SafeCFRelease(disk);
	disk = NULL;

	self.parent = nil;
	[children removeAllObjects];
	
	self.rejectedMount = NO;
	self.allowNextMount = NO;
	self.isMounting = NO;
	self.mountArgs = [NSArray array];
	self.mountPath = nil;
}

- (BOOL)isMountable
{
	CFBooleanRef value = self.diskDescription ?
		(CFBooleanRef)[self.diskDescription objectForKey:(NSString *)kDADiskDescriptionVolumeMountableKey] : NULL;
	return value ? CFBooleanGetValue(value) : NO;
}

- (BOOL)isMounted
{
	CFStringRef value = self.diskDescription ?
		(CFStringRef)[self.diskDescription objectForKey:(NSString *)kDADiskDescriptionVolumePathKey] : NULL;
	
	return value ? YES : NO;
}

- (BOOL)isWholeDisk
{
	CFBooleanRef value = self.diskDescription ?
		(CFBooleanRef)[self.diskDescription objectForKey:(NSString *)kDADiskDescriptionMediaWholeKey] : NULL;
	return value ? CFBooleanGetValue(value) : NO;
}

- (BOOL)isLeaf
{
	CFBooleanRef value = self.diskDescription ?
		(CFBooleanRef)[self.diskDescription objectForKey:(NSString *)kDADiskDescriptionMediaLeafKey] : NULL;
	return value ? CFBooleanGetValue(value) : NO;
}

- (BOOL)isNetworkVolume
{
	CFBooleanRef value = self.diskDescription ?
		(CFBooleanRef)[self.diskDescription objectForKey:(NSString *)kDADiskDescriptionVolumeNetworkKey] : NULL;
	return value ? CFBooleanGetValue(value) : NO;
}

- (BOOL)isWritable
{
	CFBooleanRef value = self.diskDescription ?
		(CFBooleanRef)[self.diskDescription objectForKey:(NSString *)kDADiskDescriptionMediaWritableKey] : NULL;
	return value ? CFBooleanGetValue(value) : NO;
}

- (BOOL)isEjectable
{
	CFBooleanRef value = self.diskDescription ?
		(CFBooleanRef)[self.diskDescription objectForKey:(NSString *)kDADiskDescriptionMediaEjectableKey] : NULL;
	return value ? CFBooleanGetValue(value) : NO;
}

- (BOOL)isRemovable
{
	CFBooleanRef value = self.diskDescription ?
		(CFBooleanRef)[self.diskDescription objectForKey:(NSString *)kDADiskDescriptionMediaRemovableKey] : NULL;
	return value ? CFBooleanGetValue(value) : NO;
}

- (BOOL)isHFS
{
	CFStringRef volumeKind = self.diskDescription ?
		(CFStringRef)[self.diskDescription objectForKey:(NSString *)kDADiskDescriptionVolumeKindKey] : NULL;
	return volumeKind ? CFEqual(CFSTR("hfs"), volumeKind) : NO;
}

- (BOOL)isFileSystemWritable
{
	BOOL retval = NO;
	struct statfs fsstat;
	CFURLRef volumePath;
	UInt8 fsrep[MAXPATHLEN];

	// if the media is not writable, the file system cannot be either
	if (self.isWritable == NO)
		return NO;

	volumePath = (CFURLRef)[self.diskDescription objectForKey:(NSString *)kDADiskDescriptionVolumePathKey];
	if (volumePath) {

		if (CFURLGetFileSystemRepresentation(volumePath, true, fsrep, sizeof(fsrep))) {

			if (statfs((char *)fsrep, &fsstat) == 0)
				retval = (fsstat.f_flags & MNT_RDONLY) ? NO : YES;
		}
	}

	return retval;
}

- (NSInteger)currentAuditMountState
{
	if (!self.isMounted)
		return DAAuditMountUnmounted;
	return self.isFileSystemWritable ? DAAuditMountReadWrite : DAAuditMountReadOnly;
}

- (void)recordAuditMountTransition
{
	NSInteger current = [self currentAuditMountState];
	if (!auditStateKnown) {
		auditMountState = current;
		auditStateKnown = YES;
		return;
	}
	if (current == auditMountState)
		return;

	NSInteger previous = auditMountState;
	auditMountState = current;

	if (previous != DAAuditMountUnmounted && current == DAAuditMountUnmounted) {
		[[AuditLog sharedLog] recordEvent:DAAuditEventUnmounted disk:self action:@"unmounted" message:nil];
		return;
	}
	if (previous == DAAuditMountUnmounted && current != DAAuditMountUnmounted) {
		// The app controller unmounts this case and records the error itself.
		if ([self.mountArgs containsObject:@"rdonly"] && self.isFileSystemWritable)
			return;
		if (current == DAAuditMountReadOnly)
			[[AuditLog sharedLog] recordEvent:DAAuditEventMountedReadOnly disk:self action:@"mounted_read_only" message:nil];
		else
			[[AuditLog sharedLog] recordEvent:DAAuditEventMountedReadWrite disk:self action:@"mounted_read_write" message:nil];
	}
}

- (void)recordAuditUnmountIfMounted
{
	if (!auditStateKnown || auditMountState == DAAuditMountUnmounted)
		return;
	auditMountState = DAAuditMountUnmounted;
	[[AuditLog sharedLog] recordEvent:DAAuditEventUnmounted disk:self action:@"unmounted" message:nil];
}

- (void)setDiskDescription:(NSDictionary *)desc
{
	NSAssert(desc, @"A NULL disk description is not allowed.");

	if (desc != _diskDescription) {
		[self willChangeValueForKey:@"diskDescription"];

		SafeCFRelease(_diskDescription);
		_diskDescription = desc ? [desc retain] : nil;
		[icon release];
		icon = nil;

		[self didChangeValueForKey:@"diskDescription"];
		[self recordAuditMountTransition];
	}
}

- (NSImage *)icon
{
	if (icon)
		return icon;

	NSDictionary *description = self.diskDescription;
	if (!description)
		return nil;

	// KextManagerCreateURLForBundleIdentifier no longer finds media icons: on current macOS those
	// kexts live in the kernel collection. Finder's volume icon is the supported replacement.
	id volumePath = [description objectForKey:(NSString *)kDADiskDescriptionVolumePathKey];
	if ([volumePath isKindOfClass:[NSURL class]]) {
		NSImage *volumeIcon = [[NSWorkspace sharedWorkspace] iconForFile:[(NSURL *)volumePath path]];
		if (volumeIcon) {
			icon = [volumeIcon retain];
			return icon;
		}
	}

	UTType *volumeType = [UTType typeWithIdentifier:@"public.volume"];
	NSImage *generic = volumeType ? [[NSWorkspace sharedWorkspace] iconForContentType:volumeType] : nil;
	if (!generic)
		generic = [NSImage imageNamed:NSImageNameFolder];
	icon = [generic retain];
	return icon;
}

- (int)BSDNameNumber
{
	// Take the BSDName and convert it into a number that can be compared with other disks for sorting.
	// For example, "disk2s1" would become 2 * 1000 + 1 = 2001.
	// If we just compare by the string value itself, then disk10 would come after disk1, instead of disk9.
	NSString *s = self.BSDName;
	int device = 0;
	int slice = 0;
	const int found = sscanf(s.UTF8String, "disk%ds%d", &device, &slice);
	if (found == 0 || device < 0 || slice < 0) {
		NSLog(@"Invalid BSD Name %@", s);
	}
	return (device * 1000) + slice;
}

@end
