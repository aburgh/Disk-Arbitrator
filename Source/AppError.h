/*
 *  AppError.h
 *  DiskArbitrator
 *
 *  Created by Aaron Burghardt on 1/24/10.
 *  Copyright 2010 Aaron Burghardt. All rights reserved.
 *
 */

void Log(int level, NSString *format, ...);

void SetShouldLogToSyslog(BOOL flag);
