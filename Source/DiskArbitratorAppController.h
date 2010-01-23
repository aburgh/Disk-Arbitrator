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
	Arbitrator *arbitrator;
	NSArray *sortDescriptors;
}

@property (assign) IBOutlet NSWindow *window;
@property (retain) NSStatusItem *statusItem;
@property (assign) IBOutlet NSMenu *statusMenu;
@property (retain) Arbitrator *arbitrator;
@property (copy) NSArray *sortDescriptors;

- (IBAction)showMainWindow:(id)sender;

#pragma mark TableView Delegates

@end
