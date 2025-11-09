//
//  ASLMessage.m
//  St0rmActivatorA12
//
//  Apple System Log (ASL) Format Implementation
//

#import "ASLMessage.h"
#import <sys/time.h>

// ============================================================================
// MARK: - ASLMessage Implementation
// ============================================================================

@implementation ASLMessage

- (instancetype)init {
    self = [super init];
    if (self) {
        _time = [NSDate date];
        _pid = -1;
        _uid = -1;
        _gid = -1;
        _level = ASLLevelNotice;
        _facility = ASLFacilityUser;
        _message = @"";
        _extendedAttributes = [NSMutableDictionary dictionary];
        _threadID = 0;
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [self init];
    if (self) {
        // Parse standard fields
        if (dict[@"Time"]) {
            _time = dict[@"Time"];
        }
        if (dict[@"Host"]) {
            _host = dict[@"Host"];
        }
        if (dict[@"Sender"]) {
            _sender = dict[@"Sender"];
        }
        if (dict[@"PID"]) {
            _pid = [dict[@"PID"] intValue];
        }
        if (dict[@"UID"]) {
            _uid = [dict[@"UID"] unsignedIntValue];
        }
        if (dict[@"GID"]) {
            _gid = [dict[@"GID"] unsignedIntValue];
        }
        if (dict[@"Level"]) {
            if ([dict[@"Level"] isKindOfClass:[NSNumber class]]) {
                _level = [dict[@"Level"] integerValue];
            } else if ([dict[@"Level"] isKindOfClass:[NSString class]]) {
                _level = [ASLMessage levelFromString:dict[@"Level"]];
            }
        }
        if (dict[@"Message"]) {
            _message = dict[@"Message"];
        }
        if (dict[@"Facility"]) {
            if ([dict[@"Facility"] isKindOfClass:[NSNumber class]]) {
                _facility = [dict[@"Facility"] integerValue];
            } else {
                _facility = [ASLMessage facilityFromString:dict[@"Facility"]];
            }
        }

        // Parse extended fields
        if (dict[@"Category"]) {
            _category = dict[@"Category"];
        }
        if (dict[@"Subsystem"]) {
            _subsystem = dict[@"Subsystem"];
        }
        if (dict[@"MessageType"]) {
            _messageType = dict[@"MessageType"];
        }
        if (dict[@"ThreadID"]) {
            id threadIDValue = dict[@"ThreadID"];
            if ([threadIDValue isKindOfClass:[NSNumber class]]) {
                _threadID = [(NSNumber *)threadIDValue unsignedLongLongValue];
            } else if ([threadIDValue isKindOfClass:[NSString class]]) {
                _threadID = (unsigned long long)[(NSString *)threadIDValue longLongValue];
            }
        }
        if (dict[@"Activity"]) {
            _activity = dict[@"Activity"];
        }
        if (dict[@"ProcessImagePath"]) {
            _processImagePath = dict[@"ProcessImagePath"];
        }

        // Store all other keys as extended attributes
        for (NSString *key in dict) {
            if (![self isStandardKey:key]) {
                [_extendedAttributes setObject:[dict[key] description] forKey:key];
            }
        }
    }
    return self;
}

- (BOOL)isStandardKey:(NSString *)key {
    static NSSet *standardKeys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        standardKeys = [NSSet setWithArray:@[
            @"Time", @"Host", @"Sender", @"PID", @"UID", @"GID",
            @"Level", @"Message", @"Facility", @"Category", @"Subsystem",
            @"MessageType", @"ThreadID", @"Activity", @"ProcessImagePath"
        ]];
    });
    return [standardKeys containsObject:key];
}

- (void)setValue:(NSString *)value forKey:(NSString *)key {
    if ([key isEqualToString:@"Message"]) {
        self.message = value;
    } else if ([key isEqualToString:@"Sender"]) {
        self.sender = value;
    } else if ([key isEqualToString:@"Host"]) {
        self.host = value;
    } else if ([key isEqualToString:@"Level"]) {
        self.level = [ASLMessage levelFromString:value];
    } else {
        [self.extendedAttributes setObject:value forKey:key];
    }
}

