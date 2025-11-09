//
//  AppDelegate.h
//  syslogger
//
//  Created by failbr34k on 2025-11-09.
//

#import <Cocoa/Cocoa.h>
#import "syslog.h"
#import "DeviceManager.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, SysloggerOutput>

@property (strong, nonatomic) NSWindow *window;
@property (strong, nonatomic) NSScrollView *scrollView;
@property (strong, nonatomic) NSTextView *textView;
@property (strong, nonatomic) syslogger *logger;
@property (strong, nonatomic) DeviceManager *deviceManager;

@end

