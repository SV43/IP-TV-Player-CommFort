unit uPlugin;

interface

uses
  Windows, Messages, SysUtils, Classes, Forms, Dialogs, Controls,
  StdCtrls, ComCtrls, Graphics, Variants, IniFiles,
  uFunc, uStickyForm, uSettings;

function  PluginStart(dwThisPluginID : DWORD; func1 : TCommFortProcess; func2 : TCommFortGetData) : Integer; cdecl; stdcall;
procedure PluginStop(); cdecl; stdcall;
procedure PluginShowOptions(); cdecl; stdcall;
procedure PluginShowAbout(); cdecl; stdcall;
procedure PluginProcess(dwID : DWORD; bInBuffer : PAnsiChar; dwInBufferSize : DWORD); cdecl; stdcall;
function  PluginGetData(dwID : DWORD; bInBuffer : PAnsiChar;
            dwInBufferSize : DWORD; bOutBuffer : PAnsiChar; dwOutBufferSize : DWORD): DWORD; cdecl; stdcall;
function CallWndProcHookProc(CODE, WParam, LParam: DWORD): DWORD; stdcall;

procedure ppUserChangeChannel(bInBuffer : PAnsiChar; dwInBufferSize : DWORD);
procedure ppUserEnterChannel(bInBuffer : PAnsiChar; dwInBufferSize : DWORD);
procedure ppUserLeaveChannel(bInBuffer : PAnsiChar; dwInBufferSize : DWORD);

function GetChatPanelSize() : TSize;
procedure FixWindowPos(AForm : TfrmStickyForm);
function Save:string;
procedure GetChannels;
procedure ReEnter;

var
  CommFort_Adress: string;
  path: string;

exports
  PluginStart, ReEnter, PluginStop, Save,
  PluginProcess, PluginGetData,
  PluginShowOptions, PluginShowAbout;

implementation

var
  ChatWindow: HWND = 0;
  ChannelsPanel: HWND = 0;
  CallWndProcHookHandle: HHOOK = 0;
  frmStickyForm: TfrmStickyForm = nil;
  StickyChanName: string;

  // глобальный ID плагина
  dwPluginID: DWORD = 0;

// =======================================================
// Логирование
// =======================================================
var
  LogFile: TextFile;

procedure DebugMsg(const S: string);
var
  LogPath: string;
begin
  try
    LogPath := path + 'IPTV_Plugin\debug.log';

    AssignFile(LogFile, LogPath);
    if FileExists(LogPath) then
      Append(LogFile)
    else
      Rewrite(LogFile);
    Writeln(LogFile, FormatDateTime('[dd.mm.yyyy hh:nn:ss]', Now) + ' - ' + S);
    CloseFile(LogFile);

    OutputDebugString(PChar('IPTV_Plugin: ' + S));
  except
    // игнорируем ошибки
  end;
end;

// =======================================================
// Вспомогательные
// =======================================================
procedure Refrash_Form;
begin
  if Assigned(frmStickyForm) then
    FixWindowPos(frmStickyForm);
end;

function Save:string;
var
  Ini: TIniFile;
begin
  DebugMsg('Save settings');
  Ini := TIniFile.Create(path+'IPTV_Plugin\IPTV_Plug.ini');
  try
    Ini.WriteString('Settings','VideoLan VLC Dll', frmSettings.dePachVLC.Text);
    Ini.WriteString('Settings','Style', frmSettings.lePachStyle.Text);
    Ini.WriteString('Settings','Chann IPTV Plug', frmSettings.cbIPTVchan.Text);
    Ini.WriteString('Settings','URL M3U', frmSettings.edURLM3U.Text);
    ini.WriteBool('Settings', 'LoadEPG', frmSettings.cbJTV.Checked);
  finally
    Ini.Free;
  end;
end;

function Open:string;
var
  Ini: TIniFile;
