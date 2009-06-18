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

#import "PILog.h"

#ifndef DefaultLogLevel
# ifdef DEBUG
#  define DefaultLogLevel PIMaxLogLevel
# else
#  define DefaultLogLevel PIWarnLogLevel
# endif /* DEBUG */
#endif /* DefaultLogLevel */

PILogLevel maxShownLogLevel = DefaultLogLevel;

void PIDefaultLogMessageDriver(PILogLevel level, NSString* message);

void (*PIMessageDriver)(PILogLevel, NSString*) = PIDefaultLogMessageDriver;

void PILog(PILogLevel level, NSString* format, ...)
{
	va_list args;
	
	va_start(args, format);
	
	PILogv(level, format, args);
	
	va_end(args);
}

void PILogv(PILogLevel level, NSString* format, va_list args)
{
	NSString* message;
	
	if (level > maxShownLogLevel)
		return;
	
	message = [[NSString alloc] initWithFormat:format arguments:args];
	
	PIMessageDriver(level, message);
	
	[message release];
}

void PIDebugLog(NSString* format, ...)
{
	va_list args;
	
	va_start(args, format);
	
	PILogv(PIDebugLogLevel, format, args);
	
	va_end(args);
}

void PINoticeLog(NSString* format, ...)
{
	va_list args;
	
	va_start(args, format);
	
	PILogv(PINoticeLogLevel, format, args);
	
	va_end(args);
}

void PIWarnLog(NSString* format, ...)
{
	va_list args;
	
	va_start(args, format);
	
	PILogv(PIWarnLogLevel, format, args);
	
	va_end(args);
}

void PIErrorLog(NSString* format, ...)
{
	va_list args;
	
	va_start(args, format);
	
	PILogv(PIErrorLogLevel, format, args);
	
	va_end(args);
}

void PISetMaxShownLogLevel(PILogLevel level)
{
	maxShownLogLevel = level;
}

void PISetMessageDriver(void (*driver)(PILogLevel, NSString*))
{
	PIMessageDriver = driver;
}

void PIDefaultLogMessageDriver(PILogLevel level, NSString* message)
{
	NSString* prefix;
	
	switch (level) {
		case PIErrorLogLevel:
			prefix = @"[ERROR]";
			break;
		case PIWarnLogLevel:
			prefix = @"[WARN]";
			break;
		case PINoticeLogLevel:
			prefix = @"[NOTICE]";
			break;
		case PIDebugLogLevel:
			prefix = @"[DEBUG]";
			break;
		default:
			prefix = @"";
			break;
	}
	
	NSLog(@"%@ %@", prefix, message);
}
