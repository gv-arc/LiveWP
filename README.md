# LiveWP

Lightweight Windows live wallpaper app that plays your own MP4 videos on the laptop screen only.

Features
- Plays local MP4/WebM/MKV videos as a desktop wallpaper
- Targets only the primary laptop display by default
- Optional monitor selection for multi-monitor setups
- Tray menu with easy controls
- Lightweight mpv-based playback with hardware decoding when available
- Imports videos from a local folder or a Lively wallpaper library folder
- Simple installer script for a Windows .exe setup package

Quick start
1. Install .NET 8 SDK for Windows.
2. Download mpv for Windows from https://mpv.io/installation/
3. Copy `mpv.exe` into `src/LiveWP/bin/Release/net8.0-windows/`
4. Build the app:
   `dotnet build src/LiveWP/LiveWP.csproj -c Release`
5. Or use the included installer script in `build/LiveWP.iss` with Inno Setup.

Project structure
- `src/LiveWP/` — main Windows app source
- `build/LiveWP.iss` — installer script for a Windows setup package
- `build/build.ps1` — optional build helper

Requirements
- Windows 10 or 11
- .NET 8 SDK
- mpv for Windows

License
MIT
