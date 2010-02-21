//
//  AttachDiskImageController.m
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 2/21/10.
//  Copyright 2010 . All rights reserved.
//

#import "AttachDiskImageController.h"
#import "AppError.h"

@implementation AttachDiskImageController

@synthesize view;

- (void)panelSelectionDidChange:(id)sender
{
	NSString *filename;
	NSFileHandle *handle;
	NSData *header;
	
	Log(LOG_DEBUG, @"%s ", __FUNCTION__);

	filename = [sender filename];

	if (!filename)
		filename = [[sender directory] stringByAppendingPathComponent:@"token"]; // SparseBundle

	Log(LOG_DEBUG, @"filename: %@\n", filename);
	
	handle = [NSFileHandle fileHandleForReadingAtPath:filename];
	
	if (handle) {
		
		header = [handle readDataOfLength:8];
		[handle closeFile];
		
		// This check only works for Version 2 encrypted disk images, the default in Tiger and beyond
		// We check only to remind the user if a password is needed, so do not need to catch every case.
		//
		// http://lorenzo.yellowspace.net/corrupt-sparseimage.html
		//
		
		if (header && [header length] == 8) {
			
			if (memcmp("encrcdsa", [header bytes], 8) == 0)
				[self.userInfo setObject:[NSNumber numberWithBool:YES] forKey:@"needPassword"];
			else
				[self.userInfo setObject:[NSNumber numberWithBool:NO] forKey:@"needPassword"];
		}
	}
	else {
		[self.userInfo setObject:[NSNumber numberWithBool:NO] forKey:@"needPassword"];
	}
}

@end
