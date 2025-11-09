//
//  MobileDeviceManager.m
//  syslogger
//
//  Singleton manager for dynamically loading MobileDevice.framework
//

#import "MobileDeviceManager.h"
#import <dlfcn.h>

@interface MobileDeviceManager ()
@property (nonatomic, assign) void *frameworkHandle;
@property (nonatomic, assign, readwrite) BOOL frameworkLoaded;
@property (nonatomic, strong, readwrite) NSMutableArray<NSValue *> *connectedDevices;
@end

@implementation MobileDeviceManager

#pragma mark - Singleton

+ (instancetype)sharedManager {
    static MobileDeviceManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _frameworkLoaded = NO;
        _frameworkHandle = NULL;
        _connectedDevices = [NSMutableArray array];

        // Automatically load framework on initialization
        [self loadMobileDeviceFramework];
    }
    return self;
}

#pragma mark - Framework Loading

- (BOOL)loadMobileDeviceFramework {
    if (self.frameworkLoaded) {
        return YES;
    }

    // Try to load MobileDevice.framework from common locations
    NSArray *possiblePaths = @[
        @"/System/Library/PrivateFrameworks/MobileDevice.framework/MobileDevice",
        @"/System/Library/PrivateFrameworks/MobileDevice.framework/Versions/A/MobileDevice",
        @"/Library/Apple/System/Library/PrivateFrameworks/MobileDevice.framework/MobileDevice",
        @"/Library/Apple/System/Library/PrivateFrameworks/MobileDevice.framework/Versions/A/MobileDevice"
    ];

    for (NSString *path in possiblePaths) {
        self.frameworkHandle = dlopen([path UTF8String], RTLD_LAZY);
        if (self.frameworkHandle) {
            NSLog(@"[MobileDeviceManager] Successfully loaded MobileDevice.framework from: %@", path);
            break;
        }
    }

    if (!self.frameworkHandle) {
        NSLog(@"[MobileDeviceManager] ERROR: Failed to load MobileDevice.framework");
        NSLog(@"[MobileDeviceManager] This application requires MobileDevice.framework which is part of Xcode/iTunes");
        return NO;
    }

    // Load all function pointers
    BOOL success = [self loadFunctionPointers];
    if (success) {
        self.frameworkLoaded = YES;
        NSLog(@"[MobileDeviceManager] All function pointers loaded successfully");
    } else {
        NSLog(@"[MobileDeviceManager] ERROR: Failed to load some function pointers");
        dlclose(self.frameworkHandle);
        self.frameworkHandle = NULL;
    }

    return self.frameworkLoaded;
}

- (BOOL)loadFunctionPointers {
    // Device notification functions
    _AMDeviceNotificationSubscribe = (AMDeviceNotificationSubscribe_t)dlsym(self.frameworkHandle, "AMDeviceNotificationSubscribe");
    _AMDeviceNotificationUnsubscribe = (AMDeviceNotificationUnsubscribe_t)dlsym(self.frameworkHandle, "AMDeviceNotificationUnsubscribe");

    // Basic device functions
    _AMDeviceConnect = (AMDeviceConnect_t)dlsym(self.frameworkHandle, "AMDeviceConnect");
    _AMDeviceDisconnect = (AMDeviceDisconnect_t)dlsym(self.frameworkHandle, "AMDeviceDisconnect");
    _AMDeviceStartSession = (AMDeviceStartSession_t)dlsym(self.frameworkHandle, "AMDeviceStartSession");
    _AMDeviceStopSession = (AMDeviceStopSession_t)dlsym(self.frameworkHandle, "AMDeviceStopSession");
    _AMDeviceCopyValue = (AMDeviceCopyValue_t)dlsym(self.frameworkHandle, "AMDeviceCopyValue");
    _AMDeviceCopyDeviceIdentifier = (AMDeviceCopyDeviceIdentifier_t)dlsym(self.frameworkHandle, "AMDeviceCopyDeviceIdentifier");
    _AMDeviceValidatePairing = (AMDeviceValidatePairing_t)dlsym(self.frameworkHandle, "AMDeviceValidatePairing");

    // Modern service API (macOS 10.13+)
    _AMDeviceSecureStartService = (AMDeviceSecureStartService_t)dlsym(self.frameworkHandle, "AMDeviceSecureStartService");
    _AMDServiceConnectionGetSocket = (AMDServiceConnectionGetSocket_t)dlsym(self.frameworkHandle, "AMDServiceConnectionGetSocket");
    _AMDServiceConnectionInvalidate = (AMDServiceConnectionInvalidate_t)dlsym(self.frameworkHandle, "AMDServiceConnectionInvalidate");
    _AMDServiceConnectionSend = (AMDServiceConnectionSend_t)dlsym(self.frameworkHandle, "AMDServiceConnectionSend");

    // Legacy service API (fallback)
    _AMDeviceStartService = (AMDeviceStartService_t)dlsym(self.frameworkHandle, "AMDeviceStartService");
    _AMDeviceStopService = (AMDeviceStopService_t)dlsym(self.frameworkHandle, "AMDeviceStopService");

    // Device management
    _AMDeviceRestart = (AMDeviceRestart_t)dlsym(self.frameworkHandle, "AMDeviceRestart");
    _AMDeviceReboot = (AMDeviceReboot_t)dlsym(self.frameworkHandle, "AMDeviceReboot");

    // AFC (Apple File Conduit) functions
    _AFCConnectionOpen = (AFCConnectionOpen_t)dlsym(self.frameworkHandle, "AFCConnectionOpen");
    _AFCConnectionClose = (AFCConnectionClose_t)dlsym(self.frameworkHandle, "AFCConnectionClose");
    _AFCDirectoryOpen = (AFCDirectoryOpen_t)dlsym(self.frameworkHandle, "AFCDirectoryOpen");
    _AFCDirectoryRead = (AFCDirectoryRead_t)dlsym(self.frameworkHandle, "AFCDirectoryRead");
    _AFCDirectoryClose = (AFCDirectoryClose_t)dlsym(self.frameworkHandle, "AFCDirectoryClose");
    _AFCFileRefOpen = (AFCFileRefOpen_t)dlsym(self.frameworkHandle, "AFCFileRefOpen");
    _AFCFileRefClose = (AFCFileRefClose_t)dlsym(self.frameworkHandle, "AFCFileRefClose");
    _AFCFileRefWrite = (AFCFileRefWrite_t)dlsym(self.frameworkHandle, "AFCFileRefWrite");
    _AFCFileRefRead = (AFCFileRefRead_t)dlsym(self.frameworkHandle, "AFCFileRefRead");
    _AFCRemovePath = (AFCRemovePath_t)dlsym(self.frameworkHandle, "AFCRemovePath");
    _AFCFileInfoOpen = (AFCFileInfoOpen_t)dlsym(self.frameworkHandle, "AFCFileInfoOpen");
    _AFCKeyValueRead = (AFCKeyValueRead_t)dlsym(self.frameworkHandle, "AFCKeyValueRead");
    _AFCKeyValueClose = (AFCKeyValueClose_t)dlsym(self.frameworkHandle, "AFCKeyValueClose");
    _AFCDirectoryCreate = (AFCDirectoryCreate_t)dlsym(self.frameworkHandle, "AFCDirectoryCreate");

    // Verify critical functions are loaded
    if (!_AMDeviceNotificationSubscribe || !_AMDeviceConnect || !_AMDeviceStartSession ||
        !_AMDeviceCopyValue || !_AMDeviceValidatePairing) {
        NSLog(@"[MobileDeviceManager] ERROR: Failed to load critical function pointers");
        return NO;
    }

    // Check if modern or legacy service API is available
    BOOL hasModernAPI = (_AMDeviceSecureStartService && _AMDServiceConnectionGetSocket && _AMDServiceConnectionInvalidate);
    BOOL hasLegacyAPI = (_AMDeviceStartService != NULL);

    if (!hasModernAPI && !hasLegacyAPI) {
        NSLog(@"[MobileDeviceManager] ERROR: Neither modern nor legacy service API is available");
        return NO;
    }

    if (hasModernAPI) {
        NSLog(@"[MobileDeviceManager] Using modern AMDeviceSecureStartService API");
    } else {
        NSLog(@"[MobileDeviceManager] WARNING: Using legacy AMDeviceStartService API");
    }

    return YES;
}

