//
//  AuditLog.m
//  DiskArbitrator
//
//  Append-only JSON Lines log of disk events, plus a viewer window.

#import "AuditLog.h"
#import "Disk.h"
#import "AppError.h"
#import <DiskArbitration/DiskArbitration.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>

NSString * const DAAuditEventAppeared = @"appeared";
NSString * const DAAuditEventDisappeared = @"disappeared";
NSString * const DAAuditEventBlocked = @"blocked";
NSString * const DAAuditEventMountedReadOnly = @"mounted_read_only";
NSString * const DAAuditEventMountedReadWrite = @"mounted_read_write";
NSString * const DAAuditEventUnmounted = @"unmounted";
NSString * const DAAuditEventEjected = @"ejected";
NSString * const DAAuditEventError = @"error";
NSString * const DAAuditEventRuleMatched = @"rule_matched";
NSString * const DAAuditEventModeChanged = @"mode_changed";

static NSArray<NSString *> *DAAuditFieldOrder(void)
{
	static NSArray<NSString *> *order;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		order = @[
			@"timestamp", @"event", @"action", @"message", @"user",
			@"bsdName", @"volumeName", @"volumeUUID", @"mediaUUID",
			@"fileSystem", @"mediaName", @"deviceModel", @"deviceProtocol", @"mediaSize"
		];
	});
	return order;
}

NSString *DAStringFromDescriptionValue(id value)
{
	if (!value || value == (id)kCFNull)
		return nil;
	if ([value isKindOfClass:[NSString class]])
		return value;
	if ([value isKindOfClass:[NSUUID class]])
		return [[(NSUUID *)value UUIDString] uppercaseString];

	CFTypeID typeID = CFGetTypeID((__bridge CFTypeRef)value);
	if (typeID == CFUUIDGetTypeID()) {
		CFStringRef string = CFUUIDCreateString(kCFAllocatorDefault, (__bridge CFUUIDRef)value);
		NSString *result = [(__bridge NSString *)string uppercaseString];
		CFRelease(string);
		return result;
	}
	if ([value isKindOfClass:[NSNumber class]])
		return [(NSNumber *)value stringValue];
	if ([value isKindOfClass:[NSURL class]])
		return [(NSURL *)value path];
	return nil;
}

NSString *DAVolumeUUIDForDisk(Disk *disk)
{
	if (![disk isKindOfClass:[Disk class]])
		return nil;
	return DAStringFromDescriptionValue(disk.diskDescription[(NSString *)kDADiskDescriptionVolumeUUIDKey]);
}

NSString *DAMediaUUIDForDisk(Disk *disk)
{
	if (![disk isKindOfClass:[Disk class]])
		return nil;
	return DAStringFromDescriptionValue(disk.diskDescription[(NSString *)kDADiskDescriptionMediaUUIDKey]);
}

static id DAJSONString(NSDictionary *description, CFStringRef key)
{
	NSString *value = DAStringFromDescriptionValue(description[(__bridge NSString *)key]);
	return value ?: [NSNull null];
}

static NSString *DADisplayString(id value)
{
	if (!value || value == (id)kCFNull)
		return @"";
	if ([value isKindOfClass:[NSString class]])
		return value;
	return [value description];
}

static NSString *DACSVEscape(id value)
{
	NSString *text = DADisplayString(value);
	NSCharacterSet *special = [NSCharacterSet characterSetWithCharactersInString:@",\"\n\r"];
	if ([text rangeOfCharacterFromSet:special].location == NSNotFound)
		return text;
	NSString *escaped = [text stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""];
	return [NSString stringWithFormat:@"\"%@\"", escaped];
}

////////////////////////////////////////////////////////////////////////////////

@interface AuditLog ()
@property (copy, readwrite) NSURL *logFileURL;
@property (strong) NSLock *writeLock;
@property (strong) NSISO8601DateFormatter *timestampFormatter;
- (void)recordEvent:(NSString *)event disk:(Disk *)disk action:(NSString *)action message:(NSString *)message user:(NSString *)user;
@end

