unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics, IniFiles,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.Buttons, Vcl.StdCtrls, xpman, TLHelp32, Psapi, NativeAPI,
  Vcl.ExtCtrls, shellapi;

type
  TForm1 = class(TForm)
    XPManifest1: TXPManifest;
    Button1: TButton;
    MAgentPath: TEdit;
    OpenDialog1: TOpenDialog;
    MServerPath: TEdit;
    LocatorPath: TEdit;
    Server_AutoRun: TTimer;
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure Button1Click(Sender: TObject);
    procedure MAgentPathClick(Sender: TObject);
    procedure MAgentPathChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure MServerPathClick(Sender: TObject);
    procedure LocatorPathClick(Sender: TObject);
    procedure MServerPathChange(Sender: TObject);
    procedure LocatorPathChange(Sender: TObject);
    procedure Server_AutoRunTimer(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  PID, cbNeeded : DWORD;
  HandleWindow: THandle;
  LoadSwitch : boolean;
  Made: NativeUInt;

implementation

{$R *.dfm}

procedure RunExternalExecutable(const FileName: string);
var
  Indicador: HWND;
begin
  // 실행할 외부 .exe 파일의 경로를 FileName 매개변수로 전달합니다.
  // 예를 들어, 'C:\Program Files\MyApp\myapp.exe'와 같은 경로입니다.
  ShellExecute(0, 'open', PChar(FileName), nil, nil, SW_MINIMIZE); // SW_MINIMIZE를 사용하여 최소화로 실행
end;

function IsExeFileExists(const FilePath: string): Boolean;
begin
  // 지정된 경로에 .exe 파일이 존재하는지 확인합니다.
  Result := FileExists(FilePath) and (ExtractFileExt(FilePath) = '.exe');
end;

function KillTask(ExeFileName: string): Integer;
const
  PROCESS_TERMINATE = $0001;
var
  ContinueLoop: BOOL;
  FSnapshotHandle: THandle;
  FProcessEntry32: TProcessEntry32;
begin
  Result := 0;
  FSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  FProcessEntry32.dwSize := SizeOf(FProcessEntry32);
  ContinueLoop := Process32First(FSnapshotHandle, FProcessEntry32);
  while Integer(ContinueLoop) <> 0 do
  begin
    if ((UpperCase(ExtractFileName(FProcessEntry32.szExeFile)) = UpperCase(ExeFileName)) or
        (UpperCase(FProcessEntry32.szExeFile) = UpperCase(ExeFileName))) then
      Result := Integer(TerminateProcess(
        OpenProcess(PROCESS_TERMINATE, BOOL(0), FProcessEntry32.th32ProcessID), 0));
    ContinueLoop := Process32Next(FSnapshotHandle, FProcessEntry32);
  end;
  CloseHandle(FSnapshotHandle);
end;

procedure saveini;
var
 ini : TIniFile;
begin
 if LoadSwitch = True then begin
 ini := TIniFile.Create(GetCurrentDir+'\GSM_Setting.ini');
 try
  ini.WriteString('GSM_Setting', 'MatchServer.exe Path', Form1.MServerPath.Text);
  ini.WriteString('GSM_Setting', 'Locator.exe Path', Form1.LocatorPath.Text);
  ini.WriteString('GSM_Setting', 'MatchAgent.exe Path', Form1.MAgentPath.Text);
 finally
  ini.Free;
 end;
 end;
end;

procedure loadini;
var
  ini : TIniFile;
  SettingStrCmp,SettingStrCmp2,SettingStrCmp3 : String;
begin
ini := TIniFile.Create(GetCurrentDir+'\GSM_Setting.ini');
  try
    if ini.ReadString( 'GSM_Setting', 'MatchServer.exe Path', '') <> '' then begin
      SettingStrCmp := ini.ReadString( 'GSM_Setting', 'MatchServer.exe Path', '');
    end else begin
      SettingStrCmp := 'MatchServer.exe Path';
    end;

    if ini.ReadString( 'GSM_Setting', 'Locator.exe Path', '') <> '' then begin
      SettingStrCmp2 := ini.ReadString( 'GSM_Setting', 'Locator.exe Path', '');
    end else begin
      SettingStrCmp2 := 'Locator.exe Path';
    end;

    if ini.ReadString( 'GSM_Setting', 'MatchAgent.exe Path', '') <> '' then begin
      SettingStrCmp3 := ini.ReadString( 'GSM_Setting', 'MatchAgent.exe Path', '');
    end else begin
      SettingStrCmp3 := 'MatchAgent.exe Path';
    end;

    Form1.MServerPath.Text := SettingStrCmp;
    Form1.LocatorPath.Text := SettingStrCmp2;
    Form1.MAgentPath.Text := SettingStrCmp3;
  finally
    ini.Free;
  end;
  LoadSwitch := True;
end;

function SetDebugPrivilege(const bPrivilege: Boolean): Boolean;
const
  SE_DEBUG_PRIVILEGE = 20;
var
  pbAdjust: PBoolean;
begin
  Result := False;
  // PBoolean 메모리 할당
  GetMem(pbAdjust, SizeOf(pbAdjust));
  try
    try
      // RtlAdjustPrivilege Native API 함수
      RtlAdjustPrivilege(SE_DEBUG_PRIVILEGE, bPrivilege, False, pbAdjust);
      Result := True;
    except
      on e: Exception do
      begin
        //ShowMessage(e.Message);
      end;
    end;
  finally
    // PBoolean 메모리 해제
    FreeMem(pbAdjust);
  end;
end;

procedure Delay(Elapsed : Integer);
var
Before, After : Integer;
begin
Before := GetTickCount;
repeat
After := GetTickCount;
Application.ProcessMessages;
Until
After > Before + Elapsed;
end;

function CheckProc(Process: String): Boolean;
var ContinueLoop: BOOL;
    FSnapshotHandle: THandle;
    FProcessEntry32: TProcessEntry32;
begin
 Result := False;
 FSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
 FProcessEntry32.dwSize := Sizeof(FProcessEntry32);
 ContinueLoop := Process32First(FSnapshotHandle,FProcessEntry32);
 while Integer(ContinueLoop) <> 0 do
 begin
  if ((UpperCase(ExtractFileName(FProcessEntry32.szExeFile)) = UpperCase(Process))
  or (UpperCase(FProcessEntry32.szExeFile) = UpperCase(Process))) then
  begin
   PID := FProcessEntry32.th32ProcessID;
   if PID <> 0 then
   begin
    HandleWindow := OpenProcess(PROCESS_ALL_ACCESS, False, PID);
    Result := True;
    try
    finally
    end;
    Break;
   end;
  end;
  ContinueLoop := Process32Next(FSnapshotHandle,FProcessEntry32);
 end;
 CloseHandle(FSnapshotHandle);
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
{SetDebugPrivilege(true);
CheckProc('Gunz.exe');
SetDebugPrivilege(False);}
  if Button1.Caption = 'Server On' then begin
    Server_AutoRun.Enabled := True;
    Button1.Caption := 'Server Off'
  end else if Button1.Caption = 'Server Off' then begin
    Server_AutoRun.Enabled := False;
    Button1.Caption := 'Server On';
    KillTask('MatchServer.exe');
    KillTask('Locator.exe');
    KillTask('MatchAgent.exe');
  end;
end;

procedure TForm1.MServerPathChange(Sender: TObject);
begin
saveini;
end;

procedure TForm1.MServerPathClick(Sender: TObject);
var
  OpenDialog: TOpenDialog;
begin
  OpenDialog := TOpenDialog.Create(nil);
  try
    OpenDialog.InitialDir := 'C:\'; // OpenDialog가 열릴 때 보여줄 디렉토리
    OpenDialog.Options := [ofFileMustExist, ofPathMustExist, ofNoChangeDir];
    if OpenDialog.Execute then
    begin
      MServerPath.Text := OpenDialog.FileName;
    end;
  finally
    OpenDialog.Free;
  end;
end;

procedure TForm1.LocatorPathChange(Sender: TObject);
begin
saveini;
end;

procedure TForm1.LocatorPathClick(Sender: TObject);
var
  OpenDialog: TOpenDialog;
begin
  OpenDialog := TOpenDialog.Create(nil);
  try
    OpenDialog.InitialDir := 'C:\'; // OpenDialog가 열릴 때 보여줄 디렉토리
    OpenDialog.Options := [ofFileMustExist, ofPathMustExist, ofNoChangeDir];
    if OpenDialog.Execute then
    begin
      LocatorPath.Text := OpenDialog.FileName;
    end;
  finally
    OpenDialog.Free;
  end;
end;

procedure TForm1.MAgentPathChange(Sender: TObject);
begin
saveini;
end;

procedure TForm1.MAgentPathClick(Sender: TObject);
var
  OpenDialog: TOpenDialog;
begin
  OpenDialog := TOpenDialog.Create(nil);
  try
    OpenDialog.InitialDir := 'C:\'; // OpenDialog가 열릴 때 보여줄 디렉토리
    OpenDialog.Options := [ofFileMustExist, ofPathMustExist, ofNoChangeDir];
    if OpenDialog.Execute then
    begin
      MAgentPath.Text := OpenDialog.FileName;
    end;
  finally
    OpenDialog.Free;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
LoadSwitch := False;
loadini;
end;

procedure TForm1.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  ReleaseCapture;
  SendMessage(Handle, WM_NCLBUTTONDOWN, HTCAPTION, 0);
end;

procedure TForm1.Server_AutoRunTimer(Sender: TObject);
begin
try
  if CheckProc('MatchServer.exe') = False then begin
    if IsExeFileExists(MServerPath.Text) then
      RunExternalExecutable(MServerPath.Text);
  end;
  if CheckProc('Locator.exe') = False then begin
    if IsExeFileExists(LocatorPath.Text) then
      RunExternalExecutable(LocatorPath.Text);
  end;
  if CheckProc('MatchAgent.exe') = False then begin
    if IsExeFileExists(MAgentPath.Text) then
      RunExternalExecutable(MAgentPath.Text);
  end;
finally

end;
end;

end.