begin
  DebugMsg('Open settings');
  Ini := TIniFile.Create(path+'IPTV_Plugin\IPTV_Plug.ini');
  try
    frmSettings.dePachVLC.Text := Ini.ReadString('Settings', 'VideoLan VLC Dll', path + 'IPTV_Plugin\VLC');
    frmSettings.lePachStyle.Text := Ini.ReadString('Settings', 'Style', path + 'IPTV_Plugin\style\');
    frmSettings.cbIPTVchan.Text := Ini.ReadString('Settings', 'Chann IPTV Plug','IP-TV');
    frmSettings.edURLM3U.Text   := Ini.ReadString('Settings', 'URL M3U','');
    frmSettings.cbJTV.Checked := Ini.ReadBool('Settings', 'LoadEPG', True);
  finally
    Ini.Free;
  end;
end;

// =======================================================
// PluginStart
// =======================================================
function PluginStart(dwThisPluginID: DWORD; func1: TCommFortProcess; func2: TCommFortGetData): Integer;
const
  BUFFER_ID_PATH = 2010;
  BUFFER_ID_ADDRESS = 10;
  TIMER_INTERVAL = 1;
var
  iSize, iReadOffset: Integer;
  aData: AnsiString;

  function GetDataFromBuffer(BufferID: Integer): string;
  begin
    iSize := CommFortGetData(dwPluginID, BufferID, nil, 0, nil, 0);
    if iSize > 0 then
    begin
      SetLength(aData, iSize);
      CommFortGetData(dwPluginID, BufferID, PAnsiChar(aData), iSize, nil, 0);
      iReadOffset := 0;
      Result := fReadText(PAnsiChar(aData), iReadOffset);
    end
    else
      Result := '';
  end;
begin
  Result := Integer(False);
  try
    DebugMsg('PluginStart: init');

    dwPluginID := dwThisPluginID;
    CommFortProcess := func1;
    CommFortGetData := func2;

    ChatWindow := FindWindow('TfChatClient', nil);
    if ChatWindow = 0 then
    begin
      DebugMsg('ChatWindow not found!');
      Exit;
    end;

    ChannelsPanel := FindWindowEx(ChatWindow, 0, 'TPanel', nil);
    if ChannelsPanel = 0 then
    begin
      DebugMsg('ChannelsPanel not found!');
      Exit;
    end;

    if CallWndProcHookHandle = 0 then
    begin
      CallWndProcHookHandle := SetWindowsHookEx(WH_CALLWNDPROC, @CallWndProcHookProc, HInstance, GetCurrentThreadId());
      if CallWndProcHookHandle = 0 then
      begin
        DebugMsg('Failed to set hook');
        Exit;
      end;
    end;

    path := GetDataFromBuffer(BUFFER_ID_PATH);
    if path = '' then Exit;

    CommFort_Adress := GetDataFromBuffer(BUFFER_ID_ADDRESS);
    if CommFort_Adress = '' then Exit;

    if not DirectoryExists(path + 'IPTV_Plugin\') then
      MkDir(path + 'IPTV_Plugin\');

    frmSettings := TfrmSettings.Create(nil);
    frmStickyForm := TfrmStickyForm.Create(nil);

    StickyChanName := frmSettings.cbIPTVchan.Text;
    Open;
    ReEnter;


    SetTimer(0, 1, TIMER_INTERVAL, @Refrash_Form);

    DebugMsg('PluginStart: success');
    Result := Integer(True);
  except
    on E: Exception do
    begin
      DebugMsg('PluginStart ERROR: ' + E.Message);
      Result := Integer(False);
    end;
  end;
end;

// =======================================================
// PluginStop
// =======================================================
procedure PluginStop();
var
  ChatPanelSize: TSize;
begin
  DebugMsg('PluginStop');
  Save;
  try
    if Assigned(frmStickyForm) then
    begin
      frmStickyForm.FStopRequested := True;
      frmStickyForm.VLC_Player.Stop;
      ChatPanelSize := GetChatPanelSize();
      if frmStickyForm.ParentChanHandle <> 0 then
        MoveWindow(frmStickyForm.ParentChanHandle, 0, 0, ChatPanelSize.cx, ChatPanelSize.cy, True);
      FreeAndNil(frmStickyForm);
    end;

    if CallWndProcHookHandle <> 0 then
    begin
      UnhookWindowsHookEx(CallWndProcHookHandle);
      CallWndProcHookHandle := 0;
    end;

    ChatWindow := 0;
    ChannelsPanel := 0;
  except
    on E: Exception do
      DebugMsg('PluginStop ERROR: ' + E.Message);
  end;
end;

// =======================================================
// PluginProcess
// =======================================================
procedure PluginProcess(dwID : DWORD; bInBuffer : PAnsiChar; dwInBufferSize : DWORD);
begin
  case dwID of
    9  : ppUserChangeChannel(bInBuffer, dwInBufferSize);
    30 : ppUserEnterChannel(bInBuffer, dwInBufferSize);
    31 : ppUserLeaveChannel(bInBuffer, dwInBufferSize);
  end;
end;

// =======================================================
// PluginGetData
// =======================================================
function PluginGetData(dwID : DWORD; bInBuffer : PAnsiChar; dwInBufferSize : DWORD;
  bOutBuffer : PAnsiChar; dwOutBufferSize : DWORD): DWORD;
var iWriteOffset, iSize: Integer;
    uName: WideString;
begin
  iWriteOffset := 0;
  if (dwID = 2800) then
  begin
    if (dwOutBufferSize = 0) then
      Result := 4
    else
    begin
      fWriteInteger(bOutBuffer, iWriteOffset, 2);
      Result := 4;
    end;
  end
  else if (dwID = 2810) then
  begin
    uName := 'IPTV Plugin';
    iSize := Length(uName) * 2 + 4;
    if (dwOutBufferSize = 0) then
      Result := iSize
    else
    begin
      fWriteText(bOutBuffer, iWriteOffset, uName);
      Result := iSize;
    end;
  end
  else
    Result := 0;
end;

// =======================================================
// Options/About
// =======================================================
procedure PluginShowOptions();
begin
  frmSettings.Show;
  frmSettings.pcSettings.ActivePageIndex := 0;
  GetChannels;
end;

procedure PluginShowAbout();
begin
  frmSettings.Show;
  frmSettings.pcSettings.ActivePageIndex := 1;
  GetChannels;
end;

// =======================================================
// Hook
// =======================================================
function CallWndProcHookProc(CODE, WParam, LParam: DWORD): DWORD; stdcall;
var _CwpStruct : ^TCWPStruct;
begin
  try
    _CwpStruct := Pointer(LParam);
    if _CwpStruct^.message = WM_SIZE then
    begin
      if Assigned(frmStickyForm) and (frmStickyForm.ParentChanHandle = _CwpStruct^.hwnd) then
        FixWindowPos(frmStickyForm);
    end;
  finally
    Result := CallNextHookEx(CallWndProcHookHandle, code, WParam, LParam);
  end;
end;

// =======================================================
// Channels
// =======================================================
procedure GetChannels;
var
  aData: AnsiString;
  iSize, iReadOffset: Integer;
  g, c, i: Integer;
  CommFortChanel, CommFortTopic: string;
begin
  iSize := CommFortGetData(dwPluginID, 15, nil, 0, nil, 0);
  if iSize <= 0 then Exit;

  SetLength(aData, iSize);
  CommFortGetData(dwPluginID, 15, PAnsiChar(aData), iSize, nil, 0);

  iReadOffset := 0;
  g := fReadInteger(PAnsiChar(aData), iReadOffset);

  frmSettings.cbIPTVchan.Items.BeginUpdate;
  try
    frmSettings.cbIPTVchan.Items.Clear;
    for c := 1 to g do
    begin
      CommFortChanel := fReadText(PAnsiChar(aData), iReadOffset);
      CommFortTopic  := fReadText(PAnsiChar(aData), iReadOffset);
      if CommFortChanel <> '' then
        frmSettings.cbIPTVchan.Items.Add(CommFortChanel);
    end;

    for i := 0 to frmSettings.cbIPTVchan.Items.Count - 1 do
      if SameText(frmSettings.cbIPTVchan.Items[i], StickyChanName) then
      begin
        frmSettings.cbIPTVchan.ItemIndex := i;
        Break;
      end;
  finally
    frmSettings.cbIPTVchan.Items.EndUpdate;
  end;
end;

// =======================================================
// ReEnter
// =======================================================
procedure ReEnter;
begin
  DebugMsg('ReEnter');
  if StickyChanName <> frmSettings.cbIPTVchan.Text then
  begin
    StickyChanName := frmSettings.cbIPTVchan.Text;

    if Assigned(frmStickyForm) then
    begin
      FreeAndNil(frmStickyForm);
      ChatWindow := 0;
      ChannelsPanel := 0;
    end;

    if not Assigned(frmStickyForm) then
    begin
      ChatWindow := FindWindow('TfChatClient', nil);
      ChannelsPanel := FindWindowEx(ChatWindow, 0, 'TPanel', nil);

      frmStickyForm := TfrmStickyForm.Create(nil);
      frmStickyForm.ParentChanName := StickyChanName;
      frmStickyForm.ParentWindow := ChannelsPanel;
      frmStickyForm.ParentChanHandle := 0;

      ppUserChangeChannel(nil, 0);
      FixWindowPos(frmStickyForm);
    end;
  end;
end;

// =======================================================
// User Events
// =======================================================
procedure ppUserChangeChannel(bInBuffer: PAnsiChar; dwInBufferSize: DWORD);
var
  iReadOffset: Integer;
  CurrentChannelName: WideString;
  CurrentChannelHandle: HWND;
begin
  DebugMsg('ppUserChangeChannel');
  iReadOffset := 0;
  if Assigned(bInBuffer) then
    CurrentChannelName := fReadText(bInBuffer, iReadOffset)
  else
    CurrentChannelName := StickyChanName;

  if Assigned(frmStickyForm) then
  begin
    if (frmStickyForm.ParentChanName = CurrentChannelName) then
    begin
      CurrentChannelHandle := FindWindowEx(ChannelsPanel, 0, 'TRichView', nil);
      frmStickyForm.ParentChanHandle := CurrentChannelHandle;
      frmStickyForm.Show;
      FixWindowPos(frmStickyForm);
    end
    else
      frmStickyForm.Hide;
  end;
end;


procedure ppUserEnterChannel(bInBuffer: PAnsiChar; dwInBufferSize: DWORD);
var
  iReadOffset: Integer;
  ChanName: WideString;
  CurrentHandle: HWND;
begin
  try
    if (bInBuffer = nil) or (dwInBufferSize = 0) then Exit;

    iReadOffset := 0;
    ChanName := fReadText(bInBuffer, iReadOffset);


    DebugMsg('ppUserEnterChannel' + ChanName);

    if (ChanName = StickyChanName) and Assigned(frmStickyForm) then
    begin
      // Ищем TRichView для текущего канала
      CurrentHandle := FindWindowEx(ChannelsPanel, 0, 'TRichView', nil);
      while (CurrentHandle <> 0) and (not IsWindowVisible(CurrentHandle)) do
        CurrentHandle := FindWindowEx(ChannelsPanel, CurrentHandle, 'TRichView', nil);

      frmStickyForm.ParentChanName := ChanName;
      frmStickyForm.ParentWindow := ChannelsPanel;
      frmStickyForm.ParentChanHandle := CurrentHandle;

      frmStickyForm.Show;
      FixWindowPos(frmStickyForm);

      DebugMsg('Форма прикреплена к ' + ChanName);
    end;
  except
    on E: Exception do
      DebugMsg('Ошибка в ppUserEnterChannel: ' + E.Message);
  end;
end;

procedure ppUserLeaveChannel(bInBuffer : PAnsiChar; dwInBufferSize : DWORD);
var
  iReadOffset: Integer;
  ChanName: WideString;
begin
  DebugMsg('ppUserLeaveChannel');
  iReadOffset := 0;
  if Assigned(frmStickyForm) then
  begin
    ChanName := fReadText(bInBuffer, iReadOffset);
    if ChanName = StickyChanName then
    begin
      frmStickyForm.VLC_Player.Stop;
      FreeAndNil(frmStickyForm);
    end;
  end;
end;

// =======================================================
// Helpers
// =======================================================
function GetChatPanelSize() : TSize;
var WindowRect : TRect;
begin
  if GetWindowRect(ChannelsPanel, WindowRect) then
  begin
    Result.cx := WindowRect.Right - WindowRect.Left;
    Result.cy := WindowRect.Bottom - WindowRect.Top;
  end
  else
  begin
    Result.cx := 0;
    Result.cy := 0;
  end;
end;

procedure FixWindowPos(AForm : TfrmStickyForm);
var ChatPanelSize : TSize;
begin
  if not Assigned(AForm) then Exit;
  if AForm.ParentChanHandle = 0 then Exit;

  ChatPanelSize := GetChatPanelSize();
  AForm.SetBounds(0, 0, ChatPanelSize.cx, ChatPanelSize.cy);
  MoveWindow(AForm.Handle, 0, 0, ChatPanelSize.cx, ChatPanelSize.cy, True);
end;

end.

