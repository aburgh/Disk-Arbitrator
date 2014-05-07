//
//  AttachDiskImageController.m
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 2/21/10.
//  Copyright 2010 . All rights reserved.
//

#import "AttachDiskImageController.h"
#import <Security/Security.h>
#import <SecurityFoundation/SFAuthorization.h>
#import "AppError.h"

@implementation AttachDiskImageController

@synthesize view;
@synthesize task;
@synthesize title;
@synthesize message;
@synthesize errorMessage;
@synthesize progress;
@synthesize isVerifying;
@synthesize canceled;

+ (NSArray *)diskImageFileExtensions;
{
	static NSArray *diskImageFileExtensions = nil;

	if (!diskImageFileExtensions)
		diskImageFileExtensions = [[NSArray alloc] initWithObjects:@"img", @"dmg", @"sparseimage", @"sparsebundle", @"iso", @"cdr", nil];

	return diskImageFileExtensions;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[stdoutBuffer release];
	[stderrBuffer release];
	[errorMessage release];
	[message release];
	[title	 release];
	[task release];
	[view release];
	[super dealloc];
}

- (NSTask *)hdiutilTaskWithCommand:(NSString *)command path:(NSString *)path options:(NSArray *)options password:(NSString *)password
{
	Log(LOG_DEBUG, @"%s command: %@ path: %@ options: %@", __func__, command, path, options);
	
	NSTask *newTask;
	NSFileHandle *stdinHandle;
	
	newTask = [[NSTask new] autorelease];
	newTask.launchPath = @"/usr/bin/hdiutil";
	
	NSMutableArray *arguments = [NSMutableArray arrayWithObject:command];
	[arguments addObject:path];
	[arguments addObjectsFromArray:options];
	
	newTask.standardOutput = NSPipe.pipe;
	newTask.standardError = NSPipe.pipe;
	newTask.standardInput = NSPipe.pipe;
	
	if (password) {
		stdinHandle = [newTask.standardInput fileHandleForWriting];
		[stdinHandle writeData:[password dataUsingEncoding:NSUTF8StringEncoding]];
		[stdinHandle writeData:[NSData dataWithBytes:"" length:1]];
		
		[arguments addObject:@"-stdinpass"];
	}
	
	newTask.arguments = arguments;

	return newTask;
}

- (BOOL)getDiskImagePropertyList:(id *)outPlist atPath:(NSString *)path command:(NSString *)command password:(NSString *)password error:(NSError **)outError
{
	BOOL retval = YES;
	NSMutableDictionary *info;
	NSString *failureReason;
	NSData *outputData;
	NSTask *newTask;

	NSArray *options = [NSArray arrayWithObjects:@"-plist", nil];
	newTask = [self hdiutilTaskWithCommand:command path:path options:options password:password];
	[newTask launch];
	[newTask waitUntilExit];

	outputData = [[newTask.standardOutput fileHandleForReading] readDataToEndOfFile];

	if (newTask.terminationStatus == 0) {
		*outPlist = [NSPropertyListSerialization propertyListFromData:outputData
													 mutabilityOption:NSPropertyListImmutable
															   format:NULL
													 errorDescription:&failureReason];
		
		if (!*outPlist) {
			Log(LOG_ERR, @"Plist deserialization error: %@", failureReason);
			failureReason = NSLocalizedString(@"hdiutil output is not a property list.", nil);
			retval = NO;
		}
	}
	else {
		Log(LOG_ERR, @"hdiutil termination status: %d", newTask.terminationStatus);
		failureReason = NSLocalizedString(@"hdiutil ended abnormally.", nil); 
		retval = NO;
	}
	
	if (retval == NO && outError) {
		info = [NSMutableDictionary dictionaryWithObjectsAndKeys:
				NSLocalizedString(@"Error executing hdiutil command", nil), NSLocalizedDescriptionKey,
				failureReason, NSLocalizedFailureReasonErrorKey,
				failureReason, NSLocalizedRecoverySuggestionErrorKey,
				nil];
		*outError = [NSError errorWithDomain:AppErrorDomain code:-1 userInfo:info];
	}
	
	return retval;
}

