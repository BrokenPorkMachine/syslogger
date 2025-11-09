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

    // Initialize logger
    self.logger = [[syslogger alloc] init];
    self.logger.outputDelegate = self;

    // Parse CLI arguments
    [self parseCommandLineArguments:args];

    if (runConsole) {
        // Console mode
        self.deviceManager = [[DeviceManager alloc] init];
        self.deviceManager.delegate = self.logger;
        [self.deviceManager startSyslogStream];

        // Keep the console app running
        [[NSRunLoop currentRunLoop] run];
    } else {
        // GUI mode
        [self createProgrammaticUI];

        self.deviceManager = [[DeviceManager alloc] init];
        self.deviceManager.delegate = self.logger;
        [self.deviceManager startSyslogStream];
    }
}

#pragma mark - CLI Argument Parsing

- (void)parseCommandLineArguments:(NSArray<NSString *> *)args {
    // Output options
    if ([args containsObject:@"--save-to-file"]) {
        self.logger.saveToFile = YES;
    }

    NSUInteger outputFileIndex = [args indexOfObject:@"--output-file"];
    if (outputFileIndex != NSNotFound && outputFileIndex + 1 < args.count) {
        self.logger.outputFilePath = args[outputFileIndex + 1];
    }

    NSUInteger formatIndex = [args indexOfObject:@"--format"];
    if (formatIndex != NSNotFound && formatIndex + 1 < args.count) {
        self.logger.outputFormat = args[formatIndex + 1];
    }

    // Display options
    if ([args containsObject:@"--no-timestamp"]) {
        self.logger.showTimestamp = NO;
    }
    if ([args containsObject:@"--no-host"]) {
        self.logger.showHost = NO;
    }
    if ([args containsObject:@"--no-pid"]) {
        self.logger.showPID = NO;
    }
    if ([args containsObject:@"--no-level"]) {
        self.logger.showLevel = NO;
    }
    if ([args containsObject:@"--color"]) {
        self.logger.colorize = YES;
    }

    NSUInteger maxLengthIndex = [args indexOfObject:@"--max-length"];
    if (maxLengthIndex != NSNotFound && maxLengthIndex + 1 < args.count) {
        self.logger.maxMessageLength = [args[maxLengthIndex + 1] integerValue];
    }

    // Filtering options
    NSUInteger minLevelIndex = [args indexOfObject:@"--min-level"];
    if (minLevelIndex != NSNotFound && minLevelIndex + 1 < args.count) {
        self.logger.minLogLevel = [ASLMessage levelFromString:args[minLevelIndex + 1]];
    }

    NSUInteger senderIndex = [args indexOfObject:@"--sender"];
    if (senderIndex != NSNotFound && senderIndex + 1 < args.count) {
        self.logger.senderFilter = args[senderIndex + 1];
    }

    NSUInteger messageIndex = [args indexOfObject:@"--message"];
    if (messageIndex != NSNotFound && messageIndex + 1 < args.count) {
        self.logger.messageFilter = args[messageIndex + 1];
    }

    if ([args containsObject:@"--important-only"]) {
        self.logger.importantOnly = YES;
    }
}

#pragma mark - UI Creation

