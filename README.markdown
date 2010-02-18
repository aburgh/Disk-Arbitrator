## Introduction

Disk Arbitrator is Mac OS X forensic utility designed to help the user ensure correct forensic procedures are followed during imaging of a disk device. 
Disk Arbitrator is essentially a user interface to the Disk Arbitration framework, which enables a program to participate in the management of block 
storage devices, to include controlling the automatic mounting of file systems.  When enabled, Disk Arbitrator will block the mounting of file systems to avoid mounting as read-write and violating the integrity of the evidence.

It is important to note that Disk Arbitrator is *not* a software write blocker---it does not change the state of currently attached devices nor does it affect newly attached devices to force a device to be read-only. The user still must be careful to not accidently write to a disk with a command such as "dd".  Owing to this fact, a hardware or software write-blocker may still be desirable for the most sound procedure.  Disk Arbitrator compliments a write-blocker with additional useful features and eliminates the typical forensic recommendation to "disable disk arbitration."

## System Requirements

* PowerPC or Intel Mac
* Mac OS X 10.5 or later

## Quick Start

### Installation

Installation is very easy:

* Drag the Disk Arbitrator application to the desired location, though /Applications/Utilities is recommended.

You may optionally want to have Disk Arbitrator automatically running every time you log in.  There are two ways to do this:

* Add Disk Arbitrator to your Login Items in the Accounts preference panel in System Preferences.

* Use the included Disk Arbitrator Agent.plist. When installed, the system's launchd will automatically launch Disk Arbitrator when you log in, just like a Login Item. In addition, the plist contains a setting which tells launchd to "Keep Alive" the program, which instructs launchd to monitor the application and automatically relaunch it in the event of a crash or if otherwise quit. This offers the most assurance that Disk Arbitrator will be running whenever you are logged in. To install the agent, copy the Disk Arbitrator Agent.plist to /Library/LaunchAgents to install for all users or to /Users/username/Library/LaunchAgents to install for a single user.

### Usage

When launched, it adds it's icon to the status bar on the right side of the menu bar. The status bar icon indictates one of three states:

* Green: the utility is activated and in Block Mounts mode.

* Orange: the utility is activated and in Read-only mode.

* Gray: the utility is deactivated and attached disks will be automatically mounted by the system.

Disk Arbitrator continuously monitors for disks to appear and disappear and tracks the disks in the main window. When a new disk is attached, the system notifies Disk Arbitrator and gives it a chance to reject mounting of a disk volume.  Disk Arbitrator responds as such:

* When deactivated, it just observes the disk changes

* When activated and in Block Mounts mode, it simply rejects every new system attempt to mount a volume.

* When activated and in Read-only mode, it rejects the original mount action and automatically sends it's own request to mount the volume, but it ensures the mount includes the option to make the file system read-only.  It also checks the file system type and, if it is HFS, it includes the flag to ignore the journal. 

**Reminder:** Disk Arbitrator does it's work by actively participating in the mounting process. If the utility is deactived or is quit and not running, there is no protection from auto-mounting attached disks.  However, once a disk appears and the process of either mounting or rejecting the mount is finished, then Disk Arbitrator may be quit without affecting the state of the disk.

### Working With Disk Images

The fact that Disk Arbitrator rejects the initial mount attempt causes problems when working with disk images. Mounting a disk image is normally initiated by the user by double-clicking or using hdituil in the Terminal. This initiates a two-step process:

1. Attach the disk image to create a /dev/disk entry.  This is analogous to the act of plugging in an external drive.
2. Mount any file systems found on the disk image.

The difficulty with disk images is that either method, double-clicking or using hdiutil, attempts to perform both steps. But, if the mount doesn't succeed, then the system detaches the disk image. Using hdiutil, you can work around this by passing the "-nomount" flag so that only the attach step is executed.

A future version of Disk Arbitrator will include an feature to attach a disk image with the "-nomount" flag as a convenience for the user.

### A Note On Dirty Journals

When set to Read-only mode, the mount request that Disk Arbitrator sends includes the option to ignore the journal, which is useful when the HFS file system was last detached without unmounting (e.g., the system crashed, or an external drive was unplugged without ejecting it). If you are working with a disk that was not cleanly ejected, then attempts to attach it read-only will normally fail because HFS knows the journal needs to be replayed and it is not allowed to make the changes, so it fails to mount.

Mounting a disk image with a dirty file system can be achieved by using a shadow file, but this is less than ideal. The shadow file protects the original disk image from changes, but the file system is mounted read-write.  A better option is to execute the two steps manually, using Terminal:

1. hdiutil attach -nomount disk_image.dmg
2. mount_hfs -j -o rdonly /dev/diskx /mount/path

Disk Arbitrator provides a convenient way to execute the second step, and a future version will perform both steps in one operation.

## Future Features

* Automatic disk image mounting.  Currently, when the utility is set to block mounts, attaching a disk image with hdiutil will fail unless the -nomount option is also specified.  As a convenience, the utility will manage the attach step, initiated via a File > Open command or drag-and-drop, saving the user from a two-step process.

* Disk imaging.  Provide disk imaging ala dd capturing and hashing of the data. 

* Incorporate libewf and/or libaff to enable imaging to a variety of forensic file formats.

* Currently, Ejecting a disk fails if any file systems on the disk are mounted. The utility should automatically unmount file systems prior to attempting eject the disk.

## Support and Feedback

For questions, support, or feedback, contact me at aburgh at mac dot com.
