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
@synthesize disk;
@synthesize diskDescription;
@synthesize diskInfo;

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
	if ([key isEqual:@"diskDescription"])
		return [NSSet setWithObject:@"disk.diskDescription"];

	return [super keyPathsForValuesAffectingValueForKey:key];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[textView release];
	[disk release];
	[diskDescription release];
	[diskInfo release];
	[super dealloc];	
}

- (NSString *)localizedStringForDADiskKey:(NSString *)key
{
	if ([key isEqual: (NSString *)kDADiskDescriptionVolumeKindKey])      /* ( CFString     ) */
		return NSLocalizedString(@"Volume Kind", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionVolumeMountableKey]) /* ( CFBoolean    ) */
		return NSLocalizedString(@"Volume Mountable", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionVolumeNameKey])      /* ( CFString     ) */
		return NSLocalizedString(@"Volume Name", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionVolumeNetworkKey])   /* ( CFBoolean    ) */
		return NSLocalizedString(@"Volume Network", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionVolumePathKey])      /* ( CFURL        ) */
		return NSLocalizedString(@"Mount Path", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionVolumeUUIDKey])      /* ( CFUUID       ) */
		return NSLocalizedString(@"Volume UUID", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionMediaBlockSizeKey])  /* ( CFNumber     ) */
		return NSLocalizedString(@"Media Block Size", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionMediaBSDMajorKey])   /* ( CFNumber     ) */
		return NSLocalizedString(@"Media BSD Major", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionMediaBSDMinorKey])   /* ( CFNumber     ) */
		return NSLocalizedString(@"Media BSD Minor", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionMediaBSDNameKey])    /* ( CFString     ) */
		return NSLocalizedString(@"Media BSD Name", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionMediaBSDUnitKey])    /* ( CFNumber     ) */
		return NSLocalizedString(@"Media BSD Unit", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionMediaContentKey])    /* ( CFString     ) */
		return NSLocalizedString(@"Media Content", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionMediaEjectableKey])  /* ( CFBoolean    ) */
		return NSLocalizedString(@"Media Ejectable", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionMediaIconKey])       /* ( CFDictionary ) */
		return NSLocalizedString(@"Media Icon", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionMediaKindKey])       /* ( CFString     ) */
		return NSLocalizedString(@"Media Kind", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionMediaLeafKey])       /* ( CFBoolean    ) */
		return NSLocalizedString(@"Media Is Leaf", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionMediaNameKey])       /* ( CFString     ) */
		return NSLocalizedString(@"Media Name", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionMediaPathKey])       /* ( CFString     ) */
		return NSLocalizedString(@"Media Path", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionMediaRemovableKey])  /* ( CFBoolean    ) */
		return NSLocalizedString(@"Media Is Removable", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionMediaSizeKey])       /* ( CFNumber     ) */
		return NSLocalizedString(@"Media Size", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionMediaTypeKey])       /* ( CFString     ) */
		return NSLocalizedString(@"Media Type", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionMediaUUIDKey])       /* ( CFUUID       ) */
		return NSLocalizedString(@"Media UUID", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionMediaWholeKey])      /* ( CFBoolean    ) */
		return NSLocalizedString(@"Media Is Whole", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionMediaWritableKey])   /* ( CFBoolean    ) */
		return NSLocalizedString(@"Media Is Writable", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionDeviceGUIDKey])      /* ( CFData       ) */
		return NSLocalizedString(@"Device GUID", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionDeviceInternalKey])  /* ( CFBoolean    ) */
		return NSLocalizedString(@"Device Is Internal", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionDeviceModelKey])     /* ( CFString     ) */
		return NSLocalizedString(@"Device Model", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionDevicePathKey])      /* ( CFString     ) */
		return NSLocalizedString(@"Device Path", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionDeviceProtocolKey])  /* ( CFString     ) */
		return NSLocalizedString(@"Device Protocol", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionDeviceRevisionKey])  /* ( CFString     ) */
		return NSLocalizedString(@"Device Revision", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionDeviceUnitKey])      /* ( CFNumber     ) */
		return NSLocalizedString(@"Device Unit", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionDeviceVendorKey])    /* ( CFString     ) */
		return NSLocalizedString(@"Device Vendor", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionBusNameKey])         /* ( CFString     ) */
		return NSLocalizedString(@"Bus", nil);
	if ([key isEqual: (NSString *)kDADiskDescriptionBusPathKey])         /* ( CFString     ) */
		return NSLocalizedString(@"Bus Path", nil);
	if ([key isEqual: @"DAAppearanceTime"])
		return NSLocalizedString(@"Appearance Time", nil);
	
	Log(LOG_INFO, @"Unknown disk description key: %@", key);
	
	return @"N/A";
}

