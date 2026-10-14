//
//  TrustedDiskStore.m
//  DiskArbitrator
//
//  Persists trusted-disk rules and shows them in a window.

#import "TrustedDiskStore.h"
#import "AuditLog.h"
#import "Disk.h"
#import "AppError.h"
#import <DiskArbitration/DiskArbitration.h>

NSString * const TrustedDiskStoreDidChangeNotification = @"TrustedDiskStoreDidChangeNotification";

static NSString * const TrustedDiskKindVolume = @"volume";
static NSString * const TrustedDiskKindMedia = @"media";

@implementation TrustedDiskRule

- (NSDictionary *)dictionaryRepresentation
{
	return @{
		@"identifier": self.identifier ?: @"",
		@"kind": self.kind ?: @"",
		@"displayName": self.displayName ?: @"",
		@"bsdName": self.bsdName ?: @"",
		@"fileSystem": self.fileSystem ?: @"",
		@"addedAt": self.addedAt ?: @""
	};
}

+ (TrustedDiskRule *)ruleFromDictionary:(NSDictionary *)dictionary
{
	if (![dictionary isKindOfClass:[NSDictionary class]])
		return nil;
	NSString *identifier = dictionary[@"identifier"];
	NSString *kind = dictionary[@"kind"];
	if (![identifier isKindOfClass:[NSString class]] || identifier.length == 0)
		return nil;
	if (![kind isEqualToString:TrustedDiskKindVolume] && ![kind isEqualToString:TrustedDiskKindMedia])
		return nil;

	TrustedDiskRule *rule = [TrustedDiskRule new];
	rule.identifier = identifier.uppercaseString;
	rule.kind = kind;
	rule.displayName = [dictionary[@"displayName"] isKindOfClass:[NSString class]] ? dictionary[@"displayName"] : @"";
	rule.bsdName = [dictionary[@"bsdName"] isKindOfClass:[NSString class]] ? dictionary[@"bsdName"] : @"";
	rule.fileSystem = [dictionary[@"fileSystem"] isKindOfClass:[NSString class]] ? dictionary[@"fileSystem"] : @"";
	rule.addedAt = [dictionary[@"addedAt"] isKindOfClass:[NSString class]] ? dictionary[@"addedAt"] : @"";
	return rule;
}

@end

////////////////////////////////////////////////////////////////////////////////

@interface TrustedDiskStore ()
@property (copy, readwrite) NSArray<TrustedDiskRule *> *rules;
@property (strong) NSLock *lock;
@property (strong) NSISO8601DateFormatter *timestampFormatter;
@end

@implementation TrustedDiskStore

+ (TrustedDiskStore *)sharedStore
{
	static TrustedDiskStore *store;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		store = [TrustedDiskStore new];
	});
	return store;
}

- (instancetype)init
{
	self = [super init];
	if (self) {
		_lock = [NSLock new];
		_rules = @[];
		_timestampFormatter = [NSISO8601DateFormatter new];
		_timestampFormatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
		[self loadRules];
	}
	return self;
}

