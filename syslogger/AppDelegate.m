//
//  AppDelegate.m
//  syslogger
//
//  Created by failbr34k on 2025-11-09.
//
//  Main application controller for iOS Syslog Viewer.
//  Handles UI creation, device management, log display, and user interactions.
//

#import "AppDelegate.h"

@interface AppDelegate ()
@property (nonatomic, strong) NSButton *startStopButton;
@property (nonatomic, strong) NSButton *clearButton;
@property (nonatomic, strong) NSButton *saveButton;
@property (nonatomic, strong) NSButton *pauseButton;
@property (nonatomic, strong) NSPopUpButton *filterLevelButton;
@property (nonatomic, strong) NSSearchField *searchField;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, assign) BOOL isPaused;
@property (nonatomic, assign) BOOL isStreaming;
@property (nonatomic, strong) NSMutableArray<NSString *> *pausedMessages;
@property (nonatomic, assign) ASLLevel filterLevel;
@property (nonatomic, strong) NSString *searchText;
@property (nonatomic, assign) NSInteger messageCount;
@property (nonatomic, assign) BOOL firstMessageReceived;
@property (nonatomic, strong) NSView *connectionIndicator;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSArray<NSString *> *args = [[NSProcessInfo processInfo] arguments];
    BOOL runConsole = [args containsObject:@"--console"];

    // Initialize logger
    self.logger = [[syslogger alloc] init];
    self.logger.outputDelegate = self;

    // Initialize filter settings
    self.isPaused = NO;
    self.isStreaming = NO;
    self.pausedMessages = [NSMutableArray array];
    self.filterLevel = ASLLevelDebug; // Show all by default
    self.searchText = @"";
    self.messageCount = 0;
    self.firstMessageReceived = NO;

    // Handle file output arguments
    if ([args containsObject:@"--save-to-file"]) {
        self.logger.saveToFile = YES;
        NSUInteger pathIndex = [args indexOfObject:@"--output-file"];
        if (pathIndex != NSNotFound && pathIndex + 1 < args.count) {
            self.logger.outputFilePath = args[pathIndex + 1];
        }
    }

    // Handle formatter style
    if ([args containsObject:@"--format"]) {
        NSUInteger formatIndex = [args indexOfObject:@"--format"];
        if (formatIndex != NSNotFound && formatIndex + 1 < args.count) {
            NSString *format = args[formatIndex + 1];
            [self.logger setFormatterStyle:format];
        }
    }

    // Handle colorize flag
    if ([args containsObject:@"--color"]) {
        [self.logger setColorize:YES];
    }

    if (runConsole) {
        // Console mode
        NSLog(@"========================================");
        NSLog(@"  iOS Device Syslog Viewer (Console)");
        NSLog(@"========================================");
        NSLog(@"Waiting for iOS device...");
        NSLog(@"Press Ctrl+C to exit");
        NSLog(@"");

        self.deviceManager = [[DeviceManager alloc] init];
        self.deviceManager.delegate = self.logger;
        [self.deviceManager startSyslogStream];
        self.isStreaming = YES;

        // Keep the console app running
        [[NSRunLoop currentRunLoop] run];
    } else {
        // GUI mode
        [self createProgrammaticUI];
        [self setupMenuBar];
        [self loadPreferences];

        self.deviceManager = [[DeviceManager alloc] init];
        self.deviceManager.delegate = self.logger;

        // Don't auto-start in GUI mode - user needs to press Start button
        [self updateStatus:@"Ready. Press 'Start' to begin logging."];
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
    [self.window setTitle:@"iOS Syslog Viewer"];
    [self.window setMinSize:NSMakeSize(800, 500)];

    // Create main content view
    NSView *contentView = self.window.contentView;

    // Create toolbar
    NSView *toolbar = [self createToolbar];
    [contentView addSubview:toolbar];

    // Create scroll view with text view
    CGFloat toolbarHeight = 80;
    NSRect scrollFrame = NSMakeRect(0, 0, contentView.bounds.size.width, contentView.bounds.size.height - toolbarHeight);

    self.scrollView = [[NSScrollView alloc] initWithFrame:scrollFrame];
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.hasHorizontalScroller = YES;
    self.scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.scrollView.borderType = NSBezelBorder;

    self.textView = [[NSTextView alloc] initWithFrame:self.scrollView.bounds];
    self.textView.editable = NO;
    self.textView.selectable = YES;
    self.textView.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
    self.textView.autoresizingMask = NSViewWidthSizable;
    self.textView.backgroundColor = [NSColor colorWithWhite:0.05 alpha:1.0];
    self.textView.textColor = [NSColor colorWithWhite:0.9 alpha:1.0];
    self.textView.insertionPointColor = [NSColor whiteColor];

    self.scrollView.documentView = self.textView;
    [contentView addSubview:self.scrollView];

    // Position toolbar
    toolbar.frame = NSMakeRect(0, contentView.bounds.size.height - toolbarHeight,
                              contentView.bounds.size.width, toolbarHeight);

    [self.window makeKeyAndOrderFront:nil];
}

