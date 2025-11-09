# iOS Syslog Viewer

A powerful macOS application for viewing iOS device system logs with full Apple System Log (ASL) format implementation. Features both a rich GUI and command-line interface for monitoring device syslog output in real-time.

## Features

### Core Functionality
- **Full ASL Format Support**: Complete implementation of Apple System Log message parsing and formatting
- **Real-time Streaming**: Live syslog relay from connected iOS devices via USB
- **Dual Interface**: Rich GUI application and command-line mode
- **Multiple Format Styles**: idevicesyslog-compatible, compact, verbose, and detailed formats
- **Binary Data Handling**: Properly filters and cleans binary/non-printable data from syslog stream

### GUI Features
- **Color-coded Log Levels**: Visual differentiation of Emergency, Alert, Critical, Error, Warning, Notice, Info, and Debug messages
- **Filtering**:
  - Filter by minimum log level
  - Search/filter by text content
- **Controls**:
  - Pause/Resume logging
  - Clear log display
  - Save to file
- **Dark Theme**: Easy-on-the-eyes dark interface with syntax-highlighted logs
- **Auto-scroll**: Automatically follows new log entries
- **Status Bar**: Real-time message count and device status

### CLI Features
- **Headless Operation**: Run without GUI using `--console` flag
- **Format Options**: Choose output format with `--format` flag
- **Color Support**: Enable ANSI color codes with `--color` flag
- **File Output**: Save logs directly to file with `--save-to-file` and `--output-file`
- **Standard Output**: Properly formatted output suitable for piping and processing

## Requirements

- macOS 10.13 or later
- Xcode command line tools or full Xcode installation (for MobileDevice.framework)
- iOS device connected via USB and paired with the Mac

## Building

```bash
# Clone the repository
git clone https://github.com/yourusername/syslogger.git
cd syslogger

# Open in Xcode
open syslogger.xcodeproj

# Build using Xcode GUI or command line
xcodebuild -project syslogger.xcodeproj -scheme syslogger -configuration Release
```

## Usage

### GUI Mode

Simply launch the application:

```bash
./syslogger
```

Or double-click the app bundle.

**GUI Controls**:
- **Clear**: Clear the log display
- **Pause/Resume**: Pause log streaming (messages are buffered)
- **Save**: Export current logs to a file
- **Min Level**: Filter by minimum log level (Emergency → Debug)
- **Search**: Filter messages by text content

### Command-Line Mode

Run in headless console mode:

```bash
./syslogger --console
```

**CLI Options**:

```bash
# Basic console mode
./syslogger --console

# With specific format
./syslogger --console --format idevicesyslog

# With ANSI colors
./syslogger --console --color

# Save to file
./syslogger --console --save-to-file --output-file ~/Desktop/device.log

# Combine options
./syslogger --console --format verbose --color --save-to-file
```

**Available Formats**:
- `idevicesyslog` (default): libimobiledevice compatible format
- `compact`: Condensed single-line format
- `verbose`: Detailed multi-line format with all fields
- `default`: Standard ASL format

## Architecture

### Core Components

#### MobileDeviceManager (`MobileDeviceManager.h/.m`)
Singleton class that dynamically loads the private `MobileDevice.framework` at runtime and provides access to:
- Device connection and session management
- Service connection APIs (modern and legacy)
- Device property queries
- Device notifications

#### DeviceManager (`DeviceManager.h/.m`)
Manages iOS device connections and syslog streaming:
- Subscribes to device connect/disconnect notifications
- Establishes syslog_relay service connection
- Streams raw syslog data using GCD dispatch sources
- Handles connection lifecycle and cleanup

#### ASLMessage (`ASLMessage.h/.m`)
Complete Apple System Log format implementation:
- **ASLMessage**: Represents a complete log entry with all standard and extended fields
- **ASLParser**: Parses raw syslog data, text lines, binary data, and os_log format
- **ASLFormatter**: Formats messages with various styles and options
- Supports all ASL log levels (Emergency through Debug)
- Handles facility codes and extended attributes

#### Syslogger (`syslog.h/.m`)
Processes raw syslog data:
- Line buffering for proper parsing
- Character encoding detection (UTF-8, ISO Latin 1, printable extraction)
- Binary garbage filtering
- Delegates formatted messages to output handler
- Optional file output

#### AppDelegate (`AppDelegate.h/.m`)
Main application controller:
- GUI creation and management
- User interaction handling
- Message filtering and display
- Both GUI and CLI mode support

### Data Flow

```
iOS Device
    ↓
syslog_relay service (via MobileDevice.framework)
    ↓
DeviceManager (raw data streaming)
    ↓
Syslogger (parsing and formatting)
    ↓
AppDelegate (display and user interaction)
    ↓
GUI TextVie / Console Output / File
```

## ASL Format Details

The application implements the full Apple System Log (ASL) format:

### Log Levels
- **0 - Emergency**: System is unusable
- **1 - Alert**: Action must be taken immediately
- **2 - Critical**: Critical conditions
- **3 - Error**: Error conditions
- **4 - Warning**: Warning conditions
- **5 - Notice**: Normal but significant
- **6 - Info**: Informational messages
- **7 - Debug**: Debug-level messages

### Message Fields
- **Time**: Message timestamp
- **Host**: Device/host name
- **Sender**: Process name
- **PID**: Process ID
- **UID/GID**: User/Group ID
- **Level**: Log severity level
- **Facility**: Syslog facility code
- **Message**: Log message text
- **Extended**: Subsystem, category, thread ID, activity, etc.

### Parsing Capabilities
- Standard syslog format: `Mon DD HH:MM:SS host process[pid]: message`
- iOS format: `process[pid] <Level>: message`
- os_log format: `timestamp host process[pid:tid] level: subsystem: message`
- Binary ASL data with printable extraction
- Automatic format detection

## Troubleshooting

### "MobileDevice.framework not loaded"
The application requires MobileDevice.framework which comes with Xcode or iTunes. Install Xcode command line tools:
```bash
xcode-select --install
```

### "Device not paired"
Ensure your iOS device is paired with your Mac:
1. Connect device via USB
2. Trust the computer when prompted on the device
3. Verify device appears in Finder sidebar

### "No device connected"
- Check USB connection
- Ensure device is unlocked
- Try disconnecting and reconnecting
- Restart the application

### Binary/Unreadable Output
The application automatically filters binary garbage from syslog output. If you're still seeing unreadable content:
- Try a different format: `--format verbose`
- Check that the device is running a compatible iOS version
- Some system processes may emit binary data intentionally

## Comparison with idevicesyslog

This application provides similar functionality to libimobiledevice's `idevicesyslog` tool but with additional features:

**Advantages over idevicesyslog**:
- Rich GUI with filtering and search
- Better binary data handling
- Multiple output formats
- Pause/resume capability
- Real-time message count
- Color-coded log levels
- Native macOS application

**Compatible with idevicesyslog**:
- Default format matches idevicesyslog output
- Can be used as drop-in replacement in scripts
- Same underlying syslog_relay service

## License

MIT License - see LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

## Credits

- MobileDevice.framework function signatures based on libimobiledevice research
- ASL format specification from Apple's system logging documentation