- (NSURL *)storeFileURL
{
	NSFileManager *files = [NSFileManager defaultManager];
	NSURL *library = [files URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
	NSURL *directory = [library URLByAppendingPathComponent:@"Disk Arbitrator" isDirectory:YES];
	[files createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:nil];
	return [directory URLByAppendingPathComponent:@"trusted-disks.json"];
}

- (void)loadRules
{
	NSData *data = [NSData dataWithContentsOfURL:[self storeFileURL]];
	if (data.length == 0) {
		self.rules = @[];
		return;
	}
	id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
	NSArray *raw = [object isKindOfClass:[NSDictionary class]] ? ((NSDictionary *)object)[@"rules"] : nil;
	if (![raw isKindOfClass:[NSArray class]]) {
		self.rules = @[];
		return;
	}
	NSMutableArray<TrustedDiskRule *> *rules = [NSMutableArray array];
	for (id entry in raw) {
		TrustedDiskRule *rule = [TrustedDiskRule ruleFromDictionary:entry];
		if (rule)
			[rules addObject:rule];
	}
	self.rules = rules;
}

- (BOOL)saveRules:(NSError **)error
{
	NSMutableArray *raw = [NSMutableArray array];
	for (TrustedDiskRule *rule in self.rules)
		[raw addObject:[rule dictionaryRepresentation]];
	NSData *data = [NSJSONSerialization dataWithJSONObject:@{@"rules": raw}
												   options:NSJSONWritingPrettyPrinted
													 error:error];
	if (!data)
		return NO;
	return [data writeToURL:[self storeFileURL] options:NSDataWritingAtomic error:error];
}

- (void)postChange
{
	[[NSNotificationCenter defaultCenter] postNotificationName:TrustedDiskStoreDidChangeNotification object:self];
}

- (TrustedDiskRule *)ruleMatchingIdentifier:(NSString *)identifier kind:(NSString *)kind
{
	if (identifier.length == 0)
		return nil;
	for (TrustedDiskRule *rule in self.rules) {
		if ([rule.kind isEqualToString:kind] && [rule.identifier caseInsensitiveCompare:identifier] == NSOrderedSame)
			return rule;
	}
	return nil;
}

- (TrustedDiskRule *)ruleMatchingDisk:(Disk *)disk
{
	if (![disk isKindOfClass:[Disk class]])
		return nil;
	[self.lock lock];
	TrustedDiskRule *match = [self ruleMatchingIdentifier:DAVolumeUUIDForDisk(disk) kind:TrustedDiskKindVolume];
	if (!match)
		match = [self ruleMatchingIdentifier:DAMediaUUIDForDisk(disk) kind:TrustedDiskKindMedia];
	[self.lock unlock];
	return match;
}

- (NSString *)displayNameForDisk:(Disk *)disk
{
	NSString *volume = DAStringFromDescriptionValue(disk.diskDescription[(NSString *)kDADiskDescriptionVolumeNameKey]);
	if (volume.length)
		return volume;
	NSString *media = DAStringFromDescriptionValue(disk.diskDescription[(NSString *)kDADiskDescriptionMediaNameKey]);
	if (media.length)
		return media;
	return disk.BSDName ?: @"";
}

- (TrustedDiskRule *)trustDisk:(Disk *)disk error:(NSError **)error
{
	if (![disk isKindOfClass:[Disk class]]) {
		if (error)
			*error = [NSError errorWithDomain:AppErrorDomain code:EINVAL userInfo:@{
				NSLocalizedDescriptionKey: NSLocalizedString(@"Select a disk first", nil)
			}];
		return nil;
	}

	NSString *volumeUUID = DAVolumeUUIDForDisk(disk);
	NSString *mediaUUID = DAMediaUUIDForDisk(disk);
	NSString *kind = nil;
	NSString *identifier = nil;
	if (volumeUUID.length) {
		kind = TrustedDiskKindVolume;
		identifier = volumeUUID;
	}
	else if (mediaUUID.length) {
		kind = TrustedDiskKindMedia;
		identifier = mediaUUID;
	}
	else {
		if (error) {
			*error = [NSError errorWithDomain:AppErrorDomain code:ENOENT userInfo:@{
				NSLocalizedDescriptionKey: NSLocalizedString(@"This disk has no stable identifier", nil),
				NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Disk Arbitration did not report a volume UUID or a media UUID, so a trusted-disk rule would not match it again.", nil)
			}];
		}
		return nil;
	}

	[self.lock lock];
	TrustedDiskRule *existing = [self ruleMatchingIdentifier:identifier kind:kind];
	if (existing) {
		[self.lock unlock];
		return existing;
	}

	TrustedDiskRule *rule = [TrustedDiskRule new];
	rule.identifier = identifier.uppercaseString;
	rule.kind = kind;
	rule.displayName = [self displayNameForDisk:disk];
	rule.bsdName = disk.BSDName ?: @"";
	rule.fileSystem = DAStringFromDescriptionValue(disk.diskDescription[(NSString *)kDADiskDescriptionVolumeKindKey]) ?: @"";
	rule.addedAt = [self.timestampFormatter stringFromDate:[NSDate date]] ?: @"";

	NSMutableArray *updated = [self.rules mutableCopy];
	[updated addObject:rule];
	NSArray *previous = self.rules;
	self.rules = updated;
	NSError *saveError = nil;
	BOOL saved = [self saveRules:&saveError];
	if (!saved)
		self.rules = previous;
	[self.lock unlock];

	if (!saved) {
		if (error)
			*error = saveError;
		return nil;
	}
	[self postChange];
	return rule;
}

- (BOOL)removeRulesAtIndexes:(NSIndexSet *)indexes error:(NSError **)error
{
	if (indexes.count == 0)
		return YES;
	[self.lock lock];
	NSMutableArray *updated = [self.rules mutableCopy];
	[updated removeObjectsAtIndexes:indexes];
	NSArray *previous = self.rules;
	self.rules = updated;
	NSError *saveError = nil;
	BOOL saved = [self saveRules:&saveError];
	if (!saved)
		self.rules = previous;
	[self.lock unlock];
	if (!saved) {
		if (error)
			*error = saveError;
		return NO;
	}
	[self postChange];
	return YES;
}

@end

////////////////////////////////////////////////////////////////////////////////

@interface TrustedDisksWindowController () <NSTableViewDataSource, NSTableViewDelegate>
@property (strong) NSTableView *tableView;
@property (strong) NSButton *removeButton;
@end

@implementation TrustedDisksWindowController

+ (TrustedDisksWindowController *)sharedController
{
	static TrustedDisksWindowController *controller;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		controller = [TrustedDisksWindowController new];
	});
	return controller;
}

