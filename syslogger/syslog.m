#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <Security/Security.h>
#import "MobileDevice.h"
#import "ASLMessage.h"

// -----------------------------------------------------------------
// MARK: - Syslog Formatting (libimobiledevice-style)
// -----------------------------------------------------------------

// Filter and clean syslog line to remove binary/non-printable characters
// Returns nil if the line is mostly binary garbage
- (NSString *)cleanSyslogLine:(NSString *)line {
    if (line.length == 0) return nil;

    // Count printable vs non-printable characters
    NSInteger printableCount = 0;
    NSInteger totalCount = line.length;
    NSMutableString *cleaned = [NSMutableString stringWithCapacity:totalCount];

    for (NSInteger i = 0; i < totalCount; i++) {
        unichar ch = [line characterAtIndex:i];

        // Allow printable ASCII characters (32-126), tabs (9), newlines (10), and carriage returns (13)
        if ((ch >= 32 && ch <= 126) || ch == '\t' || ch == '\n' || ch == '\r') {
            [cleaned appendFormat:@"%C", ch];
            printableCount++;
        } else if (ch >= 128) {
            // Allow extended ASCII/Unicode characters (could be part of valid UTF8)
            [cleaned appendFormat:@"%C", ch];
            printableCount++;
        }
        // Skip other control characters
    }

    // If less than 50% of the line is printable, it's likely binary garbage
    if (totalCount > 0 && (double)printableCount / (double)totalCount < 0.5) {
        return nil;
    }

    // If the cleaned line is too short or empty, skip it
    NSString *trimmed = [cleaned stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length < 10) {
        return nil;
    }

    return trimmed;
}

// Determine if a syslog line is important enough to display using ASL parser
- (BOOL)isImportantSyslogLine:(NSString *)line {
    if (line.length == 0) return NO;

    // Clean the line first to remove binary garbage
    NSString *cleanedLine = [self cleanSyslogLine:line];
    if (!cleanedLine) {
        return NO;
    }

    // Parse line using ASL parser
    ASLMessage *message = [ASLParser parseTextLine:cleanedLine];
    if (!message) {
        return NO;
    }

    // Use ASLMessage's built-in importance detection
    return [message isImportantMessage];
}

// Format syslog line using ASL parser and formatter
// Uses Apple System Log format for proper parsing and display
- (NSString *)formatSyslogLine:(NSString *)line lineNumber:(NSInteger)lineNumber {
    if (line.length == 0) return nil;

    // Clean the line first to remove binary garbage
    NSString *cleanedLine = [self cleanSyslogLine:line];
    if (!cleanedLine) {
        return nil;
    }

    // Parse line using ASL parser
    ASLMessage *message = [ASLParser parseTextLine:cleanedLine];
    if (!message) {
        // If parsing fails, return cleaned line if it looks valid
        if (cleanedLine.length > 20) {
            return cleanedLine;
        }
        return nil;
    }

    // Use idevicesyslog-compatible formatter
    ASLFormatter *formatter = [ASLFormatter idevicesyslogFormatter];
    formatter.maxMessageLength = 200; // Truncate long messages

    return [formatter formatMessage:message];
}

// -----------------------------------------------------------------
// MARK: - Enhanced GUID Extraction (Matches A12.sh exactly)
// -----------------------------------------------------------------