- (void)setupMenuBar {
    NSMenu *mainMenu = [[NSMenu alloc] init];

    // App menu
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    NSMenu *appMenu = [[NSMenu alloc] init];

    [appMenu addItemWithTitle:@"About Syslog Viewer"
                       action:@selector(showAboutPanel)
                keyEquivalent:@""];

    [appMenu addItem:[NSMenuItem separatorItem]];

    [appMenu addItemWithTitle:@"Preferences..."
                       action:nil
                keyEquivalent:@","];

    [appMenu addItem:[NSMenuItem separatorItem]];

    [appMenu addItemWithTitle:@"Quit Syslog Viewer"
                       action:@selector(terminate:)
                keyEquivalent:@"q"];

    [appMenuItem setSubmenu:appMenu];
    [mainMenu addItem:appMenuItem];

    // File menu
    NSMenuItem *fileMenuItem = [[NSMenuItem alloc] init];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];

    NSMenuItem *exportItem = [fileMenu addItemWithTitle:@"Export..."
                                                 action:@selector(saveButtonClicked:)
                                          keyEquivalent:@"s"];
    [exportItem setTarget:self];

    [fileMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *clearItem = [fileMenu addItemWithTitle:@"Clear Log"
                                                action:@selector(clearButtonClicked:)
                                         keyEquivalent:@"k"];
    [clearItem setTarget:self];

    [fileMenuItem setSubmenu:fileMenu];
    [mainMenu addItem:fileMenuItem];

    // Edit menu (for copy/paste support)
    NSMenuItem *editMenuItem = [[NSMenuItem alloc] init];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];

    [editMenu addItemWithTitle:@"Copy"
                        action:@selector(copy:)
                 keyEquivalent:@"c"];

    [editMenu addItemWithTitle:@"Select All"
                        action:@selector(selectAll:)
                 keyEquivalent:@"a"];

    [editMenuItem setSubmenu:editMenu];
    [mainMenu addItem:editMenuItem];

    // View menu
    NSMenuItem *viewMenuItem = [[NSMenuItem alloc] init];
    NSMenu *viewMenu = [[NSMenu alloc] initWithTitle:@"View"];

    NSMenuItem *startStopItem = [viewMenu addItemWithTitle:@"Start/Stop Logging"
                                                    action:@selector(startStopButtonClicked:)
                                             keyEquivalent:@"l"];
    [startStopItem setTarget:self];

    NSMenuItem *pauseItem = [viewMenu addItemWithTitle:@"Pause/Resume"
                                                action:@selector(pauseButtonClicked:)
                                         keyEquivalent:@"p"];
    [pauseItem setTarget:self];

    [viewMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *filterItem = [viewMenu addItemWithTitle:@"Focus Filter Field"
                                                 action:@selector(focusSearchField:)
                                          keyEquivalent:@"f"];
    [filterItem setTarget:self];

    [viewMenuItem setSubmenu:viewMenu];
    [mainMenu addItem:viewMenuItem];

    // Window menu
    NSMenuItem *windowMenuItem = [[NSMenuItem alloc] init];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];

    [windowMenu addItemWithTitle:@"Minimize"
                          action:@selector(performMiniaturize:)
                   keyEquivalent:@"m"];

    [windowMenu addItemWithTitle:@"Zoom"
                          action:@selector(performZoom:)
                   keyEquivalent:@""];

    [windowMenuItem setSubmenu:windowMenu];
    [mainMenu addItem:windowMenuItem];

    // Help menu
    NSMenuItem *helpMenuItem = [[NSMenuItem alloc] init];
    NSMenu *helpMenu = [[NSMenu alloc] initWithTitle:@"Help"];

    [helpMenu addItemWithTitle:@"Syslog Viewer Help"
                        action:@selector(showHelp:)
                 keyEquivalent:@"?"];

    [helpMenuItem setSubmenu:helpMenu];
    [mainMenu addItem:helpMenuItem];

    [NSApp setMainMenu:mainMenu];
}