- (instancetype)init
{
	self = [super initWithWindow:nil];
	if (self) {
		NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 720, 420)
														styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
														  backing:NSBackingStoreBuffered
															defer:NO];
		window.title = NSLocalizedString(@"Trusted Disks", nil);
		window.subtitle = NSLocalizedString(@"These disks mount normally", nil);
		window.toolbarStyle = NSWindowToolbarStyleUnified;
		window.minSize = NSMakeSize(560, 320);
		window.frameAutosaveName = @"TrustedDisksWindow";
		self.window = window;
		[self buildInterface];
		[window center];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(rulesChanged:)
													 name:TrustedDiskStoreDidChangeNotification
												   object:nil];
	}
	return self;
}

- (void)buildInterface
{
	NSView *content = self.window.contentView;

	NSTextField *explanation = [NSTextField wrappingLabelWithString:NSLocalizedString(@"A trusted disk is allowed to mount the way the system requested. Block Mounts and Read-only still apply to every other disk. Rules match a volume UUID, or the media UUID when the disk has no volume UUID. Choose Trust Selected Disk from the status menu to add the selected disk.", nil)];
	explanation.font = [NSFont systemFontOfSize:12];
	explanation.textColor = [NSColor secondaryLabelColor];
	explanation.preferredMaxLayoutWidth = 680;
	explanation.translatesAutoresizingMaskIntoConstraints = NO;

	self.tableView = [[NSTableView alloc] initWithFrame:NSZeroRect];
	self.tableView.style = NSTableViewStyleInset;
	self.tableView.rowHeight = 22;
	self.tableView.usesAlternatingRowBackgroundColors = YES;
	self.tableView.columnAutoresizingStyle = NSTableViewLastColumnOnlyAutoresizingStyle;
	self.tableView.headerView = [[NSTableHeaderView alloc] initWithFrame:NSZeroRect];
	self.tableView.dataSource = self;
	self.tableView.delegate = self;
	self.tableView.allowsMultipleSelection = YES;

	NSArray *specs = @[
		@[@"displayName", NSLocalizedString(@"Name", nil), @160],
		@[@"kind", NSLocalizedString(@"Kind", nil), @80],
		@[@"identifier", NSLocalizedString(@"Identifier", nil), @220],
		@[@"fileSystem", NSLocalizedString(@"File System", nil), @90],
		@[@"addedAt", NSLocalizedString(@"Added", nil), @160]
	];
	for (NSArray *spec in specs) {
		NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:spec[0]];
		column.title = spec[1];
		column.width = [spec[2] doubleValue];
		column.minWidth = 60;
		[self.tableView addTableColumn:column];
	}

	NSScrollView *tableScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
	tableScroll.documentView = self.tableView;
	tableScroll.hasVerticalScroller = YES;
	tableScroll.autohidesScrollers = YES;
	tableScroll.borderType = NSNoBorder;
	tableScroll.drawsBackground = NO;
	tableScroll.translatesAutoresizingMaskIntoConstraints = NO;

	self.removeButton = [NSButton buttonWithTitle:NSLocalizedString(@"Remove", nil) target:self action:@selector(remove:)];
	self.removeButton.bezelStyle = NSBezelStyleRounded;
	self.removeButton.translatesAutoresizingMaskIntoConstraints = NO;
	self.removeButton.enabled = NO;

	NSStackView *stack = [NSStackView stackViewWithViews:@[explanation, tableScroll, self.removeButton]];
	stack.orientation = NSUserInterfaceLayoutOrientationVertical;
	stack.alignment = NSLayoutAttributeLeading;
	stack.spacing = 10;
	stack.translatesAutoresizingMaskIntoConstraints = NO;
	[content addSubview:stack];

	[NSLayoutConstraint activateConstraints:@[
		[stack.topAnchor constraintEqualToAnchor:content.topAnchor constant:12],
		[stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
		[stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
		[stack.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-12],
		[explanation.trailingAnchor constraintEqualToAnchor:stack.trailingAnchor],
		[tableScroll.leadingAnchor constraintEqualToAnchor:stack.leadingAnchor],
		[tableScroll.trailingAnchor constraintEqualToAnchor:stack.trailingAnchor]
	]];
}

- (void)showWindow:(id)sender
{
	[self.tableView reloadData];
	[self updateRemoveButton];
	[super showWindow:sender];
}

- (void)rulesChanged:(NSNotification *)notification
{
	[self.tableView reloadData];
	[self updateRemoveButton];
}

- (void)updateRemoveButton
{
	self.removeButton.enabled = self.tableView.selectedRowIndexes.count > 0;
}

- (void)remove:(id)sender
{
	NSError *error = nil;
	if (![[TrustedDiskStore sharedStore] removeRulesAtIndexes:self.tableView.selectedRowIndexes error:&error]) {
		if (error)
			[[NSAlert alertWithError:error] beginSheetModalForWindow:self.window completionHandler:nil];
		return;
	}
	[self.tableView deselectAll:nil];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return (NSInteger)[TrustedDiskStore sharedStore].rules.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
	NSTableCellView *cell = [tableView makeViewWithIdentifier:column.identifier owner:self];
	if (!cell) {
		cell = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
		cell.identifier = column.identifier;
		NSTextField *text = [NSTextField labelWithString:@""];
		text.translatesAutoresizingMaskIntoConstraints = NO;
		text.lineBreakMode = NSLineBreakByTruncatingMiddle;
		text.font = [NSFont systemFontOfSize:12];
		text.textColor = [NSColor labelColor];
		[cell addSubview:text];
		cell.textField = text;
		[NSLayoutConstraint activateConstraints:@[
			[text.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:2],
			[text.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-2],
			[text.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor]
		]];
	}
	TrustedDiskRule *rule = [TrustedDiskStore sharedStore].rules[(NSUInteger)row];
	NSString *value = [rule valueForKey:column.identifier];
	cell.textField.stringValue = [value isKindOfClass:[NSString class]] ? value : @"";
	return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	[self updateRemoveButton];
}

@end
