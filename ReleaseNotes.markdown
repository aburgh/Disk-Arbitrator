## Release Notes

#### 0.10.2 2026/10/14

* Developer ID signed and notarized build, so it opens normally on macOS 27.
* Release signing does not inject `com.apple.security.get-task-allow`. Notarization rejects that entitlement.
* The DMG includes `LICENSE`, README, and the release notes.
* Source archives are attached to releases.
* Build number is 12. Sparkle compares `CFBundleVersion`, so this build is newer than 0.10.1.
* On launch, if the app is not running from `/Applications` (a disk image, another folder, or App Translocation), Disk Arbitrator warns and can copy itself to `/Applications/Disk Arbitrator.app`, then relaunch. The login item cannot keep finding a copy left outside Applications. Xcode debug launches are skipped.
* Audit log entries for mode changes: blocking on or off, read-only on or off, and activated or deactivated. Each entry is timestamped and includes the macOS user name.
* Copy Disk Details, in the Edit menu and the disk list context menu, copies the selected disk as plain text. The items are disabled when no disk is selected.

#### 0.10.1 2026/10/14

* The menu bar icon is the original Disk Arbitrator hard-disk platter, spindle, and actuator arm again. It is redrawn as a crisp vector at menu-bar size, instead of the generic SF Symbols (`shield`, `shield.fill`, `lock.fill`).
* Off is a template image, so it is correct on light and dark menu bars.
* Block mounts stays the original green platter. Read-only stays the original orange platter. Both have a dark-menu-bar variant with a light arm and stroke.
* Build number is 11. Sparkle compares `CFBundleVersion`. Version 0.10 was already tagged; this release is ready to tag as `v0.10.1`.
* Sparkle’s appcast URL and EdDSA public key are the build settings `SPARKLE_FEED_URL` and `SPARKLE_PUBLIC_ED_KEY`. This fork’s defaults are in `Config/Sparkle.xcconfig`. With either one empty, Check for Updates and the Settings update controls stay hidden.

#### 0.10 2026/10/14

* Audit log. Disk appear, disappear, block, read-only mount, read-write mount, unmount, eject, error, and trusted-rule events are appended as JSON Lines to `~/Library/Logs/Disk Arbitrator/audit.jsonl`. Timestamps are UTC. Mount and unmount lines follow the volume path, including mounts macOS performs for a trusted disk and unmounts started outside the app. A disk that is already mounted at launch is `appeared` only. Audit Log… shows the recent entries and can export the whole file as CSV or JSON.
* Trusted disks. Trust Selected Disk remembers a volume UUID (or the media UUID when there is no volume UUID). That disk mounts normally. Block Mounts and Read-only still apply to every other disk. Matches are written to the audit log. Rules are stored in `~/Library/Application Support/Disk Arbitrator/trusted-disks.json`.
* Sparkle 2 checks `https://github.com/derekgboyer/Disk-Arbitrator/releases/latest/download/appcast.xml`. Check for Updates… is in the status menu. Settings has “Check for updates automatically.” `SUPublicEDKey` is `kwGfxsca37dMWVwYY/YElw+U+vF6QDXHnXbqCpWNm18=`. The private key is the `SPARKLE_PRIVATE_KEY` GitHub Actions secret and is not in this repository.
* A push of a `v*` tag builds a universal Release app, uploads a DMG and a zip, and updates `appcast.xml` on the GitHub release. Developer ID signing and notarization run when the repository secrets below are set. Without them the artifact is ad-hoc signed with the hardened runtime.
* Build number is 10. Sparkle compares `CFBundleVersion`, so the next release has to use a higher build number.
* The disk window, toolbar, status icon, and Settings window use SF Symbols and system colors for light mode, dark mode, and the accent color. Each disk row shows whether it is blocked, read-only, read-write, or trusted. The app icon is the original aluminum disk and colored square, redrawn for the current macOS icon shape.

#### 0.9 2026/10/13

* Universal `arm64` + `x86_64` build for macOS 13 Ventura and later, including current Xcode. The app is ad-hoc signed with the hardened runtime and is not sandboxed.
* Deployment target is 13.0. The old per-architecture minimum of 10.6 was removed.
* Mount approval only allows a mount that Disk Arbitrator itself just submitted. A system retry can no longer slip through as read-write while a read-only remount is still pending. If a requested read-only mount comes up writable, it is unmounted.
* Read-only remounts of APFS and other non-HFS volumes use `rdonly` only. The HFS ignore-journal flag is unchanged.
* Disks with no BSD name are ignored instead of raising out of the Disk Arbitration callback.
* Disk icons no longer depend on `KextManagerCreateURLForBundleIdentifier`, which cannot see kexts that exist only in the kernel collection.
* The login item uses `SMAppService` and a Launch Agent inside the app bundle. The obsolete `EnableTransactions` plist and the hard-coded executable path are no longer written to `~/Library/LaunchAgents`.
* Encrypted disk images ask for a password in the app. Authorization Services no longer returns that password.
* Sudden termination is disabled and App Nap is suspended so the approval callback stays scheduled.
* Deprecated AppKit, NSTask, and open-panel calls used on the mount, attach, and settings paths were updated. Cell-based `DiskCell` drawing remains; `NSCell` is still what the main table uses.
* Full Disk Access is documented in the README and available from the status menu. It is not required for the approval callback. Login Items approval is required before the Launch Agent will run.

#### 0.8 2017/9/16

* Added "Show main window at activation" preference (thanks melomac)
* Fix memory leaks

#### 0.7 2016/8/3

* Fix order of disks
* Fix crash during eject

#### 0.6 2016/4/21

* Fix read-only automatic mounts not working on OS X 10.11+
* Disable the "ignore journal" mount option for non-HFS disks

#### 0.5 2015/9/9

* Added lock icon to disks that are read-only
* Fixed launchd plist containing hard coded app path
* Improved compatibility with 10.10
* Improved code stability

#### 0.4.2 2012/11/23

* Added Developer ID signature for Gatekeeper.
* Updated for Xcode 4.5 (should have no affect on behavior).
* Removed PPC architecture.

#### 0.4.1 2012/4/8

* Added feature to install/uninstall a launchd agent plist.
* Added labels and tool tips to make mount options easier to understand.

#### 0.4.0 2011/4/20

* Fixed overwriting AppLogLevel preference at startup.
* Added log message for mount approval callback.
* Activate application when showing the main window, Preferences, or About panel.
* Changed Attach Disk Image icon.
* Changed mode and activation state to persist across application restart.
* Enabled Sudden Termination (new in Snow Leopard for faster shutdowns).

#### 0.3.2 2010/8/23

* Fixed use of Snow Leopard API to retrieve disk icons.
* Minor code cleanup.

#### 0.3.1 2010/8/9

* Added Preferences window and an option to show the main window at launch.

#### 0.3.0 2010/3/29

* Added Attach Disk Image feature.
* Added check for encrypted disk image.
* Added support for attaching a disk image by dragging the file into the disks window.
* Added a progress window while a disk image is verified.
* Added disk menu to the status item menu.
* Improved validation of toolbar items.

#### 0.2.0 2010/2/14

* Added Disk Info window.
* Added mounting feature with dialog for options and mountpoint path.
* Added unmounting and ejecting.
* Added toolbar and custom icons.
* Improved logging.

#### 0.1.1 2010/2/7

* Added target to build the distribution DMG.
* Fixed refresh bug when a disk is mounted or unmounted.
* Added controls to the main window to activate and change mode.

#### 0.1.0 2010/1/31

* Initial release