- (BOOL)getDiskImageEncryptionStatus:(BOOL *)outFlag atPath:(NSString *)path error:(NSError **)outError
{
	BOOL isOK = YES;
	NSMutableDictionary *plist;
	id value;
	
	isOK = [self getDiskImagePropertyList:&plist atPath:path command:@"isencrypted" password:nil error:outError];
	if (isOK) {
		value = [plist objectForKey:@"encrypted"];
		if (value) {
			*outFlag = [value boolValue];
		}
		else {
			NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										 NSLocalizedString(@"Failed to get encryption property", nil), NSLocalizedDescriptionKey,
										 NSLocalizedString(@"Check that \"/usr/bin/hdiutil isencrypted\" is functioning correctly.", nil), 
										 NSLocalizedRecoverySuggestionErrorKey,
										 nil];
			if (outError != nil) {
				*outError = [NSError errorWithDomain:AppErrorDomain code:-1 userInfo:info];
			}
			isOK = NO;
		}
	}

	return isOK;
}

- (BOOL)getDiskImageSLAStatus:(BOOL *)outFlag atPath:(NSString *)path password:(NSString *)password error:(NSError **)outError
{
	BOOL isOK = YES;
	NSMutableDictionary *plist;
	
	isOK = [self getDiskImagePropertyList:&plist atPath:path command:@"imageinfo" password:password error:outError];
	if (isOK) {
		id value = [plist valueForKeyPath:@"Properties.Software License Agreement"];
		if (value) {
			*outFlag = [value boolValue];
		}
		else {
			NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										 NSLocalizedString(@"Failed to get SLA property", nil), NSLocalizedDescriptionKey,
										 NSLocalizedString(@"Check that \"/usr/bin/hdiutil imageinfo\" is functioning correctly.", nil),
										 NSLocalizedRecoverySuggestionErrorKey,
										 nil];
			if (outError != nil) {
				*outError = [NSError errorWithDomain:AppErrorDomain code:-1 userInfo:info];
			}
			isOK = NO;
		}
	}
	return isOK;
}

#pragma mark Attaching

- (void)hdiutilAttachDidTerminate:(NSNotification *)notif
{
	[self.window orderOut:self];
	
	NSTask *theTask = notif.object;
	
	if (!canceled && theTask.terminationStatus != 0) {
		
		NSMutableDictionary *info = [NSMutableDictionary dictionary];

		[info setObject:[NSString stringWithFormat:@"%@: %@.", NSLocalizedString(@"Error running hdiutil", nil), self.errorMessage]
				 forKey:NSLocalizedDescriptionKey];

		[info setObject:self.errorMessage
				 forKey:NSLocalizedFailureReasonErrorKey];
		
		[info setObject:NSLocalizedString(@"Check the system log for details.", nil)
				 forKey:NSLocalizedRecoverySuggestionErrorKey];

		Log(LOG_ERR, @"%s termination status: (%d) %@", __func__, theTask.terminationStatus, self.errorMessage);

		NSError *error = [NSError errorWithDomain:AppErrorDomain code:theTask.terminationStatus userInfo:info];
		[NSApp presentError:error];
	}
	self.task = nil;
	[self autorelease];
}

- (NSString *)promptUserForPasswordAtPath:(NSString *)path error:(NSError **)outError
{
	SFAuthorization *authorization;
	AuthorizationRights rights;
	AuthorizationEnvironment env;
	AuthorizationFlags flags;
	AuthorizationItemSet *info;
	OSStatus status;
	NSString *password;
	
	NSString *fileName = path.lastPathComponent;
	NSString *prompt = [NSString stringWithFormat:NSLocalizedString(@"Enter password to access %@", nil), fileName];
	
	AuthorizationItem rightsItems[1] = { { "com.apple.builtin.generic-unlock", 0, NULL, 0 } };
	rights.count = sizeof(rightsItems) / sizeof(AuthorizationItem);;
	rights.items = rightsItems;

	AuthorizationItem envItems[1] = {
		{ kAuthorizationEnvironmentPrompt, strlen([prompt UTF8String]), (void *)[prompt UTF8String], 0 }
//		{ kAuthorizationEnvironmentPassword, 0, NULL, 0 }
	};
	env.count = sizeof(envItems) / sizeof(AuthorizationItem);
	env.items = envItems;

	flags = kAuthorizationFlagDefaults| kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize;
	
	authorization = [SFAuthorization authorization];

	if (![authorization obtainWithRights:&rights flags:flags environment:&env authorizedRights:NULL error:outError])
	{
		if (outError && [*outError code] != errAuthorizationCanceled)
			Log(LOG_ERR, @"Authorization error: %@", *outError);
		return nil;
	}
	
	password = nil;

	status = AuthorizationCopyInfo([authorization authorizationRef], kAuthorizationEnvironmentPassword, &info);
	
	if (status == noErr) {
		if (info->count > 0 && info->items[0].valueLength > 0)
			password = [NSString stringWithUTF8String:info->items[0].value];
	}
	else {
		if (outError) {
			NSDictionary *info;
			info = [NSDictionary dictionaryWithObject:NSLocalizedString(@"Authorization did not return a password.", nil)
											   forKey:NSLocalizedDescriptionKey];
			*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:info];
		}
	}
	
	AuthorizationFreeItemSet(info);

	return password;
}

