//
//  GLAAppDelegate.h
//  Blik
//
//  Created by Patrick Smith on 2/07/2014.
//  Copyright (c) 2014 Patrick Smith. All rights reserved.
//

@import Cocoa;
#import "GLAMainWindowController.h"
#import "GLAStatusItemController.h"


@interface GLAAppDelegate : NSObject <NSApplicationDelegate, NSUserInterfaceValidations>

//@property (assign) IBOutlet NSWindow *window;

@property (nonatomic) GLAMainWindowController *mainWindowController;

@property (nonatomic) GLAStatusItemController *statusItemController;

@property (assign, nonatomic) IBOutlet NSMenu *mainHelpMenu;
@property (assign, nonatomic) IBOutlet NSMenuItem *activityStatusMenuItem;

@property (assign, nonatomic) IBOutlet NSMenuItem *buyMenuItem;
@property (assign, nonatomic) IBOutlet NSMenuItem *buyMacAppStoreMenuItem;

- (IBAction)toggleShowingMainWindow:(id)sender;

- (IBAction)toggleShowingStatusItem:(id)sender;

- (IBAction)showAppPreferences:(id)sender;

- (IBAction)showAppInMacAppStore:(id)sender;
- (IBAction)openAppWebsite:(id)sender;
- (IBAction)openTwitterWebProfile:(id)sender;

@end
