//
//  SettingsWindowController.m
//  DiskArbitrator
//

#import "SettingsWindowController.h"
#import "DiskArbitratorAppController.h"

@interface SettingsWindowController ()
@property (strong) NSButton *startupCheckbox;
@property (strong) NSButton *activationCheckbox;
@property (strong) NSButton *updatesCheckbox;
@end

@implementation SettingsWindowController

+ (SettingsWindowController *)sharedController
{
	static SettingsWindowController *controller;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		controller = [SettingsWindowController new];
	});
	return controller;
}

- (instancetype)init
{
	self = [super initWithWindow:nil];
	if (self) {
		CGFloat windowHeight = DiskArbitratorSparkleUpdatesConfigured() ? 460 : 360;
		NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 480, windowHeight)
														styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable)
														  backing:NSBackingStoreBuffered
															defer:NO];
		window.title = NSLocalizedString(@"Settings", nil);
		window.toolbarStyle = NSWindowToolbarStyleUnified;
		window.frameAutosaveName = @"DiskArbitratorSettings";
		self.window = window;
		[self buildInterface];
		[window center];
	}
	return self;
}

- (NSTextField *)sectionLabel:(NSString *)title
{
	NSTextField *label = [NSTextField labelWithString:title];
	label.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
	label.textColor = [NSColor labelColor];
	return label;
}

- (NSTextField *)bodyLabel:(NSString *)text
{
	NSTextField *label = [NSTextField wrappingLabelWithString:text];
	label.font = [NSFont systemFontOfSize:12];
	label.textColor = [NSColor secondaryLabelColor];
	label.preferredMaxLayoutWidth = 430;
	return label;
}

- (NSButton *)checkboxWithTitle:(NSString *)title key:(NSString *)key
{
	NSButton *button = [NSButton checkboxWithTitle:title target:self action:@selector(toggleDefault:)];
	button.identifier = key;
	button.state = [[NSUserDefaults standardUserDefaults] boolForKey:key] ? NSControlStateValueOn : NSControlStateValueOff;
	return button;
}

- (void)buildInterface
{
	self.startupCheckbox = [self checkboxWithTitle:NSLocalizedString(@"Show main window at startup", nil) key:@"ShowMainWindowAtStartup"];
	self.activationCheckbox = [self checkboxWithTitle:NSLocalizedString(@"Show main window at activation", nil) key:@"ShowMainWindowAtActivate"];

	NSButton *auditButton = [NSButton buttonWithTitle:NSLocalizedString(@"Audit Log…", nil) target:self action:@selector(showAuditLog:)];
	NSButton *trustedButton = [NSButton buttonWithTitle:NSLocalizedString(@"Trusted Disks…", nil) target:self action:@selector(showTrustedDisks:)];
	auditButton.bezelStyle = NSBezelStyleRounded;
	trustedButton.bezelStyle = NSBezelStyleRounded;

	NSStackView *diskButtons = [NSStackView stackViewWithViews:@[auditButton, trustedButton]];
	diskButtons.orientation = NSUserInterfaceLayoutOrientationHorizontal;
	diskButtons.spacing = 8;

	NSMutableArray *rows = [NSMutableArray arrayWithObjects:
		[self sectionLabel:NSLocalizedString(@"General", nil)],
		self.startupCheckbox,
		self.activationCheckbox,
		[self sectionLabel:NSLocalizedString(@"Protection", nil)],
		[self bodyLabel:NSLocalizedString(@"Trusted disks mount normally. Block Mounts and Read-only still apply to every other disk. The audit log is an append-only JSON Lines file in ~/Library/Logs/Disk Arbitrator/.", nil)],
		diskButtons,
		nil];
	if (DiskArbitratorSparkleUpdatesConfigured()) {
		self.updatesCheckbox = [self checkboxWithTitle:NSLocalizedString(@"Check for updates automatically", nil) key:@"SUEnableAutomaticChecks"];
		NSButton *updatesButton = [NSButton buttonWithTitle:NSLocalizedString(@"Check for Updates…", nil) target:self action:@selector(checkForUpdates:)];
		updatesButton.bezelStyle = NSBezelStyleRounded;
		[rows addObject:[self sectionLabel:NSLocalizedString(@"Updates", nil)]];
		[rows addObject:self.updatesCheckbox];
		[rows addObject:[self bodyLabel:NSLocalizedString(@"Automatic checks use Sparkle and the appcast URL from this build. The EdDSA public key is included in the app. The private key stays out of the app.", nil)]];
		[rows addObject:updatesButton];
	}

	NSStackView *stack = [NSStackView stackViewWithViews:rows];
	stack.orientation = NSUserInterfaceLayoutOrientationVertical;
	stack.alignment = NSLayoutAttributeLeading;
	stack.spacing = 8;
	stack.translatesAutoresizingMaskIntoConstraints = NO;
	[stack setCustomSpacing:16 afterView:self.activationCheckbox];
	[stack setCustomSpacing:16 afterView:diskButtons];

	NSView *content = self.window.contentView;
	[content addSubview:stack];
	[NSLayoutConstraint activateConstraints:@[
		[stack.topAnchor constraintEqualToAnchor:content.topAnchor constant:20],
		[stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
		[stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
		[stack.bottomAnchor constraintLessThanOrEqualToAnchor:content.bottomAnchor constant:-20]
	]];
}

- (void)showWindow:(id)sender
{
	[self refreshCheckboxes];
	[super showWindow:sender];
}

- (void)refreshCheckboxes
{
	NSMutableArray *buttons = [NSMutableArray arrayWithObjects:self.startupCheckbox, self.activationCheckbox, nil];
	if (self.updatesCheckbox)
		[buttons addObject:self.updatesCheckbox];
	for (NSButton *button in buttons) {
		button.state = [[NSUserDefaults standardUserDefaults] boolForKey:button.identifier] ? NSControlStateValueOn : NSControlStateValueOff;
	}
}

- (void)toggleDefault:(NSButton *)sender
{
	[[NSUserDefaults standardUserDefaults] setBool:(sender.state == NSControlStateValueOn) forKey:sender.identifier];
}

- (AppController *)appController
{
	id delegate = [NSApp delegate];
	return [delegate isKindOfClass:[AppController class]] ? delegate : nil;
}

- (void)showAuditLog:(id)sender
{
	[[self appController] showAuditLog:sender];
}

- (void)showTrustedDisks:(id)sender
{
	[[self appController] showTrustedDisks:sender];
}

- (void)checkForUpdates:(id)sender
{
	[[self appController] checkForUpdates:sender];
}

@end