- (NSString *)valueForKey:(NSString *)key {
    if ([key isEqualToString:@"Message"]) {
        return self.message;
    } else if ([key isEqualToString:@"Sender"]) {
        return self.sender;
    } else if ([key isEqualToString:@"Host"]) {
        return self.host;
    } else if ([key isEqualToString:@"Level"]) {
        return [ASLMessage stringFromLevel:self.level];
    }
    return self.extendedAttributes[key];
}

// MARK: - Level Conversion

+ (ASLLevel)levelFromString:(NSString *)levelString {
    levelString = [levelString lowercaseString];

    if ([levelString containsString:@"emerg"]) return ASLLevelEmergency;
    if ([levelString containsString:@"alert"]) return ASLLevelAlert;
    if ([levelString containsString:@"crit"]) return ASLLevelCritical;
    if ([levelString containsString:@"err"]) return ASLLevelError;
    if ([levelString containsString:@"warn"]) return ASLLevelWarning;
    if ([levelString containsString:@"notice"]) return ASLLevelNotice;
    if ([levelString containsString:@"info"]) return ASLLevelInfo;
    if ([levelString containsString:@"debug"]) return ASLLevelDebug;

    // Try numeric
    NSInteger level = [levelString integerValue];
    if (level >= 0 && level <= 7) {
        return (ASLLevel)level;
    }

    return ASLLevelNotice; // Default
}

+ (NSString *)stringFromLevel:(ASLLevel)level {
    switch (level) {
        case ASLLevelEmergency: return @"Emergency";
        case ASLLevelAlert:     return @"Alert";
        case ASLLevelCritical:  return @"Critical";
        case ASLLevelError:     return @"Error";
        case ASLLevelWarning:   return @"Warning";
        case ASLLevelNotice:    return @"Notice";
        case ASLLevelInfo:      return @"Info";
        case ASLLevelDebug:     return @"Debug";
        default:                return @"Unknown";
    }
}

+ (NSString *)shortStringFromLevel:(ASLLevel)level {
    switch (level) {
        case ASLLevelEmergency: return @"EMERG";
        case ASLLevelAlert:     return @"ALERT";
        case ASLLevelCritical:  return @"CRIT";
        case ASLLevelError:     return @"ERROR";
        case ASLLevelWarning:   return @"WARN";
        case ASLLevelNotice:    return @"NOTICE";
        case ASLLevelInfo:      return @"INFO";
        case ASLLevelDebug:     return @"DEBUG";
        default:                return @"UNK";
    }
}

// MARK: - Facility Conversion

+ (ASLFacility)facilityFromString:(NSString *)facilityString {
    facilityString = [facilityString lowercaseString];

    if ([facilityString isEqualToString:@"kern"]) return ASLFacilityKernel;
    if ([facilityString isEqualToString:@"user"]) return ASLFacilityUser;
    if ([facilityString isEqualToString:@"mail"]) return ASLFacilityMail;
    if ([facilityString isEqualToString:@"daemon"]) return ASLFacilityDaemon;
    if ([facilityString isEqualToString:@"auth"]) return ASLFacilityAuth;
    if ([facilityString isEqualToString:@"syslog"]) return ASLFacilitySyslog;

    return ASLFacilityUser;
}

+ (NSString *)stringFromFacility:(ASLFacility)facility {
    switch (facility) {
        case ASLFacilityKernel:   return @"kern";
        case ASLFacilityUser:     return @"user";
        case ASLFacilityMail:     return @"mail";
        case ASLFacilityDaemon:   return @"daemon";
        case ASLFacilityAuth:     return @"auth";
        case ASLFacilitySyslog:   return @"syslog";
        case ASLFacilityLPR:      return @"lpr";
        case ASLFacilityNews:     return @"news";
        case ASLFacilityUUCP:     return @"uucp";
        case ASLFacilityClock:    return @"clock";
        case ASLFacilityAuthPriv: return @"authpriv";
        case ASLFacilityFTP:      return @"ftp";
        case ASLFacilityNTP:      return @"ntp";
        case ASLFacilitySecure:   return @"secure";
        case ASLFacilityConsole:  return @"console";
        default:
            if (facility >= ASLFacilityLocal0 && facility <= ASLFacilityLocal7) {
                return [NSString stringWithFormat:@"local%ld", (long)(facility - ASLFacilityLocal0)];
            }
            return @"user";
    }
}

