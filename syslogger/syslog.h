//
//  syslog.h
//  syslogger
//
//  Created by failbr34k on 2025-11-09.
//

#import <Foundation/Foundation.h>
#import "DeviceManager.h"
#import "ASLMessage.h"

@class syslogger;

@protocol SysloggerOutput <NSObject>
- (void)syslogger:(syslogger *)logger didLogMessage:(NSString *)message;
@end

@interface syslogger : NSObject <DeviceManagerDelegate>

@property (nonatomic, weak) id<SysloggerOutput> outputDelegate;
@property (nonatomic, assign) BOOL saveToFile;
@property (nonatomic, strong) NSString *outputFilePath;

- (void)processSyslogData:(NSData *)data;

@end
