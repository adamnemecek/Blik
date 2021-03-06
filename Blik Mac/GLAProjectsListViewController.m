//
//  GLAProjectsListViewController.m
//  Blik
//
//  Created by Patrick Smith on 11/07/2014.
//  Copyright (c) 2014 Patrick Smith. All rights reserved.
//

#import "GLAProjectsListViewController.h"
// MODEL
#import "GLAProjectManager.h"
// VIEW
#import "GLAUIStyle.h"
#import "GLATableProjectRowView.h"
#import "GLAProjectOverviewTableCellView.h"
// CONTROLLERS
#import "GLAMainContentManners.h"
#import "GLAArrayTableDraggingHelper.h"


NSString *GLAProjectsListViewControllerDidChooseProjectNotification = @"GLA.projectListViewController.didChooseProject";
NSString *GLAProjectListsViewControllerDidPerformWorkOnProjectNowNotification = @"GLA.projectListViewController.didPerformWorkOnProjectNow";


@interface GLAProjectsListViewController () <GLAArrayTableDraggingHelperDelegate, NSMenuDelegate>

@property(copy, nonatomic) NSArray *projects;

@property(nonatomic) GLAArrayTableDraggingHelper *tableDraggingHelper;

@end

@implementation GLAProjectsListViewController

- (void)dealloc
{
	[self stopProjectManagingObserving];
}

- (void)prepareView
{
	[super prepareView];
	
	GLAUIStyle *uiStyle = [GLAUIStyle activeStyle];
	
	NSTableView *tableView = (self.tableView);
	(tableView.backgroundColor) = (uiStyle.contentBackgroundColor);
	(tableView.enclosingScrollView.backgroundColor) = (uiStyle.contentBackgroundColor);
	//(tableView.draggingDestinationFeedbackStyle) = NSTableViewDraggingDestinationFeedbackStyleGap;
	
	NSMenu *contextualMenu = (self.contextualMenu);
	(contextualMenu.delegate) = self;
	(tableView.menu) = contextualMenu;
	
	[tableView registerForDraggedTypes:@[[GLAProject objectJSONPasteboardType]]];
	
	NSScrollView *scrollView = [tableView enclosingScrollView];
	(scrollView.wantsLayer) = YES;
	
	(self.tableDraggingHelper) = [[GLAArrayTableDraggingHelper alloc] initWithDelegate:self];
	
	[self startProjectManagingObserving];
}

- (void)viewWillTransitionIn
{
	[super viewWillTransitionIn];
	
	[self startProjectManagingObserving];
	[self reloadAllProjects];
}

- (void)viewDidTransitionIn
{
	[super viewDidTransitionIn];
	
	NSTableView *tableView = (self.tableView);
	NSScrollView *scrollView = [tableView enclosingScrollView];
	[scrollView flashScrollers];
}

- (void)viewWillTransitionOut
{
	[super viewWillTransitionOut];
	
	[self stopProjectManagingObserving];
}

- (GLAProjectManager *)projectManager
{
	return [GLAProjectManager sharedProjectManager];
}

- (void)startProjectManagingObserving
{
	[self stopProjectManagingObserving];
	
	GLAProjectManager *pm = (self.projectManager);
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	
	// All Projects
	[nc addObserver:self selector:@selector(allProjectsDidChangeNotification:) name:GLAProjectManagerAllProjectsDidChangeNotification object:pm];
	
	// Now Project
	[nc addObserver:self selector:@selector(nowProjectDidChangeNotification:) name:GLAProjectManagerNowProjectDidChangeNotification object:pm];
}

- (void)stopProjectManagingObserving
{
	GLAProjectManager *pm = (self.projectManager);
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	
	// Stop observing any notifications on the project manager.
	[nc removeObserver:self name:nil object:pm];
}

- (void)allProjectsDidChangeNotification:(NSNotification *)note
{
	[self reloadAllProjects];
}

- (void)nowProjectDidChangeNotification:(NSNotification *)note
{
	[self reloadAllProjects];
}

#pragma mark Actions