- (void)focusSearchField:(id)sender {
    if (self.searchField) {
        [self.window makeFirstResponder:self.searchField];
    }
}

- (void)showHelp:(id)sender {
    [self showAlertWithTitle:@"Syslog Viewer Help"
                     message:@"Keyboard Shortcuts:\n\n⌘L - Start/Stop Logging\n⌘P - Pause/Resume\n⌘K - Clear Log\n⌘S - Export Log\n⌘F - Focus Filter Field\n⌘A - Select All\n⌘C - Copy\n⌘Q - Quit\n\nTip: Use the filter field at the top to search through logs in real-time!"];
}

- (NSView *)createToolbar {
    NSView *toolbar = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 80)];
    toolbar.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    toolbar.wantsLayer = YES;
    toolbar.layer.backgroundColor = [[NSColor colorWithWhite:0.15 alpha:1.0] CGColor];

    CGFloat x = 10;
    CGFloat y = 45;

    // Start/Stop button (prominent green/red color)
    self.startStopButton = [[NSButton alloc] initWithFrame:NSMakeRect(x, y, 80, 25)];
    [self.startStopButton setTitle:@"Start"];
    [self.startStopButton setBezelStyle:NSBezelStyleRounded];
    [self.startStopButton setTarget:self];
    [self.startStopButton setAction:@selector(startStopButtonClicked:)];
    [toolbar addSubview:self.startStopButton];
    x += 90;

    // Clear button
    self.clearButton = [[NSButton alloc] initWithFrame:NSMakeRect(x, y, 80, 25)];
    [self.clearButton setTitle:@"Clear"];
    [self.clearButton setBezelStyle:NSBezelStyleRounded];
    [self.clearButton setTarget:self];
    [self.clearButton setAction:@selector(clearButtonClicked:)];
    [toolbar addSubview:self.clearButton];
    x += 90;

    // Pause button
    self.pauseButton = [[NSButton alloc] initWithFrame:NSMakeRect(x, y, 80, 25)];
    [self.pauseButton setTitle:@"Pause"];
    [self.pauseButton setBezelStyle:NSBezelStyleRounded];
    [self.pauseButton setTarget:self];
    [self.pauseButton setAction:@selector(pauseButtonClicked:)];
    [toolbar addSubview:self.pauseButton];
    x += 90;

    // Save/Export button
    self.saveButton = [[NSButton alloc] initWithFrame:NSMakeRect(x, y, 80, 25)];
    [self.saveButton setTitle:@"Export..."];
    [self.saveButton setBezelStyle:NSBezelStyleRounded];
    [self.saveButton setTarget:self];
    [self.saveButton setAction:@selector(saveButtonClicked:)];
    [toolbar addSubview:self.saveButton];
    x += 90;

    // Filter level label
    NSTextField *filterLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(x, y + 3, 80, 20)];
    [filterLabel setStringValue:@"Min Level:"];
    [filterLabel setBezeled:NO];
    [filterLabel setDrawsBackground:NO];
    [filterLabel setEditable:NO];
    [filterLabel setSelectable:NO];
    [filterLabel setTextColor:[NSColor whiteColor]];
    [toolbar addSubview:filterLabel];
    x += 85;

    // Filter level popup
    self.filterLevelButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(x, y, 100, 25)];
    [self.filterLevelButton addItemWithTitle:@"Emergency"];
    [self.filterLevelButton addItemWithTitle:@"Alert"];
    [self.filterLevelButton addItemWithTitle:@"Critical"];
    [self.filterLevelButton addItemWithTitle:@"Error"];
    [self.filterLevelButton addItemWithTitle:@"Warning"];
    [self.filterLevelButton addItemWithTitle:@"Notice"];
    [self.filterLevelButton addItemWithTitle:@"Info"];
    [self.filterLevelButton addItemWithTitle:@"Debug (All)"];
    [self.filterLevelButton selectItemAtIndex:7]; // Default to Debug (show all)
    [self.filterLevelButton setTarget:self];
    [self.filterLevelButton setAction:@selector(filterLevelChanged:)];
    [toolbar addSubview:self.filterLevelButton];
    x += 110;

    // Search field
    self.searchField = [[NSSearchField alloc] initWithFrame:NSMakeRect(x, y, 200, 25)];
    [self.searchField setPlaceholderString:@"Filter messages..."];
    [self.searchField setTarget:self];
    [self.searchField setAction:@selector(searchFieldChanged:)];
    [toolbar addSubview:self.searchField];

    // Connection status indicator (visual dot)
    self.connectionIndicator = [[NSView alloc] initWithFrame:NSMakeRect(x + 215, y + 8, 10, 10)];
    self.connectionIndicator.wantsLayer = YES;
    self.connectionIndicator.layer.cornerRadius = 5;
    self.connectionIndicator.layer.backgroundColor = [[NSColor grayColor] CGColor];
    [toolbar addSubview:self.connectionIndicator];

    // Status label (bottom row)
    self.statusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 10, 980, 20)];
    [self.statusLabel setStringValue:@"Ready"];
    [self.statusLabel setBezeled:NO];
    [self.statusLabel setDrawsBackground:NO];
    [self.statusLabel setEditable:NO];
    [self.statusLabel setSelectable:NO];
    [self.statusLabel setTextColor:[NSColor colorWithWhite:0.7 alpha:1.0]];
    [self.statusLabel setFont:[NSFont systemFontOfSize:11]];
    [self.statusLabel setAutoresizingMask:NSViewWidthSizable];
    [toolbar addSubview:self.statusLabel];

    return toolbar;
}

