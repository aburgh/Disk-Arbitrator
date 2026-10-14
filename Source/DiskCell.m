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
#import "Arbitrator.h"
#import "TrustedDiskStore.h"


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
@synthesize fileSystem;
@synthesize statusText;
@synthesize trusted;


- (id)copyWithZone:(NSZone *)zone
{
	id obj = [super copyWithZone:zone];
	if (iconCell) iconCell = [iconCell copyWithZone:zone];
	if (textCell) textCell = [textCell copyWithZone:zone];
	[BSDName retain];
	[mediaName retain];
	[mediaSize retain];
	[volumeName retain];
	[fileSystem retain];
	[statusText retain];
	
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
	[fileSystem release];
	[statusText release];
	
	[super dealloc];
}

- (NSString *)sizeText
{
	if (!mediaSize)
		return nil;
	double size = mediaSize.doubleValue;
	if (size > 999 && size < 1000000)
		return [NSString stringWithFormat:@"%.2f KB", size / 1000.0];
	if (size > 999999 && size < 1000000000)
		return [NSString stringWithFormat:@"%.2f MB", size / 1000000.0];
	if (size > 999999999 && size < 1000000000000)
		return [NSString stringWithFormat:@"%.2f GB", size / 1000000000.0];
	if (size > 999999999999)
		return [NSString stringWithFormat:@"%.2f TB", size / 1000000000000.0];
	return nil;
}

- (NSColor *)statusColor
{
	if (self.isHighlighted)
		return [NSColor alternateSelectedControlTextColor];
	if (trusted)
		return [NSColor systemGreenColor];
	if ([statusText isEqualToString:NSLocalizedString(@"Read-write", nil)])
		return [NSColor systemRedColor];
	if ([statusText isEqualToString:NSLocalizedString(@"Read-only", nil)] ||
		[statusText isEqualToString:NSLocalizedString(@"Read-only mode", nil)])
		return [NSColor systemOrangeColor];
	if ([statusText isEqualToString:NSLocalizedString(@"Blocked", nil)])
		return [NSColor systemGreenColor];
	return [NSColor secondaryLabelColor];
}

- (NSString *)statusSymbolName
{
	if (trusted)
		return @"checkmark.seal.fill";
	if ([statusText isEqualToString:NSLocalizedString(@"Read-write", nil)])
		return @"exclamationmark.triangle.fill";
	if ([statusText isEqualToString:NSLocalizedString(@"Read-only", nil)] ||
		[statusText isEqualToString:NSLocalizedString(@"Read-only mode", nil)])
		return @"lock.fill";
	if ([statusText isEqualToString:NSLocalizedString(@"Blocked", nil)])
		return @"shield.fill";
	return @"circle";
}

- (void)drawStatusBadgeInFrame:(NSRect)frame
{
	if (statusText.length == 0)
		return;

	NSColor *color = [self statusColor];
	NSFont *font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
	NSDictionary *attributes = @{
		NSFontAttributeName: font,
		NSForegroundColorAttributeName: color
	};
	NSSize textSize = [statusText sizeWithAttributes:attributes];
	CGFloat symbolSide = 12.0;
	CGFloat width = textSize.width + symbolSide + 22.0;
	CGFloat height = 20.0;
	NSRect badge = NSMakeRect(NSMaxX(frame) - width - 6.0,
							   frame.origin.y + floor((NSHeight(frame) - height) / 2.0),
							   width,
							   height);
	NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:badge xRadius:height / 2.0 yRadius:height / 2.0];
	[[color colorWithAlphaComponent:(self.isHighlighted ? 0.24 : 0.16)] setFill];
	[path fill];

	NSImage *symbol = [NSImage imageWithSystemSymbolName:[self statusSymbolName] accessibilityDescription:statusText];
	NSImageSymbolConfiguration *configuration = [NSImageSymbolConfiguration configurationWithPointSize:11 weight:NSFontWeightSemibold];
	configuration = [configuration configurationByApplyingConfiguration:[NSImageSymbolConfiguration configurationWithPaletteColors:@[color]]];
	symbol = [symbol imageWithSymbolConfiguration:configuration];
	NSRect symbolRect = NSMakeRect(NSMinX(badge) + 7.0, NSMidY(badge) - (symbolSide / 2.0), symbolSide, symbolSide);
	[symbol drawInRect:symbolRect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];

	NSRect textRect = NSMakeRect(NSMaxX(symbolRect) + 4.0, NSMidY(badge) - (textSize.height / 2.0), textSize.width + 2.0, textSize.height);
	[statusText drawInRect:textRect withAttributes:attributes];
}

