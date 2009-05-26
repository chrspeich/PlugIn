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

#import <Cocoa/Cocoa.h>

@class PlugInRegistry;

extern NSString* PlugInErrorDomain;

enum _PlugInError {
	PlugInNotFound = 1,
	PlugInNotLoaded,
	PlugInNotRegistered,
	PlugInNotCompatible
};

typedef enum _PlugInError PlugInError;

#define PlugInInvokeHook(hookName,object) [[[PlugInManager sharedPlugInManager] registry] invokeHook:(hookName) withObject:(object)]

@interface PlugInManager : NSObject {
	NSMutableArray* searchPaths;
	NSMutableDictionary* plugInInformations;
	
	NSMutableArray* loadedPlugins;
	PlugInRegistry* registry;
	Class			plugInSuperclass;
	
	NSString*		plugInExtension;
}

+ (PlugInManager*)sharedPlugInManager;

- (Class) plugInSuperclass;
- (void) setPlugInSuperclass:(Class)anClass;

- (NSArray*) searchPaths;
- (void) setSearchPaths:(NSArray*)searchPaths;

- (NSString*) plugInExtension;
- (void) setPlugInExtension:(NSString*)anExtension;

- (bool) loadPlugInWithIdentifier:(NSString*)identifier error:(NSError**)anError;
- (bool) loadAllPluginsError:(NSError**)anError;

- (NSArray*) loadedPlugins;
- (NSDictionary*) plugInInformations;
- (PlugInRegistry*) registry;

@end
