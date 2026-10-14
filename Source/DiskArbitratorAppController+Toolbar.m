//
//  DiskArbitratorAppController+Toolbar.m
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 2/7/10.
//  Copyright 2010 . All rights reserved.
//

#import "DiskArbitratorAppController+Toolbar.h"
#import "Disk.h"
#import "AuditLog.h"
#import "TrustedDiskStore.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>


@implementation AppController (AppControllerToolbar)

- (NSImage *)toolbarSymbol:(NSString *)name fallback:(NSString *)fallback
{
	NSImage *image = [NSImage imageWithSystemSymbolName:name accessibilityDescription:name];
	if (!image && fallback)
		image = [NSImage imageNamed:fallback];
	NSImageSymbolConfiguration *configuration = [NSImageSymbolConfiguration configurationWithPointSize:16 weight:NSFontWeightMedium scale:NSImageSymbolScaleLarge];
	return [image imageWithSymbolConfiguration:configuration] ?: image;
}

- (NSImage *)attachDiskImageIcon
{
	UTType *diskImageType = [UTType typeWithFilenameExtension:@"dmg"];
	NSImage *dmgIcon = diskImageType ? [[NSWorkspace sharedWorkspace] iconForContentType:diskImageType] : nil;
	NSImage *plugImage = [NSImage imageNamed:@"ToolbarItem Attach Disk Plug"];

	return [NSImage imageWithSize:NSMakeSize(32, 32) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
		[dmgIcon drawInRect:dstRect];
		[plugImage drawInRect:NSMakeRect(2, 16, 16, 16)];
		return YES;
	}];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
	NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
	
	if ([itemIdentifier isEqual:ToolbarItemInfoIdentifier]) {				// Info/Inspect
		item.label = NSLocalizedString(@"Info", nil);
		item.paletteLabel = NSLocalizedString(@"Info", nil);
		item.image = [self toolbarSymbol:@"info.circle" fallback:NSImageNameInfo];
		item.target = self;
		item.action = @selector(performGetInfo:);
		item.toolTip = NSLocalizedString(@"Show detailed disk info", nil);
	} 
	else if ([itemIdentifier isEqual:ToolbarItemEjectIdentifier]) {		// Eject
		item.label = NSLocalizedString(@"Eject", nil);
		item.paletteLabel = NSLocalizedString(@"Eject", nil);
		item.image = [self toolbarSymbol:@"eject.fill" fallback:NSImageNameStopProgressTemplate];
		item.target = self;
		item.action = @selector(performEject:);
		item.toolTip = NSLocalizedString(@"Eject removable media.", nil);
	}
	else if ([itemIdentifier isEqual:ToolbarItemMountIdentifier]) {			// Mount
		item.label = NSLocalizedString(@"Mount", nil);
		item.paletteLabel = NSLocalizedString(@"Mount/Unmount", nil);
		item.image = [self toolbarSymbol:@"externaldrive.badge.plus" fallback:NSImageNameAddTemplate];
		item.target = self;
		item.action = @selector(performMountOrUnmount:);
		item.toolTip = NSLocalizedString(@"Select a volume, then click to mount or unmount.", nil);
	}
	else if ([itemIdentifier isEqual:ToolbarItemAttachDiskImageIdentifier]) {			// Attach Disk Image
		item.label = NSLocalizedString(@"Attach", nil);
		item.paletteLabel = NSLocalizedString(@"Attach Disk Image", nil);
//		item.image = [NSImage imageNamed:@"ToolbarItem Attach Disk Image"];
		item.image = [self toolbarSymbol:@"doc.badge.plus" fallback:nil] ?: self.attachDiskImageIcon;
		item.target = self;
		item.action = @selector(performAttachDiskImage:);
		item.toolTip = NSLocalizedString(@"Attach Disk Image", nil);
	}
	else if ([itemIdentifier isEqual:ToolbarItemTrustIdentifier]) {
		item.label = NSLocalizedString(@"Trust", nil);
		item.paletteLabel = NSLocalizedString(@"Trust Disk", nil);
		item.image = [self toolbarSymbol:@"checkmark.seal" fallback:NSImageNameMenuOnStateTemplate];
		item.target = self;
		item.action = @selector(trustSelectedDisk:);
		item.toolTip = NSLocalizedString(@"Let the selected disk mount normally.", nil);
	}
	return item;
}


