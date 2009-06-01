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

void PlugInInvokeHook(NSString* hookName, id object)
{
	[[[PlugInManager sharedPlugInManager] registry] invokeHook:hookName withObject:object];
}

@interface PlugInManager (PRIVATE)

- (void) setRegistry:(PlugInRegistry*)anRegistry;
- (void) setPlugInInformations:(NSMutableDictionary*)anDict;
- (void) updatePlugInInformations;
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
		[self setPlugInInformations:[NSMutableDictionary dictionary]];
		[self setRegistry:[PlugInRegistry new]];
		[self setPlugInExtension:@"plugin"];
		[self setPlugInSuperclass:[PlugIn class]];

		[self setSearchPaths:[NSArray arrayWithObject:[[NSBundle mainBundle] builtInPlugInsPath]]];
		[self updatePlugInInformations];
	}
	return self;
}

- (void) dealloc
{
	[self setPlugInInformations:Nil];
	[self setSearchPaths:Nil];
	[self setPlugInExtension:Nil];
	[self setRegistry:Nil];
	[loadedPlugins release];
	
	[super dealloc];
}

- (Class) plugInSuperclass
{
	return plugInSuperclass;
}
- (void) setPlugInSuperclass:(Class)anClass
{
	NSParameterAssert([anClass isSubclassOfClass:[PlugIn class]]);
	plugInSuperclass = anClass;
}

- (NSDictionary*) plugInInformations
{
	return plugInInformations;
}

- (void) setPlugInInformations:(NSMutableDictionary*)anDict
{
	if ([anDict isEqualToDictionary:plugInInformations])
		return;
	
	[plugInInformations release];
	plugInInformations = [anDict retain];
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
	NSEnumerator* enumerator = [plugInInformations keyEnumerator];
	NSString* identifier;
	
	while ((identifier = [enumerator nextObject])) {
		NSError* error = Nil;
		[self loadPlugInWithIdentifier:identifier error:&error];
	}
	
	NSLog(@"%@", plugInInformations);
	
	return YES;
}

- (bool) loadPlugInWithIdentifier:(NSString*)identifier error:(NSError**)anError
{
	NSParameterAssert(identifier != Nil);
	// anError is optional
	
	NSMutableDictionary* info;
	NSBundle* plugInBundle;
	Class plugInClass;
	id plugInInstance;
	NSError* error;
	
	info = [plugInInformations objectForKey:identifier];

	if (!info) {
		if (anError != NULL) {
			error = [NSError errorWithDomain:PlugInErrorDomain 
										code:PlugInNotFound 
									userInfo:Nil];
			
			*anError = error;
		}
		return NO;
	}
	
	if ([[info objectForKey:@"isLoaded"] boolValue]) {
		NSLog(@"Plugin '%@' already loaded!", identifier);
		return YES;
	}
	
	plugInBundle = [NSBundle bundleWithPath:[info objectForKey:@"path"]];
	
	if (![plugInBundle isLoaded] && ![plugInBundle load]) {
		if (anError != NULL) {
			error = [NSError errorWithDomain:PlugInErrorDomain 
										code:PlugInNotLoaded 
									userInfo:Nil];
			
			*anError = error;
		}
		return NO;
	}
	
	plugInClass = [plugInBundle principalClass];
	
	if (!plugInClass) {
		if (anError != NULL) {
			error = [NSError errorWithDomain:PlugInErrorDomain 
										code:PlugInNotLoaded 
									userInfo:Nil];
			
			*anError = error;
		}
		return NO;
	}
	
	if (![plugInClass isSubclassOfClass:[self plugInSuperclass]]) {
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
	
	[info setObject:plugInInstance forKey:@"instance"];
	[info setObject:@"YES" forKey:@"isLoaded"];
	
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

- (void) updatePlugInInformations
{
	NSEnumerator* searchPathEnumerator = [[self searchPaths] objectEnumerator];
	NSString *searchPath;
	
	while ((searchPath = [searchPathEnumerator nextObject])) {
		NSEnumerator *plugInPathEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:searchPath];
		NSString *plugInPath;
		
		while ((plugInPath = [plugInPathEnumerator nextObject])) {
			if ([[plugInPath pathExtension] isEqualToString:[self plugInExtension]]) {
				// Ok this seems to be an plugin :)
				NSMutableDictionary *dict;
				NSString* path = [searchPath stringByAppendingPathComponent:plugInPath];
				NSBundle* plugInBundle = [NSBundle bundleWithPath:path];
				NSString* identifier = [plugInBundle bundleIdentifier];
				
				dict = [plugInInformations objectForKey:identifier];
				
				if (!dict) {
					dict = [NSMutableDictionary dictionary];
				}
				else if ([[dict objectForKey:@"isLoaded"] boolValue]) {
					NSLog(@"Skip updating informations for %@ because it's currently loaded", identifier);
					continue;
				}
				
				[dict setObject:@"NO" forKey:@"isLoaded"];
				[dict setObject:path forKey:@"path"];
				[dict setObject:[NSArray array] forKey:@"dependencies"];
				[dict setObject:[NSNull null] forKey:@"instance"];
				
				[plugInInformations setObject:dict forKey:identifier];
			}
		}
	}
	
	NSLog(@"plugins %@", plugInInformations);
}

@end
