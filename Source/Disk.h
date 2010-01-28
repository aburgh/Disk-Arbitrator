//
//  Disk.h
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 1/10/10.
//  Copyright 2010 . All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString * const DADiskDidAppearNotification;
extern NSString * const DADiskDidDisappearNotification;
extern NSString * const DADiskDidChangeNotification;


@interface Disk : NSObject 
{
	CFTypeRef disk;
	NSString *BSDName;
	CFDictionaryRef description;
	BOOL mountable;
	BOOL mounted;
	NSImage *icon;
	Disk *parent;
	NSMutableSet *children;
	NSUInteger hash;
}

@property (copy) NSString *BSDName;
@property CFDictionaryRef description;
@property (readonly) BOOL mountable;
@property (readonly) BOOL mounted;
@property (readonly) BOOL isWholeDisk;
@property (retain) NSImage *icon;
@property (assign) Disk *parent;
@property (retain) NSMutableSet *children;

@end
