; Inno Setup script for fishy. Build with:
;   ISCC.exe /DAppVersion=0.2.0 installer\fishy.iss
; It packs build\fishy.exe into build\fishy-setup-v<version>.exe.
;
; Installs per user (no admin prompt) into %LOCALAPPDATA%\Programs\fishy, so
; the in-game updater can replace fishy.exe and "Start with Windows" always
; points at the same place. The save lives in %APPDATA%\Godot\app_userdata\fishy
; and is never touched by installing, updating or uninstalling.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{6B0C2B7E-3F1A-4E2C-9A57-F15E0F1D5C42}
AppName=fishy
AppVersion={#AppVersion}
AppVerName=fishy {#AppVersion}
AppPublisher=dapss
AppPublisherURL=https://github.com/dapss/fishy
AppSupportURL=https://github.com/dapss/fishy/issues
AppUpdatesURL=https://github.com/dapss/fishy/releases
VersionInfoVersion={#AppVersion}
PrivilegesRequired=lowest
DefaultDirName={localappdata}\Programs\fishy
DisableProgramGroupPage=yes
DisableDirPage=auto
DisableReadyPage=yes
UninstallDisplayIcon={app}\fishy.exe
UninstallDisplayName=fishy
OutputDir=..\build
OutputBaseFilename=fishy-setup-v{#AppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Close a running fishy before replacing it (it saves on close).
CloseApplications=yes
RestartApplications=no

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"

[Files]
Source: "..\build\fishy.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\README.txt"; DestDir: "{app}"; Flags: ignoreversion isreadme skipifsourcedoesntexist

[Icons]
Name: "{autoprograms}\fishy"; Filename: "{app}\fishy.exe"
Name: "{autodesktop}\fishy"; Filename: "{app}\fishy.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\fishy.exe"; Description: "Start fishy now"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Remove "Start with Windows" if it was turned on in the game.
Filename: "{sys}\reg.exe"; Parameters: "delete ""HKCU\Software\Microsoft\Windows\CurrentVersion\Run"" /v fishy /f"; Flags: runhidden; RunOnceId: "RemoveAutostart"

[UninstallDelete]
; Leftovers from the in-game updater.
Type: files; Name: "{app}\fishy.old.exe"
Type: files; Name: "{app}\fishy.new.exe"
