using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace LiveWP;

public sealed class WallpaperManager : IDisposable
{
    private readonly Dictionary<int, Process> _processes = new();
    private readonly Dictionary<int, WallpaperHost> _hosts = new();

    public void Play(string videoPath, Screen targetScreen, Form owner)
    {
        Stop();

        var host = new WallpaperHost(targetScreen)
        {
            Owner = owner
        };

        host.Show();
        host.Update();

        var mpvPath = FindMpvExecutable();
        if (string.IsNullOrEmpty(mpvPath))
        {
            host.Close();
            MessageBox.Show(owner, "mpv.exe was not found. Download the Windows build from https://mpv.io/installation/ and place mpv.exe in the app folder.", "LiveWP", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }

        var args = $"--wid={host.Handle} --loop --really-quiet --no-config --force-window=no --title=LiveWP --video-output=direct3d --autofit=100% --no-keepaspect --pause=no \"{videoPath}\"";

        var psi = new ProcessStartInfo
        {
            FileName = mpvPath,
            Arguments = args,
            UseShellExecute = false,
            CreateNoWindow = true,
            WorkingDirectory = Path.GetDirectoryName(mpvPath) ?? Environment.CurrentDirectory
        };

        var process = Process.Start(psi);
        if (process is null)
        {
            host.Close();
            MessageBox.Show(owner, "Unable to launch mpv.", "LiveWP", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }

        _hosts[host.GetHashCode()] = host;
        _processes[host.GetHashCode()] = process;
    }

    public void Stop()
    {
        foreach (var process in _processes.Values)
        {
            try
            {
                if (!process.HasExited)
                {
                    process.Kill(entireProcessTree: true);
                }
            }
            catch
            {
                // Ignore process shutdown errors.
            }
        }

        foreach (var host in _hosts.Values)
        {
            try
            {
                host.Close();
            }
            catch
            {
                // Ignore host shutdown errors.
            }
        }

        _processes.Clear();
        _hosts.Clear();
    }

    public static string? FindMpvExecutable()
    {
        var candidates = new List<string>
        {
            Path.Combine(AppContext.BaseDirectory, "mpv.exe"),
            Path.Combine(AppContext.BaseDirectory, "bin", "mpv.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "mpv", "mpv.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "mpv", "mpv.exe")
        };

        foreach (var candidate in candidates)
        {
            if (File.Exists(candidate))
            {
                return candidate;
            }
        }

        return null;
    }

    public void Dispose()
    {
        Stop();
    }
}

public sealed class WallpaperHost : Form
{
    public WallpaperHost(Screen targetScreen)
    {
        this.FormBorderStyle = FormBorderStyle.None;
        this.ShowInTaskbar = false;
        this.StartPosition = FormStartPosition.Manual;
        this.BackColor = Color.Black;
        this.TransparencyKey = Color.Black;
        this.TopMost = true;
        this.ControlBox = false;
        this.Text = "LiveWP Background";
        this.Bounds = targetScreen.Bounds;
        this.Location = targetScreen.Bounds.Location;
        this.DoubleBuffered = true;
        this.Width = targetScreen.Bounds.Width;
        this.Height = targetScreen.Bounds.Height;
        this.ShowIcon = false;
        this.MinimumSize = Size.Empty;
        this.MaximumSize = Size.Empty;
    }

    protected override void OnShown(EventArgs e)
    {
        base.OnShown(e);

        try
        {
            var desktop = NativeMethods.GetDesktopWindow();
            if (desktop != IntPtr.Zero)
            {
                NativeMethods.SetParent(this.Handle, desktop);
            }

            var exStyle = NativeMethods.GetWindowLong(this.Handle, NativeMethods.GWL_EXSTYLE);
            NativeMethods.SetWindowLong(this.Handle, NativeMethods.GWL_EXSTYLE, exStyle | NativeMethods.WS_EX_NOACTIVATE | NativeMethods.WS_EX_LAYERED | NativeMethods.WS_EX_TOOLWINDOW);
            NativeMethods.SetWindowPos(this.Handle, NativeMethods.HWND_TOPMOST, this.Left, this.Top, this.Width, this.Height, NativeMethods.SWP_NOACTIVATE | NativeMethods.SWP_NOOWNERZORDER | NativeMethods.SWP_SHOWWINDOW);
        }
        catch
        {
            // Ignore native desktop parenting failures and continue. The window still renders.
        }
    }
}

public static class DisplayInfo
{
    public sealed record DisplayEntry(string Label, Screen Screen);

    public static Screen GetDefaultTarget()
    {
        return Screen.PrimaryScreen ?? Screen.AllScreens.FirstOrDefault() ?? throw new InvalidOperationException("No displays were detected.");
    }

    public static List<DisplayEntry> GetDisplays()
    {
        var results = new List<DisplayEntry>();
        for (var i = 0; i < Screen.AllScreens.Length; i++)
        {
            var screen = Screen.AllScreens[i];
            var label = i == 0 ? $"Monitor {i + 1} (Primary) - {screen.DeviceName}" : $"Monitor {i + 1} - {screen.DeviceName}";
            results.Add(new DisplayEntry(label, screen));
        }

        return results;
    }
}

internal static class NativeMethods
{
    public const int GWL_EXSTYLE = -20;
    public const int GWL_STYLE = -16;
    public const int WS_EX_NOACTIVATE = 0x08000000;
    public const int WS_EX_LAYERED = 0x00080000;
    public const int WS_EX_TOOLWINDOW = 0x00000080;
    public const int SWP_NOACTIVATE = 0x0010;
    public const int SWP_NOOWNERZORDER = 0x0200;
    public const int SWP_SHOWWINDOW = 0x0040;
    public static readonly IntPtr HWND_TOPMOST = new(-1);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr GetDesktopWindow();

    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
}
