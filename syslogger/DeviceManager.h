//
//  DeviceManager.h
//  syslogger
//
//  Created by failbr34k on 2025-11-09.
//

#import <Foundation/Foundation.h>
#import "MobileDevice.h"

@protocol DeviceManagerDelegate <NSObject>
- (void)didReceiveSyslogData:(NSData *)data;
@end

@interface DeviceManager : NSObject

@property (nonatomic, weak) id<DeviceManagerDelegate> delegate;

- (void)startSyslogStream;
- (void)stopSyslogStream;

@end
