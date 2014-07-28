//
//  GLAReminderManager.m
//  Blik
//
//  Created by Patrick Smith on 24/07/2014.
//  Copyright (c) 2014 Burnt Caramel. All rights reserved.
//

#import "GLAReminderManager.h"


NSString *GLAReminderDidSaveEventKitReminderNotification = @"GLAReminderDidSaveEventKitReminderNotification";
NSString *GLAReminderCouldNotSaveEventKitReminderNotification = @"GLAReminderCouldNotSaveEventKitReminderNotification";


@interface GLAReminderManager ()

@property(nonatomic) EKEventStore *eventStore;
@property(nonatomic) NSOperationQueue *backgroundOperationQueue;
@property(nonatomic) NSBlockOperation *operationToCreateEventStore;

@property(readwrite, nonatomic) EKAuthorizationStatus authorizationStatus;

@property(nonatomic) id fetchRemindersIdentifier;
@property(nonatomic) NSBlockOperation *operationToFetchAllReminders;
@property(nonatomic) NSArray *allReminders;

@property(nonatomic) NSArray *allReminderCalendars;

@end

@implementation GLAReminderManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        _backgroundOperationQueue = [NSOperationQueue new];
		
		[self updateAuthorizationStatus];
	}
    return self;
}

+ (instancetype)sharedReminderManager
{
	static GLAReminderManager *sharedReminderManager;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedReminderManager = [GLAReminderManager new];
	});
	
	return sharedReminderManager;
}

#pragma mark Getting set up early

- (void)createEventStoreIfNeeded
{
	[self useEventStoreOnMainQueue:YES block:^(GLAReminderManager *reminderManager, EKEventStore *eventStore) {
		// Do nothing, just set off the creation.
	}];
}

#pragma mark Requesting Access from the User

- (void)updateAuthorizationStatus
{
	(self.authorizationStatus) = [EKEventStore authorizationStatusForEntityType:EKEntityTypeReminder];
}

- (BOOL)isAuthorized
{
	return (self.authorizationStatus) == EKAuthorizationStatusAuthorized;
}

- (void)requestAccessToReminders:(EKEventStoreRequestAccessCompletionHandler)completion
{
	[self useEventStoreOnMainQueue:YES block:^(GLAReminderManager *reminderManager, EKEventStore *eventStore) {
		[eventStore requestAccessToEntityType:EKEntityTypeReminder completion:^(BOOL granted, NSError *error) {
			[reminderManager updateAuthorizationStatus];
			completion(granted, error);
		}];
	}];
}

- (NSArray *)calendarsForFindingReminders
{
	return @[(self.calendarForNewReminders)];
}

#pragma mark All Reminders

- (void)useAllReminders:(void(^)(NSArray *allReminders))allRemindersReceiver
{
	[self useAllRemindersOnMainQueue:YES block:^(GLAReminderManager *reminderManager, EKEventStore *eventStore, NSArray *allReminders) {
		allRemindersReceiver(allReminders);
	}];
}

- (void)invalidateAllReminders
{
	// This will fetch the reminders again next time they are requested.
	(self.operationToFetchAllReminders) = nil;
}

#pragma mark Finding Reminders

- (void)findRemindersWithTitle:(NSString *)title reminderReceiver:(void(^)(NSArray *reminders))reminderReceiver
{
	[self useAllRemindersOnMainQueue:NO block:^(GLAReminderManager *reminderManager, EKEventStore *eventStore, NSArray *allReminders) {
		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"title = %@", title];
		NSArray *matchingReminders = [allReminders filteredArrayUsingPredicate:predicate];
		[reminderManager performBlockOnMainQueue:^{
			reminderReceiver(matchingReminders);
		}];
	}];
}

#pragma mark Reminder Lists/Calendars

- (void)useCurrentAllReminderCalendars:(void(^)(NSArray *allReminderCalendars))allReminderCalendarsReceiver
{
	[self useEventStoreOnMainQueue:YES block:^(GLAReminderManager *reminderManager, EKEventStore *eventStore) {
		NSArray *allReminderCalendars = [eventStore calendarsForEntityType:EKEntityTypeReminder];
		allReminderCalendarsReceiver(allReminderCalendars);
	}];
}

#pragma mark Saving Reminders

