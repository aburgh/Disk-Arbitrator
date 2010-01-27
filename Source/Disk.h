//
//  Disk.h
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 1/10/10.
//  Copyright 2010 . All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <DiskArbitration/DiskArbitration.h>


@interface Disk : NSObject 
{
	DADiskRef disk;
	NSString *BSDName;
	CFDictionaryRef description;
	BOOL mountable;
	BOOL mounted;
	NSImage *icon;
	Disk *parent;
	NSMutableSet *children;
}

@property (copy) NSString *BSDName;
@property CFDictionaryRef description;
@property (readonly) BOOL mountable;
@property (readonly) BOOL mounted;
@property (readonly) BOOL isWholeDisk;
@property (retain) NSImage *icon;
@property (assign) Disk *parent;
@property (retain) NSMutableSet *children;

+ (id)diskWithDiskRef:(DADiskRef)diskRef;

- (id)initWithDiskRef:(DADiskRef)diskRef;

- (void)refreshFromDescription;

@end
