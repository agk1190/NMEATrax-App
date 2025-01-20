# NMEATrax App Change Log
All notable changes to this project will be documented in this file.
 
The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project tries to adhere to [Semantic Versioning](http://semver.org/).

## [Unreleased] - yyyy-mm-dd
 
### To-Do
- move unit selection to pop-up
- add psi unit
- remove SettingsTile


## [6.0.0] - 2024-12-06

### Added
- Basics of event based mode
- Added NmeaDevice class

### Changed
- Updated both dashboard pages
- Updated options page
- Updated WiFi dialog


## [5.0.0] - 2024-09-22

### Added
- File Manager page
- Show route when opening csv file
- Drawer as class
- Reconnection to websocket
- Import GPX from CSV

### Changed
- Units from NMEATrax are metric. Conversion done locally.
- Revamped analyze page. Click on violation to see moment in data.

### Removed
- File linking


## [4.1.0] - 2024-07-19

### Added
- Ability to change WiFi settings and reboot

### Changed
- Updated Gradle


## [4.0.0] - 2024-04-08

### Changed
- Updated packages
- Updated live data widgets
- Fixed colors


## [3.0.0] - 2023-10-21

### Changed
- Now using websockets for NMEA & email data


## [2.1.0] - 2023-07-31

### Added
- Multiple GPX on map
- Chosen filename now shows on Replay data tab
- GPX will now load with csv only on Windows
- Type line num to go to
- Added more NMEATrax settings

### Changed
- Replay analysis limits now under dropdown
- Added warning if recording if off
- Removed 0 oil pressure @ line 0 warning
- Changed replay data page scroll behaviour
- Removed unused "homepage"
- Analyze button now hides once pressed
- Send email button now hides once pressed


## [2.0.0] - 2023-07-18
- Version 2 Release
