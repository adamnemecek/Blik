//
//  GLAProjectHighlightsViewController.h
//  Blik
//
//  Created by Patrick Smith on 23/10/2014.
//  Copyright (c) 2014 Patrick Smith. All rights reserved.
//

#import "GLAViewController.h"
#import "GLAInstructionsViewController.h"
#import "GLAProject.h"
#import "GLAHighlightedItem.h"
#import "GLAFileOpenerApplicationFinder.h"
#import "GLAButton.h"

@class GLAProjectViewController;


@interface GLAProjectHighlightsViewController : GLAViewController <NSTableViewDelegate, NSTableViewDataSource, NSMenuDelegate>

@property(nonatomic) IBOutlet NSTableView *tableView;
@property(nonatomic) IBOutlet NSLayoutConstraint *scrollLeadingConstraint;

@property(nonatomic) NSMenu *contextualMenu;

@property(nonatomic) IBOutlet GLAButton *openAllHighlightsButton;

@property(weak) IBOutlet GLAProjectViewController *parentViewController;

@property(strong, nonatomic) IBOutlet GLAInstructionsViewController *instructionsViewController;

@property(nonatomic) GLAProject *project;

@property(nonatomic) GLAFileOpenerApplicationFinder *openerApplicationCombiner;

- (IBAction)removedClickedItem:(id)sender;

@end
