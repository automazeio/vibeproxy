# VibeProxy Windows Port - Architecture & Implementation Plan

## Executive Summary

This document provides a comprehensive architecture plan for porting VibeProxy from macOS to Windows. The good news: **the core backend (`cli-proxy-api`) already supports Windows** with pre-built binaries available, meaning only the UI layer (~2,100 lines of Swift) needs to be rewritten.

**Recommended Approach:** C# with WPF (Windows Presentation Foundation)
**Estimated Timeline:** 1-3 weeks for experienced Windows developer
**Complexity:** Moderate - straightforward component mapping with well-established patterns

---

## Technology Stack Recommendation

### Primary Recommendation: C# + WPF

**Why WPF:**
- Native Windows performance and integration
- Excellent system tray (NotifyIcon) support
- Rich UI framework with XAML (similar to SwiftUI declarative approach)
- Built-in data binding (equivalent to Swift's `@Published` and `@ObservedObject`)
- .NET 8+ is cross-platform (could enable future Linux support)
- Easy deployment with self-contained executables
- Strong ecosystem and tooling (Visual Studio, Rider)

**Alternative Considered:**
- **Electron/Tauri**: Would work but larger bundle size (~150MB vs ~20MB)
- **Rust + native Win32**: More complex, longer development time
- **C# WinForms**: Simpler but less modern, dated UI capabilities

---

## Component-by-Component Mapping

### 1. System Tray Integration

**macOS (Swift):**
```swift
NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
statusItem.button.image = icon
statusItem.menu = NSMenu()
```

**Windows (C#):**
```csharp
NotifyIcon notifyIcon = new NotifyIcon();
notifyIcon.Icon = new Icon("icon.ico");
notifyIcon.ContextMenuStrip = new ContextMenuStrip();
notifyIcon.Visible = true;
```

**Libraries:**
- `System.Windows.Forms.NotifyIcon` (system tray)
- `System.Drawing.Icon` (icon management)

**Complexity:** ⭐ Easy - Direct 1:1 mapping

---

### 2. Settings Window UI

**macOS (Swift/SwiftUI):**
```swift
struct SettingsView: View {
    @ObservedObject var serverManager: ServerManager
    @State private var launchAtLogin = false

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
            // ...
        }
    }
}
```

**Windows (C#/WPF XAML):**
```xml
<Window x:Class="VibeProxy.SettingsWindow">
    <StackPanel>
        <CheckBox Content="Launch at login"
                  IsChecked="{Binding LaunchAtLogin}" />
        <!-- ... -->
    </StackPanel>
</Window>
```

**ViewModel (C#):**
```csharp
public class SettingsViewModel : INotifyPropertyChanged
{
    private bool _launchAtLogin;
    public bool LaunchAtLogin
    {
        get => _launchAtLogin;
        set { _launchAtLogin = value; OnPropertyChanged(); }
    }
}
```

**Libraries:**
- `System.Windows` (WPF core)
- `System.ComponentModel.INotifyPropertyChanged` (data binding)

**Complexity:** ⭐⭐ Medium - MVVM pattern similar to SwiftUI

---

### 3. Process Management

**macOS (Swift):**
```swift
let process = Process()
process.executableURL = URL(fileURLWithPath: bundledPath)
process.arguments = ["--config", configPath]
try process.run()
process.terminate() // SIGTERM
kill(pid, SIGKILL) // Force kill
```

**Windows (C#):**
```csharp
ProcessStartInfo startInfo = new ProcessStartInfo
{
    FileName = bundledPath,
    Arguments = $"--config \"{configPath}\"",
    UseShellExecute = false,
    RedirectStandardOutput = true,
    RedirectStandardError = true
};
Process process = Process.Start(startInfo);

// Graceful shutdown
process.CloseMainWindow();
process.WaitForExit(timeout: 2000);
if (!process.HasExited)
    process.Kill(); // Force terminate
```

**Libraries:**
- `System.Diagnostics.Process`
- `System.Diagnostics.ProcessStartInfo`

**Complexity:** ⭐ Easy - Almost identical API

---

### 4. File System Monitoring

**macOS (Swift):**
```swift
let fileDescriptor = open(authDir.path, O_EVTONLY)
let source = DispatchSource.makeFileSystemObjectSource(
    fileDescriptor: fileDescriptor,
    eventMask: [.write, .delete, .rename],
    queue: DispatchQueue.main
)
source.setEventHandler { /* refresh auth status */ }
```

**Windows (C#):**
```csharp
FileSystemWatcher watcher = new FileSystemWatcher();
watcher.Path = authDir;
watcher.Filter = "*.json";
watcher.NotifyFilter = NotifyFilters.FileName
                      | NotifyFilters.LastWrite;
watcher.Changed += (s, e) => { /* refresh auth status */ };
watcher.Created += (s, e) => { /* refresh auth status */ };
watcher.Deleted += (s, e) => { /* refresh auth status */ };
watcher.EnableRaisingEvents = true;
```

**Libraries:**
- `System.IO.FileSystemWatcher`

**Complexity:** ⭐ Easy - FileSystemWatcher is excellent

---

### 5. HTTP Proxy (ThinkingProxy)

**macOS (Swift):**
```swift
import Network

let listener = try NWListener(using: parameters, on: port)
listener.newConnectionHandler = { connection in
    self.handleConnection(connection)
}
listener.start(queue: .global())
```

**Windows (C#):**
```csharp
using System.Net;
using System.Net.Sockets;

HttpListener listener = new HttpListener();
listener.Prefixes.Add("http://127.0.0.1:8317/");
listener.Start();

// Or for more control:
TcpListener tcpListener = new TcpListener(
    IPAddress.Loopback, 8317);
tcpListener.Start();
while (running)
{
    TcpClient client = await tcpListener.AcceptTcpClientAsync();
    _ = Task.Run(() => HandleConnection(client));
}
```

**Libraries:**
- `System.Net.HttpListener` (high-level, easier)
- `System.Net.Sockets.TcpListener` (low-level, more control)

**Complexity:** ⭐⭐ Medium - HTTPListener simplifies, or direct port of TCP logic

---

### 6. Launch at Login

**macOS (Swift):**
```swift
import ServiceManagement

if enabled {
    try SMAppService.mainApp.register()
} else {
    try SMAppService.mainApp.unregister()
}
```

**Windows (C#):**
```csharp
using Microsoft.Win32;

const string appName = "VibeProxy";
const string startupKey = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Run";

if (enabled)
{
    using var key = Registry.CurrentUser.OpenSubKey(startupKey, true);
    key?.SetValue(appName,
        $"\"{Application.ExecutablePath}\"");
}
else
{
    using var key = Registry.CurrentUser.OpenSubKey(startupKey, true);
    key?.DeleteValue(appName, false);
}
```

**Libraries:**
- `Microsoft.Win32.Registry`

**Complexity:** ⭐ Easy - Simple registry write

---

### 7. Notifications

**macOS (Swift):**
```swift
import UserNotifications

let content = UNMutableNotificationContent()
content.title = title
content.body = body
let request = UNNotificationRequest(
    identifier: UUID().uuidString,
    content: content,
    trigger: nil
)
UNUserNotificationCenter.current().add(request)
```

**Windows (C#):**
```csharp
// Simple balloon tip (Windows 10/11 Action Center)
notifyIcon.BalloonTipTitle = title;
notifyIcon.BalloonTipText = body;
notifyIcon.ShowBalloonTip(3000);

// Or use Windows 10+ Toast Notifications:
using Microsoft.Toolkit.Uwp.Notifications;

new ToastContentBuilder()
    .AddText(title)
    .AddText(body)
    .Show();
```

**Libraries:**
- `System.Windows.Forms.NotifyIcon.ShowBalloonTip` (simple)
- `Microsoft.Toolkit.Uwp.Notifications` NuGet (modern toasts)

**Complexity:** ⭐ Easy (balloon) or ⭐⭐ Medium (modern toasts)

---

### 8. Clipboard Operations

**macOS (Swift):**
```swift
import AppKit

let pasteboard = NSPasteboard.general
pasteboard.clearContents()
pasteboard.setString(serverURL, forType: .string)
```

**Windows (C#):**
```csharp
using System.Windows;

Clipboard.SetText(serverURL);
```

**Libraries:**
- `System.Windows.Clipboard` (WPF)
- `System.Windows.Forms.Clipboard` (WinForms - also works)

**Complexity:** ⭐ Trivial

---

### 9. Authentication Management

**macOS (Swift):**
```swift
class AuthManager: ObservableObject {
    @Published var claudeStatus = AuthStatus(...)

    func checkAuthStatus() {
        // Read JSON files from ~/.cli-proxy-api
        let files = try FileManager.default.contentsOfDirectory(...)
        // Parse JSON and update @Published properties
    }
}
```

**Windows (C#):**
```csharp
public class AuthManager : INotifyPropertyChanged
{
    private AuthStatus _claudeStatus;
    public AuthStatus ClaudeStatus
    {
        get => _claudeStatus;
        set { _claudeStatus = value; OnPropertyChanged(); }
    }

    public void CheckAuthStatus()
    {
        var authDir = Path.Combine(
            Environment.GetFolderPath(
                Environment.SpecialFolder.UserProfile),
            ".cli-proxy-api");
        var files = Directory.GetFiles(authDir, "*.json");
        // Parse JSON and update properties
    }
}
```

**Libraries:**
- `System.IO.Directory` / `System.IO.File`
- `System.Text.Json` or `Newtonsoft.Json` (JSON parsing)
- `System.ComponentModel.INotifyPropertyChanged`

**Complexity:** ⭐ Easy - Same logic, different framework

---

## Project Structure

```
VibeProxyWindows/
├── VibeProxy.sln                    # Visual Studio solution
├── VibeProxy/
│   ├── VibeProxy.csproj             # Project file
│   ├── App.xaml                     # Application entry point
│   ├── App.xaml.cs                  # Application logic
│   ├── MainApplication.cs           # System tray management (AppDelegate equivalent)
│   ├── Models/
│   │   ├── AuthStatus.cs            # Auth status data model
│   │   └── ServerConfig.cs          # Configuration
│   ├── Services/
│   │   ├── ServerManager.cs         # Process management for cli-proxy-api
│   │   ├── ThinkingProxy.cs         # HTTP proxy on port 8317
│   │   ├── AuthManager.cs           # Auth file monitoring
│   │   └── NotificationService.cs   # Windows notifications
│   ├── ViewModels/
│   │   └── SettingsViewModel.cs     # Settings window view model
│   ├── Views/
│   │   └── SettingsWindow.xaml      # Settings window UI
│   │   └── SettingsWindow.xaml.cs   # Settings window code-behind
│   ├── Resources/
│   │   ├── cli-proxy-api.exe        # Bundled backend binary (from CLIProxyAPI)
│   │   ├── config.yaml              # Configuration file
│   │   ├── icon-active.ico          # Tray icon (active)
│   │   ├── icon-inactive.ico        # Tray icon (inactive)
│   │   ├── icon-claude.png          # Service icons
│   │   ├── icon-codex.png
│   │   ├── icon-gemini.png
│   │   └── icon-qwen.png
│   └── app.manifest                 # Windows manifest (admin rights, etc.)
└── Installer/
    └── setup.iss                    # Inno Setup installer script
```

---

## Implementation Phases

### Phase 1: Core Infrastructure (Week 1, Days 1-2)
**Goals:** Set up project, system tray, basic process management

**Tasks:**
1. Create WPF application project (.NET 8)
2. Implement `MainApplication` class
   - System tray icon with context menu
   - "Start Server", "Stop Server", "Settings", "Quit" menu items
   - Icon switching (active/inactive)
3. Implement `ServerManager` service
   - Launch/stop `cli-proxy-api.exe` subprocess
   - Redirect stdout/stderr to log buffer
   - Graceful shutdown (CloseMainWindow → WaitForExit → Kill)
4. Download and bundle Windows `cli-proxy-api.exe` binary
5. Test basic start/stop functionality

**Deliverable:** Tray app that can start/stop the backend server

---

### Phase 2: HTTP Proxy Layer (Week 1, Days 3-4)
**Goals:** Port ThinkingProxy to C#

**Tasks:**
1. Implement `ThinkingProxy` class
   - TCP listener on port 8317
   - HTTP request parsing
   - JSON body manipulation (thinking parameter injection)
   - Request forwarding to port 8318 (cli-proxy-api)
   - Response streaming back to client
2. Implement model name pattern detection (`-thinking-NUMBER`)
3. Test with sample OpenAI-compatible API requests
4. Verify streaming responses work correctly

**Deliverable:** Working proxy that adds thinking parameters

---

### Phase 3: Settings UI (Week 2, Days 1-2)
**Goals:** Build settings window with WPF

**Tasks:**
1. Create `SettingsWindow.xaml` and `SettingsViewModel.cs`
2. Implement UI elements:
   - Server status indicator (green/red circle)
   - Start/Stop button
   - Launch at login toggle
   - "Open Auth Folder" button
   - Service connection buttons (Claude, Codex, Gemini, Qwen)
3. Implement data binding between VM and view
4. Add footer with credits and links
5. Style to match macOS version (modern, clean)

**Deliverable:** Functional settings window

---

### Phase 4: Authentication Flow (Week 2, Days 3-4)
**Goals:** OAuth integration and credential management

**Tasks:**
1. Implement `AuthManager` class
   - File system watcher for `~/.cli-proxy-api/*.json`
   - JSON parsing for auth status
   - Email and expiration date extraction
2. Implement authentication commands
   - Launch `cli-proxy-api.exe --config config.yaml -claude-login` etc.
   - Monitor process output
   - Detect browser opening
   - Qwen email pre-collection dialog
3. Implement disconnect functionality
   - Find and delete corresponding JSON file
   - Restart server after disconnect
4. Update UI to show connected/disconnected/expired states

**Deliverable:** Full OAuth authentication flow working

---

### Phase 5: System Integration (Week 3, Days 1-2)
**Goals:** Polish Windows integration features

**Tasks:**
1. Launch at login (Registry key management)
2. Notifications (balloon tips or modern toasts)
3. Clipboard operations (Copy Server URL)
4. Icon preloading and caching
5. Orphaned process cleanup on startup
6. Graceful shutdown on Windows logoff/shutdown
7. Handle Windows-specific paths (user profile folder)
8. Code signing certificate (optional but recommended)

**Deliverable:** Full Windows integration

---

### Phase 6: Packaging & Distribution (Week 3, Days 3-4)
**Goals:** Build installer and deployment

**Tasks:**
1. Create self-contained publish profile
   - Single-file executable (optional)
   - Include .NET runtime (no install required)
2. Create Inno Setup installer script
   - Install to `Program Files\VibeProxy`
   - Add to Windows Firewall exceptions (if needed)
   - Create Start Menu shortcut
   - Uninstaller
3. Create auto-update mechanism (optional)
   - Check GitHub releases for new versions
   - Download and prompt to install
4. Build release packages
   - `VibeProxy-Setup-x64.exe` (installer)
   - `VibeProxy-Portable-x64.zip` (portable version)
5. Test on clean Windows 10 and Windows 11 VMs

**Deliverable:** Production-ready installer

---

### Phase 7: Testing & QA (Week 3, Days 5+)
**Goals:** Comprehensive testing

**Tasks:**
1. **Functional testing:**
   - Start/stop server multiple times
   - Authentication with all 4 services
   - Disconnect and reconnect
   - Thinking proxy parameter injection
   - File monitoring updates
2. **Integration testing:**
   - Test with Factory Droids
   - Test with other OpenAI-compatible clients
   - Verify streaming responses
3. **System testing:**
   - Launch at login
   - Notifications
   - Clipboard operations
   - Process cleanup on crash
4. **Compatibility testing:**
   - Windows 10 21H2+
   - Windows 11
   - Different user account types (standard vs admin)
5. **Performance testing:**
   - Memory usage
   - CPU usage during idle and active proxy
   - Response latency overhead

**Deliverable:** Tested, stable release

---

## Key Libraries & NuGet Packages

### Core Dependencies
```xml
<PackageReference Include="System.Text.Json" Version="8.*" />
<PackageReference Include="Microsoft.Toolkit.Uwp.Notifications" Version="7.*" />
```

### Optional (for enhanced features)
```xml
<PackageReference Include="Hardcodet.NotifyIcon.Wpf" Version="1.*" />
<!-- Better NotifyIcon implementation for WPF -->

<PackageReference Include="ModernWpfUI" Version="0.9.*" />
<!-- Modern UI controls (optional, for better styling) -->
```

---

## Build Configuration

### Target Framework
```xml
<TargetFramework>net8.0-windows10.0.19041.0</TargetFramework>
<UseWPF>true</UseWPF>
<OutputType>WinExe</OutputType>
<ApplicationIcon>Resources\app-icon.ico</ApplicationIcon>
```

### Publish Profiles

**Self-Contained (No .NET Runtime Required):**
```bash
dotnet publish -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true
```
Result: ~60MB single executable

**Framework-Dependent (Smaller, Requires .NET 8):**
```bash
dotnet publish -c Release -r win-x64 --self-contained false
```
Result: ~5MB executable + requires .NET 8 Runtime

**Recommendation:** Self-contained for better user experience

---

## Resource Bundling

### Bundle CLIProxyAPI Binary

**Download in Build Script:**
```bash
# Download latest Windows binary
$version = "6.3.25"
$url = "https://github.com/router-for-me/CLIProxyAPI/releases/download/v$version/CLIProxyAPI_${version}_windows_amd64.zip"
Invoke-WebRequest -Uri $url -OutFile "cli-proxy-api.zip"
Expand-Archive -Path "cli-proxy-api.zip" -DestinationPath "Resources/"
Move-Item "Resources/cli-proxy-api.exe" "VibeProxy/Resources/"
```

**Include in .csproj:**
```xml
<ItemGroup>
  <None Update="Resources\cli-proxy-api.exe">
    <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
  </None>
  <None Update="Resources\config.yaml">
    <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
  </None>
  <Resource Include="Resources\*.png" />
  <Resource Include="Resources\*.ico" />
</ItemGroup>
```

---

## Cross-Platform Considerations (Future)

If targeting Linux in the future (using .NET's cross-platform capabilities):

**System Tray:**
- Use `Avalonia UI` instead of WPF (cross-platform)
- Or use GTK# for Linux native tray icons

**Process Management:**
- `System.Diagnostics.Process` already works on Linux
- Adjust paths (no `.exe` extension)

**File Monitoring:**
- `FileSystemWatcher` works on Linux

**Launch at Login:**
- Linux: Create `.desktop` file in `~/.config/autostart/`
- macOS: Already implemented with SMAppService

---

## Code Signing & Security

### Windows Code Signing
1. **Get Certificate:**
   - Purchase from DigiCert, Sectigo, etc. (~$100-300/year)
   - Or use self-signed for testing only

2. **Sign Executable:**
```bash
signtool sign /f certificate.pfx /p password /t http://timestamp.digicert.com VibeProxy.exe
```

3. **Benefits:**
   - No SmartScreen warnings
   - User trust
   - Required for Windows Store (optional future step)

### Firewall Considerations
- `cli-proxy-api.exe` listens on `127.0.0.1:8318` (localhost only)
- `ThinkingProxy` listens on `127.0.0.1:8317` (localhost only)
- No external network access required
- Windows Firewall should not block localhost connections

---

## Testing Strategy

### Unit Tests
```csharp
// Test thinking parameter injection
[Fact]
public void ThinkingProxy_Should_Add_Parameter_For_Thinking_Model()
{
    var input = @"{""model"":""claude-sonnet-4-5-20250929-thinking-10000""}";
    var result = ThinkingProxy.ProcessThinkingParameter(input);

    Assert.Contains(@"""thinking"":{""type"":""enabled"",""budget_tokens"":10000}", result);
    Assert.Contains(@"""model"":""claude-sonnet-4-5-20250929""", result);
}
```

### Integration Tests
- Spin up actual `cli-proxy-api.exe` in test environment
- Send HTTP requests through proxy
- Verify transformations and forwarding

### Manual Testing Checklist
- [ ] Start/stop server 10+ times without memory leaks
- [ ] Authenticate with Claude, Codex, Gemini, Qwen
- [ ] Disconnect and verify file deletion
- [ ] Launch at login works after reboot
- [ ] Notifications appear correctly
- [ ] Copy Server URL to clipboard
- [ ] Settings window opens and closes cleanly
- [ ] Thinking proxy correctly transforms model names
- [ ] Graceful shutdown on Windows logoff
- [ ] Process cleanup on app crash (kill orphaned processes)

---

## Installer Configuration (Inno Setup)

**Example `setup.iss`:**
```ini
[Setup]
AppName=VibeProxy
AppVersion=1.0.0
DefaultDirName={autopf}\VibeProxy
DefaultGroupName=VibeProxy
OutputBaseFilename=VibeProxy-Setup-x64
OutputDir=Output
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
UninstallDisplayIcon={app}\VibeProxy.exe

[Files]
Source: "VibeProxy\bin\Release\net8.0-windows\win-x64\publish\*"; DestDir: "{app}"; Flags: recursesubdirs

[Icons]
Name: "{group}\VibeProxy"; Filename: "{app}\VibeProxy.exe"
Name: "{group}\Uninstall VibeProxy"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\VibeProxy.exe"; Description: "Launch VibeProxy"; Flags: nowait postinstall skipifsilent
```

---

## Timeline Estimate

| Phase | Duration | Cumulative |
|-------|----------|------------|
| 1. Core Infrastructure | 2 days | 2 days |
| 2. HTTP Proxy Layer | 2 days | 4 days |
| 3. Settings UI | 2 days | 6 days (1.2 weeks) |
| 4. Authentication Flow | 2 days | 8 days (1.6 weeks) |
| 5. System Integration | 2 days | 10 days (2 weeks) |
| 6. Packaging & Distribution | 2 days | 12 days (2.4 weeks) |
| 7. Testing & QA | 2-3 days | 14-15 days (2.8-3 weeks) |

**Total: 14-15 working days (2.8-3 weeks) for experienced developer**

For less experienced developers or part-time work: **4-6 weeks**

---

## Risk Mitigation

### Risk 1: Windows Firewall Blocks Localhost
**Mitigation:**
- Test on clean Windows 11 VM
- If needed, installer adds firewall exception for `cli-proxy-api.exe`

### Risk 2: CLIProxyAPI Windows Binary Issues
**Mitigation:**
- Test binary independently before integration
- Contact CLIProxyAPI maintainers if issues arise
- Binaries are actively maintained (v6.3.25 released today)

### Risk 3: WPF Learning Curve
**Mitigation:**
- Use simple WinForms as fallback (faster, less modern)
- Leverage ChatGPT/Claude for XAML/MVVM patterns
- Extensive documentation available

### Risk 4: Code Signing Cost
**Mitigation:**
- Launch without signing initially (users get SmartScreen warning)
- Add signing in v1.1 after validating market demand
- Self-signed cert for testing

---

## Success Metrics

### Must Have (MVP)
- ✅ System tray app starts/stops backend server
- ✅ Thinking proxy works on port 8317
- ✅ OAuth authentication for all 4 services
- ✅ Settings window with connection status
- ✅ File monitoring updates auth status in real-time
- ✅ Installer packages app for distribution

### Should Have (v1.0)
- ✅ Launch at login
- ✅ Notifications for server start/stop
- ✅ Code signed executable
- ✅ Auto-update checker (optional)

### Could Have (Future)
- Cross-platform version (Linux support via Avalonia)
- Dark/light theme toggle
- Advanced configuration editor
- Usage statistics dashboard

---

## Next Steps

1. **Prototype Decision:** Build minimal proof-of-concept in 1-2 days
   - System tray with start/stop
   - Launch cli-proxy-api.exe
   - Basic settings window

2. **Validate Approach:** Test on Windows 10 & 11
   - Confirm cli-proxy-api.exe works
   - Verify no system-level blockers

3. **Full Implementation:** Follow phase plan above

4. **Community Feedback:** Share preview build with VibeProxy users

---

## Appendix A: Code Snippets

### MainApplication.cs (System Tray Entry Point)

```csharp
using System;
using System.Windows;
using System.Windows.Forms;
using VibeProxy.Services;
using Application = System.Windows.Application;
using MessageBox = System.Windows.MessageBox;

namespace VibeProxy
{
    public class MainApplication : Application
    {
        private NotifyIcon _notifyIcon;
        private ServerManager _serverManager;
        private ThinkingProxy _thinkingProxy;
        private SettingsWindow _settingsWindow;

        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);

            // Prevent shutdown when windows close
            ShutdownMode = ShutdownMode.OnExplicitShutdown;

            // Initialize services
            _serverManager = new ServerManager();
            _thinkingProxy = new ThinkingProxy();

            // Setup system tray
            SetupSystemTray();

            // Auto-start server
            StartServer();
        }

        private void SetupSystemTray()
        {
            _notifyIcon = new NotifyIcon
            {
                Icon = new System.Drawing.Icon("Resources/icon-inactive.ico"),
                Visible = true,
                Text = "VibeProxy - Stopped"
            };

            var contextMenu = new ContextMenuStrip();
            contextMenu.Items.Add("Server: Stopped").Enabled = false;
            contextMenu.Items.Add(new ToolStripSeparator());
            contextMenu.Items.Add("Open Settings", null, OpenSettings);
            contextMenu.Items.Add(new ToolStripSeparator());
            contextMenu.Items.Add("Start Server", null, ToggleServer);
            contextMenu.Items.Add(new ToolStripSeparator());
            contextMenu.Items.Add("Copy Server URL", null, CopyServerUrl);
            contextMenu.Items.Add(new ToolStripSeparator());
            contextMenu.Items.Add("Quit", null, Quit);

            _notifyIcon.ContextMenuStrip = contextMenu;
        }

        private void StartServer()
        {
            _thinkingProxy.Start();
            _serverManager.Start(success =>
            {
                if (success)
                {
                    UpdateTrayStatus(true);
                    ShowNotification("Server Started", "VibeProxy is now running");
                }
            });
        }

        private void ToggleServer(object sender, EventArgs e)
        {
            if (_serverManager.IsRunning)
            {
                _thinkingProxy.Stop();
                _serverManager.Stop();
                UpdateTrayStatus(false);
            }
            else
            {
                StartServer();
            }
        }

        private void UpdateTrayStatus(bool running)
        {
            _notifyIcon.Icon = new System.Drawing.Icon(
                running ? "Resources/icon-active.ico" : "Resources/icon-inactive.ico");
            _notifyIcon.Text = running ? "VibeProxy - Running" : "VibeProxy - Stopped";

            var menu = _notifyIcon.ContextMenuStrip;
            menu.Items[0].Text = running ? "Server: Running (port 8317)" : "Server: Stopped";
            menu.Items[4].Text = running ? "Stop Server" : "Start Server";
            menu.Items[6].Enabled = running;
        }

        private void OpenSettings(object sender, EventArgs e)
        {
            if (_settingsWindow == null || !_settingsWindow.IsVisible)
            {
                _settingsWindow = new SettingsWindow(_serverManager);
                _settingsWindow.Show();
            }
            else
            {
                _settingsWindow.Activate();
            }
        }

        private void CopyServerUrl(object sender, EventArgs e)
        {
            Clipboard.SetText("http://localhost:8317");
            ShowNotification("Copied", "Server URL copied to clipboard");
        }

        private void ShowNotification(string title, string message)
        {
            _notifyIcon.BalloonTipTitle = title;
            _notifyIcon.BalloonTipText = message;
            _notifyIcon.ShowBalloonTip(3000);
        }

        private void Quit(object sender, EventArgs e)
        {
            _thinkingProxy?.Stop();
            _serverManager?.Stop();
            _notifyIcon.Visible = false;
            _notifyIcon.Dispose();
            Shutdown();
        }
    }
}
```

---

### App.xaml (Application Entry)

```xml
<Application x:Class="VibeProxy.MainApplication"
             xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
    <Application.Resources>
        <!-- Global styles here -->
    </Application.Resources>
</Application>
```

---

## Appendix B: Comparison with macOS Version

| Feature | macOS (Swift) | Windows (C#) | Difficulty |
|---------|---------------|--------------|------------|
| System tray | NSStatusBar | NotifyIcon | Easy ⭐ |
| Settings UI | SwiftUI | WPF/XAML | Medium ⭐⭐ |
| Process mgmt | Foundation.Process | System.Diagnostics.Process | Easy ⭐ |
| File watching | DispatchSource | FileSystemWatcher | Easy ⭐ |
| HTTP proxy | Network.NWListener | HttpListener/TcpListener | Medium ⭐⭐ |
| Launch at login | ServiceManagement | Registry | Easy ⭐ |
| Notifications | UserNotifications | NotifyIcon balloons | Easy ⭐ |
| Clipboard | NSPasteboard | Clipboard.SetText | Trivial ⭐ |
| JSON parsing | JSONSerialization | System.Text.Json | Easy ⭐ |
| OAuth browser | NSWorkspace.open | Process.Start(url) | Easy ⭐ |

**Overall Difficulty:** ⭐⭐ Medium (mostly straightforward mappings)

---

## Conclusion

Porting VibeProxy to Windows is **highly feasible** with moderate effort. The core backend already supports Windows, reducing the scope to UI layer only. Using C# with WPF provides the best balance of development speed, native integration, and maintainability.

**Recommended path forward:**
1. Build 1-2 day prototype to validate approach
2. Follow phased implementation plan (2-3 weeks)
3. Release as beta to gather feedback
4. Iterate based on Windows user needs

The Windows market is substantial, and this port would make VibeProxy accessible to a much larger audience while maintaining feature parity with the macOS version.
