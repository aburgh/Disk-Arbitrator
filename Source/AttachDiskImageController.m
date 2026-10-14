//
//  AttachDiskImageController.m
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 2/21/10.
//  Copyright 2010 . All rights reserved.
//

#import "AttachDiskImageController.h"
#import "AppError.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

////////////////////////////////////////////////////////////////////////////////

@interface AttachDiskImageController ()
{
	NSMutableString *stdoutBuffer;
	NSMutableString *stderrBuffer;
}

@end

////////////////////////////////////////////////////////////////////////////////

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

+ (NSArray *)diskImageContentTypes
{
	static NSArray *contentTypes = nil;
	if (contentTypes)
		return contentTypes;

	NSMutableArray *types = [NSMutableArray array];
	NSArray *identifiers = [NSArray arrayWithObjects:
		@"public.disk-image",
		@"com.apple.disk-image-udif",
		@"com.apple.disk-image-sparse",
		@"com.apple.disk-image-sparse-bundle",
		@"public.iso-image",
		nil];
	for (NSString *identifier in identifiers) {
		UTType *type = [UTType typeWithIdentifier:identifier];
		if (type)
			[types addObject:type];
	}
	for (NSString *extension in [self diskImageFileExtensions]) {
		UTType *type = [UTType typeWithFilenameExtension:extension];
		if (type && [types containsObject:type] == NO)
			[types addObject:type];
	}
	contentTypes = [types copy];
	return contentTypes;
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
	newTask.executableURL = [NSURL fileURLWithPath:@"/usr/bin/hdiutil"];
	
	NSMutableArray *arguments = [NSMutableArray arrayWithObject:command];
	[arguments addObject:path];
	[arguments addObjectsFromArray:options];
	
	newTask.standardOutput = NSPipe.pipe;
	newTask.standardError = NSPipe.pipe;
	newTask.standardInput = NSPipe.pipe;
	
	if (password) {
		stdinHandle = [newTask.standardInput fileHandleForWriting];
		// hdiutil -stdinpass reads a NUL-terminated passphrase.
		NSMutableData *secret = [NSMutableData dataWithData:[password dataUsingEncoding:NSUTF8StringEncoding]];
		[secret appendBytes:"" length:1];
		[stdinHandle writeData:secret error:NULL];
		
		[arguments addObject:@"-stdinpass"];
	}
	
	newTask.arguments = arguments;

	return newTask;
}

