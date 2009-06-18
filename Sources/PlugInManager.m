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
#import "PILog.h"

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

- (bool) loadAllPluginsError:(NSError**)anErrorOrNull
{
//  TODO: When anErrorOrNull is Null, all plugins should \
//	loaded with error:Null so that, they do not the 
//	unneccesary task of creating an NSError object
	
	NSEnumerator* enumerator;
	NSString* identifier;
	NSMutableArray* collectedErrors;
	
	enumerator = [plugInInformations keyEnumerator];
	collectedErrors = [NSMutableArray new];
	
	while ((identifier = [enumerator nextObject])) {
		NSError* error = Nil;
		
		[self loadPlugInWithIdentifier:identifier error:&error];
		
		if (error) {
			[collectedErrors addObject:error];
		}
	}
	
	if ([collectedErrors count] > 0) {
		if (anErrorOrNull != NULL) {
			NSError* error;
			
			error = [NSError errorWithDomain:PlugInErrorDomain 
										code:PlugInNotAllLoaded 
									userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
											  collectedErrors,kCollectedErrorsKey,Nil]];
			
			*anErrorOrNull = error;
		}
		
		[collectedErrors release];
		return NO;
	}

	[collectedErrors release];
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

	PINoticeLog(@"Load '%@'...", identifier);
	
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
		PINoticeLog(@"PlugIn '%@' already loaded!", identifier);
		return YES;
	}
	
	if ([[info objectForKey:@"dependencies"] count] > 0) {
		PIDebugLog(@"Calculating depencies for '%@'...", identifier);
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
	
	PINoticeLog(@"PlugIn '%@' loaded...", identifier);
	
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
	
	PIDebugLog(@"Begin updatePlugInInformations...");
	
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
				
				PIDebugLog(@"Update informations for '%@'...", identifier);
				
				dict = [plugInInformations objectForKey:identifier];
				
				if (!dict) {
					dict = [NSMutableDictionary dictionary];
				}
				else if ([[dict objectForKey:@"isLoaded"] boolValue]) {
					PIWarnLog(@"Skip updating informations for %@ because it's currently loaded", identifier);
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
	
	PIDebugLog(@"Updated plugInInformations: %@", plugInInformations);
	PIDebugLog(@"End updatePlugInInformations...");
}

@end