- (BOOL)attachDiskImageAtPath:(NSString *)path options:(NSArray *)options password:(NSString *)password error:(NSError **)outError
{
	Log(LOG_DEBUG, @"%s path: %@ options: %@", __func__, path, options);
	
	BOOL isEncrypted = NO, hasSLA = NO;
	NSTask *newTask;

	if (!password) {
		if ([self getDiskImageEncryptionStatus:&isEncrypted atPath:path error:outError]) {
			if (isEncrypted) {
				password = [self promptUserForPasswordAtPath:path error:outError];
				if (!password)
					return [*outError code] == errAuthorizationCanceled ? YES : NO;
			}
		}
		else {
			return NO; // get encryption status failed
		}
	}
	
	if ([self getDiskImageSLAStatus:&hasSLA atPath:path password:password error:outError] == NO)
		return NO;
	
	self.title = [NSString stringWithFormat:@"Attaching \"%@\" ...", path.lastPathComponent];
	
	NSMutableArray *arguments = [NSMutableArray array];
	[arguments addObject:@"-plist"];
	[arguments addObject:@"-puppetstrings"];
	[arguments addObjectsFromArray:options];
	
	newTask = [self hdiutilTaskWithCommand:@"attach" path:path options:arguments password:password];

	if (hasSLA) {
		[[newTask.standardInput fileHandleForWriting] writeData:[NSData dataWithBytes:"Y\n" length:3]];
	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(processStandardOutput:)
												 name:NSFileHandleReadCompletionNotification
											   object:[newTask.standardOutput fileHandleForReading]];
	[[newTask.standardOutput fileHandleForReading] readInBackgroundAndNotify];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(processStandardError:)
												 name:NSFileHandleReadCompletionNotification
											   object:[newTask.standardError fileHandleForReading]];
	[[newTask.standardError fileHandleForReading] readInBackgroundAndNotify];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hdiutilAttachDidTerminate:) name:NSTaskDidTerminateNotification object:newTask];
	[newTask launch];
	self.task = newTask;
	[self retain];
	return YES;
}

- (void)attachDiskImageOptionsSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
{
	if (sheet.isSheet)
		[sheet orderOut:self];
	
	NSString *password = nil;
	BOOL isOK;
	NSError *error;
	NSMutableArray *attachOptions = [NSMutableArray array];
	
	if (returnCode == NSOKButton) {
		NSDictionary *options = self.userInfo;
		
		if ([[options objectForKey:@"readOnly"] boolValue] == YES)
			[attachOptions addObject:@"-readonly"];
		
		if ([[options objectForKey:@"noVerify"] boolValue] == YES)
			[attachOptions addObject:@"-noverify"];
		else
			[attachOptions addObject:@"-verify"];
		
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
		
		password = [options objectForKey:@"password"];
		
		isOK = [self attachDiskImageAtPath:[options objectForKey:@"filePath"] options:attachOptions password:password error:&error];
		if (!isOK) [NSApp presentError:error];
	}
}

#pragma mark Actions

- (void)performAttachDiskImageWithPath:(NSString *)path
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	panel.canChooseFiles = YES;
	panel.canChooseDirectories = NO;
	panel.allowsMultipleSelection = NO;
	panel.message = NSLocalizedString(@"Select a disk image to attach:", nil);
	
	panel.allowedFileTypes = [self.class diskImageFileExtensions];
	
	[self.userInfo setObject:[NSNumber numberWithBool:YES] forKey:@"readOnly"];
	
	panel.accessoryView = self.view;
	panel.delegate = self;
	
	NSString *directory = path ? path.stringByDeletingLastPathComponent : nil;
	NSString *filename = path ? path.lastPathComponent : nil;

	// This is a little strange, but left over from an initial implementation which used cascading sheets on
	// the main window.  The code sheetDidEnd code is usable for this variation, though
		 
	if ([panel runModalForDirectory:directory file:filename] == NSOKButton) {
		[self.userInfo setObject:panel.filename forKey:@"filePath"];
		[self attachDiskImageOptionsSheetDidEnd:panel returnCode:NSOKButton contextInfo:self];
	}
}

