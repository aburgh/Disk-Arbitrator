//
//  DiskArbitratorAppController.m
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 1/10/10.
//  Copyright 2010 Aaron Burghardt. All rights reserved.
//

#import "DiskArbitratorAppController.h"
#import "DiskArbitratorAppController+Toolbar.h"
#import "AppError.h"
#import "Arbitrator.h"
#import "Disk.h"
#import "SheetController.h"
#import "DiskInfoController.h"
#import "AttachDiskImageController.h"


@implementation AppController

@synthesize window;
@synthesize statusMenu;
@synthesize tableView;
@synthesize disksArrayController;
@synthesize sortDescriptors;
@synthesize statusItem;
@synthesize arbitrator;
@synthesize hasUserLaunchAgent;
@synthesize hasSystemLaunchAgent;
@synthesize installUserLaunchAgentMenuTitle;

- (void)dealloc
{
	if (arbitrator.isActivated)
		[arbitrator deactivate];
	[arbitrator release];
	[sortDescriptors release];
	[statusItem release];
	[displayErrorQueue release];
	[super dealloc];
}

- (void)setStatusItemIconWithName:(NSString *)name
{
	NSString *iconPath = [[NSBundle mainBundle] pathForResource:name ofType:@"png"];
	NSImage *statusIcon = [[NSImage alloc] initWithContentsOfFile:iconPath];
	statusItem.image = statusIcon;
	[statusIcon release];
}

- (void)refreshStatusItemIcon
{
	if (arbitrator.isActivated == NO)
		[self setStatusItemIconWithName:@"StatusItem Disabled 1"];
	
	else if (arbitrator.mountMode == MM_BLOCK)
		[self setStatusItemIconWithName:@"StatusItem Green"];

	else if (arbitrator.mountMode == MM_READONLY)
		[self setStatusItemIconWithName:@"StatusItem Orange"];
	
	else
		NSAssert1(NO, @"Invalid mount mode: %ld\n", (long)arbitrator.mountMode);
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	[self refreshLaunchAgentStatus];
	
	NSMutableDictionary *defaults = [NSMutableDictionary dictionary];
	[defaults setObject:[NSNumber numberWithInt:LOG_INFO] forKey:AppLogLevelDefaultsKey];
	[defaults setObject:[NSNumber numberWithBool:YES]     forKey:@"ShowMainWindowAtStartup"];
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
	
	displayErrorQueue = [NSMutableArray new];
	
	NSStatusBar *bar = [NSStatusBar systemStatusBar];
	self.statusItem = [bar statusItemWithLength:NSSquareStatusItemLength];
    NSImage *altImage = [[[NSImage imageNamed:@"StatusItem Disabled 1.png"] copy] autorelease];
    [altImage setTemplate:YES];
    self.statusItem.alternateImage = altImage;
    [self.statusItem setHighlightMode:YES];
	[self setStatusItemIconWithName:@"StatusItem Disabled 1"];
	statusItem.menu = statusMenu;
	
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(diskDidChange:) name:DADiskDidChangeNotification object:nil];
	[center addObserver:self selector:@selector(didAttemptEject:) name:DADiskDidAttemptEjectNotification object:nil];
	[center addObserver:self selector:@selector(didAttemptMount:) name:DADiskDidAttemptMountNotification object:nil];
	[center addObserver:self selector:@selector(didAttemptUnmount:) name:DADiskDidAttemptUnmountNotification object:nil];
	
	self.arbitrator = [[Arbitrator new] autorelease];
	[arbitrator addObserver:self forKeyPath:@"isActivated" options:0 context:NULL];
	[arbitrator addObserver:self forKeyPath:@"mountMode" options:0 context:NULL];
	[self refreshStatusItemIcon];  // arbitrator status initial state is taken from user defaults, which was initialized before KVO initialized
	[arbitrator release];
	
	self.sortDescriptors = [NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:@"BSDName" ascending:YES] autorelease]];
	
	SetupToolbar(window, self);
	window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces;
	window.worksWhenModal = YES;
	
	[tableView registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowMainWindowAtStartup"])
		[window makeKeyAndOrderFront:self];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (object == arbitrator)
		if ([keyPath isEqual:@"isActivated"] || [keyPath isEqual:@"mountMode"])
			[self refreshStatusItemIcon];
}

- (IBAction)showAboutPanel:(id)sender
{
	[NSApp orderFrontStandardAboutPanel:sender];
	[NSApp activateIgnoringOtherApps:YES];
}

- (IBAction)showMainWindow:(id)sender
{
	[window makeKeyAndOrderFront:sender];
	[NSApp activateIgnoringOtherApps:YES];
}

