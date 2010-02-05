//
//  DiskArbitratorAppController.h
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 1/10/10.
//  Copyright 2010 Aaron Burghardt. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Arbitrator;

@interface AppController : NSObject <NSApplicationDelegate> 
{
    NSWindow *window;
	NSStatusItem *statusItem;
	NSMenu *statusMenu;
	NSTableView *tableView;
	
	NSArrayController *disksArrayController;
	Arbitrator *arbitrator;
	NSArray *sortDescriptors;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSMenu *statusMenu;
@property (assign) IBOutlet NSTableView *tableView;
@property (assign) IBOutlet NSArrayController *disksArrayController;
@property (copy) NSArray *sortDescriptors;
@property (retain) NSStatusItem *statusItem;
@property (retain) Arbitrator *arbitrator;

- (IBAction)showMainWindow:(id)sender;
- (IBAction)performActivation:(id)sender;
- (IBAction)performDeactivation:(id)sender;
- (IBAction)toggleActivation:(id)sender;

- (IBAction)performSetMountBlockMode:(id)sender;
- (IBAction)performSetMountReadOnlyMode:(id)sender;

@end
