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
	NSString *errorMessage;
@private
	NSMutableString *stdoutBuffer;
	NSMutableString *stderrBuffer;
}

@property (retain) IBOutlet NSView *view;
@property (retain) NSTask *task;
@property (copy) NSString *errorMessage;

+ (NSArray *)diskImageFileExtensions;

- (NSTask *)hdiutilTaskWithCommand:(NSString *)command path:(NSString *)path options:(NSArray *)options password:(NSString *)password;

- (BOOL)getDiskImagePropertyList:(id *)outPlist atPath:(NSString *)path command:(NSString *)command password:(NSString *)password error:(NSError **)outError;

- (BOOL)getDiskImageEncryptionStatus:(BOOL *)outFlag atPath:(NSString *)path error:(NSError **)outError;

- (BOOL)getDiskImageSLAStatus:(BOOL *)outFlag atPath:(NSString *)path password:(NSString *)password error:(NSError **)outError;

- (BOOL)attachDiskImageAtPath:(NSString *)path options:(NSArray *)options password:(NSString *)password error:(NSError **)error;

- (void)attachDiskImageOptionsSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;

- (IBAction)performAttachDiskImage:(id)sender;

- (void)attachDiskImageOptionsSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;

#pragma mark Delegates

- (void)panelSelectionDidChange:(id)sender;

@end