- (IBAction)showPreferences:(id)sender
{
	static NSWindowController *controller = nil;

	if (!controller)
		controller = [[NSWindowController alloc] initWithWindowNibName:@"Preferences"];

	[controller.window makeKeyAndOrderFront:self];
	[NSApp activateIgnoringOtherApps:YES];
}

- (IBAction)performActivation:(id)sender
{
	[arbitrator activate];
}

- (IBAction)performDeactivation:(id)sender
{
	[arbitrator deactivate];
}

- (IBAction)toggleActivation:(id)sender
{
	if (arbitrator.isActivated)
		[self performDeactivation:sender];
	else
		[self performActivation:sender];
}

- (IBAction)performSetMountBlockMode:(id)sender
{
	arbitrator.mountMode = MM_BLOCK;
}

- (IBAction)performSetMountReadOnlyMode:(id)sender
{
	arbitrator.mountMode = MM_READONLY;
}

- (void)performMountSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
{
	SheetController *controller = (SheetController *)contextInfo;
	[sheet orderOut:self];
	
	Disk *selectedDisk = self.selectedDisk;
	NSMutableArray *arguments = [NSMutableArray array];
	
	if (returnCode == NSOKButton) {
		NSDictionary *options = controller.userInfo;
		
		if ([[options objectForKey:@"readOnly"] boolValue] == YES)
			[arguments addObject:@"rdonly"];

		if ([[options objectForKey:@"noOwners"] boolValue] == YES)
			[arguments addObject:@"noowners"];

		if ([[options objectForKey:@"noBrowse"] boolValue] == YES)
			[arguments addObject:@"nobrowse"];

		if ([[options objectForKey:@"ignoreJournal"] boolValue] == YES)
			[arguments addObject:@"-j"];

		NSString *path = [options objectForKey:@"path"];
		
		[selectedDisk mountAtPath:path withArguments:arguments];
	}
	[controller release];
}

- (IBAction)performMount:(id)sender
{
	Disk *selectedDisk = self.selectedDisk;

	NSAssert(selectedDisk, @"No disk selected.");
	NSAssert(selectedDisk.isMounted == NO, @"Disk is already mounted.");

	SheetController *controller = [[SheetController alloc] initWithWindowNibName:@"MountOptions"];
	[controller window]; // triggers controller to load the NIB
	
	[[controller userInfo] setObject:[NSNumber numberWithBool:YES] forKey:@"readOnly"];
	[[controller userInfo] setObject:[NSNumber numberWithBool:YES] forKey:@"ignoreJournal"];
	
	[window makeKeyAndOrderFront:self];
	
	[NSApp beginSheet:controller.window
	   modalForWindow:window
		modalDelegate:self
	   didEndSelector:@selector(performMountSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:controller];
}

- (IBAction)performUnmount:(id)sender
{
	Disk *theDisk = self.selectedDisk;
	
	if (!theDisk) return;
	
	[theDisk unmountWithOptions: theDisk.isWholeDisk ?  kDiskUnmountOptionWhole : kDiskUnmountOptionDefault];
}

- (IBAction)performMountOrUnmount:(id)sender
{
	Disk *theDisk = self.selectedDisk;
	
	if (theDisk.isMounted)
		[self performUnmount:sender];
	else
		[self performMount:sender];
}

- (void)_childDidAttemptUnmountBeforeEject:(NSNotification *)notif
{
	Disk *disk = notif.object;

	// Disk may be a mountable whole disk that we were waiting on, so the parent may be the disk itself
	
	Disk *parent = disk.isWholeDisk ? disk : disk.parent;
	
	Log(LOG_DEBUG, @"%s disk: %@ child: %@", __func__, parent, disk);
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:DADiskDidAttemptUnmountNotification object:disk];
	
	// Confirm the child unmounted
	
	if (disk.isMounted) {
		// Unmount of child failed
		
		NSMutableDictionary *info = [[[notif userInfo] mutableCopy] autorelease];
		
		Log(LOG_INFO, @"%s eject disk: %@ canceled due to mounted child: %@", __func__, disk, info);
		
		NSString *statusString = [NSString stringWithFormat:@"%@:\n\n%@",
								  NSLocalizedString(@"Failed to unmount child", nil),
								  [info objectForKey:NSLocalizedFailureReasonErrorKey]];
		
		[info setObject:statusString forKey:NSLocalizedFailureReasonErrorKey];
		[info setObject:statusString forKey:NSLocalizedRecoverySuggestionErrorKey];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:DADiskDidAttemptEjectNotification object:disk userInfo:info];
	}
	
	// Child from notification is unmounted, check for remaining children to unmount
	
	for (Disk *child in parent.children) {
		if (child.isMounted)
			return;			// Still waiting for child
	}
	
	// Need to test if parent is ejectable because we enable "Eject" for a disk
	// that has children that can be unmounted (ala Disk Utility)
	
	if (parent.isEjectable)
		[parent eject];
}

