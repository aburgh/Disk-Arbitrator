//
//  SheetController.h
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 2/10/10.
//  Copyright 2010 . All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SheetController : NSWindowController 
{
	NSMutableDictionary *userInfo;
}

@property (retain) NSMutableDictionary *userInfo;

- (IBAction)alternate:(id)sender;
- (IBAction)cancel:(id)sender;
- (IBAction)ok:(id)sener;

@end
