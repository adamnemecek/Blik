//
//  GLAAppDelegate.m
//  Blik
//
//  Created by Patrick Smith on 2/07/2014.
//  Copyright (c) 2014 Patrick Smith. All rights reserved.
//

#import "Blik-Swift.h"
#import <objc/runtime.h>
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>

#if TRIAL
#import <Paddle/Paddle.h>
#elif GLA_ENABLE_PADDLE_SDK
#import <Paddle-MAS/Paddle.h>
#endif

#import "GLAProjectManager.h"
#import "GLAPreferencesWindowController.h"
#import "GLAApplicationSettingsManager.h"

#define DO_FOLDER_QUERY_TEST 0 && DEBUG

#import "GLAFolderQuery.h"
#import "GLAFolderQueryResults.h"

@interface GLAAppDelegate (Objc) <NSUserInterfaceValidations>

@end

@implementation GLAAppDelegate (Objc)

- (void)awakeFromNib
{
	[self prepareIfNeeded];
}

#if TRIAL
- (void)showThanksForTrying
{
	[[Paddle sharedInstance] startLicensing:[self productInfo] timeTrial:NO withWindow:(self.mainWindowController.window)];
}
#endif

- (void)registerCrashDetection
{
	[[NSUserDefaults standardUserDefaults] registerDefaults:@{ @"NSApplicationCrashOnExceptions": @YES }];
	[Fabric with:@[CrashlyticsKit]];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[self registerCrashDetection];
	
	[self showMainWindow];
	//[self showDesktopWidget];
	
	[[GLAApplicationSettingsManager sharedApplicationSettingsManager] ensureAccessToPermittedApplicationsFolders];
	
	GLAProjectManager *pm = [GLAProjectManager sharedProjectManager];
	GLAMainSectionNavigator *navigator = [GLAMainSectionNavigator sharedMainSectionNavigator];
	
	(self.creatorThoughtsAssistant) = [[CreatorThoughtsAssistant alloc] initWithMenu:(self.creatorThoughtsMenu)];
	(self.helpGuidesAssistant) = [[GuideArticlesAssistant alloc] initWithPlaceholderMenuItem:(self.helpGuidesPlaceholderMenuItem)];
	(self.topProjectsAssistant) = [[TopProjectsAssistant alloc] initWithPlaceholderMenuItem:(self.topProjectsPlaceholderMenuItem) projectManager:pm navigator:navigator];
	
#if TRIAL || GLA_ENABLE_PADDLE_SDK
	Paddle *paddle = [Paddle sharedInstance];
	[paddle setProductId:@"499457"];
	[paddle setVendorId:@"8725"];
	[paddle setApiKey:@"ab5bb78fc07545f6f78772d2255bce71"];
#endif
	
	
#if DO_FOLDER_QUERY_TEST
	GLAFolderQuery *folderQuery = [[GLAFolderQuery alloc] initCreatingByEditing:^(id<GLAFolderQueryEditing> editor) {
		(editor.collectedFileForFolderURL) = [[GLACollectedFile alloc] initWithFileURL:[NSURL fileURLWithPath:NSHomeDirectory()]];
		(editor.tagNames) = @[@"Backburner"];
	}];
	
	GLAFolderQueryResults *folderQueryResults = [[GLAFolderQueryResults alloc] initWithFolderQuery:folderQuery];
	
	[folderQueryResults startSearching];
	(self.folderQueryResults) = folderQueryResults;
#endif
}

#if TRIAL
- (NSDictionary *)productInfo
{
	return
  @{
	kPADCurrentPrice: @"8.99",
	kPADDevName: @"Patrick Smith",
	kPADCurrency: @"USD",
	//kPADImage: @"http://www.macupdate.com/util/iconlg/17227.png",
	kPADProductName: @"Blik",
	//kPADTrialDuration: @"7",
	kPADTrialText: @"Get Blik without limitations by purchasing",
	kPADProductImage: [NSImage imageNamed:@"AppIcon.icns"],
	};
}
#endif

- (void)prepareIfNeeded
{
	if (self.hasPrepared) {
		return;
	}
	
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	
	(self.statusItemController) = [GLAStatusItemController new];
	[nc addObserver:self selector:@selector(toggleShowingMainWindowAndApplicationHidden:) name:GLAStatusItemControllerItemWasClickedNotification object:(self.statusItemController)];
	
	[nc addObserver:self selector:@selector(helpMenuDidBeginTracking:) name:NSMenuDidBeginTrackingNotification object:(self.mainHelpMenu)];
	
#if TRIAL
	(self.buyMenuItem.hidden) = false;
#else
	(self.buyMenuItem.hidden) = true;
#endif
	
	(self.hasPrepared) = YES;
}