#pragma mark - Device Notifications

- (BOOL)subscribeToDeviceNotifications:(void (*)(struct am_device_notification_info *, void *))callback
                              userInfo:(nullable void *)userInfo
                          notification:(AMDeviceNotificationRef *)outNotification {
    if (!self.frameworkLoaded) {
        NSLog(@"[MobileDeviceManager] ERROR: Framework not loaded");
        return NO;
    }

    int result = self.AMDeviceNotificationSubscribe(callback, 0, 0, userInfo, outNotification);
    if (result != 0) {
        NSLog(@"[MobileDeviceManager] ERROR: AMDeviceNotificationSubscribe failed with error: %d", result);
        return NO;
    }

    NSLog(@"[MobileDeviceManager] Successfully subscribed to device notifications");
    return YES;
}

#pragma mark - Utility Methods

- (nullable NSString *)getDeviceUDID:(AMDeviceRef)device {
    if (!device || !self.frameworkLoaded) return nil;

    CFStringRef udid = self.AMDeviceCopyDeviceIdentifier(device);
    if (!udid) return nil;

    NSString *udidString = (__bridge_transfer NSString *)udid;
    return udidString;
}

- (nullable NSString *)getDeviceProperty:(AMDeviceRef)device
                                  domain:(nullable NSString *)domain
                                     key:(NSString *)key {
    if (!device || !self.frameworkLoaded || !key) return nil;

    CFStringRef domainRef = domain ? (__bridge CFStringRef)domain : NULL;
    CFStringRef keyRef = (__bridge CFStringRef)key;

    CFStringRef value = self.AMDeviceCopyValue(device, domainRef, keyRef);
    if (!value) return nil;

    // Handle both CFString and other CF types
    if (CFGetTypeID(value) == CFStringGetTypeID()) {
        return (__bridge_transfer NSString *)value;
    } else {
        // Convert to string description
        CFStringRef desc = CFCopyDescription(value);
        CFRelease(value);
        return (__bridge_transfer NSString *)desc;
    }
}

- (nullable NSString *)getDeviceName:(AMDeviceRef)device {
    return [self getDeviceProperty:device domain:nil key:@"DeviceName"];
}

- (nullable NSString *)getProductType:(AMDeviceRef)device {
    return [self getDeviceProperty:device domain:nil key:@"ProductType"];
}

- (nullable NSString *)getProductVersion:(AMDeviceRef)device {
    return [self getDeviceProperty:device domain:nil key:@"ProductVersion"];
}

#pragma mark - Cleanup

- (void)dealloc {
    if (self.frameworkHandle) {
        dlclose(self.frameworkHandle);
        self.frameworkHandle = NULL;
    }
}

@end