// Extract GUID from log output - matches A12.sh exactly
- (NSString *)extractGUIDFromLogOutput:(NSString *)logOutput {
    __block NSString *foundGUID = nil;
    
    // Split by lines and search each line (matches A12.sh line-by-line processing)
    [logOutput enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        if ([line containsString:@"BLDatabaseManager.sqlite"]) {
            [self log:[NSString stringWithFormat:@"[Info] BLDatabaseManager line found (COMPLETE): %@", line]];
            
            // Extract UUID pattern using exact A12.sh regex
            NSString *pattern = @"/private/var/containers/Shared/SystemGroup/[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}/Documents/BLDatabaseManager/BLDatabaseManager\\.sqlite";
            
            NSError *error = nil;
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                                   options:NSRegularExpressionCaseInsensitive
                                                                                     error:&error];
            if (error) {
                [self log:[NSString stringWithFormat:@"[Error] Regex compilation failed: %@", error.localizedDescription]];
                return;
            }
            
            NSRange range = [regex rangeOfFirstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
            if (range.location != NSNotFound) {
                NSString *fullPath = [line substringWithRange:range];
                
                // Extract GUID from the path (matches A12.sh: grep -oE '[0-9A-Fa-f-]{36}' | head -n 1 | tr '[:lower:]' '[:upper:]')
                NSRegularExpression *guidRegex = [NSRegularExpression regularExpressionWithPattern:@"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"
                                                                                           options:0
                                                                                             error:nil];
                NSRange guidRange = [guidRegex rangeOfFirstMatchInString:fullPath
                                                                 options:0
                                                                   range:NSMakeRange(0, fullPath.length)];
                if (guidRange.location != NSNotFound) {
                    foundGUID = [[fullPath substringWithRange:guidRange] uppercaseString];
                    [self log:[NSString stringWithFormat:@"[Info] GUID extracted from BLDatabaseManager: %@", foundGUID]];
                    *stop = YES;
                }
            }
        }
    }];
    
    return foundGUID;
}

- (NSString *)extractGUIDFromSyslogAtPath:(NSString *)syslogPath {
    [self log:@"[Info] Analyzing syslog for GUID..."];
    
    // Check if file exists
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:syslogPath]) {
        [self log:[NSString stringWithFormat:@"[Error] Syslog file not found at: %@", syslogPath]];
        return nil;
    }
    
    // Get file size for debugging
    NSDictionary *attrs = [fm attributesOfItemAtPath:syslogPath error:nil];
    unsigned long long fileSize = [attrs fileSize];
    [self log:[NSString stringWithFormat:@"[Info] Syslog file size: %llu bytes", fileSize]];
    
    if (fileSize == 0) {
        [self log:@"[Warning] Syslog file is empty"];
        return nil;
    }
    
    NSError *error = nil;
    NSString *logContents = [NSString stringWithContentsOfFile:syslogPath
                                                     encoding:NSUTF8StringEncoding
                                                        error:&error];
    
    if (error) {
        [self log:[NSString stringWithFormat:@"[Warning] UTF-8 read failed: %@", error.localizedDescription]];
        // Fallback to ISO Latin if UTF-8 fails
        logContents = [NSString stringWithContentsOfFile:syslogPath
                                                encoding:NSISOLatin1StringEncoding
                                                   error:&error];
        if (error) {
            [self log:[NSString stringWithFormat:@"[Error] Failed to read syslog file: %@", error.localizedDescription]];
            return nil;
        }
    }
    
    // Count lines and check for BL references
    NSArray *lines = [logContents componentsSeparatedByString:@"\n"];
    [self log:[NSString stringWithFormat:@"[Info] Analyzing %ld lines from syslog file", (long)lines.count]];
    
    NSInteger blReferences = 0;
    NSInteger blDatabaseReferences = 0;
    for (NSString *line in lines) {
        if ([line containsString:@"BL"]) {
            blReferences++;
        }
        if ([line containsString:@"BLDatabase"]) {
            blDatabaseReferences++;
        }
    }
    
    [self log:[NSString stringWithFormat:@"[Debug] Found %ld 'BL' references, %ld 'BLDatabase' references", (long)blReferences, (long)blDatabaseReferences]];
    
    // Use the same real-time extraction method
    return [self extractGUIDFromLogOutput:logContents];
}

- (void)step2_ExtractSyslog {
    [self log:@"STEP 2/14: System Log Extraction"];
    self.currentState = PipelineStateExtractingSyslog;

    // Wait for device to fully boot and initialize services after reboot
    [self log:@"[Info] Waiting 10 seconds for device services to initialize..."];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self performSyslogExtraction];
    });
}

- (void)performSyslogExtraction {
    [self performSyslogExtractionWithRetryCount:0];
}

