//
//  DiskArbitratorAppController.h
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 1/10/10.
//  Copyright 2010 Aaron Burghardt. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Arbitrator;
@class Disk;

@interface AppController : NSObject <NSApplicationDelegate> 
{
    NSPanel *window;
	NSStatusItem *statusItem;
	NSMenu *statusMenu;
	NSTableView *tableView;
	
	NSArrayController *disksArrayController;
	Arbitrator *arbitrator;
	NSArray *sortDescriptors;
	
	NSMutableArray *displayErrorQueue; // 
}

@property (assign) IBOutlet NSPanel *window;
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

- (IBAction)performMount:(id)sender;
- (IBAction)performUnmount:(id)sender;
- (IBAction)performMountOrUnmount:(id)sender;
- (IBAction)performEject:(id)sender;
- (IBAction)performGetInfo:(id)sender;
- (IBAction)performAttachDiskImage:(id)sender;

- (Disk *)selectedDisk;
- (BOOL)canEjectSelectedDisk;
- (BOOL)canMountSelectedDisk;
- (BOOL)canUnmountSelectedDisk;

@end
