//
//  DeviceManager.m
//  syslogger
//
//  Created by failbr34k on 2025-11-09.
//

#import "DeviceManager.h"
#import "MobileDeviceManager.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <fcntl.h>
#import <unistd.h>

// Device notification callback
static void DeviceNotificationCallback(struct am_device_notification_info *info, void *arg);

@interface DeviceManager () {
    AMDeviceRef _device;
    void *_serviceConnection;
    int _socket_fd;
    dispatch_queue_t _syslogQueue;
    dispatch_source_t _readSource;
    BOOL _isStreaming;
    AMDeviceNotificationRef _deviceNotification;
    NSMutableData *_receiveBuffer;
}
@end

@implementation DeviceManager

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        _syslogQueue = dispatch_queue_create("com.syslogger.syslogQueue", DISPATCH_QUEUE_SERIAL);
        _isStreaming = NO;
        _socket_fd = -1;
        _device = NULL;
        _serviceConnection = NULL;
        _deviceNotification = NULL;
        _receiveBuffer = [NSMutableData data];

        // Make sure MobileDevice framework is loaded
        MobileDeviceManager *mdm = [MobileDeviceManager sharedManager];
        if (!mdm.frameworkLoaded) {
            NSLog(@"[DeviceManager] ERROR: MobileDevice framework not loaded!");
        }

        // Subscribe to device notifications
        [self subscribeToDeviceNotifications];
    }
    return self;
}

#pragma mark - Device Notifications

- (void)subscribeToDeviceNotifications {
    MobileDeviceManager *mdm = [MobileDeviceManager sharedManager];
    if (!mdm.frameworkLoaded) {
        NSLog(@"[DeviceManager] Cannot subscribe to notifications - framework not loaded");
        return;
    }

    BOOL success = [mdm subscribeToDeviceNotifications:DeviceNotificationCallback
                                              userInfo:(__bridge void *)self
                                          notification:&_deviceNotification];

    if (success) {
        NSLog(@"[DeviceManager] Subscribed to device notifications");
    } else {
        NSLog(@"[DeviceManager] Failed to subscribe to device notifications");
    }
}

static void DeviceNotificationCallback(struct am_device_notification_info *info, void *arg) {
    DeviceManager *manager = (__bridge DeviceManager *)arg;
    MobileDeviceManager *mdm = [MobileDeviceManager sharedManager];

    if (info->msg == AMD_MSG_CONNECTED) {
        AMDeviceRef device = info->device;
        NSString *udid = [mdm getDeviceUDID:device];
        NSString *name = [mdm getDeviceName:device];
        NSString *version = [mdm getProductVersion:device];

        NSLog(@"[DeviceManager] Device connected: %@ (UDID: %@, iOS: %@)",
              name ? name : @"Unknown", udid ? udid : @"Unknown", version ? version : @"Unknown");

        // If we don't have a device yet and streaming is requested, use this one
        if (manager->_device == NULL && manager->_isStreaming) {
            manager->_device = device;
            dispatch_async(manager->_syslogQueue, ^{
                [manager connectToDeviceAndStartStream];
            });
        } else if (manager->_device == NULL) {
            // Store for later use
            manager->_device = device;
        }

    } else if (info->msg == AMD_MSG_DISCONNECTED) {
        AMDeviceRef device = info->device;
        NSLog(@"[DeviceManager] Device disconnected");

        // If this is our current device, stop streaming
        if (manager->_device == device) {
            dispatch_async(manager->_syslogQueue, ^{
                [manager cleanupDeviceConnection];
            });
            manager->_device = NULL;
        }
    }
}

#pragma mark - Syslog Streaming

- (void)startSyslogStream {
    NSLog(@"[DeviceManager] Starting syslog stream...");

    if (_isStreaming) {
        NSLog(@"[DeviceManager] Already streaming");
        return;
    }

    _isStreaming = YES;

    // If we already have a device, connect immediately
    if (_device != NULL) {
        dispatch_async(_syslogQueue, ^{
            [self connectToDeviceAndStartStream];
        });
    } else {
        NSLog(@"[DeviceManager] Waiting for device connection...");
    }
}

- (void)stopSyslogStream {
    NSLog(@"[DeviceManager] Stopping syslog stream...");

    if (!_isStreaming) {
        return;
    }

    _isStreaming = NO;
    dispatch_async(_syslogQueue, ^{
        [self cleanupDeviceConnection];
    });
}

