/*
 *  AppError.m
 *  DiskArbitrator
 *
 *  Created by Aaron Burghardt on 1/24/10.
 *  Copyright 2010 Aaron Burghardt. All rights reserved.
 *
 */

#import "AppError.h"
#include <syslog.h>


void Log(NSInteger level, NSString *format, ...)
{
	va_list args;
	NSString *formattedError;

	if (level > [[NSUserDefaults standardUserDefaults] integerForKey:AppLogLevelDefaultsKey])
		return;
	
	va_start(args, format);
	
	formattedError = [[NSString alloc] initWithFormat:format arguments:args];
	
	va_end(args);
	
	const char *utfFormattedError = [formattedError UTF8String];
	
	BOOL shouldUseSyslog = [[NSUserDefaults standardUserDefaults] boolForKey:AppShouldEnableSyslogDefaultsKey];
	
	if (shouldUseSyslog) 
		syslog((int)level, "%s\n", utfFormattedError);
	
	fprintf(stderr, "%s\n", utfFormattedError);
	
	[formattedError release];
}

void SetAppLogLevel(NSInteger level)
{
	[[NSUserDefaults standardUserDefaults] setInteger:level forKey:AppLogLevelDefaultsKey];	
}

void SetShouldLogToSyslog(BOOL flag)
{
	[[NSUserDefaults standardUserDefaults] setBool:flag forKey:AppShouldEnableSyslogDefaultsKey];
}

NSString * const AppErrorDomain = @"AppErrorDomain";
NSString * const AppLogLevelDefaultsKey = @"AppLogLevel";
NSString * const AppShouldEnableSyslogDefaultsKey = @"AppShouldEnableSyslog";