- (void)updateConnectionIndicator:(NSString *)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.connectionIndicator) return;

        if ([status containsString:@"connected"] || [status containsString:@"active"]) {
            self.connectionIndicator.layer.backgroundColor = [[NSColor colorWithRed:0.2 green:0.8 blue:0.2 alpha:1.0] CGColor];
        } else if ([status containsString:@"started"] || [status containsString:@"Logging"]) {
            self.connectionIndicator.layer.backgroundColor = [[NSColor colorWithRed:1.0 green:0.7 blue:0.0 alpha:1.0] CGColor];
        } else if ([status containsString:@"stopped"] || [status containsString:@"cleared"]) {
            self.connectionIndicator.layer.backgroundColor = [[NSColor redColor] CGColor];
        } else {
            self.connectionIndicator.layer.backgroundColor = [[NSColor grayColor] CGColor];
        }
    });
}

#pragma mark - Button Actions

- (void)startStopButtonClicked:(id)sender {
    if (self.isStreaming) {
        // Stop streaming
        [self.deviceManager stopSyslogStream];
        self.isStreaming = NO;
        [self.startStopButton setTitle:@"Start"];
        [self updateStatus:@"Logging stopped. Press 'Start' to resume."];
    } else {
        // Start streaming
        [self.deviceManager startSyslogStream];
        self.isStreaming = YES;
        [self.startStopButton setTitle:@"Stop"];
        [self updateStatus:@"Logging started. Waiting for device connection..."];
    }
}

- (void)clearButtonClicked:(id)sender {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.textView setString:@""];
        self.messageCount = 0;
        self.firstMessageReceived = NO;
        [self.pausedMessages removeAllObjects];
        [self updateStatus:@"Log cleared"];
    });
}

- (void)pauseButtonClicked:(id)sender {
    self.isPaused = !self.isPaused;

    if (self.isPaused) {
        [self.pauseButton setTitle:@"Resume"];
        [self updateStatus:@"Logging paused"];
    } else {
        [self.pauseButton setTitle:@"Pause"];
        [self updateStatus:@"Logging resumed"];

        // Flush paused messages
        dispatch_async(dispatch_get_main_queue(), ^{
            for (NSString *message in self.pausedMessages) {
                [self appendToTextView:message];
            }
            [self.pausedMessages removeAllObjects];
        });
    }
}

