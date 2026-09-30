using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Windows.Forms;

namespace LiveWP;

public sealed class MainForm : Form
{
    private readonly NotifyIcon _trayIcon;
    private readonly ContextMenuStrip _trayMenu;
    private readonly WallpaperManager _wallpaperManager = new();
    private readonly HashSet<string> _supportedExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".mp4", ".mkv", ".webm", ".avi", ".mov"
    };

    private Screen _selectedScreen = DisplayInfo.GetDefaultTarget();
    private string? _currentVideoPath;

    public MainForm()
    {
        this.Visible = false;
        this.ShowInTaskbar = false;
        this.WindowState = FormWindowState.Minimized;
        this.FormBorderStyle = FormBorderStyle.None;
        this.Size = new Size(1, 1);
        this.Location = new Point(-32000, -32000);

        _trayMenu = new ContextMenuStrip();
        _trayMenu.Items.Add("Open local video", null, OnOpenVideo);
        _trayMenu.Items.Add("Import from folder", null, OnImportFolder);
        _trayMenu.Items.Add("Choose monitor", null, OnChooseMonitor);
        _trayMenu.Items.Add("Stop wallpaper", null, OnStopWallpaper);
        _trayMenu.Items.Add(new ToolStripSeparator());
        _trayMenu.Items.Add("Exit", null, OnExit);

        _trayIcon = new NotifyIcon
        {
            Text = "LiveWP",
            Icon = SystemIcons.Application,
            Visible = true,
            ContextMenuStrip = _trayMenu
        };

        _trayIcon.DoubleClick += (_, _) => OnOpenVideo(null, EventArgs.Empty);

        this.FormClosing += (_, e) =>
        {
            _trayIcon.Visible = false;
            _trayIcon.Dispose();
            _wallpaperManager.Dispose();
        };
    }

    private void OnOpenVideo(object? sender, EventArgs e)
    {
        using var dialog = new OpenFileDialog
        {
            Filter = "Video files (*.mp4;*.mkv;*.webm;*.avi;*.mov)|*.mp4;*.mkv;*.webm;*.avi;*.mov|All files (*.*)|*.*",
            Title = "Choose a video wallpaper"
        };

        if (dialog.ShowDialog(this) != DialogResult.OK)
        {
            return;
        }

        SetWallpaper(dialog.FileName);
    }

    private void OnImportFolder(object? sender, EventArgs e)
    {
        using var dialog = new FolderBrowserDialog
        {
            Description = "Pick a folder containing MP4 videos or a Lively wallpaper folder"
        };

        if (dialog.ShowDialog(this) != DialogResult.OK)
        {
            return;
        }

        var candidates = FindVideoFiles(dialog.SelectedPath);
        if (candidates.Count == 0)
        {
            MessageBox.Show(this, "No supported video files were found in that folder.", "LiveWP", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        var selected = candidates[0];
        SetWallpaper(selected);
    }

    private void OnChooseMonitor(object? sender, EventArgs e)
    {
        var monitors = DisplayInfo.GetDisplays();
        if (monitors.Count == 0)
        {
            return;
        }

        var choice = new Form
        {
            Text = "Choose monitor",
            StartPosition = FormStartPosition.CenterParent,
            FormBorderStyle = FormBorderStyle.FixedDialog,
            MinimizeBox = false,
            MaximizeBox = false,
            ShowInTaskbar = false,
            AutoScaleMode = AutoScaleMode.Dpi,
            Width = 420,
            Height = 180
        };

        var list = new ListBox
        {
            Dock = DockStyle.Fill,
            Font = new Font(FontFamily.GenericSansSerif, 10f)
        };

        foreach (var monitor in monitors)
        {
            list.Items.Add(monitor.Label);
        }

        list.SelectedIndex = monitors.FindIndex(x => x.Screen.DeviceName == _selectedScreen.DeviceName);
        if (list.SelectedIndex < 0)
        {
            list.SelectedIndex = 0;
        }

        var buttonPanel = new FlowLayoutPanel
        {
            Dock = DockStyle.Bottom,
            Height = 40,
            FlowDirection = FlowDirection.RightToLeft
        };

        var ok = new Button { Text = "OK", DialogResult = DialogResult.OK, AutoSize = true };
        var cancel = new Button { Text = "Cancel", DialogResult = DialogResult.Cancel, AutoSize = true };
        buttonPanel.Controls.Add(ok);
        buttonPanel.Controls.Add(cancel);

        choice.Controls.Add(list);
        choice.Controls.Add(buttonPanel);
        choice.AcceptButton = ok;
        choice.CancelButton = cancel;

        if (choice.ShowDialog(this) == DialogResult.OK)
        {
            _selectedScreen = monitors[list.SelectedIndex].Screen;
            if (!string.IsNullOrEmpty(_currentVideoPath))
            {
                SetWallpaper(_currentVideoPath);
            }
        }
    }

    private void OnStopWallpaper(object? sender, EventArgs e)
    {
        _wallpaperManager.Stop();
        _currentVideoPath = null;
    }

    private void OnExit(object? sender, EventArgs e)
    {
        _wallpaperManager.Stop();
        Application.Exit();
    }

    private void SetWallpaper(string videoPath)
    {
        if (!File.Exists(videoPath))
        {
            MessageBox.Show(this, "The chosen video file no longer exists.", "LiveWP", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        var extension = Path.GetExtension(videoPath);
        if (!_supportedExtensions.Contains(extension))
        {
            MessageBox.Show(this, "Unsupported video format. Use MP4, MKV, WebM, AVI, or MOV.", "LiveWP", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        _currentVideoPath = videoPath;
        _wallpaperManager.Play(videoPath, _selectedScreen, this);
    }

    private List<string> FindVideoFiles(string root)
    {
        var items = new List<string>();

        foreach (var ext in _supportedExtensions)
        {
            items.AddRange(Directory.EnumerateFiles(root, $"*{ext}", SearchOption.AllDirectories));
        }

        if (items.Count == 0)
        {
            foreach (var metadataPath in Directory.EnumerateFiles(root, "metadata.json", SearchOption.AllDirectories))
            {
                try
                {
                    var content = File.ReadAllText(metadataPath);
                    var fileMatch = System.Text.RegularExpressions.Regex.Match(content, "\"(file|path|video)\"\\s*:\\s*\"([^\"]+)\"");
                    if (fileMatch.Success)
                    {
                        var candidate = Path.Combine(Path.GetDirectoryName(metadataPath) ?? root, fileMatch.Groups[2].Value);
                        if (File.Exists(candidate) && _supportedExtensions.Contains(Path.GetExtension(candidate)))
                        {
                            items.Add(candidate);
                        }
                    }
                }
                catch
                {
                    // Ignore invalid metadata files.
                }
            }
        }

        return items.Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(x => x).ToList();
    }
}
