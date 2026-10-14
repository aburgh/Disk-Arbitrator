//
//  SheetController.m
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 2/10/10.
//  Copyright 2010 . All rights reserved.
//

#import "SheetController.h"


@implementation SheetController

@synthesize userInfo;

- (void)windowWillLoad
{
	self.userInfo = [NSMutableDictionary dictionary];
}

- (void)endWithReturnCode:(NSModalResponse)returnCode
{
	[self.window endEditingFor:nil];
	NSWindow *parent = self.window.sheetParent;
	if (parent)
		[parent endSheet:self.window returnCode:returnCode];
	else
		[NSApp stopModalWithCode:returnCode];
}

- (IBAction)alternate:(id)sender
{
	[self endWithReturnCode:-1];
}

- (IBAction)cancel:(id)sender
{
	[self endWithReturnCode:NSModalResponseCancel];
}

- (IBAction)ok:(id)sender
{
	[self endWithReturnCode:NSModalResponseOK];
}

@end