- (void)createAndSaveEventKitReminderForReminder:(GLAReminder *)reminder
{
	if (reminder.eventKitReminder) {
		return;
	}
	
	EKReminder *eventKitReminder = [EKReminder reminderWithEventStore:(self.eventStore)];
	(eventKitReminder.calendar) = (self.calendarForNewReminders);
	
	(eventKitReminder.title) = (reminder.title);
	
	[reminder setCreatedEventKitReminder:eventKitReminder];
	
	[self useEventStoreOnMainQueue:NO block:^(GLAReminderManager *reminderManager, EKEventStore *eventStore) {
		NSError *error;
		BOOL saveSuccess = [eventStore saveReminder:eventKitReminder commit:YES error:&error];
		
		[reminderManager performBlockOnMainQueue:^{
			NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
			if (saveSuccess) {
				[nc postNotificationName:GLAReminderDidSaveEventKitReminderNotification object:reminder userInfo:nil];
			}
			else {
				[nc postNotificationName:GLAReminderCouldNotSaveEventKitReminderNotification object:reminder userInfo:
				 @{
				   @"error": error
				   }
				 ];
			}
		}];
	}];
}

#pragma mark - Private methods

- (void)didCreateEventStore:(EKEventStore *)eventStore
{
	if (!(self.calendarForNewReminders)) {
		(self.calendarForNewReminders) = (eventStore.defaultCalendarForNewReminders);
	}
}

- (NSOperation *)operationToCreateEventStoreSetUpIfNeeded
{
	if (!(self.operationToCreateEventStore)) {
		__weak GLAReminderManager *weakSelf = self;
		NSBlockOperation *operationToCreateEventStore = [NSBlockOperation blockOperationWithBlock:^{
			GLAReminderManager *self = weakSelf;

			EKEventStore *eventStore = [EKEventStore new];
			(self.eventStore) = eventStore;
			[self didCreateEventStore:eventStore];
		}];
		
		(operationToCreateEventStore.queuePriority) = NSOperationQueuePriorityHigh;
		[(self.backgroundOperationQueue) addOperation:operationToCreateEventStore];
		
		(self.operationToCreateEventStore) = operationToCreateEventStore;
	}
	
	return (self.operationToCreateEventStore);
}

- (NSOperation *)operationToFetchAllRemindersSetUpIfNeeded
{
	if (!(self.operationToFetchAllReminders)) {
		// A operation that does nothing but is started manually.
		NSBlockOperation *operationToFetchAllReminders = [NSBlockOperation blockOperationWithBlock:^{}];
		(self.operationToFetchAllReminders) = operationToFetchAllReminders;
		
		// The fetching is handled by the event store on a background thread.
		[self useEventStoreOnMainQueue:YES block:^(GLAReminderManager *reminderManager, EKEventStore *eventStore) {
			NSPredicate *predicate = [eventStore predicateForRemindersInCalendars:(self.calendarsForFindingReminders)];
			(reminderManager.fetchRemindersIdentifier) = [eventStore fetchRemindersMatchingPredicate:predicate completion:^(NSArray *reminders) {
				// If all reminders has been invalidated in the mean time.
				if (operationToFetchAllReminders != (reminderManager.operationToFetchAllReminders)) {
					return;
				}
				(reminderManager.allReminders) = reminders;
				(reminderManager.dateLastFetchedReminders) = [NSDate date];
				(reminderManager.fetchRemindersIdentifier) = nil;
				
				[operationToFetchAllReminders start];
			}];
		}];
	}
	
	return (self.operationToFetchAllReminders);
}

- (NSOperation *)useEventStoreOnMainQueue:(BOOL)onMainQueue block:(void (^)(GLAReminderManager *reminderManager, EKEventStore *eventStore))block
{
	__weak GLAReminderManager *weakSelf = self;
		
	NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
		GLAReminderManager *reminderManager = weakSelf;
		EKEventStore *eventStore = (reminderManager.eventStore);
		block(reminderManager, eventStore);
	}];
	// Event Store must be created first.
	[operation addDependency:[self operationToCreateEventStoreSetUpIfNeeded]];
	
	if (onMainQueue) {
		[[NSOperationQueue mainQueue] addOperation:operation];
	}
	else {
		[(self.backgroundOperationQueue) addOperation:operation];
	}
	
	return operation;
}

- (NSOperation *)useAllRemindersOnMainQueue:(BOOL)onMainQueue block:(void (^)(GLAReminderManager *reminderManager, EKEventStore *eventStore, NSArray *allReminders))block
{
	__weak GLAReminderManager *weakSelf = self;
	
	NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
		GLAReminderManager *reminderManager = weakSelf;
		EKEventStore *eventStore = (reminderManager.eventStore);
		NSArray *allReminders = (reminderManager.allReminders);
		block(reminderManager, eventStore, allReminders);
	}];
	// All Reminders must have been fetched first.
	[operation addDependency:[self operationToFetchAllRemindersSetUpIfNeeded]];
	
	if (onMainQueue) {
		[[NSOperationQueue mainQueue] addOperation:operation];
	}
	else {
		[(self.backgroundOperationQueue) addOperation:operation];
	}
	
	return operation;
}

- (void)performBlockOnMainQueue:(void(^)(void))block
{
	[[NSOperationQueue mainQueue] addOperationWithBlock:block];
}

@end
