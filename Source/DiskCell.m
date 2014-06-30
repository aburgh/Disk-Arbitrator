//
//  DiskCell.m
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 1/23/10.
//  Copyright 2010 Aaron Burghardt. All rights reserved.
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
@synthesize isDiskWritable;
@synthesize isFileSystemWritable;
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
//	Log(LOG_DEBUG, @"Frame: %s\t\tView Frame: %@", NSStringFromRect(frame),	NSStringFromRect([view frame]));

	NSRect iconFrame, textFrame;

	CGFloat minwh = MIN(frame.size.width - indentation, frame.size.height);
	iconFrame = NSMakeRect(frame.origin.x + indentation + ICONPADDING, frame.origin.y, minwh, minwh);

	iconCell.enabled = (mountable && !mounted) ? NO : YES;  // dimmed if a volume but not mounted
	iconCell.highlighted = self.isHighlighted;
	[iconCell drawWithFrame:iconFrame inView:controlView];

	// A disk may be mounted R/O even though the underlying disk is R/W. To avoid giving the false
	// impression that a disk is completely protected, display a transparent, faint lock when the
	// disk is R/W, and display a solid black lock when the disk and the FS are both R/O.

	if (mountable && mounted && !isFileSystemWritable) {

		NSImage *lockImage = [NSImage imageNamed:NSImageNameLockLockedTemplate];
		lockImage.flipped = controlView.isFlipped;

		CGFloat scale;
		if (frame.size.height <= 16.0)
			scale = 0.5;
		else if (frame.size.height <= 32.0)
			scale = 0.75;
		else if (frame.size.height <= 64.0)
			scale = 2.0;
		else if (frame.size.height <= 128.0)
			scale = 4.0;
		else if (frame.size.height <= 256.0)
			scale = 8.0;
		else if (frame.size.height <= 512.0)
			scale = 16.0;
		else if (frame.size.height <= 1024.0)
			scale = 32.0;
		else
			scale = 2.0;

		CGFloat opacity = isDiskWritable ? 0.40 : 1.0;

		CGFloat scaledWidth  = lockImage.size.width * scale;
		CGFloat scaledHeight = lockImage.size.height * scale;
		NSRect rect = NSMakeRect(NSMaxX(iconFrame) - scaledWidth, NSMaxY(iconFrame) - scaledHeight, scaledWidth, scaledHeight);

		[lockImage drawInRect:rect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:opacity];
	}

	textFrame = NSMakeRect(NSMaxX(iconFrame) + ICONPADDING, frame.origin.y, 
								  MAX(NSWidth(frame) - (NSMaxX(iconFrame) + ICONPADDING), 0.0),  NSHeight(frame));
	NSSize textCellSize = textCell.cellSize;
	textFrame.origin.y = frame.origin.y + floor((frame.size.height - textCellSize.height) / 2);

	textCell.enabled = (mountable && !mounted) ? NO : YES;  // dimmed if a volume but not mounted
	textCell.highlighted = self.isHighlighted;
	[textCell drawWithFrame:textFrame inView:controlView];
}


- (void)setObjectValue:(id)value
{
	Disk *disk = (Disk *)value;
	
	if (disk) {
//		Log(LOG_DEBUG, @"%s self: %p disk: %p", __func__, self, disk);

		self.BSDName = disk.BSDName;
		self.indentation = disk.isWholeDisk ? 0.0 : 17.0;
		self.mounted = disk.isMounted;
		self.mountable = disk.isMountable;
		self.isDiskWritable = disk.isWritable;
		self.isFileSystemWritable = disk.isFileSystemWritable;
		
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
		self.textCell.lineBreakMode = NSLineBreakByTruncatingTail;
		[desc release];
		
		// Create Icon cell
		
		self.iconCell = [[[NSImageCell alloc] initImageCell:disk.icon] autorelease];
		iconCell.imageScaling = NSImageScaleProportionallyDown;
		iconCell.alignment = NSLeftTextAlignment;
	}
	else {
		self.textCell = nil;
		self.iconCell = nil;
	}
}

@end
