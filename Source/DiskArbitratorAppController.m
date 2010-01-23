//
//  DiskArbitratorAppController.m
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 1/10/10.
//  Copyright 2010 . All rights reserved.
//

#import "DiskArbitratorAppController.h"
#import "Arbitrator.h"

@implementation AppController

@synthesize window;
@synthesize statusItem;
@synthesize statusMenu;
@synthesize arbitrator;
@synthesize sortDescriptors;

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	// Insert code here to initialize your application 
	
	NSStatusBar *bar = [NSStatusBar systemStatusBar];
	self.statusItem = [bar statusItemWithLength:NSVariableStatusItemLength];
	[statusItem setTitle:@"Arbitrator..."];
	[statusItem setMenu:statusMenu];
	
	self.arbitrator = [Arbitrator new];
	[arbitrator activate];
	
	self.sortDescriptors = [NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:@"BSDName" ascending:YES] autorelease]];
}

- (IBAction)showMainWindow:(id)sender
{
//	[NSApp showWindow:window];
	[window orderFront:sender];
}

@end
