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
	NSString *BSDName;
	NSString *mediaName;
	NSNumber *mediaSize;
}

@property (retain) NSImageCell *iconCell;
@property (retain) NSCell *textCell;
@property CGFloat indentation;
@property (copy) NSString *BSDName;
@property (copy) NSString *mediaName;
@property (copy) NSNumber *mediaSize;

@end
