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
  public
    Name: string;
    TVGID: string;
    LogoURL: string;
    StreamURL: string;
    TVGShift: Integer;
    GroupTitle: string;
    // EPG fields (history)
    CurrentTitle: string;
    CurrentStart: TDateTime;
    CurrentStop: TDateTime;

    EPG: TList<TEPGItem>;
    constructor Create;
    destructor Destroy; override;
    property CustomAttributes: TStringList read FCustomAttributes write FCustomAttributes;
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
    FLogoMap: TDictionary<string, Integer>; // ключ = LowerCase(LogoURL)
    FParentChanName: WideString;
    FParentChanHandle: HWND;
    FGeneration: Integer;


    procedure DrawLogo(Canvas: TCanvas; const Rect: TRect; const LogoPath: string);
    function GetLogoFilePath(const Channel: TChannelInfo): string;
    procedure QueueDownloadLogo(const Channel: TChannelInfo);
    function GetLogoIndexForLogoURL(const ALogoURL: string): Integer;
    function MakeLogoFileName(const Channel: TChannelInfo): string;

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


    function CleanChannelName(const DirtyName: string): string;
    procedure LoadSettings;
    procedure ParseExistingEPGWithIndex(const XmlFilePath: string; UrlIndex: Integer);
    procedure ParseExistingEPG(const XmlFilePath: string; UrlIndex: Integer);
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
    { Public declarations }
  end;

var
  frmStickyForm: TfrmStickyForm;
  ImageList: TImageList;
  IsFullScreen: Boolean;
  FEpgUrls: TStringList;
  FEPGTimer: TTimer;
  FEPGStartTimer: TTimer; // timer to delay EPG start
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
end;

destructor TChannelInfo.Destroy;
begin
  EPG.Free;
  FCustomAttributes.Free;
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
    if frmSettings.cbLog.Checked then
    begin
      AssignFile(LogFile, LogPath);
      if FileExists(LogPath) then
        Append(LogFile)
      else
         Rewrite(LogFile);
        Writeln(LogFile, FormatDateTime('[dd.mm.yyyy hh:nn:ss]', Now) + ' - ' + Msg);
        CloseFile(LogFile);
    end;
  except
    // не даём логированию упасть
  end;
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
  WriteDebugLog('--- Воспроизведение канала: ' + Channel.Name + ' ---');
  WriteDebugLog('URL: ' + Channel.StreamURL);

  if Channel.StreamURL = '' then
    Exit;

  try
    WriteDebugLog('Запуск потока...');
    FVlc.LoadMedia(Channel.StreamURL);
    PlayerStatus.Enabled := Enabled;
    FVlc.Play;
  except
    on E: Exception do
    begin
      WriteDebugLog('Ошибка воспроизведения: ' + E.Message);
    end;
  end;
end;


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
  FVlc.Volume := tvVolume.Position;
  FVlc.SetDisplayText('Громкость ' + IntToStr(tvVolume.Position) + '%');
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
end;

function TfrmStickyForm.IsValidPNG(const MS: TMemoryStream): Boolean;
var
  buf: array[0..7] of Byte;
begin
  Result := False;
  if MS.Size < 8 then Exit;

  try
    MS.Position := 0;
    MS.ReadBuffer(buf, SizeOf(buf));
    MS.Position := 0;

    Result := (buf[0] = $89) and (buf[1] = $50) and (buf[2] = $4E) and (buf[3] = $47) and
              (buf[4] = $0D) and (buf[5] = $0A) and (buf[6] = $1A) and (buf[7] = $0A);
  except
    Result := False;
  end;
end;






procedure TfrmStickyForm.UseDefaultLogo(const Channel: TChannelInfo);
var
  DefaultLogoPath: string;
  LogoIndex: Integer;
