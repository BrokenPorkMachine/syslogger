//
//  AppDelegate.m
//  syslogger
//
//  Created by failbr34k on 2025-11-09.
//

#import "AppDelegate.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSArray<NSString *> *args = [[NSProcessInfo processInfo] arguments];
    BOOL runConsole = [args containsObject:@"--console"];

    self.logger = [[syslogger alloc] init];
    self.logger.outputDelegate = self;

    if ([args containsObject:@"--save-to-file"]) {
        self.logger.saveToFile = YES;
        NSUInteger pathIndex = [args indexOfObject:@"--output-file"];
        if (pathIndex != NSNotFound && pathIndex + 1 < args.count) {
            self.logger.outputFilePath = args[pathIndex + 1];
        }
    }

    if (runConsole) {
        self.deviceManager = [[DeviceManager alloc] init];
        self.deviceManager.delegate = self.logger;
        [self.deviceManager startSyslogStream];
        
        // Keep the console app running
        [[NSRunLoop currentRunLoop] run];
    } else {
        [self createProgrammaticUI];
        
        self.deviceManager = [[DeviceManager alloc] init];
        self.deviceManager.delegate = self.logger;
        [self.deviceManager startSyslogStream];
    }
}

- (void)createProgrammaticUI {
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 800, 600)
                                              styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    [self.window center];
    [self.window setTitle:@"Syslog Viewer"];
    
    self.scrollView = [[NSScrollView alloc] initWithFrame:self.window.contentView.bounds];
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    self.textView = [[NSTextView alloc] initWithFrame:self.scrollView.bounds];
    self.textView.editable = NO;
    self.textView.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
    self.textView.autoresizingMask = NSViewWidthSizable;
    
    self.scrollView.documentView = self.textView;
    self.window.contentView = self.scrollView;
    
    [self.window makeKeyAndOrderFront:nil];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self.deviceManager stopSyslogStream];
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

#pragma mark - SysloggerOutput

- (void)syslogger:(syslogger *)logger didLogMessage:(NSString *)message {
    if (self.textView) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:[message stringByAppendingString:@"\n"]];
            [self.textView.textStorage appendAttributedString:attrString];
            [self.textView scrollRangeToVisible:NSMakeRange(self.textView.string.length, 0)];
        });
    } else {
        // Console mode
        printf("%s\n", [message UTF8String]);
    }
}

@end
