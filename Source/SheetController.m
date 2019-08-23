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

- (IBAction)alternate:(id)sender
{
	[self.window endEditingFor:nil];
	[NSApp endSheet:self.window returnCode:-1];
}

- (IBAction)cancel:(id)sender
{
	[NSApp endSheet:self.window returnCode:NSModalResponseCancel];
}

- (IBAction)ok:(id)sener
{
	[self.window endEditingFor:nil];
	[NSApp endSheet:self.window returnCode:NSModalResponseOK];
}

@end