begin
  DefaultLogoPath := FCacheDir + 'NoLogo.png';

  if FileExists(DefaultLogoPath) then
  begin
    // Для старого TDictionary используем Integer как индекс
    // Предполагаем, что -1 означает "нет логотипа"
    LogoIndex := 0; // или любое другое значение, которое вы используете для дефолтного лого

    try
      FLogoMap.Add(Channel.TVGID, LogoIndex);
    except
      on E: EListError do
      begin
        // Игнорируем ошибку дубликата ключа
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
  end
  else
  begin
    WriteDebugLog('Дефолтный логотип не найден: ' + DefaultLogoPath);
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

  WriteDebugLog('=== НАЧАЛО ЗАГРУЗКИ ЛОГОТИПА ===');
  WriteDebugLog('Канал: ' + Channel.Name);
  WriteDebugLog('TVGID: ' + Channel.TVGID);
  WriteDebugLog('LogoURL: ' + Channel.LogoURL);

  if lbChannels.Items.IndexOf(Channel.Name) < 0 then
  begin
    WriteDebugLog('❌ Канал не найден в списке');
    Exit;
  end;

  if Channel.TVGID <> '' then
    FileName := MakeSafeFileName(Channel.TVGID) + '.png'
  else
    FileName := MakeSafeFileName(Channel.Name) + '.png';

  DestPath := TPath.Combine(LogoDir, FileName);
  WriteDebugLog('Полный путь: ' + DestPath);

  // ПРОВЕРКА НА СУЩЕСТВОВАНИЕ В КЭШЕ
  if FileExists(DestPath) then
  begin
    WriteDebugLog('✅ Логотип уже существует в кэше');

    // Используем индекс 1 для существующих логотипов
    LogoIndex := 1;

    try
      FLogoMap.Add(Channel.TVGID, LogoIndex);
    except
      on E: EListError do
      begin
        // Игнорируем ошибку дубликата ключа
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
    WriteDebugLog('❌ URL логотипа пустой');
    UseDefaultLogo(Channel);
    Exit;
  end;

  if not (SafeLogoURL.StartsWith('http://', True) or SafeLogoURL.StartsWith('https://', True)) then
  begin
    WriteDebugLog('❌ Неверный URL логотипа: ' + SafeLogoURL);
    UseDefaultLogo(Channel);
    Exit;
  end;

  WriteDebugLog('🚀 Запускаем скачивание через FileDownloader: ' + SafeLogoURL);
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
          WriteDebugLog('📥 Скачиваем через FileDownloader: ' + SafeLogoURL);

          LocalFile := Downloader.EnsureFileAvailableEx(SafeLogoURL, WasDownloaded);

          if LocalFile <> '' then
          begin
            WriteDebugLog('✅ FileDownloader успешно скачал: ' + LocalFile);
            WriteDebugLog('📊 Было скачано: ' + BoolToStr(WasDownloaded, True));

            Success := True;

            if not SameText(LocalFile, DestPath) then
            begin
              try
                if FileExists(DestPath) then
                  DeleteFile(DestPath);
                if RenameFile(LocalFile, DestPath) then
                begin
                  WriteDebugLog('✅ Файл переименован в: ' + DestPath);
                  LocalFile := DestPath;
                end
                else
                begin
                  WriteDebugLog('⚠️ Не удалось переименовать файл, используем оригинальный путь');
                end;
              except
                on E: Exception do
                  WriteDebugLog('⚠️ Ошибка переименования: ' + E.Message);
              end;
            end;
          end
          else
          begin
            WriteDebugLog('❌ FileDownloader не смог скачать файл');
          end;

        finally
          Downloader.Free;
        end;

      except
        on E: Exception do
        begin
          WriteDebugLog('💥 Ошибка в FileDownloader: ' + E.Message);
        end;
      end;

      // ОБНОВЛЯЕМ ИНТЕРФЕЙС
      if Success then
      begin
        LogoIndex := 1; // индекс для скачанных логотипов

        try
          FLogoMap.Add(Channel.TVGID, LogoIndex);
        except
          on E: EListError do
          begin
            // Игнорируем ошибку дубликата ключа
          end;
        end;

        TThread.Queue(nil,
          procedure
          begin
            if localGen = FGeneration then
            begin
              try
                WriteDebugLog('🔄 Обновляем UI для: ' + Channel.Name);
                var idx := lbChannels.Items.IndexOf(Channel.Name);
                if idx >= 0 then
                begin
                  lbChannels.Invalidate;
                  WriteDebugLog('✅ Логотип добавлен для: ' + Channel.Name);
                end;
              except
                on E: Exception do
                begin
                  WriteDebugLog('💥 Ошибка обновления UI: ' + E.Message);
                  UseDefaultLogo(Channel);
                end;
              end;
            end;
          end
        );
      end
      else
      begin
        WriteDebugLog('❌ Не удалось загрузить логотип');
        TThread.Queue(nil,
          procedure
          begin
            UseDefaultLogo(Channel);
          end
        );
      end;

      WriteDebugLog('=== ЗАВЕРШЕНИЕ ПОТОКА ЗАГРУЗКИ ===');
    end
  ).Start;
end;

function TfrmStickyForm.GetLogoFilePath(const Channel: TChannelInfo): string;
var
  LogoIndex: Integer;
  LogoPath: string;
