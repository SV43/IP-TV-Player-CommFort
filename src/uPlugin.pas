unit uPlugin;

interface

uses Graphics, Windows, Classes, SysUtils, Dialogs, Messages, uFunc,
     Variants,  Controls, Forms, uStickyForm,
     StdCtrls, ComCtrls, Unit1, inifiles;

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
  CommFort_Adress:string;
  path:String;

exports PluginStart, ReEnter, PluginStop, Save, PluginProcess, PluginGetData, PluginShowOptions, PluginShowAbout;

implementation

var
  ChatWindow : HWND = 0; //������� ���� ����
  ChannelsPanel : HWND = 0; //������ �� ������� ��������� ���� �������
  CallWndProcHookHandle : HHOOK = 0;
  ChatWindowHeight : integer;
  frmStickyForm : TfrmStickyForm = nil;
  StickyChanName :String;
  Ini: Tinifile;


//---------------------------------------------------------------------------
//���������� ����� ������ 1 ���.
procedure Refrash_Form;
begin
  FixWindowPos(frmStickyForm);
end;


function Save:string;
var
  Ini: Tinifile;
begin
  Ini:=TiniFile.Create(path+'IPTV_Plugin\IPTV_Plug.ini');
  Ini.WriteString('Setings','VideoLan VLC Dll', Form1.dePachVLC.Text);
  Ini.WriteString('Setings','Style', Form1.lePachStyle.Text);
  Ini.WriteString('Setings','Chann IPTV Plug', Form1.cbIPTVchan.Text);
  Ini.WriteString('Setings','URL M3U', Form1.edURLM3U.Text);
  Ini.WriteString('Setings','URL JTV', Form1.edURLJTV.Text);
  Ini.Free;
end;

function Open:string;
var
 ini: TIniFile;
begin
  Ini:=TiniFile.Create(path+'IPTV_Plugin\IPTV_Plug.ini');
  Form1.dePachVLC.Text:=Ini.ReadString('Setings', 'VideoLan VLC Dll',ExtractFileDir(ParamStr(0))+'\Plugins\IPTV_Plugin\VLC');
  Form1.lePachStyle.Text:=Ini.ReadString('Setings', 'Style', ExtractFileDir(ParamStr(0))+'\Plugins\IPTV_Plugin\style');
  Form1.cbIPTVchan.Text:=Ini.ReadString('Setings', 'Chann IPTV Plug','IP-TV');
  Form1.edURLM3U.Text:=Ini.ReadString('Setings', 'URL M3U','https://site.ru/iptv.m3u');
  Form1.edURLJTV.Text:=Ini.ReadString('Setings', 'URL JTV','https://site.ru/jtv.zip2');
  Ini.Free;
end;

function PluginStart(dwThisPluginID: DWORD;func1: TCommFortProcess; func2: TCommFortGetData): Integer;
const
  BUFFER_ID_PATH = 2010;
  BUFFER_ID_ADDRESS = 10;
  TIMER_INTERVAL = 1;