- (void)saveButtonClicked:(id)sender {
    if (!self.textView || self.textView.string.length == 0) {
        [self showAlertWithTitle:@"Nothing to Export" message:@"The log is empty. Start logging to capture device output."];
        [self updateStatus:@"Nothing to export - log is empty"];
        return;
    }

    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setNameFieldStringValue:[NSString stringWithFormat:@"syslog_export_%@.txt", [self currentTimestampString]]];
    [savePanel setAllowedFileTypes:@[@"txt", @"log"]];
    [savePanel setMessage:@"Export logs to file"];
    [savePanel setPrompt:@"Export"];

    [savePanel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            NSURL *url = [savePanel URL];
            if (!url) {
                [self showAlertWithTitle:@"Export Failed" message:@"Invalid file path selected."];
                return;
            }

            NSString *content = self.textView.string;
            NSError *error = nil;

            BOOL success = [content writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&error];

            if (!success || error) {
                NSLog(@"[AppDelegate] Error exporting file: %@", error);
                [self showAlertWithTitle:@"Export Failed"
                                 message:[NSString stringWithFormat:@"Failed to save file: %@", error.localizedDescription]];
                [self updateStatus:[NSString stringWithFormat:@"Export failed: %@", error.localizedDescription]];
            } else {
                NSUInteger lineCount = [[content componentsSeparatedByString:@"\n"] count];
                [self updateStatus:[NSString stringWithFormat:@"✓ Exported %lu lines to: %@", (unsigned long)lineCount, url.lastPathComponent]];
            }
        }
    }];
}

- (NSString *)currentTimestampString {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd_HH-mm-ss"];
    return [formatter stringFromDate:[NSDate date]];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:title];
        [alert setInformativeText:message];
        [alert setAlertStyle:NSAlertStyleWarning];
        [alert addButtonWithTitle:@"OK"];

        if (self.window) {
            [alert beginSheetModalForWindow:self.window completionHandler:nil];
        } else {
            [alert runModal];
        }
    });
}

- (void)filterLevelChanged:(id)sender {
    self.filterLevel = (ASLLevel)[self.filterLevelButton indexOfSelectedItem];
    [self updateStatus:[NSString stringWithFormat:@"Filter level: %@", [self.filterLevelButton titleOfSelectedItem]]];
}

- (void)searchFieldChanged:(id)sender {
    // Input validation: Sanitize search text
    NSString *rawText = [self.searchField stringValue];

    // Trim whitespace and limit length for performance
    self.searchText = [[rawText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
                       substringToIndex:MIN(rawText.length, 500)];

    if (self.searchText.length > 0) {
        [self updateStatus:[NSString stringWithFormat:@"Filtering: %@",
                           self.searchText.length > 50 ? [[self.searchText substringToIndex:50] stringByAppendingString:@"..."] : self.searchText]];
    } else {
        [self updateStatus:@"Ready"];
    }
}

- (void)updateStatus:(NSString *)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.statusLabel setStringValue:status];
        [self updateConnectionIndicator:status];
    });
}

#pragma mark - SysloggerOutput

- (void)syslogger:(syslogger *)logger didLogMessage:(NSString *)message {
    // Apply filters
    if (![self shouldDisplayMessage:message]) {
        return;
    }

    if (self.textView) {
        if (self.isPaused) {
            // Buffer messages while paused
            [self.pausedMessages addObject:message];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self appendToTextView:message];
            });
        }
    } else {
        // Console mode - just print
        printf("%s\n", [message UTF8String]);
        fflush(stdout);
    }
}

- (BOOL)shouldDisplayMessage:(NSString *)message {
    // Apply level filter (check if message contains level indicators)
    // This is a simple heuristic - proper filtering would parse the ASLMessage
    if (self.filterLevel < ASLLevelDebug) {
        NSArray *levelKeywords = @[@"Emergency", @"Alert", @"Critical", @"Error", @"Warning", @"Notice", @"Info"];
        BOOL matchesLevel = NO;

        for (NSInteger i = 0; i <= self.filterLevel; i++) {
            if ([message containsString:levelKeywords[i]]) {
                matchesLevel = YES;
                break;
            }
        }

        if (!matchesLevel) {
            return NO;
        }
    }

    // Apply search filter
    if (self.searchText && self.searchText.length > 0) {
        if (![message localizedCaseInsensitiveContainsString:self.searchText]) {
            return NO;
        }
    }

    return YES;
}

