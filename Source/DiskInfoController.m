//
//  DiskInfoController.m
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 2/11/10.
//  Copyright 2010 . All rights reserved.
//

#import "DiskInfoController.h"
#import "AppError.h"
#import <DiskArbitration/DiskArbitration.h>
#import "Disk.h"


@implementation DiskInfoController

@synthesize textView;
@synthesize diskDescription;
@synthesize diskInfo;

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
	if ([key isEqual:@"diskDescription"])
	{
		return [NSSet setWithObject:@"disk.diskDescription"];
	}

	return [super keyPathsForValuesAffectingValueForKey:key];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSString *)localizedStringForDADiskKey:(NSString *)key
{
	static dispatch_once_t sOnceToken;
	static NSDictionary *localizedStrings = nil;
	dispatch_once(&sOnceToken, ^{
		localizedStrings =
		@{
			(NSString *)kDADiskDescriptionVolumeKindKey: 		NSLocalizedString(@"Volume Kind", nil),
			(NSString *)kDADiskDescriptionVolumeMountableKey: 	NSLocalizedString(@"Volume Mountable", nil),
			(NSString *)kDADiskDescriptionVolumeNameKey: 		NSLocalizedString(@"Volume Name", nil),
			(NSString *)kDADiskDescriptionVolumeNetworkKey: 	NSLocalizedString(@"Volume Network", nil),
			(NSString *)kDADiskDescriptionVolumePathKey: 		NSLocalizedString(@"Mount Path", nil),
			(NSString *)kDADiskDescriptionVolumeTypeKey: 		NSLocalizedString(@"Volume Type", nil),
			(NSString *)kDADiskDescriptionVolumeUUIDKey: 		NSLocalizedString(@"Volume UUID", nil),
			(NSString *)kDADiskDescriptionMediaBlockSizeKey: 	NSLocalizedString(@"Media Block Size", nil),
			(NSString *)kDADiskDescriptionMediaBSDMajorKey: 	NSLocalizedString(@"Media BSD Major", nil),
			(NSString *)kDADiskDescriptionMediaBSDMinorKey: 	NSLocalizedString(@"Media BSD Minor", nil),
			(NSString *)kDADiskDescriptionMediaBSDNameKey: 		NSLocalizedString(@"Media BSD Name", nil),
			(NSString *)kDADiskDescriptionMediaBSDUnitKey: 		NSLocalizedString(@"Media BSD Unit", nil),
			(NSString *)kDADiskDescriptionMediaContentKey: 		NSLocalizedString(@"Media Content", nil),
			(NSString *)kDADiskDescriptionMediaEjectableKey: 	NSLocalizedString(@"Media Ejectable", nil),
			(NSString *)kDADiskDescriptionMediaIconKey: 		NSLocalizedString(@"Media Icon", nil),
			(NSString *)kDADiskDescriptionMediaKindKey: 		NSLocalizedString(@"Media Kind", nil),
			(NSString *)kDADiskDescriptionMediaLeafKey: 		NSLocalizedString(@"Media Is Leaf", nil),
			(NSString *)kDADiskDescriptionMediaNameKey: 		NSLocalizedString(@"Media Name", nil),
			(NSString *)kDADiskDescriptionMediaPathKey: 		NSLocalizedString(@"Media Path", nil),
			(NSString *)kDADiskDescriptionMediaRemovableKey: 	NSLocalizedString(@"Media Is Removable", nil),
			(NSString *)kDADiskDescriptionMediaSizeKey: 		NSLocalizedString(@"Media Size", nil),
			(NSString *)kDADiskDescriptionMediaTypeKey: 		NSLocalizedString(@"Media Type", nil),
			(NSString *)kDADiskDescriptionMediaUUIDKey: 		NSLocalizedString(@"Media UUID", nil),
			(NSString *)kDADiskDescriptionMediaWholeKey: 		NSLocalizedString(@"Media Is Whole", nil),
			(NSString *)kDADiskDescriptionMediaWritableKey: 	NSLocalizedString(@"Media Is Writable", nil),
			(NSString *)kDADiskDescriptionMediaEncryptedKey: 	NSLocalizedString(@"Encrypted", nil),
			(NSString *)kDADiskDescriptionMediaEncryptionDetailKey: NSLocalizedString(@"Encryption Detail", nil),
			(NSString *)kDADiskDescriptionDeviceGUIDKey: 		NSLocalizedString(@"Device GUID", nil),
			(NSString *)kDADiskDescriptionDeviceInternalKey: 	NSLocalizedString(@"Device Is Internal", nil),
			(NSString *)kDADiskDescriptionDeviceModelKey: 		NSLocalizedString(@"Device Model", nil),
			(NSString *)kDADiskDescriptionDevicePathKey: 		NSLocalizedString(@"Device Path", nil),
			(NSString *)kDADiskDescriptionDeviceProtocolKey: 	NSLocalizedString(@"Device Protocol", nil),
			(NSString *)kDADiskDescriptionDeviceRevisionKey: 	NSLocalizedString(@"Device Revision", nil),
			(NSString *)kDADiskDescriptionDeviceUnitKey: 		NSLocalizedString(@"Device Unit", nil),
			(NSString *)kDADiskDescriptionDeviceVendorKey: 		NSLocalizedString(@"Device Vendor", nil),
			(NSString *)kDADiskDescriptionDeviceTDMLockedKey: 	NSLocalizedString(@"TDM Locked", nil),
			(NSString *)kDADiskDescriptionBusNameKey: 			NSLocalizedString(@"Bus", nil),
			(NSString *)kDADiskDescriptionBusPathKey: 			NSLocalizedString(@"Bus Path", nil),
			@"DAAppearanceTime": 								NSLocalizedString(@"Appearance Time", nil)
		};
	});

	NSString *description = localizedStrings[key];

	if (nil == description)
	{
		Log(LOG_INFO, @"Unknown disk description key: %@", key);
		description = @"N/A";
	}

	return description;
}

