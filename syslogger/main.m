//
//  main.m
//  syslogger
//
//  Created by failbr34k on 2025-11-09.
//

#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSArray<NSString *> *args = [[NSProcessInfo processInfo] arguments];
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
