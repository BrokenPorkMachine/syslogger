//
//  DeviceManager.m
//  syslogger
//
//  Created by failbr34k on 2025-11-09.
//

#import "DeviceManager.h"

@interface DeviceManager () {
    AMDeviceRef _device;
    void *_serviceConnection;
    int _socket_fd;
    dispatch_queue_t _syslogQueue;
    BOOL _isStreaming;
}
@end

@implementation DeviceManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _syslogQueue = dispatch_queue_create("com.syslogger.syslogQueue", DISPATCH_QUEUE_SERIAL);
        _isStreaming = NO;
    }
    return self;
}

- (void)startSyslogStream {
    if (_isStreaming) {
        return;
    }

    dispatch_async(_syslogQueue, ^{
        [self setupDeviceConnection];
        if (self->_device && self->_socket_fd > 0) {
            self->_isStreaming = YES;
            [self readSyslogStream];
        }
    });
}

- (void)stopSyslogStream {
    if (!_isStreaming) {
        return;
    }

    _isStreaming = NO;
    dispatch_async(_syslogQueue, ^{
        [self cleanupDeviceConnection];
    });
}

- (void)setupDeviceConnection {
    // This is a simplified connection logic. In a real app, you'd handle device notifications.
    // For now, we'll just try to connect to the first available device.
    NSArray *devices = [[MobileDeviceManager sharedManager] connectedDevices];
    if (devices.count == 0) {
        NSLog(@"No connected devices found.");
        return;
    }

    _device = (__bridge AMDeviceRef)devices[0];
    MobileDeviceManager *mdm = [MobileDeviceManager sharedManager];

    if (mdm.AMDeviceConnect(_device) != 0) {
        NSLog(@"AMDeviceConnect failed.");
        _device = NULL;
        return;
    }
    if (mdm.AMDeviceValidatePairing(_device) != 0) {
        NSLog(@"AMDeviceValidatePairing failed.");
        mdm.AMDeviceDisconnect(_device);
        _device = NULL;
        return;
    }
    if (mdm.AMDeviceStartSession(_device) != 0) {
        NSLog(@"AMDeviceStartSession failed.");
        mdm.AMDeviceDisconnect(_device);
        _device = NULL;
        return;
    }

    int ret = mdm.AMDeviceSecureStartService(_device, CFSTR("com.apple.syslog_relay"), NULL, &self->_serviceConnection);
    if (ret == 0 && self->_serviceConnection != NULL) {
        self->_socket_fd = mdm.AMDServiceConnectionGetSocket(self->_serviceConnection);
    } else {
        NSLog(@"Failed to start syslog_relay service.");
        mdm.AMDeviceStopSession(_device);
        mdm.AMDeviceDisconnect(_device);
        _device = NULL;
    }
}

- (void)readSyslogStream {
    char buffer[4096];
    ssize_t bytesRead;

    fcntl(_socket_fd, F_SETFL, O_NONBLOCK);

    while (_isStreaming) {
        bytesRead = recv(_socket_fd, buffer, sizeof(buffer) - 1, 0);
        if (bytesRead > 0) {
            buffer[bytesRead] = '\0';
            NSData *data = [NSData dataWithBytes:buffer length:bytesRead];
            if (self.delegate) {
                [self.delegate didReceiveSyslogData:data];
            }
        } else if (bytesRead == 0) {
            // Connection closed
            [self stopSyslogStream];
            break;
        } else if (errno != EAGAIN && errno != EWOULDBLOCK) {
            // Error
            [self stopSyslogStream];
            break;
        }
        usleep(10000); // 10ms
    }
}

- (void)cleanupDeviceConnection {
    MobileDeviceManager *mdm = [MobileDeviceManager sharedManager];
    if (_serviceConnection) {
        mdm.AMDServiceConnectionInvalidate(_serviceConnection);
        _serviceConnection = NULL;
    }
    if (_socket_fd > 0) {
        close(_socket_fd);
        _socket_fd = 0;
    }
    if (_device) {
        mdm.AMDeviceStopSession(_device);
        mdm.AMDeviceDisconnect(_device);
        _device = NULL;
    }
}

- (void)dealloc {
    [self stopSyslogStream];
}

@end