begin
  Result := FCacheDir + 'NoLogo.png'; // значение по умолчанию

  if FLogoMap.TryGetValue(Channel.TVGID, LogoIndex) then
  begin
    WriteDebugLog('GetLogoFilePath: найден индекс ' + IntToStr(LogoIndex) + ' для ' + Channel.TVGID);

    if LogoIndex = 1 then // логотип канала
    begin
      // Формируем путь к логотипу канала
      if Channel.TVGID <> '' then
        LogoPath := path + 'IPTV_Plugin\logo-channels\' + MakeSafeFileName(Channel.TVGID) + '.png';

      WriteDebugLog('GetLogoFilePath: ищем файл по пути: ' + LogoPath);

      // Проверяем существует ли файл
      if FileExists(LogoPath) then
      begin
        Result := LogoPath;
        WriteDebugLog('GetLogoFilePath: используется кастомный логотип - ' + LogoPath);
      end
      else
      begin
          Result := FCacheDir + 'NoLogo.png';
          WriteDebugLog('GetLogoFilePath: кастомный логотип не существует, используется дефолтный');
          WriteDebugLog('GetLogoFilePath: TVGID: ' + Channel.TVGID);
          WriteDebugLog('GetLogoFilePath: Name: ' + Channel.Name);
          WriteDebugLog('GetLogoFilePath: Ожидаемый путь: ' + LogoPath);
      end;
    end
    else
    begin
      WriteDebugLog('GetLogoFilePath: используется дефолтный логотип (индекс ' + IntToStr(LogoIndex) + ')');
    end;
  end
  else
  begin
    WriteDebugLog('GetLogoFilePath: ключ не найден в FLogoMap - ' + Channel.TVGID);
  end;
end;

procedure TfrmStickyForm.DrawLogo(Canvas: TCanvas; const Rect: TRect; const LogoPath: string);
var
  PNG: TPngImage;
  ScaleX, ScaleY, Scale: Double;
  NewWidth, NewHeight: Integer;
  X, Y: Integer;
  DestRect: TRect;
begin
  if not FileExists(LogoPath) then
  begin
    WriteDebugLog('DrawLogo: файл не существует - ' + LogoPath);
    Exit;
  end;

  PNG := TPngImage.Create;
  try
    try
      PNG.LoadFromFile(LogoPath);
      WriteDebugLog('DrawLogo: загружен PNG - ' + LogoPath + ' размер: ' + IntToStr(PNG.Width) + 'x' + IntToStr(PNG.Height));

      // Рассчитываем масштаб для сохранения пропорций
      ScaleX := (Rect.Right - Rect.Left) / PNG.Width;
      ScaleY := (Rect.Bottom - Rect.Top) / PNG.Height;
      Scale := Min(ScaleX, ScaleY); // Используем минимальный масштаб для сохранения пропорций

      NewWidth := Round(PNG.Width * Scale);
      NewHeight := Round(PNG.Height * Scale);

      // Центрируем изображение
      X := Rect.Left + ((Rect.Right - Rect.Left) - NewWidth) div 2;
      Y := Rect.Top + ((Rect.Bottom - Rect.Top) - NewHeight) div 2;

      // Создаем Rect правильно - используем функцию Rect()
      DestRect := System.Classes.Rect(X, Y, X + NewWidth, Y + NewHeight);

      // Устанавливаем высокое качество отрисовки
      SetStretchBltMode(Canvas.Handle, HALFTONE);
      SetBrushOrgEx(Canvas.Handle, 0, 0, nil);

      // Рисуем PNG напрямую с сохранением прозрачности
      PNG.Draw(Canvas, DestRect);

      WriteDebugLog(Format('DrawLogo: успешно отрисован - %s, масштаб: %.2f, новый размер: %dx%d',
        [LogoPath, Scale, NewWidth, NewHeight]));

    except
      on E: Exception do
      begin
        WriteDebugLog('Ошибка отрисовки логотипа: ' + E.Message);
      end;
    end;
  finally
    PNG.Free;
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

  WriteDebugLog('Очистка названия: "' + DirtyName + '" -> "' + CleanName + '"');

  Result := CleanName;
end;

procedure TfrmStickyForm.ParseExistingEPG(const XmlFilePath: string; UrlIndex: Integer);
var
  MS: TMemoryStream;
