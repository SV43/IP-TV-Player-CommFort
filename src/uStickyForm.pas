unit uStickyForm;

interface

uses
 Windows, Classes, SysUtils, System.StrUtils, Dialogs, Messages, uFunc,
  Variants,  Controls, Forms, Vcl.StdCtrls, Vcl.Buttons, Vcl.XPMan,
  Vcl.ComCtrls,  PasLibVlcUnit, Vcl.ExtCtrls, System.Win.Registry,
  System.Win.ScktComp, Vcl.Menus,Vcl.Graphics, PNGImage,
  Vcl.ExtDlgs,  System.Generics.Collections, System.IOUtils,
  IdBaseComponent, IdComponent, IdTCPConnection,System.Threading,
  IdTCPClient, IdHTTP, System.ImageList, PasLibVlcPlayerUnit, Vcl.ImgList,
  IdSSLOpenSSL, RegularExpressions, System.Net.HttpClientComponent, System.Math,
  uImageTrackBar;

type
  TChannelInfo = record
    Name: string;
    TVGID: string;
    LogoURL: string;
    StreamURL: string;
end;


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
    lbChannels: TListBox;
    sbOpen: TSpeedButton;
    ilLogos: TImageList;
    odFile: TOpenDialog;
    lbStatus: TLabel;
    tStatus: TTimer;
    sbVolume: TSpeedButton;
    tvVolume: TImageTrackBar;



    procedure C1Click(Sender: TObject);
    procedure sbOpenClick(Sender: TObject);
    procedure sbNextClick(Sender: TObject);
    procedure sbBackClick(Sender: TObject);
    procedure sbStopClick(Sender: TObject);
    procedure tvVolumeChange(Sender: TObject);
    procedure tStatusTimer(Sender: TObject);
    procedure sbFullScreenClick(Sender: TObject);
    procedure lbChannelsDblClick(Sender: TObject);
    procedure N1Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure lbChannelsDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure sbPlayClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure ImageTrackBar1Change(Sender: TObject);
  private
    FChannels: TList<TChannelInfo>;
    FLogoMap: TDictionary<string, Integer>; // ключ = LowerCase(LogoURL)
    FParentChanName: WideString;
    FParentChanHandle: HWND;
    FCacheDir: string;
    FGeneration: Integer;
    procedure QueueDownloadLogo(const Channel: TChannelInfo);
    procedure AddImageFromFileToImageList(const AFileName, ALowerLogo: string);
    function GetLogoIndexForLogoURL(const ALogoURL: string): Integer;
    function MakeLogoFileName(const Channel: TChannelInfo): string;
    procedure ResetImageListToNoLogo;
    function IsValidPNG(const MS: TMemoryStream): Boolean;


    procedure SetParentChanName(const Value: WideString);
    procedure SetParentChanHandle(const Value: HWND);
    { Private declarations }
    procedure PlayChannelByIndex(AIndex: Integer);
  public
    property ParentChanName   : WideString read FParentChanName write SetParentChanName;
    property ParentChanHandle : HWND read FParentChanHandle write SetParentChanHandle;
    procedure ParseM3U(const FileName: string);

    { Public declarations }
  end;








{ TfrmStickyForm }
var
  frmStickyForm : TfrmStickyForm;
  ImageList: TImageList;





implementation

{$R *.dfm}

uses FullScreenFormUnit, uPlugin, Unit1;


procedure TfrmStickyForm.PlayChannelByIndex(AIndex: Integer);
var
  Channel: TChannelInfo;
begin
  if (FChannels = nil) or (AIndex < 0) or (AIndex >= FChannels.Count) then
  begin
    lbStatus.Caption := 'Неправильный индекс канала';
    Exit;
  end;

  Channel := FChannels[AIndex];

  if Channel.StreamURL = '' then
  begin
    lbStatus.Caption := 'URL не найден';
    Exit;
  end;

  // Обновляем статус и запускаем поток через VLC
  lbStatus.Caption := Channel.StreamURL;

  try
    // если у тебя есть путь к VLC в настройках, можно установить его:
    VLC_Player.VLC.Path := Form1.dePachVLC.Text;
    VLC_Player.Play(Channel.StreamURL);
  except
    on E: Exception do
      lbStatus.Caption := 'Ошибка воспроизведения: ' + E.Message;
  end;
end;


{ ------------------ Helpers ------------------ }

function TfrmStickyForm.MakeLogoFileName(const Channel: TChannelInfo): string;
var
  base: string;