@synthesize projects = _projects;

- (void)reloadAllProjects
{
	GLAProjectManager *projectManager = (self.projectManager);
	
	[projectManager loadAllProjectsIfNeeded];
	NSArray *projects = [projectManager copyAllProjects];
	
	if (!projects) {
		projects = @[];
	}
	(self.projects) = projects;
	
	[self setUpChildViewControllersForProjectCount:(projects.count)];
	
	[(self.tableView) reloadData];
}

- (void)setUpChildViewControllersForProjectCount:(NSUInteger)count
{
	NSView *hasContentView = (self.hasContentView);
	NSView *emptyContentView = (self.emptyContentViewController.view);
	
	BOOL hasProjects = (count > 0);
	if (hasProjects) {
		if (!(hasContentView.superview)) {
			[emptyContentView removeFromSuperview];
			[self fillViewWithChildView:hasContentView];
		}
	}
	else {
		if (!(emptyContentView.superview)) {
			[hasContentView removeFromSuperview];
			[self fillViewWithChildView:emptyContentView];
		}
	}
}

#if TRIAL

- (BOOL)projectRowIsAllowedInTrial:(NSInteger)row
{
	return (row <= 4);
}

#endif

- (GLAProject *)clickedProject
{
	NSInteger clickedRow = (self.tableView.clickedRow);
	if (clickedRow == -1) {
		return nil;
	}
	
#if TRIAL
	if (![self projectRowIsAllowedInTrial:clickedRow]) {
		return nil;
	}
#endif
	
	GLAProject *project = (self.projects)[clickedRow];
	
	return project;
}

- (IBAction)tableViewClicked:(id)sender
{
	GLAProject *project = (self.clickedProject);
	if (!project) {
		return;
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:GLAProjectsListViewControllerDidChooseProjectNotification object:self userInfo:@{@"project": project}];
}

- (IBAction)permanentlyDeleteClickedProject:(id)sender
{
	GLAProject *project = (self.clickedProject);
	if (!project) {
		return;
	}
	
	GLAMainContentManners *manners = [GLAMainContentManners sharedManners];
	[manners askToPermanentlyDeleteProject:project fromView:(self.view)];
}

- (IBAction)hideClickedProjectFromLauncherMenu:(NSMenuItem *)sender
{
	GLAProject *project = (self.clickedProject);
	if (!project) {
		return;
	}
	
	BOOL currentHidesFromLauncherMenu = (project.hideFromLauncherMenu);
	BOOL newHidesFromLauncherMenu = !currentHidesFromLauncherMenu;
	
	GLAProjectManager *pm = (self.projectManager);
	[pm setProject:project hidesFromLauncherMenu:newHidesFromLauncherMenu];
}

- (void)updateContextualMenu
{
	GLAProject *project = (self.clickedProject);
	if (!project) {
		return;
	}
	
	BOOL currentHidesInLauncherMenu = (project.hideFromLauncherMenu);
	(self.hideFromLauncherMenuItem.state) = currentHidesInLauncherMenu ? NSOnState : NSOffState;
}

- (IBAction)workOnProjectNowClicked:(NSButton *)senderButton
{
	NSInteger projectIndex = (senderButton.tag);
	if (projectIndex == -1) {
		return;
	}
	
#if TRIAL
	if (![self projectRowIsAllowedInTrial:projectIndex]) {
		return;
	}
#endif
	
	id project = (self.projects)[projectIndex];
	[[NSNotificationCenter defaultCenter] postNotificationName:GLAProjectListsViewControllerDidPerformWorkOnProjectNowNotification object:self userInfo:@{@"project": project}];
}

#pragma mark Table Dragging Helper Delegate

- (void)arrayEditorTableDraggingHelper:(GLAArrayTableDraggingHelper *)tableDraggingHelper makeChangesUsingEditingBlock:(GLAArrayEditingBlock)editBlock
{
	GLAProjectManager *pm = (self.projectManager);
	[pm editAllProjectsUsingBlock:editBlock];
}

