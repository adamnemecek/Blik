//
//  GLADirectoryWatcher.m
//  Blik
//
//  Created by Patrick Smith on 31/01/2015.
//  Copyright (c) 2015 Burnt Caramel. All rights reserved.
//

#import "GLADirectoryWatcher.h"
@import CoreServices;
#import "GLAAccessedFileInfo.h"


@interface GLADirectoryWatcher ()

@property(nonatomic) NSMutableDictionary *directoryURLsToAccessedFileInfos;

@property(nonatomic) FSEventStreamRef fsEventStream;
@property(nonatomic) BOOL eventStreamHasStarted;
@property(readonly, nonatomic) dispatch_queue_t eventStreamQueue;

@property(nonatomic) FSEventStreamEventId lastReceivedEventID;

- (void)eventStreamQueue_receiveEventsForPaths:(NSArray *)paths numberOfEvents:(size_t)numEvents flags:(const FSEventStreamEventFlags[])eventFlags eventIDs:(const FSEventStreamEventId[])eventIds;

@end

@implementation GLADirectoryWatcher

void GLADirectoryWatcherCallback( ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, CFArrayRef eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[] )
{
	GLADirectoryWatcher *directoryWatcher = (__bridge GLADirectoryWatcher *)clientCallBackInfo;
	[directoryWatcher eventStreamQueue_receiveEventsForPaths:(__bridge NSArray *)eventPaths numberOfEvents:numEvents flags:eventFlags eventIDs:eventIds];
}

- (instancetype)initWithDelegate:(id<GLADirectoryWatcherDelegate>)delegate previousStateData:(NSData *)previousStateData
{
	self = [super init];
	if (self) {
		_delegate = delegate;
		
		_eventStreamQueue = dispatch_queue_create("com.burntcaramel.GLADirectoryWatcher", DISPATCH_QUEUE_SERIAL);
		
		_lastReceivedEventID = [self FSEventStreamEventIDWithStateData:previousStateData];
		
		_directoryURLsToAccessedFileInfos = [NSMutableDictionary new];
	}
	return self;
}

- (instancetype)init
{
	return [self initWithDelegate:nil previousStateData:nil];
}

- (void)dealloc
{
	[self clearEventStream];
}

- (void)clearEventStream
{
	if (_fsEventStream) {
		if (self.eventStreamHasStarted) {
			FSEventStreamStop(_fsEventStream);
			(self.eventStreamHasStarted) = NO;
		}
		FSEventStreamInvalidate(_fsEventStream);
		FSEventStreamRelease(_fsEventStream);
		_fsEventStream = NULL;
	}
}

NSString *GLADirectoryWatcherArchiverKey_FSEventStreamEventId = @"FSEventStreamEventId";

- (FSEventStreamEventId)lastReceivedEventID
{
	__block FSEventStreamEventId lastReceivedEventID;
	dispatch_sync((self.eventStreamQueue), ^{
		lastReceivedEventID = self->_lastReceivedEventID;
	});
	
	return lastReceivedEventID;
}

- (NSData *)stateData
{
	FSEventStreamRef eventStream = (self.fsEventStream);
	if (!eventStream) {
		return nil;
	}
	
	FSEventStreamEventId eventID = (self.lastReceivedEventID);
	
	NSMutableData *data = [NSMutableData new];
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
	[archiver encodeInt64:(eventID) forKey:GLADirectoryWatcherArchiverKey_FSEventStreamEventId];
	[archiver finishEncoding];
	
	return data;
}

- (FSEventStreamEventId)FSEventStreamEventIDWithStateData:(NSData *)stateData
{
	FSEventStreamEventId eventID = kFSEventStreamEventIdSinceNow;
	if (stateData) {
		NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:stateData];
		if ([unarchiver containsValueForKey:GLADirectoryWatcherArchiverKey_FSEventStreamEventId]) {
			eventID = [unarchiver decodeInt64ForKey:GLADirectoryWatcherArchiverKey_FSEventStreamEventId];
		}
		[unarchiver finishDecoding];
	}
	
	return eventID;
}

- (CFTimeInterval)eventStreamLatency
{
	return 1.0;
}