// MARK: - Formatting

- (NSString *)formattedString {
    return [self formattedStringWithStyle:@"standard"];
}

- (NSString *)formattedStringWithStyle:(NSString *)style {
    if ([style isEqualToString:@"compact"]) {
        return [self compactFormat];
    } else if ([style isEqualToString:@"detailed"]) {
        return [self detailedFormat];
    } else if ([style isEqualToString:@"idevicesyslog"]) {
        return [self idevicesyslogFormat];
    }

    // Standard ASL format
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
    NSString *timeStr = [formatter stringFromDate:self.time];

    NSString *hostStr = self.host ? self.host : @"localhost";
    NSString *senderStr = self.sender ? self.sender : @"unknown";
    NSString *levelStr = [ASLMessage shortStringFromLevel:self.level];

    return [NSString stringWithFormat:@"%@ %@ %@[%d] <%@>: %@",
            timeStr, hostStr, senderStr, (int)self.pid, levelStr, self.message];
}

- (NSString *)compactFormat {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm:ss"];
    NSString *timeStr = [formatter stringFromDate:self.time];

    NSString *senderStr = self.sender ? self.sender : @"?";
    NSString *levelStr = [ASLMessage shortStringFromLevel:self.level];

    return [NSString stringWithFormat:@"%@ [%@] %@: %@",
            timeStr, levelStr, senderStr, self.message];
}

- (NSString *)detailedFormat {
    NSMutableString *result = [NSMutableString string];

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS Z"];

    [result appendFormat:@"========== ASL Message ==========\n"];
    [result appendFormat:@"Time:     %@\n", [formatter stringFromDate:self.time]];
    if (self.host) {
        [result appendFormat:@"Host:     %@\n", self.host];
    }
    if (self.sender) {
        [result appendFormat:@"Sender:   %@\n", self.sender];
    }
    if (self.pid >= 0) {
        [result appendFormat:@"PID:      %d\n", (int)self.pid];
    }
    if (self.uid != (uid_t)-1) {
        [result appendFormat:@"UID:      %u\n", self.uid];
    }
    if (self.gid != (gid_t)-1) {
        [result appendFormat:@"GID:      %u\n", self.gid];
    }
    [result appendFormat:@"Level:    %@ (%ld)\n", [ASLMessage stringFromLevel:self.level], (long)self.level];
    [result appendFormat:@"Facility: %@ (%ld)\n", [ASLMessage stringFromFacility:self.facility], (long)self.facility];

    if (self.subsystem) {
        [result appendFormat:@"Subsystem: %@\n", self.subsystem];
    }
    if (self.category) {
        [result appendFormat:@"Category:  %@\n", self.category];
    }
    if (self.threadID > 0) {
        [result appendFormat:@"Thread:    0x%llx\n", self.threadID];
    }
    if (self.processImagePath) {
        [result appendFormat:@"Path:      %@\n", self.processImagePath];
    }

    [result appendFormat:@"Message:  %@\n", self.message];

    if (self.extendedAttributes.count > 0) {
        [result appendString:@"Extended Attributes:\n"];
        for (NSString *key in [self.extendedAttributes.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            [result appendFormat:@"  %@: %@\n", key, self.extendedAttributes[key]];
        }
    }

    [result appendString:@"=================================\n"];

    return result;
}

- (NSString *)idevicesyslogFormat {
    // Format: "Mon DD HH:MM:SS DeviceName ProcessName[PID] <Level>: Message"
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"MMM dd HH:mm:ss"];
    NSString *timeStr = [formatter stringFromDate:self.time];

    NSString *hostStr = self.host ? self.host : @"Device";
    NSString *senderStr = self.sender ? self.sender : @"unknown";
    NSString *levelStr = [ASLMessage stringFromLevel:self.level];

    if (self.pid >= 0) {
        return [NSString stringWithFormat:@"%@ %@ %@[%d] <%@>: %@",
                timeStr, hostStr, senderStr, (int)self.pid, levelStr, self.message];
    } else {
        return [NSString stringWithFormat:@"%@ %@ %@ <%@>: %@",
                timeStr, hostStr, senderStr, levelStr, self.message];
    }
}

