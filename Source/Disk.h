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
	NSString *BSDName;
	CFDictionaryRef description;
	BOOL mounted;
	NSImage *icon;
	NSMutableArray *children;
}

@property (copy) NSString *BSDName;
@property CFDictionaryRef description;
@property (readonly) BOOL mounted;
@property (readonly) BOOL isWholeDisk;
@property (retain) NSImage *icon;
@property (retain) NSMutableArray *children;

+ (id)diskWithDiskRef:(DADiskRef)diskRef;

- (id)initWithDiskRef:(DADiskRef)diskRef;

- (void)refreshFromDescription;

@end
