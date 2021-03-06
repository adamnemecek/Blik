//
//	GLAPrototypeBWindowController.m
//	Blik
//
//	Created by Patrick Smith on 7/07/2014.
//	Copyright (c) 2014 Patrick Smith. All rights reserved.
//

#import "GLAMainWindowController.h"
#import "GLAUIStyle.h"
#import "GLATableProjectRowView.h"
#import "GLAMainContentManners.h"
// MODEL
#import "GLAApplicationSettingsManager.h"
#import "GLAProjectManager.h"
#import "GLACollection.h"
#import <objc/runtime.h>
@import QuartzCore;


#define USE_MAIN_CONTENT_VIEW_CONTROLLER 1


@interface GLAMainWindowController ()

@property(readwrite, nonatomic) GLAMainSectionNavigator *mainSectionNavigator;
@property(nonatomic) GLACollection *collectionWithDetailsBeingEdited;

@end

@implementation GLAMainWindowController

- (void)windowDidLoad
{
	[super windowDidLoad];
	
	NSWindow *window = (self.window);
	(window.movableByWindowBackground) = YES;
	
	(window.appearance) = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
	
	(window.title) = NSLocalizedString(@"Blik", @"Title for main window as it appears in Mission Control");
	//(window.level) = CGWindowLevelForKey(kCGDesktopIconWindowLevelKey) - 1;
	
	[NSApp addWindowsItem:window title:NSLocalizedString(@"Main Window", @"Title for main window as it appears in the Windows menu") filename:NO];
	
	[self updateFromSettings];
	
	(self.mainSectionNavigator) = [GLAMainSectionNavigator sharedMainSectionNavigator];
	
	[self setUpNotifications];
	[self setUpBaseUI];
	
	[self setUpContentViewController];
	[self setUpMainNavigationBarController];
	
	//TODO: add waiting to load animation
	GLAProjectManager *projectManager = [GLAProjectManager sharedProjectManager];
	[projectManager loadNowProjectIfNeeded];
	[projectManager loadAllProjectsIfNeeded];
	
	[self goToNowProject:nil];
}

- (GLAApplicationSettingsManager *)applicationSettingsManager
{
	return [GLAApplicationSettingsManager sharedApplicationSettingsManager];
}

#pragma mark Setting Up View Controllers

- (void)updateFromSettings
{
	GLAApplicationSettingsManager *settingsManager = (self.applicationSettingsManager);
	(self.window.hidesOnDeactivate) = (settingsManager.hidesMainWindowWhenInactive) || (settingsManager.hidesDockIcon);
	(self.window.level) = NSNormalWindowLevel;
}

- (void)setUpNotifications
{
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	
	GLAApplicationSettingsManager *settingsManager = (self.applicationSettingsManager);
	[nc addObserver:self selector:@selector(updateFromSettings) name:GLAApplicationSettingsManagerHideMainWindowWhenInactiveDidChangeNotification object:settingsManager];
	[nc addObserver:self selector:@selector(updateFromSettings) name:GLAApplicationSettingsManagerHidesDockIconDidChangeNotification object:settingsManager];
}

- (void)setUpBaseUI
{
	(self.barHolderView.translatesAutoresizingMaskIntoConstraints) = NO;
	(self.contentView.translatesAutoresizingMaskIntoConstraints) = NO;
	
	NSView *contentView = (self.contentView);
	(contentView.wantsLayer) = YES;
	(contentView.layer.backgroundColor) = ([GLAUIStyle activeStyle].contentBackgroundColor.CGColor);
}

- (void)setUpContentViewController
{
	GLAMainContentViewController *controller = [[GLAMainContentViewController alloc] init];
	(controller.delegate) = self;
	(controller.view) = (self.contentView);
	(controller.view.identifier) = @"contentView";
	
	(controller.sectionNavigator) = (self.mainSectionNavigator);
	
	(self.mainContentViewController) = controller;
}

- (NSString *)layoutConstraintIdentifierWithBase:(NSString *)baseIdentifier inView:(NSView *)view
{
	return [NSString stringWithFormat:@"%@--%@", (view.identifier), baseIdentifier];
}

