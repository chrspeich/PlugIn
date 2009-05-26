/*
 
 The PlugIn Framework
 Copyright (C) 2009 by Christian Speich <kleinweby@kleinweby.de>
 
 This file is part of the PlugIn Framework.
 
 The PlugIn Framework is free software: you can redistribute it and/or modify
 it under the terms of the GNU Lesser General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 The PlugIn Framework is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU Lesser General Public License for more details.
 
 You should have received a copy of the GNU Lesser General Public License
 along with the PlugIn Framework.  If not, see <http://www.gnu.org/licenses/>.
 
 */

#import "PlugIn.h"

NSString* PlugInErrorDomain = @"de.kleinweby.plugin";

static PlugInManager *sharedPlugInManager = nil;

@interface PlugInManager (PRIVATE)

- (void) setRegistry:(PlugInRegistry*)anRegistry;

- (BOOL) registerPlugIn:(PlugIn*)anPlugIn;

@end


@implementation PlugInManager

#pragma mark SingelTon

+ (PlugInManager*)sharedPlugInManager
{
    @synchronized(self) {
        if (sharedPlugInManager == nil) {
            [[self alloc] init]; // assignment not done here
        }
    }
    return sharedPlugInManager;
}

+ (id)allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if (sharedPlugInManager == nil) {
            sharedPlugInManager = [super allocWithZone:zone];
            return sharedPlugInManager;  // assignment and return on first allocation
        }
    }
    return nil; //on subsequent allocation attempts return nil
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain
{
    return self;
}

- (unsigned)retainCount
{
    return UINT_MAX;  //denotes an object that cannot be released
} 

- (void)release
{
    //do nothing
}

- (id)autorelease
{
    return self;
}

#pragma mark -

- (id) init
{
	self = [super init];
	if (self != nil) {
		loadedPlugins = [NSMutableArray new];
		[self setRegistry:[PlugInRegistry new]];
		[self setPlugInExtension:@"plugin"];
		
		[self setSearchPaths:[NSArray arrayWithObject:[[NSBundle mainBundle] builtInPlugInsPath]]];
	}
	return self;
}

- (void) dealloc
{
	[self setSearchPaths:Nil];
	[self setPlugInExtension:Nil];
	[self setRegistry:Nil];
	[loadedPlugins release];
	
	[super dealloc];
}

- (NSArray*) searchPaths
{
	return searchPaths;
}

- (void) setSearchPaths:(NSArray*)anArray
{
	if ([anArray isEqualToArray:searchPaths])
		return;
	
	[searchPaths release];
	searchPaths = [anArray retain];
}

- (NSArray*) loadedPlugins
{
	return loadedPlugins;
}

- (PlugInRegistry*) registry
{
	return registry;
}

- (void) setRegistry:(PlugInRegistry*)anRegistry
{
	if ([anRegistry isEqualTo:registry])
		return;
	
	[registry release];
	registry = [anRegistry retain];
}

- (NSString*) plugInExtension
{
	return plugInExtension;
}

- (void) setPlugInExtension:(NSString*)anExtension
{
	if ([anExtension isEqualToString:plugInExtension])
		return;
	
	[plugInExtension release];
	plugInExtension = [anExtension retain];
}

- (bool) loadAllPluginsError:(NSError**)anError
{
	NSEnumerator *searchPathEnumerator = [[self searchPaths] objectEnumerator];
	NSString *searchPath;
	
	while ((searchPath = [searchPathEnumerator nextObject])) {
		NSEnumerator *plugInPathEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:searchPath];
		NSString *plugInPath;
		
		while ((plugInPath = [plugInPathEnumerator nextObject])) {
			if ([[plugInPath pathExtension] isEqualToString:[self plugInExtension]])
				[self loadPlugIn:[searchPath stringByAppendingPathComponent:plugInPath] error:NULL];
		}
	}
	
	return YES;
}

- (bool) loadPlugIn:(NSString*)anPath error:(NSError**)anError
{
	NSParameterAssert(anPath != Nil);
	// anError is optional
	
	NSLog(@"DEBUG: Load plugIn '%@' from '%@'", [anPath lastPathComponent], [anPath stringByDeletingLastPathComponent]);
	
	NSBundle *plugIn = [NSBundle bundleWithPath:anPath];
	NSError *error = Nil;
	Class plugInClass;
	id plugInInstance;
	
	NSLog(@"DEBUG: Plugin identifier %@", [plugIn bundleIdentifier]);
	
	if (plugIn == Nil) {
		error = [NSError errorWithDomain:PlugInErrorDomain 
											 code:PlugInNotFound 
										 userInfo:Nil];
		
		*anError = error;
		return NO;
	}
	
	if ([plugIn isLoaded]) {
		NSLog(@"Plugin '%@' already loaded!", [anPath lastPathComponent]);
		return YES;
	}
	
	if (![plugIn load]) {
		if (anError != NULL) {
			error = [NSError errorWithDomain:PlugInErrorDomain 
									code:PlugInNotLoaded 
								userInfo:Nil];
		
			*anError = error;
		}
		return NO;
	}
	
	plugInClass = [plugIn principalClass];
	
	if (!plugInClass) {
		if (anError != NULL) {
			error = [NSError errorWithDomain:PlugInErrorDomain 
										code:PlugInNotLoaded 
									userInfo:Nil];
		
			*anError = error;
		}
		return NO;
	}
		
	if (![plugInClass isSubclassOfClass:[PlugIn class]]) {
		if (anError != NULL) {
			error = [NSError errorWithDomain:PlugInErrorDomain 
										code:PlugInNotCompatible 
									userInfo:Nil];
		
			*anError = error;
		}
		return NO;
	}
	
	
	plugInInstance = [[plugInClass alloc] init];
		
	if (![plugInInstance setupError:&error]) {
		[plugInInstance release];
		
		if (anError != NULL)
			*anError = error;
		
		return NO;
	}
	
	if (![self registerPlugIn:plugInInstance]) {
		[plugInInstance release];
		
		if (anError != NULL) {
			error = [NSError errorWithDomain:PlugInErrorDomain 
										code:PlugInNotRegistered 
									userInfo:Nil];
		
			*anError = error;
		}

		return NO;
	}

	[[self mutableArrayValueForKey:@"loadedPlugins"] addObject:plugInInstance];
	
	[plugInInstance release];
	
	NSLog(@"DEBUG: Plugin '%@' succesfully loaded.", [anPath lastPathComponent]);
		
	return YES;
}

- (BOOL) registerPlugIn:(PlugIn*)anPlugIn
{
	NSParameterAssert([anPlugIn isKindOfClass:[PlugIn class]]);
	
	NSDictionary *registryInfo;
	
	registryInfo = [anPlugIn registryInfo];

	if (!registryInfo)
		return NO;
	
	return [[self registry] registerPlugInWithInfo:registryInfo];
}

@end