@implementation AuditLog

+ (AuditLog *)sharedLog
{
	static AuditLog *log;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		log = [AuditLog new];
	});
	return log;
}

- (instancetype)init
{
	self = [super init];
	if (self) {
		_writeLock = [NSLock new];
		_timestampFormatter = [NSISO8601DateFormatter new];
		_timestampFormatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
		_timestampFormatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];

		NSFileManager *files = [NSFileManager defaultManager];
		NSURL *library = [files URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask].firstObject;
		NSURL *directory = [library URLByAppendingPathComponent:@"Logs/Disk Arbitrator" isDirectory:YES];
		NSError *error = nil;
		if (![files createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:&error])
			Log(LOG_ERR, @"Audit log directory: %@", error);
		_logFileURL = [directory URLByAppendingPathComponent:@"audit.jsonl"];
	}
	return self;
}

- (NSDictionary *)fieldsForDisk:(Disk *)disk
{
	NSDictionary *description = [disk isKindOfClass:[Disk class]] ? disk.diskDescription : nil;
	id size = description[(NSString *)kDADiskDescriptionMediaSizeKey];
	if (![size isKindOfClass:[NSNumber class]])
		size = [NSNull null];

	return @{
		@"bsdName": ([disk isKindOfClass:[Disk class]] ? disk.BSDName : nil) ?: [NSNull null],
		@"volumeName": DAJSONString(description, kDADiskDescriptionVolumeNameKey),
		@"volumeUUID": DAJSONString(description, kDADiskDescriptionVolumeUUIDKey),
		@"mediaUUID": DAJSONString(description, kDADiskDescriptionMediaUUIDKey),
		@"fileSystem": DAJSONString(description, kDADiskDescriptionVolumeKindKey),
		@"mediaName": DAJSONString(description, kDADiskDescriptionMediaNameKey),
		@"deviceModel": DAJSONString(description, kDADiskDescriptionDeviceModelKey),
		@"deviceProtocol": DAJSONString(description, kDADiskDescriptionDeviceProtocolKey),
		@"mediaSize": size
	};
}

- (void)recordEvent:(NSString *)event disk:(Disk *)disk action:(NSString *)action message:(NSString *)message
{
	[self recordEvent:event disk:disk action:action message:message user:nil];
}

- (void)recordModeChange:(NSString *)state
{
	NSString *user = NSUserName();
	NSString *mode = state.length ? state : @"mode changed";
	[self recordEvent:DAAuditEventModeChanged disk:nil action:mode message:mode user:(user.length ? user : @"unavailable")];
}

- (void)recordEvent:(NSString *)event disk:(Disk *)disk action:(NSString *)action message:(NSString *)message user:(NSString *)user
{
	NSMutableDictionary *record = [NSMutableDictionary dictionary];
	record[@"timestamp"] = [self.timestampFormatter stringFromDate:[NSDate date]] ?: @"";
	record[@"event"] = event.length ? event : @"unknown";
	record[@"action"] = action ?: [NSNull null];
	record[@"message"] = message ?: [NSNull null];
	if (user.length)
		record[@"user"] = user;
	[record addEntriesFromDictionary:[self fieldsForDisk:disk]];

	NSError *error = nil;
	NSData *json = [NSJSONSerialization dataWithJSONObject:record
													options:(NSJSONWritingSortedKeys | NSJSONWritingWithoutEscapingSlashes)
													  error:&error];
	if (!json) {
		Log(LOG_ERR, @"Audit log encode failed: %@", error);
		return;
	}

	NSMutableData *line = [json mutableCopy];
	[line appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];

	[self.writeLock lock];
	int fd = open(self.logFileURL.path.fileSystemRepresentation, O_WRONLY | O_CREAT | O_APPEND, 0644);
	if (fd < 0) {
		Log(LOG_ERR, @"Audit log open failed: %s", strerror(errno));
	}
	else {
		const uint8_t *bytes = line.bytes;
		size_t remaining = line.length;
		while (remaining > 0) {
			ssize_t wrote = write(fd, bytes, remaining);
			if (wrote < 0) {
				if (errno == EINTR)
					continue;
				Log(LOG_ERR, @"Audit log write failed: %s", strerror(errno));
				break;
			}
			bytes += wrote;
			remaining -= (size_t)wrote;
		}
		close(fd);
	}
	[self.writeLock unlock];
}

