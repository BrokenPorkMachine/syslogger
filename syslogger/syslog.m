//
//  syslog.m
//  syslogger
//
//  Syslog processor using ASL (Apple System Log) format
//

#import "syslog.h"
#import "ASLMessage.h"

@interface syslogger ()
{
    NSMutableString *_lineBuffer;
    NSFileHandle *_fileHandle;
    ASLFormatter *_formatter;
    NSMutableArray<ASLMessage *> *_messageBuffer;
    dispatch_queue_t _processingQueue;
}
@end

@implementation syslogger

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        _lineBuffer = [NSMutableString string];
        _messageBuffer = [NSMutableArray array];
        _processingQueue = dispatch_queue_create("com.syslogger.processing", DISPATCH_QUEUE_SERIAL);

        // Use idevicesyslog-compatible formatter for nice readable output
        _formatter = [ASLFormatter idevicesyslogFormatter];
        _formatter.colorize = NO; // Can be enabled for terminal output
        _formatter.maxMessageLength = 0; // No truncation by default

        _saveToFile = NO;
        _outputFilePath = nil;
    }
    return self;
}

#pragma mark - File Output Setup

- (void)setSaveToFile:(BOOL)saveToFile {
    _saveToFile = saveToFile;

    if (_saveToFile) {
        [self setupFileOutput];
    } else {
        [self closeFileOutput];
    }
}

- (void)setOutputFilePath:(NSString *)outputFilePath {
    _outputFilePath = outputFilePath;

    if (_saveToFile) {
        [self closeFileOutput];
        [self setupFileOutput];
    }
}

- (void)setupFileOutput {
    if (!_outputFilePath) {
        // Default to ~/Desktop/syslog_output.log
        NSString *desktopPath = [NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES) firstObject];
        _outputFilePath = [desktopPath stringByAppendingPathComponent:@"syslog_output.log"];
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];

    // Create file if it doesn't exist
    if (![fileManager fileExistsAtPath:_outputFilePath]) {
        [fileManager createFileAtPath:_outputFilePath contents:nil attributes:nil];
    }

    _fileHandle = [NSFileHandle fileHandleForWritingAtPath:_outputFilePath];
    if (_fileHandle) {
        [_fileHandle seekToEndOfFile];
        NSLog(@"[Syslogger] Logging to file: %@", _outputFilePath);
    } else {
        NSLog(@"[Syslogger] ERROR: Failed to open file for writing: %@", _outputFilePath);
    }
}

- (void)closeFileOutput {
    if (_fileHandle) {
        [_fileHandle closeFile];
        _fileHandle = nil;
    }
}

#pragma mark - DeviceManagerDelegate

- (void)didReceiveSyslogData:(NSData *)data {
    dispatch_async(_processingQueue, ^{
        [self processSyslogData:data];
    });
}

#pragma mark - Syslog Processing

- (void)processSyslogData:(NSData *)data {
    if (!data || data.length == 0) {
        return;
    }

    // Try to decode as UTF-8 string
    NSString *chunk = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    // Fallback to ISO Latin 1 if UTF-8 fails
    if (!chunk) {
        chunk = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    }

    // If still can't decode, try to extract printable characters
    if (!chunk) {
        chunk = [self extractPrintableString:data];
    }

    if (!chunk || chunk.length == 0) {
        return;
    }

    // Append to line buffer
    [_lineBuffer appendString:chunk];

    // Process complete lines
    [self processLineBuffer];
}

- (NSString *)extractPrintableString:(NSData *)data {
    const unsigned char *bytes = [data bytes];
    NSMutableString *result = [NSMutableString stringWithCapacity:data.length];

    for (NSUInteger i = 0; i < data.length; i++) {
        unsigned char byte = bytes[i];
        // Include printable ASCII and common whitespace
        if ((byte >= 32 && byte <= 126) || byte == '\t' || byte == '\n' || byte == '\r') {
            [result appendFormat:@"%c", byte];
        } else if (byte >= 128) {
            // Include extended ASCII/UTF-8 continuation bytes
            [result appendFormat:@"%c", byte];
        }
    }

    return result;
}

