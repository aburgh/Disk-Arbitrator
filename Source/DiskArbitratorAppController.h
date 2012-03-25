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

@interface AppController : NSObject // <NSApplicationDelegate> 
{
    NSPanel *window;
	NSStatusItem *statusItem;
	NSMenu *statusMenu;
	NSTableView *tableView;
	
	NSArrayController *disksArrayController;
	Arbitrator *arbitrator;
	NSArray *sortDescriptors;

	BOOL hasUserLaunchAgent;
	BOOL hasSystemLaunchAgent;
	NSString *installUserLaunchAgentMenuTitle;
	
	NSMutableArray *displayErrorQueue; // 
}

@property (assign) IBOutlet NSPanel *window;
@property (assign) IBOutlet NSMenu *statusMenu;
@property (assign) IBOutlet NSTableView *tableView;
@property (assign) IBOutlet NSArrayController *disksArrayController;
@property (copy) NSArray *sortDescriptors;
@property (retain) NSStatusItem *statusItem;
@property (retain) Arbitrator *arbitrator;
@property (readwrite) BOOL hasUserLaunchAgent;
@property (readwrite) BOOL hasSystemLaunchAgent;
@property (readonly)  BOOL canInstallLaunchAgent;
@property (copy) NSString *installUserLaunchAgentMenuTitle;

- (IBAction)showAboutPanel:(id)sender;
- (IBAction)showMainWindow:(id)sender;
- (IBAction)showPreferences:(id)sender;
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

- (void)refreshLaunchAgentStatus;
- (IBAction)installUserLaunchAgent:(id)sender;

- (Disk *)selectedDisk;
- (BOOL)canEjectSelectedDisk;
- (BOOL)canMountSelectedDisk;
- (BOOL)canUnmountSelectedDisk;

@end
