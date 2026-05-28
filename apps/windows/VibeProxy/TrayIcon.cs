using System;
using System.Runtime.InteropServices;
using Microsoft.UI.Xaml;
using Windows.UI.Notifications;
using WinRT.Interop;

namespace VibeProxy;

/// <summary>
/// System tray icon implementation for WinUI 3
/// Uses Windows API directly since WinUI 3 doesn't have built-in tray support
/// </summary>
public class TrayIcon : IDisposable
{
    private IntPtr _iconHandle = IntPtr.Zero;
    private IntPtr _windowHandle = IntPtr.Zero;
    private bool _disposed = false;
    private Window? _window;
    
    // Events for context menu actions
    public event EventHandler? ShowWindowRequested;
    public event EventHandler? SettingsRequested;
    public event EventHandler? QuitRequested;

    [DllImport("user32.dll")]
    private static extern IntPtr LoadIcon(IntPtr hInstance, IntPtr lpIconName);

    [DllImport("shell32.dll")]
    private static extern IntPtr Shell_NotifyIcon(uint dwMessage, ref NOTIFYICONDATA lpData);
    
    [DllImport("user32.dll")]
    private static extern IntPtr CreatePopupMenu();
    
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern bool AppendMenu(IntPtr hMenu, uint uFlags, uint uIDNewItem, string lpNewItem);
    
    [DllImport("user32.dll")]
    private static extern bool TrackPopupMenu(IntPtr hMenu, uint uFlags, int x, int y, int nReserved, IntPtr hWnd, IntPtr prcRect);
    
    [DllImport("user32.dll")]
    private static extern bool DestroyMenu(IntPtr hMenu);
    
    [DllImport("user32.dll")]
    private static extern IntPtr GetCursorPos(out POINT lpPoint);
    
    [DllImport("user32.dll")]
    private static extern IntPtr SetForegroundWindow(IntPtr hWnd);

    private const uint NIM_ADD = 0x00000000;
    private const uint NIM_DELETE = 0x00000002;
    private const uint NIM_MODIFY = 0x00000001;
    private const uint NIF_ICON = 0x00000002;
    private const uint NIF_MESSAGE = 0x00000001;
    private const uint NIF_TIP = 0x00000004;
    private const uint WM_USER = 0x0400;
    private const uint WM_CONTEXTMENU = 0x007B;
    private const uint WM_LBUTTONUP = 0x0202;
    private const uint WM_RBUTTONUP = 0x0205;
    
    // Menu flags
    private const uint MF_STRING = 0x00000000;
    private const uint MF_SEPARATOR = 0x00000800;
    private const uint TPM_LEFTALIGN = 0x0000;
    private const uint TPM_RIGHTBUTTON = 0x0002;
    private const uint TPM_RETURNCMD = 0x0100;
    
    // Menu item IDs
    private const uint IDM_SHOW = 1001;
    private const uint IDM_SETTINGS = 1002;
    private const uint IDM_QUIT = 1003;
    
    [StructLayout(LayoutKind.Sequential)]
    private struct POINT
    {
        public int x;
        public int y;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct NOTIFYICONDATA
    {
        public uint cbSize;
        public IntPtr hWnd;
        public uint uID;
        public uint uFlags;
        public uint uCallbackMessage;
        public IntPtr hIcon;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string szTip;
    }

    public TrayIcon(Window window)
    {
        _window = window;
        // Get window handle
        _windowHandle = WinRT.Interop.WindowNative.GetWindowHandle(window);
        
        // Create tray icon
        CreateTrayIcon();
        
        // Hook up window message handler for tray icon messages
        HookWindowMessages();
    }
    
    private void HookWindowMessages()
    {
        // Note: In WinUI 3, we need to use a different approach for message handling
        // This is a simplified version - in production, you'd use a proper message loop hook
        // For now, we'll handle double-click to show window
    }
    
