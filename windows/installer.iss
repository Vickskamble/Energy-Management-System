; EMS (Energy-Management-System) Windows installer — Inno Setup 6.
; Build: & "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" windows/installer.iss /DAppVersion=v1.1.11
; Paths are relative to this file (windows/), so the Flutter release output is
; reached via "..\build\windows\x64\runner\Release".

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

; ISPP note: {#X} inside a #define string literal does NOT expand — use the
; + concatenation operator (the canonical ISPP pattern) instead.
#define MyAppVersion "EMS " + AppVersion
#define MyAppPublisher "PowerEMS"

[Setup]
AppId={{A57B0C9F-7E62-4A46-9D98-5F4B2E3C9A12}
AppName=EMS Energy Management System
AppVersion={#AppVersion}
AppVerName={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\EMS
DefaultGroupName=EMS
AllowNoIcons=yes
OutputDir=..\build\installer
OutputBaseFilename=EMS Setup {#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\ems.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{autoprograms}\EMS"; Filename: "{app}\ems.exe"
Name: "{autodesktop}\EMS"; Filename: "{app}\ems.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\ems.exe"; Description: "{cm:LaunchProgram,EMS}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\data"