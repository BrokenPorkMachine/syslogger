//
//  ASLMessage.h
//  St0rmActivatorA12
//
//  Apple System Log (ASL) Format Implementation
//  Full ASL message structure and parser for iOS syslog data
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// ASL Log Levels (matching syslog severity levels)
typedef NS_ENUM(NSInteger, ASLLevel) {
    ASLLevelEmergency   = 0,  // System is unusable
    ASLLevelAlert       = 1,  // Action must be taken immediately
    ASLLevelCritical    = 2,  // Critical conditions
    ASLLevelError       = 3,  // Error conditions
    ASLLevelWarning     = 4,  // Warning conditions
    ASLLevelNotice      = 5,  // Normal but significant condition
    ASLLevelInfo        = 6,  // Informational
    ASLLevelDebug       = 7   // Debug-level messages
};

// ASL Facility codes
typedef NS_ENUM(NSInteger, ASLFacility) {
    ASLFacilityKernel       = 0,   // Kernel messages
    ASLFacilityUser         = 1,   // User-level messages
    ASLFacilityMail         = 2,   // Mail system
    ASLFacilityDaemon       = 3,   // System daemons
    ASLFacilityAuth         = 4,   // Security/authorization messages
    ASLFacilitySyslog       = 5,   // Messages generated internally by syslogd
    ASLFacilityLPR          = 6,   // Line printer subsystem
    ASLFacilityNews         = 7,   // Network news subsystem
    ASLFacilityUUCP         = 8,   // UUCP subsystem
    ASLFacilityClock        = 9,   // Clock daemon
    ASLFacilityAuthPriv     = 10,  // Security/authorization messages (private)
    ASLFacilityFTP          = 11,  // FTP daemon
    ASLFacilityNTP          = 12,  // NTP subsystem
    ASLFacilitySecure       = 13,  // Log audit
    ASLFacilityConsole      = 14,  // Log alert
    ASLFacilityLocal0       = 16,  // Reserved for local use
    ASLFacilityLocal1       = 17,
    ASLFacilityLocal2       = 18,
    ASLFacilityLocal3       = 19,
    ASLFacilityLocal4       = 20,
    ASLFacilityLocal5       = 21,
    ASLFacilityLocal6       = 22,
    ASLFacilityLocal7       = 23
};

/**
 * ASLMessage - Represents a complete Apple System Log message
 *
 * This class encapsulates all fields of an ASL log entry including
 * standard fields (time, host, sender, PID, etc.) and extended
 * key-value attributes.
 */
@interface ASLMessage : NSObject

// Standard ASL Fields
@property (nonatomic, strong) NSDate *time;              // Message timestamp
@property (nonatomic, strong, nullable) NSString *host;  // Device/host name
@property (nonatomic, strong, nullable) NSString *sender; // Process name
@property (nonatomic, assign) pid_t pid;                 // Process ID
@property (nonatomic, assign) uid_t uid;                 // User ID
@property (nonatomic, assign) gid_t gid;                 // Group ID
@property (nonatomic, assign) ASLLevel level;            // Log level/severity
@property (nonatomic, strong) NSString *message;         // Log message text
@property (nonatomic, assign) ASLFacility facility;      // Syslog facility

// Extended ASL Fields (iOS-specific)
@property (nonatomic, strong, nullable) NSString *category;    // Log category
@property (nonatomic, strong, nullable) NSString *subsystem;   // Subsystem identifier
@property (nonatomic, strong, nullable) NSString *messageType; // Message type
@property (nonatomic, assign) uint64_t threadID;               // Thread identifier
@property (nonatomic, strong, nullable) NSString *activity;    // Activity identifier
@property (nonatomic, strong, nullable) NSString *processImagePath; // Full process path

// Additional key-value pairs
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *extendedAttributes;

// Initialization
- (instancetype)init;
- (instancetype)initWithDictionary:(NSDictionary *)dict;

// Field accessors
- (void)setValue:(NSString *)value forKey:(NSString *)key;
- (nullable NSString *)valueForKey:(NSString *)key;

// Level conversion utilities
+ (ASLLevel)levelFromString:(NSString *)levelString;
+ (NSString *)stringFromLevel:(ASLLevel)level;
+ (NSString *)shortStringFromLevel:(ASLLevel)level;

// Facility conversion utilities
+ (ASLFacility)facilityFromString:(NSString *)facilityString;
+ (NSString *)stringFromFacility:(ASLFacility)facility;

// Formatting
- (NSString *)formattedString;                    // Standard ASL format
- (NSString *)formattedStringWithStyle:(NSString *)style; // Custom formatting
- (NSString *)compactFormat;                      // Compact one-line format
- (NSString *)detailedFormat;                     // Verbose multi-line format
- (NSString *)idevicesyslogFormat;                // libimobiledevice compatible format

// Comparison and filtering
- (BOOL)matchesFilter:(NSDictionary *)filter;
- (BOOL)isImportantMessage;

@end

/**
 * ASLParser - Parses raw syslog data into ASLMessage objects
 *
 * Supports both text-based and binary ASL formats from iOS devices
 */
@interface ASLParser : NSObject

// Parse single line of text syslog
+ (nullable ASLMessage *)parseTextLine:(NSString *)line;

// Parse binary ASL data
+ (nullable ASLMessage *)parseBinaryData:(NSData *)data;

// Parse multiple lines
+ (NSArray<ASLMessage *> *)parseTextLines:(NSString *)text;

// Parse raw syslog_relay output
+ (nullable ASLMessage *)parseSyslogRelayData:(NSData *)data;

// Parse iOS 10+ os_log format
+ (nullable ASLMessage *)parseOSLogLine:(NSString *)line;

@end

/**
 * ASLFormatter - Formats ASLMessage objects for display
 */
@interface ASLFormatter : NSObject

// Format options
@property (nonatomic, assign) BOOL showTimestamp;
@property (nonatomic, assign) BOOL showHost;
@property (nonatomic, assign) BOOL showPID;
@property (nonatomic, assign) BOOL showLevel;
@property (nonatomic, assign) BOOL colorize;
@property (nonatomic, assign) BOOL verbose;
@property (nonatomic, assign) NSInteger maxMessageLength;

// Date format
@property (nonatomic, strong) NSDateFormatter *dateFormatter;

// Initialization
- (instancetype)init;
+ (instancetype)defaultFormatter;
+ (instancetype)compactFormatter;
+ (instancetype)verboseFormatter;
+ (instancetype)idevicesyslogFormatter;

// Format single message
- (NSString *)formatMessage:(ASLMessage *)message;

// Format multiple messages
- (NSString *)formatMessages:(NSArray<ASLMessage *> *)messages;

// ANSI color codes for terminal output (if colorize is enabled)
+ (NSString *)colorForLevel:(ASLLevel)level;
+ (NSString *)resetColor;

@end

NS_ASSUME_NONNULL_END
