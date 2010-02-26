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

+ (NSArray *)diskImageFileExtensions;

- (void)attachDiskImageAtPath:(NSString *)path options:(NSArray *)options password:(NSString *)password;

- (void)attachDiskImageOptionsSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;

- (IBAction)performAttachDiskImage:(id)sender;

- (void)attachDiskImageOptionsSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;


- (void)panelSelectionDidChange:(id)sender;

@end