begin
  if Channel.TVGID <> '' then
    base := Channel.TVGID
  else if Channel.Name <> '' then
    base := Channel.Name
  else
    base := 'channel';

  base := StringReplace(base, ' ', '_', [rfReplaceAll]);
  base := StringReplace(base, '/', '_', [rfReplaceAll]);
  base := StringReplace(base, '\', '_', [rfReplaceAll]);
  base := StringReplace(base, ':', '_', [rfReplaceAll]);
  base := StringReplace(base, '?', '_', [rfReplaceAll]);
  base := StringReplace(base, '&', '_', [rfReplaceAll]);
  base := StringReplace(base, '"', '_', [rfReplaceAll]);

  Result := base + '.png';
end;

procedure TfrmStickyForm.ImageTrackBar1Change(Sender: TObject);
begin
   VLC_Player.SetAudioVolume(tvVolume.Position);
   lbStatus.Caption:= 'Громкость ' + IntToStr(tvVolume.Position) + '%';

end;

function TfrmStickyForm.IsValidPNG(const MS: TMemoryStream): Boolean;
const
  PNG_SIG: array[0..7] of Byte = ($89, $50, $4E, $47, $0D, $0A, $1A, $0A);
var
  buf: array[0..7] of Byte;
begin
  Result := False;
  if MS.Size < 8 then Exit;

  MS.Position := 0;
  MS.ReadBuffer(buf, SizeOf(buf));
  MS.Position := 0;

  Result := CompareMem(@buf, @PNG_SIG, SizeOf(buf));
end;

procedure TfrmStickyForm.AddImageFromFileToImageList(const AFileName, ALowerLogo: string);
var
  PNG: TPngImage;
  BMP: TBitmap;
  idx: Integer;
begin
  if (ALowerLogo = '') or (not FileExists(AFileName)) then Exit;

  if FLogoMap.TryGetValue(ALowerLogo, idx) then Exit;

  try
    PNG := TPngImage.Create;
    try
      PNG.LoadFromFile(AFileName);
      BMP := TBitmap.Create;
      try
        BMP.SetSize(ilLogos.Width, ilLogos.Height);
        BMP.PixelFormat := pf32bit;
        BMP.AlphaFormat := afDefined;
        BMP.Canvas.StretchDraw(Rect(0, 0, ilLogos.Width - 1, ilLogos.Height - 1), PNG);

        if not FLogoMap.ContainsKey(ALowerLogo) then
        begin
          idx := ilLogos.Add(BMP, nil);
          FLogoMap.AddOrSetValue(ALowerLogo, idx);
        end;
      finally
        BMP.Free;
      end;
    finally
      PNG.Free;
    end;
  except
    // ignore
  end;
end;

procedure TfrmStickyForm.QueueDownloadLogo(const Channel: TChannelInfo);
var
  LowerLogo, DestPath: string;
  localGen: Integer;
begin
  if Channel.LogoURL = '' then Exit;
  LowerLogo := AnsiLowerCase(Channel.LogoURL);

  if FLogoMap.ContainsKey(LowerLogo) then Exit;

  DestPath := TPath.Combine(FCacheDir, MakeLogoFileName(Channel));

  if FileExists(DestPath) then
  begin
    TThread.Queue(nil,
      procedure
      begin
        AddImageFromFileToImageList(DestPath, LowerLogo);
        lbChannels.Invalidate;
      end);
    Exit;
  end;

  localGen := FGeneration;

  TTask.Run(
    procedure
    var
      HttpClient: TNetHTTPClient;
      MS: TMemoryStream;
    begin
      try
        HttpClient := TNetHTTPClient.Create(nil);
        MS := TMemoryStream.Create;
        try
          try
            HttpClient.Get(Channel.LogoURL, MS);
            if (MS.Size > 0) and IsValidPNG(MS) then
            begin
              try
                MS.SaveToFile(DestPath);
              except
              end;

              TThread.Queue(nil,
                procedure
                begin
                  if localGen <> FGeneration then Exit;
                  AddImageFromFileToImageList(DestPath, LowerLogo);
                  lbChannels.Invalidate;
                end);
            end;
          except
          end;
        finally
          MS.Free;
          HttpClient.Free;
        end;
      except
      end;
    end);
end;


procedure TfrmStickyForm.ParseM3U(const FileName: string);
var
  SL: TStringList;
  i: Integer;
  Line, TVGID, LogoURL, Name, StreamURL: string;
  Info: TChannelInfo;
  m: TMatch;
begin
  Inc(FGeneration);
  FLogoMap.Clear;
  ResetImageListToNoLogo;

  lbChannels.Items.BeginUpdate;
  try
    lbChannels.Clear;
    FChannels.Clear;

    SL := TStringList.Create;
    try
      SL.LoadFromFile(FileName, TEncoding.UTF8);
      i := 0;
      while i < SL.Count do
      begin
        Line := Trim(SL[i]);

        if Line.StartsWith('#EXTINF', True) then
        begin
          m := TRegEx.Match(Line, 'tvg-id\s*=\s*"(.*?)"', [roIgnoreCase]);
          if m.Success then TVGID := m.Groups[1].Value else TVGID := '';

          m := TRegEx.Match(Line, 'tvg-logo\s*=\s*"(.*?)"', [roIgnoreCase]);
          if m.Success then LogoURL := m.Groups[1].Value else LogoURL := '';

          if Pos(',', Line) > 0 then
            Name := Trim(Copy(Line, Pos(',', Line) + 1, MaxInt))
          else
            Name := '';

          StreamURL := '';
          if (i + 1 < SL.Count) and (not SL[i + 1].StartsWith('#')) then
          begin
            StreamURL := Trim(SL[i + 1]);
            Inc(i);
          end;

          Info.Name := Name;
          Info.TVGID := TVGID;
          Info.LogoURL := LogoURL;
          Info.StreamURL := StreamURL;

          FChannels.Add(Info);
          lbChannels.Items.Add(Info.Name);

          if LogoURL <> '' then
            QueueDownloadLogo(Info);
        end;

        Inc(i);
      end;
    finally
      SL.Free;
    end;
  finally
    lbChannels.Items.EndUpdate;
    lbChannels.Invalidate;
  end;
end;

function TfrmStickyForm.GetLogoIndexForLogoURL(const ALogoURL: string): Integer;
var
  idx: Integer;
  key: string;
begin
  Result := 0;
  if (ALogoURL = '') or (FLogoMap = nil) then Exit;
  key := AnsiLowerCase(ALogoURL);
  if FLogoMap.TryGetValue(key, idx) then
    Result := idx;
end;

procedure TfrmStickyForm.ResetImageListToNoLogo;
var
  NoLogoPath: string;
  PNG: TPngImage;
  BMP: TBitmap;
begin
  if ilLogos <> nil then
    ilLogos.Clear;

  NoLogoPath := Form1.lePachStyle.Text + 'logo-channels\NoLogo.png';

  BMP := TBitmap.Create;
  try
    BMP.SetSize(ilLogos.Width, ilLogos.Height);
    BMP.PixelFormat := pf32bit;
    BMP.AlphaFormat := afDefined;
    if FileExists(NoLogoPath) then
    begin
      PNG := TPngImage.Create;
      try
        PNG.LoadFromFile(NoLogoPath);
        BMP.Canvas.StretchDraw(Rect(0, 0, ilLogos.Width - 1, ilLogos.Height - 1), PNG);
      finally
        PNG.Free;
      end;
    end
    else
    begin
      BMP.Canvas.Brush.Color := clGray;
      BMP.Canvas.FillRect(Rect(0, 0, ilLogos.Width, ilLogos.Height));
      BMP.Canvas.Pen.Color := clRed;
      BMP.Canvas.MoveTo(0, 0); BMP.Canvas.LineTo(ilLogos.Width, ilLogos.Height);
      BMP.Canvas.MoveTo(0, ilLogos.Height); BMP.Canvas.LineTo(ilLogos.Width, 0);
    end;
    if ilLogos <> nil then
      ilLogos.Add(BMP, nil);
  finally
    BMP.Free;
  end;
end;





procedure LoadPNGToControl(const FileName: string; Control: TControl);
var
  PNG: TPngImage;
  Bmp: TBitmap;
  ImageList: TImageList;
  Index: Integer;
begin
  if not Assigned(Control) then
    raise Exception.Create('Компонент не определен');

  PNG := TPngImage.Create;
  try
    PNG.LoadFromFile(FileName);

    Bmp := TBitmap.Create;
    try
      Bmp.Width := Control.Width;
      Bmp.Height := Control.Height;

      Bmp.Canvas.Brush.Color := clWhite;
      Bmp.Canvas.FillRect(Rect(0, 0, Bmp.Width, Bmp.Height));

      // Расчет пропорций
      var ScaleX := Bmp.Width / PNG.Width;
      var ScaleY := Bmp.Height / PNG.Height;
      var Scale := Min(ScaleX, ScaleY);

      var NewWidth := Round(PNG.Width * Scale);
      var NewHeight := Round(PNG.Height * Scale);

      var X := (Bmp.Width - NewWidth) div 2;
      var Y := (Bmp.Height - NewHeight) div 2;

      Bmp.Canvas.StretchDraw(
        Rect(X, Y, X + NewWidth, Y + NewHeight),
        PNG
      );

      // Обработка разных типов компонентов
      if Control is TBitBtn then
      begin
        (Control as TBitBtn).Glyph.Assign(Bmp);
      end
      else if Control is TSpeedButton then
      begin
        (Control as TSpeedButton).Glyph.Assign(Bmp);
      end
      else if Control is TButton then
      begin
        // Создаем временный ImageList для TButton
        ImageList := TImageList.Create(nil);
        try
          ImageList.Width := Control.Width;
          ImageList.Height := Control.Height;
          Index := ImageList.Add(Bmp, nil);
          (Control as TButton).Images := ImageList;
          (Control as TButton).ImageIndex := Index;
        finally
          ImageList.Free;
        end;
      end;
    finally
      Bmp.Free;
    end;
  finally
    PNG.Free;
  end;
end;



procedure TfrmStickyForm.N1Click(Sender: TObject);
begin
  Form1.Show;
  GetChannels;
end;

procedure TfrmStickyForm.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FChannels);
  FreeAndNil(FLogoMap);
  try
    VLC_Player.Stop;
  except
    on E: Exception do
      lbStatus.Caption := 'Ошибка при очистке VLC: ' + E.Message;
  end;
