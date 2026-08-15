; EMS (Energy-Management-System) Windows installer — Inno Setup 6.
; Build: & "C:\Users\PC3\AppData\Local\Programs\Inno Setup 6\ISCC.exe" windows/installer.iss /DAppVersion=v1.1.11
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
Source: "redist\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: ignoreversion deleteafterinstall

[Icons]
Name: "{autoprograms}\EMS"; Filename: "{app}\ems.exe"
Name: "{autodesktop}\EMS"; Filename: "{app}\ems.exe"; Tasks: desktopicon

[Run]
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing Microsoft Visual C++ Runtime..."; Check: not VCppRedistInstalled; Flags: skipifdoesntexist
Filename: "{app}\ems.exe"; Description: "{cm:LaunchProgram,EMS}"; Flags: nowait postinstall skipifsilent

[Code]
function VCppRedistInstalled(): Boolean;
var
  Value: Cardinal;
begin
  Result := RegQueryDWordValue(HKLM, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Installed', Value) and (Value = 1);
end;

[UninstallDelete]
Type: filesandordirs; Name: "{app}\data"