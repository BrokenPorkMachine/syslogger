//
//  syslog.m
//  syslogger
//
//  Created by failbr34k on 2025-11-09.
//

#import "syslog.h"

@interface syslogger ()
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, strong) NSMutableString *lineBuffer;
@end

@implementation syslogger

- (instancetype)init {
    self = [super init];
    if (self) {
        // Set default values
        _outputFormat = @"idevicesyslog";
        _showTimestamp = YES;
        _showHost = YES;
        _showPID = YES;
        _showLevel = YES;
        _colorize = NO;
        _maxMessageLength = 0;  // No limit
        _minLogLevel = ASLLevelDebug;  // Show all levels
        _importantOnly = NO;
        _saveToFile = NO;
        _lineBuffer = [NSMutableString string];
    }
    return self;
}

- (void)dealloc {
    if (_fileHandle) {
        [_fileHandle closeFile];
    }
}

#pragma mark - Formatter Creation

- (ASLFormatter *)createFormatter {
    ASLFormatter *formatter = nil;

    if ([self.outputFormat isEqualToString:@"compact"]) {
        formatter = [ASLFormatter compactFormatter];
    } else if ([self.outputFormat isEqualToString:@"verbose"]) {
        formatter = [ASLFormatter verboseFormatter];
    } else if ([self.outputFormat isEqualToString:@"standard"]) {
        formatter = [ASLFormatter defaultFormatter];
    } else {
        // Default to idevicesyslog format
        formatter = [ASLFormatter idevicesyslogFormatter];
    }

    // Apply custom display options
    formatter.showTimestamp = self.showTimestamp;
    formatter.showHost = self.showHost;
    formatter.showPID = self.showPID;
    formatter.showLevel = self.showLevel;
    formatter.colorize = self.colorize;
    formatter.maxMessageLength = self.maxMessageLength;

    return formatter;
}

#pragma mark - Filtering

- (BOOL)shouldDisplayMessage:(ASLMessage *)message {
    // Check log level filter
    if (message.level > self.minLogLevel) {
        return NO;
    }

    // Check important-only filter
    if (self.importantOnly && ![message isImportantMessage]) {
        return NO;
    }

    // Check sender filter
    if (self.senderFilter && self.senderFilter.length > 0) {
        if (!message.sender || ![message.sender containsString:self.senderFilter]) {
            return NO;
        }
    }

    // Check message filter
    if (self.messageFilter && self.messageFilter.length > 0) {
        if (!message.message || ![message.message containsString:self.messageFilter]) {
            return NO;
        }
    }

    return YES;
}

#pragma mark - File Output

- (void)setupFileOutput {
    if (!self.saveToFile) return;

    NSString *path = self.outputFilePath ? self.outputFilePath : @"syslog.txt";

    // Create file if it doesn't exist
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path]) {
        [fileManager createFileAtPath:path contents:nil attributes:nil];
    }

    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:path];
    if (self.fileHandle) {
        [self.fileHandle seekToEndOfFile];
    } else {
        NSLog(@"Failed to open file for writing: %@", path);
    }
}

- (void)writeToFile:(NSString *)message {
    if (!self.fileHandle) {
        [self setupFileOutput];
    }

    if (self.fileHandle) {
        NSString *lineWithNewline = [message stringByAppendingString:@"\n"];
        NSData *data = [lineWithNewline dataUsingEncoding:NSUTF8StringEncoding];
        [self.fileHandle writeData:data];
    }
}

#pragma mark - Data Processing

- (void)processSyslogData:(NSData *)data {
    if (!data || data.length == 0) return;

    // Try UTF-8 encoding first
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    // Fallback to ISO Latin 1 if UTF-8 fails
    if (!text) {
        text = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    }

    if (!text) return;

    // Append to line buffer
    [self.lineBuffer appendString:text];

    // Process complete lines
    NSArray *lines = [self.lineBuffer componentsSeparatedByString:@"\n"];

    // Keep the last incomplete line in buffer
    self.lineBuffer = [[lines lastObject] mutableCopy];

    // Process all complete lines (all but last)
    ASLFormatter *formatter = [self createFormatter];

    for (NSUInteger i = 0; i < lines.count - 1; i++) {
        NSString *line = lines[i];
        if (line.length == 0) continue;

        // Parse the line
        ASLMessage *message = [ASLParser parseTextLine:line];
        if (!message) continue;

        // Apply filters
        if (![self shouldDisplayMessage:message]) {
            continue;
        }

        // Format the message
        NSString *formattedMessage = [formatter formatMessage:message];

        // Send to output delegate
        if (self.outputDelegate && [self.outputDelegate respondsToSelector:@selector(syslogger:didLogMessage:)]) {
            [self.outputDelegate syslogger:self didLogMessage:formattedMessage];
        }

        // Write to file if enabled
        if (self.saveToFile) {
            [self writeToFile:formattedMessage];
        }
    }
}

#pragma mark - DeviceManagerDelegate

- (void)didReceiveSyslogData:(NSData *)data {
    [self processSyslogData:data];
}

@end