- (IBAction)performEject:(id)sender
{
	Disk *selectedDisk = self.selectedDisk;
	BOOL waitForChildren = NO;
	
	NSSet *disks;
	if (selectedDisk.isWholeDisk && selectedDisk.isLeaf)
		disks = [NSSet setWithObject:selectedDisk];
	else
		disks = selectedDisk.children;
	
	for (Disk *disk in disks) {
		if (disk.isMountable && disk.isMounted) {
			[[NSNotificationCenter defaultCenter] addObserver:self
													 selector:@selector(_childDidAttemptUnmountBeforeEject:)
														 name:DADiskDidAttemptUnmountNotification
													   object:disk];
			[disk unmountWithOptions:0];
			waitForChildren = YES;
		}
	}

	if (!waitForChildren) {
		if (selectedDisk.isEjectable)
			[selectedDisk eject];
	}
}

- (IBAction)performGetInfo:(id)sender
{
	DiskInfoController *controller = [[DiskInfoController alloc] initWithWindowNibName:@"DiskInfo"];
	controller.disk = self.selectedDisk;
	[controller showWindow:self];
	[controller refreshDiskInfo];
	
//	[controller autorelease];
}

- (IBAction)performAttachDiskImage:(id)sender
{
	AttachDiskImageController *controller = [[[AttachDiskImageController alloc] initWithWindowNibName:@"AttachDiskImageAccessory"] autorelease];
	[controller window];
	[controller performAttachDiskImage:sender];
}

#pragma mark Launch Agent

- (NSString *)systemLaunchAgentPath {

	NSString *path = nil;

	CFStringRef identifier = CFBundleGetIdentifier(CFBundleGetMainBundle());
	if (identifier) {
		path = [NSString stringWithFormat:@"%@/%@/%@.plist", @"/", @"Library/LaunchAgents", identifier];
	}

	return path;	
}

- (NSString *)userLaunchAgentPath {

	NSString *path = nil;
	
	CFStringRef identifier = CFBundleGetIdentifier(CFBundleGetMainBundle());
	if (identifier) {
		path = [NSString stringWithFormat:@"%@/%@/%@.plist", NSHomeDirectory(), @"Library/LaunchAgents", identifier];
	}

	return  path;
}

- (void)refreshLaunchAgentStatus {
	NSFileManager *fm = [NSFileManager defaultManager];
	
	self.hasSystemLaunchAgent = [fm fileExistsAtPath:self.systemLaunchAgentPath];

	self.hasUserLaunchAgent = [fm fileExistsAtPath:self.userLaunchAgentPath];
	if (self.hasUserLaunchAgent)
		self.installUserLaunchAgentMenuTitle = @"Uninstall User Launch Agent...";
	else
		self.installUserLaunchAgentMenuTitle = @"Install User Launch Agent...";
}

- (BOOL)canInstallLaunchAgent {
	return (self.hasUserLaunchAgent == NO || self.hasSystemLaunchAgent);
}

