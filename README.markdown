## Introduction

Disk Arbitrator is Mac OS X forensic utility designed to help the user ensure correct forensic procedures are followed during imaging of a disk device. 
Disk Arbitrator is essentially a user interface to the Disk Arbitration framework, which enables a program to participate in the management of block 
storage devices, to include controlling the automatic mounting of file systems.  When enabled, Disk Arbitrator will block the mounting of file systems to avoid mounting as read-write and violating the integrity of the evidence.

It is important to note that Disk Arbitrator is *not* a software write blocker---it does not change the state of currently attached devices nor does it affect newly attached devices to force a device to be read-only. The user still must be careful to not accidently write to a disk with a command such as "dd".  Owing to this fact, a hardware or software write-blocker may still be desirable for the most sound procedure.  Disk Arbitrator compliments a write-blocker with additional useful features and eliminates the typical forensic recommendation to "disable disk arbitration."

## System Requirements

* PowerPC or Intel Mac
* Mac OS X 10.5 or later

## Future Features

* Automatic disk image mounting.  Currently, when the utility is set to block mounts, attaching a disk image with hdiutil will fail unless the -nomount option is also specified.  As a convenience, the utility will manage the attach step, initiated via a File > Open command or drag-and-drop, saving the user from a two-step process.

* Mount options dialog.  This provides fields to specify custom options and mount paths.

* Disk imaging.  Provide disk imaging ala dd capturing and hashing of the data. 

* Incorporate libewf and/or libaff to enable imaging to a variety of forensic file formats.