- (NSString *)formattedSizeDescriptionFromNumber:(NSNumber *)sizeValue
{
	NSString *formattedValue;

	double size = [sizeValue doubleValue];

	if (size > 999.0 && size < 1000000.0)
	{
		formattedValue = [NSString stringWithFormat:@"%03.02f KB (%@ bytes)", (size / 1000.0), sizeValue];
	}
	else if (size > 999999.0 && size < 1000000000.0)
	{
		formattedValue = [NSString stringWithFormat:@"%03.02f MB (%@ bytes)", (size / 1000000.0), sizeValue];
	}
	else if (size > 999999999.0 && size < 1000000000000.0)
	{
		formattedValue = [NSString stringWithFormat:@"%03.02f GB (%@ bytes)", (size / 1000000000.0), sizeValue];
	}
	else if (size > 999999999999.0)
	{
		formattedValue = [NSString stringWithFormat:@"%03.02f TB (%@ bytes)", (size / 1000000000000.0), sizeValue];
	}
	else
	{
		formattedValue = sizeValue.stringValue;
	}

	return formattedValue;
}

- (NSString *)localizedValueStringForDADiskKey:(NSString *)key value:(id)value
{
	CFStringRef keyRef = (__bridge CFStringRef) key;

	if (CFEqual(keyRef, kDADiskDescriptionVolumeKindKey))      /* ( CFString     ) */
	{
		return value;
	}

	if (CFEqual(keyRef, kDADiskDescriptionVolumeMountableKey) || /* ( CFBoolean    ) */
		CFEqual(keyRef, kDADiskDescriptionVolumeNetworkKey)   ||
		CFEqual(keyRef, kDADiskDescriptionMediaLeafKey)       ||
		CFEqual(keyRef, kDADiskDescriptionMediaEjectableKey)  ||
		CFEqual(keyRef, kDADiskDescriptionMediaRemovableKey)  ||
		CFEqual(keyRef, kDADiskDescriptionMediaWholeKey)      ||
		CFEqual(keyRef, kDADiskDescriptionMediaWritableKey)   ||
		CFEqual(keyRef, kDADiskDescriptionDeviceInternalKey)
		)
	{
		return [value boolValue] ? @"Yes" : @"No";
	}

	if (CFEqual(keyRef, kDADiskDescriptionVolumeNameKey))      /* ( CFString     ) */
	{
		return value;
	}

	if (CFEqual(keyRef, kDADiskDescriptionVolumePathKey))      /* ( CFURL        ) */
	{
		return [(NSURL *)value path];
	}

	if (CFEqual(keyRef, kDADiskDescriptionVolumeUUIDKey) || 	 /* ( CFUUID       ) */
		CFEqual(keyRef, kDADiskDescriptionMediaUUIDKey))
	{
		NSString *uuidString = (NSString *) CFBridgingRelease(CFUUIDCreateString(kCFAllocatorDefault, (CFUUIDRef)value));

		return uuidString;
	}

	if (CFEqual(keyRef, kDADiskDescriptionMediaBlockSizeKey))  /* ( CFNumber     ) */
	{
		return [value stringValue];
	}

	if (CFEqual(keyRef, kDADiskDescriptionMediaBSDMajorKey))   /* ( CFNumber     ) */
	{
		return [value stringValue];
	}

	if (CFEqual(keyRef, kDADiskDescriptionMediaBSDMinorKey))   /* ( CFNumber     ) */
	{
		return [value stringValue];
	}

	if (CFEqual(keyRef, kDADiskDescriptionMediaBSDNameKey))    /* ( CFString     ) */
	{
		return value;
	}

	if (CFEqual(keyRef, kDADiskDescriptionMediaBSDUnitKey))    /* ( CFNumber     ) */
	{
		return [value stringValue];
	}

	if (CFEqual(keyRef, kDADiskDescriptionMediaContentKey))    /* ( CFString     ) */
	{
		return value;
	}

	if (CFEqual(keyRef, kDADiskDescriptionMediaIconKey))       /* ( CFDictionary ) */
	{
		return [value description];
	}

	if (CFEqual(keyRef, kDADiskDescriptionMediaKindKey))       /* ( CFString     ) */
	{
		return value;
	}

	if (CFEqual(keyRef, kDADiskDescriptionMediaNameKey))       /* ( CFString     ) */
	{
		return value;
	}

	if (CFEqual(keyRef, kDADiskDescriptionMediaPathKey))       /* ( CFString     ) */
	{
		return value;
	}

	if (CFEqual(keyRef, kDADiskDescriptionMediaSizeKey))       /* ( CFNumber     ) */
	{
		return [self formattedSizeDescriptionFromNumber:(NSNumber *)value];
	}

	if (CFEqual(keyRef, kDADiskDescriptionMediaTypeKey))       /* ( CFString     ) */
	{
		return value;
	}

	if (CFEqual(keyRef, kDADiskDescriptionDeviceGUIDKey))      /* ( CFData       ) */
	{
		return [value description];
	}

	if (CFEqual(keyRef, kDADiskDescriptionDeviceModelKey))     /* ( CFString     ) */
	{
		return value;
	}

	if (CFEqual(keyRef, kDADiskDescriptionDevicePathKey))      /* ( CFString     ) */
	{
		return value;
	}

	if (CFEqual(keyRef, kDADiskDescriptionDeviceProtocolKey))  /* ( CFString     ) */
	{
		return value;
	}

	if (CFEqual(keyRef, kDADiskDescriptionDeviceRevisionKey))  /* ( CFString     ) */
	{
		return value;
	}

	if (CFEqual(keyRef, kDADiskDescriptionDeviceUnitKey))      /* ( CFNumber     ) */
	{
		return [value stringValue];
	}

	if (CFEqual(keyRef, kDADiskDescriptionDeviceVendorKey))    /* ( CFString     ) */
	{
		return value;
	}

	if (CFEqual(keyRef, kDADiskDescriptionBusNameKey))         /* ( CFString     ) */
	{
		return value;
	}

	if (CFEqual(keyRef, kDADiskDescriptionBusPathKey))         /* ( CFString     ) */
	{
		return value;
	}

	if (CFEqual(keyRef, CFSTR("DAAppearanceTime")))
	{
		return [[NSDate dateWithTimeIntervalSinceReferenceDate:[value doubleValue]] description];
	}

	Log(LOG_INFO, @"Unknown disk description key: %@", keyRef);

	return @"N/A";
}