- (void)connectToDeviceAndStartStream {
    if (!_device) {
        NSLog(@"[DeviceManager] ERROR: No device available");
        [self notifyError:@"No iOS device found. Please connect a device via USB."];
        return;
    }

    MobileDeviceManager *mdm = [MobileDeviceManager sharedManager];
    if (!mdm || !mdm.frameworkLoaded) {
        NSLog(@"[DeviceManager] ERROR: MobileDevice framework not loaded");
        [self notifyError:@"Failed to load MobileDevice framework. This app requires macOS system frameworks."];
        return;
    }

    // Connect to device
    NSLog(@"[DeviceManager] Connecting to device...");
    int connectResult = mdm.AMDeviceConnect(_device);
    if (connectResult != 0) {
        NSLog(@"[DeviceManager] ERROR: AMDeviceConnect failed with code %d", connectResult);
        [self notifyError:@"Failed to connect to device. Please check the USB connection."];
        return;
    }

    // Validate pairing
    int pairingResult = mdm.AMDeviceValidatePairing(_device);
    if (pairingResult != 0) {
        NSLog(@"[DeviceManager] ERROR: AMDeviceValidatePairing failed with code %d", pairingResult);
        [self notifyError:@"Device is not paired with this Mac. Please trust this computer on your iOS device."];
        mdm.AMDeviceDisconnect(_device);
        return;
    }

    // Start session
    int sessionResult = mdm.AMDeviceStartSession(_device);
    if (sessionResult != 0) {
        NSLog(@"[DeviceManager] ERROR: AMDeviceStartSession failed with code %d", sessionResult);
        [self notifyError:@"Failed to start device session. Please reconnect the device."];
        mdm.AMDeviceDisconnect(_device);
        return;
    }

    // Start syslog_relay service
    NSLog(@"[DeviceManager] Starting syslog_relay service...");
    int ret = mdm.AMDeviceSecureStartService(_device, CFSTR("com.apple.syslog_relay"), NULL, &_serviceConnection);
    if (ret == 0 && _serviceConnection != NULL) {
        _socket_fd = mdm.AMDServiceConnectionGetSocket(_serviceConnection);
        if (_socket_fd < 0) {
            NSLog(@"[DeviceManager] ERROR: Invalid socket descriptor");
            [self notifyError:@"Failed to establish connection socket."];
            mdm.AMDeviceStopSession(_device);
            mdm.AMDeviceDisconnect(_device);
            return;
        }

        NSLog(@"[DeviceManager] ✓ Syslog service started successfully on socket %d", _socket_fd);

        // Set socket to non-blocking mode
        int flags = fcntl(_socket_fd, F_GETFL, 0);
        if (flags >= 0) {
            fcntl(_socket_fd, F_SETFL, flags | O_NONBLOCK);
        }

        // Start reading from socket using GCD
        [self startReadingFromSocket];
    } else {
        NSLog(@"[DeviceManager] ERROR: Failed to start syslog_relay service (error: %d)", ret);
        [self notifyError:[NSString stringWithFormat:@"Failed to start syslog service (error code: %d)", ret]];
        mdm.AMDeviceStopSession(_device);
        mdm.AMDeviceDisconnect(_device);
    }
}

- (void)notifyError:(NSString *)errorMessage {
    NSLog(@"[DeviceManager] Notifying error: %@", errorMessage);
    // Could add a delegate method here to notify the UI
}

- (void)startReadingFromSocket {
    if (_socket_fd < 0) {
        NSLog(@"[DeviceManager] Invalid socket");
        return;
    }

    // Create a dispatch source for reading from the socket
    _readSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, _socket_fd, 0, _syslogQueue);

    __weak DeviceManager *weakSelf = self;
    dispatch_source_set_event_handler(_readSource, ^{
        DeviceManager *strongSelf = weakSelf;
        if (!strongSelf) return;

        [strongSelf readFromSocket];
    });

    dispatch_source_set_cancel_handler(_readSource, ^{
        NSLog(@"[DeviceManager] Read source cancelled");
    });

    dispatch_resume(_readSource);
    NSLog(@"[DeviceManager] Started reading from syslog socket");
}

- (void)readFromSocket {
    if (_socket_fd < 0 || !_isStreaming) {
        return;
    }

    char buffer[8192];
    ssize_t bytesRead;

    while ((bytesRead = recv(_socket_fd, buffer, sizeof(buffer), 0)) > 0) {
        NSData *data = [NSData dataWithBytes:buffer length:bytesRead];

        // Send to delegate
        if (self.delegate && [self.delegate respondsToSelector:@selector(didReceiveSyslogData:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate didReceiveSyslogData:data];
            });
        }
    }

    if (bytesRead == 0) {
        // Connection closed
        NSLog(@"[DeviceManager] Socket connection closed");
        dispatch_async(_syslogQueue, ^{
            [self cleanupDeviceConnection];
        });
    } else if (bytesRead < 0 && errno != EAGAIN && errno != EWOULDBLOCK) {
        // Error occurred
        NSLog(@"[DeviceManager] Socket read error: %s", strerror(errno));
        dispatch_async(_syslogQueue, ^{
            [self cleanupDeviceConnection];
        });
    }
}

- (void)cleanupDeviceConnection {
    NSLog(@"[DeviceManager] Cleaning up device connection...");

    // Cancel read source
    if (_readSource) {
        dispatch_source_cancel(_readSource);
        _readSource = NULL;
    }

    MobileDeviceManager *mdm = [MobileDeviceManager sharedManager];

    // Invalidate service connection
    if (_serviceConnection) {
        mdm.AMDServiceConnectionInvalidate(_serviceConnection);
        _serviceConnection = NULL;
    }

    // Close socket
    if (_socket_fd > 0) {
        close(_socket_fd);
        _socket_fd = -1;
    }

    // Stop session and disconnect
    if (_device) {
        mdm.AMDeviceStopSession(_device);
        mdm.AMDeviceDisconnect(_device);
        // Note: Don't set _device to NULL here, it might reconnect
    }

    NSLog(@"[DeviceManager] Device connection cleaned up");
}

#pragma mark - Cleanup

- (void)dealloc {
    NSLog(@"[DeviceManager] Deallocating...");

    [self stopSyslogStream];

    // Unsubscribe from device notifications
    if (_deviceNotification) {
        MobileDeviceManager *mdm = [MobileDeviceManager sharedManager];
        if (mdm.AMDeviceNotificationUnsubscribe) {
            mdm.AMDeviceNotificationUnsubscribe(_deviceNotification);
        }
        _deviceNotification = NULL;
    }
}

@end