- (NSLayoutConstraint *)layoutConstraintWithIdentifier:(NSString *)baseIdentifier view:(NSView *)view inHolderView:(NSView *)holderView
{
	NSString *constraintIdentifier = [self layoutConstraintIdentifierWithBase:baseIdentifier inView:view];
	NSArray *leadingConstraintInArray = [(holderView.constraints) filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"identifier = %@", constraintIdentifier]];
	
	if (leadingConstraintInArray.count == 0) {
		return nil;
	}
	else {
		return leadingConstraintInArray[0];
	}
}

- (void)setUpViewController:(NSViewController *)viewController constrainedToFillView:(NSView *)holderView
{
	(viewController.nextResponder) = self;
	
	NSView *view = (viewController.view);
	
	[holderView addSubview:view];
	
	// Interface Builder's default is to have this on for new view controllers in 10.9 for some reason.
	// I have disabled it where I remember to in the xib file.
	(view.translatesAutoresizingMaskIntoConstraints) = NO;
	
	NSLayoutConstraint *widthConstraint = [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:holderView attribute:NSLayoutAttributeWidth multiplier:1.0 constant:0.0];
	NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:holderView attribute:NSLayoutAttributeHeight multiplier:1.0 constant:0.0];
	NSLayoutConstraint *leadingConstraint = [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:holderView attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0.0];
	NSLayoutConstraint *topConstraint = [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:holderView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0];
	
	(leadingConstraint.identifier) = [self layoutConstraintIdentifierWithBase:@"leading" inView:view];
	(topConstraint.identifier) = [self layoutConstraintIdentifierWithBase:@"top" inView:view];
	
	[holderView addConstraints:@[widthConstraint, heightConstraint, leadingConstraint, topConstraint]];
}

- (void)addViewToContentViewIfNeeded:(NSView *)view layout:(BOOL)layout
{
	if (!(view.superview)) {
		[(self.mainContentViewController) fillViewWithChildView:view];
		
		if (layout) {
			[(self.mainContentViewController.view) layoutSubtreeIfNeeded];
		}
	}
}

- (NSLayoutConstraint *)layoutConstraintWithIdentifier:(NSString *)baseIdentifier inContentInnerView:(NSView *)view
{
	[self addViewToContentViewIfNeeded:view layout:YES];
	return [self layoutConstraintWithIdentifier:baseIdentifier view:view inHolderView:(self.contentView)];
}

- (void)setUpMainNavigationBarController
{
	if (self.mainNavigationBarController) {
		return;
	}
	
	GLAMainNavigationBarController *controller = [[GLAMainNavigationBarController alloc] initWithNibName:@"GLAMainNavigationBarController" bundle:nil];
	(controller.delegate) = self;
	(controller.view.identifier) = @"mainNavigationBar";
	
	(controller.sectionNavigator) = (self.mainSectionNavigator);
	
	(self.mainNavigationBarController) = controller;
	
	//[(self.mainNavigationBarController) fillViewWithInnerView:(controller.view)];
	[self setUpViewController:controller constrainedToFillView:(self.barHolderView)];
	
	NSView *navigationBarView = (controller.view);
	(navigationBarView.wantsLayer) = YES;
	(navigationBarView.layer.backgroundColor) = ([GLAUIStyle activeStyle].barBackgroundColor.CGColor);
}

#pragma mark Editing Projects

- (GLAMainSection *)currentSection
{
	return (self.mainSectionNavigator.currentSection);
}

- (void)goToSection:(GLAMainSection *)newSection
{
	[(self.mainSectionNavigator) goToSection:newSection];
}

- (void)goToPreviousSection
{
	[(self.mainSectionNavigator) goToPreviousSection];
}

- (void)workOnProjectNow:(GLAProject *)project
{
	[[GLAProjectManager sharedProjectManager] changeNowProject:project];
	
	[(self.mainSectionNavigator) goToNowProject];
}

- (void)editProject:(GLAProject *)project
{
	[(self.mainSectionNavigator) goToProject:project];
}

#pragma mark New Project

- (IBAction)addNewProject:(id)sender
{
	[(self.mainSectionNavigator) addNewProject];
}

#pragma mark New Collection

