//
//  GLACollectedItemContentHolderView.m
//  Blik
//
//  Created by Patrick Smith on 7/04/2015.
//  Copyright (c) 2015 Burnt Caramel. All rights reserved.
//

#import "GLACollectedItemContentHolderView.h"


@interface GLACollectedItemContentHolderView ()

@property(nonatomic) NSTrackingArea *mainTrackingArea;

@end

@implementation GLACollectedItemContentHolderView

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (NSSize)intrinsicContentSize
{
	CGFloat minimumHeight = (self.minimumHeight);
	if (minimumHeight == 0.0) {
		return [super intrinsicContentSize];
	}
	else {
		return NSMakeSize(NSViewNoInstrinsicMetric, minimumHeight);
	}
}

- (void)updateTrackingAreas
{
	NSTrackingArea *mainTrackingArea = (self.mainTrackingArea);
	if (!mainTrackingArea) {
		mainTrackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:( NSTrackingMouseEnteredAndExited | NSTrackingActiveInActiveApp | NSTrackingInVisibleRect ) owner:self userInfo:nil];
		[self addTrackingArea:mainTrackingArea];
		(self.mainTrackingArea) = mainTrackingArea;
	}
}

- (void)mouseEntered:(NSEvent *)theEvent
{
	id<GLACollectedItemContentHolderViewDelegate> delegate = (self.delegate);
	if (!delegate) {
		return;
	}
	
	[delegate mouseDidEnterContentHolderView:self];
}

- (void)mouseExited:(NSEvent *)theEvent
{
	id<GLACollectedItemContentHolderViewDelegate> delegate = (self.delegate);
	if (!delegate) {
		return;
	}
	
	[delegate mouseDidExitContentHolderView:self];
}

- (void)mouseUp:(NSEvent *)theEvent
{
	[(self.window) makeFirstResponder:self];
	
	id<GLACollectedItemContentHolderViewDelegate> delegate = (self.delegate);
	if (!delegate) {
		return;
	}
	
	[delegate didClickContentHolderView:self];
}

@end
