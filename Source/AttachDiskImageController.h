//
//  AttachDiskImageController.h
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 2/21/10.
//  Copyright 2010 . All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SheetController.h"

@interface AttachDiskImageController : SheetController <NSOpenSavePanelDelegate>
{
	NSView *view;
	NSTask *task;
	NSString *title;
	NSString *message;
	NSString *errorMessage;
	double progress;
	BOOL isVerifying;
	BOOL canceled;
@private
	NSMutableString *stdoutBuffer;
	NSMutableString *stderrBuffer;
}

@property (retain) IBOutlet NSView *view;
@property (retain) NSTask *task;
@property (copy) NSString *title;
@property (copy) NSString *message;
@property (copy) NSString *errorMessage;
@property double progress;
@property BOOL isVerifying;
@property BOOL canceled;

+ (NSArray *)diskImageFileExtensions;

- (NSTask *)hdiutilTaskWithCommand:(NSString *)command path:(NSString *)path options:(NSArray *)options password:(NSString *)password;

- (BOOL)getDiskImagePropertyList:(id *)outPlist atPath:(NSString *)path command:(NSString *)command password:(NSString *)password error:(NSError **)outError;

- (BOOL)getDiskImageEncryptionStatus:(BOOL *)outFlag atPath:(NSString *)path error:(NSError **)outError;

- (BOOL)getDiskImageSLAStatus:(BOOL *)outFlag atPath:(NSString *)path password:(NSString *)password error:(NSError **)outError;

- (BOOL)attachDiskImageAtPath:(NSString *)path options:(NSArray *)options password:(NSString *)password error:(NSError **)error;

- (void)attachDiskImageOptionsSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;

- (void)performAttachDiskImageWithPath:(NSString *)path;

- (IBAction)performAttachDiskImage:(id)sender;

- (IBAction)cancel:(id)sender;

- (IBAction)skip:(id)sender;

#pragma mark Delegates

- (void)panelSelectionDidChange:(id)sender;

@end
