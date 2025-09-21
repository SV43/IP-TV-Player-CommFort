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
  uImageTrackBar, uSettings, FullScreenFormUnit,
  // added for EPG
  XmlIntf, XmlDoc, DateUtils, System.Net.HttpClient;

type
  TChannelInfo = record
    Name: string;
    TVGID: string;
    LogoURL: string;
    StreamURL: string;
    // EPG fields
    CurrentTitle: string;
    CurrentStart: TDateTime;
    CurrentStop: TDateTime;
end;


type
  TfrmStickyForm = class(TForm)
    pmMenu: TPopupMenu;
    C1: TMenuItem;
    N1: TMenuItem;
    PanelButton: TPanel;
    Splitter: TSplitter;
    pnPlayer: TPanel;
    sbBack: TSpeedButton;
    sbPlay: TSpeedButton;
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
    VLC_Player: TPasLibVlcPlayer;



    procedure C1Click(Sender: TObject);
    procedure sbOpenClick(Sender: TObject);
    procedure sbNextClick(Sender: TObject);
    procedure sbBackClick(Sender: TObject);
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
    procedure OnBuffering(Sender: TObject; cache: Single);
    procedure OnError(Sender: TObject);
    procedure VLC_PlayerMediaPlayerPlaying(Sender: TObject);
    procedure OnPlaying(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure sbVolumeClick(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure VLC_PlayerDblClick(Sender: TObject);
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
    procedure EPGTimerHandler(Sender: TObject);

    procedure SetParentChanName(const Value: WideString);
    procedure SetParentChanHandle(const Value: HWND);
    { Private declarations }
    procedure PlayChannelByIndex(AIndex: Integer);


    procedure LoadEPGUrlsFromM3ULine(const Line: string);
    procedure DownloadAndParseAllEPG;
    procedure DownloadAndParseEPG(const AUrl: string);
    procedure ParseEPGStream(const MS: TMemoryStream);
    function ParseXMLTVDate(const S: string): TDateTime;
    procedure ClearCurrentPrograms;
    procedure RefreshCurrentPrograms;
  public
    property ParentChanName   : WideString read FParentChanName write SetParentChanName;
    property ParentChanHandle : HWND read FParentChanHandle write SetParentChanHandle;
    procedure ParseM3U(const FileName: string);

    { Public declarations }
  end;








{ TfrmStickyForm }
var
  frmStickyForm: TfrmStickyForm;
  ImageList: TImageList;
  FButtonDir: string;
  IsFullScreen: Boolean;
  FEpgUrls: TStringList;
  FEPGTimer: TTimer;

implementation

{$R *.dfm}

uses uPlugin;

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
    VLC_Player.VLC.Path := frmSettings.dePachVLC.Text;
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

  if VLC_Player.GetAudioMute then
  begin
   LoadPNGToControl(FButtonDir + 'volume.png', sbVolume);
   VLC_Player.SetAudioMute(False);
  end;
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
  // local vars for EPG header scanning
  j: Integer;
  HeaderLine: string;
begin
  Inc(FGeneration);
  FLogoMap.Clear;
  ResetImageListToNoLogo;

  // prepare EPG urls list
  if FEpgUrls = nil then
    FEpgUrls := TStringList.Create;
  FEpgUrls.Clear;

  lbChannels.Items.BeginUpdate;
  try
    lbChannels.Clear;
    FChannels.Clear;

    SL := TStringList.Create;
    try
      SL.LoadFromFile(FileName, TEncoding.UTF8);

      // ищем заголовок #EXTM3U и парсим url-tvg если есть
      for j := 0 to SL.Count - 1 do
      begin
        HeaderLine := Trim(SL[j]);
        if HeaderLine.StartsWith('#EXTM3U', True) then
        begin
          LoadEPGUrlsFromM3ULine(HeaderLine);
          Break;
        end;
      end;

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
          // init epg fields
          Info.CurrentTitle := '';
          Info.CurrentStart := 0;
          Info.CurrentStop := 0;

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
  if (ALogoURL = '') or (FLogoMap = nil) then
    Exit;

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

  NoLogoPath := frmSettings.lePachStyle.Text + 'logo-channels\NoLogo.png';

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







procedure TfrmStickyForm.OnPlaying(Sender: TObject);
begin
  lbStatus.Caption := '';
end;


procedure TfrmStickyForm.OnBuffering(Sender: TObject; cache: Single);
begin
  if Trunc(cache) < 100 then
    lbStatus.Caption := Format('Буферизация: %d%%', [Trunc(cache)])
  else
    lbStatus.Caption := 'Воспроизведение...';

end;

procedure TfrmStickyForm.OnError(Sender: TObject);
begin
  lbStatus.Caption := 'Ошибка воспроизведения!';
end;


procedure TfrmStickyForm.N1Click(Sender: TObject);
begin
  frmSettings.Show;
  GetChannels;
end;

procedure TfrmStickyForm.FormCreate(Sender: TObject);
begin
  VLC_Player.StartOptions.Add('--network-caching=300');
  VLC_Player.StartOptions.Add('--no-drop-late-frames');
  VLC_Player.StartOptions.Add('--no-skip-frames');
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


procedure TfrmStickyForm.FormPaint(Sender: TObject);
var
  state: TPasLibVlcPlayerState;
begin
  state := Vlc_Player.GetState;

  if state = plvPlayer_Playing then
      LoadPNGToControl(FButtonDir + 'stop-playing.png', sbPlay)
  else
    LoadPNGToControl(FButtonDir + 'play.png', sbPlay);

  if VLC_Player.GetAudioMute then
    LoadPNGToControl(FButtonDir + 'volume-mute.png', sbVolume)
  else
    LoadPNGToControl(FButtonDir + 'volume.png', sbVolume);
end;

procedure TfrmStickyForm.EPGTimerHandler(Sender: TObject);
begin
  TTask.Run(
    procedure
    begin
      DownloadAndParseAllEPG;
    end
  );
end;

procedure TfrmStickyForm.FormShow(Sender: TObject);
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


    FCacheDir := frmSettings.lePachStyle.Text + 'logo-channels\';
    FButtonDir := frmSettings.lePachStyle.Text + 'image-button\';
    VLC_Player.VLC.Path := frmSettings.dePachVLC.Text;

    ForceDirectories(FCacheDir);
    //Сделать проверку на существование файла
    if not FileExists(frmSettings.edURLM3U.Text) then
      else
    ParseM3U(frmSettings.edURLM3U.Text);

    // start EPG structures & load
if FEpgUrls = nil then
  FEpgUrls := TStringList.Create;

if FEPGTimer = nil then
begin
  FEPGTimer := TTimer.Create(Self);
  FEPGTimer.Interval := 15 * 60 * 1000; // 15 минут
  FEPGTimer.OnTimer := EPGTimerHandler; // <-- используем метод формы
  FEPGTimer.Enabled := True;
end;

// старт парсинга EPG в фоне
TTask.Run(
  procedure
  begin
    DownloadAndParseAllEPG;
  end
);

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
    LoadPNGToControl(FButtonDir + 'volume.png', sbVolume);

    tvVolume.TrackFile := FButtonDir + 'track.png';
    tvVolume.ThumbFile := FButtonDir + 'thumb-48.png';
   end;

  VLC_Player.OnMediaPlayerBuffering := OnBuffering;
  VLC_Player.OnMediaPlayerEncounteredError := OnError;
  VLC_Player.OnMediaPlayerPlaying := OnPlaying;
  IsFullScreen := False;
end;

procedure TfrmStickyForm.C1Click(Sender: TObject);
begin
 if lbChannels.Visible = True then
 begin
   lbChannels.Visible := False;
   Splitter.Visible := False;
 end else
 begin
   lbChannels.Visible := True;
   Splitter.Visible := True;
 end;
end;

procedure TfrmStickyForm.lbChannelsDblClick(Sender: TObject);
var
  idx: Integer;
  state: TPasLibVlcPlayerState;
begin
  state := Vlc_Player.GetState;

  if state = plvPlayer_Playing then
  begin
    // ⏹ Если уже играет — останавливаем
    VLC_Player.Stop;

    LoadPNGToControl(FButtonDir + 'play.png', sbPlay);
    lbStatus.Caption := 'Остановлено';
  end
  else
  begin
    // ▶️ Иначе запускаем
    idx := lbChannels.ItemIndex;

    if (idx < 0) and (FChannels <> nil) and (FChannels.Count > 0) then
    begin
      idx := 0;
      lbChannels.ItemIndex := idx;
    end;

    if (idx >= 0) and (idx < FChannels.Count) then
    begin
      PlayChannelByIndex(idx);
      LoadPNGToControl(FButtonDir + 'stop-playing.png', sbPlay);
      lbStatus.Caption := 'Воспроизведение...';
    end
    else
      lbStatus.Caption := 'Список каналов пуст';
  end;
end;

procedure TfrmStickyForm.lbChannelsDrawItem(Control: TWinControl; Index: Integer;
  Rect: TRect; State: TOwnerDrawState);
var
  nameLeft: Integer;
  ch: TChannelInfo;
  logoIdx: Integer;
  R: TRect;
  oldFontSize: Integer;
begin
  if (Index < 0) or (Index >= FChannels.Count) then Exit;

  ch := FChannels[Index];

  // фон элемента
  if odSelected in State then
    lbChannels.Canvas.Brush.Color := clHighlight
  else
    lbChannels.Canvas.Brush.Color := lbChannels.Color;

  lbChannels.Canvas.FillRect(Rect);

  // логотип
  logoIdx := GetLogoIndexForLogoURL(ch.LogoURL);
  ilLogos.Draw(lbChannels.Canvas, Rect.Left + 2, Rect.Top + 2, logoIdx);

  // отступ для текста
  nameLeft := Rect.Left + ilLogos.Width + 8;

  // название канала
  lbChannels.Canvas.Font.Color := clWindowText;
  lbChannels.Canvas.Font.Style := [fsBold];
  lbChannels.Canvas.TextOut(nameLeft, Rect.Top + 4, ch.Name);

  // текущая передача (если есть)
  if (ch.CurrentTitle <> '') then
  begin
    oldFontSize := lbChannels.Canvas.Font.Size;
    lbChannels.Canvas.Font.Size := oldFontSize - 2;
    lbChannels.Canvas.Font.Style := [];
    lbChannels.Canvas.Font.Color := clGrayText;

    R := Rect;
    R.Top := Rect.Top + 20;
    lbChannels.Canvas.TextOut(nameLeft, R.Top, ch.CurrentTitle);

    lbChannels.Canvas.Font.Size := oldFontSize; // вернуть размер
  end;
end;


{ ------------------ EPG implementation ------------------ }

procedure TfrmStickyForm.LoadEPGUrlsFromM3ULine(const Line: string);
var
  m: TMatch;
  urls, u: string;
  startPos, p: Integer;
begin
  if FEpgUrls = nil then
    FEpgUrls := TStringList.Create
  else
    FEpgUrls.Clear;

  m := TRegEx.Match(Line, 'url-tvg\s*=\s*"(.*?)"', [roIgnoreCase]);
  if not m.Success then
    Exit;

  urls := m.Groups[1].Value;
  startPos := 1;

  // Простая функция разделения по запятой (без использования WordCount/ExtractWord)
  for p := 1 to Length(urls) do
  begin
    if urls[p] = ',' then
    begin
      u := Trim(Copy(urls, startPos, p - startPos));
      if (u <> '') and (FEpgUrls.IndexOf(u) = -1) then
        FEpgUrls.Add(u);
      startPos := p + 1;
    end;
  end;

  // последний элемент (после последней запятой)
  if startPos <= Length(urls) then
  begin
    u := Trim(Copy(urls, startPos, MaxInt));
    if (u <> '') and (FEpgUrls.IndexOf(u) = -1) then
      FEpgUrls.Add(u);
  end;
end;

procedure TfrmStickyForm.DownloadAndParseAllEPG;
var
  i: Integer;
begin
  ClearCurrentPrograms;

  if (FEpgUrls = nil) or (FEpgUrls.Count = 0) then Exit;

  for i := 0 to FEpgUrls.Count - 1 do
  begin
    try
      DownloadAndParseEPG(FEpgUrls[i]);
    except
      // ignore
    end;
  end;

  TThread.Queue(nil, procedure begin RefreshCurrentPrograms; end);
end;

procedure TfrmStickyForm.DownloadAndParseEPG(const AUrl: string);
var
  HttpClient: TNetHTTPClient;
  MS: TMemoryStream;
begin
  HttpClient := TNetHTTPClient.Create(nil);
  MS := TMemoryStream.Create;
  try
    try
      HttpClient.Get(AUrl, MS);
      if MS.Size > 0 then
      begin
        MS.Position := 0;
        ParseEPGStream(MS);
      end;
    except
      // ignore download error
    end;
  finally
    MS.Free;
    HttpClient.Free;
  end;
end;

procedure TfrmStickyForm.ParseEPGStream(const MS: TMemoryStream);
var
  Doc: IXMLDocument;
  root, node, child: IXMLNode;
  i, j, idx: Integer;
  chId, startS, stopS, title: string;
  progStart, progStop: TDateTime;
  nowDT: TDateTime;
  ch: TChannelInfo;
begin
  try
    MS.Position := 0;
    Doc := TXMLDocument.Create(nil);
    Doc.LoadFromStream(MS);
    Doc.Active := True;
    root := Doc.DocumentElement;
    if root = nil then Exit;

    nowDT := Now;

    for i := 0 to root.ChildNodes.Count - 1 do
    begin
      node := root.ChildNodes[i];
      if SameText(node.NodeName, 'programme') then
      begin
        chId := VarToStr(node.Attributes['channel']);
        startS := VarToStr(node.Attributes['start']);
        stopS := VarToStr(node.Attributes['stop']);
        title := '';
        for j := 0 to node.ChildNodes.Count - 1 do
        begin
          child := node.ChildNodes[j];
          if SameText(child.NodeName, 'title') then
            title := child.Text;
        end;

        progStart := ParseXMLTVDate(startS);
        progStop := ParseXMLTVDate(stopS);
        if (progStart > 0) and (progStop > progStart) and (progStart <= nowDT) and (progStop > nowDT) then
        begin
          for idx := 0 to FChannels.Count - 1 do
          begin
            ch := FChannels[idx];
            if ((ch.TVGID <> '') and SameText(ch.TVGID, chId)) or ((ch.TVGID = '') and (ch.Name <> '') and SameText(ch.Name, chId)) then
            begin
              ch.CurrentTitle := title;
              ch.CurrentStart := progStart;
              ch.CurrentStop := progStop;
              FChannels[idx] := ch;
            end;
          end;
        end;
      end;
    end;
  except
    // ignore parse errors
  end;
end;

function TfrmStickyForm.ParseXMLTVDate(const S: string): TDateTime;
var
  sDate, tz: string;
  y, m, d, hh, nn, ss, tzSign, tzH, tzM: Integer;
begin
  Result := 0;
  if S = '' then Exit;

  if S.EndsWith('Z') then
  begin
    sDate := Copy(S, 1, Length(S)-1);
    tz := '+0000';
  end
  else if Length(S) > 14 then
  begin
    sDate := Copy(S, 1, 14);
    tz := Trim(Copy(S, 15, MaxInt));
    tz := StringReplace(tz, ':', '', [rfReplaceAll]);
    if tz = '' then tz := '+0000';
  end
  else
  begin
    sDate := S;
    tz := '+0000';
  end;

  if Length(sDate) < 14 then Exit;

  try
    y := StrToIntDef(Copy(sDate,1,4),0);
    m := StrToIntDef(Copy(sDate,5,2),0);
    d := StrToIntDef(Copy(sDate,7,2),0);
    hh := StrToIntDef(Copy(sDate,9,2),0);
    nn := StrToIntDef(Copy(sDate,11,2),0);
    ss := StrToIntDef(Copy(sDate,13,2),0);

    Result := EncodeDate(y,m,d) + EncodeTime(hh,nn,ss,0);

    if (tz <> '') and ((tz[1] = '+') or (tz[1] = '-')) and (Length(tz) >= 5) then
    begin
      tzSign := 1;
      if tz[1] = '-' then tzSign := -1;
      tzH := StrToIntDef(Copy(tz,2,2),0);
      tzM := StrToIntDef(Copy(tz,4,2),0);
      Result := Result - tzSign * (tzH / 24 + tzM / 1440);
    end;

    Result := TTimeZone.Local.ToLocalTime(Result);
  except
    Result := 0;
  end;
end;

procedure TfrmStickyForm.ClearCurrentPrograms;
var
  i: Integer;
  ch: TChannelInfo;
begin
  if FChannels = nil then Exit;
  for i := 0 to FChannels.Count - 1 do
  begin
    ch := FChannels[i];
    ch.CurrentTitle := '';
    ch.CurrentStart := 0;
    ch.CurrentStop := 0;
    FChannels[i] := ch;
  end;
end;

procedure TfrmStickyForm.RefreshCurrentPrograms;
begin
  lbChannels.Invalidate;
end;

procedure TfrmStickyForm.VLC_PlayerDblClick(Sender: TObject);
begin
  sbFullScreenClick(Self);
end;

procedure TfrmStickyForm.sbOpenClick(Sender: TObject);
begin
  odFile.Filter := 'M3U playlist (*.m3u)|*.m3u|All files (*.*)|*.*';
  if odFile.Execute then
  begin
    ParseM3U(odFile.FileName);
    frmSettings.edURLM3U.Text := odFile.FileName;
  end;
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

procedure TfrmStickyForm.tvVolumeChange(Sender: TObject);
begin
  VLC_Player.SetAudioVolume(tvVolume.Position);
  lbStatus.Caption := 'Громкость ' + IntToStr(tvVolume.Position) + '%'
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


     lbStatus.caption:=(stateName);

end;

procedure TfrmStickyForm.sbFullScreenClick(Sender: TObject);
var
  aFullScreenForm : TFullScreenForm;
  oldL, oldT, oldW, oldH : Integer;
  oldA: TAlign;
begin
if not IsFullScreen then
begin
  oldL := VLC_Player.Left;
  oldT := VLC_Player.Top;
  oldW := VLC_Player.Width;
  oldH := VLC_Player.Height;
  oldA := VLC_Player.Align;

  if (oldA <> alNone) then
    VLC_Player.Align := alNone;

  aFullScreenForm := TFullScreenForm.Create(Self);
  aFullScreenForm.SetBounds(Monitor.Left, Monitor.Top, Monitor.Width, Monitor.Height);

  {$IFDEF FPC}
    LCLIntf.SetParent(VLC_Player.Handle, aFullScreenForm.Handle);
  {$ELSE}
    {$IFDEF MSWINDOWS}
      Windows.SetParent(VLC_Player.Handle, aFullScreenForm.Handle);
    {$ENDIF}
  {$ENDIF}

  VLC_Player.SetBounds(0, 0, Monitor.Width, Monitor.Height);

  IsFullScreen := True;
  aFullScreenForm.ShowModal;

  // выход из fullscreen
  VLC_Player.SetBounds(oldL, oldT, oldW, oldH);
  {$IFDEF FPC}
    LCLIntf.SetParent(VLC_Player.Handle, Self.Handle);
  {$ELSE}
    {$IFDEF MSWINDOWS}
      Windows.SetParent(VLC_Player.Handle, Self.Handle);
    {$ENDIF}
  {$ENDIF}

  IsFullScreen := False;
  aFullScreenForm.Free;
end;
end;

procedure TfrmStickyForm.sbPlayClick(Sender: TObject);
var
  idx: Integer;
  state: TPasLibVlcPlayerState;
begin
  state := Vlc_Player.GetState;

  if state = plvPlayer_Playing then
  begin
    // ⏹ Если уже играет — останавливаем
    VLC_Player.Stop;

    LoadPNGToControl(FButtonDir + 'play.png', sbPlay);
    lbStatus.Caption := 'Остановлено';
  end
  else
  begin
    // ▶️ Иначе запускаем
    idx := lbChannels.ItemIndex;

    if (idx < 0) and (FChannels <> nil) and (FChannels.Count > 0) then
    begin
      idx := 0;
      lbChannels.ItemIndex := idx;
    end;

    if (idx >= 0) and (idx < FChannels.Count) then
    begin
      PlayChannelByIndex(idx);
      LoadPNGToControl(FButtonDir + 'stop-playing.png', sbPlay);
      lbStatus.Caption := 'Воспроизведение...';
    end
    else
      lbStatus.Caption := 'Список каналов пуст';
  end;
    sbPlay.Invalidate;   // 🔄 форсируем перерисовку
    sbPlay.Update;
end;

procedure TfrmStickyForm.VLC_PlayerMediaPlayerPlaying(Sender: TObject);
begin
  lbStatus.Caption := '';
end;

procedure TfrmStickyForm.sbVolumeClick(Sender: TObject);
begin
  // Проверяем текущее состояние mute
  if VLC_Player.GetAudioMute then
  begin
    // 🔊 Если звук выключен → включаем
    VLC_Player.SetAudioMute(False);
    LoadPNGToControl(FButtonDir + 'volume.png', sbVolume);   // картинка громкости
    lbStatus.Caption := 'Звук включён';
  end
  else
  begin
    // 🔇 Если звук включен → выключаем
    VLC_Player.SetAudioMute(True);
    LoadPNGToControl(FButtonDir + 'volume-mute.png', sbVolume); // картинка mute
    lbStatus.Caption := 'Звук выключен';
  end;
    sbVolume.Invalidate;   // 🔄 форсируем перерисовку
    sbVolume.Update;
end;

procedure TfrmStickyForm.SetParentChanName(const Value: WideString);
begin
  FParentChanName := Value;
end;

procedure TfrmStickyForm.SetParentChanHandle(const Value: HWND);
begin
  FParentChanHandle := Value;
end;


initialization

end.

