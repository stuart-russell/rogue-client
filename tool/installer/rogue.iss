; Rogue - Windows installer (Inno Setup 6)
;
; Built by .github/workflows/release.yml after `tool/build_windows.ps1`:
;   ISCC.exe /DAppVersion=0.1.0 ^
;            /DSourceDir=build\windows\x64\runner\Release ^
;            /DOutputDir=dist tool\installer\rogue.iss
;
; Installs the same layout the in-app updater expects:
;   %LOCALAPPDATA%\Programs\Rogue\app-<version>\
;   %LOCALAPPDATA%\Programs\Rogue\current  ->  app-<version>  (junction)
; so a fresh install can update itself, and an existing install can be
; upgraded by running a newer setup.exe.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif

#define AppName "Rogue"
#define AppExe "rogue.exe"

[Setup]
AppId={{6E2B8A41-0B7D-4B51-9F1B-6B0E2A0C7D31}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Rogue
DefaultDirName={localappdata}\Programs\Rogue\app-{#AppVersion}
DefaultGroupName={#AppName}
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableWelcomePage=no
PrivilegesRequired=lowest
OutputDir={#OutputDir}
OutputBaseFilename=Rogue-{#AppVersion}-win-x64-setup
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={localappdata}\Programs\Rogue\current\{#AppExe}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
MinVersion=10.0
CloseApplications=no
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{localappdata}\Programs\Rogue\current\{#AppExe}"; WorkingDir: "{localappdata}\Programs\Rogue\current"
Name: "{autodesktop}\{#AppName}"; Filename: "{localappdata}\Programs\Rogue\current\{#AppExe}"; WorkingDir: "{localappdata}\Programs\Rogue\current"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"

[Run]
Filename: "{localappdata}\Programs\Rogue\current\{#AppExe}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{cmd}"; Parameters: "/c rmdir ""{localappdata}\Programs\Rogue\current"""; Flags: runhidden; RunOnceId: "RemoveLauncher"

[Code]
procedure PointLauncherAt(VersionDir: String);
var
  Root, Link, Cmd: String;
  ResultCode: Integer;
begin
  Root := ExpandConstant('{localappdata}\Programs\Rogue');
  Link := Root + '\current';
  Cmd := ExpandConstant('{cmd}');

  { A junction is removed with rmdir; it never touches the folder it points at. }
  if DirExists(Link) then
    Exec(Cmd, '/c rmdir "' + Link + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

  if (not Exec(Cmd, '/c mklink /J "' + Link + '" "' + VersionDir + '"', '',
               SW_HIDE, ewWaitUntilTerminated, ResultCode))
     or (ResultCode <> 0) then
    MsgBox('Rogue installed, but the launcher link could not be created at:' + #13#10 +
           Link + #13#10#13#10 +
           'Start the app from ' + VersionDir + '\{#AppExe} instead.',
           mbError, MB_OK);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    PointLauncherAt(ExpandConstant('{app}'));
end;
