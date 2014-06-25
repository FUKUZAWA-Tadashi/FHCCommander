//
//  exceptionHandler.m
//  fhcc
//
//  Created by 福澤 正 on 2014/09/08.
//  Copyright (c) 2014年 Fukuzawa Technology. All rights reserved.
//

#import <Foundation/Foundation.h>


static NSString *exceptionLogKey;

void exceptionHandler(NSException *exception)
{
    // ログをUserDefaultsに保存しておく。
    NSString *log = [NSString stringWithFormat:@"%@, %@, %@", exception.name, exception.reason, exception.callStackSymbols];
    NSLog(@"%@", log);
    [[NSUserDefaults standardUserDefaults] setValue:log forKey:exceptionLogKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

void setUncaughtExceptionLogSaver(NSString *key)
{
    exceptionLogKey = key;
    NSSetUncaughtExceptionHandler(exceptionHandler);
}
