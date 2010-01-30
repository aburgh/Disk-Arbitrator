//
//  DiskCell.m
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 1/23/10.
//  Copyright 2010 . All rights reserved.
//

#import "DiskCell.h"
#import "AppError.h"
#import "Disk.h"


#define ICONPADDING 3.0

@implementation DiskCell

@synthesize iconCell;
@synthesize textCell;
@synthesize indentation;
@synthesize mountable;
@synthesize mounted;
@synthesize mediaName;
@synthesize mediaSize;
@synthesize BSDName;
@synthesize volumeName;


- (id)copyWithZone:(NSZone *)zone
{
	id obj = [super copyWithZone:zone];
	if (iconCell) iconCell = [iconCell copyWithZone:zone];
	if (textCell) textCell = [textCell copyWithZone:zone];
	[BSDName retain];
	[mediaName retain];
	[mediaSize retain];
	[volumeName retain];
	
	return obj;
}

- (void)dealloc
{
	[iconCell release];
	[textCell release];
	[BSDName release];
	[mediaName release];
	[mediaSize release];
	[volumeName release];
	
	[super dealloc];
}

- (void)drawInteriorWithFrame:(NSRect)frame inView:(NSView *)controlView
{
//	fprintf(stderr, "Frame: %s\t\tView Frame: %s\n", [NSStringFromRect(frame) UTF8String],
//			[NSStringFromRect([view frame]) UTF8String]);

	NSRect iconFrame, textFrame;

	CGFloat minwh = MIN(frame.size.width - indentation, frame.size.height);
	iconFrame = NSMakeRect(frame.origin.x + indentation + ICONPADDING, frame.origin.y, minwh, minwh);

	[iconCell setEnabled: (mountable && !mounted) ? NO : YES];  // gray out if a volume but not mounted
	[iconCell setHighlighted:[self isHighlighted]];
	[iconCell drawWithFrame:iconFrame inView:controlView];

	textFrame = NSMakeRect(NSMaxX(iconFrame) + ICONPADDING, frame.origin.y, 
								  MAX(NSWidth(frame) - NSWidth(iconFrame) - ICONPADDING, 0.0),  NSHeight(frame));

	[textCell setEnabled: (mountable && !mounted) ? NO : YES];  // gray out if a volume but not mounted
	[textCell setHighlighted:[self isHighlighted]];
	[textCell drawWithFrame:textFrame inView:controlView];
}


- (void)setObjectValue:(id)value
{
	Disk *disk = (Disk *)value;
	
	if (disk) {
//		Log(1, @"%s self: %p disk: %p", __FUNCTION__, self, disk);

		self.indentation = disk.isWholeDisk ? 0.0 : 17.0;
		self.mounted = disk.mounted;
		self.mountable = disk.mountable;
		
		CFDictionaryRef descRef = disk.diskDescription;
		self.mediaName = (NSString *) CFDictionaryGetValue(descRef, kDADiskDescriptionMediaNameKey);
		self.mediaSize = (NSNumber *) CFDictionaryGetValue(descRef, kDADiskDescriptionMediaSizeKey);
		self.volumeName = (NSString *) CFDictionaryGetValue(descRef, kDADiskDescriptionVolumeNameKey);
		
		// Create Text description cell
		
		NSString *sizeDisplayValue = nil;
		if (mediaSize) {
			double size = [mediaSize doubleValue];
			if (size > 999 && size < 1000000)
				sizeDisplayValue = [NSString stringWithFormat:@"%03.02f KB ", (size / 1000.0)];
			else if (size > 999999 && size < 1000000000)
				sizeDisplayValue = [NSString stringWithFormat:@"%03.02f MB ", (size / 1000000.0)];
			else if (size > 999999999 && size < 1000000000000)
				sizeDisplayValue = [NSString stringWithFormat:@"%03.02f GB ", (size / 1000000000.0)];
			else if (size > 999999999999)
				sizeDisplayValue = [NSString stringWithFormat:@"%03.02f TB ", (size / 1000000000000.0)];
		}
		NSMutableString *desc = sizeDisplayValue ? [sizeDisplayValue mutableCopy] : [NSMutableString new];

		if (volumeName)
			[desc appendString:volumeName];
		else if (mediaName) 
			[desc appendString:mediaName];

		self.textCell = [[[NSCell alloc] initTextCell:desc] autorelease];
		[desc release];
		
		// Create Icon cell
		
		self.iconCell = [[[NSImageCell alloc] initImageCell:disk.icon] autorelease];
		[iconCell setImageScaling:NSImageScaleProportionallyDown];
		[iconCell setAlignment:NSLeftTextAlignment];
	}
	else {
		self.textCell = nil;
		self.iconCell = nil;
	}
}

@end