// MARK: - Filtering

- (BOOL)matchesFilter:(NSDictionary *)filter {
    // Check level filter
    if (filter[@"minLevel"]) {
        ASLLevel minLevel = [filter[@"minLevel"] integerValue];
        if (self.level > minLevel) return NO;
    }

    // Check sender filter
    if (filter[@"sender"]) {
        NSString *senderPattern = filter[@"sender"];
        if (![self.sender containsString:senderPattern]) return NO;
    }

    // Check message filter
    if (filter[@"message"]) {
        NSString *messagePattern = filter[@"message"];
        if (![self.message containsString:messagePattern]) return NO;
    }

    return YES;
}

- (BOOL)isImportantMessage {
    // High severity levels are always important
    if (self.level <= ASLLevelError) {
        return YES;
    }

    // Check for important keywords in message
    NSArray *importantKeywords = @[
        @"activation", @"Activation",
        @"BLDatabase", @"Books",
        @"iTunes", @"asset.epub",
        @"crash", @"exception", @"assertion",
        @"GUID", @"SystemGroup"
    ];

    for (NSString *keyword in importantKeywords) {
        if ([self.message containsString:keyword]) {
            return YES;
        }
        if ([self.sender containsString:keyword]) {
            return YES;
        }
    }

    return NO;
}

@end

// ============================================================================
// MARK: - ASLParser Implementation
// ============================================================================

@implementation ASLParser