- (IBAction)installUserLaunchAgent:(id)sender {
	NSError *error;
	NSAlert *alert = nil;
	NSString *srcPath, *dstPath;
	NSFileManager *fm = [NSFileManager defaultManager];

	if (self.hasUserLaunchAgent) {

		dstPath = self.userLaunchAgentPath;
		
		if ([fm removeItemAtPath:dstPath error:&error] == YES) {
			alert = [NSAlert alertWithMessageText:@"Launch Agent file successfully removed"
									defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
		}
		else {
			alert = [NSAlert alertWithError:error];
		}
	}
	else {
		srcPath = [[NSBundle mainBundle] pathForResource:@"Disk Arbitrator Agent" ofType:@"plist"];
		dstPath = [self userLaunchAgentPath];

		if ([fm copyItemAtPath:srcPath toPath:dstPath error:&error] == YES) {
			alert = [NSAlert alertWithMessageText:@"Launch Agent file successfully installed"
									defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
		}
		else {
			alert = [NSAlert alertWithError:error];
		}
	}
	if (alert)
		[alert runModal];
	
	[self refreshLaunchAgentStatus];
}

#pragma mark Selected Disk

- (Disk *)selectedDisk
{
	NSIndexSet *indexes = [disksArrayController selectionIndexes];
	
	if (indexes.count == 1)
		return [disksArrayController.arrangedObjects objectAtIndex:indexes.lastIndex];
	else
		return nil;
}

- (BOOL)canEjectSelectedDisk
{
	/* "Eject" in the GUI means eject or unmount (like Disk Utility)
	 * To the Disk class, "ejectable" means the media object is ejectable.
	 */

	Disk *selectedDisk = self.selectedDisk;
	BOOL canEject = [selectedDisk isEjectable];

	if (!canEject) {
		for (Disk *child in selectedDisk.children) {
			if (child.isMountable && child.isMounted)
				canEject = YES;
		}
	}
	return canEject;
}

- (BOOL)canMountSelectedDisk
{
	Disk *disk = self.selectedDisk;
	
	if (disk.isMountable && !disk.isMounted)
		return YES;
	else
		return NO;
}

- (BOOL)canUnmountSelectedDisk
{
	Disk *disk = self.selectedDisk;

	return (disk.isMountable && disk.isMounted);
	
//	// Yes if the disk or any children are mounted
//	
//	if (disk.mountable && disk.mounted) return YES;
//	
//	for (Disk *child in disk.children)
//		if (child.mountable && child.mounted)
//			return YES;
}

#pragma mark TableView Delegates

// A custom cell is used for the media description column.  Couldn't find a way to bind it to the disk
// object, so implemented the dataSource delegate.

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)column row:(int)rowIndex
{
    Disk *disk;
	
    NSParameterAssert(rowIndex >= 0 && rowIndex < arbitrator.disks.count);
    disk = [disksArrayController.arrangedObjects objectAtIndex:rowIndex];

	if ([column.identifier isEqual:@"BSDName"])
		return disk.BSDName;

	//	fprintf(stdout, "getting value: %s\n", disk.BSDName.UTF8String);
	return disk;
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op
{
    Log(LOG_DEBUG, @"%s op: %ld info: %@", __func__, op, info);

    NSPasteboard* pboard = [info draggingPasteboard];

	if (op == NSDragOperationCopy && [pboard.types containsObject:NSFilenamesPboardType]) {
		
		NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
		NSArray *extensions = [AttachDiskImageController diskImageFileExtensions];

		for (NSString *file in files) {
			if ([extensions containsObject:[file pathExtension]] == NO)
				return NSDragOperationNone;
		}
		return NSDragOperationCopy;
	}
	return NSDragOperationNone;
}

- (void)doAttachDiskImageAtPath:(NSString *)path
{
	NSError *error;
	
	AttachDiskImageController *controller = [[[AttachDiskImageController alloc] initWithWindowNibName:@"AttachDiskImageAccessory"] autorelease];
	[controller window];

	NSArray *options;
	if (arbitrator.isActivated)
		options = [NSArray arrayWithObjects:@"-readonly", @"-nomount", nil];
	else
		options = [NSArray arrayWithObjects:@"-readonly", @"-mount", @"optional", nil];
	
	if (![controller attachDiskImageAtPath:path options:options password:nil error:&error])
	{
		[NSApp presentError:error];
	}
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info
			  row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
    NSPasteboard* pboard = [info draggingPasteboard];
	
	Log(LOG_DEBUG, @"%s", __func__);

	if (operation == NSDragOperationCopy && [pboard.types containsObject:NSFilenamesPboardType] ) {
		NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];

		Log(LOG_DEBUG, @"files: %@", files);
		
		for (NSString *file in files)
			[self performSelector:@selector(doAttachDiskImageAtPath:) withObject:file afterDelay:0.01];
	}
	return YES;
}

#pragma mark Window Delegates

- (void)windowWillClose:(NSNotification *)notification
{
	[NSApp deactivate];
}

#pragma mark Disk Notifications

- (void)didPresentErrorWithRecovery:(BOOL)didRecover contextInfo:(void *)contextInfo
{
	// If another sheet has unexpected been displayed, recover gracefully
	
	if (window.attachedSheet) {
		Log(LOG_INFO, @"Discarding pending errors: %@", displayErrorQueue);
		[displayErrorQueue removeAllObjects];
		return;
	}
	
	if (displayErrorQueue.count > 0)
	{
		NSError *nextError = [displayErrorQueue objectAtIndex:0];
	
		[window makeKeyAndOrderFront:self];
		[NSApp presentError:nextError
			 modalForWindow:window
				   delegate:self
		 didPresentSelector:@selector(didPresentErrorWithRecovery:contextInfo:)
				contextInfo:NULL];

		[displayErrorQueue removeObjectAtIndex:0];
	}		
}

- (void)diskDidChange:(NSNotification *)notif
{
	NSUInteger row = [disksArrayController.arrangedObjects indexOfObject:notif.object];
	
	[tableView setNeedsDisplayInRect:[tableView rectOfRow:row]];
	[window.toolbar validateVisibleItems];
}

- (void)didAttemptMount:(NSNotification *)notif
{
	Disk *disk = notif.object;
	NSMutableDictionary *info;
	
	if (disk.isMounted) {
		Log(LOG_DEBUG, @"%s: Mounted: %@", __func__, disk.BSDName);
	}
	else {
		// If the mount failed, the notification userInfo will have keys/values that correspond to an NSError
		
		info = [[notif userInfo] mutableCopy];
		
		Log(LOG_ERR, @"Mount failed: %@ (%@) %@", disk.BSDName, [info objectForKey:DAStatusErrorKey], [info objectForKey:NSLocalizedFailureReasonErrorKey]);
		
		[info setObject:[NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"Mount rejected", nil), disk.BSDName]
				 forKey:NSLocalizedDescriptionKey];
		
		NSError *error = [NSError errorWithDomain:AppErrorDomain
											 code:[[info objectForKey:DAStatusErrorKey] intValue]
										 userInfo:info];
		[info release];
		
		if (window.attachedSheet) {
			[displayErrorQueue addObject:error];
		}
		else {
			[window makeKeyAndOrderFront:self];
			[NSApp presentError:error
				 modalForWindow:window
					   delegate:self
			 didPresentSelector:@selector(didPresentErrorWithRecovery:contextInfo:)
					contextInfo:NULL];
		}
	}
	[window.toolbar validateVisibleItems];
}

