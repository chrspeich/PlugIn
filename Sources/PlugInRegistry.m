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

#import "PlugInRegistry.h"
#import "PlugInPriorityProtocol.h"

#import "PILog.h"

NSComparisonResult sortCategorie(id firstObject, id secondObject, void *context)
{
	int firstPriority = 0;
	int secondPriority = 0;
	NSString* firstComparisonString = @"";
	NSString* secondComparisonString = @"";
	
	if ([firstObject conformsToProtocol:@protocol(PlugInPriorityProtocol)]) {
		firstPriority = [firstObject priority];
		firstComparisonString = [firstObject comparisonString];
	}
	
	if ([secondObject conformsToProtocol:@protocol(PlugInPriorityProtocol)]) {
		secondPriority = [secondObject priority];
		secondComparisonString = [secondObject comparisonString];
	}
	
	if (firstPriority < secondPriority)
		return NSOrderedAscending;
	else if (firstPriority > secondPriority)
		return NSOrderedDescending;
	else
		return [firstComparisonString compare:secondComparisonString];
}

@interface PlugInRegistry (PRIVAT)

- (void) sortAllCategories;
- (void) sortCategorie:(NSString*)anCategorie;

@end


#define CategorieAssert(categorie) NSParameterAssert((categorie) != Nil && [(categorie) rangeOfString:@"."].location == NSNotFound)

@implementation PlugInRegistry

- (id) init
{
	self = [super init];
	if (self != nil) {
		plugInCategories = [NSMutableDictionary new];
		hooks = [NSMutableDictionary new];
	}
	return self;
}

- (void) dealloc
{
	[plugInCategories release];
	[hooks release];
	
	[super dealloc];
}

- (void) addCategorie:(NSString*)anCategorie
{
	CategorieAssert(anCategorie);

	// We have already this Categorie in our Registry
	if ([plugInCategories valueForKey:anCategorie]) {
		PIDebugLog(@"%@ already in this Registry.");
		return;
	}
	
	[plugInCategories setValue:[NSArray array] forKey:anCategorie];
}

- (NSArray*) allCategories
{
	return [plugInCategories allKeys];
}

- (NSDictionary*) plugInCategories
{
	return plugInCategories;
}

- (BOOL) registerPlugInWithInfo:(NSDictionary*)anDictionary
{
	NSParameterAssert(anDictionary != Nil);
	
	NSString *categorie;
	NSEnumerator *categorieEnumerator;
		
	// Check if we've all these categories, add missing
	categorieEnumerator = [anDictionary keyEnumerator];
	
	while ((categorie = [categorieEnumerator nextObject])) {
		CategorieAssert(categorie);
		if ([plugInCategories valueForKey:categorie] == Nil) {
			[self addCategorie:categorie];
		}
	}
	
	// Now add the objects from each categorie from plugin
	categorieEnumerator = [anDictionary keyEnumerator];
	
	while ((categorie = [categorieEnumerator nextObject])) {		
		[[plugInCategories mutableArrayValueForKey:categorie] 
		 addObjectsFromArray:[anDictionary valueForKey:categorie]];
		[self sortCategorie:categorie];
	}
	
	return YES;
}

- (NSArray*) objectsForCategorie:(NSString*)anCategorie
{
	CategorieAssert(anCategorie);
	
	NSArray *categorie = [plugInCategories valueForKey:anCategorie];
	
	if (!categorie) {
		[NSException raise:@"Unknown PlugIn Category" 
					format:@"Categorie %@ is not in this Registry!", anCategorie];
		return Nil;
	}
	
	return categorie;
}

- (void) addObject:(id)anObject toCategorie:(NSString*)anCategorie
{
	NSParameterAssert(anObject != Nil);
	CategorieAssert(anCategorie);

	if (![plugInCategories valueForKey:anCategorie]) {
		[NSException raise:@"Unknown PlugIn Category" 
					format:@"Categorie %@ is not in this Registry!", anCategorie];
		return;
	}
	
	[[plugInCategories mutableArrayValueForKey:anCategorie] addObject:anObject];
	[self sortCategorie:anCategorie];
}

