# Windows App Testing Guide

## Overview

This guide provides testing procedures for the VibeProxy Windows application on Windows 11.

## Prerequisites

- Windows 11 (build 22000 or later)
- .NET 8 SDK installed
- Windows 10 SDK (10.0.19041.0 or later)
- Microsoft.WindowsAppSDK 1.5.240627000
- Bifrost CLI executable available (for server control testing)

## Build Instructions

1. Open the solution in Visual Studio 2022 or later
2. Restore NuGet packages
3. Build the solution (Release or Debug)
4. Run the application

## Test Checklist

### ✅ System Tray Functionality

**Test 1: Tray Icon Appearance**
- [ ] Application starts and tray icon appears in system tray
- [ ] Tray icon shows correct tooltip ("VibeProxy - Stopped" or "VibeProxy - Running")
- [ ] Tray icon is visible after minimizing window

**Test 2: Context Menu**
- [ ] Right-click tray icon shows context menu
- [ ] Context menu contains: "Show Window", "Settings", "Quit"
- [ ] "Show Window" restores hidden window
- [ ] "Settings" opens settings window
- [ ] "Quit" closes application completely

**Test 3: Window Hide/Show**
- [ ] Clicking X button hides window to tray
- [ ] Toast notification appears when window is hidden
- [ ] Double-clicking tray icon shows window (if implemented)
- [ ] Window can be restored from context menu

### ✅ Server Control

**Test 4: Server Start**
- [ ] Click "Start" button starts server
- [ ] Status indicator changes to green
- [ ] Status text shows "Running (Healthy)" or "Running (Unhealthy)"
- [ ] Start button becomes disabled
- [ ] Stop and Restart buttons become enabled
- [ ] Toast notification shows "Server started"
- [ ] Tray icon tooltip updates to "VibeProxy - Running"

**Test 5: Server Stop**
- [ ] Click "Stop" button stops server
- [ ] Status indicator changes to red
- [ ] Status text shows "Stopped"
- [ ] Stop and Restart buttons become disabled
- [ ] Start button becomes enabled
- [ ] Toast notification shows "Server stopped"
- [ ] Tray icon tooltip updates to "VibeProxy - Stopped"

**Test 6: Server Restart**
- [ ] Click "Restart" button restarts server
- [ ] Server stops, then starts again
- [ ] Status updates correctly during restart
- [ ] Health monitoring resumes after restart

**Test 7: Health Monitoring**
- [ ] Health status updates every 5 seconds when server is running
- [ ] Backend latency is displayed correctly
- [ ] Status shows "Healthy" or "Unhealthy" appropriately
- [ ] Monitoring stops when server is stopped

**Test 8: Error Handling**
- [ ] Error toast appears if server fails to start
- [ ] Error toast appears if server fails to stop
- [ ] Error messages are clear and actionable
- [ ] Application doesn't crash on errors

### ✅ Settings Window

**Test 9: Settings Load**
- [ ] Settings window opens correctly
- [ ] All fields load with current configuration
- [ ] API key loads from credential manager (if saved)
- [ ] Dropdown selections are correct

**Test 10: Input Validation**
- [ ] Empty Backend URL shows validation error
- [ ] Invalid URL format shows validation error
- [ ] Port < 1 or > 65535 shows validation error
- [ ] Empty SLM URL shows validation error
- [ ] Tunnel ID required when tunnel is enabled
- [ ] Error borders appear on invalid fields
- [ ] Save button is disabled when validation fails

**Test 11: Credential Manager Integration**
- [ ] API key is saved to Windows Credential Manager
- [ ] API key is retrieved from Credential Manager on load
- [ ] API key persists across application restarts
- [ ] API key is encrypted in Windows Credential Manager

**Test 12: Settings Save**
- [ ] Valid settings save successfully
- [ ] Success dialog appears after save
- [ ] Settings window closes after successful save
- [ ] Settings persist after application restart
- [ ] Error dialog appears if save fails

**Test 13: Settings Cancel**
- [ ] Cancel button closes window without saving
- [ ] Changes are discarded on cancel
- [ ] No settings are modified on cancel

### ✅ Credential Manager

**Test 14: API Key Storage**
- [ ] API keys are stored securely in Windows Credential Manager
- [ ] API keys can be retrieved after storage
- [ ] API keys can be deleted
- [ ] Multiple service keys can be stored independently

**Test 15: Credential Manager Access**
- [ ] Credentials are accessible via Windows Credential Manager UI
- [ ] Credentials are listed under "VibeProxy:*" target names
- [ ] Credentials can be viewed in Windows Credential Manager

### ✅ Application Lifecycle

**Test 16: Application Startup**
- [ ] Application starts without errors
- [ ] All components initialize correctly
- [ ] Rust core initializes successfully
- [ ] Server manager initializes correctly

**Test 17: Application Shutdown**
- [ ] Server stops gracefully on application exit
- [ ] All resources are disposed correctly
- [ ] Tray icon is removed on exit
- [ ] No memory leaks on shutdown

**Test 18: Error Recovery**
- [ ] Application handles missing bifrost executable gracefully
- [ ] Application handles network errors gracefully
- [ ] Application handles invalid configuration gracefully
- [ ] Application recovers from errors without crashing

## Known Issues

### System Tray Context Menu
- Context menu requires proper message loop hooking in WinUI 3
- Currently uses Windows API directly which may have limitations
- Consider using H.NotifyIcon.WinUI package for better integration

### Server Process Management
- Server executable path detection may need adjustment for different installations
- Process monitoring may need enhancement for better error detection

## Performance Testing

**Test 19: Performance**
- [ ] Application starts in < 3 seconds
- [ ] Settings window opens in < 1 second
- [ ] Server start/stop completes in < 5 seconds
- [ ] Health monitoring doesn't impact UI responsiveness
- [ ] Memory usage stays reasonable (< 100MB idle)

## Accessibility Testing

**Test 20: Accessibility**
- [ ] All controls are keyboard accessible
- [ ] Screen reader can read all text
- [ ] High contrast mode works correctly
- [ ] Focus indicators are visible

## Security Testing

**Test 21: Security**
- [ ] API keys are not logged or exposed
- [ ] Credential Manager encryption works correctly
- [ ] No sensitive data in memory dumps
- [ ] Network communication is secure (if applicable)

## Reporting Issues

When reporting issues, please include:
1. Windows version and build number
2. .NET version
3. Steps to reproduce
4. Expected vs actual behavior
5. Error messages or logs
6. Screenshots if applicable

## Next Steps

After completing all tests:
1. Document any issues found
2. Create GitHub issues for bugs
3. Update this guide with new test cases
4. Consider automated testing for regression prevention