- (void)performSyslogExtractionWithRetryCount:(NSInteger)retryCount {
    AMDeviceRef device = (AMDeviceRef)([self.deviceInfo[@"AMDeviceRef_NSValue"] pointerValue]);
    if (device == NULL) { [self failPipeline:@"AMDeviceRef is NULL."]; return; }

    MobileDeviceManager *mdm = [MobileDeviceManager sharedManager];

    if (mdm.AMDeviceConnect(device) != 0) { [self failPipeline:@"AMDeviceConnect failed."]; return; }
    if (mdm.AMDeviceValidatePairing(device) != 0) { [self failPipeline:@"AMDeviceValidatePairing failed."]; mdm.AMDeviceDisconnect(device); return; }
    if (mdm.AMDeviceStartSession(device) != 0) { [self failPipeline:@"AMDeviceStartSession failed."]; mdm.AMDeviceDisconnect(device); return; }

    // Query all gestalt properties to trigger cache access before syslog capture
    // This increases the chances of the gestalt cache being accessed during syslogging,
    // exposing the GUID we need
    [self log:@"[Info] Querying device properties to trigger gestalt cache access..."];
    [self queryAllGestaltProperties];
    [self log:@"[Info] Gestalt query complete. Now capturing syslog..."];

    // Use modern AMDeviceSecureStartService API with AMDServiceConnectionGetSocket
    int socket_fd = -1;
    void* conn = NULL;
    int ret = mdm.AMDeviceSecureStartService(device, CFSTR("com.apple.syslog_relay"), NULL, &conn);
    if (ret == 0 && conn != NULL) {
        socket_fd = mdm.AMDServiceConnectionGetSocket(conn);
    }

    if (socket_fd < 0 || conn == NULL) {
        if (conn != NULL) {
            mdm.AMDServiceConnectionInvalidate(conn);
        }
        mdm.AMDeviceStopSession(device);
        mdm.AMDeviceDisconnect(device);

        if (retryCount < 5) {
            NSTimeInterval delay = 3.0 + (retryCount * 2.0);
            [self log:[NSString stringWithFormat:@"[Info] Socket not ready (ret=%d, socket=%d, attempt %ld/5). Retrying in %.0f seconds...", ret, socket_fd, (long)(retryCount + 1), delay]];

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self performSyslogExtractionWithRetryCount:retryCount + 1];
            });
            return;
        } else {
            [self failPipeline:[NSString stringWithFormat:@"Failed to get valid socket from syslog_relay service after 5 attempts (last ret=%d, socket=%d).", ret, socket_fd]];
            return;
        }
    }

    if (ret != 0) {
        [self failPipeline:[NSString stringWithFormat:@"syslog_relay returned error %d with valid socket %d (unexpected).", ret, socket_fd]];
        if (conn != NULL) {
            mdm.AMDServiceConnectionInvalidate(conn);
        }
        close(socket_fd);
        mdm.AMDeviceStopSession(device);
        mdm.AMDeviceDisconnect(device);
        return;
    }

    [self log:[NSString stringWithFormat:@"[Info] Syslog service started on socket %d", socket_fd]];
    [self log:@"[Info] Reading syslog stream until GUID is found (max 30 seconds)..."];
    [self log:@"[Info] ** TIP: Device may need to use Books app or media to generate BLDatabaseManager logs **"];

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *syslogPath = [[paths firstObject] stringByAppendingPathComponent:@"device_syslog.log"];
    [self log:[NSString stringWithFormat:@"[Info] Saving syslog to: %@", syslogPath]];

    FILE *logFile = fopen([syslogPath UTF8String], "w");
    if (!logFile) {
        [self failPipeline:@"Failed to open log file for writing"];
        if (conn != NULL) {
            mdm.AMDServiceConnectionInvalidate(conn);
        }
        close(socket_fd);
        mdm.AMDeviceStopSession(device);
        mdm.AMDeviceDisconnect(device);
        return;
    }
    
    [self log:[NSString stringWithFormat:@"[Info] Created syslog file: %@", syslogPath]];
    [self log:@"[Info] You can manually inspect this file if GUID extraction fails"];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        char buffer[4096];
        ssize_t bytesRead;
        NSDate *startTime = [NSDate date];
        NSTimeInterval maxDuration = 30.0; // Increased to 30 seconds
        int totalLines = 0;
        __block NSString *foundGUID = nil;
        __block NSString *lineBuffer = @""; // Buffer for incomplete lines

        fcntl(socket_fd, F_SETFL, O_NONBLOCK);

        while ([[NSDate date] timeIntervalSinceDate:startTime] < maxDuration && foundGUID == nil) {
            bytesRead = recv(socket_fd, buffer, sizeof(buffer) - 1, 0);
            if (bytesRead > 0) {
                buffer[bytesRead] = '\0';

                // Write to file
                fwrite(buffer, 1, bytesRead, logFile);
                fflush(logFile);

                // Process buffer in real-time to find GUID
                NSString *chunk = [[NSString alloc] initWithBytes:buffer length:bytesRead encoding:NSUTF8StringEncoding];
                if (!chunk) {
                    // Fallback to ISO Latin if UTF-8 fails
                    chunk = [[NSString alloc] initWithBytes:buffer length:bytesRead encoding:NSISOLatin1StringEncoding];
                }

                if (chunk) {
                    // Append to line buffer for proper line processing
                    lineBuffer = [lineBuffer stringByAppendingString:chunk];

                    // Process complete lines
                    NSArray *lines = [lineBuffer componentsSeparatedByString:@"\n"];

                    // Keep the last incomplete line in buffer
                    lineBuffer = [lines lastObject];

                    // Process complete lines (all but last)
                    for (NSUInteger i = 0; i < lines.count - 1; i++) {
                        NSString *line = lines[i];
                        if (line.length == 0) continue;

                        totalLines++;

                        // Format and display important syslog entries (like idevicesyslog)
                        if ([self isImportantSyslogLine:line]) {
                            NSString *formattedLine = [self formatSyslogLine:line lineNumber:totalLines];
                            if (formattedLine) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [self log:[NSString stringWithFormat:@"[Syslog] %@", formattedLine]];
                                });
                            }
                        }

                        // Search for GUID in this line
                        if ([line containsString:@"BLDatabaseManager.sqlite"]) {
                            NSString *guid = [self extractGUIDFromLogOutput:line];
                            if (guid) {
                                foundGUID = guid;
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [self log:[NSString stringWithFormat:@"[✓] Found GUID in syslog: %@", guid]];
                                });
                                break;
                            }
                        }
                    }

                    // Progress update every 100 lines
                    if (totalLines % 100 == 0 && totalLines > 0) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
                            [self log:[NSString stringWithFormat:@"[Syslog] Captured %d lines (%.1fs elapsed)", totalLines, elapsed]];
                        });
                    }
                }

            } else if (bytesRead == 0) {
                break;
            } else if (errno != EAGAIN && errno != EWOULDBLOCK) {
                break;
            }
            usleep(10000); // 10ms
        }

        fclose(logFile);
        if (conn != NULL) {
            mdm.AMDServiceConnectionInvalidate(conn);
        }
        close(socket_fd);
        mdm.AMDeviceStopSession(device);
        mdm.AMDeviceDisconnect(device);

        dispatch_async(dispatch_get_main_queue(), ^{
            [self log:[NSString stringWithFormat:@"[✓] Syslog extraction completed! Captured %d lines", totalLines]];
            self.totalStepsCompleted++; // Step 2 completed

            if (foundGUID) {
                [self log:[NSString stringWithFormat:@"[✓] GUID found during streaming: %@", foundGUID]];
                self.extractedGUID = foundGUID;
                self.totalStepsCompleted++; // Step 3 also completed (GUID extraction)
                [self step4_CallAPI];
            } else {
                [self log:@"[Info] GUID not found during streaming, analyzing saved log file..."];
                [self log:@"[Info] If GUID extraction continues to fail, check the troubleshooting tips in the next step"];
                [self step3_AnalyzeSyslogWithRetryCount:0];
            }
        });
    });
}