end;


procedure TfrmStickyForm.FormShow(Sender: TObject);
var
  FButtonDir:String;
begin

    Randomize;
    FChannels := TList<TChannelInfo>.Create;
    FLogoMap := TDictionary<string, Integer>.Create;
    FGeneration := 0;

    ilLogos.Clear;
    ilLogos.Width := 50;
    ilLogos.Height := 50;

    ResetImageListToNoLogo;

    lbChannels.Style := lbOwnerDrawFixed;
    lbChannels.ItemHeight := Max(ilLogos.Height + 4, 48);


    FCacheDir := Form1.lePachStyle.Text + 'logo-channels\';
    FButtonDir := Form1.lePachStyle.Text + 'image-button\';

    ForceDirectories(FCacheDir);
    //Сделать проверку на существование файла
    if not FileExists(Form1.edURLM3U.Text) then
      else
    ParseM3U(Form1.edURLM3U.Text);

    if not DirectoryExists(FCacheDir) then
       ShowMessage('Создайте папку для кэша картинок "logo-channels"');

   if not DirectoryExists(FCacheDir) then
      ShowMessage('Не найдена папка с иконками для кнопок "image-button"')
    else
   begin
    LoadPNGToControl(FButtonDir + 'backward.png', sbBack);
    LoadPNGToControl(FButtonDir + 'screen-full.png', sbFullScreen);
    LoadPNGToControl(FButtonDir + 'forwards.png', sbNext);
    LoadPNGToControl(FButtonDir + 'film-list.png', sbOpen);
    LoadPNGToControl(FButtonDir + 'play.png', sbPlay);
    LoadPNGToControl(FButtonDir + 'stop-playing.png', sbStop);
    LoadPNGToControl(FButtonDir + 'volume-mute.png', sbVolume);

    tvVolume.TrackFile := FButtonDir + 'track.png';
    tvVolume.ThumbFile := FButtonDir + 'thumb-48.png';
   end;

