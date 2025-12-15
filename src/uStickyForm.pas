unit uStickyForm;

interface

uses
  Windows, Classes, SysUtils, System.StrUtils, Dialogs, Messages, uFunc,
  Variants, Controls, Forms, Vcl.StdCtrls, Vcl.Buttons, Vcl.XPMan,
  Vcl.ComCtrls, Vcl.ExtCtrls, System.Win.Registry,
  System.Win.ScktComp, Vcl.Menus, Vcl.Graphics, PNGImage,
  Vcl.ExtDlgs, System.Generics.Collections, System.IOUtils,
  IdBaseComponent, IdComponent, IdTCPConnection, System.Threading,
  System.ImageList, Vcl.ImgList, Types,
  RegularExpressions, System.Net.HttpClientComponent, System.Math,
  uImageTrackBar, uSettings, FullScreenFormUnit, System.ZLib, System.NetEncoding,
  DateUtils, System.Net.HttpClient, Xml.XMLDoc, xmldom, Xml.XMLIntf, Xml.adomxmldom,
  NativeXml, VlcVisualComponent, IniFiles, FileDownloader;

type
  TEPGItem = record
    Title: string;
    StartDT: TDateTime;
    StopDT: TDateTime;
  end;

  TChannelInfo = class
  private
    FCustomAttributes: TStringList;
    FAspectRatio: string;
  public
    Name: string;
    TVGID: string;
    LogoURL: string;
    StreamURL: string;
    TVGShift: Integer;
    GroupTitle: string;
    CurrentTitle: string;
    CurrentStart: TDateTime;
    CurrentStop: TDateTime;

    EPG: TList<TEPGItem>;
    constructor Create;
    destructor Destroy; override;
    property CustomAttributes: TStringList read FCustomAttributes write FCustomAttributes;
    property AspectRatio: string read FAspectRatio write FAspectRatio;
  end;