- (BOOL)getDiskImagePropertyList:(id *)outPlist atPath:(NSString *)path command:(NSString *)command password:(NSString *)password error:(NSError **)outError
{
	BOOL retval = YES;
	NSMutableDictionary *info;
	NSString *failureReason = nil;
	NSData *outputData;
	NSTask *newTask;

	NSArray *options = [NSArray arrayWithObjects:@"-plist", nil];
	newTask = [self hdiutilTaskWithCommand:command path:path options:options password:password];
	[[newTask.standardInput fileHandleForWriting] closeAndReturnError:NULL];
	NSError *launchError = nil;
	if (![newTask launchAndReturnError:&launchError]) {
		Log(LOG_ERR, @"hdiutil failed to launch: %@", launchError);
		failureReason = launchError.localizedDescription ?: NSLocalizedString(@"hdiutil failed to launch.", nil);
		retval = NO;
		outputData = nil;
	}
	else {
		[newTask waitUntilExit];
		outputData = [[newTask.standardOutput fileHandleForReading] readDataToEndOfFileAndReturnError:NULL];
	}

	if (retval && newTask.terminationStatus == 0 && outputData) {
        NSError *plistErr = nil;
        *outPlist = [NSPropertyListSerialization propertyListWithData:outputData options:NSPropertyListImmutable format:nil error:&plistErr];
        if (plistErr) {
            failureReason = plistErr.localizedDescription;
        }
		if (!*outPlist) {
			Log(LOG_ERR, @"Plist deserialization error: %@", failureReason);
			failureReason = NSLocalizedString(@"hdiutil output is not a property list.", nil);
			retval = NO;
		}
	}
	else if (retval) {
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
	[theTask.standardOutput fileHandleForReading].readabilityHandler = nil;
	[theTask.standardError fileHandleForReading].readabilityHandler = nil;
	
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
	// AuthorizationCopyInfo(kAuthorizationEnvironmentPassword) no longer returns the
	// password the user typed. Ask with a secure field instead.
	NSString *fileName = path.lastPathComponent;
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = NSLocalizedString(@"Disk Image Password", nil);
	alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"Enter the password to access %@.", nil), fileName];
	[alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];

	NSSecureTextField *field = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, 0, 280, 24)];
	alert.accessoryView = field;
	ActivateDiskArbitratorApp();
	NSModalResponse response = [alert runModal];
	NSString *password = [field.stringValue copy];
	[field release];
	[alert release];

	if (response != NSAlertFirstButtonReturn || password.length == 0) {
		[password release];
		if (outError) {
			NSDictionary *info = [NSDictionary dictionaryWithObject:NSLocalizedString(@"Password entry was canceled.", nil)
			                                                 forKey:NSLocalizedDescriptionKey];
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:info];
		}
		return nil;
	}

	return [password autorelease];
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
					return (outError && *outError && [*outError code] == NSUserCancelledError) ? YES : NO;
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

	if (hasSLA)
		[[newTask.standardInput fileHandleForWriting] writeData:[NSData dataWithBytes:"Y\n" length:3] error:NULL];
	[[newTask.standardInput fileHandleForWriting] closeAndReturnError:NULL];

	NSFileHandle *stdoutHandle = [newTask.standardOutput fileHandleForReading];
	NSFileHandle *stderrHandle = [newTask.standardError fileHandleForReading];
	stdoutHandle.readabilityHandler = ^(NSFileHandle *handle) {
		NSData *data = [handle readDataUpToLength:64 * 1024 error:NULL];
		dispatch_async(dispatch_get_main_queue(), ^{
			[self consumeStandardOutput:data];
			if (data.length == 0)
				handle.readabilityHandler = nil;
		});
	};
	stderrHandle.readabilityHandler = ^(NSFileHandle *handle) {
		NSData *data = [handle readDataUpToLength:64 * 1024 error:NULL];
		dispatch_async(dispatch_get_main_queue(), ^{
			[self consumeStandardError:data];
			if (data.length == 0)
				handle.readabilityHandler = nil;
		});
	};

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hdiutilAttachDidTerminate:) name:NSTaskDidTerminateNotification object:newTask];
	NSError *launchError = nil;
	if (![newTask launchAndReturnError:&launchError]) {
		stdoutHandle.readabilityHandler = nil;
		stderrHandle.readabilityHandler = nil;
		if (outError)
			*outError = launchError;
		return NO;
	}
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
	
	if (returnCode == NSModalResponseOK) {
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

- (void)performAttachDiskImage
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	panel.canChooseFiles = YES;
	panel.canChooseDirectories = NO;
	panel.allowsMultipleSelection = NO;
	panel.message = NSLocalizedString(@"Select a disk image to attach:", nil);
	
	panel.allowedContentTypes = [self.class diskImageContentTypes];
	
	[self.userInfo setObject:[NSNumber numberWithBool:YES] forKey:@"readOnly"];
	
	panel.accessoryView = self.view;
	panel.delegate = self;
	
	// This is a little strange, but left over from an initial implementation which used cascading sheets on
	// the main window.  The code sheetDidEnd code is usable for this variation, though
		 
	if ([panel runModal] == NSModalResponseOK) {
		[self.userInfo setObject:panel.URL.path forKey:@"filePath"];
		[self attachDiskImageOptionsSheetDidEnd:panel returnCode:NSModalResponseOK contextInfo:self];
	}
}

- (IBAction)performAttachDiskImage:(id)sender
{
	[self performAttachDiskImage];
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
	
	NSOpenPanel *panel = sender;
	NSURL *selectedURL = panel.URL;
	filename = selectedURL.path;
	
	BOOL isDirectory = NO;
	if (filename && [[NSFileManager defaultManager] fileExistsAtPath:filename isDirectory:&isDirectory] && isDirectory) {
		filename = [filename stringByAppendingPathComponent:@"token"]; // SparseBundle
	}
	
	Log(LOG_DEBUG, @"filename: %@\n", filename);
	
	handle = [NSFileHandle fileHandleForReadingAtPath:filename];
	
	if (handle) {
		
		header = [handle readDataUpToLength:8 error:NULL];
		[handle closeAndReturnError:NULL];
		
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

- (void)consumeStandardOutput:(NSData *)data
{
	Log(LOG_DEBUG, @"%s", __func__);

	NSString *mymessage;
	double percentage;
	
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
}

- (void)consumeStandardError:(NSData *)data
{
	Log(LOG_DEBUG, @"%s", __func__);
	
	NSString *mymessage;
	
	while ((mymessage = [self _parseNextMessage:&stderrBuffer newData:data]))
	{
		data = nil;
		
		if ([mymessage hasPrefix:@"hdiutil:"])
			mymessage = [mymessage substringFromIndex:[@"hdiutil:" length]];
		
		Log(LOG_ERR, @"Error: %@", mymessage);
		self.errorMessage = mymessage;
	}
}

@end
