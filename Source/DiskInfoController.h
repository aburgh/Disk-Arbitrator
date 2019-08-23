//
//  DiskInfoController.h
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 2/11/10.
//  Copyright 2010 . All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Disk;

@interface DiskInfoController : NSWindowController 

@property (strong) IBOutlet NSTextView *textView;
@property (strong, nonatomic) Disk *disk;
@property (copy) NSDictionary *diskDescription;
@property (copy) NSAttributedString *diskInfo;

- (void)refreshDiskInfo;

@end
