; ============================================================================
; PowerEMS — production Windows installer (Inno Setup 6)
; Publisher: Brilliants Automation and Software Solutions
; Website:   https://www.brilliants.in
;
; Build via build_windows.bat (recommended) or manually:
;   "C:\Users\PC3\AppData\Local\Programs\Inno Setup 6\ISCC.exe" ^
;     windows\PowerEMS.iss /DAppVersion=1.1.19
;
; All paths below are relative to this file (windows/). The complete Flutter
; release directory (build\windows\x64\runner\Release) is packaged recursively,
; including the VC++ runtime DLLs staged app-local by build_windows.bat, so no
; Visual C++ Redistributable installation is required on client PCs.
;
; ARCHITECTURE: Flutter currently builds Windows x64 only (no x86/arm64 native
; Windows target exists in Flutter 3.44). The x64 build therefore covers:
;   - x64 Windows        -> installed natively
;   - ARM64 Windows      -> installed via "x64compatible" mode, runs under the
;                           built-in x64 emulation (Prism) - still 64-bit install
; Real 32-bit x86 Windows is not supported (Flutter limitation; Windows 11 has
; no 32-bit edition at all).
; ============================================================================

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

#define MyAppName "PowerEMS"
#define MyAppVersion AppVersion
#define MyAppExeName "ems.exe"
#define MyAppPublisher "Brilliants Automation and Software Solutions"
#define MyAppURL "https://www.brilliants.in"
#define MyAppId "{{B08B157D-4EC4-4D04-BD6F-CD2985300E7E}"

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=..\dist
OutputBaseFilename=PowerEMS_Setup_v{#MyAppVersion}
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
CloseApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Complete Flutter release output — preserves the exact directory structure
; (exe, all plugin DLLs, VC++ runtime DLLs, data\app.so, data\icudtl.dat,
; data\flutter_assets\... including nested/hidden files).
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

; NOTE: no [UninstallDelete] is used — uninstall removes only installed files.
; User data (local sembast database, settings) lives outside {app} in the
; user profile and is intentionally left untouched.