//---------------------------------------------------------- 
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects: 
			NSToolbarSpaceItemIdentifier,
			NSToolbarFlexibleSpaceItemIdentifier,
			ToolbarItemInfoIdentifier,
			ToolbarItemMountIdentifier,
			ToolbarItemEjectIdentifier,
			ToolbarItemTrustIdentifier,
			ToolbarItemAttachDiskImageIdentifier,
			nil];
}


//---------------------------------------------------------- 
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:   
			ToolbarItemInfoIdentifier,
			ToolbarItemMountIdentifier,
			ToolbarItemEjectIdentifier,
			ToolbarItemTrustIdentifier,
			NSToolbarFlexibleSpaceItemIdentifier,
			ToolbarItemAttachDiskImageIdentifier,
			nil];
}


//---------------------------------------------------------- 
-(BOOL)validateToolbarItem:(NSToolbarItem*)toolbarItem {
	BOOL enabled = YES;
	
    if ([[toolbarItem itemIdentifier] isEqual:ToolbarItemInfoIdentifier])
		enabled = YES;
	
	else if ([[toolbarItem itemIdentifier] isEqual:ToolbarItemMountIdentifier]) {

		// Enable the item if the disk is mountable
		// Set the label "Unmount" if mounted, otherwise to "Mount"
		
		if (self.canUnmountSelectedDisk) {
			[toolbarItem setLabel:NSLocalizedString(@"Unmount", nil)];
			toolbarItem.image = [self toolbarSymbol:@"externaldrive.badge.minus" fallback:NSImageNameStopProgressTemplate];
			enabled	= YES;
		}
		else {
			[toolbarItem setLabel:NSLocalizedString(@"Mount", nil)];
			toolbarItem.image = [self toolbarSymbol:@"externaldrive.badge.plus" fallback:NSImageNameAddTemplate];

			if (!self.canMountSelectedDisk)
				enabled = NO;
		}
	}
	else if ([[toolbarItem itemIdentifier] isEqual:ToolbarItemTrustIdentifier]) {
		Disk *disk = self.selectedDisk;
		BOOL identifiable = DAVolumeUUIDForDisk(disk).length > 0 || DAMediaUUIDForDisk(disk).length > 0;
		BOOL alreadyTrusted = identifiable && [[TrustedDiskStore sharedStore] ruleMatchingDisk:disk] != nil;
		enabled = identifiable && !alreadyTrusted;
	}
	
	else if ([[toolbarItem itemIdentifier] isEqual:ToolbarItemEjectIdentifier]) {
		
		enabled = self.canEjectSelectedDisk;
	}
	
	return enabled;
}

@end


void SetupToolbar(NSWindow *window, id delegate)
{
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:ToolbarItemMainIdentifier];
	[toolbar setDelegate:delegate];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	[window setToolbar:toolbar];
}



// Toolbar Item Identifier constants
NSString * const ToolbarItemMainIdentifier = @"DiskArbitratorToolbar-v2";
NSString * const ToolbarItemInfoIdentifier = @"ToolbarItemInfoIdentifier"; 
NSString * const ToolbarItemMountIdentifier = @"ToolbarItemMountIdentifier";
NSString * const ToolbarItemEjectIdentifier = @"ToolbarItemEjectIdentifier"; 
NSString * const ToolbarItemAttachDiskImageIdentifier = @"ToolbarItemAttachDiskImageIdentifier";
NSString * const ToolbarItemTrustIdentifier = @"ToolbarItemTrustIdentifier"; 

