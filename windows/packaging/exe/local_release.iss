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
CloseApplications=force
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimp"; MessagesFile: "ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Dirs]
; Runtime state is intentionally retained during an uninstall/reinstall so a
; normal version upgrade never removes follows, settings or IPTV providers.
Name: "{app}\AppData"; Flags: uninsneveruninstall

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[Code]
var
  PreviousInstallDirectory: String;

function ReadInstallLocation(RootKey: Integer; SubKey: String): String;
begin
  Result := '';
  RegQueryStringValue(RootKey, SubKey, 'InstallLocation', Result);
end;

function FindPreviousInstallDirectory(): String;
begin
  { Current 2.1.x installer identity. }
  Result := ReadInstallLocation(HKCU,
    'Software\Microsoft\Windows\CurrentVersion\Uninstall\{C76CD88E-EB3F-49AD-9191-65691050035A}_is1');
  if Result = '' then
    Result := ReadInstallLocation(HKLM64,
      'Software\Microsoft\Windows\CurrentVersion\Uninstall\{C76CD88E-EB3F-49AD-9191-65691050035A}_is1');

  { Legacy 2.0.x fastforge identity, with both historical key spellings. }
  if Result = '' then
    Result := ReadInstallLocation(HKCU,
      'Software\Microsoft\Windows\CurrentVersion\Uninstall\7B973E89-76D9-430B-81E2-9DB393C8C042_is1');
  if Result = '' then
    Result := ReadInstallLocation(HKLM32,
      'Software\Microsoft\Windows\CurrentVersion\Uninstall\7B973E89-76D9-430B-81E2-9DB393C8C042_is1');
  if Result = '' then
    Result := ReadInstallLocation(HKLM64,
      'Software\Microsoft\Windows\CurrentVersion\Uninstall\7B973E89-76D9-430B-81E2-9DB393C8C042_is1');
end;

procedure InitializeWizard();
begin
  PreviousInstallDirectory := FindPreviousInstallDirectory();

  { Respect an explicit /DIR= command line value. }
  if ExpandConstant('{param:DIR|}') <> '' then
    exit;

  if (PreviousInstallDirectory <> '') and DirExists(PreviousInstallDirectory) then
    WizardForm.DirEdit.Text := RemoveBackslashUnlessRoot(PreviousInstallDirectory);
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  NewDirectory: String;
  LedgerPath: String;
begin
  if CurStep <> ssInstall then
    exit;

  NewDirectory := RemoveBackslashUnlessRoot(ExpandConstant('{app}'));
  if (PreviousInstallDirectory = '') or
     SameText(RemoveBackslashUnlessRoot(PreviousInstallDirectory), NewDirectory) then
    exit;

  { The app consumes this ledger on first start and merges the old Hive/IPTV
    data into the newly selected directory before controllers initialize. }
  LedgerPath := AddBackslash(NewDirectory) + 'AppData\previous_install_locations.txt';
  ForceDirectories(ExtractFileDir(LedgerPath));
  SaveStringToFile(LedgerPath, RemoveBackslashUnlessRoot(PreviousInstallDirectory) + #13#10, True);
end;
