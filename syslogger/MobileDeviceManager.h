//
//  MobileDeviceManager.h
//  syslogger
//
//  Singleton manager for dynamically loading MobileDevice.framework
//  and managing device connections
//

#import <Foundation/Foundation.h>
#import "MobileDevice.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * MobileDeviceManager - Singleton class for managing iOS device connections
 *
 * This class dynamically loads the private MobileDevice.framework at runtime
 * and provides access to all the necessary functions for device communication.
 */
@interface MobileDeviceManager : NSObject

// Singleton accessor
+ (instancetype)sharedManager;

// Framework loading
- (BOOL)loadMobileDeviceFramework;
@property (nonatomic, assign, readonly) BOOL frameworkLoaded;

// Function pointers (populated when framework is loaded)
@property (nonatomic, assign) AMDeviceNotificationSubscribe_t AMDeviceNotificationSubscribe;
@property (nonatomic, assign) AMDeviceNotificationUnsubscribe_t AMDeviceNotificationUnsubscribe;
@property (nonatomic, assign) AMDeviceConnect_t AMDeviceConnect;
@property (nonatomic, assign) AMDeviceDisconnect_t AMDeviceDisconnect;
@property (nonatomic, assign) AMDeviceStartSession_t AMDeviceStartSession;
@property (nonatomic, assign) AMDeviceStopSession_t AMDeviceStopSession;
@property (nonatomic, assign) AMDeviceCopyValue_t AMDeviceCopyValue;
@property (nonatomic, assign) AMDeviceCopyDeviceIdentifier_t AMDeviceCopyDeviceIdentifier;
@property (nonatomic, assign) AMDeviceValidatePairing_t AMDeviceValidatePairing;

// Modern service API
@property (nonatomic, assign) AMDeviceSecureStartService_t AMDeviceSecureStartService;
@property (nonatomic, assign) AMDServiceConnectionGetSocket_t AMDServiceConnectionGetSocket;
@property (nonatomic, assign) AMDServiceConnectionInvalidate_t AMDServiceConnectionInvalidate;
@property (nonatomic, assign) AMDServiceConnectionSend_t AMDServiceConnectionSend;

// Legacy service API (fallback for older macOS)
@property (nonatomic, assign) AMDeviceStartService_t AMDeviceStartService;
@property (nonatomic, assign) AMDeviceStopService_t AMDeviceStopService;

// Device management
@property (nonatomic, assign) AMDeviceRestart_t AMDeviceRestart;
@property (nonatomic, assign) AMDeviceReboot_t AMDeviceReboot;

// AFC (Apple File Conduit) API
@property (nonatomic, assign) AFCConnectionOpen_t AFCConnectionOpen;
@property (nonatomic, assign) AFCConnectionClose_t AFCConnectionClose;
@property (nonatomic, assign) AFCDirectoryOpen_t AFCDirectoryOpen;
@property (nonatomic, assign) AFCDirectoryRead_t AFCDirectoryRead;
@property (nonatomic, assign) AFCDirectoryClose_t AFCDirectoryClose;
@property (nonatomic, assign) AFCFileRefOpen_t AFCFileRefOpen;
@property (nonatomic, assign) AFCFileRefClose_t AFCFileRefClose;
@property (nonatomic, assign) AFCFileRefWrite_t AFCFileRefWrite;
@property (nonatomic, assign) AFCFileRefRead_t AFCFileRefRead;
@property (nonatomic, assign) AFCRemovePath_t AFCRemovePath;
@property (nonatomic, assign) AFCFileInfoOpen_t AFCFileInfoOpen;
@property (nonatomic, assign) AFCKeyValueRead_t AFCKeyValueRead;
@property (nonatomic, assign) AFCKeyValueClose_t AFCKeyValueClose;
@property (nonatomic, assign) AFCDirectoryCreate_t AFCDirectoryCreate;

// Connected devices tracking
@property (nonatomic, strong, readonly) NSMutableArray<NSValue *> *connectedDevices;

// Device notification subscription
- (BOOL)subscribeToDeviceNotifications:(void (*)(struct am_device_notification_info *, void *))callback
                              userInfo:(nullable void *)userInfo
                          notification:(AMDeviceNotificationRef *)outNotification;

// Utility methods
- (nullable NSString *)getDeviceUDID:(AMDeviceRef)device;
- (nullable NSString *)getDeviceProperty:(AMDeviceRef)device
                                  domain:(nullable NSString *)domain
                                     key:(NSString *)key;
- (nullable NSString *)getDeviceName:(AMDeviceRef)device;
- (nullable NSString *)getProductType:(AMDeviceRef)device;
- (nullable NSString *)getProductVersion:(AMDeviceRef)device;

@end

NS_ASSUME_NONNULL_END