- (NSString *)formattedSizeDescriptionFromNumber:(NSNumber *)sizeValue
{
	NSString *formattedValue;

	double size = [sizeValue doubleValue];
	
	if (size > 999.0 && size < 1000000.0)
		formattedValue = [NSString stringWithFormat:@"%03.02f KB (%@ bytes)", (size / 1000.0), sizeValue];
	else if (size > 999999.0 && size < 1000000000.0)
		formattedValue = [NSString stringWithFormat:@"%03.02f MB (%@ bytes)", (size / 1000000.0), sizeValue];
	else if (size > 999999999.0 && size < 1000000000000.0)
		formattedValue = [NSString stringWithFormat:@"%03.02f GB (%@ bytes)", (size / 1000000000.0), sizeValue];
	else if (size > 999999999999.0)
		formattedValue = [NSString stringWithFormat:@"%03.02f TB (%@ bytes)", (size / 1000000000000.0), sizeValue];
	else
		formattedValue = sizeValue.stringValue;

	return formattedValue;
}

- (NSString *)localizedValueStringForDADiskKey:(NSString *)key value:(id)value
{
	CFStringRef keyRef = (CFStringRef) key;

	if (CFEqual(keyRef, kDADiskDescriptionVolumeKindKey))      /* ( CFString     ) */
		return value;

	if (CFEqual(keyRef, kDADiskDescriptionVolumeMountableKey) || /* ( CFBoolean    ) */
		CFEqual(keyRef, kDADiskDescriptionVolumeNetworkKey)   ||
		CFEqual(keyRef, kDADiskDescriptionMediaLeafKey)       ||
		CFEqual(keyRef, kDADiskDescriptionMediaEjectableKey)  ||
		CFEqual(keyRef, kDADiskDescriptionMediaRemovableKey)  ||
		CFEqual(keyRef, kDADiskDescriptionMediaWholeKey)      ||
		CFEqual(keyRef, kDADiskDescriptionMediaWritableKey)   ||
		CFEqual(keyRef, kDADiskDescriptionDeviceInternalKey)
		)
		return [value boolValue] ? @"Yes" : @"No";
	
	
	if (CFEqual(keyRef, kDADiskDescriptionVolumeNameKey))      /* ( CFString     ) */
		return value;
	
	if (CFEqual(keyRef, kDADiskDescriptionVolumePathKey))      /* ( CFURL        ) */
		return [(NSURL *)value path];
	
	if (CFEqual(keyRef, kDADiskDescriptionVolumeUUIDKey) || 	 /* ( CFUUID       ) */
		CFEqual(keyRef, kDADiskDescriptionMediaUUIDKey))
	{
		NSString *uuidString = (NSString *) CFUUIDCreateString(kCFAllocatorDefault, (CFUUIDRef)value);

		return [uuidString autorelease];
	}

	if (CFEqual(keyRef, kDADiskDescriptionMediaBlockSizeKey))  /* ( CFNumber     ) */
		return [value stringValue];
	
	if (CFEqual(keyRef, kDADiskDescriptionMediaBSDMajorKey))   /* ( CFNumber     ) */
		return [value stringValue];
	
	if (CFEqual(keyRef, kDADiskDescriptionMediaBSDMinorKey))   /* ( CFNumber     ) */
		return [value stringValue];

	if (CFEqual(keyRef, kDADiskDescriptionMediaBSDNameKey))    /* ( CFString     ) */
		return value;

	if (CFEqual(keyRef, kDADiskDescriptionMediaBSDUnitKey))    /* ( CFNumber     ) */
		return [value stringValue];

	if (CFEqual(keyRef, kDADiskDescriptionMediaContentKey))    /* ( CFString     ) */
		return value;

	if (CFEqual(keyRef, kDADiskDescriptionMediaIconKey))       /* ( CFDictionary ) */
		return [value description];

	if (CFEqual(keyRef, kDADiskDescriptionMediaKindKey))       /* ( CFString     ) */
		return value;

	if (CFEqual(keyRef, kDADiskDescriptionMediaNameKey))       /* ( CFString     ) */
		return value;

	if (CFEqual(keyRef, kDADiskDescriptionMediaPathKey))       /* ( CFString     ) */
		return value;

	if (CFEqual(keyRef, kDADiskDescriptionMediaSizeKey))       /* ( CFNumber     ) */
		return [self formattedSizeDescriptionFromNumber:(NSNumber *)value];

	if (CFEqual(keyRef, kDADiskDescriptionMediaTypeKey))       /* ( CFString     ) */
		return value;

	if (CFEqual(keyRef, kDADiskDescriptionDeviceGUIDKey))      /* ( CFData       ) */
		return [value description];

	if (CFEqual(keyRef, kDADiskDescriptionDeviceModelKey))     /* ( CFString     ) */
		return value;

	if (CFEqual(keyRef, kDADiskDescriptionDevicePathKey))      /* ( CFString     ) */
		return value;

	if (CFEqual(keyRef, kDADiskDescriptionDeviceProtocolKey))  /* ( CFString     ) */
		return value;

	if (CFEqual(keyRef, kDADiskDescriptionDeviceRevisionKey))  /* ( CFString     ) */
		return value;

	if (CFEqual(keyRef, kDADiskDescriptionDeviceUnitKey))      /* ( CFNumber     ) */
		return [value stringValue];
	
	if (CFEqual(keyRef, kDADiskDescriptionDeviceVendorKey))    /* ( CFString     ) */
		return value;

	if (CFEqual(keyRef, kDADiskDescriptionBusNameKey))         /* ( CFString     ) */
		return value;

	if (CFEqual(keyRef, kDADiskDescriptionBusPathKey))         /* ( CFString     ) */
		return value;
	
	if (CFEqual(keyRef, CFSTR("DAAppearanceTime")))
		return [[NSDate dateWithTimeIntervalSinceReferenceDate:[value doubleValue]] description];

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
	self.diskDescription = (NSDictionary *)disk.diskDescription;
	
	NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@""];

	NSFont *font = [NSFont fontWithName:@"Helvetica Bold" size:12.0];
	NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil];
	
	NSArray *keys = [(NSDictionary *)disk.diskDescription allKeys];
	keys = [keys sortedArrayUsingSelector:@selector(compare:)];
	
	for (NSString *key in keys)
	{
		// Ignore certain keys
		if ([key isEqual: (NSString *)kDADiskDescriptionMediaIconKey])
			continue;
		
		id value = [(NSDictionary *)disk.diskDescription objectForKey:key];
		
		NSString *string;
		NSAttributedString *attrString;

		string = [NSString stringWithFormat:@"\t%@\t", [self localizedStringForDADiskKey:key]];
		attrString = [[NSAttributedString alloc] initWithString:string attributes:attrs];
		[text appendAttributedString:attrString];
		[attrString release];

		string = [NSString stringWithFormat:@"%@\n", [self localizedValueStringForDADiskKey:key value:value]];
		attrString = [[NSAttributedString alloc] initWithString:string];
		[text appendAttributedString:attrString];
		[attrString release];
	}

	
	NSMutableParagraphStyle *style = [[NSMutableParagraphStyle new] autorelease];
	NSMutableArray *tabStops = [NSMutableArray array];
	[tabStops addObject:[[[NSTextTab alloc] initWithType:NSRightTabStopType location:2.0 * 72.0] autorelease]];
	[tabStops addObject:[[[NSTextTab alloc] initWithType:NSLeftTabStopType location:2.125 * 72.0] autorelease]];
	style.tabStops = tabStops;
	style.headIndent = (2.125 * 72.0);
	
	attrs = [NSDictionary dictionaryWithObjectsAndKeys:style, NSParagraphStyleAttributeName, nil];
	[text addAttributes:attrs range:NSMakeRange(0, [text length])];

	self.diskInfo = text;
	[text release];
}

- (void)diskDidChange:(NSNotification *)notif
{
	[self refreshDiskInfo];
}

- (void)setDisk:(Disk *)newDisk
{
	if (newDisk	!= disk) {
		[[NSNotificationCenter defaultCenter] removeObserver:self name:DADiskDidChangeNotification object:disk];
		[disk autorelease];
		disk = [newDisk retain];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(diskDidChange:) name:DADiskDidChangeNotification object:disk];
	}
}

@end