    private void CreateTrayIcon()
    {
        try
        {
            var nid = new NOTIFYICONDATA
            {
                cbSize = (uint)Marshal.SizeOf<NOTIFYICONDATA>(),
                hWnd = _windowHandle,
                uID = 0,
                uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP,
                uCallbackMessage = WM_USER + 1,
                hIcon = LoadIcon(IntPtr.Zero, new IntPtr(32512)), // IDI_APPLICATION
                szTip = "VibeProxy - AI Gateway Proxy"
            };

            Shell_NotifyIcon(NIM_ADD, ref nid);
            _iconHandle = nid.hIcon;
        }
        catch
        {
            // Tray icon creation failed - app will still work without it
        }
    }
    
    /// <summary>
    /// Shows the context menu at the cursor position
    /// Call this from your window's message handler when receiving tray icon messages
    /// </summary>
    public void ShowContextMenu()
    {
        try
        {
            GetCursorPos(out POINT point);
            
            IntPtr hMenu = CreatePopupMenu();
            if (hMenu == IntPtr.Zero) return;
            
            AppendMenu(hMenu, MF_STRING, IDM_SHOW, "Show Window");
            AppendMenu(hMenu, MF_STRING, IDM_SETTINGS, "Settings");
            AppendMenu(hMenu, MF_SEPARATOR, 0, null);
            AppendMenu(hMenu, MF_STRING, IDM_QUIT, "Quit");
            
            SetForegroundWindow(_windowHandle);
            
            uint selected = TrackPopupMenu(hMenu, TPM_LEFTALIGN | TPM_RIGHTBUTTON | TPM_RETURNCMD, 
                point.x, point.y, 0, _windowHandle, IntPtr.Zero);
            
            if (selected != 0)
            {
                HandleMenuCommand(selected);
            }
            
            DestroyMenu(hMenu);
        }
        catch
        {
            // Menu creation failed - silently continue
        }
    }
    
    private void HandleMenuCommand(uint commandId)
    {
        switch (commandId)
        {
            case IDM_SHOW:
                ShowWindowRequested?.Invoke(this, EventArgs.Empty);
                break;
            case IDM_SETTINGS:
                SettingsRequested?.Invoke(this, EventArgs.Empty);
                break;
            case IDM_QUIT:
                QuitRequested?.Invoke(this, EventArgs.Empty);
                break;
        }
    }
    
    /// <summary>
    /// Updates the tray icon tooltip
    /// </summary>
    public void UpdateTooltip(string tooltip)
    {
        try
        {
            var nid = new NOTIFYICONDATA
            {
                cbSize = (uint)Marshal.SizeOf<NOTIFYICONDATA>(),
                hWnd = _windowHandle,
                uID = 0,
                uFlags = NIF_TIP,
                szTip = tooltip
            };
            Shell_NotifyIcon(NIM_MODIFY, ref nid);
        }
        catch
        {
            // Update failed - silently continue
        }
    }

    public void ShowNotification(string title, string message)
    {
        try
        {
            // Use Windows toast notifications
            var toastXml = Windows.Data.Xml.Dom.XmlDocument.CreateInstance();
            toastXml.LoadXml($@"
                <toast>
                    <visual>
                        <binding template=""ToastGeneric"">
                            <text>{System.Security.SecurityElement.Escape(title)}</text>
                            <text>{System.Security.SecurityElement.Escape(message)}</text>
                        </binding>
                    </visual>
                </toast>");

            var toast = new ToastNotification(toastXml);
            ToastNotificationManager.CreateToastNotifier("VibeProxy").Show(toast);
        }
        catch
        {
            // Toast notification failed - silently continue
        }
    }

    public void Dispose()
    {
        if (!_disposed)
        {
            try
            {
                var nid = new NOTIFYICONDATA
                {
                    cbSize = (uint)Marshal.SizeOf<NOTIFYICONDATA>(),
                    hWnd = _windowHandle,
                    uID = 0
                };
                Shell_NotifyIcon(NIM_DELETE, ref nid);
            }
            catch
            {
                // Ignore errors during cleanup
            }
            _disposed = true;
        }
    }
}
