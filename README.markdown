## Introduction

Disk Arbitrator is a Mac OS X forensic utility designed to help the user ensure correct forensic procedures are followed during imaging of a disk device. 
Disk Arbitrator is essentially a user interface to the Disk Arbitration framework, which enables a program to participate in the management of block 
storage devices, including the automatic mounting of file systems.  When enabled, Disk Arbitrator will block the mounting of file systems to avoid mounting as read-write and violating the integrity of the evidence.

It is important to note that Disk Arbitrator is *not* a software write blocker---it does not change the state of currently attached devices nor does it affect newly attached devices to force a device to be read-only. The user still must be careful to not accidentally write to a disk with a command such as "dd".  Owing to this fact, a hardware or software write-blocker may still be desirable for the most sound procedure.  Disk Arbitrator compliments a write-blocker with additional useful features and eliminates the typical forensic recommendation to "disable disk arbitration."

## System Requirements

* Mac with Apple silicon or Intel
* macOS 13 Ventura or later
* A universal build (`arm64` and `x86_64`) from the Xcode project. Xcode 15 or later is enough; current Xcode is fine.
* The app is not sandboxed. Disk Arbitration mount approval does not work from an App Sandbox.

Build the **DiskArbitrator** scheme in Xcode. Release produces one universal `Disk Arbitrator.app`. Ad-hoc signing (`CODE_SIGN_IDENTITY = -`) plus the hardened runtime lets that local build run on Apple silicon. It is not notarized. The first time you open a downloaded copy, use the Finder (right-click the app, choose Open) or allow it under System Settings > Privacy & Security. Copy it to `/Applications` before you rely on it. Running it from a disk image hits App Translocation, and a Launch Agent then points at a path that disappears.

## Permissions

Disk Arbitrator has no privilege helper. Mount decisions are made by a normal user-level Disk Arbitration approval session.

* **Full Disk Access** is not required for the approval callback itself. Grant it anyway when the disk list stays empty, Get Info cannot read a volume, or you will image the disk from this Mac. macOS does not prompt. Open the menu item **Full Disk Access…**, or go to System Settings > Privacy & Security > Full Disk Access, add **Disk Arbitrator**, then quit and reopen it.
* **Login Items.** "Install User Launch Agent" registers the agent inside the app bundle with `SMAppService` (macOS 13 and later). macOS may leave it waiting for approval under System Settings > General > Login Items & Extensions. Allow it there. The agent starts Disk Arbitrator at login and relaunches it if it quits. That is still after login: disks attached at the login window or earlier can already be mounted. System Integrity Protection prevents unloading `diskarbitrationd`, so there is no supported way for this app to block those early mounts.
* An older install may still have `~/Library/LaunchAgents/us.burghardt.Disk-Arbitrator.plist`. Install the agent again from version 0.9 so launchd uses the copy embedded in the app. The old file hard-coded the executable path and used the obsolete `EnableTransactions` key.

## Limitations on current macOS

These are limits of Disk Arbitration and SIP, not optional features that were removed.

* This is still not a write blocker. A volume that is already mounted is left as it is. `dd` and other tools can still write to the raw device. Use a hardware write-blocker when the procedure requires one.
* Protection exists only while the app is running and activated. Quitting it, or letting macOS terminate it, stops the approval callback. Version 0.9 turns off sudden termination and App Nap so a running copy stays scheduled to answer mount requests.
* **Block Mounts** dissents every new mount, including APFS volumes on external disks and disk images. It does not unmount volumes that are already mounted, and it does not change the startup disk.
* **Read-only** dissents the system mount, then mounts again with the `rdonly` option. For HFS it still passes `-j` (ignore journal). APFS, ExFAT, and MS-DOS do not get `-j`; a dirty APFS volume usually mounts read-only without replaying a journal, but if it does not, attach a disk image with a shadow file or mount it by hand. After a read-only request, Disk Arbitrator checks `statfs`. If the volume came up writable, it unmounts it and shows an error. Confirm with `mount` before you trust the volume.
* The first system mount request is rejected, and only a mount Disk Arbitrator itself just submitted is approved. That closes a gap where a second system attempt could be allowed read-write before the read-only remount started.
* APFS containers show up as one whole disk plus a volume per container entry. Snapshot and synthesized disks that have no BSD name are ignored so they cannot crash the callback.
* Disk icons come from Finder (`NSWorkspace`). The old kext-bundle lookup does not work when the media driver lives only in the kernel collection, which is the usual case on Apple silicon.
* The menu bar icon is the original hard-disk platter, spindle, and actuator arm, redrawn as a crisp vector (version 0.10.1). Off is a template image for light and dark menu bars. Block mounts is the green platter and read-only is the orange platter. The toolbar and disk list use SF Symbols and system colors, so they follow light mode, dark mode, and the accent color. The app icon is the same aluminum disk and colored square as before, redrawn for the current macOS icon shape.
* Encrypted disk images ask for a password in the app. The old Authorization Services prompt stopped returning the password the user typed. Software license agreements are still answered "Yes" automatically.
* Time Machine and other automatic mounts are blocked while Disk Arbitrator is activated. That is the same behavior as before.

