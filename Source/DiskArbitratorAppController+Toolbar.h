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
extern NSString * const ToolbarItemMainIdentifier;
extern NSString * const ToolbarItemInfoIdentifier;
extern NSString * const ToolbarItemMountIdentifier;
extern NSString * const ToolbarItemEjectIdentifier;
extern NSString * const ToolbarItemAttachDiskImageIdentifier;