- (void)didAttemptUnmount:(NSNotification *)notif
{
	Disk *disk = notif.object;
	NSMutableDictionary *info;

	Log(LOG_DEBUG, @"%s: Unmount %@: %@", __func__, (disk.isMounted ? @"failed" : @"succeeded"), disk.BSDName);

	if (disk.isMounted) {
		// If the unmount failed, the notification userInfo will have keys/values that correspond to an NSError
		
		info = [[notif userInfo] mutableCopy];
		
		Log(LOG_INFO, @"Unmount %@ failed: (%@) %@", disk.BSDName, [info objectForKey:DAStatusErrorKey], [info objectForKey:NSLocalizedFailureReasonErrorKey]);
		
		[info setObject:NSLocalizedString(@"Unmount failed", nil) forKey:NSLocalizedDescriptionKey];
		
		NSError *error = [NSError errorWithDomain:AppErrorDomain
											 code:[[info objectForKey:DAStatusErrorKey] intValue]
										 userInfo:info];
		[info release];
		
		if (window.attachedSheet) {
			[displayErrorQueue addObject:error];
		}
		else {
			
			[window makeKeyAndOrderFront:self];
			[NSApp presentError:error
				 modalForWindow:window
					   delegate:self
			 didPresentSelector:@selector(didPresentErrorWithRecovery:contextInfo:)
					contextInfo:NULL];
		}
	}
	[window.toolbar validateVisibleItems];
}

- (void)didAttemptEject:(NSNotification *)notif
{
	Disk *disk = notif.object;
	
	if ([notif userInfo]) {
		
		NSMutableDictionary *info = [[notif userInfo] mutableCopy];
		
		// If the eject failed, the notification userInfo will have keys/values that correspond to an NSError
		
		Log(LOG_INFO, @"Ejecting %@ failed: (%@) %@", disk.BSDName, [info objectForKey:DAStatusErrorKey], [info objectForKey:NSLocalizedFailureReasonErrorKey]);
		
		[info setObject:NSLocalizedString(@"Eject failed", nil) forKey:NSLocalizedDescriptionKey];
		
		NSError *error = [NSError errorWithDomain:AppErrorDomain
											 code:[[info objectForKey:DAStatusErrorKey] intValue]
										 userInfo:info];
		[info release];
		
		if (window.attachedSheet) {
			[displayErrorQueue addObject:error];
		}
		else {
			
			[window makeKeyAndOrderFront:self];
			[NSApp presentError:error
				 modalForWindow:window
					   delegate:self
			 didPresentSelector:@selector(didPresentErrorWithRecovery:contextInfo:)
					contextInfo:NULL];
		}
	}
	else {
		Log(LOG_DEBUG, @"%s: Ejected: %@", __func__, disk);
	}
	[window.toolbar validateVisibleItems];
}

@end