## Audit log

Every disk event is appended to `~/Library/Logs/Disk Arbitrator/audit.jsonl`. The file is JSON Lines: one JSON object per line. The fields are `timestamp`, `event`, `action`, `message`, `bsdName`, `volumeName`, `volumeUUID`, `mediaUUID`, `fileSystem`, `mediaName`, `deviceModel`, `deviceProtocol`, and `mediaSize`.

Events are `appeared`, `disappeared`, `blocked`, `mounted_read_only`, `mounted_read_write`, `unmounted`, `ejected`, `error`, and `rule_matched`. Timestamps are UTC. Launch records disks that are already attached as `appeared`, including ones that are already mounted. A later mount or unmount is recorded when Disk Arbitration reports the volume path, so a trusted disk that macOS mounts itself, and an unmount started in Finder, are included. A volume that disappears while still mounted is recorded as `unmounted` and then `disappeared`. The log is append-only from the app’s point of view. It is an ordinary file in your home directory, so it is an operational record, not a sealed evidence store.

**Audit Log…** in the status menu shows the newest entries (up to 5,000 on screen). Export JSON writes the whole file as a JSON array. Export CSV writes the same rows. Reveal in Finder opens the log.

## Trusted disks

**Trust Selected Disk** stores a rule for the selected disk’s volume UUID. If Disk Arbitration did not report a volume UUID, the rule uses the media UUID. **Trusted Disks…** lists the rules and can remove them. The file is `~/Library/Application Support/Disk Arbitrator/trusted-disks.json`.

While Disk Arbitrator is activated, a matching disk is allowed to mount the way macOS requested. Every other disk is still blocked or remounted read-only. A match is an audit event named `rule_matched` with action `allowed_normal_mount`. Trust is a convenience for a disk you already know. It is not a write blocker, and it does not change a volume that is already mounted.

## Updates

The app links Sparkle 2 with Swift Package Manager. **Check for Updates…** and the Settings update controls are shown only when the build has both an appcast URL and an EdDSA public key. If either one is missing or empty, those controls stay hidden and Sparkle is not started. There is no missing-key alert on that path.

`Resources/DiskArbitrator-Info.plist` does not hardcode a repository. It substitutes two Xcode build settings:

| Build setting | Info.plist key |
| --- | --- |
| `SPARKLE_FEED_URL` | `SUFeedURL` |
| `SPARKLE_PUBLIC_ED_KEY` | `SUPublicEDKey` |

The plist values are `$(SPARKLE_FEED_URL:default=)` and `$(SPARKLE_PUBLIC_ED_KEY:default=)`. An empty or unset setting expands to an empty string, which this app treats as updates off. A build-phase script also clears a leftover `$(SPARKLE_...)` literal so it cannot ship in the app. The private signing key is not required to build.

### This fork

`Config/Sparkle.xcconfig` is the committed default for derekgboyer/Disk-Arbitrator. Local builds use:

* Feed URL: `https://github.com/derekgboyer/Disk-Arbitrator/releases/latest/download/appcast.xml`
* Public key: `kwGfxsca37dMWVwYY/YElw+U+vF6QDXHnXbqCpWNm18=`

Upstream, or another fork, should replace or clear those two lines. Clearing them still builds, and update checks stay off. xcconfig treats `//` as a comment, so the feed URL is written with `$(SPARKLE_URL_SLASH)` between `https:` and the host.

Optional local override, not committed:

```
cp Config/Sparkle.xcconfig.example Config/Sparkle.local.xcconfig
```

`Config/Sparkle.xcconfig` includes `Sparkle.local.xcconfig` when that file exists. Put your own feed URL and public key there. `Config/Sparkle.local.xcconfig` is gitignored.

### Release workflow

Pushing a `v*` tag runs `.github/workflows/release.yml`, which passes:

* `SPARKLE_FEED_URL=https://github.com/${GITHUB_REPOSITORY}/releases/latest/download/appcast.xml`
* `SPARKLE_PUBLIC_ED_KEY` from the repository **variable** `SPARKLE_PUBLIC_ED_KEY`, or from a secret of the same name when the variable is empty

That feed URL follows whichever repository runs the workflow. It is not hardcoded to this fork. Set the variable under Settings → Secrets and variables → Actions → Variables. The public key is safe to store as a variable. For this fork, set it to `kwGfxsca37dMWVwYY/YElw+U+vF6QDXHnXbqCpWNm18=`. If the variable and the secret are both empty, the release build keeps the public key from `Config/Sparkle.xcconfig`.

