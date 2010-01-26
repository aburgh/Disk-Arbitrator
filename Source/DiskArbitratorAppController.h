//
//  DiskArbitratorAppController.h
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 1/10/10.
//  Copyright 2010 . All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Arbitrator;

@interface AppController : NSObject <NSApplicationDelegate> 
{
    NSWindow *window;
	NSStatusItem *statusItem;
	NSMenu *statusMenu;
	
	NSArrayController *disksArrayController;
	Arbitrator *arbitrator;
	NSArray *sortDescriptors;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSMenu *statusMenu;
@property (assign) IBOutlet NSArrayController *disksArrayController;
@property (copy) NSArray *sortDescriptors;
@property (retain) NSStatusItem *statusItem;
@property (retain) Arbitrator *arbitrator;

- (IBAction)showMainWindow:(id)sender;

@end
