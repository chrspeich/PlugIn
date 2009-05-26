//
//  PlugInManager.h
//  XAMPP Control
//
//  Created by Christian Speich on 20.04.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

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
	NSMutableArray* loadedPlugins;
	PlugInRegistry* registry;
	
	NSString*		plugInExtension;
}

+ (PlugInManager*)sharedPlugInManager;

- (NSArray*) searchPaths;
- (NSString*) plugInExtension;
- (void) setPlugInExtension:(NSString*)anExtension;

- (bool) loadPlugIn:(NSString*)anPath error:(NSError**)anError;
- (bool) loadPlugInNamed:(NSString*)plugInName error:(NSError**)anError;
- (bool) loadAllPluginsError:(NSError**)anError;

- (NSArray*) loadedPlugins;
- (PlugInRegistry*) registry;

@end
