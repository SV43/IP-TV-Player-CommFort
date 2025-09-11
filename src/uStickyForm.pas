unit uStickyForm;

interface

uses
 Windows, Classes, SysUtils, System.StrUtils, Dialogs, Messages, uFunc,
  Variants,  Controls, Forms, Vcl.StdCtrls, Vcl.Buttons, Vcl.XPMan,
  Vcl.ComCtrls,  PasLibVlcUnit, Vcl.ExtCtrls, System.Win.Registry,
  System.Win.ScktComp, Vcl.Menus,Vcl.Graphics, PNGImage,
  Vcl.ExtDlgs,
  IdBaseComponent, IdComponent, IdTCPConnection,
  IdTCPClient, IdHTTP, System.ImageList, PasLibVlcPlayerUnit, Vcl.ImgList,
  IdSSLOpenSSL, RegularExpressions, System.Net.HttpClientComponent;
type
  TfrmStickyForm = class(TForm)
    pmMenu: TPopupMenu;
    C1: TMenuItem;
    N1: TMenuItem;
    PanelButton: TPanel;
    Splitter1: TSplitter;
    pnPlayer: TPanel;
    VLC_Player: TPasLibVlcPlayer;
    sbBack: TSpeedButton;
    sbPlay: TSpeedButton;
    sbStop: TSpeedButton;
    sbNext: TSpeedButton;
    sbFullScreen: TSpeedButton;
    tvVolume: TTrackBar;
    lbIPTVlist: TListBox;
    sbOpen: TSpeedButton;
    ilLoad: TImageList;
    odFile: TOpenDialog;
    ilButton: TImageList;
    procedure C1Click(Sender: TObject);
    procedure lbIPTVlistDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure sbOpenClick(Sender: TObject);
    procedure sbNextClick(Sender: TObject);
    procedure N1Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure sbFullScreenClick(Sender: TObject);
    procedure tvVolumeChange(Sender: TObject);
    procedure VLC_PlayerMediaPlayerPlaying(Sender: TObject);
    procedure lbIPTVlistDblClick(Sender: TObject);
  private
    FParentChanName: WideString;
    FParentChanHandle: HWND;
    procedure SetParentChanName(const Value: WideString);
    procedure SetParentChanHandle(const Value: HWND);
    { Private declarations }
    procedure ParseM3U(const FileName: string);
    function LoadPNGToImageList(const AFileName: string): Integer;
    function GetLogoIndexForItem(Index: Integer): Integer;
  public
    property ParentChanName   : WideString read FParentChanName write SetParentChanName;
    property ParentChanHandle : HWND read FParentChanHandle write SetParentChanHandle;

    { Public declarations }
  end;

  TDownloadThread = class(TThread)
  private
    FFileName: string;
    FNetHTTPClient: TNetHTTPClient;
    FStream: TMemoryStream;
    FURLList: TStringList;
    FForm: TfrmStickyForm;
  protected
    procedure Execute; override;
  public
    constructor Create(const FileName: string; Form: TfrmStickyForm);
    destructor Destroy; override;
  end;


{ TfrmStickyForm }
var
  frmStickyForm : TfrmStickyForm;
  ImageList: TImageList;




implementation

{$R *.dfm}

uses FullScreenFormUnit, uPlugin, Unit1;



// ������� ���������� �������� �������� tvg-id �� ������
function ExtractTVGID(const Line: string): string;
var
  RegEx: TRegEx;
  Match: TMatch;
begin
  RegEx := TRegEx.Create('tvg-id="([^"]+)"'); // ���������� ��������� ��� ��������
  Match := RegEx.Match(Line);
  if Match.Success then
    Result := Match.Groups[1].Value // �������� �������� ������� ������� ������
  else
    Result := ''; // ���� ���������� �� �������, ���������� ������ ������
end;

// �������� ��������� PNG-�����
function CheckPNGSignature(Stream: TStream): Boolean;
const
  PNG_SIGNATURE: array[0..7] of Byte = ($89, $50, $4E, $47, $0D, $0A, $1A, $0A);
var
  BytesRead: Integer;
  SignatureBytes: array[0..7] of Byte;