- (NSString *)stringForDADiskKey:(NSString *)key value:(id)value
{
	return [NSString stringWithFormat:@"\t%@\t%@\n", 
			[self localizedStringForDADiskKey:key], 
			[self localizedValueStringForDADiskKey:key value:value]];
}

- (void)refreshDiskInfo
{
	self.diskDescription = self.disk.diskDescription;

	NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@""];

	NSFont *font = [NSFont fontWithName:@"Helvetica Bold" size:12.0];
	NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil];

	NSArray *keys = [self.disk.diskDescription allKeys];
	keys = [keys sortedArrayUsingSelector:@selector(compare:)];

	for (NSString *key in keys)
	{
		// Ignore certain keys
		if ([key isEqual: (NSString *)kDADiskDescriptionMediaIconKey])
		{
			continue;
		}

		id value = [self.disk.diskDescription objectForKey:key];

		NSString *string = nil;
		NSAttributedString *attrString = nil;

		string = [NSString stringWithFormat:@"\t%@\t", [self localizedStringForDADiskKey:key]];
		attrString = [[NSAttributedString alloc] initWithString:string attributes:attrs];
		[text appendAttributedString:attrString];

		string = [NSString stringWithFormat:@"%@\n", [self localizedValueStringForDADiskKey:key value:value]];
		attrString = [[NSAttributedString alloc] initWithString:string];
		[text appendAttributedString:attrString];
	}

	NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
	NSMutableArray *tabStops = [NSMutableArray array];
	[tabStops addObject:[[NSTextTab alloc] initWithType:NSRightTabStopType location:2.0 * 72.0]];
	[tabStops addObject:[[NSTextTab alloc] initWithType:NSLeftTabStopType location:2.125 * 72.0]];
	style.tabStops = tabStops;
	style.headIndent = (2.125 * 72.0);

	attrs = [NSDictionary dictionaryWithObjectsAndKeys:style, NSParagraphStyleAttributeName, nil];
	[text addAttributes:attrs range:NSMakeRange(0, [text length])];

	self.diskInfo = text;
}

- (void)diskDidChange:(NSNotification *)notif
{
	[self refreshDiskInfo];
}

- (void)setDisk:(Disk *)newDisk
{
	if (newDisk	!= _disk)
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self
			name:DADiskDidChangeNotification object:_disk];
		_disk = newDisk;
		[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(diskDidChange:) name:DADiskDidChangeNotification
			object:_disk];
	}
}

@end
