# Notification Center Fix

## Problem
The app was crashing on launch when running via `swift run` with:
```
*** Terminating app due to uncaught exception 'NSInternalInconsistencyException', 
reason: 'bundleProxyForCurrentProcess is nil'
```

## Root Cause
`UNUserNotificationCenter.current()` requires the app to be in a proper `.app` bundle. When running via `swift run`, the executable is in `.build/` directory and not in a bundle, causing the crash.

## Solution
Changed notification center initialization from a stored property to a lazy function that:
1. Checks if we're running from `.build/` (swift run) vs `.app/` (proper bundle)
2. Only initializes `UNUserNotificationCenter.current()` when in a proper bundle
3. Falls back to logging when notifications aren't available

## Changes Made
- `notificationCenter` changed from stored property to `getNotificationCenter()` function
- Added check for `.build/` in executable path to detect `swift run`
- All notification calls now safely handle `nil` notification center
- App continues to work without notifications when running via `swift run`

## Testing
```bash
# Should run without crashing
swift run

# When built as proper app bundle, notifications will work
swift build -c release
# Then run from .app bundle
```