- (NSData *)logDataNewestTail:(BOOL)tail
{
	NSError *error = nil;
	NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self.logFileURL.path error:&error];
	if (!attributes)
		return nil;

	NSFileHandle *handle = [NSFileHandle fileHandleForReadingFromURL:self.logFileURL error:&error];
	if (!handle)
		return nil;

	unsigned long long size = [attributes fileSize];
	const unsigned long long tailLimit = 4ull * 1024ull * 1024ull;
	if (tail && size > tailLimit) {
		[handle seekToOffset:(size - tailLimit) error:nil];
	}

	NSData *data = [handle readDataToEndOfFileAndReturnError:&error];
	[handle closeAndReturnError:nil];
	if (tail && size > tailLimit && data.length > 0) {
		NSData *newline = [@"\n" dataUsingEncoding:NSUTF8StringEncoding];
		NSRange firstBreak = [data rangeOfData:newline options:0 range:NSMakeRange(0, data.length)];
		if (firstBreak.location != NSNotFound && NSMaxRange(firstBreak) < data.length)
			data = [data subdataWithRange:NSMakeRange(NSMaxRange(firstBreak), data.length - NSMaxRange(firstBreak))];
	}
	return data;
}

- (NSArray<NSDictionary *> *)entriesFromData:(NSData *)data limit:(NSUInteger)limit newestFirst:(BOOL)newestFirst
{
	if (data.length == 0)
		return @[];

	NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if (!text)
		return @[];

	NSMutableArray<NSDictionary *> *entries = [NSMutableArray array];
	for (NSString *line in [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
		if (line.length == 0)
			continue;
		NSData *lineData = [line dataUsingEncoding:NSUTF8StringEncoding];
		id object = [NSJSONSerialization JSONObjectWithData:lineData options:0 error:nil];
		if ([object isKindOfClass:[NSDictionary class]])
			[entries addObject:object];
	}

	if (limit > 0 && entries.count > limit) {
		NSRange range = NSMakeRange(entries.count - limit, limit);
		entries = [[entries subarrayWithRange:range] mutableCopy];
	}
	if (!newestFirst)
		return entries;
	return [[entries reverseObjectEnumerator] allObjects];
}

- (NSArray<NSDictionary *> *)entriesWithLimit:(NSUInteger)limit
{
	BOOL tail = limit > 0;
	return [self entriesFromData:[self logDataNewestTail:tail] limit:limit newestFirst:YES];
}

- (NSArray<NSDictionary *> *)allEntriesChronological
{
	return [self entriesFromData:[self logDataNewestTail:NO] limit:0 newestFirst:NO];
}

- (BOOL)exportJSONToURL:(NSURL *)url error:(NSError **)error
{
	NSArray *entries = [self allEntriesChronological];
	NSData *data = [NSJSONSerialization dataWithJSONObject:entries options:NSJSONWritingPrettyPrinted error:error];
	if (!data)
		return NO;
	return [data writeToURL:url options:NSDataWritingAtomic error:error];
}

- (BOOL)exportCSVToURL:(NSURL *)url error:(NSError **)error
{
	NSMutableString *csv = [NSMutableString string];
	[csv appendString:[DAAuditFieldOrder() componentsJoinedByString:@","]];
	[csv appendString:@"\n"];
	for (NSDictionary *entry in [self allEntriesChronological]) {
		NSMutableArray<NSString *> *columns = [NSMutableArray array];
		for (NSString *key in DAAuditFieldOrder())
			[columns addObject:DACSVEscape(entry[key])];
		[csv appendString:[columns componentsJoinedByString:@","]];
		[csv appendString:@"\n"];
	}
	return [[csv dataUsingEncoding:NSUTF8StringEncoding] writeToURL:url options:NSDataWritingAtomic error:error];
}

- (void)revealInFinder
{
	NSFileManager *files = [NSFileManager defaultManager];
	NSURL *url = self.logFileURL;
	if (![files fileExistsAtPath:url.path])
		url = [url URLByDeletingLastPathComponent];
	[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[url]];
}

@end

////////////////////////////////////////////////////////////////////////////////

static const NSUInteger DAAuditDisplayLimit = 5000;

@interface AuditLogWindowController () <NSTableViewDataSource, NSTableViewDelegate>
@property (strong) NSTableView *tableView;
@property (strong) NSTextView *detailView;
@property (strong) NSSearchField *searchField;
@property (strong) NSTextField *pathField;
@property (copy) NSArray<NSDictionary *> *entries;
@property (copy) NSArray<NSDictionary *> *visibleEntries;
@property (strong) NSDateFormatter *displayDateFormatter;
@property (strong) NSISO8601DateFormatter *parseDateFormatter;
@end

@implementation AuditLogWindowController

+ (AuditLogWindowController *)sharedController
{
	static AuditLogWindowController *controller;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		controller = [AuditLogWindowController new];
	});
	return controller;
}

