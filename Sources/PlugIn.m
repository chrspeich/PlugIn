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


@implementation PlugIn

- (id) init
{
	self = [super init];
	if (self != nil) {
		[self setRegistryInfo:[NSDictionary dictionary]];
	}
	return self;
}


- (BOOL) setupError:(NSError**)anError
{
	if (anError != NULL) {
		*anError = [NSError errorWithDomain:@"" code:1 userInfo:Nil];
	}
	
	return NO;
}

- (void) setRegistryInfo:(NSDictionary*)anDictionary
{
	if ([anDictionary isEqualToDictionary:registryInfo])
		return;
	
	[self willChangeValueForKey:@"registryInfo"];
	
	[registryInfo release];
	registryInfo = [anDictionary retain];
	
	[self didChangeValueForKey:@"registryInfo"];
}

- (NSDictionary*) registryInfo
{
	return registryInfo;
}

@end
