#ifndef SourceDir
  #error SourceDir is required
#endif
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef OutputDir
  #define OutputDir "."
#endif

#define AppName "纯粹直播"
#define AppExeName "pure_live.exe"

[Setup]
AppId={{C76CD88E-EB3F-49AD-9191-65691050035A}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Pure Live
AppPublisherURL=https://github.com/liuchuancong/pure_live
DefaultDirName={autopf}\PureLive
DisableDirPage=no
UsePreviousAppDir=yes
DefaultGroupName={#AppName}
OutputDir={#OutputDir}
OutputBaseFilename=PureLive-{#AppVersion}-windows-x64-setup
SetupIconFile=..\..\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\{#AppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimp"; MessagesFile: "ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