var
  iSize, iReadOffset: Integer;
  aData: AnsiString;
  Success: Boolean;

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
    // ������������� �������� ����������
    dwPluginID := dwThisPluginID;
    CommFortProcess := func1;
    CommFortGetData := func2;

    // ����� ����
    ChatWindow := FindWindow('TfChatClient', nil);
    if ChatWindow = 0 then Exit;

    ChannelsPanel := FindWindowEx(ChatWindow, 0, 'TPanel', nil);
    if ChannelsPanel = 0 then Exit;

    // ��������� ����
    if CallWndProcHookHandle = 0 then
    begin
      CallWndProcHookHandle := SetWindowsHookEx(
        WH_CALLWNDPROC,
        @CallWndProcHookProc,
        HInstance,
        GetCurrentThreadId()
      );
      if CallWndProcHookHandle = 0 then Exit;
    end;

    // ��������� ������
    path := GetDataFromBuffer(BUFFER_ID_PATH);
    if path = '' then Exit;

    CommFort_Adress := GetDataFromBuffer(BUFFER_ID_ADDRESS);
    if CommFort_Adress = '' then Exit;

    // �������� ����������
    if not DirectoryExists(path + 'IPTV_Plugin\') then
      MkDir(path + 'IPTV_Plugin\');

    // �������� ����
    form1 := TForm1.Create(Application);
    frmStickyForm := TfrmStickyForm.Create(nil);

    // �������������
    open;
    reenter;
    StickyChanName := Form1.cbIPTVchan.Text;



    // ��������� �������
    setTimer(0, 1, TIMER_INTERVAL, @Refrash_Form);

    Result := Integer(True);

  except
    on E: Exception do
    begin
      ShowMessage('������ ��� ������� �������: ' + E.Message);
      Result := Integer(False);
    end;
  end;
end;


procedure ReEnter;
var
  TmpBoolean: Boolean;
  TmpInteger: Integer;
  ChatPanelSize: TSize;
begin
  // ���������, ��������� �� ��������� �����
  if StickyChanName <> Form1.cbIPTVchan.Text then
  begin
    // ��������� ����� ��� ������
    StickyChanName := Form1.cbIPTVchan.Text;

    // ���� ����� ����������, ����������� �������
    if Assigned(frmStickyForm) then
    begin
      try
        // �������� ������ ������ ����
        ChatPanelSize := GetChatPanelSize();

        // ��������� ���, ���� �� ����������
        if (CallWndProcHookHandle <> 0) then
        begin
          UnhookWindowsHookEx(CallWndProcHookHandle);
          CallWndProcHookHandle := 0;
        end;

        // ����������������� ����
        if frmStickyForm.ParentChanHandle <> 0 then
          MoveWindow(frmStickyForm.ParentChanHandle,0,0,ChatPanelSize.cx,ChatPanelSize.cy,True);

        // ����������� �����
        FreeAndNil(frmStickyForm);

        // ���������� ��������� ����������
        ChatWindow := 0;
        ChannelsPanel := 0;
      except
        on E: Exception do
        begin
          ShowMessage('������ ��� ����������� �����: ' + E.Message);
        end;
      end;
    end;

    // ������� ����� �����, ���� ��� �� ����������
    if not Assigned(frmStickyForm) then
    begin
      try
        // ������� ���� ���� � ������ �������
        ChatWindow := FindWindow('TfChatClient', nil);
        ChannelsPanel := FindWindowEx(ChatWindow, 0, 'TPanel', nil);

        // ������������� ���
        if CallWndProcHookHandle = 0 then
          CallWndProcHookHandle := SetWindowsHookEx(
            WH_CALLWNDPROC,
            @CallWndProcHookProc,
            HInstance,
            GetCurrentThreadId()
          );

        // ������� � ����������� �����
        frmStickyForm := TfrmStickyForm.Create(nil);
        frmStickyForm.ParentChanName := StickyChanName;
        frmStickyForm.ParentWindow := ChannelsPanel;
        frmStickyForm.ParentChanHandle := 0;

        // ��������� ����� � �������
        ppUserChangeChannel(nil, 0);
        FixWindowPos(frmStickyForm);
      except
        on E: Exception do
        begin
          ShowMessage('������ ��� �������� �����: ' + E.Message);
        end;
      end;
    end;
  end;
end;

procedure GetChannels;
const
  BUFFER_ID = 15;
var
  // ��������� ���������� � ��������� ����������
  BufferSize: Integer;
  ReadOffset: Integer;
  ChannelCount: Integer;
  ChannelIndex: Integer;

  DataBuffer: AnsiString;
  ChannelName: string;
begin
  try
    // �������� ������ ������
    BufferSize := CommFortGetData(dwPluginID,BUFFER_ID,nil,0,nil,0);

    // ��������� ������������ ����������� �������
    if BufferSize <= 0 then
    begin
      Exit;
    end;

    // �������� ������ ��� �����
    SetLength(DataBuffer, BufferSize);

    // ��������� ����� �������
    CommFortGetData(dwPluginID,BUFFER_ID,PAnsiChar(DataBuffer),BufferSize,nil,0);

    // �������������� �������� ������
    ReadOffset := 0;

    // ������ ���������� �������
    ChannelCount := fReadInteger(PAnsiChar(DataBuffer), ReadOffset);

    // ������� ������ �������
    Form1.cbIPTVchan.Clear;

    // ��������� ������ �������
    if ChannelCount > 0 then
    begin
      // ���������� ����� �������� ���� �� 0 �� ChannelCount - 1
      for ChannelIndex := 0 to ChannelCount  do
      begin
        // ������ �������� ������
        ChannelName := fReadText(PAnsiChar(DataBuffer), ReadOffset);

        // ��������� ����� � ������, ���� �������� �� ������
        if ChannelName <> '' then
          Form1.cbIPTVchan.Items.Add(ChannelName);
      end;

      // ������������� ��������� �����
      Form1.cbIPTVchan.ItemIndex :=
        Form1.cbIPTVchan.Items.IndexOf(StickyChanName);
    end;
  except
    on E: Exception do
    begin
      // ����� ������������� ��������� �� ������
      ShowMessage(
        '������ ��� ��������� ������ �������: ' +
        E.Message
      );
    end;
  end;
end;

//-----

//---------------------------------------------------------------------------
procedure PluginStop();
var
    ChatPanelSize : TSize;
begin

   Save;

  try
    if (CallWndProcHookHandle <> 0) and (Integer(UnhookWindowsHookEx(CallWndProcHookHandle)) <> 0) then
      CallWndProcHookHandle := 0;
    if Assigned(frmStickyForm) then
      begin
        ChatPanelSize := GetChatPanelSize();
        MoveWindow(frmStickyForm.ParentChanHandle, 0, 0, ChatPanelSize.cx, ChatPanelSize.cy, True);
        FreeAndNil(frmStickyForm);
      end;
    ChatWindow := 0;
    ChannelsPanel := 0;
  except
    on E : Exception do
      ShowMessage('PluginStop() ' + E.Message);
  end;

end;


//---------------------------------------------------------------------------
procedure PluginProcess(dwID : DWORD; bInBuffer : PAnsiChar; dwInBufferSize : DWORD);
var iReadOffset: Integer;
begin
  iReadOffset := 0;
  case dwID of
    9  : ppUserChangeChannel(bInBuffer, dwInBufferSize);
    30 : ppUserEnterChannel(bInBuffer, dwInBufferSize);
    31 : ppUserLeaveChannel(bInBuffer, dwInBufferSize);
  end;
end;
//---------------------------------------------------------------------------
function PluginGetData(dwID : DWORD; bInBuffer : PAnsiChar; dwInBufferSize : DWORD; bOutBuffer : PAnsiChar; dwOutBufferSize : DWORD): DWORD;
var iWriteOffset, iSize: Integer;
    uName: WideString;
begin
	iWriteOffset := 0;
	if (dwID = 2800) then //�������������� �������
	begin
		if (dwOutBufferSize = 0) then
			Result := 4 //����� ������ � ������, ������� ���������� �������� ���������
		else
		begin
			fWriteInteger(bOutBuffer, iWriteOffset, 2); //������ �������� ������ ��� �������
			Result := 4;//����� ������������ ������ � ������
		end;
	end
	else
	if (dwID = 2810) then //�������� ������� (������������ � ������)
	begin
		uName := 'IPTV Plugin';//�������� �������
		iSize := Length(uName) * 2 + 4;

		if (dwOutBufferSize = 0) then
			Result := iSize //����� ������ � ������, ������� ���������� �������� ���������
		else
		begin
			fWriteText(bOutBuffer, iWriteOffset, uName);
			Result := iSize;//����� ������������ ������ � ������
		end;
	end
	else
		Result := 0;//������������ �������� - ����� ���������� ������
end;


//---------------------------------------------------------------------------
procedure PluginShowOptions();
begin
  Form1.show;
  Form1.pcSettings.ActivePageIndex := 0;
end;

//---------------------------------------------------------------------------
procedure PluginShowAbout();
begin
 Form1.show;
 Form1.pcSettings.ActivePageIndex := 1;
end;

//--------------------------------------------------------------------------------------------------
function CallWndProcHookProc(CODE, WParam, LParam: DWORD): DWORD; stdcall;
var _CwpStruct : ^TCWPStruct;
begin
  try
    _CwpStruct := Pointer(LParam);
    case _CwpStruct.message of
      WM_SIZE :
        begin
          if Assigned(frmStickyForm) and (frmStickyForm.ParentChanHandle = _CwpStruct.hwnd) then
            FixWindowPos(frmStickyForm);
        end;
    end;
  finally
    Result := CallNextHookEx(CallWndProcHookHandle, code, WParam, LParam);
  end;
end;


procedure ppUserChangeChannel(bInBuffer: PAnsiChar; dwInBufferSize: DWORD);
var
  iReadOffset: Integer;
  CurrentChannelName: WideString;
  CurrentChannelHandle: HWND;
  iAttempts: Integer;
begin
  iReadOffset := 0;

  try
    if Assigned(bInBuffer) then
      CurrentChannelName := fReadText(bInBuffer, iReadOffset)
    else
      CurrentChannelName := GetCurrentChannelName();

    if Assigned(frmStickyForm) then
    begin
      if (frmStickyForm.ParentChanName = CurrentChannelName) then
      begin
        if frmStickyForm.ParentChanHandle = 0 then
        begin
          CurrentChannelHandle := FindWindowEx(ChannelsPanel, 0, 'TRichView', nil);
          iAttempts := 0;

          while (not IsWindowVisible(CurrentChannelHandle)) and
                (CurrentChannelHandle <> 0) and
                (iAttempts < 10) do
          begin
            CurrentChannelHandle := FindWindowEx(ChannelsPanel, CurrentChannelHandle, 'TRichView', nil);
            Inc(iAttempts);
          end;

          frmStickyForm.ParentChanHandle := CurrentChannelHandle;

          if frmStickyForm.ParentChanHandle = 0 then
          begin
            frmStickyForm.Show();
            FixWindowPos(frmStickyForm);
          end;
        end;
      end
      else
        frmStickyForm.Hide();
    end;
  except
    on E: Exception do
    begin
      ShowMessage('ppUserChangeChannel() ' + E.Message);
    end;
  end;
end;


procedure ppUserEnterChannel(bInBuffer: PAnsiChar; dwInBufferSize: DWORD);
var
  iReadOffset: Integer;
  ChanName: WideString;
begin
  try
    if (bInBuffer = nil) or (dwInBufferSize = 0) then
      Exit;

    iReadOffset := 0;
    ChanName := fReadText(bInBuffer, iReadOffset);

    if (ChanName = StickyChanName) and Assigned(frmStickyForm) then
    begin
      frmStickyForm.ParentChanName := ChanName;
      frmStickyForm.ParentWindow := ChannelsPanel;
      frmStickyForm.ParentChanHandle := 0;
      ppUserChangeChannel(nil, 0);
      frmStickyForm.Show;
      FixWindowPos(frmStickyForm);
    end;
  except
    on E: Exception do
    begin
      // ����������� ������
       ShowMessage('ppUserEnterChannel() ' + E.Message);
      // ����� ���������� ���������
    end;
  end;
end;

procedure ppUserLeaveChannel(bInBuffer : PAnsiChar; dwInBufferSize : DWORD);
var iReadOffset : Integer;

    ChanName : WideString;
begin
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
  if AForm.ParentChanHandle <> 0 then
    Exit;
  ChatPanelSize := GetChatPanelSize();
  AForm.Height := ChatPanelSize.cy;
  AForm.Width := ChatPanelSize.cx;
  MoveWindow(AForm.ParentChanHandle, 0, AForm.Height, AForm.Width, ChatPanelSize.cy - AForm.Height, True);
end;


end.