- (void)processLineBuffer {
    // Split buffer by newlines
    NSArray *lines = [_lineBuffer componentsSeparatedByString:@"\n"];

    // Keep the last incomplete line in the buffer
    if (lines.count > 0) {
        _lineBuffer = [NSMutableString stringWithString:[lines lastObject]];
    }

    // Process all complete lines (all but the last one)
    for (NSUInteger i = 0; i < lines.count - 1; i++) {
        NSString *line = lines[i];
        [self processLine:line];
    }
}

- (void)processLine:(NSString *)line {
    // Trim whitespace
    line = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    // Skip empty lines
    if (line.length == 0) {
        return;
    }

    // Skip lines that are mostly binary garbage
    if (![self isLineReadable:line]) {
        return;
    }

    // Parse the line using ASL parser
    ASLMessage *message = [ASLParser parseSyslogRelayData:[line dataUsingEncoding:NSUTF8StringEncoding]];

    // If ASL parser failed, try text line parser
    if (!message) {
        message = [ASLParser parseTextLine:line];
    }

    // If parsing still failed but line looks valid, create a basic message
    if (!message && line.length > 10) {
        message = [[ASLMessage alloc] init];
        message.message = line;
        message.level = ASLLevelNotice;
    }

    if (message) {
        [self outputMessage:message];
    }
}

- (BOOL)isLineReadable:(NSString *)line {
    if (line.length < 5) {
        return NO;
    }

    NSInteger printableCount = 0;
    NSInteger totalCount = MIN(100, line.length);

    for (NSInteger i = 0; i < totalCount; i++) {
        unichar ch = [line characterAtIndex:i];
        // Count printable ASCII, whitespace, and extended characters
        if ((ch >= 32 && ch <= 126) || ch == '\t' || ch == '\n' || ch == '\r' || ch >= 128) {
            printableCount++;
        }
    }

    // Line must be at least 50% printable
    return (double)printableCount / (double)totalCount >= 0.5;
}

#pragma mark - Output

- (void)outputMessage:(ASLMessage *)message {
    // Format the message
    NSString *formattedMessage = [_formatter formatMessage:message];

    // Send to delegate
    if (self.outputDelegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.outputDelegate syslogger:self didLogMessage:formattedMessage];
        });
    }

    // Write to file if enabled
    if (_saveToFile && _fileHandle) {
        NSString *lineToWrite = [formattedMessage stringByAppendingString:@"\n"];
        NSData *data = [lineToWrite dataUsingEncoding:NSUTF8StringEncoding];
        @try {
            [_fileHandle writeData:data];
        } @catch (NSException *exception) {
            NSLog(@"[Syslogger] ERROR writing to file: %@", exception);
        }
    }
}

#pragma mark - Public Configuration

- (void)setFormatterStyle:(NSString *)style {
    if ([style isEqualToString:@"compact"]) {
        _formatter = [ASLFormatter compactFormatter];
    } else if ([style isEqualToString:@"verbose"]) {
        _formatter = [ASLFormatter verboseFormatter];
    } else if ([style isEqualToString:@"idevicesyslog"]) {
        _formatter = [ASLFormatter idevicesyslogFormatter];
    } else {
        _formatter = [ASLFormatter defaultFormatter];
    }
}

- (void)setColorize:(BOOL)colorize {
    _formatter.colorize = colorize;
}

- (void)setShowTimestamp:(BOOL)show {
    _formatter.showTimestamp = show;
}

- (void)setShowPID:(BOOL)show {
    _formatter.showPID = show;
}

- (void)setShowLevel:(BOOL)show {
    _formatter.showLevel = show;
}

- (void)setMaxMessageLength:(NSInteger)length {
    _formatter.maxMessageLength = length;
}

#pragma mark - Cleanup

- (void)dealloc {
    [self closeFileOutput];
}

@end
