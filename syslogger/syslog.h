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

// Formatting options
@property (nonatomic, strong) NSString *outputFormat;  // "standard", "compact", "verbose", "idevicesyslog"
@property (nonatomic, assign) BOOL showTimestamp;
@property (nonatomic, assign) BOOL showHost;
@property (nonatomic, assign) BOOL showPID;
@property (nonatomic, assign) BOOL showLevel;
@property (nonatomic, assign) BOOL colorize;
@property (nonatomic, assign) NSInteger maxMessageLength;

// Filtering options
@property (nonatomic, assign) ASLLevel minLogLevel;
@property (nonatomic, strong) NSString *senderFilter;
@property (nonatomic, strong) NSString *messageFilter;
@property (nonatomic, assign) BOOL importantOnly;

- (void)processSyslogData:(NSData *)data;
- (ASLFormatter *)createFormatter;

@end