+ (nullable ASLMessage *)parseTextLine:(NSString *)line {
    if (line.length == 0) return nil;

    ASLMessage *msg = [[ASLMessage alloc] init];

    // Try to parse different formats
    // Format 1: Standard syslog - "Mon DD HH:MM:SS host process[pid]: message"
    // Format 2: iOS format - "process[pid] <Level>: message"
    // Format 3: os_log format - "timestamp host process[pid:tid] level: message"

    NSString *workingLine = line;

    // Try to extract timestamp (various formats)
    NSRegularExpression *timestampRegex = [NSRegularExpression regularExpressionWithPattern:
        @"^(\\w{3}\\s+\\d{1,2}\\s+\\d{2}:\\d{2}:\\d{2})"
        options:0 error:nil];
    NSTextCheckingResult *timestampMatch = [timestampRegex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
    if (timestampMatch) {
        NSString *timestampStr = [line substringWithRange:[timestampMatch rangeAtIndex:1]];
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"MMM dd HH:mm:ss"];
        NSDate *parsedDate = [formatter dateFromString:timestampStr];
        if (parsedDate) {
            msg.time = parsedDate;
        }
        workingLine = [[line substringFromIndex:timestampMatch.range.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }

    // Try to extract host/device name
    NSRegularExpression *hostRegex = [NSRegularExpression regularExpressionWithPattern:
        @"^([A-Za-z0-9_-]+)\\s+"
        options:0 error:nil];
    NSTextCheckingResult *hostMatch = [hostRegex firstMatchInString:workingLine options:0 range:NSMakeRange(0, workingLine.length)];
    if (hostMatch && [hostMatch rangeAtIndex:1].length > 0) {
        NSString *potentialHost = [workingLine substringWithRange:[hostMatch rangeAtIndex:1]];
        // Only treat as host if it doesn't look like a process name with PID following
        NSRange remainingRange = NSMakeRange(hostMatch.range.length, workingLine.length - hostMatch.range.length);
        if (remainingRange.length > 0) {
            NSString *remaining = [workingLine substringWithRange:remainingRange];
            if (![remaining hasPrefix:@"["]) {
                msg.host = potentialHost;
                workingLine = [remaining stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            }
        }
    }

    // Extract process[pid] pattern
    NSRegularExpression *processRegex = [NSRegularExpression regularExpressionWithPattern:
        @"^([A-Za-z0-9_.-]+)\\[(\\d+)\\]"
        options:0 error:nil];
    NSTextCheckingResult *processMatch = [processRegex firstMatchInString:workingLine options:0 range:NSMakeRange(0, workingLine.length)];
    if (processMatch) {
        msg.sender = [workingLine substringWithRange:[processMatch rangeAtIndex:1]];
        msg.pid = [[workingLine substringWithRange:[processMatch rangeAtIndex:2]] intValue];
        workingLine = [[workingLine substringFromIndex:processMatch.range.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    } else {
        // Try to extract process name without PID
        NSRegularExpression *processOnlyRegex = [NSRegularExpression regularExpressionWithPattern:
            @"^([A-Za-z0-9_.-]+):"
            options:0 error:nil];
        NSTextCheckingResult *processOnlyMatch = [processOnlyRegex firstMatchInString:workingLine options:0 range:NSMakeRange(0, workingLine.length)];
        if (processOnlyMatch) {
            msg.sender = [workingLine substringWithRange:[processOnlyMatch rangeAtIndex:1]];
            workingLine = [[workingLine substringFromIndex:processMatch.range.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }
    }

    // Extract log level <Level>
    NSRegularExpression *levelRegex = [NSRegularExpression regularExpressionWithPattern:
        @"<(\\w+)>:?"
        options:0 error:nil];
    NSTextCheckingResult *levelMatch = [levelRegex firstMatchInString:workingLine options:0 range:NSMakeRange(0, workingLine.length)];
    if (levelMatch) {
        NSString *levelStr = [workingLine substringWithRange:[levelMatch rangeAtIndex:1]];
        msg.level = [ASLMessage levelFromString:levelStr];
        workingLine = [[workingLine substringFromIndex:levelMatch.range.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }

    // Remove leading colon if present
    if ([workingLine hasPrefix:@":"]) {
        workingLine = [[workingLine substringFromIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }

    // Remaining text is the message
    msg.message = workingLine.length > 0 ? workingLine : line;

    return msg;
}

+ (nullable ASLMessage *)parseBinaryData:(NSData *)data {
    // Binary ASL format parsing
    // This is a simplified implementation - real ASL binary format is complex
    if (data.length < 16) return nil;

    ASLMessage *msg = [[ASLMessage alloc] init];

    // In real ASL binary format, data is structured with headers and key-value pairs
    // For now, we'll treat it as text if it's printable
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (text) {
        return [self parseTextLine:text];
    }

    return msg;
}

+ (NSArray<ASLMessage *> *)parseTextLines:(NSString *)text {
    NSMutableArray<ASLMessage *> *messages = [NSMutableArray array];

    [text enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        ASLMessage *msg = [self parseTextLine:line];
        if (msg) {
            [messages addObject:msg];
        }
    }];

    return messages;
}

+ (nullable ASLMessage *)parseSyslogRelayData:(NSData *)data {
    // iOS syslog_relay can send binary ASL data or text data
    // First try UTF8 encoding for clean text data
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    // If UTF8 fails, the data is likely binary - try to extract printable content
    if (!text) {
        // Create string by filtering out non-printable bytes
        const unsigned char *bytes = [data bytes];
        NSMutableString *filtered = [NSMutableString stringWithCapacity:data.length];

        for (NSUInteger i = 0; i < data.length; i++) {
            unsigned char byte = bytes[i];
            // Only keep printable ASCII and common whitespace
            if ((byte >= 32 && byte <= 126) || byte == '\t' || byte == '\n' || byte == '\r') {
                [filtered appendFormat:@"%c", byte];
            }
        }

        // If we extracted enough printable content, use it
        if (filtered.length > 10) {
            text = filtered;
        } else {
            // Not enough readable content, skip this data
            return nil;
        }
    }

    // Validate that the text is mostly printable before parsing
    if (text && text.length > 0) {
        NSInteger printableCount = 0;
        NSInteger totalCount = text.length;

        for (NSInteger i = 0; i < MIN(100, totalCount); i++) {
            unichar ch = [text characterAtIndex:i];
            if ((ch >= 32 && ch <= 126) || ch == '\t' || ch == '\n' || ch == '\r' || ch >= 128) {
                printableCount++;
            }
        }

        // If less than 50% printable in sample, it's likely binary garbage
        if (totalCount > 0 && (double)printableCount / (double)MIN(100, totalCount) < 0.5) {
            return nil;
        }

        return [self parseTextLine:text];
    }

    return nil;
}

+ (nullable ASLMessage *)parseOSLogLine:(NSString *)line {
    // Parse iOS 10+ os_log format
    // Format: "timestamp process[pid:tid] level: subsystem: message"

    if (line.length == 0) return nil;

    ASLMessage *msg = [[ASLMessage alloc] init];
    NSString *workingLine = line;

    // Try to parse timestamp (yyyy-MM-dd HH:mm:ss.SSS)
    NSRegularExpression *timestampRegex = [NSRegularExpression regularExpressionWithPattern:
        @"^(\\d{4}-\\d{2}-\\d{2}\\s+\\d{2}:\\d{2}:\\d{2}\\.\\d{3})"
        options:0 error:nil];
    NSTextCheckingResult *timestampMatch = [timestampRegex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
    if (timestampMatch) {
        NSString *timestampStr = [line substringWithRange:[timestampMatch rangeAtIndex:1]];
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
        NSDate *parsedDate = [formatter dateFromString:timestampStr];
        if (parsedDate) {
            msg.time = parsedDate;
        }
        workingLine = [[line substringFromIndex:timestampMatch.range.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }

    // Parse process[pid:tid]
    NSRegularExpression *processRegex = [NSRegularExpression regularExpressionWithPattern:
        @"^([A-Za-z0-9_.-]+)\\[(\\d+):(\\d+)\\]"
        options:0 error:nil];
    NSTextCheckingResult *processMatch = [processRegex firstMatchInString:workingLine options:0 range:NSMakeRange(0, workingLine.length)];
    if (processMatch) {
        msg.sender = [workingLine substringWithRange:[processMatch rangeAtIndex:1]];
        msg.pid = [[workingLine substringWithRange:[processMatch rangeAtIndex:2]] intValue];
        msg.threadID = (unsigned long long)[[workingLine substringWithRange:[processMatch rangeAtIndex:3]] longLongValue];
        workingLine = [[workingLine substringFromIndex:processMatch.range.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }

    // Parse level
    NSRegularExpression *levelRegex = [NSRegularExpression regularExpressionWithPattern:
        @"^(\\w+):"
        options:0 error:nil];
    NSTextCheckingResult *levelMatch = [levelRegex firstMatchInString:workingLine options:0 range:NSMakeRange(0, workingLine.length)];
    if (levelMatch) {
        NSString *levelStr = [workingLine substringWithRange:[levelMatch rangeAtIndex:1]];
        msg.level = [ASLMessage levelFromString:levelStr];
        workingLine = [[workingLine substringFromIndex:levelMatch.range.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }

    // Parse subsystem (optional)
    NSRegularExpression *subsystemRegex = [NSRegularExpression regularExpressionWithPattern:
        @"^([a-z0-9._-]+):"
        options:NSRegularExpressionCaseInsensitive error:nil];
    NSTextCheckingResult *subsystemMatch = [subsystemRegex firstMatchInString:workingLine options:0 range:NSMakeRange(0, MIN(100, workingLine.length))];
    if (subsystemMatch) {
        msg.subsystem = [workingLine substringWithRange:[subsystemMatch rangeAtIndex:1]];
        workingLine = [[workingLine substringFromIndex:subsystemMatch.range.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }

    // Remaining is the message
    msg.message = workingLine.length > 0 ? workingLine : line;

    return msg;
}

@end

// ============================================================================
// MARK: - ASLFormatter Implementation
// ============================================================================

@implementation ASLFormatter

- (instancetype)init {
    self = [super init];
    if (self) {
        _showTimestamp = YES;
        _showHost = YES;
        _showPID = YES;
        _showLevel = YES;
        _colorize = NO;
        _verbose = NO;
        _maxMessageLength = 200;

        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:@"MMM dd HH:mm:ss"];
    }
    return self;
}

+ (instancetype)defaultFormatter {
    return [[ASLFormatter alloc] init];
}

+ (instancetype)compactFormatter {
    ASLFormatter *formatter = [[ASLFormatter alloc] init];
    formatter.showHost = NO;
    formatter.maxMessageLength = 100;
    [formatter.dateFormatter setDateFormat:@"HH:mm:ss"];
    return formatter;
}

+ (instancetype)verboseFormatter {
    ASLFormatter *formatter = [[ASLFormatter alloc] init];
    formatter.verbose = YES;
    formatter.maxMessageLength = 0; // No limit
    [formatter.dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
    return formatter;
}

+ (instancetype)idevicesyslogFormatter {
    ASLFormatter *formatter = [[ASLFormatter alloc] init];
    [formatter.dateFormatter setDateFormat:@"MMM dd HH:mm:ss"];
    formatter.showHost = YES;
    formatter.showPID = YES;
    formatter.showLevel = YES;
    formatter.maxMessageLength = 0;
    return formatter;
}

- (NSString *)formatMessage:(ASLMessage *)message {
    if (self.verbose) {
        return [message detailedFormat];
    }

    NSMutableString *result = [NSMutableString string];

    // Add timestamp
    if (self.showTimestamp) {
        NSString *timeStr = [self.dateFormatter stringFromDate:message.time];
        [result appendFormat:@"%@ ", timeStr];
    }

    // Add host
    if (self.showHost && message.host) {
        [result appendFormat:@"%@ ", message.host];
    }

    // Add process name and PID
    NSString *sender = message.sender ? message.sender : @"unknown";
    if (self.showPID && message.pid >= 0) {
        [result appendFormat:@"%@[%d] ", sender, (int)message.pid];
    } else {
        [result appendFormat:@"%@ ", sender];
    }

    // Add log level
    if (self.showLevel) {
        NSString *levelStr = [ASLMessage stringFromLevel:message.level];

        if (self.colorize) {
            NSString *colorCode = [ASLFormatter colorForLevel:message.level];
            [result appendFormat:@"%@<%@>%@: ", colorCode, levelStr, [ASLFormatter resetColor]];
        } else {
            [result appendFormat:@"<%@>: ", levelStr];
        }
    }

    // Add message
    NSString *msg = message.message;
    if (self.maxMessageLength > 0 && msg.length > self.maxMessageLength) {
        msg = [[msg substringToIndex:self.maxMessageLength - 3] stringByAppendingString:@"..."];
    }
    [result appendString:msg];

    return result;
}

- (NSString *)formatMessages:(NSArray<ASLMessage *> *)messages {
    NSMutableString *result = [NSMutableString string];

    for (ASLMessage *message in messages) {
        [result appendString:[self formatMessage:message]];
        [result appendString:@"\n"];
    }

    return result;
}

+ (NSString *)colorForLevel:(ASLLevel)level {
    // ANSI color codes
    switch (level) {
        case ASLLevelEmergency:
        case ASLLevelAlert:
        case ASLLevelCritical:
            return @"\033[1;31m"; // Bold Red
        case ASLLevelError:
            return @"\033[0;31m"; // Red
        case ASLLevelWarning:
            return @"\033[0;33m"; // Yellow
        case ASLLevelNotice:
            return @"\033[0;32m"; // Green
        case ASLLevelInfo:
            return @"\033[0;36m"; // Cyan
        case ASLLevelDebug:
            return @"\033[0;37m"; // White
        default:
            return @"";
    }
}

+ (NSString *)resetColor {
    return @"\033[0m";
}

@end
