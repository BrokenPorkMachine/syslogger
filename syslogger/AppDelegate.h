//
//  AppDelegate.h
//  syslogger
//
//  Created by failbr34k on 2025-11-09.
//

#import <Cocoa/Cocoa.h>
#import "syslog.h"
#import "DeviceManager.h"

/**
 * AppDelegate - Main application controller
 *
 * Manages the iOS Syslog Viewer application lifecycle, UI, and device communication.
 * Supports both GUI and console modes with real-time log streaming and filtering.
 *
 * Features:
 * - Real-time syslog streaming from iOS devices via USB
 * - Advanced filtering by log level, sender, and message content
 * - Color-coded log display with multiple format options
 * - Export functionality with timestamped filenames
 * - Pause/Resume with message buffering
 * - Keyboard shortcuts for common actions
 * - Persistent preferences
 *
 * @version 1.0.0
 */
@interface AppDelegate : NSObject <NSApplicationDelegate, SysloggerOutput>

@property (strong, nonatomic) NSWindow *window;
@property (strong, nonatomic) NSScrollView *scrollView;
@property (strong, nonatomic) NSTextView *textView;
@property (strong, nonatomic) syslogger *logger;
@property (strong, nonatomic) DeviceManager *deviceManager;

@end

