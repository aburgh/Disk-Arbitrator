## Release Notes

#### 0.8

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