- (BOOL)arrayEditorTableDraggingHelper:(GLAArrayTableDraggingHelper *)tableDraggingHelper canUseDraggingPasteboard:(NSPasteboard *)draggingPasteboard
{
	return [GLAProject canCopyObjectsFromPasteboard:draggingPasteboard];
}

#pragma mark Table View Data Source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return (self.projects.count);
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	GLAProject *project = (self.projects)[row];
	return project;
}

- (id<NSPasteboardWriting>)tableView:(NSTableView *)tableView pasteboardWriterForRow:(NSInteger)row
{
	GLAProject *project = (self.projects)[row];
	return project;
}

- (void)tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint forRowIndexes:(NSIndexSet *)rowIndexes
{
	return [(self.tableDraggingHelper) tableView:tableView draggingSession:session willBeginAtPoint:screenPoint forRowIndexes:rowIndexes];
}

- (void)tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation
{
	return [(self.tableDraggingHelper) tableView:tableView draggingSession:session endedAtPoint:screenPoint operation:operation];
}

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation
{
	return [(self.tableDraggingHelper) tableView:tableView validateDrop:info proposedRow:row proposedDropOperation:dropOperation];
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation
{
	return [(self.tableDraggingHelper) tableView:tableView acceptDrop:info row:row dropOperation:dropOperation];
}

#pragma mark Table View Delegate

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	GLATableProjectRowView *rowView = [tableView makeViewWithIdentifier:NSTableViewRowViewKey owner:nil];
	
#if TRIAL
	(rowView.enabled) = [self projectRowIsAllowedInTrial:row];
#endif
	
	return rowView;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	GLAProjectOverviewTableCellView *cellView = [tableView makeViewWithIdentifier:(tableColumn.identifier) owner:nil];
	
	GLAUIStyle *activeStyle = [GLAUIStyle activeStyle];
	
	GLAProject *project = (self.projects)[row];
	NSString *displayName = (project.name);
	(cellView.objectValue) = displayName;
	(cellView.textField.stringValue) = displayName;
	
	if (row < 6) {
		(cellView.shortcutField.integerValue) = (row + 1); // 0 to 1 based
	} else {
		(cellView.shortcutField.stringValue) = @"";
	}
	
	NSTextField *plannedDateTextField = (cellView.plannedDateTextField);
	(plannedDateTextField.textColor) = (activeStyle.lightTextDisabledColor);
	
	GLAProjectManager *pm = (self.projectManager);
	GLAProject *nowProject = (pm.nowProject);
	
	GLANavigationButton *workOnNowButton = (cellView.workOnNowButton);
	if ([(project.UUID) isEqual:(nowProject.UUID)]) {
		//(workOnNowButton.hidden) = YES;
		(workOnNowButton.enabled) = NO;
		(workOnNowButton.title) = NSLocalizedString(@"Working on Now", @"Title for Work on Now button in projects list that is already the now project");
	}
	else {
		(workOnNowButton.enabled) = YES;
		(workOnNowButton.title) = NSLocalizedString(@"Work on Now", @"Title for Work on Now button in an projects list");
		(workOnNowButton.target) = self;
		(workOnNowButton.action) = @selector(workOnProjectNowClicked:);
		(workOnNowButton.tag) = row;
		//(workOnNowButton.textHighlightColor) = ([GLAUIStyle activeStyle].deleteProjectButtonColor);
	}
	
#if TRIAL
	if (![self projectRowIsAllowedInTrial:row]) {
		(cellView.alphaValue) = 0.3;
		
		(workOnNowButton.enabled) = NO;
		(workOnNowButton.title) = NSLocalizedString(@"Limited by Trial", @"Title for Work on Now button when number of projects is past the trial limit");
	}
	else {
		(cellView.alphaValue) = 1.0;
	}
#endif
	
	return cellView;
}

#pragma mark NSMenuDelegate

- (void)menuNeedsUpdate:(NSMenu *)menu
{
	if (menu == (self.contextualMenu)) {
		[self updateContextualMenu];
	}
}

@end
