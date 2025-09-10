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
  IdSSLOpenSSL, RegularExpressions;
type
  TfrmStickyForm = class(TForm)
    PopupMenu1: TPopupMenu;
    C1: TMenuItem;
    N1: TMenuItem;
    PanelButton: TPanel;
    Splitter1: TSplitter;
    pnPlayer: TPanel;
    iLogo: TImage;
    VLC_Player: TPasLibVlcPlayer;
    sbBack: TSpeedButton;
    sbPlay: TSpeedButton;
    sbStop: TSpeedButton;
    sbNext: TSpeedButton;
    sbFullScreen: TSpeedButton;
    tvVolume: TTrackBar;
    lbIPTVlist: TListBox;
    sbOpen: TSpeedButton;
    ImageList1: TImageList;
    OpenDialog1: TOpenDialog;
    Memo1: TMemo;
    procedure C1Click(Sender: TObject);
    procedure lbIPTVlistDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure sbOpenClick(Sender: TObject);
    procedure sbNextClick(Sender: TObject);
  private
    FParentChanName: WideString;
    FParentChanHandle: HWND;
    procedure SetParentChanName(const Value: WideString);
    procedure SetParentChanHandle(const Value: HWND);
    { Private declarations }
    procedure ParseM3U(const FileName: string);
    function LoadPNGToImageList(const AFileName: string): Integer;
    function GetLogoIndexForItem(Index: Integer): Integer;
    procedure UpdateMemo(const Text: string);
  public
    property ParentChanName   : WideString read FParentChanName write SetParentChanName;
    property ParentChanHandle : HWND read FParentChanHandle write SetParentChanHandle;

    { Public declarations }
  end;

  TDownloadThread = class(TThread)
  private
    FFileName: string;
    FSSLIOHandler: TIdSSLIOHandlerSocketOpenSSL;
    FIdHTTP: TIdHTTP;
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


procedure InitializeSSL;
begin
  if not IdSSLOpenSSL.LoadOpenSSLLibrary then
//  begin
///  IdSSLOpenSSL.LoadOpenSSLLibrary('C:\Program Files (x86)\CommFort\Plugins\libeay32.dll');
//  IdSSLOpenSSL.LoadOpenSSLCryptoLibrary('C:\Program Files (x86)\CommFort\Plugins\ssleay32.dll');
//  end;
   raise Exception.Create('�� ������� ��������� ���������� OpenSSL');
end;


function ExtractTVGID(const Line: string): string;
var
  RegEx: TRegEx;
  Match: TMatch;
begin
  RegEx := TRegEx.Create('tvg-id="([^"]+)"');
  Match := RegEx.Match(Line);
  if Match.Success then
    Result := Match.Groups[1].Value
  else
    Result := '';
end;

constructor TDownloadThread.Create(const FileName: string; Form: TfrmStickyForm);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FFileName := FileName;
  FForm := Form;
end;

procedure TfrmStickyForm.UpdateMemo(const Text: string);
begin
  Memo1.Lines.Add(Text);
  Memo1.Update;
end;


destructor TDownloadThread.Destroy;
begin
  inherited;
end;

procedure TDownloadThread.Execute;
var
  I: Integer;
  Line, TVGID: String;
  FileName: String;