- (IBAction)performAttachDiskImage:(id)sender
{
	[self performAttachDiskImageWithPath:nil];
}

- (IBAction)cancel:(id)sender
{
	self.canceled = YES;
	[task terminate];
}

- (IBAction)skip:(id)sender
{
}

#pragma mark Delegates

- (void)panelSelectionDidChange:(id)sender
{
	NSString *filename;
	NSFileHandle *handle;
	NSData *header;
	
	Log(LOG_DEBUG, @"%s ", __func__);
	
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

#pragma mark Notification Callbacks

- (NSString *)_parseNextMessage:(NSMutableString **)bufferRef newData:(NSData *)data
{
	NSMutableString **buffer = bufferRef;
	NSString *returnString = nil;
	NSString *newString;

	// If data, append to buffer
	
	if (data && [data length] > 0) {
		newString = [[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding];
		
		if (newString) {
			if (*buffer)
				[*buffer appendString:newString];
			else
				*buffer = [newString mutableCopy];
			[newString release];
		}
	}
	
	// Parse either a plist or a single-line message
	
	NSString *endOfMessage = [*buffer hasPrefix:@"<?xml"] ? @"</plist>\n" : @"\n";
	
	NSRange range = [*buffer rangeOfString:endOfMessage];
	if (range.location != NSNotFound)
	{
		returnString = [*buffer substringToIndex:(range.location + range.length - 1)];
		[*buffer deleteCharactersInRange:NSMakeRange(0, [returnString length] + 1)];
	}

	return returnString;
}

- (void)processStandardOutput:(NSNotification *)notif
{
	Log(LOG_DEBUG, @"%s", __func__);

	NSString *mymessage;
	NSFileHandle *stdoutHandle = notif.object;
	double percentage;
	
//	NSData *data = [stdoutHandle availableData];
	NSData *data = [[notif userInfo] objectForKey:NSFileHandleNotificationDataItem];
	
	while ((mymessage = [self _parseNextMessage:&stdoutBuffer newData:data]))
	{
		data = nil;
		
		if ([mymessage hasPrefix:@"PERCENT:"]) {
			percentage = [[mymessage substringFromIndex:[@"PERCENT:" length]] doubleValue];
			Log(LOG_DEBUG, @"Percent: %f", percentage);
			
			if (percentage > 0.0) {
				if (!self.isVerifying) {
					self.isVerifying = YES;
					[self showWindow:self];
					[NSApp unhide:self];
//					[self.window makeKeyAndOrderFront:self];
				}
				self.progress = percentage;
			}
		}
		
		else if ([mymessage hasPrefix:@"MESSAGE:"]) {
			mymessage = [mymessage substringFromIndex:[@"MESSAGE:" length]];
			Log(LOG_DEBUG, @"Message: %@", mymessage);
			
			self.message = mymessage;
		}
		
		else if ([mymessage hasPrefix:@"hdiutil:"]) {
			mymessage = [mymessage substringFromIndex:[@"hdiutil:" length]];
			// error?
			Log(LOG_ERR, @"Error: %@", mymessage);
		}
		
		else if ([mymessage hasPrefix:@"<?xml"]) {
			Log(LOG_DEBUG, @"Got XML");
			// not used yet
		}

		else {
			Log(LOG_ERR, @"hdiutil stdout: %@", mymessage);
		}
	}
	
	if (self.task && self.task.isRunning)
		[stdoutHandle readInBackgroundAndNotify];
}

- (void)processStandardError:(NSNotification *)notif
{
	Log(LOG_DEBUG, @"%s", __func__);
	
	NSString *mymessage;
	NSFileHandle *stderrHandle = notif.object;
	
//	NSData *data = [stderrHandle availableData];

	NSData *data = [[notif userInfo] objectForKey:NSFileHandleNotificationDataItem];
	
	while ((mymessage = [self _parseNextMessage:&stderrBuffer newData:data]))
	{
		data = nil;
		
		if ([mymessage hasPrefix:@"hdiutil:"])
			mymessage = [mymessage substringFromIndex:[@"hdiutil:" length]];
		
		Log(LOG_ERR, @"Error: %@", mymessage);
		self.errorMessage = mymessage;
	}
	
	if (self.task && self.task.isRunning)
		[stderrHandle readInBackgroundAndNotify];
}

@end