begin
  WriteDebugLog('ParseExistingEPG: ' + XmlFilePath + ', индекс: ' + IntToStr(UrlIndex));

  if not FileExists(XmlFilePath) then
  begin
    WriteDebugLog('Файл не существует: ' + XmlFilePath);
    Exit;
  end;

  MS := TMemoryStream.Create;
  try
    try
      MS.LoadFromFile(XmlFilePath);
      ParseEPGStream(MS);
      WriteDebugLog('Успешно распарсен существующий EPG: ' + XmlFilePath);
    except
      on E: Exception do
      begin
        WriteDebugLog('Ошибка парсинга существующего EPG: ' + E.Message);
        // Если парсинг существующего файла не удался, скачиваем заново
        WriteDebugLog('Пробуем скачать EPG заново: ' + FEpgUrls[UrlIndex]);
        DownloadAndParseEPG(FEpgUrls[UrlIndex]);
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
begin
  Inc(FGeneration);
  FLogoMap.Clear;
  // Больше не нужно сбрасывать ImageList

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

      // ищем заголовок #EXTM3U
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

        // пропускаем пустые строки
        if Line = '' then
        begin
          Inc(i);
          Continue;
        end;

        // Обрабатываем #EXTGRP перед #EXTINF
        if Line.StartsWith('#EXTGRP:', True) then
        begin
          CurrentExtGrp := Trim(Copy(Line, 9, MaxInt));
          WriteDebugLog('Найдена группа #EXTGRP: ' + CurrentExtGrp);
          Inc(i);
          Continue;
        end;

        // если нашли #EXTINF — начинаем новый канал
        if Line.StartsWith('#EXTINF', True) then
        begin
          Attrs := TStringList.Create;
          VLCOpts := TStringList.Create;
          SkipChannel := False;
          FoundExtGrp := '';

          try
            // Парсим атрибуты #EXTINF
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
              Match := Match.NextMatch;
            end;

            // Проверяем TVG-ID
            if Attrs.Values['tvg-id'] = '' then
            begin
              SkipChannel := True;
            end;

            // Имя канала
            if Pos(',', Line) > 0 then
            begin
              Name := Trim(Copy(Line, Pos(',', Line) + 1, MaxInt));
              Name := CleanChannelName(Name);
            end
            else
              Name := '';

            TempGroup := Attrs.Values['group-title'];

            // Переходим к следующей строке
            Inc(i);

            // Ищем #EXTGRP и #EXTVLCOPT сразу после #EXTINF
            while (i < SL.Count) do
            begin
              Line := Trim(SL[i]);
              if Line = '' then
              begin
                Inc(i);
                Continue;
              end;

              if not Line.StartsWith('#') then
                Break; // Дошли до URL

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
                end;
                Inc(i);
              end
              else
              begin
                Break; // Другие теги - выходим
              end;
            end;

            // Ищем URL
            StreamURL := 'null';
            if i < SL.Count then
            begin
              StreamURL := Trim(SL[i]);
              Inc(i); // Переходим после URL
            end;

            // Создаем канал если не пропускаем
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

              // Определяем группу
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
  if not FVlc.IsPlaying then
    Exit;

  // Получаем текущий URL воспроизведения
  currentUrl := FVlc.GetCurrentMediaURL;
  if currentUrl = '' then
    currentUrl := FVlc.MediaURL;

  // Ищем канал с этим URL
  ch := nil;
  for i := 0 to FChannels.Count - 1 do
  begin
    if (FChannels[i].StreamURL = currentUrl) then
    begin
      ch := FChannels[i];
      Break;
    end;
  end;

  if not Assigned(ch) then
  begin
    OutputDebugString(PChar('Канал не найден для URL: ' + currentUrl));
    Exit;
  end;

  // ПРАВИЛЬНО: Ищем текущую программу с учетом TVGShift
  nowDT := Now;
  foundCurrent := False;
  cur := 'Нет актуальных данных';
  timeRange := '';

  if Assigned(ch.EPG) then
  begin
    for j := 0 to ch.EPG.Count - 1 do
    begin
      // Применяем смещение к временам EPG программ
      epgStartDT := IncHour(ch.EPG[j].StartDT, ch.TVGShift);
      epgStopDT := IncHour(ch.EPG[j].StopDT, ch.TVGShift);

      // Ищем по реальному текущему времени
      if (epgStartDT <= nowDT) and (epgStopDT > nowDT) then
      begin
        cur := ch.EPG[j].Title;
        // Формируем диапазон времени из СДВИНУТЫХ времен
        timeRange := FormatDateTime('hh:nn', epgStartDT) + ' - ' +
                     FormatDateTime('hh:nn', epgStopDT);
        foundCurrent := True;

        // Обновляем информацию о текущей программе в канале
        ch.CurrentTitle := cur;
        ch.CurrentStart := epgStartDT;
        ch.CurrentStop := epgStopDT;
        Break;
      end;
    end;
  end;

  // Если не нашли текущую программу
  if not foundCurrent then
  begin
    ch.CurrentTitle := '';
    ch.CurrentStart := 0;
    ch.CurrentStop := 0;
  end;

  // Очищаем название от времени в скобках (если оно там есть)
  var cleanTitle := cur;
  var p := Pos('(', cleanTitle);
  if p > 0 then
    cleanTitle := Trim(Copy(cleanTitle, 1, p - 1));

  // Формируем текст для отображения
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

  FVlc.SetDisplayText(displayText);