The private key stays the `SPARKLE_PRIVATE_KEY` secret. The workflow passes it to `generate_appcast` and `sign_update` when it is present. Do not commit the private key, and do not paste it into a pull request.

To rotate the pair, generate it once on a Mac from the Sparkle 2 tools archive (`generate_keys` is inside the `.tar.xz` on the [Sparkle releases](https://github.com/sparkle-project/Sparkle/releases)):

```
./bin/generate_keys
```

The tool prints the public key and stores the private key in your login keychain (account `ed25519`, service `https://sparkle-project.org`). Put the printed public key in `SPARKLE_PUBLIC_ED_KEY` (`Config/Sparkle.xcconfig` or `Config/Sparkle.local.xcconfig`, and the repository variable).

Export the private key for GitHub Actions:

```
security find-generic-password -a ed25519 -s "https://sparkle-project.org" -w
```

Store that output as the `SPARKLE_PRIVATE_KEY` secret. `./bin/generate_keys -h` lists the current export flags if you prefer the tool’s own export over the keychain command. The public key inside the app and the private key that signs `appcast.xml` have to be the pair from the same `generate_keys` run. Sparkle compares `CFBundleVersion` (the Xcode build number), which is 12 for version 0.10.2 and must increase for the next release. Version 0.10.2 (build 12) is ready to tag as `v0.10.2`.

## Releasing

Pull requests and branch pushes run `.github/workflows/build.yml`, which builds the universal Release app. The build and release workflows use current Node 24 GitHub Actions, including `actions/checkout@v5`.

Pushing a tag named `v*` (for example `v0.10.2`) runs `.github/workflows/release.yml` on a macOS runner. It builds the universal Release app, uploads a zip and a DMG to the GitHub release, and writes `appcast.xml` onto that same release. The feed contains only that release. Its enclosure is the app zip (`Disk.Arbitrator-<version>.zip`). Source archives and older compiled zips are not update items. The app’s feed URL is `https://github.com/<owner>/<repo>/releases/latest/download/appcast.xml` for the repository that ran the workflow.

The same job uploads source archives of the tagged commit: `Disk-Arbitrator-<version>-source.zip` and `Disk-Arbitrator-<version>-source.tar.gz`. `git archive` writes the source tree, including `LICENSE`, under a top-level folder named `Disk Arbitrator <version>`. GitHub still adds its own Source code (zip and tar.gz) links for the tag. It also uploads `README.md` (from `README.markdown`) and `ReleaseNotes.md` (from `ReleaseNotes.markdown`) as their own assets. The DMG includes `LICENSE`, `README.md`, and `ReleaseNotes.md` beside the app, in addition to any `README.html` and `ReleaseNotes.html` copied from the app bundle. The app zip is the application only.

Signing and notarization are optional. With none of the secrets below, the workflow ad-hoc signs the app (`codesign` identity `-`, hardened runtime) and still uploads the zip, DMG, source archives, README, changelog, and appcast. An appcast built without `SPARKLE_PRIVATE_KEY` has no EdDSA signature. Sparkle will reject that feed until you add the key and publish again.

Set the public key as an Actions variable (it is not a secret):

| Variable | Required | Purpose |
| --- | --- | --- |
| `SPARKLE_PUBLIC_ED_KEY` | For in-app update checks on a CI release | EdDSA public key passed into the app as `SPARKLE_PUBLIC_ED_KEY`. A secret of the same name is used only when the variable is empty |

Set these under the repository’s Actions secrets:

| Secret | Required | Purpose |
| --- | --- | --- |
| `SPARKLE_PRIVATE_KEY` | For a signed appcast | EdDSA private key passed to `generate_appcast` / `sign_update`. Never commit this |
| `BUILD_CERTIFICATE_BASE64` | No | Base64 of a Developer ID Application `.p12` |
| `P12_PASSWORD` | With the certificate | Password for that `.p12` |
| `KEYCHAIN_PASSWORD` | No | Temporary keychain password on the runner. The workflow creates one if this is empty |
| `APPLE_API_KEY_ID` | No | App Store Connect API key id, for `notarytool` |
| `APPLE_API_ISSUER_ID` | No | App Store Connect issuer id |
| `APPLE_API_KEY` | No | Contents of the `AuthKey_XXXX.p8` file |

Create the certificate secret from the `.p12` exported from Keychain Access:

```
base64 -i DeveloperID.p12 | pbcopy
```

Notarization runs only when the Developer ID certificate and the three App Store Connect secrets are all present. The workflow then staples the app and the DMG.

## Downloads

Builds from this fork are attached to [its releases](https://github.com/derekgboyer/Disk-Arbitrator/releases). Upstream history remains at [aburgh/Disk-Arbitrator](https://github.com/aburgh/Disk-Arbitrator/releases).

## Quick Start

### Installation

To install, drag the Disk Arbitrator application to the desired location, for example /Applications.

You may optionally want to have Disk Arbitrator automatically running every time you log in. There are two ways to do this:

* Add Disk Arbitrator to your Login Items in the User & Groups (or Accounts on older OS X versions) preference panel in System Preferences.

* Use the included "Install User Launch Agent" feature (accessible from the menu). On macOS 13 and later this registers a Launch Agent that is stored inside the app bundle. launchd starts Disk Arbitrator when you log in and relaunches it if it quits. Approve the item under System Settings > General > Login Items if macOS asks. This is the strongest option while you are logged in. It does not cover mounts that happen before login.

### Usage

When launched, it adds its icon to the status bar on the right side of the menu bar. The status bar icon indicates one of three states:

* Green: the utility is activated and in Block Mounts mode.

* Orange: the utility is activated and in Read-only mode.

* Gray: the utility is deactivated and attached disks will be automatically mounted by the system.

Disk Arbitrator continuously monitors for disks to appear and disappear and tracks the disks in the main window. When a new disk is attached, the system notifies Disk Arbitrator and gives it a chance to reject mounting of a disk volume.  Disk Arbitrator responds as such:

* When deactivated, it just observes the disk changes

* When activated and in Block Mounts mode, it simply rejects every new system attempt to mount a volume.

* When activated and in Read-only mode, it rejects the original mount action and automatically sends its own request to mount the volume, but it ensures the mount includes the option to make the file system read-only.  It also checks the file system type and, if it is HFS, it includes the flag to ignore the journal.

**Reminder:** Disk Arbitrator does its work by actively participating in the mounting process. If the utility is deactivated or is quit and not running, there is no protection from auto-mounting attached disks.  However, once a disk appears and the process of either mounting or rejecting the mount is finished, then Disk Arbitrator may be quit without affecting the state of the disk.

### Working With Disk Images

As of version 0.3.0, Disk Arbitrator has support for disk images.  

Using Disk Arbitrator's Attach Disk Image feature, attaching the disk image is effectively coordinated.  When "Attach Disk Image..." is selected from the menu, an open panel appears which includes additional options for attaching and mounting the disk image.  The default is to only attach the disk image.  When the "Open" button is clicked, Disk Arbitrator attaches the disk using hdiutil.  Once it is attached, Disk Arbitrator's normal behavior applies, so if it is activated and the mode is set to Read-Only, the volumes on the disk image will be mounted read-only.  If the mode is set to Block Mounts, the volumes will be ignored.

The disk image open panel includes an option to attempt to mount the disk image for when Disk Arbitrator isn't activated and is being used as a convenient means to attach a disk image.  When the mount option is used, Disk Arbitrator passes "-mount optional" to hdiutil, which attempts to attach and mount the disk image, but with the benefit that if the mount fails, the disk image is not detached.

Disk Arbitrator also supports drag and drop to attach a disk image.  Simply drag one or more disk images from a Finder window to Disk Arbitrator's list of disks to initiate attaching the disk images.  When using drag and drop, the default options include "-mount optional", so mounting is also attempted.  If the mount fails, the disk image remains attached and can be mounted manually.

Notes:

* Attempting to attach and mount a disk image outside of Disk Arbitrator, either by double-clicking it in the Finder or using hdiutil attach, will behave as before: the disk image will be attached, then the system will attempt to mount it, Disk Arbitrator will reject the mount, and the disk image will be unattached because the mount failed.

* If a disk image with a Software License Agreement is attached, Disk Arbitrator automatically replies "Yes" to the agreement.  Caveat Emptor.

### A Note On Dirty Journals

When set to Read-only mode, the mount request that Disk Arbitrator sends includes the option to ignore the journal, which is useful when the HFS file system was last detached without unmounting (e.g., the system crashed, or an external drive was unplugged without ejecting it). If you are working with a disk that was not cleanly ejected, then attempts to attach it read-only will normally fail because HFS knows the journal needs to be replayed and it is not allowed to make the changes, so it fails to mount.

Mounting a disk image with a dirty file system can be achieved by using a shadow file, but this is less than ideal. The shadow file protects the original disk image from changes, but the file system is mounted read-write.  A better option is to execute the two steps manually, using Terminal:

1. `hdiutil attach -nomount disk_image.dmg`
2. `mount_hfs -j -o rdonly /dev/diskx /mount/path`

Disk Arbitrator provides a convenient way to execute the second step, and a future version will perform both steps in one operation.