- (void)step3_AnalyzeSyslogWithRetryCount:(NSInteger)retryCount {
    if (retryCount == 0) {
        [self log:@"STEP 3/14: GUID Analysis..."];
        self.currentState = PipelineStateAnalyzingSyslog;
    } else {
        [self log:[NSString stringWithFormat:@"[Info] GUID Analysis retry attempt %ld/5...", (long)retryCount]];
    }

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *syslogPath = [[paths firstObject] stringByAppendingPathComponent:@"device_syslog.log"];

    // Use the enhanced GUID extraction method
    NSString *foundGUID = [self extractGUIDFromSyslogAtPath:syslogPath];
    
    if (foundGUID) {
        self.extractedGUID = foundGUID;
        [self log:[NSString stringWithFormat:@"[✓] GUID extracted: %@", self.extractedGUID]];
        self.totalStepsCompleted++; // Step 3 completed
        [self step4_CallAPI];
    } else {
        // GUID not found - retry up to 5 times
        if (retryCount < 5) {
            NSTimeInterval delay = 5.0;
            [self log:[NSString stringWithFormat:@"[Warning] GUID not found in current syslog (attempt %ld/5). Extracting more syslog in %.0f seconds...", (long)(retryCount + 1), delay]];
            
            // Show helpful hints
            if (retryCount == 0) {
                [self log:@"[Info] ** TIP: Try opening Books app or playing media on device to trigger BLDatabaseManager logs **"];
            } else if (retryCount == 2) {
                [self log:@"[Info] ** TIP: Some devices require accessing iTunes Store or media content **"];
            }

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self performSyslogExtractionForRetry:retryCount + 1];
            });
        } else {
            [self log:@"[Error] GUID not found after 5 analysis attempts"];
            [self log:@"[Info] ** TROUBLESHOOTING TIPS **"];
            [self log:@"[Info] 1. Ensure device is unlocked and awake"];
            [self log:@"[Info] 2. Try opening Books app on device"];
            [self log:@"[Info] 3. Try accessing iTunes Store or media content"];
            [self log:@"[Info] 4. Some devices require specific user interaction to generate logs"];
            [self log:@"[Info] 5. Device may need to be in a specific activation state"];

            NSString *errorMsg = @"Could not find BLDatabaseManager GUID in syslog after 5 attempts.";
            if (self.continueOnFailure) {
                [self failPipeline:errorMsg attemptContinue:YES fromStep:@"step3_AnalyzeSyslog"];
                [self log:@"[Info] Continuing to next step despite GUID extraction failure..."];
                [self step4_CallAPI]; // Continue to next step
            } else {
                [self failPipeline:errorMsg];
            }
        }
    }
}

