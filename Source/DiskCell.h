//
//  DiskCell.h
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 1/23/10.
//  Copyright 2010 . All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface DiskCell : NSCell 
{
	NSImageCell *iconCell;
	NSCell *textCell;
	CGFloat indentation;
	BOOL mountable;
	BOOL mounted;
	NSString *BSDName;
	NSString *mediaName;
	NSNumber *mediaSize;
	NSString *volumeName;
}

@property (retain) NSImageCell *iconCell;
@property (retain) NSCell *textCell;
@property CGFloat indentation;
@property BOOL mountable;
@property BOOL mounted;
@property (copy) NSString *BSDName;
@property (copy) NSString *mediaName;
@property (copy) NSNumber *mediaSize;
@property (copy) NSString *volumeName;

@end