- (GLAProject *)projectToAddNewCollectionTo
{
	GLAMainSection *currentSection = (self.mainSectionNavigator.currentSection);
	if (!currentSection) {
		return nil;
	}
	
	if ((currentSection.isEditProject) || (currentSection.isNow)) {
		GLAEditProjectSection *editProjectSection = (GLAEditProjectSection *)currentSection;
		GLAProject *project = (editProjectSection.project);
		
		return project;
	}
	else {
		return nil;
	}
}

- (BOOL)canAddNewCollection
{
	GLAProject *project = (self.projectToAddNewCollectionTo);
	return (project != nil);
}

- (IBAction)addNewCollectedFilesCollection:(id)sender
{
	GLAProject *project = (self.projectToAddNewCollectionTo);
	if (project) {
		[(self.mainSectionNavigator) addNewCollectedFilesCollectionToProject:project];
	}
}

- (IBAction)addNewFilteredFolderCollection:(id)sender
{
	GLAProject *project = (self.projectToAddNewCollectionTo);
	if (project) {
		[(self.mainSectionNavigator) addNewFilteredFolderCollectionToProject:project];
	}
}

#pragma mark Collections

- (void)enterCollection:(GLACollection *)collection
{
	GLAMainSection *currentSection = (self.currentSection);
	NSAssert1((currentSection.isNow) || [currentSection isKindOfClass:[GLAEditProjectSection class]], @"When entering a collection, the previously current section (%@) must be now or an edit project section", currentSection);
	
	[(self.mainSectionNavigator) goToCollection:collection];
}

#pragma mark Actions

- (IBAction)goToAll:(id)sender
{
	[(self.mainSectionNavigator) goToAllProjects];
}

- (IBAction)goToNowProject:(id)sender
{
	[(self.mainSectionNavigator) goToNowProject];
}

- (BOOL)canWorkOnEditedProjectNow
{
	GLAMainSection *currentSection = (self.currentSection);
	return (currentSection.isEditProject);
}

- (IBAction)workOnEditedProjectNow:(id)sender
{
	if (!(self.canWorkOnEditedProjectNow)) {
		return;
	}
	
	GLAMainSection *currentSection = (self.currentSection);
	if ([currentSection isKindOfClass:[GLAEditProjectSection class]]) {
		GLAEditProjectSection *editProjectSection = (id)currentSection;
		GLAProject *project = (editProjectSection.project);
		NSAssert(project != nil, @"Must have a project to be able to work on it.");
		
		[self workOnProjectNow:project];
	}
}

- (BOOL)hasViewedProject
{
	GLAMainSection *currentSection = (self.currentSection);
	return ((currentSection.isEditProject) || (currentSection.isNowAndHasProject));
}

- (IBAction)editPrimaryFoldersOfViewedProject:(id)sender
{
	if (!(self.hasViewedProject)) {
		return;
	}
	
	GLAEditProjectSection *editProjectSection = (id)(self.currentSection);
	GLAProject *project = (editProjectSection.project);
	
	[(self.mainSectionNavigator) editPrimaryFoldersOfProject:project];
}

- (IBAction)toggleSeparateHighlightsIntoGroupsForViewedProject:(id)sender
{
	if (!(self.hasViewedProject)) {
		return;
	}
	
	GLAEditProjectSection *editProjectSection = (id)(self.currentSection);
	GLAProject *project = (editProjectSection.project);
	GLAProjectManager *pm = [GLAProjectManager sharedProjectManager];
	
	[pm editProject:project withBlock:^(id<GLAProjectEditing> _Nonnull projectEditor) {
		(projectEditor.groupHighlights) = !(projectEditor.groupHighlights);
	}];
}

- (IBAction)deleteViewedProject:(id)sender
{
	if ([self hasViewedProject]) {
		GLAMainSection *currentSection = (self.currentSection);
		if ([currentSection isKindOfClass:[GLAEditProjectSection class]]) {
			GLAEditProjectSection *editProjectSection = (id)currentSection;
			GLAProject *project = (editProjectSection.project);
			NSAssert(project != nil, @"Must have a project to be able to delete it.");
			
			GLAMainContentManners *manners = [GLAMainContentManners sharedManners];
			[manners askToPermanentlyDeleteProject:project fromView:(self.window.contentView)];
		}
	}
}