- (void)drawInteriorWithFrame:(NSRect)frame inView:(NSView *)controlView
{
	CGFloat iconSide = MIN(32.0, MAX(16.0, NSHeight(frame) - 10.0));
	NSRect iconFrame = NSMakeRect(frame.origin.x + indentation + 4.0,
								   frame.origin.y + floor((NSHeight(frame) - iconSide) / 2.0),
								   iconSide,
								   iconSide);
	iconCell.enabled = (mountable && !mounted) ? NO : YES;
	iconCell.highlighted = self.isHighlighted;
	[iconCell drawWithFrame:iconFrame inView:controlView];

	BOOL dimmed = mountable && !mounted && !self.isHighlighted;
	NSColor *primary = self.isHighlighted ? [NSColor alternateSelectedControlTextColor] : (dimmed ? [NSColor secondaryLabelColor] : [NSColor labelColor]);
	NSColor *secondary = self.isHighlighted ? [NSColor alternateSelectedControlTextColor] : [NSColor secondaryLabelColor];
	NSString *title = volumeName.length ? volumeName : (mediaName.length ? mediaName : (BSDName ?: @""));
	NSMutableArray *details = [NSMutableArray array];
	if (BSDName.length)
		[details addObject:BSDName];
	if (fileSystem.length)
		[details addObject:fileSystem.uppercaseString];
	NSString *sizeText = [self sizeText];
	if (sizeText.length)
		[details addObject:sizeText];
	NSString *subtitle = [details componentsJoinedByString:@"  ·  "];

	NSDictionary *titleAttributes = @{
		NSFontAttributeName: [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold],
		NSForegroundColorAttributeName: primary
	};
	NSDictionary *subtitleAttributes = @{
		NSFontAttributeName: [NSFont systemFontOfSize:11],
		NSForegroundColorAttributeName: secondary
	};
	NSSize titleSize = [title sizeWithAttributes:titleAttributes];
	NSSize subtitleSize = [subtitle sizeWithAttributes:subtitleAttributes];
	CGFloat textX = NSMaxX(iconFrame) + 8.0;
	CGFloat badgeReserve = statusText.length ? (statusText.length * 7.0 + 56.0) : 8.0;
	CGFloat textWidth = MAX(0.0, NSMaxX(frame) - textX - badgeReserve);
	CGFloat blockHeight = titleSize.height + (subtitle.length ? (2.0 + subtitleSize.height) : 0.0);
	CGFloat textY = frame.origin.y + floor((NSHeight(frame) - blockHeight) / 2.0);
	[title drawInRect:NSMakeRect(textX, textY, textWidth, titleSize.height) withAttributes:titleAttributes];
	if (subtitle.length)
		[subtitle drawInRect:NSMakeRect(textX, textY + titleSize.height + 2.0, textWidth, subtitleSize.height) withAttributes:subtitleAttributes];

	[self drawStatusBadgeInFrame:frame];
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

		self.mediaName = (NSString *)[disk.diskDescription objectForKey: (NSString *)kDADiskDescriptionMediaNameKey];
		self.mediaSize = (NSNumber *)[disk.diskDescription objectForKey: (NSString *)kDADiskDescriptionMediaSizeKey];
		self.volumeName = (NSString *)[disk.diskDescription objectForKey: (NSString *)kDADiskDescriptionVolumeNameKey];
		self.fileSystem = (NSString *)[disk.diskDescription objectForKey:(NSString *)kDADiskDescriptionVolumeKindKey];
		self.trusted = [[TrustedDiskStore sharedStore] ruleMatchingDisk:disk] != nil;

		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		BOOL activated = [defaults boolForKey:ArbitratorIsEnabled];
		NSInteger mode = [defaults integerForKey:ArbitratorMountMode];
		if (self.trusted)
			self.statusText = NSLocalizedString(@"Trusted", nil);
		else if (disk.isMounted && !disk.isFileSystemWritable)
			self.statusText = NSLocalizedString(@"Read-only", nil);
		else if (disk.isMounted && disk.isFileSystemWritable)
			self.statusText = NSLocalizedString(@"Read-write", nil);
		else if (disk.isMountable && activated && mode == MM_BLOCK)
			self.statusText = NSLocalizedString(@"Blocked", nil);
		else if (disk.isMountable && activated && mode == MM_READONLY)
			self.statusText = NSLocalizedString(@"Read-only mode", nil);
		else if (disk.isMountable)
			self.statusText = NSLocalizedString(@"Not mounted", nil);
		else
			self.statusText = disk.isWholeDisk ? NSLocalizedString(@"Disk", nil) : NSLocalizedString(@"Volume", nil);

		self.textCell = nil;
		
		// Create Icon cell
		
		NSImageCell *imageCell = [[NSImageCell alloc] init];
		imageCell.image = disk.icon;
		self.iconCell = [imageCell autorelease];
		iconCell.imageScaling = NSImageScaleProportionallyDown;
		iconCell.alignment = NSTextAlignmentLeft;
	}
	else {
		self.textCell = nil;
		self.iconCell = nil;
		self.fileSystem = nil;
		self.statusText = nil;
		self.trusted = NO;
	}
}

@end