end;


procedure TfrmStickyForm.OnPlaying(Sender: TObject);
begin
  EpgStatus;
end;

procedure TfrmStickyForm.OnBuffering(Sender: TObject; cache: Single);
begin
  if Trunc(cache) < 100 then
  else
    EpgStatus;
end;

procedure TfrmStickyForm.OnError(Sender: TObject);
begin
  LoadPNGToControl(FButtonDir + 'play.png', sbPlay);
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

  // Создаем папку для логотипов
//  FCacheDir := ExtractFilePath(ParamStr(0)) + 'Plugins\IPTV_Plugin\logo-channels\';
//  ForceDirectories(FCacheDir); // ← ДОБАВЬТЕ ЭТУ СТРОКУ

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

  DownloadM3UFromURL(frmSettings.edURLM3U.Text);

  NoLogoPath := ExtractFilePath(ParamStr(0)) + 'Plugins\IPTV_Plugin\logo-channels\NoLogo.png';

  // Сначала путь к библиотеке
  FVlc.LibPath := ExtractFilePath(ParamStr(0)) + 'Plugins\IPTV_Plugin';
  FVlc.ShowTopImage := False;
  FVlc.EnableMouseEvents;
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

  // cleanup timers if any
  FreeAndNil(FEPGTimer);
  FreeAndNil(FEPGStartTimer);
  FreeAndNil(FullScreenForm);
  FVlc.Free;
end;

procedure TfrmStickyForm.FormShow(Sender: TObject);
begin
  lbChannels.Style := lbOwnerDrawFixed;
  lbChannels.ItemHeight := 80; // ← ДОБАВЬТЕ ЭТУ СТРОКУ

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

    FVlc.TopImage.LoadFromFile(FButtonDir + 'volume-mute-player.png');
  end;
    FVlc.Unmute;

  if not Assigned(lbChannels.OnDrawItem) then
    lbChannels.OnDrawItem := lbChannelsDrawItem;
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



procedure TfrmStickyForm.TimeEpgStatusTimer(Sender: TObject);
begin
  if FVlc.IsPlaying then
   EpgStatus else
   FVlc.SetDisplayText('');
end;

procedure TfrmStickyForm.PlayerStatusTimer(Sender: TObject);
var
  CurrentProgress: Integer;
begin
  if FVlc.IsLoading then
  begin
    CurrentProgress := FVlc.GetActualLoadingProgress;

    // Обновляем UI

    FVlc.SetDisplayText(Format('Состояние: %s',
      [FVLC.GetPlayerStatus]));



  if FVlc.IsPlaying then
    PlayerStatus.Enabled := false
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
    end;
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
  LeftMargin: Integer; // Добавляем переменную для отступа слева
