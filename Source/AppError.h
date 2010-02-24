/*
 *  AppError.h
 *  DiskArbitrator
 *
 *  Created by Aaron Burghardt on 1/24/10.
 *  Copyright 2010 Aaron Burghardt. All rights reserved.
 *
 */

/*
 Log levels: 
 
 LOG_EMERG     A panic condition.  This is normally broadcast to all users.
 
 LOG_ALERT     A condition that should be corrected immediately, such as a corrupted system database.
 
 LOG_CRIT      Critical conditions, e.g., hard device errors.
 
 LOG_ERR       Errors.
 
 LOG_WARNING   Warning messages.
 
 LOG_NOTICE    Conditions that are not error conditions, but should possibly be handled specially.
 
 LOG_INFO      Informational messages.
 
 LOG_DEBUG     Messages that contain information normally of use only when debugging a program.

*/

#include <syslog.h>

void Log(NSInteger level, NSString *format, ...);

void SetAppLogLevel(NSInteger level);
void SetShouldLogToSyslog(BOOL flag);

extern NSString * const AppErrorDomain;
extern NSString * const AppLogLevelDefaultsKey;
extern NSString * const AppShouldEnableSyslogDefaultsKey;