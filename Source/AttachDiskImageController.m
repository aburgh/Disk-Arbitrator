//
//  AttachDiskImageController.m
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 2/21/10.
//  Copyright 2010 . All rights reserved.
//

#import "AttachDiskImageController.h"
#import "AppError.h"

@implementation AttachDiskImageController

@synthesize view;

+ (NSArray *)diskImageFileExtensions;
{
	static NSArray *diskImageFileExtensions = nil;

	if (!diskImageFileExtensions)
		diskImageFileExtensions = [[NSArray alloc] initWithObjects:@"img", @"dmg", @"sparseimage", @"sparsebundle", @"iso", @"cdr", nil];

	return diskImageFileExtensions;
}

- (void)dealloc
{
	[view release];
	[super dealloc];
}

- (BOOL)getDiskImageEncryptionStatus:(BOOL *)outFlag atPath:(NSString *)path error:(NSError **)outError
{
	// hdiutil isencrypted -plist

	BOOL retval = YES;
	NSDictionary *info;
	NSString *failureReason;
	NSData *outputData;
	NSPipe *outPipe = [NSPipe pipe];
	NSTask *task = [NSTask new];

	[task setLaunchPath:@"/usr/bin/hdiutil"];
	[task setArguments:[NSArray arrayWithObjects:@"isencrypted", @"-plist", path, nil]];
	[task setStandardOutput:outPipe];
	[task launch];
	[task waitUntilExit];

	outputData = [[outPipe fileHandleForReading] readDataToEndOfFile];

	if ([task terminationStatus] == 0) {
		info = [NSPropertyListSerialization propertyListFromData:outputData
												mutabilityOption:NSPropertyListImmutable
														  format:NULL
												errorDescription:&failureReason];

		if (info && [info objectForKey:@"encrypted"]) {
			*outFlag = [[info objectForKey:@"encrypted"] boolValue];
		}
		else {
			failureReason = NSLocalizedString(@"Invalid output from hdiutil.", nil);
			retval = NO;
		}
	}
	else {
		failureReason = NSLocalizedString(@"Executing \"hdiutil isencrypted file\" failed.", nil); 
		retval = NO;
	}
	
	if (retval == NO) {
		info = [NSDictionary dictionaryWithObjectsAndKeys:
				NSLocalizedString(@"Failed to get encryption status of disk image", nil), NSLocalizedDescriptionKey,
				failureReason, NSLocalizedFailureReasonErrorKey,
				nil];
		*outError = [NSError errorWithDomain:AppErrorDomain code:-1 userInfo:info];
	}
	[task release];
	
	return retval;
}

- (void)hdiutilAttachDidTerminate:(NSNotification *)notif
{
	NSTask *task = [notif object];
	
	if ([task terminationStatus] != 0) {
		
		NSMutableDictionary *info = [NSMutableDictionary dictionary];
		[info setObject:NSLocalizedString(@"Failed to attach disk image", nil)
				 forKey:NSLocalizedDescriptionKey];
		[info setObject:[NSString stringWithFormat:@"%@ %d", NSLocalizedString(@"Error code", nil), [task terminationStatus]]
				 forKey:NSLocalizedFailureReasonErrorKey];
		
		NSError *error = [NSError errorWithDomain:AppErrorDomain code:[task terminationStatus] userInfo:info];
		[NSApp presentError:error];
	}
}

- (void)attachDiskImageAtPath:(NSString *)path options:(NSArray *)options password:(NSString *)password
{
	NSTask *task;
	NSPipe *stdinPipe;
	NSFileHandle *stdinHandle;
	NSMutableArray *arguments = [NSMutableArray arrayWithObject:@"attach"];
	
	[arguments addObject:path];
	[arguments addObjectsFromArray:options];
	
	task = [[NSTask new] autorelease];
	[task setLaunchPath:@"/usr/bin/hdiutil"];
	
	if (password) {
		stdinPipe = [NSPipe pipe];
		[task setStandardInput:stdinPipe];
		stdinHandle = [stdinPipe fileHandleForWriting];
		[stdinHandle writeData:[password dataUsingEncoding:NSUTF8StringEncoding]];
		[stdinHandle writeData:[NSData dataWithBytes:"" length:1]];
		
		[arguments addObject:@"-stdinpass"];
	}
	
	[task setArguments:arguments];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hdiutilAttachDidTerminate:) name:NSTaskDidTerminateNotification object:task];
	[task launch];
}