begin
  if (Index < 0) or (Index >= FChannels.Count) then Exit;

  ch := FChannels[Index];
  WriteDebugLog('lbChannelsDrawItem: отрисовка канала ' + ch.Name + ' (индекс ' + IntToStr(Index) + ')');

  // Определяем отступ слева (в пикселях)
  LeftMargin := 10; // Можно изменить на нужное значение

  // Определяем цвета текста
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

  // Получаем путь к логотипу
  LogoPath := GetLogoFilePath(ch);
  WriteDebugLog('lbChannelsDrawItem: путь к логотипу - ' + LogoPath);

  if (LogoPath = '') or not FileExists(LogoPath) then
  begin
    LogoPath := FCacheDir + 'NoLogo.png'; // Дефолтный логотип
    WriteDebugLog('lbChannelsDrawItem: используется дефолтный логотип');
  end;

  // Отрисовываем логотип с правильным масштабированием И ОТСТУПОМ СЛЕВА
  LogoRect := Rect;
  LogoRect.Left := LogoRect.Left + LeftMargin; // ДОБАВЛЯЕМ ОТСТУП СЛЕВА
  LogoRect.Right := LogoRect.Left + 50; // Фиксированная ширина для логотипа
  LogoRect.Bottom := LogoRect.Top + 50; // Фиксированная высота для логотипа

  // Центрируем по вертикали
  LogoRect.Top := Rect.Top + (Rect.Bottom - Rect.Top - 50) div 2;
  if LogoRect.Top < Rect.Top + 2 then
    LogoRect.Top := Rect.Top + 2;
  LogoRect.Bottom := LogoRect.Top + 50;

  // ПРАВИЛЬНОЕ МАСШТАБИРОВАНИЕ PNG с сохранением качества
  if FileExists(LogoPath) then
  begin
    PNG := TPngImage.Create;
    try
      try
        PNG.LoadFromFile(LogoPath);

        // Рассчитываем масштаб для сохранения пропорций
        ScaleX := (LogoRect.Right - LogoRect.Left) / PNG.Width;
        ScaleY := (LogoRect.Bottom - LogoRect.Top) / PNG.Height;
        Scale := Min(ScaleX, ScaleY); // Используем минимальный масштаб для сохранения пропорций

        NewWidth := Round(PNG.Width * Scale);
        NewHeight := Round(PNG.Height * Scale);

        // Центрируем изображение
        X := LogoRect.Left + ((LogoRect.Right - LogoRect.Left) - NewWidth) div 2;
        Y := LogoRect.Top + ((LogoRect.Bottom - LogoRect.Top) - NewHeight) div 2;

        // Создаем Rect правильно - используем функцию Rect()
        DestRect := System.Classes.Rect(X, Y, X + NewWidth, Y + NewHeight);

        // Устанавливаем высокое качество отрисовки
        SetStretchBltMode(lbChannels.Canvas.Handle, HALFTONE);
        SetBrushOrgEx(lbChannels.Canvas.Handle, 0, 0, nil);

        // Рисуем PNG напрямую с сохранением прозрачности
        PNG.Draw(lbChannels.Canvas, DestRect);

        WriteDebugLog(Format('Логотип отмасштабирован: %dx%d -> %dx%d (масштаб: %.2f)',
          [PNG.Width, PNG.Height, NewWidth, NewHeight, Scale]));

      except
        on E: Exception do
        begin
          WriteDebugLog('Ошибка загрузки логотипа: ' + E.Message);
        end;
      end;
    finally
      PNG.Free;
    end;
  end;

  // Остальной код с учетом отступа слева
  nameLeft := LogoRect.Right + 8; // Отступ после логотипа (уже с учетом LeftMargin)
  oldFontSize := lbChannels.Canvas.Font.Size;

  // Название канала
  lbChannels.Canvas.Font.Color := textColor;
  lbChannels.Canvas.Font.Style := [fsBold];
  lbChannels.Canvas.TextOut(nameLeft, Rect.Top + 6, ch.Name);

  // Группа канала
  lbChannels.Canvas.Font.Size := oldFontSize - 1;
  lbChannels.Canvas.Font.Style := [];
  lbChannels.Canvas.Font.Color := grayTextColor;

  if ch.GroupTitle <> '' then
    lbChannels.Canvas.TextOut(nameLeft, Rect.Top + 24, 'Группа: ' + ch.GroupTitle)
  else
    lbChannels.Canvas.TextOut(nameLeft, Rect.Top + 24, 'Группа: не указана');

  // Восстанавливаем размер шрифта
  lbChannels.Canvas.Font.Size := oldFontSize;

  // ПРАВИЛЬНАЯ обработка EPG с учетом TVGShift
  hasCurr := False;
  nowDT := Now; // Текущее реальное время

  // Форматируем текст сдвига
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
      // ПРАВИЛЬНО: сдвигаем времена EPG программ, а не текущее время
      epgStartDT := IncHour(ch.EPG[i].StartDT, ch.TVGShift);
      epgStopDT := IncHour(ch.EPG[i].StopDT, ch.TVGShift);

      // Ищем программу по реальному текущему времени
      if (epgStartDT <= nowDT) and (epgStopDT > nowDT) then
      begin
        currEPG := ch.EPG[i];
        // Для отображения используем сдвинутые времена
        currEPG.StartDT := epgStartDT;
        currEPG.StopDT := epgStopDT;

        if i + 1 < ch.EPG.Count then
        begin
          nextEPG := ch.EPG[i + 1];
          // Сдвигаем и следующую программу для отображения
          nextEPG.StartDT := IncHour(nextEPG.StartDT, ch.TVGShift);
          nextEPG.StopDT := IncHour(nextEPG.StopDT, ch.TVGShift);
        end;

        hasCurr := True;
        Break;
      end;
    end;
  end;

  // Уменьшаем шрифт для EPG
  lbChannels.Canvas.Font.Size := oldFontSize - 1;
  lbChannels.Canvas.Font.Style := [];
  lbChannels.Canvas.Font.Color := grayTextColor;

  R := Rect;
  R.Top := Rect.Top + 42;

  if hasCurr then
  begin
    // Отображаем сдвинутые времена
    if ch.TVGShift <> 0 then
    begin
      lbChannels.Canvas.TextOut(nameLeft, R.Top,
        Format('%s (%s-%s) [сдвиг %s]', [
          currEPG.Title,
          FormatDateTime('hh:nn', currEPG.StartDT),  // Уже сдвинутое время
          FormatDateTime('hh:nn', currEPG.StopDT),   // Уже сдвинутое время
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

  // Восстанавливаем размер шрифта
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

procedure TfrmStickyForm.ParseExistingEPGWithIndex(const XmlFilePath: string; UrlIndex: Integer);
var
  MS: TMemoryStream;
begin
  WriteDebugLog('ParseExistingEPGWithIndex: ' + XmlFilePath);

  if not FileExists(XmlFilePath) then
  begin
    WriteDebugLog('Файл не существует: ' + XmlFilePath);
    Exit;
  end;

  MS := TMemoryStream.Create;
  try
    try
      MS.LoadFromFile(XmlFilePath);
      ParseEPGStream(MS);
      WriteDebugLog('Успешно распарсен существующий EPG: ' + XmlFilePath);
    except
      on E: Exception do
      begin
        WriteDebugLog('Ошибка парсинга существующего EPG: ' + E.Message);
        // Если парсинг существующего файла не удался, скачиваем заново
        WriteDebugLog('Пробуем скачать EPG заново: ' + FEpgUrls[UrlIndex]);
        DownloadAndParseEPG(FEpgUrls[UrlIndex]);
      end;
    end;
  finally
    MS.Free;
  end;
end;

procedure TfrmStickyForm.DownloadAndParseAllEPG;
var
  i, total: Integer;
  FilePath, XmlPath: string;
  FileAgeHours: Double;
  EpgUrl: string;
begin
  WriteDebugLog('Запуск DownloadAndParseAllEPG');
  ClearCurrentPrograms;

  // Определяем источник EPG в зависимости от состояния чекбокса
  if frmSettings.cbJTV.Checked then
  begin
    // Используем плейлист для получения EPG
    if (FEpgUrls = nil) or (FEpgUrls.Count = 0) then
    begin
      WriteDebugLog('Нет EPG URL из плейлиста');
      Exit;
    end;
    WriteDebugLog('Используем EPG из плейлиста');
  end
  else
  begin
    // Используем пользовательский EPG из deEpg.text
    if Trim(frmSettings.deEpg.Text) = '' then
    begin
      WriteDebugLog('Нет пользовательского EPG URL');
      Exit;
    end;

    // Создаем временный список с одним URL
    if FEpgUrls = nil then
      FEpgUrls := TStringList.Create
    else
      FEpgUrls.Clear;

    FEpgUrls.Add(frmSettings.deEpg.Text);
    WriteDebugLog('Используем пользовательский EPG: ' + frmSettings.deEpg.Text);
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
      // Получаем текущий URL
      EpgUrl := FEpgUrls[i];

      // Проверяем возраст существующего файла EPG
      FilePath := path+'IPTV_Plugin\epg\' +
                  StringReplace(EpgUrl, 'https://', '', [rfIgnoreCase]);
      FilePath := StringReplace(FilePath, 'http://', '', [rfIgnoreCase]);
      FilePath := StringReplace(FilePath, '/', PathDelim, [rfReplaceAll]);

      XmlPath := ChangeFileExt(FilePath, '.xml');

      // Если файл существует и ему меньше 24 часов - парсим существующий
      if FileExists(XmlPath) then
      begin
        FileAgeHours := (Now - FileDateToDateTime(FileAge(XmlPath))) * 24;
        WriteDebugLog('Файл EPG существует: ' + XmlPath + ', возраст: ' +
                      FormatFloat('0.00', FileAgeHours) + ' часов');

        if FileAgeHours < 24 then
        begin
          WriteDebugLog('Файл моложе 24 часов, парсим существующий: ' + XmlPath);
          ParseExistingEPG(XmlPath, i); // Передаем индекс i
          Continue; // Переходим к следующему URL
        end
        else
        begin
          WriteDebugLog('Файл старше 24 часов, скачиваем заново: ' + EpgUrl);
        end;
      end
      else
      begin
        WriteDebugLog('Файл EPG не существует, скачиваем: ' + EpgUrl);
      end;

      WriteDebugLog('Загрузка EPG: ' + EpgUrl);
      DownloadAndParseEPG(EpgUrl);

    except
      on E: Exception do
      begin
        WriteDebugLog('Ошибка загрузки EPG: ' + E.Message);
      end;
    end;

    Sleep(100);
  end;

  // Если использовали временный список для пользовательского EPG, очищаем его
  if not frmSettings.cbJTV.Checked and (FEpgUrls <> nil) then
    FEpgUrls.Clear;

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
  FilePath := path+'IPTV_Plugin\epg\' +
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
            // Удаляем временный gz файл после распаковки
            DeleteFile(FilePath);
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

procedure TfrmStickyForm.sbOpenClick(Sender: TObject);

begin
  frmSettings.ShowModal;

  if not Assigned(frmSettings) then else
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
      (Sender as TForm).ModalResult := mrCancel; // Выход по ESC
    VK_SPACE:
      TogglePlayPause; // Пауза/воспроизведение по пробелу
    VK_UP:
      VolumeUp; // Увеличить громкость
    VK_DOWN:
      VolumeDown; // Уменьшить громкость
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
  (Sender as TForm).ModalResult := mrCancel; // Выход по двойному клику
//  FullScreenForm.Close;
end;

// Вспомогательные методы для управления в полноэкранном режиме
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

  // Переменные для сохранения событий
  oldOnClick: TNotifyEvent;
  oldOnDblClick: TNotifyEvent;
  oldOnMouseDown: TMouseEvent;
  oldOnMouseMove: TMouseMoveEvent;
  oldOnMouseUp: TMouseEvent;
  oldOnKeyDown: TKeyEvent;
  oldOnKeyPress: TKeyPressEvent;
  oldOnKeyUp: TKeyEvent;
begin
  // СОХРАНЯЕМ СОСТОЯНИЕ И ВСЕ СОБЫТИЯ
  oldParent := FVlc.Parent;
  oldAlign := FVlc.Align;
  wasPlaying := FVlc.IsPlaying;
  currentPosition := FVlc.GetPosition;

  // Сохраняем все обработчики событий
  oldOnClick := FVlc.OnClick;
  oldOnDblClick := FVlc.OnDblClick;
  oldOnMouseDown := FVlc.OnMouseDown;
  oldOnMouseMove := FVlc.OnMouseMove;
  oldOnMouseUp := FVlc.OnMouseUp;


  // Создаем полноэкранную форму
  aFullScreenForm := TFullScreenForm.Create(nil);
  try
    aFullScreenForm.SetBounds(Monitor.Left, Monitor.Top, Monitor.Width, Monitor.Height);

    // НАСТРАИВАЕМ ОБРАБОТЧИКИ СОБЫТИЙ ДЛЯ ПОЛНОЭКРАННОЙ ФОРМЫ
    aFullScreenForm.OnKeyDown := FullScreenFormKeyDown;
    aFullScreenForm.OnDblClick := FullScreenFormDblClick;
    aFullScreenForm.KeyPreview := True; // Важно: форма получает события первой

    // ПЕРЕНОС В ПОЛНОЭКРАННЫЙ РЕЖИМ
    if wasPlaying then
      FVlc.Stop;

    // Меняем родителя
    FVlc.SetNewParent(aFullScreenForm);

    // ВОССТАНАВЛИВАЕМ ВСЕ СОБЫТИЯ НА НОВОЙ ФОРМЕ
    FVlc.OnClick := oldOnClick;
    FVlc.OnDblClick := oldOnDblClick;
    FVlc.OnMouseDown := oldOnMouseDown;
    FVlc.OnMouseMove := oldOnMouseMove;
    FVlc.OnMouseUp := oldOnMouseUp;


    // Устанавливаем полноэкранные размеры
    FVlc.Align := alNone;
    FVlc.SetBounds(0, 0, Monitor.Width, Monitor.Height);
    FVlc.Show;

    // Восстанавливаем воспроизведение
    if wasPlaying then
    begin
      Sleep(200);
      FVlc.Play;
    end;

    // Показываем полноэкранную форму МОДАЛЬНО (только ShowModal)
    aFullScreenForm.ShowModal;

  finally
    // ВОЗВРАТ ИЗ ПОЛНОЭКРАННОГО РЕЖИМА
    if FVlc.IsPlaying then
      FVlc.Stop;

    // Возвращаем на исходную панель
    FVlc.SetNewParent(Panel_VLC_Player);

    // ВОССТАНАВЛИВАЕМ ВСЕ СОБЫТИЯ НА ИСХОДНОМ РОДИТЕЛЕ
    FVlc.OnClick := oldOnClick;
    FVlc.OnDblClick := oldOnDblClick;
    FVlc.OnMouseDown := oldOnMouseDown;
    FVlc.OnMouseMove := oldOnMouseMove;
    FVlc.OnMouseUp := oldOnMouseUp;

    // ВОССТАНАВЛИВАЕМ РАЗМЕРЫ
    FVlc.Align := alNone;
    FVlc.SetBounds(2, 2, Panel_VLC_Player.Width - 4, Panel_VLC_Player.Height - 4);
    FVlc.Align := oldAlign;

    FVlc.Show;

    // Принудительно обновляем видео вывод
    FVlc.ReattachVideo;

    // Восстанавливаем воспроизведение
    if wasPlaying then
    begin
      Sleep(200);
      FVlc.Play;
    end;

    // Обновляем интерфейс
    Panel_VLC_Player.Invalidate;

    // Освобождаем форму
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

