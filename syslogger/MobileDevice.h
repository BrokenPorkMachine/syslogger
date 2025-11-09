#import <CoreFoundation/CoreFoundation.h>

/*
 * This is a "re-creation" of the private MobileDevice.framework headers.
 * We define the C types and function pointers we need to load dynamically.
 */

// Define opaque C structures
typedef struct __am_device * AMDeviceRef;

struct am_device_notification_info {
    AMDeviceRef device;     // The device object
    unsigned int msg;       // The event (e.g., connected, disconnected)
    // ... there are more fields, but we only need 'device'
};
typedef struct am_device_notification * AMDeviceNotificationRef;

// Define function pointer types
typedef int (*AMDeviceNotificationSubscribe_t)(
    void (*callback)(struct am_device_notification_info *info, void *arg),
    int flags,
    int unused,
    void *arg,
    AMDeviceNotificationRef *notification
);

typedef int (*AMDeviceNotificationUnsubscribe_t)(AMDeviceNotificationRef notification);
typedef int (*AMDeviceConnect_t)(AMDeviceRef device);
typedef int (*AMDeviceDisconnect_t)(AMDeviceRef device);
typedef int (*AMDeviceStartSession_t)(AMDeviceRef device);
typedef int (*AMDeviceStopSession_t)(AMDeviceRef device);
typedef CFStringRef (*AMDeviceCopyValue_t)(AMDeviceRef device, CFStringRef domain, CFStringRef key);
typedef CFStringRef (*AMDeviceCopyDeviceIdentifier_t)(AMDeviceRef device); // Gets the UDID
typedef int (*AMDeviceValidatePairing_t)(AMDeviceRef device);

// Modern service connection API (macOS 10.13+)
typedef int (*AMDeviceSecureStartService_t)(AMDeviceRef device, CFStringRef service_name, CFDictionaryRef options, void **service_connection);
typedef int (*AMDServiceConnectionGetSocket_t)(void *service_connection);
typedef void (*AMDServiceConnectionInvalidate_t)(void *service_connection);
typedef int (*AMDServiceConnectionSend_t)(void *service_connection, const void *data, size_t size);

// Legacy service API (older macOS versions)
typedef int (*AMDeviceStartService_t)(AMDeviceRef device, CFStringRef service_name, int *socket_fd, unsigned int *unknown);
typedef int (*AMDeviceStopService_t)(AMDeviceRef device, int socket_fd);



typedef int (*AMDeviceRestart_t)(AMDeviceRef device, int options);
typedef int (*AMDeviceReboot_t)(AMDeviceRef device, int options);

// AFC (Apple File Conduit) Connection Types
typedef struct __afc_connection * AFCConnectionRef;

// AFC Operation Modes
typedef enum {
    AFC_FOPEN_RDONLY = 0x00000001,
    AFC_FOPEN_RW     = 0x00000002,
    AFC_FOPEN_WRONLY = 0x00000003,
    AFC_FOPEN_WR     = 0x00000004,
    AFC_FOPEN_APPEND = 0x00000005,
    AFC_FOPEN_RDAPPEND = 0x00000006
} AFCFileMode;

// AFC Function Pointers
typedef int (*AFCConnectionOpen_t)(void *service_connection, unsigned int io_timeout, AFCConnectionRef *afc_connection);
typedef int (*AFCConnectionClose_t)(AFCConnectionRef afc_connection);
typedef int (*AFCDirectoryOpen_t)(AFCConnectionRef afc_connection, const char *path, void **dir);
typedef int (*AFCDirectoryRead_t)(AFCConnectionRef afc_connection, void *dir, char **dirent);
typedef int (*AFCDirectoryClose_t)(AFCConnectionRef afc_connection, void *dir);
typedef int (*AFCFileRefOpen_t)(AFCConnectionRef afc_connection, const char *path, unsigned long long mode, void **ref);
typedef int (*AFCFileRefClose_t)(AFCConnectionRef afc_connection, void *ref);
typedef int (*AFCFileRefWrite_t)(AFCConnectionRef afc_connection, void *ref, const void *buf, size_t len);
typedef int (*AFCFileRefRead_t)(AFCConnectionRef afc_connection, void *ref, void *buf, size_t *len);
typedef int (*AFCRemovePath_t)(AFCConnectionRef afc_connection, const char *path);
typedef int (*AFCFileInfoOpen_t)(AFCConnectionRef afc_connection, const char *path, void **dict);
typedef int (*AFCKeyValueRead_t)(void *dict, char **key, char **val);
typedef int (*AFCKeyValueClose_t)(void *dict);
typedef int (*AFCDirectoryCreate_t)(AFCConnectionRef afc_connection, const char *path);

// Diagnostics Relay Service - NOT USED, use service-based approach instead
// We'll use AMDeviceSecureStartService with "com.apple.mobile.diagnostics_relay" service
// and send plist commands over the socket connection

#define AMD_MSG_CONNECTED    1
#define AMD_MSG_DISCONNECTED 2
