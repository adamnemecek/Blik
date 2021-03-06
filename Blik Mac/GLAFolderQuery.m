//
//  GLAFolderQuery.m
//  Blik
//
//  Created by Patrick Smith on 14/02/2015.
//  Copyright (c) 2015 Burnt Caramel. All rights reserved.
//

#import "GLAFolderQuery.h"


@interface GLAFolderQuery ()

@property(readwrite, copy, nonatomic) GLACollectedFile *collectedFileForFolderURL;
@property(readwrite, copy, nonatomic) NSArray *tagNames;

@end

@interface GLAFolderQuery (GLAFolderQueryEditing) <GLAFolderQueryEditing>

@end

@implementation GLAFolderQuery

@synthesize tagNames = _tagNames;

- (instancetype)initCreatingByEditing:(void(^)(id<GLAFolderQueryEditing> editor))editingBlock
{
	self = [super init];
	if (self) {
		editingBlock(self);
	}
	return self;
}

- (instancetype)copyWithChangesFromEditing:(void(^)(id<GLAFolderQueryEditing> editor))editingBlock
{
	GLAFolderQuery *copy = [self copy];
	editingBlock(copy);
	
	return copy;
}

+ (NSValueTransformer *)collectedFileForFolderURLJSONTransformer
{
	return [NSValueTransformer mtl_JSONDictionaryTransformerWithModelClass:[GLACollectedFile class]];
}

- (NSString *)escapedStringForMetadataQuery:(NSString *)inputString
{
	NSMutableString *alteredString = [inputString mutableCopy];
	
	[alteredString replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:0 range:NSMakeRange(0, (alteredString.length))];
	[alteredString replaceOccurrencesOfString:@"'" withString:@"\'" options:0 range:NSMakeRange(0, (alteredString.length))];
	
	return alteredString;
}

- (NSString *)fileMetadataQueryRepresentation
{
	NSMutableArray *queryParts = [NSMutableArray new];
	
	NSArray *tagNames = (self.tagNames);
	if (tagNames) {
		NSMutableArray *tagNamesQueries = [NSMutableArray new];
		for (NSString *tagName in tagNames) {
			NSString *tagQuery = [NSString stringWithFormat:@"%@ = \"%@*\"cdwt", @"kMDItemUserTags", [self escapedStringForMetadataQuery:tagName]];
			[tagNamesQueries addObject:tagQuery];
		}
		
		[queryParts addObject:[tagNamesQueries componentsJoinedByString:@" || "]];
	}
	
	return [queryParts componentsJoinedByString:@" && "];
}

#pragma mark -

+ (NSSet *)availableTagNamesInsideFolderURL:(NSURL *)folderURL
{
	NSMutableSet *foundTagNames = [NSMutableSet new];
	
	NSArray *requiredResourceKeys = @[NSURLTagNamesKey];
	
	NSFileManager *fm = [NSFileManager defaultManager];
	NSDirectoryEnumerator *de = [fm enumeratorAtURL:folderURL includingPropertiesForKeys:requiredResourceKeys options:( NSDirectoryEnumerationSkipsPackageDescendants | NSDirectoryEnumerationSkipsHiddenFiles) errorHandler:^BOOL(NSURL *url, NSError *error) {
		return YES;
	}];
	
	for (NSURL *foundURL in de) {
		NSDictionary *resourceValues = [foundURL resourceValuesForKeys:requiredResourceKeys error:nil];

		if (!resourceValues) {
			continue;
		}
		
		NSArray *tagNamesForFile = resourceValues[NSURLTagNamesKey];
		if (tagNamesForFile) {
			[foundTagNames addObjectsFromArray:tagNamesForFile];
		}
	}
	
	return foundTagNames;
}

@end