- (void)attachDiskImageOptionsSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
{
	if ([sheet isSheet])
		[sheet orderOut:self];
	
	NSString *password = nil;
	
	NSMutableArray *attachOptions = [NSMutableArray array];
	
	if (returnCode == NSOKButton) {
		NSDictionary *options = self.userInfo;
		
		if ([[options objectForKey:@"readOnly"] boolValue] == YES)
			[attachOptions addObject:@"-readonly"];
		
		if ([[options objectForKey:@"noVerify"] boolValue] == YES)
			[attachOptions addObject:@"-noverify"];
		
		if ([[options objectForKey:@"attemptMount"] boolValue] == YES)
		{
			[attachOptions addObject:@"-mount"];
			[attachOptions addObject:@"optional"];
			
			if ([[options objectForKey:@"noOwners"] boolValue] == YES) {
				[attachOptions addObject:@"-owners"];
				[attachOptions addObject:@"off"];
			}
			
			if ([[options objectForKey:@"noBrowse"] boolValue] == YES)
				[attachOptions addObject:@"-nobrowse"];
			
			NSString *rootPath = [options objectForKey:@"rootPath"];
			if (rootPath && [rootPath length]) {
				[attachOptions addObject:@"-mountroot"];
				[attachOptions addObject:rootPath];
			}
		}
		else {
			[attachOptions addObject:@"-nomount"];
		}
		
		[attachOptions addObject:@"-drivekey"];
		[attachOptions addObject:@"disk_arbitrator=1"];
		
		password = [options objectForKey:@"password"];
		
		[self attachDiskImageAtPath:[options objectForKey:@"filePath"] options:attachOptions password:password];
	}
}

//- (void)_beginSheetAttachDiskImageOptionsWithPath:(NSString *)filePath needPassword:(BOOL)needPassword
//{
//	SheetController *controller = [[[SheetController alloc] initWithWindowNibName:@"AttachDiskImageOptions"] autorelease];
//	[controller window]; // triggers controller to load the NIB
//	
//	[[controller userInfo] setObject:[NSNumber numberWithBool:YES] forKey:@"readOnly"];
//	[[controller userInfo] setObject:[NSNumber numberWithBool:needPassword] forKey:@"needPassword"];
//	[[controller userInfo] setObject:filePath forKey:@"filePath"];
//	
//	[window makeKeyAndOrderFront:self];
//	
//	[NSApp beginSheet:[controller window]
//	   modalForWindow:window
//		modalDelegate:self
//	   didEndSelector:@selector(attachDiskImageOptionsSheetDidEnd:returnCode:contextInfo:)
//		  contextInfo:controller];
//}

//- (void)attachDiskImagePanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
//{
//	NSError *error;
//	BOOL isEncrypted;
//	NSArray *options;
//	
//	if (returnCode == NSOKButton) {
//		
//		if ([self getDiskImageEncryptionStatus:&isEncrypted atPath:[panel filename] error:&error]) {
//			// got encryption status
//
//			if (isEncrypted) {
//				[panel orderOut:self];
//				[self _beginSheetAttachDiskImageOptionsWithPath:[panel filename] needPassword:YES];
//			}
//			else {
//				options = [NSArray arrayWithObjects:@"-nomount", @"-readonly", @"-drivekey", @"disk_arbitrator=1", nil];
//				
//				[self _attachDiskImageAtPath:[panel filename] options:options password:nil];
//			}
//		}
//		else {
//			// failed to get encryption status
//			
//			[NSApp presentError:error modalForWindow:window delegate:nil didPresentSelector:NULL contextInfo:NULL];
//		}
//	}
//}

- (IBAction)performAttachDiskImage:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setCanChooseFiles:YES];
	[panel setCanChooseDirectories:NO];
	[panel setAllowsMultipleSelection:NO];
	[panel setMessage:NSLocalizedString(@"Select a disk image to attach:", nil)];
	
	[panel setAllowedFileTypes:[[self class] diskImageFileExtensions]];
	
	[self.userInfo setObject:[NSNumber numberWithBool:YES] forKey:@"readOnly"];
	
	[panel setAccessoryView:self.view];
	[panel setDelegate:self];
	
	// This is a little strange, but left over from an initial implementation which used cascading sheets on
	// the main window.  The code sheetDidEnd code is usable for this variation, though
	
	if ([panel runModal] == NSOKButton) {
		[self.userInfo setObject:[panel filename] forKey:@"filePath"];
		[self attachDiskImageOptionsSheetDidEnd:panel returnCode:NSOKButton contextInfo:self];
	}
}

- (void)panelSelectionDidChange:(id)sender
{
	NSString *filename;
	NSFileHandle *handle;
	NSData *header;
	
	Log(LOG_DEBUG, @"%s ", __FUNCTION__);
	
	filename = [sender filename];
	
	if (!filename)
		filename = [[sender directory] stringByAppendingPathComponent:@"token"]; // SparseBundle
	
	Log(LOG_DEBUG, @"filename: %@\n", filename);
	
	handle = [NSFileHandle fileHandleForReadingAtPath:filename];
	
	if (handle) {
		
		header = [handle readDataOfLength:8];
		[handle closeFile];
		
		// This check only works for Version 2 encrypted disk images, the default in Tiger and beyond
		// We check only to remind the user if a password is needed, so do not need to catch every case.
		//
		// http://lorenzo.yellowspace.net/corrupt-sparseimage.html
		//
		
		if (header && [header length] == 8) {
			
			if (memcmp("encrcdsa", [header bytes], 8) == 0)
				[self.userInfo setObject:[NSNumber numberWithBool:YES] forKey:@"needPassword"];
			else
				[self.userInfo setObject:[NSNumber numberWithBool:NO] forKey:@"needPassword"];
		}
	}
	else {
		[self.userInfo setObject:[NSNumber numberWithBool:NO] forKey:@"needPassword"];
	}
}


@end
