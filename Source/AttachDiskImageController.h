//
//  AttachDiskImageController.h
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 2/21/10.
//  Copyright 2010 . All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SheetController.h"

@interface AttachDiskImageController : SheetController <NSOpenSavePanelDelegate>
{
	NSView *view;
}

@property (retain) IBOutlet NSView *view;

@end