end;

procedure TfrmStickyForm.C1Click(Sender: TObject);
begin
 if lbChannels.Visible = True then
 begin
   lbChannels.Visible := False;
   Splitter1.Visible := False;
 end else
 begin
   lbChannels.Visible := True;
   Splitter1.Visible := True;
 end;
end;





procedure TfrmStickyForm.lbChannelsDblClick(Sender: TObject);
var
  idx: Integer;
begin
  idx := lbChannels.ItemIndex;
  if (idx >= 0) and (idx < FChannels.Count) then
    PlayChannelByIndex(idx);
end;

procedure TfrmStickyForm.lbChannelsDrawItem(Control: TWinControl;
  Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  Canvas: TCanvas;
  Info: TChannelInfo;
  LogoIndex: Integer;
begin
  Canvas := (Control as TListBox).Canvas;
  Canvas.FillRect(Rect);

  if (FChannels = nil) or (Index < 0) or (Index >= FChannels.Count) then
    Exit;

  Info := FChannels[Index];
  LogoIndex := GetLogoIndexForLogoURL(Info.LogoURL);

  if (ilLogos <> nil) and (LogoIndex >= 0) and (LogoIndex < ilLogos.Count) then
    ilLogos.Draw(Canvas, Rect.Left + 2, Rect.Top + 2, LogoIndex)
  else if (ilLogos <> nil) and (ilLogos.Count > 0) then
    ilLogos.Draw(Canvas, Rect.Left + 2, Rect.Top + 2, 0); // NoLogo

  Canvas.TextOut(
    Rect.Left + ilLogos.Width + 8,
    Rect.Top + (Rect.Height - Canvas.TextHeight(Info.Name)) div 2,
    Info.Name
  );
end;

procedure TfrmStickyForm.sbBackClick(Sender: TObject);
var
  idx: Integer;
begin
  if (FChannels = nil) or (FChannels.Count = 0) then
  begin
    lbStatus.Caption := 'Список каналов пуст';
    Exit;
  end;

  idx := lbChannels.ItemIndex;

  // если ничего не выбрано — стартуем с последнего
  if idx < 0 then
    idx := FChannels.Count - 1
  else
  begin
    Dec(idx); // шаг назад
    if idx < 0 then
      idx := FChannels.Count - 1; // зацикливаем в конец
  end;

  lbChannels.ItemIndex := idx;
  PlayChannelByIndex(idx);
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
var
  idx: Integer;
begin
  if (FChannels = nil) or (FChannels.Count = 0) then
  begin
    lbStatus.Caption := 'Список каналов пуст';
    Exit;
  end;

  idx := lbChannels.ItemIndex;

  // если ничего не выбрано — стартуем с первого
  if idx < 0 then
    idx := 0
  else
  begin
    Inc(idx); // шаг вперёд
    if idx >= FChannels.Count then
      idx := 0; // зацикливаем в начало
  end;

  lbChannels.ItemIndex := idx;
  PlayChannelByIndex(idx);
end;

procedure TfrmStickyForm.sbOpenClick(Sender: TObject);
begin
  odFile.Filter := 'M3U playlist (*.m3u)|*.m3u|All files (*.*)|*.*';
  if odFile.Execute then
  begin
    ParseM3U(odFile.FileName);
    Form1.edURLM3U.Text := odFile.FileName;
  end;
end;

procedure TfrmStickyForm.sbPlayClick(Sender: TObject);
var
  idx: Integer;
begin
  idx := lbChannels.ItemIndex;

  // если ничего не выбрано, пробуем выбрать первый
  if (idx < 0) and (FChannels <> nil) and (FChannels.Count > 0) then
  begin
    idx := 0;
    lbChannels.ItemIndex := idx;
  end;

  if (idx >= 0) and (idx < FChannels.Count) then
    PlayChannelByIndex(idx)
  else
    lbStatus.Caption := 'Список каналов пуст';
end;

procedure TfrmStickyForm.sbStopClick(Sender: TObject);
begin
   VLC_Player.Stop();
end;

procedure TfrmStickyForm.SetParentChanHandle(const Value: HWND);
begin
  FParentChanHandle := Value;
end;

procedure TfrmStickyForm.SetParentChanName(const Value: WideString);
begin
  FParentChanName := Value;
end;





procedure TfrmStickyForm.tStatusTimer(Sender: TObject);
var
  stateName: string;
begin

  case VLC_Player.GetState() of
    plvPlayer_NothingSpecial: stateName := '';
    plvPlayer_Opening:        stateName := 'Открытие потока';
    plvPlayer_Buffering:      stateName := 'Буфирация';
//    plvPlayer_Playing:        stateName :=  TVProgramm;
    plvPlayer_Paused:         stateName := 'Пауза';
    plvPlayer_Stopped:        stateName := 'Остановлено';
    plvPlayer_Ended:          stateName := '';
    plvPlayer_Error:          stateName := 'Ошибка загрузки потока';
    else                      stateName := '';
  end;

  if stateName = '' then
   else
     lbStatus.caption:=(stateName);

end;

procedure TfrmStickyForm.tvVolumeChange(Sender: TObject);
begin
  VLC_Player.SetAudioVolume(tvVolume.Position);
  lbStatus.Caption := 'Громкость ' + IntToStr(tvVolume.Position) + '%'
end;

initialization

end.