begin
  Result := False;

  // ��������� ������������ ������� ������
  var OldPos := Stream.Position;

  try
    // ������������ � ������ ������
    Stream.Position := 0;

    // ������ ������ ������ ������
    BytesRead := Stream.Read(SignatureBytes, SizeOf(PNG_SIGNATURE));

    // ��������������� ������� ������ �������
    Stream.Position := OldPos;

    // ��������� ���������� ���������
    Result := (BytesRead = SizeOf(PNG_SIGNATURE)) and CompareMem(@SignatureBytes, @PNG_SIGNATURE, SizeOf(PNG_SIGNATURE));
  except
    on E: Exception do
    begin
      Result := False;
    end;
  end;
end;

// ����������� ������ ��������
constructor TDownloadThread.Create(const FileName: string; Form: TfrmStickyForm);
begin
  inherited Create(True); // ������� ����� ����������������
  FreeOnTerminate := True; // ����������� ������������� ��� ����������
  FFileName := FileName;
  FForm := Form;
end;

// ���������� ������ ��������
destructor TDownloadThread.Destroy;
begin
  if Assigned(FStream) then
    FStream.Free; // ������������ ������ ��� Memory Stream
  if Assigned(FNetHTTPClient) then
    FNetHTTPClient.Free; // ������������ HTTP-�������
  if Assigned(FURLList) then
    FURLList.Free; // ������������ ������ �����
  inherited;
end;

procedure TDownloadThread.Execute;
var
  I: Integer;
  Line, TVGID: String;
  FileName: String;
  TempStream: TMemoryStream; // ��������� ���������� ������
begin
  FNetHTTPClient := TNetHTTPClient.Create(nil); // ������ ������� �����
  FURLList := TStringList.Create;

  try
    FURLList.LoadFromFile(FFileName);

    for I := 0 to FURLList.Count - 1 do
    begin
      Line := FURLList[I];

      if Pos('tvg-logo="', Line) > 0 then
      begin
        Delete(Line, 1, Pos('tvg-logo=', Line) + Length('tvg-logo='));
        Line := Trim(Copy(Line, 1, Pos('"', Line) - 1));

        TVGID := ExtractTVGID(FURLList[I]);
        if TVGID <> '' then
        begin
          FileName := Format('%s.png', [TVGID]);

          if FileExists(path+'IPTV_Plugin\image\' + FileName) then
            Continue;


          // ������ ��������� ����� ��� ������� �����������
          TempStream := TMemoryStream.Create;
          try
            try
              FNetHTTPClient.Get(Line, TempStream);

              if TempStream.Size > 0 then
              begin
                // ���������, �������� �� ���� ��������� PNG-������������
                if CheckPNGSignature(TempStream) then
                  TempStream.SaveToFile(path+'IPTV_Plugin\image\' + FileName)
              end
            except
              on E: Exception do
              begin
                // ���������� ��� ������
              end;
            end;
          finally
            FreeAndNil(TempStream); // ����������� ������ ����� ��������
          end;
        end;
      end;
    end;
  finally
    FreeAndNil(FURLList);
    FreeAndNil(FNetHTTPClient);
  end;
end;


function TfrmStickyForm.LoadPNGToImageList(const AFileName: string): Integer;
var
  PNG: TPngImage;
  BMP: TBitmap;
begin
  Result := -1;
  PNG := TPngImage.Create;
  try
    PNG.LoadFromFile(AFileName);

    BMP := TBitmap.Create;
    try
      // ������������� ������ 50x50
      BMP.Width := 70;
      BMP.Height := 70;
      BMP.PixelFormat := pf32bit;
      BMP.AlphaFormat := afDefined;

      // ����������� �����������
      BMP.Canvas.StretchDraw(Rect(0, 0, 70, 70), PNG);

      Result := ilLoad.Add(BMP, nil);
    finally
      BMP.Free;
    end;
  finally
    PNG.Free;
  end;
end;


procedure TfrmStickyForm.N1Click(Sender: TObject);
begin
   Form1.Show;
end;

procedure TfrmStickyForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  VLC_Player.Stop;
end;

function TfrmStickyForm.GetLogoIndexForItem(Index: Integer): Integer;
begin
  // ����� ���� ������ ��������� �������
  // ��������:
  Result := Index mod ilLoad.Count; // ������� ������
end;





procedure TfrmStickyForm.C1Click(Sender: TObject);
begin
 if lbIPTVlist.Visible = True then
 begin
   lbIPTVlist.Visible := False;
   Splitter1.Visible := False;
 end else
 begin
   lbIPTVlist.Visible := True;
   Splitter1.Visible := True;
 end;
end;





procedure TfrmStickyForm.lbIPTVlistDblClick(Sender: TObject);
begin
 if   lbIPTVlist.Items.Count-1 >= 0 then
 begin
  VLC_Player.VLC.Path := Form1.dePachVLC.Text;
//  VLC_Player.PlayNormal(lbIPTVlist.Items[lbIPTVlist.itemindex])
 end;
end;

procedure TfrmStickyForm.lbIPTVlistDrawItem(Control: TWinControl;
  Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  ListBox: TListBox;
  Canvas: TCanvas;
  Text: string;
  Y: Integer;
  ItemRect: TRect;
  LogoIndex: Integer;
begin
  ListBox := TListBox(Control);
  Canvas := ListBox.Canvas;

  // �������� ������� ImageList
  if not Assigned(ilLoad) then
    Exit;


  // ������� �������
  if odSelected in State then
    Canvas.Brush.Color := clHighlight
  else
    Canvas.Brush.Color := ListBox.Color;

  Canvas.FillRect(Rect);

  // �������� ����� ��������
  Text := ListBox.Items[Index];

  // �������� ������ �����������
  LogoIndex := GetLogoIndexForItem(Index);

  // ��������� ������������ �������
  if (LogoIndex >= 0) and (LogoIndex < ilLoad.Count) then
  begin
    // ������ ����������� � ��������� ��������
    ilLoad.Draw(
      Canvas,
      Rect.Left + 2,
      Rect.Top + 2,
      LogoIndex
    );
  end;

  // ����������� ��������� ������
  Canvas.Font := ListBox.Font;
  if odSelected in State then
    Canvas.Font.Color := clHighlightText
  else
    Canvas.Font.Color := clWindowText;

  // ������� ������������� ��� ������
  ItemRect := Rect;
  ItemRect.Left := ItemRect.Left + ilLoad.Width + 10;
  ItemRect.Top := ItemRect.Top + 2;

  // ��������� ����� �� ������
  Y := ItemRect.Top;
  while (Text <> '') and (Y < ItemRect.Bottom) do
  begin
    if Pos(#13#10, Text) > 0 then
    begin
      Canvas.TextOut(ItemRect.Left, Y, Copy(Text, 1, Pos(#13#10, Text) - 1));
      Y := Y + Canvas.TextHeight('Hg');
      Delete(Text, 1, Pos(#13#10, Text));
    end
    else
    begin
      Canvas.TextOut(ItemRect.Left, Y, Text);
      Break;
    end;
  end;
end;


procedure TfrmStickyForm.ParseM3U(const FileName: string);
var
  List: TStringList;
  i, j, ItemNumber: Integer;
  Line, Attributes, URL, ChannelName, Key, Value: string;
  Attrs: TStringList;
  Result: string;
  LogoURL: string;

  function CleanQuotes(const S: string): string;
  begin
    Result := S;
    if (Length(Result) > 0) and (Result[1] = '"') then
      Delete(Result, 1, 1);
    if (Length(Result) > 0) and (Result[Length(Result)] = '"') then
      Delete(Result, Length(Result), 1);
  end;

begin
  lbIPTVlist.Clear;
  ItemNumber := 1;

  List := TStringList.Create;
  try
    try
      List.LoadFromFile(FileName, TEncoding.UTF8);
    except on E: Exception do
      begin
        ShowMessage('������ �������� �����: ' + E.Message);
        Exit;
      end;
    end;

    for i := 0 to List.Count - 1 do
    begin
      Line := List[i];

      if Line = '#EXTM3U' then
        Continue;

      if Pos('#EXTINF', Line) = 1 then
      begin
        Delete(Line, 1, 8);
        Attributes := Copy(Line, 1, Pos(',', Line) - 1);
        ChannelName := Trim(Copy(Line, Pos(',', Line) + 1, Length(Line)));

        Attrs := TStringList.Create;
        try
          Attrs.Delimiter := ' ';
          Attrs.StrictDelimiter := True;
          Attrs.DelimitedText := Attributes;

          // ��������� ��������� ������
          Result := IntToStr(ItemNumber) + '. ' + ChannelName;
          LogoURL := '';

          // �������� ��������
          for j := 0 to Attrs.Count - 1 do
          begin
            if Pos('=', Attrs[j]) > 0 then
            begin
              Key := Trim(Copy(Attrs[j], 1, Pos('=', Attrs[j]) - 1));
              Value := Trim(Copy(Attrs[j], Pos('=', Attrs[j]) + 1, Length(Attrs[j])));
              Value := CleanQuotes(Value);

              if Key = 'tvg-logo' then
                LogoURL := Value
              else
                Result := Result + #13#10 +  Key + ': ' + Value;
            end;
          end;

          // ��������� URL
          if (i + 1 < List.Count) and (Pos('#EXTINF', List[i + 1]) <> 1) then
          begin
            URL := List[i + 1];
            Result := Result + #13#10 + 'URL: ' + URL;
          end;

          // ��������� ������� � ListBox
          lbIPTVlist.Items.Add(Result);

          // ��������� URL �������� ��� ����������� �������������
          // (����� �������� ����������� ����� ImageList)
          // ��������� ImageList ��� ������ 70x70
          ilLoad.Width :=  70;
          ilLoad.Height := 70;
          ilLoad.ColorDepth := cd32Bit;

          // �������� �����������
          LoadPNGToImageList(path+'IPTV_Plugin\image\No.png');

           // ��������� ListBox
          lbIPTVlist.Style := lbOwnerDrawFixed;
          lbIPTVlist.ItemHeight := ilLoad.Height + 10;

          Inc(ItemNumber);
        finally
          Attrs.Free;
        end;
      end
      else
      begin
        // ���������� �������� ������
      end;
    end;

  finally
    List.Free;
  end;
end;




procedure TfrmStickyForm.sbFullScreenClick(Sender: TObject);
var
  aFullScreenForm : TFullScreenForm;
  oldL, oldT, oldW, oldH : Integer;
  oldA: TAlign;
begin
  oldL := VLC_Player.Left;
  oldT := VLC_Player.Top;
  oldW := VLC_Player.Width;
  oldH := VLC_Player.Height;
  oldA := VLC_Player.Align;

  if (oldA <> alNone) then VLC_Player.Align := alNone;

  aFullScreenForm := TFullScreenForm.Create(SELF);
  aFullScreenForm.SetBounds(Monitor.Left, Monitor.Top, Monitor.Width, Monitor.Height);

  {  sPanel1.Parent := aFullScreenForm.sPan;
  sPanel1.Align:= alBottom;     }

  // PasLibVlcPlayer1.ParentWindow := aFullScreenForm.Handle;
  {$IFDEF FPC}
    LCLIntf.SetParent(VLC_Player.Handle, aFullScreenForm.Handle);
  {$ELSE}
    {$IFDEF MSWINDOWS}
      Windows.SetParent(VLC_Player.Handle, aFullScreenForm.Handle);
    {$ENDIF}
  {$ENDIF}
  VLC_Player.SetBounds(0, 0, Monitor.Width, Monitor.Height);

  aFullScreenForm.ShowModal;

  VLC_Player.SetBounds(oldL, oldT, oldW, oldH);
  {$IFDEF FPC}
    LCLIntf.SetParent(VLC_Player.Handle, SELF.Handle);
  {$ELSE}
    {$IFDEF MSWINDOWS}
      Windows.SetParent(VLC_Player.Handle, SELF.Handle);
    {$ENDIF}
  {$ENDIF}

  aFullScreenForm.Free;
end;

procedure TfrmStickyForm.sbNextClick(Sender: TObject);
begin
  with TDownloadThread.Create(Form1.edURLM3U.Text, Self) do
  begin
    Start;
  end;
end;

procedure TfrmStickyForm.sbOpenClick(Sender: TObject);
begin
  if odFile.Execute then
  begin
    ParseM3U(odFile.FileName);
    Form1.edURLM3U.Text := odFile.FileName;
  end;
end;

procedure TfrmStickyForm.SetParentChanHandle(const Value: HWND);
begin
  FParentChanHandle := Value;
end;

procedure TfrmStickyForm.SetParentChanName(const Value: WideString);
begin
  FParentChanName := Value;
end;





procedure TfrmStickyForm.tvVolumeChange(Sender: TObject);
begin
  VLC_Player.SetAudioVolume(tvVolume.Position);
//  sLabel2.Caption:='��������� ' + IntToStr(tvVolume.Position) + '%'
end;

procedure TfrmStickyForm.VLC_PlayerMediaPlayerPlaying(Sender: TObject);
begin
   VLC_Player.SetVideoAspectRatio('16:9');
end;

initialization

end.
