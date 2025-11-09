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

// UI Controls
@property (strong, nonatomic) NSPopUpButton *formatPopup;
@property (strong, nonatomic) NSPopUpButton *levelPopup;
@property (strong, nonatomic) NSButton *timestampCheckbox;
@property (strong, nonatomic) NSButton *hostCheckbox;
@property (strong, nonatomic) NSButton *pidCheckbox;
@property (strong, nonatomic) NSButton *levelCheckbox;
@property (strong, nonatomic) NSButton *importantOnlyCheckbox;
@property (strong, nonatomic) NSTextField *senderField;
@property (strong, nonatomic) NSTextField *messageField;
@property (strong, nonatomic) NSButton *clearButton;
@property (strong, nonatomic) NSButton *saveButton;

@end

