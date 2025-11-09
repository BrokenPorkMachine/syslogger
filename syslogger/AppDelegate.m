//
//  AppDelegate.m
//  syslogger
//
//  Created by failbr34k on 2025-11-09.
//

#import "AppDelegate.h"

@interface AppDelegate ()
@property (nonatomic, strong) NSButton *clearButton;
@property (nonatomic, strong) NSButton *saveButton;
@property (nonatomic, strong) NSButton *pauseButton;
@property (nonatomic, strong) NSPopUpButton *filterLevelButton;
@property (nonatomic, strong) NSSearchField *searchField;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, assign) BOOL isPaused;
@property (nonatomic, strong) NSMutableArray<NSString *> *pausedMessages;
@property (nonatomic, assign) ASLLevel filterLevel;
@property (nonatomic, strong) NSString *searchText;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSArray<NSString *> *args = [[NSProcessInfo processInfo] arguments];
    BOOL runConsole = [args containsObject:@"--console"];

    self.logger = [[syslogger alloc] init];
    self.logger.outputDelegate = self;

    // Initialize filter settings
    self.isPaused = NO;
    self.pausedMessages = [NSMutableArray array];
    self.filterLevel = ASLLevelDebug; // Show all by default
    self.searchText = @"";

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

- (void)createProgrammaticUI {
    // Create main window
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1000, 700)
                                              styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    [self.window center];
    [self.window setTitle:@"iOS Syslog Viewer"];
    [self.window setMinSize:NSMakeSize(600, 400)];

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

- (NSView *)createToolbar {
    NSView *toolbar = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 80)];
    toolbar.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    toolbar.wantsLayer = YES;
    toolbar.layer.backgroundColor = [[NSColor colorWithWhite:0.15 alpha:1.0] CGColor];

    CGFloat x = 10;
    CGFloat y = 45;

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

    // Save button
    self.saveButton = [[NSButton alloc] initWithFrame:NSMakeRect(x, y, 80, 25)];
    [self.saveButton setTitle:@"Save..."];
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

    // Status label (bottom row)
    self.statusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 10, 980, 20)];
    [self.statusLabel setStringValue:@"Waiting for device..."];
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

#pragma mark - Button Actions

- (void)clearButtonClicked:(id)sender {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.textView setString:@""];
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
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setNameFieldStringValue:@"syslog_output.txt"];
    [savePanel setAllowedFileTypes:@[@"txt", @"log"]];

    [savePanel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            NSURL *url = [savePanel URL];
            NSString *content = self.textView.string;
            NSError *error = nil;

            [content writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&error];

            if (error) {
                NSLog(@"Error saving file: %@", error);
                [self updateStatus:[NSString stringWithFormat:@"Error saving: %@", error.localizedDescription]];
            } else {
                [self updateStatus:[NSString stringWithFormat:@"Saved to: %@", url.path]];
            }
        }
    }];
}

- (void)filterLevelChanged:(id)sender {
    self.filterLevel = (ASLLevel)[self.filterLevelButton indexOfSelectedItem];
    [self updateStatus:[NSString stringWithFormat:@"Filter level: %@", [self.filterLevelButton titleOfSelectedItem]]];
}

- (void)searchFieldChanged:(id)sender {
    self.searchText = [self.searchField stringValue];
    if (self.searchText.length > 0) {
        [self updateStatus:[NSString stringWithFormat:@"Filtering: %@", self.searchText]];
    } else {
        [self updateStatus:@"Ready"];
    }
}

- (void)updateStatus:(NSString *)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.statusLabel setStringValue:status];
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
    static NSInteger messageCount = 0;
    messageCount++;
    if (messageCount % 10 == 0) {
        [self updateStatus:[NSString stringWithFormat:@"Messages: %ld", (long)messageCount]];
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
    [self.deviceManager stopSyslogStream];
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end