- (void)createProgrammaticUI {
    // Create main window
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1000, 700)
                                              styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    [self.window center];
    [self.window setTitle:@"Syslog Viewer"];

    // Create container view
    NSView *contentView = self.window.contentView;

    // Create toolbar/controls area
    NSView *controlsView = [[NSView alloc] initWithFrame:NSMakeRect(0, 620, 1000, 80)];
    [contentView addSubview:controlsView];

    CGFloat xPos = 10;
    CGFloat yPos = 45;

    // Format label and popup
    NSTextField *formatLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(xPos, yPos, 60, 24)];
    formatLabel.stringValue = @"Format:";
    formatLabel.editable = NO;
    formatLabel.bordered = NO;
    formatLabel.backgroundColor = [NSColor clearColor];
    [controlsView addSubview:formatLabel];
    xPos += 65;

    self.formatPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(xPos, yPos, 150, 24)];
    [self.formatPopup addItemsWithTitles:@[@"idevicesyslog", @"standard", @"compact", @"verbose"]];
    [self.formatPopup setTarget:self];
    [self.formatPopup setAction:@selector(formatChanged:)];
    [controlsView addSubview:self.formatPopup];
    xPos += 160;

    // Level label and popup
    NSTextField *levelLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(xPos, yPos, 70, 24)];
    levelLabel.stringValue = @"Min Level:";
    levelLabel.editable = NO;
    levelLabel.bordered = NO;
    levelLabel.backgroundColor = [NSColor clearColor];
    [controlsView addSubview:levelLabel];
    xPos += 75;

    self.levelPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(xPos, yPos, 120, 24)];
    [self.levelPopup addItemsWithTitles:@[@"Debug", @"Info", @"Notice", @"Warning", @"Error", @"Critical", @"Alert", @"Emergency"]];
    [self.levelPopup setTarget:self];
    [self.levelPopup setAction:@selector(levelChanged:)];
    [controlsView addSubview:self.levelPopup];
    xPos += 130;

    // Important only checkbox
    self.importantOnlyCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(xPos, yPos, 140, 24)];
    [self.importantOnlyCheckbox setButtonType:NSButtonTypeSwitch];
    self.importantOnlyCheckbox.title = @"Important Only";
    [self.importantOnlyCheckbox setTarget:self];
    [self.importantOnlyCheckbox setAction:@selector(importantOnlyChanged:)];
    [controlsView addSubview:self.importantOnlyCheckbox];
    xPos += 150;

    // Clear button
    self.clearButton = [[NSButton alloc] initWithFrame:NSMakeRect(xPos, yPos, 80, 24)];
    self.clearButton.title = @"Clear";
    [self.clearButton setBezelStyle:NSBezelStyleRounded];
    [self.clearButton setTarget:self];
    [self.clearButton setAction:@selector(clearLog:)];
    [controlsView addSubview:self.clearButton];
    xPos += 90;

    // Save button
    self.saveButton = [[NSButton alloc] initWithFrame:NSMakeRect(xPos, yPos, 80, 24)];
    self.saveButton.title = @"Save...";
    [self.saveButton setBezelStyle:NSBezelStyleRounded];
    [self.saveButton setTarget:self];
    [self.saveButton setAction:@selector(saveLog:)];
    [controlsView addSubview:self.saveButton];

    // Second row of controls
    xPos = 10;
    yPos = 15;

    // Display options checkboxes
    self.timestampCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(xPos, yPos, 110, 24)];
    [self.timestampCheckbox setButtonType:NSButtonTypeSwitch];
    self.timestampCheckbox.title = @"Timestamp";
    self.timestampCheckbox.state = self.logger.showTimestamp ? NSControlStateValueOn : NSControlStateValueOff;
    [self.timestampCheckbox setTarget:self];
    [self.timestampCheckbox setAction:@selector(displayOptionsChanged:)];
    [controlsView addSubview:self.timestampCheckbox];
    xPos += 115;

    self.hostCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(xPos, yPos, 70, 24)];
    [self.hostCheckbox setButtonType:NSButtonTypeSwitch];
    self.hostCheckbox.title = @"Host";
    self.hostCheckbox.state = self.logger.showHost ? NSControlStateValueOn : NSControlStateValueOff;
    [self.hostCheckbox setTarget:self];
    [self.hostCheckbox setAction:@selector(displayOptionsChanged:)];
    [controlsView addSubview:self.hostCheckbox];
    xPos += 75;

    self.pidCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(xPos, yPos, 60, 24)];
    [self.pidCheckbox setButtonType:NSButtonTypeSwitch];
    self.pidCheckbox.title = @"PID";
    self.pidCheckbox.state = self.logger.showPID ? NSControlStateValueOn : NSControlStateValueOff;
    [self.pidCheckbox setTarget:self];
    [self.pidCheckbox setAction:@selector(displayOptionsChanged:)];
    [controlsView addSubview:self.pidCheckbox];
    xPos += 65;

    self.levelCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(xPos, yPos, 70, 24)];
    [self.levelCheckbox setButtonType:NSButtonTypeSwitch];
    self.levelCheckbox.title = @"Level";
    self.levelCheckbox.state = self.logger.showLevel ? NSControlStateValueOn : NSControlStateValueOff;
    [self.levelCheckbox setTarget:self];
    [self.levelCheckbox setAction:@selector(displayOptionsChanged:)];
    [controlsView addSubview:self.levelCheckbox];
    xPos += 80;

    // Sender filter
    NSTextField *senderLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(xPos, yPos, 60, 24)];
    senderLabel.stringValue = @"Sender:";
    senderLabel.editable = NO;
    senderLabel.bordered = NO;
    senderLabel.backgroundColor = [NSColor clearColor];
    [controlsView addSubview:senderLabel];
    xPos += 65;

    self.senderField = [[NSTextField alloc] initWithFrame:NSMakeRect(xPos, yPos, 150, 24)];
    self.senderField.placeholderString = @"Filter by sender...";
    [self.senderField setTarget:self];
    [self.senderField setAction:@selector(filterChanged:)];
    [controlsView addSubview:self.senderField];
    xPos += 160;

    // Message filter
    NSTextField *messageLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(xPos, yPos, 70, 24)];
    messageLabel.stringValue = @"Message:";
    messageLabel.editable = NO;
    messageLabel.bordered = NO;
    messageLabel.backgroundColor = [NSColor clearColor];
    [controlsView addSubview:messageLabel];
    xPos += 75;

    self.messageField = [[NSTextField alloc] initWithFrame:NSMakeRect(xPos, yPos, 150, 24)];
    self.messageField.placeholderString = @"Filter by message...";
    [self.messageField setTarget:self];
    [self.messageField setAction:@selector(filterChanged:)];
    [controlsView addSubview:self.messageField];

    // Create scroll view for text
    self.scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 620)];
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    self.textView = [[NSTextView alloc] initWithFrame:self.scrollView.bounds];
    self.textView.editable = NO;
    self.textView.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
    self.textView.autoresizingMask = NSViewWidthSizable;

    self.scrollView.documentView = self.textView;
    [contentView addSubview:self.scrollView];

    // Setup autoresizing
    controlsView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;

    [self.window makeKeyAndOrderFront:nil];
}

