//
//  DiskCell.h
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 1/23/10.
//  Copyright 2010 Aaron Burghardt. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface DiskCell : NSTextFieldCell 

@property (retain) NSImageCell *iconCell;
@property (retain) NSCell *textCell;
@property CGFloat indentation;
@property BOOL mountable;
@property BOOL mounted;
@property BOOL isDiskWritable;
@property BOOL isFileSystemWritable;
@property (copy) NSString *BSDName;
@property (copy) NSString *mediaName;
@property (copy) NSNumber *mediaSize;
@property (copy) NSString *volumeName;

@end
