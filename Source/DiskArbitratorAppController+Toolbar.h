//
//  DiskArbitratorAppController+Toolbar.h
//  DiskArbitrator
//
//  Created by Aaron Burghardt on 2/7/10.
//  Copyright 2010 . All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DiskArbitratorAppController.h"

@interface AppController (AppControllerToolbar)


@end

void SetupToolbar(NSWindow *window, id delegate);

// Toolbar Item Identifier constants
NSString * const ToolbarItemMainIdentifier;
NSString * const ToolbarItemInfoIdentifier;
NSString * const ToolbarItemMountIdentifier;
NSString * const ToolbarItemEjectIdentifier;
NSString * const ToolbarItemAttachDiskImageIdentifier;
