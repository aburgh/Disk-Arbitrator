//
//  DiskArbitratorAppController.m
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 1/10/10.
//  Copyright 2010 . All rights reserved.
//

#import "DiskArbitratorAppController.h"
#import "Arbitrator.h"
#import "Disk.h"

@implementation AppController

@synthesize window;
@synthesize statusMenu;
@synthesize disksArrayController;
@synthesize sortDescriptors;
@synthesize statusItem;
@synthesize arbitrator;

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	// Insert code here to initialize your application 
	
	NSStatusBar *bar = [NSStatusBar systemStatusBar];
//	self.statusItem = [bar statusItemWithLength:NSVariableStatusItemLength];
//	[statusItem setTitle:@"Arbitrator..."];
	self.statusItem = [bar statusItemWithLength:NSSquareStatusItemLength];
	NSString *iconPath = [[NSBundle mainBundle] pathForResource:@"StatusItem Green" ofType:@"png"];
	NSImage *statusIcon = [[NSImage alloc] initWithContentsOfFile:iconPath];
	[statusItem setImage:statusIcon];
	[statusIcon release];
	[statusItem setMenu:statusMenu];
	
	self.arbitrator = [Arbitrator new];
	[arbitrator activate];
	
	self.sortDescriptors = [NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:@"BSDName" ascending:YES] autorelease]]	;
}

- (IBAction)showMainWindow:(id)sender
{
//	[NSApp showWindow:window];
	[window orderFront:sender];
}

#pragma mark TableView Delegates

// A custom cell is used for the media description column.  Couldn't find a way to bind it to the disk
// object, so implemented the dataSource delegate.

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)column row:(int)rowIndex
{
    Disk *disk;
	
    NSParameterAssert(rowIndex >= 0 && rowIndex < [arbitrator.disks count]);
    disk = [[disksArrayController arrangedObjects] objectAtIndex:rowIndex];

	if ([[column identifier] isEqual:@"BSDName"])
		return disk.BSDName;

	//	fprintf(stdout, "getting value: %s\n", [disk.BSDName UTF8String]);
	return disk;
}

@end