begin
  // ������������� SSL � HTTP �����������
  FSSLIOHandler := TIdSSLIOHandlerSocketOpenSSL.Create(nil);
  FSSLIOHandler.SSLOptions.SSLVersions := [sslvTLSv1_2]; // ����� �������� sslvTLSv1_3 ��� �������������
  FSSLIOHandler.ConnectTimeout := 10000;
  FSSLIOHandler.ReadTimeout := 10000;

  FIdHTTP := TIdHTTP.Create(nil);
  FIdHTTP.IOHandler := FSSLIOHandler;
  FIdHTTP.Request.UserAgent := 'Mozilla/5.0'; // ��������� ����������� User-Agent
  FIdHTTP.HandleRedirects := True; // ����� ��������� ���������������, ���� ��� �����������
  FIdHTTP.ReadTimeout := 10000;

  FStream := TMemoryStream.Create;
  FURLList := TStringList.Create;

  try
    // ��������� ������ URL �� �����
    if not FileExists(FFileName) then
    begin
      Synchronize(
        procedure
        begin
          ShowMessage('���� �� ������: ' + FFileName);
        end
      );
      Exit;
    end;

    FURLList.LoadFromFile(FFileName); // ������ ������ URL

    for I := 0 to FURLList.Count - 1 do
    begin
      Line := FURLList[I];
      if Pos('tvg-logo="', Line) > 0 then
      begin
        // ��������� URL ��������
        Delete(Line, 1, Pos('tvg-logo=', Line) + Length('tvg-logo='));
        Line := Trim(Copy(Line, 1, Pos('"', Line) - 1)); // �������� ����� ��������

        TVGID := ExtractTVGID(FURLList[I]); // ��������� ��-GUID
        if TVGID = '' then Continue; // ���������� ������ ��� TVGID

        // ��������� ��� �����
        FileName := Format('%s.png', [TVGID]);

        // ��������� ������������� �����
        if FileExists('C:\Delphi\Source\Save Image M3U\Win32\Debug\' + FileName) then
        begin
          Synchronize(
            procedure
            begin
              ShowMessage(Format('���� ��� ����������: %s', [FileName]));
            end
          );
          Continue;
        end;

        try
          FStream.Clear;
          FIdHTTP.Get(Line, FStream); // ����������� ��������

          if FStream.Size > 0 then
          begin
            FStream.Position := 0; // ������������� ������� ������ ������
            FStream.SaveToFile('C:\Delphi\Source\Save Image M3U\Win32\Debug\' + FileName); // ��������� ����
            Synchronize(
              procedure
              begin
                ShowMessage(Format('�������� ��������: %s', [TVGID]));
              end
            );
          end
          else
          begin
            Synchronize(
              procedure
              begin
                ShowMessage(Format('������ ����� �� ������� ���: %s', [TVGID]));
              end
            );
          end;
        except
          on E: EIdHTTPProtocolException do
          begin
            Synchronize(
              procedure
              begin
                ShowMessage(Format('�������� URL ��-�� ������ ���������: %s', [Line]));
              end
            );
            Continue;
          end;
          on E: Exception do
          begin
            Synchronize(
              procedure
              begin
                ShowMessage(Format('�������� URL ��-�� ������: %s', [E.Message]));
              end
            );
            Continue;
          end;
        end;
      end;
    end;
  finally
    FreeAndNil(FURLList);
    FreeAndNil(FStream);
    FreeAndNil(FIdHTTP);
    FreeAndNil(FSSLIOHandler);
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

      Result := ImageList1.Add(BMP, nil);
    finally
      BMP.Free;
    end;
  finally
    PNG.Free;
  end;
end;


function TfrmStickyForm.GetLogoIndexForItem(Index: Integer): Integer;
begin
  // ����� ���� ������ ��������� �������
  // ��������:
  Result := Index mod ImageList1.Count; // ������� ������
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
  if not Assigned(ImageList1) then
  begin
    ShowMessage('ImageList �� ��������!');
    Exit;
  end;

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
  if (LogoIndex >= 0) and (LogoIndex < ImageList1.Count) then
  begin
    // ������ ����������� � ��������� ��������
    ImageList1.Draw(
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
  ItemRect.Left := ItemRect.Left + ImageList1.Width + 10;
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
          ImageList1.Width :=  70;
          ImageList1.Height := 70;
          ImageList1.ColorDepth := cd32Bit;

          // �������� �����������
          LoadPNGToImageList('C:\Program Files (x86)\CommFort\Plugins\VLC\image\No.png');

           // ��������� ListBox
          lbIPTVlist.Style := lbOwnerDrawFixed;
          lbIPTVlist.ItemHeight := ImageList1.Height + 10;

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




procedure TfrmStickyForm.sbNextClick(Sender: TObject);
begin
  with TDownloadThread.Create(Form1.edURLM3U.Text, Self) do
  begin
    Start;
  end;
end;

procedure TfrmStickyForm.sbOpenClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
    ParseM3U(OpenDialog1.FileName);
end;

procedure TfrmStickyForm.SetParentChanHandle(const Value: HWND);
begin
  FParentChanHandle := Value;
end;

procedure TfrmStickyForm.SetParentChanName(const Value: WideString);
begin
  FParentChanName := Value;
end;





initialization

end.
