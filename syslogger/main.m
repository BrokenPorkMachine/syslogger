//
//  main.m
//  syslogger
//
//  Created by failbr34k on 2025-11-09.
//

#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

void printHelp() {
    printf("Syslogger - iOS Device System Log Viewer\n");
    printf("=========================================\n\n");
    printf("USAGE:\n");
    printf("  syslogger [OPTIONS]\n\n");

    printf("OPTIONS:\n");
    printf("  --console                  Run in console mode (no GUI)\n");
    printf("  --help, -h                 Show this help message\n\n");

    printf("OUTPUT OPTIONS:\n");
    printf("  --save-to-file             Save syslog output to file\n");
    printf("  --output-file <path>       Specify output file path (default: syslog.txt)\n");
    printf("  --format <type>            Output format: standard, compact, verbose, idevicesyslog (default: idevicesyslog)\n\n");

    printf("DISPLAY OPTIONS:\n");
    printf("  --show-timestamp           Show timestamps (default: on)\n");
    printf("  --no-timestamp             Hide timestamps\n");
    printf("  --show-host                Show host/device name (default: on)\n");
    printf("  --no-host                  Hide host/device name\n");
    printf("  --show-pid                 Show process IDs (default: on)\n");
    printf("  --no-pid                   Hide process IDs\n");
    printf("  --show-level               Show log levels (default: on)\n");
    printf("  --no-level                 Hide log levels\n");
    printf("  --color                    Enable colored output (console only)\n");
    printf("  --no-color                 Disable colored output (default)\n");
    printf("  --max-length <num>         Maximum message length (0 = no limit, default: 0)\n\n");

    printf("FILTERING OPTIONS:\n");
    printf("  --min-level <level>        Minimum log level to display\n");
    printf("                             Levels: emergency, alert, critical, error, warning, notice, info, debug\n");
    printf("  --sender <name>            Filter by process/sender name (partial match)\n");
    printf("  --message <text>           Filter by message content (partial match)\n");
    printf("  --important-only           Show only important messages (default: off)\n\n");

    printf("EXAMPLES:\n");
    printf("  # Run with GUI\n");
    printf("  syslogger\n\n");

    printf("  # Run in console mode with colored output\n");
    printf("  syslogger --console --color\n\n");

    printf("  # Save to file with compact format\n");
    printf("  syslogger --console --save-to-file --output-file device.log --format compact\n\n");

    printf("  # Filter error messages only\n");
    printf("  syslogger --console --min-level error\n\n");

    printf("  # Filter by sender\n");
    printf("  syslogger --console --sender SpringBoard\n\n");

    printf("  # Show important messages only in verbose format\n");
    printf("  syslogger --console --important-only --format verbose\n\n");
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSArray<NSString *> *args = [[NSProcessInfo processInfo] arguments];

        // Check for help flag
        if ([args containsObject:@"--help"] || [args containsObject:@"-h"]) {
            printHelp();
            return 0;
        }

        BOOL runConsole = [args containsObject:@"--console"];

        if (runConsole) {
            AppDelegate *appDelegate = [[AppDelegate alloc] init];
            [appDelegate applicationDidFinishLaunching:nil];
            return 0;
        } else {
            NSApplication *application = [NSApplication sharedApplication];
            AppDelegate *appDelegate = [[AppDelegate alloc] init];
            application.delegate = appDelegate;
            return NSApplicationMain(argc, argv);
        }
    }
}
