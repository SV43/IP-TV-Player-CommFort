unit uStickyForm;

interface

uses
  Windows, Classes, SysUtils, System.StrUtils, Dialogs, Messages, uFunc,
  Variants, Controls, Forms, Vcl.StdCtrls, Vcl.Buttons, Vcl.XPMan,
  Vcl.ComCtrls, Vcl.ExtCtrls, System.Win.Registry,
  System.Win.ScktComp, Vcl.Menus, Vcl.Graphics, PNGImage,
  Vcl.ExtDlgs, System.Generics.Collections, System.IOUtils,
  IdBaseComponent, IdComponent, IdTCPConnection, System.Threading,
  IdTCPClient, IdHTTP, System.ImageList, Vcl.ImgList,
  IdSSLOpenSSL, RegularExpressions, System.Net.HttpClientComponent, System.Math,
  uImageTrackBar, uSettings, FullScreenFormUnit, System.ZLib, System.NetEncoding,
  DateUtils, System.Net.HttpClient, Xml.XMLDoc, xmldom, Xml.XMLIntf, Xml.adomxmldom,
  PasLibVlcUnit,  NativeXml, PasLibVlcPlayerUnit;
type
  TEPGItem = record
    Title: string;
    StartDT: TDateTime;
    StopDT: TDateTime;
  end;

  TChannelInfo = class
  public
    Name: string;
    TVGID: string;
    LogoURL: string;
    StreamURL: string;

    // EPG fields (history)
    CurrentTitle: string;
    CurrentStart: TDateTime;
    CurrentStop: TDateTime;

    EPG: TList<TEPGItem>;

    constructor Create;
    destructor Destroy; override;
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
    lbEPG_Text: TLabel;
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
    procedure OnPlaying(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure sbVolumeClick(Sender: TObject);
    procedure VLC_PlayerDblClick(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    FChannels: TList<TChannelInfo>;
    FLogoMap: TDictionary<string, Integer>; // ключ = LowerCase(LogoURL)
    FParentChanName: WideString;
    FParentChanHandle: HWND;
    FCacheDir: string;
    FGeneration: Integer;
    procedure QueueDownloadLogo(const Channel: TChannelInfo);
    function AddImageFromFileToImageList(const AFileName, AKey: string): Integer;
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

    // new: delayed EPG start timer
    procedure StartEPGTimerHandler(Sender: TObject);
    procedure DecompressGZip(const GZipFile, XmlFile: string);
    procedure UseDefaultLogo(const Channel: TChannelInfo);
    function GetLogoIndexForTVGID(const ATVGID: string): Integer;
    function ExtractCurrentProgram(const AText: string): string;
    procedure EpgStatus;
  public
    FStopRequested: Boolean;
    property ParentChanName: WideString read FParentChanName write SetParentChanName;
    property ParentChanHandle: HWND read FParentChanHandle write SetParentChanHandle;
    procedure ParseM3U(const FileName: string);
    { Public declarations }
  end;

var
  frmStickyForm: TfrmStickyForm;
  ImageList: TImageList;
  FButtonDir: string;
  IsFullScreen: Boolean;
  FEpgUrls: TStringList;
  FEPGTimer: TTimer;
  FEPGStartTimer: TTimer; // timer to delay EPG start

implementation

{$R *.dfm}

uses uPlugin;


constructor TChannelInfo.Create;
begin
  inherited;
  EPG := TList<TEPGItem>.Create;
end;

destructor TChannelInfo.Destroy;
begin
  EPG.Free;
  inherited;
end;

procedure WriteDebugLog(const Msg: string);
var
  LogFile: TextFile;
  LogPath: string;
begin
  try
    // пишем рядом с остальными данными (папка из настроек)
    LogPath := path + 'IPTV_Plugin\debug.log';
    AssignFile(LogFile, LogPath);
    if FileExists(LogPath) then
      Append(LogFile)
    else
      Rewrite(LogFile);
    Writeln(LogFile, FormatDateTime('[dd.mm.yyyy hh:nn:ss]', Now) + ' - ' + Msg);
    CloseFile(LogFile);
  except
    // не даём логированию упасть
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

      Bmp.Canvas.StretchDraw(Rect(X, Y, X + NewWidth, Y + NewHeight), PNG);

      // Обработка разных типов компонентов
      if Control is TBitBtn then
        (Control as TBitBtn).Glyph.Assign(Bmp)
      else if Control is TSpeedButton then
        (Control as TSpeedButton).Glyph.Assign(Bmp)
      else if Control is TButton then
      begin
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
  lbStatus.Caption := 'Громкость ' + IntToStr(tvVolume.Position) + '%';

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

function TfrmStickyForm.AddImageFromFileToImageList(const AFileName, AKey: string): Integer;
var
  PNG: TPngImage;
  BMP: TBitmap;
  idx: Integer;
  LogoFile, NoLogoPath: string;
begin
  Result := -1;
  if AKey = '' then Exit;

  // если уже есть → возвращаем индекс
  if FLogoMap.TryGetValue(AKey, idx) then
  begin
    Result := idx;
    Exit;
  end;

  NoLogoPath := frmSettings.lePachStyle.Text + 'logo-channels\NoLogo.png';

  LogoFile := AFileName;
  if not FileExists(LogoFile) then
    LogoFile := NoLogoPath;

  try
    PNG := TPngImage.Create;
    try
      PNG.LoadFromFile(LogoFile);

      BMP := TBitmap.Create;
      try
        BMP.PixelFormat := pf32bit;
        BMP.AlphaFormat := afDefined;
        BMP.SetSize(ilLogos.Width, ilLogos.Height);

        BMP.Canvas.Draw(0, 0, PNG);

        idx := ilLogos.Add(BMP, nil);
        FLogoMap.AddOrSetValue(AKey, idx);

        Result := idx;
      finally
        BMP.Free;
      end;
    finally
      PNG.Free;
    end;
  except
    // fallback: NoLogo
    if FileExists(NoLogoPath) then
      Result := AddImageFromFileToImageList(NoLogoPath, AKey)
    else
    begin
      FLogoMap.AddOrSetValue(AKey, -1);
      Result := -1;
    end;
  end;
  lbChannels.Repaint;
end;





procedure TfrmStickyForm.UseDefaultLogo(const Channel: TChannelInfo);
var
  idx, imgIndex: Integer;
  noLogoPath: string;
  itemRect: TRect;
begin
  noLogoPath := frmSettings.lePachStyle.Text + 'logo-channels\NoLogo.png';

  if not FileExists(noLogoPath) then
    Exit; // fallback — файла вообще нет

  // Для безопасности UI вызываем через Synchronize
  TThread.Synchronize(nil,
    procedure
    begin
      imgIndex := AddImageFromFileToImageList(noLogoPath, 'NoLogo');

      if imgIndex >= 0 then
        FLogoMap.AddOrSetValue(Channel.TVGID, imgIndex);

      idx := lbChannels.Items.IndexOf(Channel.Name);
      if idx >= 0 then
      begin
        lbChannels.Items.Objects[idx] := TObject(NativeInt(imgIndex));

        // перерисовываем только нужную строку
        itemRect := lbChannels.ItemRect(idx);
        InvalidateRect(lbChannels.Handle, @itemRect, True);
        UpdateWindow(lbChannels.Handle);
      end;
    end
  );
end;



procedure ResizePNG(const InStream, OutStream: TStream; const NewWidth, NewHeight: Integer);
var
  pngIn: TPngImage;
  bmp: TBitmap;
  pngOut: TPngImage;
begin
  pngIn := TPngImage.Create;
  bmp := TBitmap.Create;
  pngOut := TPngImage.Create;
  try
    InStream.Position := 0;
    pngIn.LoadFromStream(InStream);

    bmp.PixelFormat := pf32bit;
    bmp.AlphaFormat := afDefined; // обязательно для прозрачности
    bmp.SetSize(NewWidth, NewHeight);

    bmp.Canvas.StretchDraw(Rect(0, 0, NewWidth, NewHeight), pngIn);

    pngOut.Assign(bmp);
    pngOut.SaveToStream(OutStream);
  finally
    pngIn.Free;
    pngOut.Free;
    bmp.Free;
  end;
end;


procedure TfrmStickyForm.QueueDownloadLogo(const Channel: TChannelInfo);
var
  DestPath, FileName, LogoDir: string;
  localGen: Integer;
begin
  LogoDir := frmSettings.lePachStyle.Text + 'logo-channels\';

  if lbChannels.Items.IndexOf(Channel.Name) < 0 then Exit;
  if Channel.TVGID = '' then Exit;

  FileName := Channel.TVGID + '.png';
  DestPath := TPath.Combine(LogoDir, FileName);

  // если логотип уже есть на диске
  if FileExists(DestPath) then
  begin
    TThread.Synchronize(nil,
      procedure
      var
        idx, imgIndex: Integer;
        itemRect: TRect;
      begin
        imgIndex := AddImageFromFileToImageList(DestPath, Channel.TVGID);

        if imgIndex >= 0 then
          FLogoMap.AddOrSetValue(Channel.TVGID, imgIndex);

        idx := lbChannels.Items.IndexOf(Channel.Name);
        if idx >= 0 then
        begin
          lbChannels.Items.Objects[idx] := TObject(NativeInt(imgIndex));

          // перерисуем только одну строку
          itemRect := lbChannels.ItemRect(idx);
          InvalidateRect(lbChannels.Handle, @itemRect, True);
          UpdateWindow(lbChannels.Handle);
        end;
      end);
    Exit;
  end;

  // если URL отсутствует → используем дефолтный
  if Channel.LogoURL = '' then
  begin
    UseDefaultLogo(Channel);
    Exit;
  end;

  localGen := FGeneration;

  // поток для скачивания логотипа
  TThread.CreateAnonymousThread(
    procedure
    var
      HttpClient: TNetHTTPClient;
      MS, Resized: TMemoryStream;
    begin
      HttpClient := TNetHTTPClient.Create(nil);
      MS := TMemoryStream.Create;
      try
        try
          HttpClient.ConnectionTimeout := 3000;
          HttpClient.ResponseTimeout   := 5000;
          HttpClient.Get(Channel.LogoURL, MS);

          if (MS.Size > 0) and IsValidPNG(MS) then
          begin
            if not DirectoryExists(LogoDir) then
              ForceDirectories(LogoDir);

            Resized := TMemoryStream.Create;
            try
              ResizePNG(MS, Resized, 50, 50);
              Resized.SaveToFile(DestPath);
            finally
              Resized.Free;
            end;

            // применяем картинку в UI
            TThread.Synchronize(nil,
              procedure
              var
                idx, imgIndex: Integer;
                itemRect: TRect;
              begin
                if localGen <> FGeneration then Exit;

                imgIndex := AddImageFromFileToImageList(DestPath, Channel.TVGID);

                if imgIndex >= 0 then
                  FLogoMap.AddOrSetValue(Channel.TVGID, imgIndex);

                idx := lbChannels.Items.IndexOf(Channel.Name);
                if idx >= 0 then
                begin
                  lbChannels.Items.Objects[idx] := TObject(NativeInt(imgIndex));

                  // перерисуем только изменившуюся строку
                  itemRect := lbChannels.ItemRect(idx);
                  InvalidateRect(lbChannels.Handle, @itemRect, True);
                  UpdateWindow(lbChannels.Handle);
                end;
              end);
          end
          else
            UseDefaultLogo(Channel);
        except
          UseDefaultLogo(Channel);
        end;
      finally
        MS.Free;
        HttpClient.Free;
      end;
    end).Start;
end;








procedure TfrmStickyForm.ParseM3U(const FileName: string);
var
  SL: TStringList;
  i: Integer;
  Line, TVGID, LogoURL, Name, StreamURL: string;
  Info: TChannelInfo;
  m: TMatch;
  HeaderLine: string;
begin
  Inc(FGeneration);
  FLogoMap.Clear;
  ResetImageListToNoLogo;

  if FEpgUrls = nil then
    FEpgUrls := TStringList.Create;
  FEpgUrls.Clear;

  lbChannels.Items.BeginUpdate;
  try
    // очищаем старые каналы
    for i := 0 to FChannels.Count - 1 do
      FChannels[i].Free;
    FChannels.Clear;
    lbChannels.Clear;

    SL := TStringList.Create;
    try
      SL.LoadFromFile(FileName, TEncoding.UTF8);

      // ищем заголовок #EXTM3U и парсим epg url
      for i := 0 to SL.Count - 1 do
      begin
        HeaderLine := Trim(SL[i]);
        if HeaderLine.StartsWith('#EXTM3U', True) then
        begin
          if frmSettings.cbJTV.Checked then
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
          if (i + 1 < SL.Count) and not SL[i + 1].StartsWith('#') then
          begin
            StreamURL := Trim(SL[i + 1]);
            Inc(i);
          end;

          Info := TChannelInfo.Create;
          Info.Name := Name;
          Info.TVGID := TVGID;
          Info.LogoURL := LogoURL;
          Info.StreamURL := StreamURL;
          Info.CurrentTitle := '';
          Info.CurrentStart := 0;
          Info.CurrentStop := 0;

          FChannels.Add(Info);
          lbChannels.Items.Add(Info.Name);

          // логотип загружается асинхронно и перерисовывает только нужный элемент
          QueueDownloadLogo(Info);
        end;

        Inc(i);
      end;
    finally
      SL.Free;
    end;
  finally
    lbChannels.Items.EndUpdate;
    // **не вызываем Invalidate на весь список**
  end;

  // управление таймером EPG
  if Assigned(FEPGTimer) then
    FEPGTimer.Enabled := frmSettings.cbJTV.Checked;

  // **не вызываем lbChannels.Update**, отдельные элементы обновятся через QueueDownloadLogo/UseDefaultLogo
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

procedure TfrmStickyForm.EpgStatus;
var
  idx: Integer;
  cur: string;
  state: TPasLibVlcPlayerState;
  ch: TChannelInfo;
begin
  if not Assigned(Vlc_Player) then
    Exit;

  state := Vlc_Player.GetState;
  if state <> plvPlayer_Playing then
    Exit;

  idx := lbChannels.ItemIndex;
  if (idx < 0) or (idx >= FChannels.Count) then
    Exit;

  ch := FChannels[idx];
  if not Assigned(ch) then
    Exit;

  cur := Trim(ch.CurrentTitle);

  if cur = '' then
    cur := 'Нет актуальных данных'
  else
  begin
    var p := Pos('(', cur);
    if p > 0 then
      cur := Trim(Copy(cur, 1, p - 1));
  end;

  if Assigned(lbEPG_Text) then
    lbEPG_Text.Caption := 'Сейчас: ' + cur;
end;




procedure TfrmStickyForm.OnPlaying(Sender: TObject);
begin
  EpgStatus;
end;

procedure TfrmStickyForm.OnBuffering(Sender: TObject; cache: Single);
begin
  if Trunc(cache) < 100 then
    lbStatus.Caption := Format('Буферизация: %d%%', [Trunc(cache)])
  else
    lbStatus.Caption := 'Воспроизведение...';
    lbEPG_Text.Caption := '';
    EpgStatus;
end;

procedure TfrmStickyForm.OnError(Sender: TObject);
begin
  lbStatus.Caption := 'Ошибка воспроизведения!';
  lbEPG_Text.Caption := '';
  LoadPNGToControl(FButtonDir + 'play.png', sbPlay);
end;



procedure TfrmStickyForm.N1Click(Sender: TObject);
begin
  frmSettings.Show;
  GetChannels;
end;


procedure TfrmStickyForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  FStopRequested := True;
end;

procedure TfrmStickyForm.FormCreate(Sender: TObject);

begin
  Randomize;

  FChannels := TList<TChannelInfo>.Create;
  FLogoMap := TDictionary<string, Integer>.Create;
  FGeneration := 0;

  ilLogos.Clear;
  ilLogos.ColorDepth := cd32Bit;
  ilLogos.Width := 50;
  ilLogos.Height := 50;
  ilLogos.DrawingStyle := dsTransparent;
  ResetImageListToNoLogo;

  VLC_Player.VLC.Path := frmSettings.dePachVLC.Text;

  if FEpgUrls = nil then
    FEpgUrls := TStringList.Create;

  if FEPGTimer = nil then
  begin
    FEPGTimer := TTimer.Create(Self);
    FEPGTimer.Interval := 15 * 60 * 1000; // 15 минут
    FEPGTimer.OnTimer  := EPGTimerHandler;
    FEPGTimer.Enabled  := True;
  end;

  if FEPGStartTimer = nil then
  begin
    FEPGStartTimer := TTimer.Create(Self);
    FEPGStartTimer.Interval := 2000; // 2 секунды
    FEPGStartTimer.OnTimer  := StartEPGTimerHandler;
    FEPGStartTimer.Enabled  := True;
  end;

  VLC_Player.OnMediaPlayerBuffering        := OnBuffering;
  VLC_Player.OnMediaPlayerEncounteredError := OnError;
  VLC_Player.OnMediaPlayerPlaying          := OnPlaying;

  IsFullScreen := False;


{  // Устанавливаем минимальные значения буферов (100 мс)
  VLC_Player.StartOptions.Add(':network-caching=1000');
  VLC_Player.StartOptions.Add(':live-caching=1000');
  VLC_Player.StartOptions.Add(':file-caching=1000');
  VLC_Player.StartOptions.Add(':disc-caching=1000');
  VLC_Player.StartOptions.Add(':tcp-caching=1000');
  VLC_Player.StartOptions.Add(':udp-caching=1000');
  VLC_Player.StartOptions.Add(':rtsp-caching=1000');
  VLC_Player.StartOptions.Add(':verbose=2');  }



  if (FChannels.Count = 0) and FileExists(frmSettings.edURLM3U.Text) then
     ParseM3U(frmSettings.edURLM3U.Text);
end;

procedure TfrmStickyForm.FormDestroy(Sender: TObject);
var
  i: Integer;
begin
  // сначала освободим все каналы
  if Assigned(FChannels) then
  begin
    for i := 0 to FChannels.Count - 1 do
      FChannels[i].Free;
    FreeAndNil(FChannels);
  end;

  FreeAndNil(FLogoMap);

  try
    VLC_Player.Stop;
  except
    on E: Exception do
      lbStatus.Caption := 'Ошибка при очистке VLC: ' + E.Message;
  end;

  // cleanup timers if any
  FreeAndNil(FEPGTimer);
  FreeAndNil(FEPGStartTimer);
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
  // use anonymous thread for periodic EPG refresh (safer in DLL)
  TThread.CreateAnonymousThread(
    procedure
    begin
      DownloadAndParseAllEPG;
    end).Start;

end;

procedure TfrmStickyForm.StartEPGTimerHandler(Sender: TObject);
begin
  if Assigned(FEPGStartTimer) then
  begin
    FEPGStartTimer.Enabled := False;
    FreeAndNil(FEPGStartTimer);
  end;

  // start download in a thread (so UI not blocked)
  TThread.CreateAnonymousThread(
    procedure
    begin
      DownloadAndParseAllEPG;
    end).Start;
end;



procedure TfrmStickyForm.FormShow(Sender: TObject);
var
  NoLogoPath: string;
begin
  lbChannels.Style := lbOwnerDrawFixed;
  lbChannels.ItemHeight := Max(ilLogos.Height + 4, 48);

  FCacheDir  := frmSettings.lePachStyle.Text + 'logo-channels\';
  FButtonDir := frmSettings.lePachStyle.Text + 'image-button\';

  ForceDirectories(FCacheDir);

  if not DirectoryExists(FCacheDir) then
    ShowMessage('Создайте папку для кэша картинок "logo-channels"');

  if not DirectoryExists(FButtonDir) then
    ShowMessage('Не найдена папка с иконками для кнопок "image-button"')
  else
  begin
    LoadPNGToControl(FButtonDir + 'backward.png',     sbBack);
    LoadPNGToControl(FButtonDir + 'screen-full.png',  sbFullScreen);
    LoadPNGToControl(FButtonDir + 'forwards.png',     sbNext);
    LoadPNGToControl(FButtonDir + 'film-list.png',    sbOpen);
    LoadPNGToControl(FButtonDir + 'play.png',         sbPlay);
    LoadPNGToControl(FButtonDir + 'volume.png',       sbVolume);

    tvVolume.TrackFile := FButtonDir + 'track.png';
    tvVolume.ThumbFile := FButtonDir + 'thumb-48.png';
  end;

  NoLogoPath := frmSettings.lePachStyle.Text + 'logo-channels\NoLogo.png';
  if FileExists(NoLogoPath) then
    AddImageFromFileToImageList(NoLogoPath, 'NoLogo');

end;


procedure TfrmStickyForm.C1Click(Sender: TObject);
begin
  if lbChannels.Visible = True then
  begin
    lbChannels.Visible := False;
    Splitter.Visible := False;
  end
  else
  begin
    lbChannels.Visible := True;
    Splitter.Visible := True;
  end;
end;

procedure TfrmStickyForm.lbChannelsDblClick(Sender: TObject);
var
  idx: Integer;
begin
    idx := lbChannels.ItemIndex;

    if (idx >= 0) and (idx < FChannels.Count) then
    begin
      PlayChannelByIndex(idx);
      LoadPNGToControl(FButtonDir + 'stop-playing.png', sbPlay);
      lbStatus.Caption := 'Воспроизведение...';
    end
    else
      lbStatus.Caption := 'Список каналов пуст';

end;

function TfrmStickyForm.GetLogoIndexForTVGID(const ATVGID: string): Integer;
begin
  if not FLogoMap.TryGetValue(ATVGID, Result) then
    Result := -1;
end;

procedure TfrmStickyForm.lbChannelsDrawItem(Control: TWinControl; Index: Integer;
  Rect: TRect; State: TOwnerDrawState);
var
  nameLeft: Integer;
  ch: TChannelInfo;
  logoIdx: Integer;
  R: TRect;
  oldFontSize: Integer;
  i: Integer;
  nowDT: TDateTime;
  currEPG, nextEPG: TEPGItem;
  hasCurr: Boolean;
begin
  if (Index < 0) or (Index >= FChannels.Count) then Exit;

  ch := FChannels[Index];

  // фон при выделении/обычный
  if odSelected in State then
    lbChannels.Canvas.Brush.Color := clHighlight
  else
    lbChannels.Canvas.Brush.Color := lbChannels.Color;

  lbChannels.Canvas.FillRect(Rect);


  logoIdx := -1;

  // 1) сначала пробуем взять индекс из Objects
  if lbChannels.Items.Objects[Index] <> nil then
    logoIdx := Integer(NativeInt(lbChannels.Items.Objects[Index]));

  // 2) если не нашли → пробуем по карте по ключу TVGID
  if (logoIdx < 0) and (ch.TVGID <> '') then
    if not FLogoMap.TryGetValue(ch.TVGID, logoIdx) then
      logoIdx := -1;

  // 3) если ничего не нашли → ставим NoLogo
  if logoIdx < 0 then
    if not FLogoMap.TryGetValue('NoLogo', logoIdx) then
      logoIdx := -1;

  // рисуем логотип если нашли
  if logoIdx >= 0 then
    ilLogos.Draw(lbChannels.Canvas, Rect.Left + 2, Rect.Top + 2, logoIdx);

  nameLeft := Rect.Left + ilLogos.Width + 8;


  lbChannels.Canvas.Font.Color := clWindowText;
  lbChannels.Canvas.Font.Style := [fsBold];
  lbChannels.Canvas.TextOut(nameLeft, Rect.Top + 4, ch.Name);


  hasCurr := False;
  nowDT := Now;
  FillChar(currEPG, SizeOf(currEPG), 0);
  FillChar(nextEPG, SizeOf(nextEPG), 0);

  if Assigned(ch.EPG) then
  begin
    for i := 0 to ch.EPG.Count - 1 do
    begin
      if (ch.EPG[i].StartDT <= nowDT) and (ch.EPG[i].StopDT > nowDT) then
      begin
        currEPG := ch.EPG[i];
        if i+1 < ch.EPG.Count then
          nextEPG := ch.EPG[i+1];
        hasCurr := True;
        Break;
      end;
    end;
  end;

  oldFontSize := lbChannels.Canvas.Font.Size;
  lbChannels.Canvas.Font.Size := oldFontSize - 2;
  lbChannels.Canvas.Font.Style := [];
  lbChannels.Canvas.Font.Color := clGrayText;

  R := Rect;
  R.Top := Rect.Top + 20;

  if hasCurr then
  begin
    lbChannels.Canvas.TextOut(nameLeft, R.Top,
      Format('%s (%s-%s)', [
        currEPG.Title,
        FormatDateTime('hh:nn', currEPG.StartDT),
        FormatDateTime('hh:nn', currEPG.StopDT)
      ]));

    if nextEPG.Title <> '' then
      lbChannels.Canvas.TextOut(nameLeft, R.Top + 16,
        'Следом: ' + nextEPG.Title);

  end
  else
    lbChannels.Canvas.TextOut(nameLeft, R.Top, 'Нет актуальных данных');

  lbChannels.Canvas.Font.Size := oldFontSize;
end;




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

  if startPos <= Length(urls) then
  begin
    u := Trim(Copy(urls, startPos, MaxInt));
    if (u <> '') and (FEpgUrls.IndexOf(u) = -1) then
      FEpgUrls.Add(u);
  end;
end;

procedure TfrmStickyForm.DownloadAndParseAllEPG;
var
  i, total: Integer;
begin
  WriteDebugLog('Запуск DownloadAndParseAllEPG');
  ClearCurrentPrograms;

  if (FEpgUrls = nil) or (FEpgUrls.Count = 0) then
  begin
    WriteDebugLog('Нет EPG URL');
    Exit;
  end;

  total := FEpgUrls.Count;
  for i := 0 to total - 1 do
  begin
    if FStopRequested then
    begin
      WriteDebugLog('Остановка цикла по запросу');
      Break;
    end;

    try
      WriteDebugLog('Загрузка EPG: ' + FEpgUrls[i]);
      DownloadAndParseEPG(FEpgUrls[i]);
    except
      on E: Exception do
      begin
        WriteDebugLog('Ошибка загрузки EPG: ' + E.Message);
      end;
    end;

    Sleep(100);
  end;

  if not FStopRequested then
    TThread.Queue(nil,
      procedure
      begin
        RefreshCurrentPrograms;
        WriteDebugLog('EPG обновлено');
      end);
    EpgStatus;
    lbChannels.Invalidate;
end;



procedure TfrmStickyForm.DecompressGZip(const GZipFile, XmlFile: string);
var
  Source: TFileStream;
  Target: TFileStream;
  ZStream: TZDecompressionStream;
begin
  WriteDebugLog('Распаковка: ' + GZipFile);
  Source := TFileStream.Create(GZipFile, fmOpenRead or fmShareDenyWrite);
  try
    Target := TFileStream.Create(XmlFile, fmCreate);
    try
      ZStream := TZDecompressionStream.Create(Source, 15 + 16); // <-- 15+16 = GZIP mode
      try
        Target.CopyFrom(ZStream, 0);
      finally
        ZStream.Free;
      end;
    finally
      Target.Free;
    end;
  finally
    Source.Free;
  end;
end;



procedure TfrmStickyForm.DownloadAndParseEPG(const AUrl: string);
var
  HttpClient: TNetHTTPClient;
  Resp: IHTTPResponse;
  FilePath, XmlPath: string;
  MS: TMemoryStream;
begin
  WriteDebugLog('DownloadAndParseEPG: ' + AUrl);

  // Преобразуем URL → путь на диске
  FilePath := IncludeTrailingPathDelimiter(frmSettings.lePachStyle.Text) + 'epg\' +
              StringReplace(AUrl, 'https://', '', [rfIgnoreCase]);
  FilePath := StringReplace(FilePath, 'http://', '', [rfIgnoreCase]);
  FilePath := StringReplace(FilePath, '/', PathDelim, [rfReplaceAll]);

  // Создаём все папки для будущего файла
  ForceDirectories(ExtractFilePath(FilePath));

  XmlPath := ChangeFileExt(FilePath, '.xml');


  HttpClient := TNetHTTPClient.Create(nil);
  try
    HttpClient.UserAgent := 'Mozilla/5.0';
    HttpClient.AcceptEncoding := 'gzip, deflate';
    try
      HttpClient.SecureProtocols := [THTTPSecureProtocol.TLS12, THTTPSecureProtocol.TLS13];
    except
    end;

    MS := TMemoryStream.Create;
    try
      Resp := HttpClient.Get(AUrl, MS);
      if Resp.StatusCode = 200 then
      begin
        MS.SaveToFile(FilePath);
        WriteDebugLog('EPG скачан: ' + FilePath);

        if ExtractFileExt(FilePath).ToLower = '.gz' then
        begin
          try
            DecompressGZip(FilePath, XmlPath);
            WriteDebugLog('EPG распакован: ' + XmlPath);
          except
            on E: Exception do
            begin
              WriteDebugLog('Ошибка распаковки: ' + E.Message);
              Exit;
            end;
          end;
        end
        else
          XmlPath := FilePath;

        if FileExists(XmlPath) then
        begin
          MS.Clear;
          MS.LoadFromFile(XmlPath);
          ParseEPGStream(MS);
        end;
      end
      else
      begin
        WriteDebugLog('Ошибка HTTP ' + Resp.StatusText);
      end;
    finally
      MS.Free;
    end;
  finally
    HttpClient.Free;
  end;
  if not FStopRequested then
  EpgStatus;
end;




procedure TfrmStickyForm.ParseEPGStream(const MS: TMemoryStream);
var
  XML: TNativeXml;
  Root, Node, Child: TXmlNode;
  i, j: Integer;
  chId, startS, stopS, title, key: string;
  progStart, progStop, nowDT: TDateTime;
  ch: TChannelInfo;
  epgItem: TEPGItem;
  R: TRect;
  chDict: TDictionary<string, Integer>; // ключ = TVGID/Name → индекс в FChannels
  k: Integer;
begin
  WriteDebugLog('Начало ParseEPGStream (NativeXml)');

  chDict := TDictionary<string, Integer>.Create;
  try
    // Словарь только для каналов в lbChannels
    for i := 0 to lbChannels.Count - 1 do
    begin
      ch := FChannels[i];
      if ch.TVGID <> '' then
        key := LowerCase(ch.TVGID)
      else
        key := LowerCase(ch.Name);

      if key <> '' then
        chDict.TryAdd(key, i);
    end;

    try
      MS.Position := 0;
      XML := TNativeXml.Create(nil);
      try
        XML.LoadFromStream(MS);
        Root := XML.Root;

        if Root = nil then
        begin
          WriteDebugLog('Ошибка: пустой XML');
          Exit;
        end;

        nowDT := Now;

        // --- Убираем старые EPG (оставляем только 6 часов в обе стороны) ---
        for i := 0 to lbChannels.Count - 1 do
        begin
          ch := FChannels[i];
          k := 0;
          while k < ch.EPG.Count do
          begin
            if (ch.EPG[k].StopDT < (nowDT - (6/24))) or
               (ch.EPG[k].StartDT > (nowDT + (6/24))) then
              ch.EPG.Delete(k)
            else
              Inc(k);
          end;
        end;

        // --- Парсим XML ---
        for i := 0 to Root.NodeCount - 1 do
        begin
          Node := Root.Nodes[i];
          if SameText(Node.Name, 'programme') then
          begin
            chId   := Node.AttributeByName['channel'].ValueUnicode;
            startS := Node.AttributeByName['start'].ValueUnicode;
            stopS  := Node.AttributeByName['stop'].ValueUnicode;

            title := '';
            for j := 0 to Node.NodeCount - 1 do
            begin
              Child := Node.Nodes[j];
              if SameText(Child.Name, 'title') then
              begin
                title := Child.ValueUnicode;
                Break;
              end;
            end;

            progStart := ParseXMLTVDate(startS);
            progStop  := ParseXMLTVDate(stopS);

            // фильтр по времени ±6 часов
            if (progStart > 0) and (progStop > progStart) and
               (progStop >= (nowDT - (6/24))) and (progStart <= (nowDT + (6/24))) then
            begin
              key := LowerCase(chId);

              if chDict.ContainsKey(key) then
              begin
                ch := FChannels[chDict[key]];

                // --- проверка на дубликат ---
                var duplicate := False;
                for k := 0 to ch.EPG.Count - 1 do
                  if (Abs(ch.EPG[k].StartDT - progStart) < (1/86400)) and // равенство до 1 сек
                     SameText(ch.EPG[k].Title, title) then
                  begin
                    duplicate := True;
                    Break;
                  end;

                if not duplicate then
                begin
                  epgItem.Title   := title;
                  epgItem.StartDT := progStart;
                  epgItem.StopDT  := progStop;
                  ch.EPG.Add(epgItem);
                end;

                // если программа текущая
                if (progStart <= nowDT) and (progStop > nowDT) then
                begin
                  ch.CurrentTitle := title;
                  ch.CurrentStart := progStart;
                  ch.CurrentStop  := progStop;

                  R := lbChannels.ItemRect(chDict[key]);
                  InvalidateRect(lbChannels.Handle, @R, True);
                  lbChannels.Update;
                end;
              end;
            end;
          end;
        end;

        WriteDebugLog('Завершение ParseEPGStream (NativeXml)');
      finally
        XML.Free;
      end;
    except
      on E: Exception do
        WriteDebugLog('Ошибка ParseEPGStream: ' + E.Message);
    end;
  finally
    chDict.Free;
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
    sDate := Copy(S, 1, Length(S) - 1);
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
    y := StrToIntDef(Copy(sDate, 1, 4), 0);
    m := StrToIntDef(Copy(sDate, 5, 2), 0);
    d := StrToIntDef(Copy(sDate, 7, 2), 0);
    hh := StrToIntDef(Copy(sDate, 9, 2), 0);
    nn := StrToIntDef(Copy(sDate, 11, 2), 0);
    ss := StrToIntDef(Copy(sDate, 13, 2), 0);

    Result := EncodeDate(y, m, d) + EncodeTime(hh, nn, ss, 0);

    if (tz <> '') and ((tz[1] = '+') or (tz[1] = '-')) and (Length(tz) >= 5) then
    begin
      tzSign := 1;
      if tz[1] = '-' then tzSign := -1;
      tzH := StrToIntDef(Copy(tz, 2, 2), 0);
      tzM := StrToIntDef(Copy(tz, 4, 2), 0);
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
    Save;
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

  if idx < 0 then
    idx := 0
  else
  begin
    Inc(idx);
    if idx >= FChannels.Count then
      idx := 0;
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

  if idx < 0 then
    idx := FChannels.Count - 1
  else
  begin
    Dec(idx);
    if idx < 0 then
      idx := FChannels.Count - 1;
  end;

  lbChannels.ItemIndex := idx;
  PlayChannelByIndex(idx);
end;

procedure TfrmStickyForm.tvVolumeChange(Sender: TObject);
begin
  VLC_Player.SetAudioVolume(tvVolume.Position);
  lbStatus.Caption := 'Громкость ' + IntToStr(tvVolume.Position) + '%';
end;

procedure TfrmStickyForm.tStatusTimer(Sender: TObject);
var
  stateName: string;
  state: TPasLibVlcPlayerState;
begin
  case VLC_Player.GetState() of
    plvPlayer_NothingSpecial: stateName := '';
    plvPlayer_Opening:        stateName := 'Открытие потока';
    plvPlayer_Buffering:      stateName := 'Буфирация';
    plvPlayer_Paused:         stateName := 'Пауза';
    plvPlayer_Stopped:        stateName := 'Остановлено';
    plvPlayer_Ended:          stateName := '';
    plvPlayer_Error:          stateName := 'Ошибка загрузки потока';
    else                      stateName := '';
  end;

  lbStatus.Caption := stateName;

end;

procedure TfrmStickyForm.sbFullScreenClick(Sender: TObject);
var
  aFullScreenForm: TFullScreenForm;
  oldL, oldT, oldW, oldH: Integer;
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
    VLC_Player.Stop;
    LoadPNGToControl(FButtonDir + 'play.png', sbPlay);
    lbStatus.Caption := 'Остановлено';
    lbEPG_Text.Caption := '';
  end
  else
  begin
    idx := lbChannels.ItemIndex;
    if (idx < 0) and (FChannels <> nil) and (FChannels.Count > 0) then
      idx := 0;

    if (idx >= 0) and (idx < FChannels.Count) then
    begin
      PlayChannelByIndex(idx);
      LoadPNGToControl(FButtonDir + 'stop-playing.png', sbPlay);
      lbStatus.Caption := 'Воспроизведение...';
    end
    else
      lbStatus.Caption := 'Список каналов пуст';
  end;
  sbPlay.Invalidate;
  sbPlay.Update;
end;

function TfrmStickyForm.ExtractCurrentProgram(const AText: string): string;
var
  Lines: TArray<string>;
begin
  Lines := AText.Split([sLineBreak]);
  if Length(Lines) >= 2 then
    Result := Trim(Lines[1])  // вторая строка = текущая передача
  else
    Result := '';
end;


procedure TfrmStickyForm.sbVolumeClick(Sender: TObject);
begin
  if VLC_Player.GetAudioMute then
  begin
    VLC_Player.SetAudioMute(False);
    LoadPNGToControl(FButtonDir + 'volume.png', sbVolume);
    lbStatus.Caption := 'Звук включён';
  end
  else
  begin
    VLC_Player.SetAudioMute(True);
    LoadPNGToControl(FButtonDir + 'volume-mute.png', sbVolume);
    lbStatus.Caption := 'Звук выключен';
  end;
  sbVolume.Invalidate;
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