- (void)createEventStream
{
	[self clearEventStream];
	
	NSSet *directoryURLs = (self.directoryURLsToWatch);
	if (!directoryURLs || (directoryURLs.count) == 0) {
		return;
	}
	
#if DEBUG && 0
	NSLog(@"WATCHING directoryURLs %@", directoryURLs);
#endif
	
	NSArray *directoryPaths = [(directoryURLs.allObjects) valueForKey:@"path"];
	
	FSEventStreamContext eventStreamContext = {
		.version =  0,
		.info = (void *)CFBridgingRetain(self),
		.retain = CFRetain,
		.release = CFRelease,
		.copyDescription = NULL
	};
	
	FSEventStreamEventId previousEventID = (self.lastReceivedEventID);
	
	_fsEventStream = FSEventStreamCreate(kCFAllocatorDefault, (FSEventStreamCallback)GLADirectoryWatcherCallback, &eventStreamContext, (__bridge CFArrayRef)directoryPaths, previousEventID, (self.eventStreamLatency), kFSEventStreamCreateFlagUseCFTypes |kFSEventStreamCreateFlagWatchRoot | kFSEventStreamCreateFlagIgnoreSelf);
	
	FSEventStreamSetDispatchQueue(_fsEventStream, (self.eventStreamQueue));
	
	FSEventStreamStart(_fsEventStream);
	(self.eventStreamHasStarted) = YES;
}

- (void)setDirectoryURLsToWatch:(NSSet *)directoryURLs
{
	NSMutableDictionary *directoryURLsToAccessedFileInfos = (self.directoryURLsToAccessedFileInfos);
	[directoryURLsToAccessedFileInfos removeAllObjects];
	
	_directoryURLsToWatch = directoryURLs ? [directoryURLs copy] : nil;
	
	if (_directoryURLsToWatch) {
		for (NSURL *directoryURL in _directoryURLsToWatch) {
			directoryURLsToAccessedFileInfos[directoryURL] = [[GLAAccessedFileInfo alloc] initWithFileURL:directoryURL];
		}
	}
	
	[self createEventStream];
}

#pragma mark -

- (void)eventStreamQueue_receiveEventsForPaths:(NSArray *)paths numberOfEvents:(size_t)eventCount flags:(const FSEventStreamEventFlags[])eventFlags eventIDs:(const FSEventStreamEventId[])eventIds
{
	FSEventStreamRef eventStream = (self.fsEventStream);
	_lastReceivedEventID = FSEventStreamGetLatestEventId(eventStream);
	
	BOOL subdirectoriesDidChange = NO;
	BOOL mainDirectoriesWereMoved = NO;
	for (size_t eventIndex = 0; eventIndex < eventCount; eventIndex++) {
		if ((eventFlags[eventIndex] & kFSEventStreamEventFlagMustScanSubDirs)) {
			subdirectoriesDidChange = YES;
		}
		if ((eventFlags[eventIndex] & kFSEventStreamEventFlagRootChanged)) {
			mainDirectoriesWereMoved = YES;
		}
	}
	
	NSMutableArray *URLs = [NSMutableArray new];
	for (NSString *filePath in paths) {
		[URLs addObject:[NSURL fileURLWithPath:filePath]];
	}
	
#if DEBUG
	NSLog(@"DIRECTORIES did change %@", URLs);
#endif
	
	[[NSOperationQueue mainQueue] addOperationWithBlock:^{
		NSNotification *note = [NSNotification notificationWithName:GLADirectoryWatcherDirectoriesDidChangeNotification object:self];
		[[NSNotificationQueue defaultQueue] enqueueNotification:note postingStyle:NSPostASAP coalesceMask:(NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender) forModes:@[NSRunLoopCommonModes]];
	
		id<GLADirectoryWatcherDelegate> delegate = (self.delegate);
		if (delegate) {
			[delegate directoryWatcher:self directoriesURLsDidChange:URLs];
			
			if (subdirectoriesDidChange && [delegate respondsToSelector:@selector(directoryWatcher:subdirectoriesDidChangeForURLs:)]) {
				[delegate directoryWatcher:self subdirectoriesDidChangeForURLs:URLs];
			}
			
			if (mainDirectoriesWereMoved && [delegate respondsToSelector:@selector(directoryWatcher:mainDirectoriesWereMovedOrDeleted:)]) {
				[delegate directoryWatcher:self mainDirectoriesWereMovedOrDeleted:URLs];
			}
		}
		
	}];
}

@end

NSString *GLADirectoryWatcherDirectoriesDidChangeNotification = @"GLADirectoryWatcherDirectoriesDidChangeNotification";