#pragma mark - UI Actions

- (void)formatChanged:(id)sender {
    NSString *selectedFormat = [self.formatPopup titleOfSelectedItem];
    self.logger.outputFormat = [selectedFormat lowercaseString];
}

- (void)levelChanged:(id)sender {
    NSString *selectedLevel = [self.levelPopup titleOfSelectedItem];
    self.logger.minLogLevel = [ASLMessage levelFromString:selectedLevel];
}

- (void)importantOnlyChanged:(id)sender {
    self.logger.importantOnly = (self.importantOnlyCheckbox.state == NSControlStateValueOn);
}

- (void)displayOptionsChanged:(id)sender {
    self.logger.showTimestamp = (self.timestampCheckbox.state == NSControlStateValueOn);
    self.logger.showHost = (self.hostCheckbox.state == NSControlStateValueOn);
    self.logger.showPID = (self.pidCheckbox.state == NSControlStateValueOn);
    self.logger.showLevel = (self.levelCheckbox.state == NSControlStateValueOn);
}

- (void)filterChanged:(id)sender {
    self.logger.senderFilter = self.senderField.stringValue.length > 0 ? self.senderField.stringValue : nil;
    self.logger.messageFilter = self.messageField.stringValue.length > 0 ? self.messageField.stringValue : nil;
}

- (void)clearLog:(id)sender {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.textView.string = @"";
    });
}

- (void)saveLog:(id)sender {
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.nameFieldStringValue = @"syslog.txt";
    savePanel.allowedFileTypes = @[@"txt", @"log"];

    [savePanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK) {
            NSURL *fileURL = savePanel.URL;
            NSError *error = nil;
            [self.textView.string writeToURL:fileURL atomically:YES encoding:NSUTF8StringEncoding error:&error];
            if (error) {
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"Save Failed";
                alert.informativeText = error.localizedDescription;
                [alert addButtonWithTitle:@"OK"];
                [alert runModal];
            }
        }
    }];
}

#pragma mark - Application Lifecycle

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