#pragma mark Validating UI Items

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)anItem
{
	SEL action = (anItem.action);
	if (sel_isEqual(@selector(workOnEditedProjectNow:), action)) {
		return [self canWorkOnEditedProjectNow];
	}
	else if (sel_isEqual(@selector(editPrimaryFoldersOfViewedProject:), action)) {
		return [self hasViewedProject];
	}
	else if (sel_isEqual(@selector(deleteViewedProject:), action)) {
		return [self hasViewedProject];
	}
	else if (sel_isEqual(@selector(addNewCollectedFilesCollection:), action)) {
		return [self canAddNewCollection];
	}
	else if (sel_isEqual(@selector(addNewFilteredFolderCollection:), action)) {
		return [self canAddNewCollection];
	}
	
	if ([(NSObject *)anItem isKindOfClass:[NSMenuItem class]]) {
		NSMenuItem *menuItem = (NSMenuItem *)anItem;
		BOOL enabled = YES;
		BOOL stateAsBool = NO;
		GLAMainSection *currentSection = (self.mainNavigationBarController.currentSection);
		
		if (sel_isEqual(@selector(goToAll:), action)) {
			stateAsBool = (currentSection.isAllProjects);
		}
		else if (sel_isEqual(@selector(goToNowProject:), action)) {
			stateAsBool = (currentSection.isNow);
		}
		else if (sel_isEqual(@selector(toggleSeparateHighlightsIntoGroupsForViewedProject:), action)) {
			if ((currentSection.isEditProject) || (currentSection.isNowAndHasProject)) {
				GLAEditProjectSection *editProjectSection = (id)(self.currentSection);
				NSUUID *projectUUID = (editProjectSection.project.UUID);
				GLAProjectManager *pm = [GLAProjectManager sharedProjectManager];
				GLAProject *project = [pm projectWithUUID:projectUUID];
				if (project) {
					stateAsBool = (project.groupHighlights);
				}
				else {
					enabled = NO;
				}
			}
			else {
				enabled = NO;
			}
		}
		
		(menuItem.state) = stateAsBool ? NSOnState : NSOffState;
		
		return enabled;
	}
	
	return YES;
}

#pragma mark Window Delegate

- (void)windowDidBecomeMain:(NSNotification *)notification
{
	[[GLAUIStyle activeStyle] primaryWindowDidBecomeMain:(self.window)];
}

- (void)windowDidResignMain:(NSNotification *)notification
{
	[[GLAUIStyle activeStyle] primaryWindowDidResignMain:(self.window)];
}

#if 1
- (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)client
{
	if (!(self.fieldEditor)) {
		NSTextView *fieldEditor = [NSTextView new];
		(fieldEditor.fieldEditor) = YES;
		(fieldEditor.richText) = NO;
		(self.fieldEditor) = fieldEditor;
	}
	
	NSTextView *fieldEditor = (self.fieldEditor);
	GLAUIStyle *uiStyle = [GLAUIStyle activeStyle];
	
	(fieldEditor.insertionPointColor) = (uiStyle.lightTextColor);
	
#if 0
	(fieldEditor.textColor) = (uiStyle.editedTextColor);
	//(nameTextField.drawsBackground) = YES;
	(fieldEditor.backgroundColor) = (uiStyle.editedTextBackgroundColor);
#endif
	
	return fieldEditor;
}
#endif

- (NSRect)window:(NSWindow *)window willPositionSheet:(NSWindow *)sheet usingRect:(NSRect)rect
{
	rect = (self.barHolderView.frame);
	rect.size.height = 0;
	
	return rect;
}

#pragma mark Project View Controller Notifications

- (void)activeProjectViewControllerDidBeginEditing:(NSNotification *)note
{
	(self.mainNavigationBarController.enabled) = NO;
}

- (void)activeProjectViewControllerDidEndEditing:(NSNotification *)note
{
	GLAProjectViewController *controller = (note.object);
	if (controller != (self.addedProjectViewController)) {
		(self.mainNavigationBarController.enabled) = YES;
	}
}

- (void)activeProjectViewControllerDidEnterCollection:(NSNotification *)note
{
	GLACollection *collection = (note.userInfo)[@"collection"];
	[self enterCollection:collection];
}