- (void)performSyslogExtractionForRetry:(NSInteger)retryCount {
    [self log:[NSString stringWithFormat:@"[Info] Extracting additional syslog data (retry %ld/5)...", (long)retryCount]];

    AMDeviceRef device = (AMDeviceRef)([self.deviceInfo[@"AMDeviceRef_NSValue"] pointerValue]);
    if (device == NULL) { [self failPipeline:@"AMDeviceRef is NULL."]; return; }

    MobileDeviceManager *mdm = [MobileDeviceManager sharedManager];

    if (mdm.AMDeviceConnect(device) != 0) { [self failPipeline:@"AMDeviceConnect failed."]; return; }
    if (mdm.AMDeviceValidatePairing(device) != 0) { [self failPipeline:@"AMDeviceValidatePairing failed."]; mdm.AMDeviceDisconnect(device); return; }
    if (mdm.AMDeviceStartSession(device) != 0) { [self failPipeline:@"AMDeviceStartSession failed."]; mdm.AMDeviceDisconnect(device); return; }

    int socket_fd = -1;
    void* conn = NULL;
    int ret = mdm.AMDeviceSecureStartService(device, CFSTR("com.apple.syslog_relay"), NULL, &conn);
    if (ret == 0 && conn != NULL) {
        socket_fd = mdm.AMDServiceConnectionGetSocket(conn);
    }

    if (socket_fd < 0) {
        if (conn != NULL) {
            mdm.AMDServiceConnectionInvalidate(conn);
        }
        mdm.AMDeviceStopSession(device);
        mdm.AMDeviceDisconnect(device);
        [self failPipeline:[NSString stringWithFormat:@"Failed to get syslog socket for retry %ld", (long)retryCount]];
        return;
    }

    [self log:[NSString stringWithFormat:@"[Info] Syslog service started on socket %d for retry", socket_fd]];
    [self log:@"[Info] Reading syslog stream for 15 seconds..."];

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *syslogPath = [[paths firstObject] stringByAppendingPathComponent:@"device_syslog.log"];

    FILE *logFile = fopen([syslogPath UTF8String], "a");
    if (!logFile) {
        [self failPipeline:@"Failed to open log file for appending"];
        if (conn != NULL) {
            mdm.AMDServiceConnectionInvalidate(conn);
        }
        close(socket_fd);
        mdm.AMDeviceStopSession(device);
        mdm.AMDeviceDisconnect(device);
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        char buffer[4096];
        ssize_t bytesRead;
        NSDate *startTime = [NSDate date];
        NSTimeInterval maxDuration = 15.0;
        int totalLines = 0;
        __block NSString *lineBuffer = @""; // Buffer for incomplete lines
        fcntl(socket_fd, F_SETFL, O_NONBLOCK);

        while ([[NSDate date] timeIntervalSinceDate:startTime] < maxDuration) {
            bytesRead = recv(socket_fd, buffer, sizeof(buffer) - 1, 0);
            if (bytesRead > 0) {
                buffer[bytesRead] = '\0';
                fwrite(buffer, 1, bytesRead, logFile);
                fflush(logFile);

                // Process and format syslog output for retry too
                NSString *chunk = [[NSString alloc] initWithBytes:buffer length:bytesRead encoding:NSUTF8StringEncoding];
                if (!chunk) {
                    chunk = [[NSString alloc] initWithBytes:buffer length:bytesRead encoding:NSISOLatin1StringEncoding];
                }

                if (chunk) {
                    lineBuffer = [lineBuffer stringByAppendingString:chunk];
                    NSArray *lines = [lineBuffer componentsSeparatedByString:@"\n"];
                    lineBuffer = [lines lastObject];

                    for (NSUInteger i = 0; i < lines.count - 1; i++) {
                        NSString *line = lines[i];
                        if (line.length == 0) continue;
                        totalLines++;

                        // Format and display important lines
                        if ([self isImportantSyslogLine:line]) {
                            NSString *formattedLine = [self formatSyslogLine:line lineNumber:totalLines];
                            if (formattedLine) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [self log:[NSString stringWithFormat:@"[Syslog] %@", formattedLine]];
                                });
                            }
                        }
                    }

                    // Progress update
                    if (totalLines % 50 == 0 && totalLines > 0) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
                            [self log:[NSString stringWithFormat:@"[Syslog] +%d lines (%.1fs elapsed)", totalLines, elapsed]];
                        });
                    }
                }

            } else if (bytesRead == 0) {
                break;
            } else if (errno != EAGAIN && errno != EWOULDBLOCK) {
                break;
            }
            usleep(10000);
        }

        fclose(logFile);
        if (conn != NULL) {
            mdm.AMDServiceConnectionInvalidate(conn);
        }
        close(socket_fd);
        mdm.AMDeviceStopSession(device);
        mdm.AMDeviceDisconnect(device);

        dispatch_async(dispatch_get_main_queue(), ^{
            [self log:[NSString stringWithFormat:@"[✓] Additional syslog captured! Added %d lines", totalLines]];
            [self step3_AnalyzeSyslogWithRetryCount:retryCount];
        });
    });
}