- (instancetype)init
{
	self = [super initWithWindow:nil];
	if (self) {
		_displayDateFormatter = [NSDateFormatter new];
		_displayDateFormatter.dateStyle = NSDateFormatterMediumStyle;
		_displayDateFormatter.timeStyle = NSDateFormatterMediumStyle;
		_parseDateFormatter = [NSISO8601DateFormatter new];
		_parseDateFormatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;

		NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 780, 520)
														styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
														  backing:NSBackingStoreBuffered
															defer:NO];
		window.title = NSLocalizedString(@"Audit Log", nil);
		window.subtitle = NSLocalizedString(@"Append-only record of disk events", nil);
		window.toolbarStyle = NSWindowToolbarStyleUnified;
		window.minSize = NSMakeSize(640, 380);
		window.frameAutosaveName = @"AuditLogWindow";
		window.autorecalculatesKeyViewLoop = YES;
		self.window = window;
		[self buildInterface];
		[window center];
	}
	return self;
}

- (NSButton *)pushButtonWithTitle:(NSString *)title action:(SEL)action
{
	NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
	button.bezelStyle = NSBezelStyleRounded;
	button.translatesAutoresizingMaskIntoConstraints = NO;
	return button;
}

- (void)buildInterface
{
	NSView *content = self.window.contentView;

	self.searchField = [[NSSearchField alloc] initWithFrame:NSZeroRect];
	self.searchField.placeholderString = NSLocalizedString(@"Filter", nil);
	[self.searchField.widthAnchor constraintGreaterThanOrEqualToConstant:160].active = YES;
	self.searchField.target = self;
	self.searchField.action = @selector(filterChanged:);
	self.searchField.continuous = YES;
	self.searchField.translatesAutoresizingMaskIntoConstraints = NO;
	[self.searchField setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

	NSButton *refreshButton = [self pushButtonWithTitle:NSLocalizedString(@"Refresh", nil) action:@selector(reload:)];
	NSButton *jsonButton = [self pushButtonWithTitle:NSLocalizedString(@"Export JSON…", nil) action:@selector(exportJSON:)];
	NSButton *csvButton = [self pushButtonWithTitle:NSLocalizedString(@"Export CSV…", nil) action:@selector(exportCSV:)];
	NSButton *revealButton = [self pushButtonWithTitle:NSLocalizedString(@"Reveal in Finder", nil) action:@selector(reveal:)];

	NSStackView *toolbar = [NSStackView stackViewWithViews:@[self.searchField, refreshButton, jsonButton, csvButton, revealButton]];
	toolbar.orientation = NSUserInterfaceLayoutOrientationHorizontal;
	toolbar.spacing = 8;
	toolbar.alignment = NSLayoutAttributeCenterY;
	toolbar.translatesAutoresizingMaskIntoConstraints = NO;
	[toolbar setHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationVertical];

	self.tableView = [[NSTableView alloc] initWithFrame:NSZeroRect];
	self.tableView.style = NSTableViewStyleInset;
	self.tableView.rowHeight = 22;
	self.tableView.usesAlternatingRowBackgroundColors = YES;
	self.tableView.columnAutoresizingStyle = NSTableViewLastColumnOnlyAutoresizingStyle;
	self.tableView.headerView = [[NSTableHeaderView alloc] initWithFrame:NSZeroRect];
	self.tableView.dataSource = self;
	self.tableView.delegate = self;
	self.tableView.allowsMultipleSelection = NO;
	NSDictionary<NSString *, NSString *> *columns = @{
		@"timestamp": NSLocalizedString(@"Time", nil),
		@"event": NSLocalizedString(@"Event", nil),
		@"bsdName": NSLocalizedString(@"BSD Name", nil),
		@"volumeName": NSLocalizedString(@"Volume", nil),
		@"action": NSLocalizedString(@"Action", nil)
	};
	NSArray<NSString *> *order = @[@"timestamp", @"event", @"bsdName", @"volumeName", @"action"];
	NSDictionary<NSString *, NSNumber *> *widths = @{@"timestamp": @180, @"event": @140, @"bsdName": @90, @"volumeName": @140, @"action": @180};
	for (NSString *identifier in order) {
		NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:identifier];
		column.title = columns[identifier];
		column.width = widths[identifier].doubleValue;
		column.minWidth = 60;
		[self.tableView addTableColumn:column];
	}

	NSScrollView *tableScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
	tableScroll.documentView = self.tableView;
	tableScroll.hasVerticalScroller = YES;
	tableScroll.autohidesScrollers = YES;
	tableScroll.borderType = NSNoBorder;
	tableScroll.translatesAutoresizingMaskIntoConstraints = NO;
	tableScroll.drawsBackground = NO;

	NSTextField *detailLabel = [NSTextField labelWithString:NSLocalizedString(@"Event", nil)];
	detailLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
	detailLabel.textColor = [NSColor labelColor];

	self.detailView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
	self.detailView.editable = NO;
	self.detailView.selectable = YES;
	self.detailView.richText = NO;
	self.detailView.drawsBackground = NO;
	self.detailView.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
	self.detailView.textColor = [NSColor labelColor];
	self.detailView.textContainerInset = NSMakeSize(6, 6);

	NSScrollView *detailScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
	detailScroll.documentView = self.detailView;
	detailScroll.hasVerticalScroller = YES;
	detailScroll.borderType = NSBezelBorder;
	detailScroll.translatesAutoresizingMaskIntoConstraints = NO;
	[detailScroll.heightAnchor constraintEqualToConstant:140].active = YES;

	self.pathField = [NSTextField labelWithString:@""];
	self.pathField.font = [NSFont systemFontOfSize:11];
	self.pathField.textColor = [NSColor secondaryLabelColor];
	self.pathField.lineBreakMode = NSLineBreakByTruncatingMiddle;
	[self.pathField setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

	NSStackView *stack = [NSStackView stackViewWithViews:@[toolbar, tableScroll, detailLabel, detailScroll, self.pathField]];
	stack.orientation = NSUserInterfaceLayoutOrientationVertical;
	stack.alignment = NSLayoutAttributeLeading;
	stack.spacing = 8;
	stack.translatesAutoresizingMaskIntoConstraints = NO;
	[stack setCustomSpacing:12 afterView:toolbar];
	[content addSubview:stack];

	[NSLayoutConstraint activateConstraints:@[
		[stack.topAnchor constraintEqualToAnchor:content.topAnchor constant:12],
		[stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
		[stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
		[stack.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-12],
		[toolbar.trailingAnchor constraintEqualToAnchor:stack.trailingAnchor],
		[tableScroll.leadingAnchor constraintEqualToAnchor:stack.leadingAnchor],
		[tableScroll.trailingAnchor constraintEqualToAnchor:stack.trailingAnchor],
		[detailScroll.leadingAnchor constraintEqualToAnchor:stack.leadingAnchor],
		[detailScroll.trailingAnchor constraintEqualToAnchor:stack.trailingAnchor],
		[self.pathField.trailingAnchor constraintEqualToAnchor:stack.trailingAnchor]
	]];
}

- (void)showWindow:(id)sender
{
	[self reload:sender];
	[super showWindow:sender];
}

- (NSString *)displayTimestamp:(id)value
{
	NSString *text = DADisplayString(value);
	NSDate *date = [self.parseDateFormatter dateFromString:text];
	return date ? [self.displayDateFormatter stringFromDate:date] : text;
}

- (void)reload:(id)sender
{
	self.entries = [[AuditLog sharedLog] entriesWithLimit:DAAuditDisplayLimit];
	self.pathField.stringValue = [AuditLog sharedLog].logFileURL.path ?: @"";
	[self applyFilter];
}

- (void)filterChanged:(id)sender
{
	[self applyFilter];
}

- (void)applyFilter
{
	NSString *query = self.searchField.stringValue.lowercaseString;
	if (query.length == 0) {
		self.visibleEntries = self.entries ?: @[];
	}
	else {
		NSMutableArray *matches = [NSMutableArray array];
		for (NSDictionary *entry in self.entries) {
			for (id value in entry.allValues) {
				if ([DADisplayString(value).lowercaseString containsString:query]) {
					[matches addObject:entry];
					break;
				}
			}
		}
		self.visibleEntries = matches;
	}
	[self.tableView reloadData];
	self.detailView.string = @"";
	if (self.visibleEntries.count > 0) {
		[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
	}
}

- (void)exportJSON:(id)sender
{
	[self exportWithContentType:UTTypeJSON name:@"Disk Arbitrator Audit.json" csv:NO];
}

- (void)exportCSV:(id)sender
{
	[self exportWithContentType:UTTypeCommaSeparatedText name:@"Disk Arbitrator Audit.csv" csv:YES];
}

- (void)exportWithContentType:(UTType *)type name:(NSString *)name csv:(BOOL)csv
{
	NSSavePanel *panel = [NSSavePanel savePanel];
	panel.allowedContentTypes = @[type];
	panel.nameFieldStringValue = name;
	panel.canCreateDirectories = YES;
	[panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
		if (result != NSModalResponseOK)
			return;
		NSError *error = nil;
		BOOL ok = csv ? [[AuditLog sharedLog] exportCSVToURL:panel.URL error:&error]
					  : [[AuditLog sharedLog] exportJSONToURL:panel.URL error:&error];
		if (!ok) {
			NSAlert *alert = [NSAlert alertWithError:error];
			[alert beginSheetModalForWindow:self.window completionHandler:nil];
		}
	}];
}

- (void)reveal:(id)sender
{
	[[AuditLog sharedLog] revealInFinder];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return (NSInteger)self.visibleEntries.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
	NSTableCellView *cell = [tableView makeViewWithIdentifier:column.identifier owner:self];
	if (!cell) {
		cell = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
		cell.identifier = column.identifier;
		NSTextField *text = [NSTextField labelWithString:@""];
		text.translatesAutoresizingMaskIntoConstraints = NO;
		text.lineBreakMode = NSLineBreakByTruncatingTail;
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

	NSDictionary *entry = self.visibleEntries[(NSUInteger)row];
	id value = entry[column.identifier];
	if ([column.identifier isEqualToString:@"timestamp"])
		cell.textField.stringValue = [self displayTimestamp:value];
	else
		cell.textField.stringValue = DADisplayString(value);
	return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	NSInteger row = self.tableView.selectedRow;
	if (row < 0 || row >= (NSInteger)self.visibleEntries.count) {
		self.detailView.string = @"";
		return;
	}
	NSDictionary *entry = self.visibleEntries[(NSUInteger)row];
	NSData *data = [NSJSONSerialization dataWithJSONObject:entry options:NSJSONWritingPrettyPrinted error:nil];
	self.detailView.string = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"";
}

@end