- (void)activeProjectViewControllerDidRequestPrimaryFolders:(NSNotification *)note
{
	GLAProjectViewController *controller = (note.object);
	GLAProject *project = (controller.project);
	
	[(self.mainSectionNavigator) editPrimaryFoldersOfProject:project];
}

- (void)activeProjectViewControllerDidRequestAddNewCollection:(NSNotification *)note
{
	GLAProjectViewController *controller = (note.object);
	GLAProject *project = (controller.project);
	
	[(self.mainSectionNavigator) addNewCollectionToProject:project];
}

#pragma mark GLAMainContentViewControllerDelegate

- (void)mainContentViewController:(GLAMainContentViewController *)contentViewController projectViewControllerDidBecomeActive:(GLAProjectViewController *)projectViewController
{
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	// Begin editing items
	[nc addObserver:self selector:@selector(activeProjectViewControllerDidBeginEditing:) name:GLAProjectViewControllerDidBeginEditingCollectionsNotification object:projectViewController];
	// Begin editing plan
	[nc addObserver:self selector:@selector(activeProjectViewControllerDidBeginEditing:) name:GLAProjectViewControllerDidBeginEditingPlanNotification object:projectViewController];
	// End editing items
	[nc addObserver:self selector:@selector(activeProjectViewControllerDidEndEditing:) name:GLAProjectViewControllerDidEndEditingCollectionsNotification object:projectViewController];
	// End editing plan
	[nc addObserver:self selector:@selector(activeProjectViewControllerDidEndEditing:) name:GLAProjectViewControllerDidEndEditingPlanNotification object:projectViewController];
	
	// Enter collection
	[nc addObserver:self selector:@selector(activeProjectViewControllerDidEnterCollection:) name:GLAProjectViewControllerDidEnterCollectionNotification object:projectViewController];
	[nc addObserver:self selector:@selector(activeProjectViewControllerDidRequestPrimaryFolders:) name:GLAProjectViewControllerDidRequestPrimaryFoldersNotification object:projectViewController];
	
	// Request add new collection
	[nc addObserver:self selector:@selector(activeProjectViewControllerDidRequestAddNewCollection:) name:GLAProjectViewControllerRequestAddNewCollectionNotification object:projectViewController];
}

- (void)mainContentViewController:(GLAMainContentViewController *)contentViewController projectViewControllerDidBecomeInactive:(GLAProjectViewController *)projectViewController
{
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	// Remove all that were added in -projectViewControllerDidBecomeActive:
	[nc removeObserver:self name:nil object:projectViewController];
}

- (void)mainContentViewController:(GLAMainContentViewController *)contentViewController projectsListViewController:(GLAProjectsListViewController *)projectsListViewController didClickOnProject:(GLAProject *)project
{
	[self editProject:project];
}

- (void)mainContentViewController:(GLAMainContentViewController *)contentViewController projectsListViewController:(GLAProjectsListViewController *)projectsListViewController didPerformWorkOnProject:(GLAProject *)project
{
	[self workOnProjectNow:project];
}

- (void)mainContentViewController:(GLAMainContentViewController *)contentViewController addNewProjectViewController:(GLAAddNewProjectViewController *)addNewProjectViewController didConfirmCreatingProject:(GLAProject *)project
{
	[self editProject:project];
}

- (void)mainContentViewController:(GLAMainContentViewController *)contentViewController addNewCollectionViewControllerDidBecomeActive:(GLAAddNewCollectionChooseNameAndColorViewController *)addNewCollectionViewController
{
	//(addNewCollectionViewController.pendingAddedCollectedFilesInfo) = (self.);
}

- (void)mainContentViewController:(GLAMainContentViewController *)contentViewController addNewCollectionViewController:(GLAAddNewCollectionChooseNameAndColorViewController *)addNewCollectionViewController didConfirmCreatingCollection:(GLACollection *)collection inProject:(GLAProject *)project
{
	[(self.mainSectionNavigator) goToCollection:collection];
}

#pragma mark Main Navigation

- (void)mainNavigationBarController:(GLAMainNavigationBarController *)controller handleWorkNowOnProject:(GLAProject *)project
{
	[self workOnProjectNow:project];
}

- (void)mainNavigationBarController:(GLAMainNavigationBarController *)controller handleEditDetailsForCollection:(GLACollection *)collection fromButton:(GLAButton *)button
{
	
}

@end