- (void)appendToTextView:(NSString *)message {
    // Color code based on log level
    NSColor *textColor = [self colorForMessage:message];

    NSDictionary *attributes = @{
        NSForegroundColorAttributeName: textColor,
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular]
    };

    NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:[message stringByAppendingString:@"\n"]
                                                                     attributes:attributes];
    [self.textView.textStorage appendAttributedString:attrString];

    // Auto-scroll to bottom
    [self.textView scrollRangeToVisible:NSMakeRange(self.textView.string.length, 0)];

    // Update status with message count
    self.messageCount++;

    // Show "device connected and logging" on first message
    if (!self.firstMessageReceived && self.isStreaming) {
        [self updateStatus:@"Device connected - logging active"];
        self.firstMessageReceived = YES;
    } else if (self.messageCount % 10 == 0) {
        [self updateStatus:[NSString stringWithFormat:@"Messages: %ld", (long)self.messageCount]];
    }
}

- (NSColor *)colorForMessage:(NSString *)message {
    // Simple color coding based on message content
    if ([message containsString:@"Emergency"] || [message containsString:@"EMERG"]) {
        return [NSColor colorWithRed:1.0 green:0.2 blue:0.2 alpha:1.0]; // Bright red
    } else if ([message containsString:@"Alert"] || [message containsString:@"ALERT"]) {
        return [NSColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0]; // Red
    } else if ([message containsString:@"Critical"] || [message containsString:@"CRIT"]) {
        return [NSColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1.0]; // Light red
    } else if ([message containsString:@"Error"] || [message containsString:@"ERROR"]) {
        return [NSColor colorWithRed:1.0 green:0.5 blue:0.5 alpha:1.0]; // Pink
    } else if ([message containsString:@"Warning"] || [message containsString:@"WARN"]) {
        return [NSColor colorWithRed:1.0 green:0.8 blue:0.2 alpha:1.0]; // Yellow
    } else if ([message containsString:@"Notice"] || [message containsString:@"NOTICE"]) {
        return [NSColor colorWithRed:0.5 green:1.0 blue:0.5 alpha:1.0]; // Green
    } else if ([message containsString:@"Info"] || [message containsString:@"INFO"]) {
        return [NSColor colorWithRed:0.5 green:0.8 blue:1.0 alpha:1.0]; // Cyan
    } else if ([message containsString:@"Debug"] || [message containsString:@"DEBUG"]) {
        return [NSColor colorWithWhite:0.7 alpha:1.0]; // Gray
    }

    return [NSColor colorWithWhite:0.9 alpha:1.0]; // Default white
}

#pragma mark - Application Lifecycle

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    if (self.deviceManager) {
        [self.deviceManager stopSyslogStream];
    }
    [self savePreferences];
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

#pragma mark - Menu Actions

- (void)showAboutPanel {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"iOS Syslog Viewer"];
        [alert setInformativeText:@"Version 1.0.0\n\nA professional macOS application for viewing iOS device system logs in real-time.\n\nFeatures:\n• Real-time log streaming\n• Multiple output formats\n• Advanced filtering\n• Color-coded log levels\n• Export functionality\n\n© 2025 Syslogger"];
        [alert setAlertStyle:NSAlertStyleInformational];
        [alert addButtonWithTitle:@"OK"];

        if (self.window) {
            [alert beginSheetModalForWindow:self.window completionHandler:nil];
        } else {
            [alert runModal];
        }
    });
}

#pragma mark - Preferences

- (void)loadPreferences {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // Load filter level
    if ([defaults objectForKey:@"filterLevel"]) {
        self.filterLevel = [defaults integerForKey:@"filterLevel"];
        if (self.filterLevelButton) {
            [self.filterLevelButton selectItemAtIndex:self.filterLevel];
        }
    }

    // Load window position and size
    if ([defaults objectForKey:@"windowFrame"]) {
        NSString *frameString = [defaults stringForKey:@"windowFrame"];
        NSRect frame = NSRectFromString(frameString);
        [self.window setFrame:frame display:YES];
    }
}

- (void)savePreferences {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // Save filter level
    [defaults setInteger:self.filterLevel forKey:@"filterLevel"];

    // Save window position and size
    if (self.window) {
        NSString *frameString = NSStringFromRect(self.window.frame);
        [defaults setObject:frameString forKey:@"windowFrame"];
    }

    [defaults synchronize];
}

@end