type
  TfrmStickyForm = class(TForm)
    pmMenu: TPopupMenu;
    C1: TMenuItem;
    N1: TMenuItem;
    Panel_Button: TPanel;
    Splitter: TSplitter;
    sbBack: TSpeedButton;
    sbPlay: TSpeedButton;
    sbNext: TSpeedButton;
    sbFullScreen: TSpeedButton;
    lbChannels: TListBox;
    sbOpen: TSpeedButton;
    sbVolume: TSpeedButton;
    tvVolume: TImageTrackBar;
    Panel_Channels: TPanel;
    Panel_VLC_Player: TPanel;
    PlayerStatus: TTimer;
    FVlc: TVlcPlayer;
    TimeEpgStatus: TTimer;

    procedure C1Click(Sender: TObject);
    procedure sbOpenClick(Sender: TObject);
    procedure sbNextClick(Sender: TObject);
    procedure sbBackClick(Sender: TObject);
    procedure tvVolumeChange(Sender: TObject);
    procedure lbChannelsDblClick(Sender: TObject);
    procedure N1Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure lbChannelsDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure sbPlayClick(Sender: TObject);
    procedure ImageTrackBar1Change(Sender: TObject);
    procedure OnBuffering(Sender: TObject; cache: Single);
    procedure OnError(Sender: TObject);
    procedure OnPlaying(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure sbVolumeClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormShow(Sender: TObject);
    procedure PlayerStatusTimer(Sender: TObject);
    procedure TimeEpgStatusTimer(Sender: TObject);
    procedure sbFullScreenClick(Sender: TObject);
    procedure FVlcDblClick(Sender: TObject);
    procedure FVlcVideoDblClick(Sender: TObject);
  private
    FChannels: TList<TChannelInfo>;
    FLogoMap: TDictionary<string, Integer>;
    FParentChanName: WideString;
    FParentChanHandle: HWND;
    FGeneration: Integer;

    function GetLogoFilePath(const Channel: TChannelInfo): string;
    procedure QueueDownloadLogo(const Channel: TChannelInfo);
    procedure EPGTimerHandler(Sender: TObject);
    procedure SetParentChanName(const Value: WideString);
    procedure SetParentChanHandle(const Value: HWND);
    procedure PlayChannelByIndex(AIndex: Integer);
    procedure LoadEPGUrlsFromM3ULine(const Line: string);
    procedure DownloadAndParseAllEPG;
    procedure DownloadAndParseEPG(const AUrl: string);
    procedure ParseEPGStream(const MS: TMemoryStream);
    function ParseXMLTVDate(const S: string): TDateTime;
    procedure ClearCurrentPrograms;
    procedure RefreshCurrentPrograms;
    procedure StartEPGTimerHandler(Sender: TObject);
    procedure DecompressGZip(const GZipFile, XmlFile: string);
    procedure UseDefaultLogo(const Channel: TChannelInfo);
    procedure EpgStatus;
    function CleanChannelName(const DirtyName: string): string;
    procedure LoadSettings;
    procedure ParseExistingEPG(const XmlFilePath, AUrl: string);
    function MakeSafeFileName(const AText: string): string;
  public
    FStopRequested: Boolean;
    FCacheDir: String;
    FButtonDir: String;
    property ParentChanName: WideString read FParentChanName write SetParentChanName;
    property ParentChanHandle: HWND read FParentChanHandle write SetParentChanHandle;
    procedure ParseM3U(const FileName: string);
    procedure FullScreenFormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FullScreenFormDblClick(Sender: TObject);
    procedure TogglePlayPause;
    procedure VolumeUp;
    procedure VolumeDown;
    procedure DownloadM3UFromURL(const URL: string);
  end;

var
  frmStickyForm: TfrmStickyForm;
  ImageList: TImageList;
  IsFullScreen: Boolean;
  FEpgUrls: TStringList;
  FEPGTimer: TTimer;
  FEPGStartTimer: TTimer;
  FButtonDir: String;
  FimageChan:String;
  aFullScreenForm: TFullScreenForm;

implementation

{$R *.dfm}

uses uPlugin;

constructor TChannelInfo.Create;
begin
  inherited;
  EPG := TList<TEPGItem>.Create;
  FCustomAttributes := TStringList.Create;
  FAspectRatio := '';
end;

destructor TChannelInfo.Destroy;
begin
  EPG.Free;
  FCustomAttributes.Free;
  inherited;
end;

procedure LoadPNGToControl(const FileName: string; Control: TControl);
var
  PNG: TPngImage;
  Bmp: TBitmap;
begin
  if not Assigned(Control) then
    Exit;

  if not FileExists(FileName) then
    Exit;

  PNG := TPngImage.Create;
  try
    try
      PNG.LoadFromFile(FileName);
    except
      Exit;
    end;

    Bmp := TBitmap.Create;
    try
      Bmp.Width := Control.Width;
      Bmp.Height := Control.Height;

      Bmp.Canvas.Brush.Color := clWhite;
      Bmp.Canvas.FillRect(Rect(0, 0, Bmp.Width, Bmp.Height));

      var ScaleX := Bmp.Width / PNG.Width;
      var ScaleY := Bmp.Height / PNG.Height;
      var Scale := Min(ScaleX, ScaleY);

      var NewWidth := Round(PNG.Width * Scale);
      var NewHeight := Round(PNG.Height * Scale);

      var X := (Bmp.Width - NewWidth) div 2;
      var Y := (Bmp.Height - NewHeight) div 2;

      Bmp.Canvas.StretchDraw(Rect(X, Y, X + NewWidth, Y + NewHeight), PNG);

      if Control is TBitBtn then
        (Control as TBitBtn).Glyph.Assign(Bmp)
      else if Control is TSpeedButton then
        (Control as TSpeedButton).Glyph.Assign(Bmp);

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
    Exit;

  Channel := FChannels[AIndex];

  if Channel.StreamURL = '' then
    Exit;

  try
    FVlc.LoadMedia(Channel.StreamURL);
    PlayerStatus.Enabled := Enabled;
    FVlc.Play;

    // Обновляем текст EPG сразу после запуска воспроизведения
    TThread.Synchronize(nil,
      procedure
      begin
        EpgStatus;
      end);
  except
    on E: Exception do
    begin
    end;
  end;
end;

procedure TfrmStickyForm.ImageTrackBar1Change(Sender: TObject);
begin
  FVlc.Volume := tvVolume.Position;
  FVlc.SetDisplayText('Громкость ' + IntToStr(tvVolume.Position) + '%');
  FVlc.SetDisplayTextVisible(True);
  FVlc.ShowTopImage := False;

  if FVlc.IsMuted then
  begin
    LoadPNGToControl(FButtonDir + 'volume.png', sbVolume);
    FVlc.Unmute;
  end;

  if tvVolume.Position = 0 then
  begin
    FVlc.ShowTopImage := True;
    LoadPNGToControl(FButtonDir + 'volume-mute.png', sbVolume);
  end
  else
    LoadPNGToControl(FButtonDir + 'volume.png', sbVolume);

  // Автоматически скрываем текст через 2 секунды
  TThread.CreateAnonymousThread(
    procedure
    begin
      Sleep(2000);
      TThread.Synchronize(nil,
        procedure
        begin
          if FVlc.Volume = tvVolume.Position then // Проверяем, что громкость не изменилась
          begin
            FVlc.SetDisplayTextVisible(False);
            FVlc.Invalidate;
          end;
        end);
    end).Start;
end;

procedure TfrmStickyForm.UseDefaultLogo(const Channel: TChannelInfo);
var
  DefaultLogoPath: string;
  LogoIndex: Integer;
begin
  DefaultLogoPath := FCacheDir + 'NoLogo.png';

  if FileExists(DefaultLogoPath) then
  begin
    LogoIndex := 0;

    try
      FLogoMap.Add(Channel.TVGID, LogoIndex);
    except
      on E: EListError do
      begin
      end;
    end;

    TThread.Queue(nil,
      procedure
      var
        idx: Integer;
      begin
        idx := lbChannels.Items.IndexOf(Channel.Name);
        if idx >= 0 then
          lbChannels.Invalidate;
      end
    );
  end;
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
    bmp.AlphaFormat := afDefined;

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

function TfrmStickyForm.MakeSafeFileName(const AText: string): string;
begin
  Result := AText;
  Result := StringReplace(Result, ' ', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '/', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '\', '_', [rfReplaceAll]);
  Result := StringReplace(Result, ':', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '*', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '?', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '|', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '&', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '%', '_', [rfReplaceAll]);

  if Length(Result) > 100 then
    Result := Copy(Result, 1, 100);
end;

function GetFileSize(const AFileName: string): Int64;
var
  SR: TSearchRec;
begin
  Result := 0;
  if FindFirst(AFileName, faAnyFile, SR) = 0 then
  begin
    Result := SR.Size;
    FindClose(SR);
  end;
end;

procedure TfrmStickyForm.QueueDownloadLogo(const Channel: TChannelInfo);
var
  DestPath, FileName, LogoDir: string;
  localGen: Integer;
  SafeLogoURL: string;
  LogoIndex: Integer;
begin
  LogoDir := path + 'IPTV_Plugin\logo-channels\';

  if lbChannels.Items.IndexOf(Channel.Name) < 0 then
    Exit;

  if Channel.TVGID <> '' then
    FileName := MakeSafeFileName(Channel.TVGID) + '.png'
  else
    FileName := MakeSafeFileName(Channel.Name) + '.png';

  DestPath := TPath.Combine(LogoDir, FileName);

  if FileExists(DestPath) then
  begin
    LogoIndex := 1;

    try
      FLogoMap.Add(Channel.TVGID, LogoIndex);
    except
      on E: EListError do
      begin
      end;
    end;

    TThread.Queue(nil,
      procedure
      var
        idx: Integer;
      begin
        idx := lbChannels.Items.IndexOf(Channel.Name);
        if idx >= 0 then
          lbChannels.Invalidate;
      end
    );
    Exit;
  end;

  SafeLogoURL := Trim(Channel.LogoURL);
  if (SafeLogoURL = '') then
  begin
    UseDefaultLogo(Channel);
    Exit;
  end;

  if not (SafeLogoURL.StartsWith('http://', True) or SafeLogoURL.StartsWith('https://', True)) then
  begin
    UseDefaultLogo(Channel);
    Exit;
  end;

  localGen := FGeneration;

  TThread.CreateAnonymousThread(
    procedure
    var
      Downloader: TFileDownloader;
      LocalFile: string;
      WasDownloaded: Boolean;
      Success: Boolean;
    begin
      Success := False;

      try
        Downloader := TFileDownloader.CreateWithPath(LogoDir);
        try
          LocalFile := Downloader.EnsureFileAvailableEx(SafeLogoURL, WasDownloaded);

          if LocalFile <> '' then
          begin
            Success := True;

            if not SameText(LocalFile, DestPath) then
            begin
              try
                if FileExists(DestPath) then
                  DeleteFile(DestPath);
                if RenameFile(LocalFile, DestPath) then
                  LocalFile := DestPath;
              except
                on E: Exception do
                begin
                end;
              end;
            end;
          end

        finally
          Downloader.Free;
        end;

      except
        on E: Exception do
        begin
        end;
      end;

      if Success then
      begin
        LogoIndex := 1;

        try
          FLogoMap.Add(Channel.TVGID, LogoIndex);
        except
          on E: EListError do
          begin
          end;
        end;

        TThread.Queue(nil,
          procedure
          begin
            if localGen = FGeneration then
            begin
              try
                var idx := lbChannels.Items.IndexOf(Channel.Name);
                if idx >= 0 then
                  lbChannels.Invalidate;
              except
                on E: Exception do
                begin
                  UseDefaultLogo(Channel);
                end;
              end;
            end;
          end
        );
      end
      else
      begin
        TThread.Queue(nil,
          procedure
          begin
            UseDefaultLogo(Channel);
          end
        );
      end;
    end
  ).Start;
end;

function TfrmStickyForm.GetLogoFilePath(const Channel: TChannelInfo): string;
var
  LogoIndex: Integer;
  LogoPath: string;
begin
  Result := FCacheDir + 'NoLogo.png';

  if FLogoMap.TryGetValue(Channel.TVGID, LogoIndex) then
  begin
    if LogoIndex = 1 then
    begin
      if Channel.TVGID <> '' then
        LogoPath := path + 'IPTV_Plugin\logo-channels\' + MakeSafeFileName(Channel.TVGID) + '.png';

      if FileExists(LogoPath) then
        Result := LogoPath
      else
          Result := FCacheDir + 'NoLogo.png';
    end
  end;
end;

function TfrmStickyForm.CleanChannelName(const DirtyName: string): string;
var
  CleanName: string;
begin
  CleanName := Trim(DirtyName);

  if Pos('tvg-id=', CleanName) > 0 then
    CleanName := Copy(CleanName, 1, Pos('tvg-id=', CleanName) - 1);

  if Pos('group-title=', CleanName) > 0 then
    CleanName := Copy(CleanName, 1, Pos('group-title=', CleanName) - 1);

  if Pos('tvg-logo=', CleanName) > 0 then
    CleanName := Copy(CleanName, 1, Pos('tvg-logo=', CleanName) - 1);

  if Pos('tvg-shift=', CleanName) > 0 then
    CleanName := Copy(CleanName, 1, Pos('tvg-shift=', CleanName) - 1);

  CleanName := Trim(CleanName);
  CleanName := StringReplace(CleanName, '"', '', [rfReplaceAll]);

  Result := CleanName;
end;

procedure TfrmStickyForm.ParseExistingEPG(const XmlFilePath, AUrl: string);
var
  MS: TMemoryStream;
begin
  if not FileExists(XmlFilePath) then
    Exit;

  MS := TMemoryStream.Create;
  try
    try
      MS.LoadFromFile(XmlFilePath);
      ParseEPGStream(MS);
    except
      on E: Exception do
      begin
        // Если парсинг существующего файла не удался, скачиваем заново
        DownloadAndParseEPG(AUrl);
      end;
    end;
  finally
    MS.Free;
  end;
end;

function IsModalWindowOpen(AFormClass: TFormClass = nil): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to Screen.CustomFormCount - 1 do
  begin
    if fsModal in Screen.CustomForms[i].FormState then
    begin
      if (AFormClass = nil) or (Screen.CustomForms[i] is AFormClass) then
      begin
        Result := True;
        Exit;
      end;
    end;
  end;
end;

procedure TfrmStickyForm.ParseM3U(const FileName: string);
var
  SL: TStringList;
  i: Integer;
  Line, StreamURL, Name: string;
  Info: TChannelInfo;
  HeaderLine: string;
  Attrs, VLCOpts: TStringList;
  Regex: TRegEx;
  Match: TMatch;
  Key, Value: string;
  TempGroup: string;
  SkipChannel: Boolean;
  CurrentExtGrp: string;
  FoundExtGrp: string;
  AspectRatio: string;
begin
  Inc(FGeneration);
  FLogoMap.Clear;

  if FEpgUrls = nil then
    FEpgUrls := TStringList.Create;
  FEpgUrls.Clear;

  lbChannels.Items.BeginUpdate;
  try
    for i := 0 to FChannels.Count - 1 do
      FChannels[i].Free;
    FChannels.Clear;
    lbChannels.Clear;

    SL := TStringList.Create;
    try
      SL.LoadFromFile(FileName, TEncoding.UTF8);

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
      CurrentExtGrp := '';

      while i < SL.Count do
      begin
        Line := Trim(SL[i]);

        if Line = '' then
        begin
          Inc(i);
          Continue;
        end;

        if Line.StartsWith('#EXTGRP:', True) then
        begin
          CurrentExtGrp := Trim(Copy(Line, 9, MaxInt));
          Inc(i);
          Continue;
        end;

        if Line.StartsWith('#EXTINF', True) then
        begin
          Attrs := TStringList.Create;
          VLCOpts := TStringList.Create;
          SkipChannel := False;
          FoundExtGrp := '';
          AspectRatio := '';

          try
            Regex := TRegEx.Create('([\w-]+)\s*=\s*("([^"]*)"|([^,\s]+))', [roIgnoreCase]);
            Match := Regex.Match(Line);
            while Match.Success do
            begin
              Key := Match.Groups[1].Value;
              if Match.Groups[3].Value <> '' then
                Value := Match.Groups[3].Value
              else
                Value := Match.Groups[4].Value;

              Attrs.Values[Key] := Value;

              if SameText(Key, 'aspect-ratio') or SameText(Key, 'aspectratio') then
                AspectRatio := Value;

              Match := Match.NextMatch;
            end;

            if Attrs.Values['tvg-id'] = '' then
            begin
              SkipChannel := True;
            end;

            if Pos(',', Line) > 0 then
            begin
              Name := Trim(Copy(Line, Pos(',', Line) + 1, MaxInt));
              Name := CleanChannelName(Name);
            end
            else
              Name := '';

            TempGroup := Attrs.Values['group-title'];

            Inc(i);

            while (i < SL.Count) do
            begin
              Line := Trim(SL[i]);
              if Line = '' then
              begin
                Inc(i);
                Continue;
              end;

              if not Line.StartsWith('#') then
                Break;

              if Line.StartsWith('#EXTGRP:', True) then
              begin
                FoundExtGrp := Trim(Copy(Line, 9, MaxInt));
                Inc(i);
              end
              else if Line.StartsWith('#EXTVLCOPT:', True) then
              begin
                Line := StringReplace(Line, '#EXTVLCOPT:', '', [rfIgnoreCase]);
                if Pos('=', Line) > 0 then
                begin
                  Key := Trim(Copy(Line, 1, Pos('=', Line) - 1));
                  Value := Trim(Copy(Line, Pos('=', Line) + 1, MaxInt));
                  VLCOpts.Values[Key] := Value;

                  if SameText(Key, 'aspect-ratio') or SameText(Key, 'aspectratio') then
                    AspectRatio := Value;
                end;
                Inc(i);
              end
              else if Line.StartsWith('#EXT-X-STREAM-INF', True) or
                      Line.StartsWith('#EXT-X-MEDIA', True) then
              begin
                Match := Regex.Match(Line);
                while Match.Success do
                begin
                  Key := Match.Groups[1].Value;
                  if Match.Groups[3].Value <> '' then
                    Value := Match.Groups[3].Value
                  else
                    Value := Match.Groups[4].Value;

                  if SameText(Key, 'aspect-ratio') or SameText(Key, 'aspectratio') then
                    AspectRatio := Value;

                  Match := Match.NextMatch;
                end;
                Inc(i);
              end
              else
              begin
                Break;
              end;
            end;

            StreamURL := 'null';
            if i < SL.Count then
            begin
              StreamURL := Trim(SL[i]);
              Inc(i);
            end;

            if not SkipChannel then
            begin
              Info := TChannelInfo.Create;
              Info.Name := Name;
              Info.TVGID := Attrs.Values['tvg-id'];
              Info.LogoURL := Attrs.Values['tvg-logo'];
              Info.StreamURL := StreamURL;
              Info.CurrentTitle := '';
              Info.CurrentStart := 0;
              Info.CurrentStop := 0;
              Info.TVGShift := StrToIntDef(Attrs.Values['tvg-shift'], 0);

              Info.AspectRatio := AspectRatio;

              if TempGroup <> '' then
                Info.GroupTitle := TempGroup
              else if FoundExtGrp <> '' then
                Info.GroupTitle := FoundExtGrp
              else if CurrentExtGrp <> '' then
                Info.GroupTitle := CurrentExtGrp
              else
                Info.GroupTitle := '';

              Info.CustomAttributes.Assign(VLCOpts);
              FChannels.Add(Info);
              lbChannels.Items.Add(Info.Name);

              QueueDownloadLogo(Info);
            end;

          finally
            Attrs.Free;
            VLCOpts.Free;
          end;
        end
        else
        begin
          Inc(i);
        end;
      end;
    finally
      SL.Free;
    end;
  finally
    lbChannels.Items.EndUpdate;
  end;

  if Assigned(FEPGTimer) then
    FEPGTimer.Enabled := True;
end;

function IsFullScreenMode: Boolean;
begin
  Result := (Screen.ActiveForm <> nil) and
            (Screen.ActiveForm.WindowState = wsMaximized) and
            (Screen.ActiveForm.BorderStyle = bsNone);
end;

procedure TfrmStickyForm.EpgStatus;
var
  i, j: Integer;
  ch: TChannelInfo;
  currentUrl: string;
  timeRange: string;
  cur: string;
  nowDT: TDateTime;
  epgStartDT, epgStopDT: TDateTime;
  foundCurrent: Boolean;
begin
  // Отладочное сообщение
  OutputDebugString(PChar('EpgStatus: начат'));

  if not FVlc.IsPlaying then
  begin
    FVlc.SetDisplayTextVisible(False);
    OutputDebugString(PChar('EpgStatus: не играет, скрываем текст'));
    Exit;
  end;

  currentUrl := FVlc.GetCurrentMediaURL;
  if currentUrl = '' then
    currentUrl := FVlc.MediaURL;

  OutputDebugString(PChar('EpgStatus: текущий URL = ' + currentUrl));

  ch := nil;
  for i := 0 to FChannels.Count - 1 do
  begin
    if (FChannels[i].StreamURL = currentUrl) then
    begin
      ch := FChannels[i];
      OutputDebugString(PChar('EpgStatus: найден канал = ' + ch.Name));
      Break;
    end;
  end;

  if not Assigned(ch) then
  begin
    FVlc.SetDisplayTextVisible(False);
    OutputDebugString(PChar('EpgStatus: канал не найден'));
    Exit;
  end;

  nowDT := Now;
  foundCurrent := False;
  cur := 'Нет актуальных данных';
  timeRange := '';

  if Assigned(ch.EPG) then
  begin
    OutputDebugString(PChar('EpgStatus: EPG канала содержит ' + IntToStr(ch.EPG.Count) + ' записей'));

    for j := 0 to ch.EPG.Count - 1 do
    begin
      epgStartDT := IncHour(ch.EPG[j].StartDT, ch.TVGShift);
      epgStopDT := IncHour(ch.EPG[j].StopDT, ch.TVGShift);

      if (epgStartDT <= nowDT) and (epgStopDT > nowDT) then
      begin
        cur := ch.EPG[j].Title;
        timeRange := FormatDateTime('hh:nn', epgStartDT) + ' - ' +
                     FormatDateTime('hh:nn', epgStopDT);
        foundCurrent := True;

        ch.CurrentTitle := cur;
        ch.CurrentStart := epgStartDT;
        ch.CurrentStop := epgStopDT;

        OutputDebugString(PChar('EpgStatus: найдена текущая программа = ' + cur));
        Break;
      end;
    end;
  end
  else
  begin
    OutputDebugString(PChar('EpgStatus: у канала нет данных EPG'));
  end;

  if not foundCurrent then
  begin
    ch.CurrentTitle := '';
    ch.CurrentStart := 0;
    ch.CurrentStop := 0;
    OutputDebugString(PChar('EpgStatus: текущая программа не найдена'));
  end;

  var cleanTitle := cur;
  var p := Pos('(', cleanTitle);
  if p > 0 then
    cleanTitle := Trim(Copy(cleanTitle, 1, p - 1));

  var displayText: string;
  if foundCurrent then
  begin
    if ch.TVGShift <> 0 then
    begin
      var shiftText := Format('%s%d ч',
        [IfThen(ch.TVGShift > 0, '+', ''), ch.TVGShift]);
      displayText := Format('%s: %s (%s) [сдвиг %s]',
        [ch.Name, cleanTitle, timeRange, shiftText]);
    end
    else
    begin
      displayText := Format('%s: %s (%s)',
        [ch.Name, cleanTitle, timeRange]);
    end;
  end
  else
  begin
    if ch.TVGShift <> 0 then
    begin
      var shiftText := Format('%s%d ч',
        [IfThen(ch.TVGShift > 0, '+', ''), ch.TVGShift]);
      displayText := Format('%s: %s [сдвиг %s]',
        [ch.Name, cleanTitle, shiftText]);
    end
    else
    begin
      displayText := Format('%s: %s',
        [ch.Name, cleanTitle]);
    end;
  end;

  // ОСНОВНОЕ ИСПРАВЛЕНИЕ: устанавливаем текст и делаем его видимым
  FVlc.SetDisplayText(displayText);
  FVlc.SetDisplayTextVisible(True);

  // Настраиваем стиль текста
  FVlc.SetDisplayTextStyle(
    14,                    // Размер шрифта
    clWhite,              // Цвет текста
    $80202020,            // Полупрозрачный черный фон
    220,                  // Alpha канал
    8                     // Закругление
  );

  OutputDebugString(PChar('EpgStatus: установлен текст = ' + displayText));

  // Принудительное обновление отображения
  FVlc.Invalidate;

  // Дополнительное обновление через короткую задержку для надежности
  TThread.CreateAnonymousThread(
    procedure
    begin
      Sleep(100);
      TThread.Synchronize(nil,
        procedure
        begin
          FVlc.Invalidate;
        end);
    end).Start;
end;

procedure TfrmStickyForm.OnPlaying(Sender: TObject);
begin
  OutputDebugString(PChar('OnPlaying: начал играть'));
  EpgStatus;

  // Дополнительное обновление интерфейса
  if FVlc.HandleAllocated then
  begin
    FVlc.Invalidate;
    FVlc.Update;
    Invalidate;
  end;
end;

procedure TfrmStickyForm.OnBuffering(Sender: TObject; cache: Single);
begin
  if Trunc(cache) < 100 then
    OutputDebugString(PChar('OnBuffering: буферизация ' + FloatToStr(cache)))
  else
  begin
    OutputDebugString(PChar('OnBuffering: буферизация завершена'));
    EpgStatus;
  end;
end;

procedure TfrmStickyForm.OnError(Sender: TObject);
begin
  OutputDebugString(PChar('OnError: ошибка воспроизведения'));
  LoadPNGToControl(FButtonDir + 'play.png', sbPlay);
  FVlc.SetDisplayTextVisible(False);
end;

procedure TfrmStickyForm.N1Click(Sender: TObject);
begin
  frmSettings.Show;
  GetChannels;
end;

procedure TfrmStickyForm.LoadSettings;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(path + 'IPTV_Plugin\IPTV_Plug.ini');
  try
    tvVolume.Position := Ini.ReadInteger('IPTV-Player', 'Volume', 100);
    FButtonDir := Ini.ReadString('Settings', 'Style', path + 'IPTV_Plugin\style\');
  finally
    Ini.Free;
  end;
end;

procedure TfrmStickyForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  FStopRequested := True;
  Save;
end;

procedure TfrmStickyForm.DownloadM3UFromURL(const URL: string);
var
  Downloader: TFileDownloader;
  LocalFile: string;
  WasDownloaded: Boolean;
begin
  Downloader := TFileDownloader.Create;
  try
    LocalFile := Downloader.EnsureFileAvailableEx(
      URL,
      WasDownloaded,
      path+'IPTV_Plugin\m3u'
    );

    if LocalFile <> '' then
       ParseM3U(LocalFile);

  finally
    Downloader.Free;
  end;
end;

procedure TfrmStickyForm.FormCreate(Sender: TObject);
var
  NoLogoPath: string;
  Downloader: TFileDownloader;
  LocalFile: string;
  WasDownloaded: Boolean;
begin
  LoadSettings;

  Randomize;
  FChannels := TList<TChannelInfo>.Create;
  FLogoMap := TDictionary<string, Integer>.Create;
  FGeneration := 0;

  if FEpgUrls = nil then
    FEpgUrls := TStringList.Create;

  if FEPGTimer = nil then
  begin
    FEPGTimer := TTimer.Create(Self);
    FEPGTimer.Interval := 15 * 60 * 1000;
    FEPGTimer.OnTimer  := EPGTimerHandler;
    FEPGTimer.Enabled  := True;
  end;

  if FEPGStartTimer = nil then
  begin
    FEPGStartTimer := TTimer.Create(Self);
    FEPGStartTimer.Interval := 2000;
    FEPGStartTimer.OnTimer  := StartEPGTimerHandler;
    FEPGStartTimer.Enabled  := True;
  end;

  DownloadM3UFromURL(frmSettings.edURLM3U.Text);

  NoLogoPath := ExtractFilePath(ParamStr(0)) + 'Plugins\IPTV_Plugin\logo-channels\NoLogo.png';

  FVlc.LibPath := ExtractFilePath(ParamStr(0)) + 'Plugins\IPTV_Plugin';
  FVlc.ShowTopImage := False;

  // Инициализация текста EPG
  FVlc.SetDisplayTextVisible(True);
  FVlc.SetDisplayText('Загрузка...');

  // Настройка стиля по умолчанию для текста EPG
  FVlc.SetDisplayTextStyle(
    14,                    // Размер шрифта
    clWhite,              // Цвет текста
    $80202020,            // Полупрозрачный черный фон
    220,                  // Прозрачность
    8                     // Закругление
  );

  // Настройка интервалов таймеров
  TimeEpgStatus.Interval := 30000;  // Обновление EPG каждые 30 секунд
  PlayerStatus.Interval := 1000;    // Статус плеера каждую секунду

  OutputDebugString(PChar('FormCreate: TVlcPlayer инициализирован'));
end;

procedure TfrmStickyForm.FormDestroy(Sender: TObject);
var
  i: Integer;
begin
  if Assigned(FChannels) then
  begin
    for i := 0 to FChannels.Count - 1 do
      FChannels[i].Free;
    FreeAndNil(FChannels);
  end;

  FreeAndNil(FLogoMap);

  FreeAndNil(FEPGTimer);
  FreeAndNil(FEPGStartTimer);
  FreeAndNil(FullScreenForm);
  FVlc.Free;
end;

procedure TfrmStickyForm.FormShow(Sender: TObject);
begin
  lbChannels.Style := lbOwnerDrawFixed;
  lbChannels.ItemHeight := 80;

  FCacheDir  := ExtractFilePath(ParamStr(0)) + 'Plugins\IPTV_Plugin\logo-channels\';
  FButtonDir := ExtractFilePath(ParamStr(0)) + 'Plugins\IPTV_Plugin\image-button\';

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

    if FVlc.IsPlaying then
       LoadPNGToControl(FButtonDir + 'stop-playing.png', sbPlay)
    else
       LoadPNGToControl(FButtonDir + 'play.png', sbPlay);

    if FVlc.IsMuted then
       LoadPNGToControl(FButtonDir + 'volume-mute.png', sbVolume)
    else
       LoadPNGToControl(FButtonDir + 'volume.png', sbVolume);

    tvVolume.TrackFile := FButtonDir + 'track.png';
    tvVolume.ThumbFile := FButtonDir + 'thumb-48.png';

    if tvVolume.Position = 0 then
    begin
       LoadPNGToControl(FButtonDir + 'volume-mute.png', sbVolume);
       FVlc.ShowTopImage := True;
    end
       else
       LoadPNGToControl(FButtonDir + 'volume.png', sbVolume);

    FVlc.TopImagePath := FButtonDir + 'volume-mute-player.png';
  end;

  if not Assigned(lbChannels.OnDrawItem) then
    lbChannels.OnDrawItem := lbChannelsDrawItem;

  // Тестовый вывод текста при показе формы
  FVlc.SetDisplayText('Тест: Форма показана');
  FVlc.SetDisplayTextVisible(True);
  FVlc.Invalidate;

  OutputDebugString(PChar('FormShow: форма показана, тестовый текст установлен'));
end;

procedure TfrmStickyForm.FVlcDblClick(Sender: TObject);
begin
  if not (FVlc.Parent is TFullScreenForm) then
  begin
    sbFullScreenClick(self);
  end;
    if IsModalWindowOpen(TFullScreenForm) then
    begin
      keybd_event(VK_ESCAPE, 0, 0, 0);
      keybd_event(VK_ESCAPE, 0, KEYEVENTF_KEYUP, 0);
    end;
end;

procedure TfrmStickyForm.FVlcVideoDblClick(Sender: TObject);
begin
  if not (FVlc.Parent is TFullScreenForm) then
  begin
    sbFullScreenClick(self);
  end;
    if IsModalWindowOpen(TFullScreenForm) then
    begin
      keybd_event(VK_ESCAPE, 0, 0, 0);
      keybd_event(VK_ESCAPE, 0, KEYEVENTF_KEYUP, 0);
    end;
end;

procedure TfrmStickyForm.EPGTimerHandler(Sender: TObject);
begin
  OutputDebugString(PChar('EPGTimerHandler: обновление EPG по таймеру'));
  TThread.CreateAnonymousThread(
    procedure
    begin
      DownloadAndParseAllEPG;
    end).Start;
end;

procedure TfrmStickyForm.StartEPGTimerHandler(Sender: TObject);
begin
  OutputDebugString(PChar('StartEPGTimerHandler: запуск первого обновления EPG'));

  if Assigned(FEPGStartTimer) then
  begin
    FEPGStartTimer.Enabled := False;
    FreeAndNil(FEPGStartTimer);
  end;

  TThread.CreateAnonymousThread(
    procedure
    begin
      DownloadAndParseAllEPG;
    end).Start;
end;

procedure TfrmStickyForm.TimeEpgStatusTimer(Sender: TObject);
begin
  if FVlc.IsPlaying then
  begin
    OutputDebugString(PChar('TimeEpgStatusTimer: обновление текста EPG'));
    EpgStatus;
  end
  else
  begin
    FVlc.SetDisplayTextVisible(False);
    OutputDebugString(PChar('TimeEpgStatusTimer: не играет, скрываем текст'));
  end;
end;

procedure TfrmStickyForm.PlayerStatusTimer(Sender: TObject);
var
  CurrentProgress: Integer;
begin
  // Проверяем статус воспроизведения и обновляем EPG если нужно
  if FVlc.IsPlaying then
  begin
    // Периодически обновляем EPG, но не слишком часто
    if Random(10) = 0 then  // Примерно каждые 10 секунд
    begin
      EpgStatus;
    end;
  end;
end;

procedure TfrmStickyForm.C1Click(Sender: TObject);
begin
  if Panel_Channels.Visible = True then
  begin
    Panel_Channels.Visible := False;
    Splitter.Visible := False;
  end
  else
  begin
    Panel_Channels.Visible := True;
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

      // Сразу обновляем текст EPG
      TThread.CreateAnonymousThread(
        procedure
        begin
          Sleep(500); // Небольшая задержка для загрузки потока
          TThread.Synchronize(nil,
            procedure
            begin
              EpgStatus;
            end);
        end).Start;
    end;
end;

procedure TfrmStickyForm.lbChannelsDrawItem(Control: TWinControl; Index: Integer;
  Rect: TRect; State: TOwnerDrawState);
var
  nameLeft: Integer;
  ch: TChannelInfo;
  LogoPath: string;
  R: TRect;
  oldFontSize: Integer;
  i: Integer;
  nowDT: TDateTime;
  currEPG, nextEPG: TEPGItem;
  hasCurr: Boolean;
  textColor, grayTextColor: TColor;
  shiftText: string;
  epgStartDT, epgStopDT: TDateTime;
  LogoRect: TRect;
  PNG: TPngImage;
  ScaleX, ScaleY, Scale: Double;
  NewWidth, NewHeight: Integer;
  X, Y: Integer;
  DestRect: TRect;
  LeftMargin: Integer;
begin
  if (Index < 0) or (Index >= FChannels.Count) then Exit;

  ch := FChannels[Index];

  LeftMargin := 10;

  if odSelected in State then
  begin
    lbChannels.Canvas.Brush.Color := clHighlight;
    textColor := clHighlightText;
    grayTextColor := clSilver;
  end
  else
  begin
    lbChannels.Canvas.Brush.Color := lbChannels.Color;
    textColor := clWindowText;
    grayTextColor := clGrayText;
  end;

  lbChannels.Canvas.FillRect(Rect);

  LogoPath := GetLogoFilePath(ch);

  if (LogoPath = '') or not FileExists(LogoPath) then
  begin
    LogoPath := FCacheDir + 'NoLogo.png';
  end;

  LogoRect := Rect;
  LogoRect.Left := LogoRect.Left + LeftMargin;
  LogoRect.Right := LogoRect.Left + 50;
  LogoRect.Bottom := LogoRect.Top + 50;

  LogoRect.Top := Rect.Top + (Rect.Bottom - Rect.Top - 50) div 2;
  if LogoRect.Top < Rect.Top + 2 then
    LogoRect.Top := Rect.Top + 2;
  LogoRect.Bottom := LogoRect.Top + 50;

  if FileExists(LogoPath) then
  begin
    PNG := TPngImage.Create;
    try
      try
        PNG.LoadFromFile(LogoPath);

        ScaleX := (LogoRect.Right - LogoRect.Left) / PNG.Width;
        ScaleY := (LogoRect.Bottom - LogoRect.Top) / PNG.Height;
        Scale := Min(ScaleX, ScaleY);

        NewWidth := Round(PNG.Width * Scale);
        NewHeight := Round(PNG.Height * Scale);

        X := LogoRect.Left + ((LogoRect.Right - LogoRect.Left) - NewWidth) div 2;
        Y := LogoRect.Top + ((LogoRect.Bottom - LogoRect.Top) - NewHeight) div 2;

        DestRect := System.Classes.Rect(X, Y, X + NewWidth, Y + NewHeight);

        SetStretchBltMode(lbChannels.Canvas.Handle, HALFTONE);
        SetBrushOrgEx(lbChannels.Canvas.Handle, 0, 0, nil);

        PNG.Draw(lbChannels.Canvas, DestRect);

      except
        on E: Exception do
        begin
        end;
      end;
    finally
      PNG.Free;
    end;
  end;

  nameLeft := LogoRect.Right + 8;
  oldFontSize := lbChannels.Canvas.Font.Size;

  lbChannels.Canvas.Font.Color := textColor;
  lbChannels.Canvas.Font.Style := [fsBold];
  lbChannels.Canvas.TextOut(nameLeft, Rect.Top + 6, ch.Name);

  if ch.AspectRatio <> '' then
  begin
    lbChannels.Canvas.Font.Size := oldFontSize - 2;
    lbChannels.Canvas.Font.Color := clBlue;
    var aspectText := ' [' + ch.AspectRatio + ']';
    var textWidth := lbChannels.Canvas.TextWidth(ch.Name);
    lbChannels.Canvas.TextOut(nameLeft + textWidth + 5, Rect.Top + 6, aspectText);
    lbChannels.Canvas.Font.Size := oldFontSize;
    lbChannels.Canvas.Font.Color := textColor;
  end;

  lbChannels.Canvas.Font.Size := oldFontSize - 1;
  lbChannels.Canvas.Font.Style := [];
  lbChannels.Canvas.Font.Color := grayTextColor;

  if ch.GroupTitle <> '' then
    lbChannels.Canvas.TextOut(nameLeft, Rect.Top + 24, 'Группа: ' + ch.GroupTitle)
  else
    lbChannels.Canvas.TextOut(nameLeft, Rect.Top + 24, 'Группа: не указана');

  lbChannels.Canvas.Font.Size := oldFontSize;

  hasCurr := False;
  nowDT := Now;

  if ch.TVGShift <> 0 then
  begin
    if ch.TVGShift > 0 then
      shiftText := Format('+%d ч', [ch.TVGShift])
    else
      shiftText := Format('%d ч', [ch.TVGShift]);
  end
  else
    shiftText := '';

  currEPG := Default(TEPGItem);
  nextEPG := Default(TEPGItem);

  if Assigned(ch.EPG) then
  begin
    for i := 0 to ch.EPG.Count - 1 do
    begin
      epgStartDT := IncHour(ch.EPG[i].StartDT, ch.TVGShift);
      epgStopDT := IncHour(ch.EPG[i].StopDT, ch.TVGShift);

      if (epgStartDT <= nowDT) and (epgStopDT > nowDT) then
      begin
        currEPG := ch.EPG[i];
        currEPG.StartDT := epgStartDT;
        currEPG.StopDT := epgStopDT;

        if i + 1 < ch.EPG.Count then
        begin
          nextEPG := ch.EPG[i + 1];
          nextEPG.StartDT := IncHour(nextEPG.StartDT, ch.TVGShift);
          nextEPG.StopDT := IncHour(nextEPG.StopDT, ch.TVGShift);
        end;

        hasCurr := True;
        Break;
      end;
    end;
  end;

  lbChannels.Canvas.Font.Size := oldFontSize - 1;
  lbChannels.Canvas.Font.Style := [];
  lbChannels.Canvas.Font.Color := grayTextColor;

  R := Rect;
  R.Top := Rect.Top + 42;

  if hasCurr then
  begin
    if ch.TVGShift <> 0 then
    begin
      lbChannels.Canvas.TextOut(nameLeft, R.Top,
        Format('%s (%s-%s) [сдвиг %s]', [
          currEPG.Title,
          FormatDateTime('hh:nn', currEPG.StartDT),
          FormatDateTime('hh:nn', currEPG.StopDT),
          shiftText
        ]));
    end
    else
    begin
      lbChannels.Canvas.TextOut(nameLeft, R.Top,
        Format('%s (%s-%s)', [
          currEPG.Title,
          FormatDateTime('hh:nn', currEPG.StartDT),
          FormatDateTime('hh:nn', currEPG.StopDT)
        ]));
    end;

    if (nextEPG.Title <> '') and (R.Top + 32 <= Rect.Bottom) then
      lbChannels.Canvas.TextOut(nameLeft, R.Top + 16,
        Format('Следом: %s (%s)', [nextEPG.Title, FormatDateTime('hh:nn', nextEPG.StartDT)]));
  end
  else
  begin
    if ch.TVGShift <> 0 then
      lbChannels.Canvas.TextOut(nameLeft, R.Top,
        Format('Нет актуальных данных [сдвиг %s]', [shiftText]))
    else
      lbChannels.Canvas.TextOut(nameLeft, R.Top, 'Нет актуальных данных');
  end;

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
  FilePath, XmlPath: string;
  FileAgeHours: Double;
  EpgUrl: string;
  LocalEpgUrls: TStringList;
begin
  OutputDebugString(PChar('DownloadAndParseAllEPG: начато обновление EPG'));

  ClearCurrentPrograms;

  // Создаем локальную копию списка URL для потокобезопасности
  LocalEpgUrls := TStringList.Create;
  try
    // Определяем источник EPG
    if frmSettings.cbJTV.Checked then
    begin
      // Используем плейлист для получения EPG
      if (FEpgUrls = nil) or (FEpgUrls.Count = 0) then
      begin
        OutputDebugString(PChar('DownloadAndParseAllEPG: нет URL EPG в плейлисте'));
        Exit;
      end;
      LocalEpgUrls.Assign(FEpgUrls);
    end
    else
    begin
      // Используем пользовательский EPG из deEpg.text
      if Trim(frmSettings.deEpg.Text) = '' then
      begin
        OutputDebugString(PChar('DownloadAndParseAllEPG: пользовательский EPG не указан'));
        Exit;
      end;
      LocalEpgUrls.Add(frmSettings.deEpg.Text);
    end;

    total := LocalEpgUrls.Count;
    OutputDebugString(PChar('DownloadAndParseAllEPG: всего ' + IntToStr(total) + ' источников EPG'));

    for i := 0 to total - 1 do
    begin
      if FStopRequested then
      begin
        OutputDebugString(PChar('DownloadAndParseAllEPG: запрошена остановка'));
        Break;
      end;

      try
        EpgUrl := LocalEpgUrls[i];
        OutputDebugString(PChar('DownloadAndParseAllEPG: обработка ' + EpgUrl));

        FilePath := path + 'IPTV_Plugin\epg\' +
                    StringReplace(EpgUrl, 'https://', '', [rfIgnoreCase]);
        FilePath := StringReplace(FilePath, 'http://', '', [rfIgnoreCase]);
        FilePath := StringReplace(FilePath, '/', PathDelim, [rfReplaceAll]);

        XmlPath := ChangeFileExt(FilePath, '.xml');

        if FileExists(XmlPath) then
        begin
          FileAgeHours := (Now - FileDateToDateTime(FileAge(XmlPath))) * 24;

          if FileAgeHours < 24 then
          begin
            OutputDebugString(PChar('DownloadAndParseAllEPG: используем кэшированный файл (возраст ' + FloatToStr(FileAgeHours) + ' ч)'));
            ParseExistingEPG(XmlPath, EpgUrl);
            Continue;
          end
          else
          begin
            OutputDebugString(PChar('DownloadAndParseAllEPG: файл устарел (возраст ' + FloatToStr(FileAgeHours) + ' ч)'));
          end;
        end;

        OutputDebugString(PChar('DownloadAndParseAllEPG: загрузка нового EPG'));
        DownloadAndParseEPG(EpgUrl);

      except
        on E: Exception do
        begin
          OutputDebugString(PChar('DownloadAndParseAllEPG ошибка: ' + E.Message));
        end;
      end;

      Sleep(100);
    end;
  finally
    LocalEpgUrls.Free;
  end;

  if not FStopRequested then
  begin
    TThread.Queue(nil,
      procedure
      begin
        RefreshCurrentPrograms;
        // Обновляем текст EPG в плеере
        EpgStatus;
      end);

    OutputDebugString(PChar('DownloadAndParseAllEPG: обновление завершено'));
  end
  else
  begin
    OutputDebugString(PChar('DownloadAndParseAllEPG: обновление прервано'));
  end;
end;

procedure TfrmStickyForm.DecompressGZip(const GZipFile, XmlFile: string);
var
  Source: TFileStream;
  Target: TFileStream;
  ZStream: TZDecompressionStream;
begin
  Source := TFileStream.Create(GZipFile, fmOpenRead or fmShareDenyWrite);
  try
    Target := TFileStream.Create(XmlFile, fmCreate);
    try
      ZStream := TZDecompressionStream.Create(Source, 15 + 16);
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
  OutputDebugString(PChar('DownloadAndParseEPG: загрузка ' + AUrl));

  FilePath := path + 'IPTV_Plugin\epg\' +
              StringReplace(AUrl, 'https://', '', [rfIgnoreCase]);
  FilePath := StringReplace(FilePath, 'http://', '', [rfIgnoreCase]);
  FilePath := StringReplace(FilePath, '/', PathDelim, [rfReplaceAll]);

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
        OutputDebugString(PChar('DownloadAndParseEPG: успешно загружено, размер ' + IntToStr(MS.Size)));

        MS.SaveToFile(FilePath);

        if ExtractFileExt(FilePath).ToLower = '.gz' then
        begin
          try
            OutputDebugString(PChar('DownloadAndParseEPG: распаковка GZIP'));
            DecompressGZip(FilePath, XmlPath);
            DeleteFile(FilePath);
          except
            on E: Exception do
            begin
              OutputDebugString(PChar('DownloadAndParseEPG ошибка распаковки: ' + E.Message));
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
          OutputDebugString(PChar('DownloadAndParseEPG: успешно обработан'));
        end;
      end
      else
      begin
        OutputDebugString(PChar('DownloadAndParseEPG: HTTP ошибка ' + IntToStr(Resp.StatusCode)));
      end;
    finally
      MS.Free;
    end;
  finally
    HttpClient.Free;
  end;

  if not FStopRequested then
  begin
    TThread.Synchronize(nil,
      procedure
      begin
        EpgStatus;
      end);
  end;
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
  chDict: TDictionary<string, Integer>;
  k: Integer;
begin
  OutputDebugString(PChar('ParseEPGStream: начало парсинга'));

  chDict := TDictionary<string, Integer>.Create;
  try
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

    OutputDebugString(PChar('ParseEPGStream: каналов в словаре ' + IntToStr(chDict.Count)));

    try
      MS.Position := 0;
      XML := TNativeXml.Create(nil);
      try
        XML.LoadFromStream(MS);
        Root := XML.Root;

        if Root = nil then
        begin
          OutputDebugString(PChar('ParseEPGStream: корневой элемент не найден'));
          Exit;
        end;

        nowDT := Now;

        // Очищаем устаревшие записи EPG
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

        var programCount := 0;
        for i := 0 to Root.NodeCount - 1 do
        begin
          Node := Root.Nodes[i];
          if SameText(Node.Name, 'programme') then
          begin
            Inc(programCount);
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

            if (progStart > 0) and (progStop > progStart) and
               (progStop >= (nowDT - (6/24))) and (progStart <= (nowDT + (6/24))) then
            begin
              key := LowerCase(chId);

              if chDict.ContainsKey(key) then
              begin
                ch := FChannels[chDict[key]];

                var duplicate := False;
                for k := 0 to ch.EPG.Count - 1 do
                  if (Abs(ch.EPG[k].StartDT - progStart) < (1/86400)) and
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

        OutputDebugString(PChar('ParseEPGStream: обработано ' + IntToStr(programCount) + ' программ'));
      finally
        XML.Free;
      end;
    except
      on E: Exception do
      begin
        OutputDebugString(PChar('ParseEPGStream ошибка: ' + E.Message));
      end;
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
  OutputDebugString(PChar('RefreshCurrentPrograms: обновление списка каналов'));
  lbChannels.Invalidate;
end;

procedure TfrmStickyForm.sbOpenClick(Sender: TObject);
begin
  frmSettings.ShowModal;

  if Assigned(frmSettings) then
  begin
    DownloadM3UFromURL(frmSettings.edURLM3U.Text);
    TThread.CreateAnonymousThread(
      procedure
      begin
        DownloadAndParseAllEPG;
      end).Start;
  end;
end;

procedure TfrmStickyForm.sbNextClick(Sender: TObject);
var
  idx: Integer;
begin
  if (FChannels = nil) or (FChannels.Count = 0) then
    Exit;

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
    Exit;

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

procedure TfrmStickyForm.FullScreenFormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_ESCAPE:
      (Sender as TForm).ModalResult := mrCancel;
    VK_SPACE:
      TogglePlayPause;
    VK_UP:
      VolumeUp;
    VK_DOWN:
      VolumeDown;
  end;
end;

procedure TfrmStickyForm.VolumeUp;
begin
  var NewVolume := FVlc.Volume + 10;
  if NewVolume > 100 then NewVolume := 100;
  FVlc.Volume := NewVolume;
  tvVolume.Position := NewVolume;
end;

procedure TfrmStickyForm.VolumeDown;
begin
  var NewVolume := FVlc.Volume - 10;
  if NewVolume < 0 then NewVolume := 0;
  FVlc.Volume := NewVolume;
  tvVolume.Position := NewVolume;
end;

procedure TfrmStickyForm.FullScreenFormDblClick(Sender: TObject);
begin
  (Sender as TForm).ModalResult := mrCancel;
end;

procedure TfrmStickyForm.TogglePlayPause;
begin
  if FVlc.IsPlaying then
  begin
    FVlc.Pause;
    LoadPNGToControl(FButtonDir + 'play.png', sbPlay);
  end
  else
  begin
    FVlc.Play;
    LoadPNGToControl(FButtonDir + 'stop-playing.png', sbPlay);
  end;
end;

procedure TfrmStickyForm.sbFullScreenClick(Sender: TObject);
var
  oldParent: TWinControl;
  oldAlign: TAlign;
  wasPlaying: Boolean;
  currentPosition: Int64;
  oldOnClick: TNotifyEvent;
  oldOnDblClick: TNotifyEvent;
  oldOnMouseDown: TMouseEvent;
  oldOnMouseMove: TMouseMoveEvent;
  oldOnMouseUp: TMouseEvent;
  oldOnKeyDown: TKeyEvent;
  oldOnKeyPress: TKeyPressEvent;
  oldOnKeyUp: TKeyEvent;
begin
  oldParent := FVlc.Parent;
  oldAlign := FVlc.Align;
  wasPlaying := FVlc.IsPlaying;

  oldOnClick := FVlc.OnClick;
  oldOnDblClick := FVlc.OnDblClick;
  oldOnMouseDown := FVlc.OnMouseDown;
  oldOnMouseMove := FVlc.OnMouseMove;
  oldOnMouseUp := FVlc.OnMouseUp;

  aFullScreenForm := TFullScreenForm.Create(nil);
  try
    aFullScreenForm.SetBounds(Monitor.Left, Monitor.Top, Monitor.Width, Monitor.Height);

    aFullScreenForm.OnKeyDown := FullScreenFormKeyDown;
    aFullScreenForm.OnDblClick := FullScreenFormDblClick;
    aFullScreenForm.KeyPreview := True;

    if wasPlaying then
      FVlc.Pause;

    FVlc.OnClick := oldOnClick;
    FVlc.OnDblClick := oldOnDblClick;
    FVlc.OnMouseDown := oldOnMouseDown;
    FVlc.OnMouseMove := oldOnMouseMove;
    FVlc.OnMouseUp := oldOnMouseUp;

    FVlc.Align := alNone;
    FVlc.SetBounds(0, 0, Monitor.Width, Monitor.Height);
    FVlc.Show;

    if wasPlaying then
    begin
      Sleep(200);
      FVlc.Play;
    end;

    aFullScreenForm.ShowModal;

  finally
    if FVlc.IsPlaying then
      FVlc.Pause;

    FVlc.OnClick := oldOnClick;
    FVlc.OnDblClick := oldOnDblClick;
    FVlc.OnMouseDown := oldOnMouseDown;
    FVlc.OnMouseMove := oldOnMouseMove;
    FVlc.OnMouseUp := oldOnMouseUp;

    FVlc.Align := alNone;
    FVlc.SetBounds(2, 2, Panel_VLC_Player.Width - 4, Panel_VLC_Player.Height - 4);
    FVlc.Align := oldAlign;

    FVlc.Show;

    if wasPlaying then
    begin
      Sleep(200);
      FVlc.Play;
    end;

    Panel_VLC_Player.Invalidate;

    aFullScreenForm.Free;
  end;
end;

procedure TfrmStickyForm.tvVolumeChange(Sender: TObject);
begin
  FVlc.Volume := tvVolume.Position;
end;

procedure TfrmStickyForm.sbPlayClick(Sender: TObject);
var
  idx: Integer;
begin
  if Fvlc.IsPlaying then
  begin
    Fvlc.Stop;
    LoadPNGToControl(FButtonDir + 'play.png', sbPlay);
    FVlc.SetDisplayTextVisible(False);
  end else
  begin
    idx := lbChannels.ItemIndex;
    if (idx < 0) and (FChannels <> nil) and (FChannels.Count > 0) then
      idx := 0;

    if (idx >= 0) and (idx < FChannels.Count) then
    begin
      PlayChannelByIndex(idx);
      LoadPNGToControl(FButtonDir + 'stop-playing.png', sbPlay);
    end;
  end;
  sbPlay.Invalidate;
  sbPlay.Update;
end;

procedure TfrmStickyForm.sbVolumeClick(Sender: TObject);
begin
  if FVlc.IsMuted then
  begin
    FVlc.Unmute;
    LoadPNGToControl(FButtonDir + 'volume.png', sbVolume);
    FVlc.ShowTopImage := False;
  end
  else
  begin
    FVlc.Mute;
    LoadPNGToControl(FButtonDir + 'volume-mute.png', sbVolume);
    FVlc.ShowTopImage := True;
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