- (BOOL)isShowingWindowController:(NSWindowController *)windowController
{
	if ((windowController != nil) && (windowController.isWindowLoaded)) {
		return [(windowController.window) isVisible];
	}
	else {
		return NO;
	}
}

#pragma mark Actions

- (IBAction)toggleShowingMainWindow:(id)sender
{
	[self toggleShowingMainWindowToggleApplicationHiddenAlso:NO];
}

- (IBAction)toggleShowingMainWindowAndApplicationHidden:(id)sender
{
	[self toggleShowingMainWindowToggleApplicationHiddenAlso:YES];
}

- (IBAction)toggleShowingMainWindowToggleApplicationHiddenAlso:(BOOL)toggleApplicationHidden
{
	NSApplication *app = NSApp;
	
	BOOL isShowing = (self.showingMainWindowController);
	if (toggleApplicationHidden) {
		isShowing = isShowing && (app.isActive);
	}
	
	if (!isShowing) {
		if (toggleApplicationHidden) {
			[app activateIgnoringOtherApps:YES];
		}
		
		[self showMainWindow];
	}
	else {
		if (toggleApplicationHidden) {
			[app hide:nil];
		}
		else {
			[self hideMainWindow];
		}
	}
}

- (void)toggleShowingStatusItem:(id)sender
{
	[(self.statusItemController) toggleShowingItem:sender];
}

- (IBAction)showAppPreferences:(id)sender
{
	[GLAPreferencesWindowController showWindow];
}

- (IBAction)showAppInMacAppStore:(id)sender
{
	NSURL *blikOnAppStoreURL = [NSURL URLWithString:@"macappstore://itunes.apple.com/us/app/blik/id955293604?mt=12"];
	
	[[NSWorkspace sharedWorkspace] openURL:blikOnAppStoreURL];
}

- (IBAction)openAppWebsite:(id)sender
{
	NSURL *blikWebsiteURL = [NSURL URLWithString:@"http://www.burntcaramel.com/blik/"];
	
	[[NSWorkspace sharedWorkspace] openURL:blikWebsiteURL];
}

- (void)openTwitterWebProfile:(id)sender
{
	NSURL *twitterProfileURL = [NSURL URLWithString:@"https://twitter.com/BlikApp"];
	
	[[NSWorkspace sharedWorkspace] openURL:twitterProfileURL];
}

- (IBAction)openFeedbackWebsite:(id)sender
{
	NSURL *blikSupportWebsiteURL = [NSURL URLWithString:@"http://www.burntcaramel.com/blik/support/"];
	
	[[NSWorkspace sharedWorkspace] openURL:blikSupportWebsiteURL];
}

- (IBAction)openFeedbackEmail:(id)sender
{
	NSURL *blikEmailURL = [NSURL URLWithString:@"mailto:blik@burntcaramel.com"];
	
	[[NSWorkspace sharedWorkspace] openURL:blikEmailURL];
}

#pragma mark Help Menu

- (void)updateActivityStatusMenuItem
{
	GLAProjectManager *projectManager = [GLAProjectManager sharedProjectManager];
	
	NSMenuItem *activityStatusMenuItem = (self.activityStatusMenuItem);
	if (activityStatusMenuItem) {
		NSString *status = (projectManager.statusOfCompletedActivity);
	#if DEBUG
		NSLog(@"%@", status);
	#endif
		/*NSArray *actionStati = [status componentsSeparatedByString:@"\n"];
		for (NSString *actionStatus in actionStati) {
			
		}*/
		(activityStatusMenuItem.title) = status;
	}
}

- (void)helpMenuDidBeginTracking:(NSNotification *)note
{
	//[self updateActivityStatusMenuItem];
}

#pragma mark Validating UI Items

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)anItem
{
	SEL action = (anItem.action);
	
	if ([(NSObject *)anItem isKindOfClass:[NSMenuItem class]]) {
		NSMenuItem *menuItem = (NSMenuItem *)anItem;
		BOOL stateAsBool = NO;
		
		if (sel_isEqual(@selector(toggleShowingStatusItem:), action)) {
			GLAStatusItemController *statusItemController = (self.statusItemController);
			stateAsBool = (statusItemController.showsItem);
		}
		else if (sel_isEqual(@selector(toggleHideMainWindowWhenInactive:), action)) {
			stateAsBool = (self.hidesMainWindowWhenInactive);
		}
		
		(menuItem.state) = stateAsBool ? NSOnState : NSOffState;
	}
	
	return YES;
}

@end