- (void) removeObject:(id)anObject
{
	NSParameterAssert(anObject != Nil);

	NSEnumerator *enumerator = [plugInCategories keyEnumerator];
	NSString *categorie;
	
	while ((categorie = [enumerator nextObject])) {
		[self removeObject:anObject fromCategorie:categorie];
	}
}

- (void) removeObject:(id)anObject fromCategorie:(NSString*)anCategorie
{
	NSParameterAssert(anObject != Nil);
	CategorieAssert(anCategorie);

	if (![plugInCategories valueForKey:anCategorie]) {
		[NSException raise:@"Unknown PlugIn Category" 
					format:@"Categorie %@ is not in this Registry!", anCategorie];
		return;
	}
	
	[[plugInCategories mutableArrayValueForKey:anCategorie] removeObject:anObject];
}

@end

@implementation PlugInRegistry (HOOKS)

- (NSInvocation*) registerTarget:(id)anObject withSelector:(SEL)selector forHook:(NSString*)hookName
{
	NSParameterAssert(anObject != Nil);
	NSParameterAssert(selector != Nil);
	NSParameterAssert(hookName != Nil);
	
	NSInvocation *invocation;
	
	invocation = [NSInvocation invocationWithMethodSignature:[anObject methodSignatureForSelector:selector]];
	[invocation setTarget:anObject];
	[invocation setSelector:selector];
	
	[self registerInvocation:invocation forHook:hookName];
	
	return invocation;
}

- (void) registerInvocation:(NSInvocation*)invocation forHook:(NSString*)hookName
{
	NSParameterAssert(invocation != Nil);
	NSParameterAssert([invocation target] != Nil);
	NSParameterAssert([invocation selector] != NULL);
	NSParameterAssert(hookName != Nil);
	
	// Look if this hook is already known, if not add it :)
	if (![hooks valueForKey:hookName])
		[hooks setValue:[NSArray array] forKey:hookName];
	
	[[hooks mutableArrayValueForKey:hookName] addObject:invocation];
}

- (void) invokeHook:(NSString*)hookName withObject:(id)object
{
	NSParameterAssert(hookName != Nil);
	// dictionary is optional
	
	NSArray *invocations;
	NSEnumerator *enumerator;
	NSInvocation *invocation;
	
	invocations = [hooks valueForKey:hookName];
	
	if (!invocations || ![invocations count]) {
		PINoticeLog(@"No hooks for '%@'", hookName);
		return;
	}
	
	enumerator = [invocations objectEnumerator];
	
	while ((invocation = [enumerator nextObject])) {
		// Ok, the target accepts arguments, the first argument will be our dictionary
		if ([[invocation methodSignature] numberOfArguments] > 0)
			[invocation setArgument:&object atIndex:2];
		
		// Great invoke it an catches the error...
		@try {
			PIDebugLog(@"Invoke hook '%@' on %@", hookName, invocation);
			[invocation invoke];
		}
		@catch (NSException * e) {
			PIErrorLog(@"Hook '%@' failed on %@: %@", hookName, invocation, e);
		}
	}
}

@end

@implementation PlugInRegistry (DEBUG)

- (NSString*) stringFromRegistryContent
{
	return [NSString stringWithFormat:@"Categories: %@\nHooks: %@", [plugInCategories description], [hooks description]];
}

@end

@implementation PlugInRegistry (PRIVAT)

- (void) sortAllCategories
{
	NSEnumerator* enumerator;
	NSString* categorie;
	
	enumerator = [[self allCategories] objectEnumerator];
	
	while ((categorie = [enumerator nextObject]))
		[self sortCategorie:categorie];
}

- (void) sortCategorie:(NSString*)anCategorie;
{
	CategorieAssert(anCategorie);
	
	[[plugInCategories mutableArrayValueForKey:anCategorie] sortUsingFunction:sortCategorie context:NULL];
}

@end

