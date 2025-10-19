unit VlcComponent;

interface

uses
  Windows, Messages, SysUtils, Classes, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Dialogs,
  TypInfo, Vcl.Graphics, Vcl.Controls;

type
  // Состояния плеера
  TVlcState = (vlcIdle, vlcLoading, vlcPlaying, vlcPaused, vlcStopped, vlcError);

  // Режимы качества
  TVlcQualityMode = (qmAuto, qmBest, qmWorst, qmCustom);

  // Типы событий
  TVlcNotifyEvent = procedure(Sender: TObject) of object;
  TVlcLogEvent = procedure(Sender: TObject; const Msg: string) of object;
  TVlcProgressEvent = procedure(Sender: TObject; Progress: Integer) of object;

  TVlcPlayerEx = class(TComponent)
  private
    FLibPath: string;              // Путь к библиотеке VLC
    FLibHandle: THandle;           // Хэндл загруженной библиотеки
    FState: TVlcState;             // Текущее состояние плеера
    FMediaURL: string;             // URL медиа-потока
    FVolume: Integer;              // Громкость (0-100)
    FAutoPlay: Boolean;            // Автоматическое воспроизведение
    FVideoHandle: HWND;            // Хэндл окна для вывода видео
    FUserAgent: string;            // User-Agent для HTTP-запросов
    FReferer: string;              // Referer для HTTP-запросов
    FHttpHeaders: TStringList;     // Дополнительные HTTP-заголовки
    FAutoDetectProtectedStreams: Boolean; // Автоопределение защищенных потоков
    FForceWinkHeaders: Boolean;    // Принудительное использование Wink заголовков
    FIsLoading: Boolean;           // Флаг загрузки
    FLoadingProgress: Integer;     // Прогресс загрузки
    FQualityMode: TVlcQualityMode; // Режим качества
    FForcedBitrate: Integer;       // Принудительный битрейт
    FForcedResolution: string;     // Принудительное разрешение
    FMuted: Boolean;               // Флаг состояния звука (включен/выключен)

    // Элементы управления на плеере
    FLoadingStatusLabel: TLabel;   // Label для статуса загрузки в левом нижнем углу

    // Переменные для рисования картинки
    FLogoBitmap: TBitmap;          // Битовой образ картинки
    FLogoVisible: Boolean;         // Видимость картинки
    FLogoFileName: string;         // Имя файла картинки
    FLogoPosition: TRect;          // Позиция и размер картинки
    FLogoPaintTimer: TTimer;       // Таймер для перерисовки картинки

    // Указатели на объекты VLC
    FInstance: Pointer;      // Экземпляр VLC
    FMedia: Pointer;         // Медиа-объект
    FPlayer: Pointer;        // Плеер
    FEventManager: Pointer;  // Менеджер событий

    // Объявления функций библиотеки VLC
    T_libvlc_new: function(argc: Integer; argv: PPAnsiChar): Pointer; cdecl;
    T_libvlc_release: procedure(p_instance: Pointer); cdecl;
    T_libvlc_media_new_path: function(p_instance: Pointer; path: PAnsiChar): Pointer; cdecl;
    T_libvlc_media_new_location: function(p_instance: Pointer; psz_mrl: PAnsiChar): Pointer; cdecl;
    T_libvlc_media_release: procedure(p_media: Pointer); cdecl;
    T_libvlc_media_player_new_from_media: function(p_media: Pointer): Pointer; cdecl;
    T_libvlc_media_player_release: procedure(p_player: Pointer); cdecl;
    T_libvlc_media_player_play: function(p_player: Pointer): Integer; cdecl;
    T_libvlc_media_player_pause: procedure(p_player: Pointer); cdecl;
    T_libvlc_media_player_stop: procedure(p_player: Pointer); cdecl;
    T_libvlc_media_player_set_hwnd: procedure(p_player: Pointer; hwnd: Pointer); cdecl;
    T_libvlc_audio_set_volume: procedure(p_player: Pointer; volume: Integer); cdecl;
    T_libvlc_media_add_option: procedure(p_media: Pointer; psz_options: PAnsiChar); cdecl;
    T_libvlc_media_player_get_length: function(p_player: Pointer): Int64; cdecl;
    T_libvlc_media_player_get_time: function(p_player: Pointer): Int64; cdecl;
    T_libvlc_media_player_get_position: function(p_player: Pointer): Single; cdecl;
    T_libvlc_event_attach: procedure(p_event_manager: Pointer; event_type: Integer; callback: Pointer; user_data: Pointer); cdecl;
    T_libvlc_media_player_event_manager: function(p_player: Pointer): Pointer; cdecl;
    T_libvlc_audio_set_mute: procedure(p_player: Pointer; status: Integer); cdecl;
    T_libvlc_audio_get_mute: function(p_player: Pointer): Integer; cdecl;
    T_libvlc_media_player_is_playing: function(p_player: Pointer): Integer; cdecl;

    // События компонента
    FOnPlaying: TVlcNotifyEvent;
    FOnPaused: TVlcNotifyEvent;
    FOnStopped: TVlcNotifyEvent;
    FOnEndReached: TVlcNotifyEvent;
    FOnError: TVlcNotifyEvent;
    FOnLoading: TVlcNotifyEvent;
    FOnLog: TVlcLogEvent;
    FOnLoadingProgress: TVlcProgressEvent;
    FOnBuffering: TVlcProgressEvent;
    FOnQualityChanged: TVlcNotifyEvent;

    // Приватные методы
    procedure SetMediaURL(const Value: string);
    procedure SetVolume(Value: Integer);
    procedure SetUserAgent(const Value: string);
    procedure SetReferer(const Value: string);
    procedure SetHttpHeaders(const Value: TStringList);
    procedure SetQualityMode(const Value: TVlcQualityMode);
    procedure SetForcedBitrate(const Value: Integer);
    procedure SetForcedResolution(const Value: string);
    function GetMuted: Boolean;
    procedure SetMuted(const Value: Boolean);

    procedure InitVLC;
    procedure LoadFunctions;
    procedure FreeVLC;
    procedure SetState(Value: TVlcState);
    function GetLastErrorText: string;
    procedure Log(const Msg: string);
    function BuildVlcOptions: TStringList;
    function IsProtectedStream(const AUrl: string): Boolean;
    function TestStreamProtection(const AUrl: string): Boolean;
    procedure ApplyAppropriateHeaders(const AUrl: string);
    procedure StopCurrentStream;
    procedure SetupEventHandlers;
    procedure UpdateLoadingProgress;
    procedure ApplyQualitySettings;
    function GetQualityOptions: TStringList;

    // Методы для управления статусом загрузки
    procedure CreateLoadingStatusLabel;
    procedure DestroyLoadingStatusLabel;
    procedure UpdateLoadingStatusLayout;
    procedure SetLoadingStatusText(const AText: string);

    // Методы для рисования картинки на handle
    procedure CreateLogoBitmap;
    procedure DestroyLogoBitmap;
    procedure UpdateLogoPosition;
    procedure SetLogoVisible(const Value: Boolean);
    procedure LogoPaintTimer(Sender: TObject);
    procedure DrawLogoOnHandle;
    procedure ForceRedrawLogo;

    // НОВЫЕ МЕТОДЫ ДЛЯ ЗАПИСИ СОБЫТИЙ
    procedure SendLoadingEvent(const AEvent: string; AProgress: Integer = -1);
    procedure SendStateEvent(const AState: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    // Основные методы управления
    procedure Play;
    procedure Pause;
    procedure Stop;
    procedure LoadMedia(const APath: string);

    // Методы получения состояния
    function IsInitialized: Boolean;
    function IsPlaying: Boolean;
    function IsActuallyPlaying: Boolean;
    function GetDuration: Int64;
    function GetPosition: Int64;
    function GetPlaybackPosition: Single;
    function GetPlayerStatus: string;

    // Методы управления качеством
    procedure ForceBestQuality;
    procedure ForceWorstQuality;
    procedure ForceAutoQuality;
    procedure ForceCustomQuality(Bitrate: Integer; const Resolution: string);

    // Методы работы с HTTP-заголовками
    procedure AddHttpHeader(const AName, AValue: string);
    procedure ClearHttpHeaders;
    procedure SetWinkHeaders;
    procedure SetBasicHeaders;

    // Методы управления звуком
    procedure Mute;
    procedure Unmute;
    procedure ToggleMute;
    function IsMuted: Boolean;

    // Методы управления картинкой в правом верхнем углу
    procedure LoadLogoFromFile(const AFileName: string);
    procedure ShowLogo;
    procedure HideLogo;
    function IsLogoVisible: Boolean;

    // Публичные свойства
    property Handle: HWND read FVideoHandle write FVideoHandle;
    property AutoDetectProtectedStreams: Boolean read FAutoDetectProtectedStreams write FAutoDetectProtectedStreams default True;
    property ForceWinkHeaders: Boolean read FForceWinkHeaders write FForceWinkHeaders default False;
    property LoadingProgress: Integer read FLoadingProgress;
    property IsLoading: Boolean read FIsLoading;
    property QualityMode: TVlcQualityMode read FQualityMode write SetQualityMode;
    property ForcedBitrate: Integer read FForcedBitrate write SetForcedBitrate;
    property ForcedResolution: string read FForcedResolution write SetForcedResolution;
    property Muted: Boolean read GetMuted write SetMuted;
    property LogoVisible: Boolean read FLogoVisible write SetLogoVisible;

  published
    // Опубликованные свойства
    property LibPath: string read FLibPath write FLibPath;
    property MediaURL: string read FMediaURL write SetMediaURL;
    property AutoPlay: Boolean read FAutoPlay write FAutoPlay default True;
    property Volume: Integer read FVolume write SetVolume default 100;
    property UserAgent: string read FUserAgent write SetUserAgent;
    property Referer: string read FReferer write SetReferer;
    property HttpHeaders: TStringList read FHttpHeaders write SetHttpHeaders;
    property State: TVlcState read FState;

    // События
    property OnLoading: TVlcNotifyEvent read FOnLoading write FOnLoading;
    property OnPlaying: TVlcNotifyEvent read FOnPlaying write FOnPlaying;
    property OnPaused: TVlcNotifyEvent read FOnPaused write FOnPaused;
    property OnStopped: TVlcNotifyEvent read FOnStopped write FOnStopped;
    property OnEndReached: TVlcNotifyEvent read FOnEndReached write FOnEndReached;
    property OnError: TVlcNotifyEvent read FOnError write FOnError;
    property OnLog: TVlcLogEvent read FOnLog write FOnLog;
    property OnLoadingProgress: TVlcProgressEvent read FOnLoadingProgress write FOnLoadingProgress;
    property OnBuffering: TVlcProgressEvent read FOnBuffering write FOnBuffering;
    property OnQualityChanged: TVlcNotifyEvent read FOnQualityChanged write FOnQualityChanged;
  end;

// Константы событий VLC
const
  libvlc_MediaPlayerBuffering = 3;
  libvlc_MediaPlayerPlaying = 4;
  libvlc_MediaPlayerPaused = 5;
  libvlc_MediaPlayerStopped = 6;
  libvlc_MediaPlayerEndReached = 7;
  libvlc_MediaPlayerEncounteredError = 8;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('Samples', [TVlcPlayerEx]);
end;

// Callback функция для обработки событий VLC
procedure VlcEventCallback(p_event: Pointer; user_data: Pointer); cdecl;
var
  Player: TVlcPlayerEx;
  EventType: Integer;
begin
  Player := TVlcPlayerEx(user_data);
  if not Assigned(Player) then Exit;

  // Получаем тип события
  EventType := PInteger(p_event)^;

  case EventType of
    libvlc_MediaPlayerBuffering:
      begin
        Player.Log('Буферизация...');
        Player.SendLoadingEvent('BUFFERING', 50);
        if Assigned(Player.FOnBuffering) then
          Player.FOnBuffering(Player, 50);
      end;

    libvlc_MediaPlayerPlaying:
      begin
        Player.SetState(vlcPlaying);
        Player.FIsLoading := False;
        Player.FLoadingProgress := 100;

        // Запускаем таймер перерисовки если картинка видима
        if Player.FLogoVisible then
          Player.FLogoPaintTimer.Enabled := True;

        // Дополнительная проверка реального состояния
        if Player.IsActuallyPlaying then
          Player.Log('Воспроизведение началось (подтверждено VLC)')
        else
          Player.Log('Состояние Playing, но VLC не воспроизводит');

        if Assigned(Player.FOnLoadingProgress) then
          Player.FOnLoadingProgress(Player, 100);

        // Скрываем статус загрузки при начале воспроизведения
        Player.SetLoadingStatusText('');

        Player.SendLoadingEvent('PLAYING');
        Player.SendStateEvent('PLAYING');
      end;

    libvlc_MediaPlayerPaused:
      begin
        Player.SetState(vlcPaused);
        Player.Log('Воспроизведение приостановлено');
        // Останавливаем таймер перерисовки
        Player.FLogoPaintTimer.Enabled := False;
        Player.SendLoadingEvent('PAUSED');
        Player.SendStateEvent('PAUSED');
      end;

    libvlc_MediaPlayerStopped:
      begin
        Player.SetState(vlcStopped);
        Player.FIsLoading := False;
        Player.FLoadingProgress := 0;
        Player.Log('Воспроизведение остановлено');
        Player.SetLoadingStatusText('');
        // Останавливаем таймер перерисовки
        Player.FLogoPaintTimer.Enabled := False;
        Player.SendLoadingEvent('STOPPED');
        Player.SendStateEvent('STOPPED');
      end;

    libvlc_MediaPlayerEndReached:
      begin
        Player.Log('Воспроизведение завершено');
        // Останавливаем таймер перерисовки
        Player.FLogoPaintTimer.Enabled := False;
        Player.SendLoadingEvent('END_REACHED');
        if Assigned(Player.FOnEndReached) then
          Player.FOnEndReached(Player);
      end;

    libvlc_MediaPlayerEncounteredError:
      begin
        Player.SetState(vlcError);
        Player.Log('Ошибка воспроизведения');
        Player.FIsLoading := False;
        Player.FLoadingProgress := 0;
        Player.SetLoadingStatusText('Ошибка загрузки');
        // Останавливаем таймер перерисовки
        Player.FLogoPaintTimer.Enabled := False;
        Player.SendLoadingEvent('ERROR');
        Player.SendStateEvent('ERROR');
      end;
  end;
end;

{ TVlcPlayerEx }

constructor TVlcPlayerEx.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FLibPath := 'libvlc.dll';
  FHttpHeaders := TStringList.Create;
  FAutoPlay := True;
  FVolume := 100;
  FState := vlcIdle;
  FAutoDetectProtectedStreams := True;
  FForceWinkHeaders := False;
  FIsLoading := False;
  FLoadingProgress := 0;
  FQualityMode := qmAuto;
  FForcedBitrate := 0;
  FForcedResolution := '';
  FMuted := False;

  FLoadingStatusLabel := nil;
  FLogoVisible := False;
  FLogoBitmap := nil;

  // Создаем таймер для перерисовки картинки
  FLogoPaintTimer := TTimer.Create(Self);
  FLogoPaintTimer.Interval := 100;
  FLogoPaintTimer.Enabled := False;
  FLogoPaintTimer.OnTimer := LogoPaintTimer;

  // Устанавливаем базовые заголовки по умолчанию
  SetBasicHeaders;
end;

destructor TVlcPlayerEx.Destroy;
begin
  // Обнуляем события для избежания access violation
  FOnLog := nil;
  FOnLoadingProgress := nil;
  FOnBuffering := nil;
  FOnQualityChanged := nil;

  // Останавливаем таймер
  FLogoPaintTimer.Enabled := False;

  // Освобождаем ресурсы VLC
  FreeVLC;

  // Освобождаем элементы интерфейса
  DestroyLoadingStatusLabel;
  DestroyLogoBitmap;

  // Освобождаем объекты
  FHttpHeaders.Free;

  inherited Destroy;
end;

// Методы для рисования картинки на handle

procedure TVlcPlayerEx.CreateLogoBitmap;
begin
  if FLogoBitmap = nil then
  begin
    FLogoBitmap := TBitmap.Create;
    FLogoBitmap.PixelFormat := pf32bit;
    FLogoBitmap.Transparent := True;
    FLogoBitmap.TransparentColor := clFuchsia;
  end;
end;

procedure TVlcPlayerEx.DestroyLogoBitmap;
begin
  if Assigned(FLogoBitmap) then
  begin
    FLogoBitmap.Free;
    FLogoBitmap := nil;
  end;
end;

procedure TVlcPlayerEx.UpdateLogoPosition;
var
  ParentControl: TWinControl;
begin
  if FVideoHandle = 0 then Exit;

  ParentControl := FindControl(FVideoHandle);
  if ParentControl = nil then Exit;

  // Правый верхний угол с отступом 10 пикселей, размер 50x50
  FLogoPosition := Rect(
    ParentControl.Width - 60,
    10,
    ParentControl.Width - 10,
    60
  );
end;

procedure TVlcPlayerEx.SetLogoVisible(const Value: Boolean);
begin
  if FLogoVisible <> Value then
  begin
    FLogoVisible := Value;

    // Запускаем/останавливаем таймер перерисовки
    FLogoPaintTimer.Enabled := FLogoVisible and IsPlaying;

    if FLogoVisible then
    begin
      UpdateLogoPosition;
      ForceRedrawLogo;
      Log('Картинка показана');
    end
    else
    begin
      ForceRedrawLogo;
      Log('Картинка скрыта');
    end;
  end;
end;

procedure TVlcPlayerEx.LogoPaintTimer(Sender: TObject);
begin
  // Рисуем картинку только если воспроизведение идет и картинка видима
  if FLogoVisible and IsPlaying and (FVideoHandle <> 0) then
  begin
    DrawLogoOnHandle;
  end;
end;

procedure TVlcPlayerEx.DrawLogoOnHandle;
var
  DC: HDC;
begin
  if (FVideoHandle = 0) or not Assigned(FLogoBitmap) or FLogoBitmap.Empty then
    Exit;

  try
    // Получаем контекст устройства окна
    DC := GetDC(FVideoHandle);
    if DC = 0 then Exit;

    try
      // Используем прозрачную отрисовку
      SetStretchBltMode(DC, HALFTONE);
      SetBrushOrgEx(DC, 0, 0, nil);

      // Рисуем картинку с прозрачностью
      TransparentBlt(
        DC,
        FLogoPosition.Left,
        FLogoPosition.Top,
        FLogoPosition.Right - FLogoPosition.Left,
        FLogoPosition.Bottom - FLogoPosition.Top,
        FLogoBitmap.Canvas.Handle,
        0, 0,
        FLogoBitmap.Width,
        FLogoBitmap.Height,
        FLogoBitmap.TransparentColor
      );
    finally
      ReleaseDC(FVideoHandle, DC);
    end;
  except
    on E: Exception do
      Log('Ошибка рисования картинки: ' + E.Message);
  end;
end;

procedure TVlcPlayerEx.ForceRedrawLogo;
begin
  if FVideoHandle = 0 then Exit;

  // Принудительно перерисовываем область картинки
  InvalidateRect(FVideoHandle, @FLogoPosition, True);
  UpdateWindow(FVideoHandle);
end;

// Публичные методы для управления картинкой

procedure TVlcPlayerEx.LoadLogoFromFile(const AFileName: string);
begin
  if not FileExists(AFileName) then
  begin
    Log('Файл картинки не найден: ' + AFileName);
    Exit;
  end;

  try
    CreateLogoBitmap;
    FLogoBitmap.LoadFromFile(AFileName);
    FLogoFileName := AFileName;

    // Масштабируем до 50x50
    FLogoBitmap.Width := 50;
    FLogoBitmap.Height := 50;

    UpdateLogoPosition;
    Log('Картинка загружена: ' + AFileName);

  except
    on E: Exception do
      Log('Ошибка загрузки картинки: ' + E.Message);
  end;
end;

procedure TVlcPlayerEx.ShowLogo;
begin
  SetLogoVisible(True);
end;

procedure TVlcPlayerEx.HideLogo;
begin
  SetLogoVisible(False);
end;

function TVlcPlayerEx.IsLogoVisible: Boolean;
begin
  Result := FLogoVisible;
end;

// Существующие методы без изменений

procedure TVlcPlayerEx.CreateLoadingStatusLabel;
var
  ParentControl: TWinControl;
begin
  if FVideoHandle = 0 then Exit;

  try
    ParentControl := FindControl(FVideoHandle);
    if ParentControl = nil then
    begin
      Log('Не удалось найти контрол плеера для статуса загрузки');
      Exit;
    end;

    FLoadingStatusLabel := TLabel.Create(ParentControl);
    with FLoadingStatusLabel do
    begin
      Parent := ParentControl;
      AutoSize := False;
      Alignment := taLeftJustify;
      Font.Size := 10;
      Font.Color := clWhite;
      Font.Style := [fsBold];
      Color := $80000000;
      Transparent := False;
      Visible := False;

      Left := 10;
      Top := ParentControl.Height - 30;
      Width := 200;
      Height := 20;
      BringToFront;
    end;

    Log('Label статуса загрузки создан');

  except
    on E: Exception do
      Log('Ошибка создания Label статуса загрузки: ' + E.Message);
  end;
end;

procedure TVlcPlayerEx.DestroyLoadingStatusLabel;
begin
  if Assigned(FLoadingStatusLabel) then
  begin
    FLoadingStatusLabel.Free;
    FLoadingStatusLabel := nil;
  end;
end;

procedure TVlcPlayerEx.UpdateLoadingStatusLayout;
var
  ParentControl: TWinControl;
begin
  if (FVideoHandle = 0) or not Assigned(FLoadingStatusLabel) then Exit;

  try
    ParentControl := FindControl(FVideoHandle);
    if ParentControl = nil then Exit;

    FLoadingStatusLabel.Left := 10;
    FLoadingStatusLabel.Top := ParentControl.Height - 30;
    FLoadingStatusLabel.Width := 200;
    FLoadingStatusLabel.Height := 20;
    FLoadingStatusLabel.BringToFront;

  except
    on E: Exception do
      Log('Ошибка обновления расположения статуса загрузки: ' + E.Message);
  end;
end;

procedure TVlcPlayerEx.SetLoadingStatusText(const AText: string);
begin
  if (FVideoHandle <> 0) and not Assigned(FLoadingStatusLabel) then
  begin
    CreateLoadingStatusLabel;
  end;

  if Assigned(FLoadingStatusLabel) then
  begin
    FLoadingStatusLabel.Caption := AText;
    FLoadingStatusLabel.Visible := (AText <> '');

    if AText <> '' then
      UpdateLoadingStatusLayout;

    FLoadingStatusLabel.BringToFront;
  end;
end;

procedure TVlcPlayerEx.SendLoadingEvent(const AEvent: string; AProgress: Integer = -1);
var
  EventData: string;
  CopyDataStruct: TCopyDataStruct;
begin
  if FVideoHandle = 0 then Exit;

  if AProgress >= 0 then
    EventData := AEvent + '|' + IntToStr(AProgress) + '|' + IntToStr(GetTickCount)
  else
    EventData := AEvent + '||' + IntToStr(GetTickCount);

  CopyDataStruct.dwData := 0;
  CopyDataStruct.cbData := (Length(EventData) + 1) * SizeOf(Char);
  CopyDataStruct.lpData := PChar(EventData);

  SendMessage(FVideoHandle, WM_COPYDATA, WPARAM(Self.Handle), LPARAM(@CopyDataStruct));
end;

procedure TVlcPlayerEx.SendStateEvent(const AState: string);
begin
  SendLoadingEvent('STATE_' + AState);
end;

procedure TVlcPlayerEx.Log(const Msg: string);
begin
  if Assigned(FOnLog) then
    FOnLog(Self, Msg);
end;

function TVlcPlayerEx.GetLastErrorText: string;
var
  ErrorCode: Integer;
begin
  ErrorCode := GetLastError;
  if ErrorCode <> 0 then
    Result := SysErrorMessage(ErrorCode)
  else
    Result := 'Неизвестная ошибка';
end;

function TVlcPlayerEx.GetMuted: Boolean;
begin
  Result := FMuted;
end;

procedure TVlcPlayerEx.SetMuted(const Value: Boolean);
begin
  if FMuted <> Value then
  begin
    FMuted := Value;
    if (FPlayer <> nil) and Assigned(T_libvlc_audio_set_mute) then
    begin
      T_libvlc_audio_set_mute(FPlayer, Integer(FMuted));
      if FMuted then
        Log('Звук отключен')
      else
        Log('Звук включен');
    end;
  end;
end;

procedure TVlcPlayerEx.Mute;
begin
  if not FMuted then
  begin
    FMuted := True;
    if (FPlayer <> nil) and Assigned(T_libvlc_audio_set_mute) then
    begin
      T_libvlc_audio_set_mute(FPlayer, 1);
      Log('Звук отключен');
    end;
  end;
end;

procedure TVlcPlayerEx.Unmute;
begin
  if FMuted then
  begin
    FMuted := False;
    if (FPlayer <> nil) and Assigned(T_libvlc_audio_set_mute) then
    begin
      T_libvlc_audio_set_mute(FPlayer, 0);
      Log('Звук включен');
    end;
  end;
end;

procedure TVlcPlayerEx.ToggleMute;
begin
  if IsMuted then
    Unmute
  else
    Mute;
end;

function TVlcPlayerEx.IsMuted: Boolean;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_audio_get_mute) then
  begin
    FMuted := T_libvlc_audio_get_mute(FPlayer) <> 0;
    Result := FMuted;
  end
  else
    Result := FMuted;
end;

function TVlcPlayerEx.IsPlaying: Boolean;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_is_playing) then
    Result := (T_libvlc_media_player_is_playing(FPlayer) <> 0)
  else
    Result := FState = vlcPlaying;
end;

function TVlcPlayerEx.IsActuallyPlaying: Boolean;
var
  Position: Single;
  Duration: Int64;
begin
  Result := False;

  if not IsInitialized or (FPlayer = nil) then
    Exit;

  if Assigned(T_libvlc_media_player_is_playing) then
    if T_libvlc_media_player_is_playing(FPlayer) = 0 then
      Exit;

  if FState <> vlcPlaying then
    Exit;

  Position := GetPlaybackPosition;
  Duration := GetDuration;

  Result := (Duration > 0) and (Position >= 0) and (not FIsLoading);
end;

function TVlcPlayerEx.GetPlayerStatus: string;
var
  IsVlcPlaying: Boolean;
  Position: Single;
begin
  if not IsInitialized then
    Exit('Плеер не инициализирован');

  if Assigned(T_libvlc_media_player_is_playing) and (FPlayer <> nil) then
    IsVlcPlaying := T_libvlc_media_player_is_playing(FPlayer) <> 0
  else
    IsVlcPlaying := False;

  Position := GetPlaybackPosition;

  case FState of
    vlcPlaying:
      begin
        if IsVlcPlaying then
          Result := 'Активно воспроизводится'
        else
          Result := 'Состояние Playing, но VLC не воспроизводит';

        Result := Result + Format(' (Позиция: %.1f%%)', [Position * 100]);
      end;
    vlcPaused: Result := 'На паузе' + Format(' (Позиция: %.1f%%)', [Position * 100]);
    vlcStopped: Result := 'Остановлено';
    vlcLoading: Result := Format('Загрузка... (%d%%)', [FLoadingProgress]);
    vlcIdle: Result := 'Ожидание';
    vlcError: Result := 'Ошибка';
  end;

  if IsMuted then
    Result := Result + ' | Без звука'
  else
    Result := Result + Format(' | %d%%', [FVolume]);

  if GetDuration > 0 then
    Result := Result + Format(' | %d сек', [GetDuration div 1000]);
end;

procedure TVlcPlayerEx.SetQualityMode(const Value: TVlcQualityMode);
begin
  if FQualityMode <> Value then
  begin
    FQualityMode := Value;
    Log('Режим качества установлен: ' + GetEnumName(TypeInfo(TVlcQualityMode), Ord(Value)));

    if IsPlaying or FIsLoading then
      ApplyQualitySettings;

    if Assigned(FOnQualityChanged) then
      FOnQualityChanged(Self);
  end;
end;

procedure TVlcPlayerEx.SetForcedBitrate(const Value: Integer);
begin
  if FForcedBitrate <> Value then
  begin
    FForcedBitrate := Value;
    if FQualityMode = qmCustom then
    begin
      Log('Установлена битрейт: ' + IntToStr(Value) + ' kbps');
      ApplyQualitySettings;
    end;
  end;
end;

procedure TVlcPlayerEx.SetForcedResolution(const Value: string);
begin
  if FForcedResolution <> Value then
  begin
    FForcedResolution := Value;
    if FQualityMode = qmCustom then
    begin
      Log('Установлено разрешение: ' + Value);
      ApplyQualitySettings;
    end;
  end;
end;

procedure TVlcPlayerEx.StopCurrentStream;
begin
  if FIsLoading then
  begin
    Log('Прерывание загрузки текущего потока...');
  end;

  if FPlayer <> nil then
  begin
    T_libvlc_media_player_stop(FPlayer);
  end;

  FIsLoading := False;
  FLoadingProgress := 0;
  SetState(vlcStopped);
end;

procedure TVlcPlayerEx.SetupEventHandlers;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_event_manager) then
  begin
    FEventManager := T_libvlc_media_player_event_manager(FPlayer);
    if FEventManager <> nil then
    begin
      T_libvlc_event_attach(FEventManager, libvlc_MediaPlayerPlaying, @VlcEventCallback, Self);
      T_libvlc_event_attach(FEventManager, libvlc_MediaPlayerPaused, @VlcEventCallback, Self);
      T_libvlc_event_attach(FEventManager, libvlc_MediaPlayerStopped, @VlcEventCallback, Self);
      T_libvlc_event_attach(FEventManager, libvlc_MediaPlayerEndReached, @VlcEventCallback, Self);
      T_libvlc_event_attach(FEventManager, libvlc_MediaPlayerEncounteredError, @VlcEventCallback, Self);
      T_libvlc_event_attach(FEventManager, libvlc_MediaPlayerBuffering, @VlcEventCallback, Self);
    end;
  end;
end;

procedure TVlcPlayerEx.UpdateLoadingProgress;
begin
  if not FIsLoading then Exit;

  if FLoadingProgress < 100 then
    FLoadingProgress := FLoadingProgress + 1;

  if Assigned(FOnLoadingProgress) then
    FOnLoadingProgress(Self, FLoadingProgress);

  SetLoadingStatusText('Загрузка: ' + IntToStr(FLoadingProgress) + '%');

  SendLoadingEvent('LOADING_PROGRESS', FLoadingProgress);

  Log('Загрузка: ' + IntToStr(FLoadingProgress) + '%');

  if (FLoadingProgress >= 100) and (FState <> vlcPlaying) then
  begin
    FIsLoading := False;
    Log('Загрузка завершена, ожидание воспроизведения...');
    SendLoadingEvent('LOADING_COMPLETE');
  end;
end;

function TVlcPlayerEx.GetQualityOptions: TStringList;
begin
  Result := TStringList.Create;
  try
    case FQualityMode of
      qmAuto:
        begin
          Result.Add(':network-caching=3000');
          Result.Add(':live-caching=3000');
          Log('Режим качества: Автоматический');
        end;

      qmBest:
        begin
          Result.Add(':network-caching=5000');
          Result.Add(':live-caching=5000');
          Result.Add(':sout-x264-preset=slow');
          Result.Add(':sout-x264-tune=film');
          Result.Add(':crf=18');
          Result.Add(':prefer-hw-decoder=1');
          Log('Режим качества: Лучшее (максимальное)');
        end;

      qmWorst:
        begin
          Result.Add(':network-caching=1000');
          Result.Add(':live-caching=1000');
          Result.Add(':sout-x264-preset=ultrafast');
          Result.Add(':crf=28');
          Result.Add(':drop-late-frames');
          Result.Add(':skip-frames');
          Log('Режим качества: Худшее (экономное)');
        end;

      qmCustom:
        begin
          Result.Add(':network-caching=3000');
          Result.Add(':live-caching=3000');

          if FForcedBitrate > 0 then
          begin
            Result.Add(':sout-x264-bitrate=' + IntToStr(FForcedBitrate));
            Log('Режим качества: Пользовательский (битрейт: ' + IntToStr(FForcedBitrate) + 'kbps)');
          end;

          if FForcedResolution <> '' then
          begin
            Result.Add(':sout-x264-resolution=' + FForcedResolution);
            Log('Режим качества: Пользовательский (разрешение: ' + FForcedResolution + ')');
          end;
        end;
    end;

    Result.Add(':hls-prefer-native');

    case FQualityMode of
      qmBest:
        begin
          Result.Add(':hls-preferred-resolution=1080');
          Result.Add(':hls-bitrate=5000000');
        end;
      qmWorst:
        begin
          Result.Add(':hls-preferred-resolution=360');
          Result.Add(':hls-bitrate=500000');
        end;
      else
        begin
          Result.Add(':hls-preferred-resolution=720');
          Result.Add(':hls-bitrate=2000000');
        end;
    end;

  except
    Result.Free;
    raise;
  end;
end;

procedure TVlcPlayerEx.ApplyQualitySettings;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_add_option) and (FMedia <> nil) then
  begin
    var QualityOptions := GetQualityOptions;
    try
      for var I := 0 to QualityOptions.Count - 1 do
      begin
        T_libvlc_media_add_option(FMedia, PAnsiChar(UTF8Encode(QualityOptions[I])));
        Log('Добавлена опция качества: ' + QualityOptions[I]);
      end;
    finally
      QualityOptions.Free;
    end;
  end;
end;

procedure TVlcPlayerEx.ForceBestQuality;
begin
  QualityMode := qmBest;
end;

procedure TVlcPlayerEx.ForceWorstQuality;
begin
  QualityMode := qmWorst;
end;

procedure TVlcPlayerEx.ForceAutoQuality;
begin
  QualityMode := qmAuto;
end;

procedure TVlcPlayerEx.ForceCustomQuality(Bitrate: Integer; const Resolution: string);
begin
  FForcedBitrate := Bitrate;
  FForcedResolution := Resolution;
  QualityMode := qmCustom;
end;

procedure TVlcPlayerEx.SetMediaURL(const Value: string);
begin
  if FMediaURL <> Value then
  begin
    FMediaURL := Value;
    if Value <> '' then
      LoadMedia(Value);
  end;
end;

procedure TVlcPlayerEx.SetVolume(Value: Integer);
begin
  if Value < 0 then Value := 0;
  if Value > 100 then Value := 100;

  if FVolume <> Value then
  begin
    FVolume := Value;
    if (FPlayer <> nil) and Assigned(T_libvlc_audio_set_volume) then
    begin
      T_libvlc_audio_set_volume(FPlayer, Value);
      Log('Громкость установлена: ' + IntToStr(Value));
    end;
  end;
end;

procedure TVlcPlayerEx.SetUserAgent(const Value: string);
begin
  if FUserAgent <> Value then
  begin
    FUserAgent := Value;
    Log('User-Agent установлен: ' + Value);
  end;
end;

procedure TVlcPlayerEx.SetReferer(const Value: string);
begin
  if FReferer <> Value then
  begin
    FReferer := Value;
    Log('Referer установлен: ' + Value);
  end;
end;

procedure TVlcPlayerEx.SetHttpHeaders(const Value: TStringList);
begin
  FHttpHeaders.Assign(Value);
end;

procedure TVlcPlayerEx.SetState(Value: TVlcState);
begin
  if FState <> Value then
  begin
    FState := Value;
    Log('Состояние изменено: ' + GetEnumName(TypeInfo(TVlcState), Ord(Value)));

    case Value of
      vlcPlaying:
        if Assigned(FOnPlaying) then FOnPlaying(Self);
      vlcPaused:
        if Assigned(FOnPaused) then FOnPaused(Self);
      vlcStopped:
        if Assigned(FOnStopped) then FOnStopped(Self);
      vlcError:
        if Assigned(FOnError) then FOnError(Self);
    end;
  end;
end;

function TVlcPlayerEx.BuildVlcOptions: TStringList;
begin
  Result := TStringList.Create;
  try
    Result.Add(':network-caching=3000');
    Result.Add(':live-caching=3000');

    if FUserAgent <> '' then
      Result.Add(':http-user-agent=' + FUserAgent);

    if FReferer <> '' then
      Result.Add(':http-referrer=' + FReferer);

    for var I := 0 to FHttpHeaders.Count - 1 do
    begin
      if FHttpHeaders.Names[I] <> '' then
        Result.Add(':http-extra-header=' + FHttpHeaders.Names[I] + ': ' + FHttpHeaders.ValueFromIndex[I]);
    end;

  except
    Result.Free;
    raise;
  end;
end;

function TVlcPlayerEx.IsProtectedStream(const AUrl: string): Boolean;
begin
  Result := (Pos('wink.', AUrl) > 0) or
            (Pos('protected.', AUrl) > 0) or
            (Pos('secure.', AUrl) > 0) or
            (Pos('premium.', AUrl) > 0);
end;

function TVlcPlayerEx.TestStreamProtection(const AUrl: string): Boolean;
begin
  Result := IsProtectedStream(AUrl);
end;

procedure TVlcPlayerEx.ApplyAppropriateHeaders(const AUrl: string);
begin
  if FAutoDetectProtectedStreams and TestStreamProtection(AUrl) then
  begin
    Log('Обнаружен защищенный поток, применяем специальные заголовки');
    SetWinkHeaders;
  end
  else if FForceWinkHeaders then
  begin
    Log('Принудительно применяем Wink заголовки');
    SetWinkHeaders;
  end
  else
  begin
    Log('Применяем стандартные заголовки');
    SetBasicHeaders;
  end;
end;

procedure TVlcPlayerEx.SetBasicHeaders;
begin
  FUserAgent := 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
  FReferer := '';
  ClearHttpHeaders;
  AddHttpHeader('Accept', '*/*');
  AddHttpHeader('Accept-Language', 'en-US,en;q=0.9');
  AddHttpHeader('Accept-Encoding', 'gzip, deflate, br');
end;

procedure TVlcPlayerEx.SetWinkHeaders;
begin
  FUserAgent := 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
  FReferer := 'https://wink.ru/';
  ClearHttpHeaders;
  AddHttpHeader('Accept', '*/*');
  AddHttpHeader('Accept-Language', 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7');
  AddHttpHeader('Accept-Encoding', 'gzip, deflate, br');
  AddHttpHeader('Origin', 'https://wink.ru');
  AddHttpHeader('Sec-Fetch-Dest', 'empty');
  AddHttpHeader('Sec-Fetch-Mode', 'cors');
  AddHttpHeader('Sec-Fetch-Site', 'cross-site');
end;

procedure TVlcPlayerEx.AddHttpHeader(const AName, AValue: string);
begin
  FHttpHeaders.Values[AName] := AValue;
end;

procedure TVlcPlayerEx.ClearHttpHeaders;
begin
  FHttpHeaders.Clear;
end;

procedure TVlcPlayerEx.InitVLC;
var
  Args: array of PAnsiChar;
  I: Integer;
  LibName: string;
begin
  if IsInitialized then Exit;

  if FLibPath = '' then
    LibName := 'libvlc.dll'
  else
    LibName := FLibPath;

  SetDllDirectory(PChar(FLibPath));
  FLibHandle := LoadLibrary('libvlc.dll');
  SetDllDirectory(nil);
  if FLibHandle = 0 then
    raise Exception.Create('Не удалось загрузить библиотеку VLC: ' + LibName + '. Ошибка: ' + GetLastErrorText);

  LoadFunctions;

  SetLength(Args, 2);
  Args[0] := PAnsiChar(UTF8Encode('--intf=dummy'));
  Args[1] := nil;

  FInstance := T_libvlc_new(1, @Args[0]);
  if FInstance = nil then
    raise Exception.Create('Не удалось создать экземпляр VLC');

  Log('VLC инициализирован успешно');
end;

procedure TVlcPlayerEx.LoadFunctions;
begin
  @T_libvlc_new := GetProcAddress(FLibHandle, 'libvlc_new');
  @T_libvlc_release := GetProcAddress(FLibHandle, 'libvlc_release');
  @T_libvlc_media_new_path := GetProcAddress(FLibHandle, 'libvlc_media_new_path');
  @T_libvlc_media_new_location := GetProcAddress(FLibHandle, 'libvlc_media_new_location');
  @T_libvlc_media_release := GetProcAddress(FLibHandle, 'libvlc_media_release');
  @T_libvlc_media_player_new_from_media := GetProcAddress(FLibHandle, 'libvlc_media_player_new_from_media');
  @T_libvlc_media_player_release := GetProcAddress(FLibHandle, 'libvlc_media_player_release');
  @T_libvlc_media_player_play := GetProcAddress(FLibHandle, 'libvlc_media_player_play');
  @T_libvlc_media_player_pause := GetProcAddress(FLibHandle, 'libvlc_media_player_pause');
  @T_libvlc_media_player_stop := GetProcAddress(FLibHandle, 'libvlc_media_player_stop');
  @T_libvlc_media_player_set_hwnd := GetProcAddress(FLibHandle, 'libvlc_media_player_set_hwnd');
  @T_libvlc_audio_set_volume := GetProcAddress(FLibHandle, 'libvlc_audio_set_volume');
  @T_libvlc_media_add_option := GetProcAddress(FLibHandle, 'libvlc_media_add_option');
  @T_libvlc_media_player_get_length := GetProcAddress(FLibHandle, 'libvlc_media_player_get_length');
  @T_libvlc_media_player_get_time := GetProcAddress(FLibHandle, 'libvlc_media_player_get_time');
  @T_libvlc_media_player_get_position := GetProcAddress(FLibHandle, 'libvlc_media_player_get_position');
  @T_libvlc_event_attach := GetProcAddress(FLibHandle, 'libvlc_event_attach');
  @T_libvlc_media_player_event_manager := GetProcAddress(FLibHandle, 'libvlc_media_player_event_manager');
  @T_libvlc_audio_set_mute := GetProcAddress(FLibHandle, 'libvlc_audio_set_mute');
  @T_libvlc_audio_get_mute := GetProcAddress(FLibHandle, 'libvlc_audio_get_mute');
  @T_libvlc_media_player_is_playing := GetProcAddress(FLibHandle, 'libvlc_media_player_is_playing');

  if not Assigned(T_libvlc_new) or not Assigned(T_libvlc_media_new_location) then
    raise Exception.Create('Не удалось загрузить основные функции VLC');
end;

procedure TVlcPlayerEx.FreeVLC;
begin
  if FPlayer <> nil then
  begin
    T_libvlc_media_player_stop(FPlayer);
    T_libvlc_media_player_release(FPlayer);
    FPlayer := nil;
  end;

  if FMedia <> nil then
  begin
    T_libvlc_media_release(FMedia);
    FMedia := nil;
  end;

  if FInstance <> nil then
  begin
    T_libvlc_release(FInstance);
    FInstance := nil;
  end;

  if FLibHandle <> 0 then
  begin
    FreeLibrary(FLibHandle);
    FLibHandle := 0;
  end;

  FState := vlcIdle;
  FIsLoading := False;
  FLoadingProgress := 0;
  FMuted := False;
end;

function TVlcPlayerEx.IsInitialized: Boolean;
begin
  Result := (FInstance <> nil) and (FLibHandle <> 0);
end;

function TVlcPlayerEx.GetDuration: Int64;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_get_length) then
    Result := T_libvlc_media_player_get_length(FPlayer)
  else
    Result := 0;
end;

function TVlcPlayerEx.GetPosition: Int64;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_get_time) then
    Result := T_libvlc_media_player_get_time(FPlayer)
  else
    Result := 0;
end;

function TVlcPlayerEx.GetPlaybackPosition: Single;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_get_position) then
    Result := T_libvlc_media_player_get_position(FPlayer)
  else
    Result := 0;
end;

procedure TVlcPlayerEx.LoadMedia(const APath: string);
var
  MediaType: string;
  Options: TStringList;
  I: Integer;
begin
  Log('=== ЗАГРУЗКА МЕДИА ===');
  Log('URL: ' + APath);

  SendLoadingEvent('LOADING_START');

  if APath = '' then
  begin
    Log('Ошибка: Пустой URL медиа');
    SendLoadingEvent('LOADING_ERROR', 0);
    Exit;
  end;

  StopCurrentStream;

  ApplyAppropriateHeaders(APath);

  SetState(vlcLoading);
  FIsLoading := True;
  FLoadingProgress := 0;

  if Assigned(FOnLoading) then
    FOnLoading(Self);

  if Assigned(FOnLoadingProgress) then
    FOnLoadingProgress(Self, 0);

  SetLoadingStatusText('Загрузка: 0%');

  try
    if FVideoHandle = 0 then
    begin
      Log('Внимание: Handle окна не установлен!');
    end
    else if not IsWindow(FVideoHandle) then
    begin
      Log('Ошибка: Неверный handle окна!');
      FVideoHandle := 0;
    end;

    if FPlayer <> nil then
    begin
      T_libvlc_media_player_release(FPlayer);
      FPlayer := nil;
    end;

    if FMedia <> nil then
    begin
      T_libvlc_media_release(FMedia);
      FMedia := nil;
    end;

    if not IsInitialized then
      InitVLC;

    if (Pos('http://', LowerCase(APath)) = 1) or (Pos('https://', LowerCase(APath)) = 1) then
    begin
      MediaType := 'HTTP/HTTPS поток';
      FMedia := T_libvlc_media_new_location(FInstance, PAnsiChar(UTF8Encode(APath)));

      if Assigned(T_libvlc_media_add_option) then
      begin
        Options := BuildVlcOptions;
        try
          for I := 0 to Options.Count - 1 do
          begin
            T_libvlc_media_add_option(FMedia, PAnsiChar(UTF8Encode(Options[I])));
            Log('Добавлена опция: ' + Options[I]);
          end;
        finally
          Options.Free;
        end;

        ApplyQualitySettings;
      end;
    end
    else
    begin
      MediaType := 'Локальный файл';
      FMedia := T_libvlc_media_new_path(FInstance, PAnsiChar(UTF8Encode(APath)));
    end;

    Log('Тип медиа: ' + MediaType);

    if FMedia = nil then
      raise Exception.Create('Не удалось создать медиа объект');

    FPlayer := T_libvlc_media_player_new_from_media(FMedia);
    if FPlayer = nil then
      raise Exception.Create('Не удалось создать медиаплеер');

    SetupEventHandlers;

    if FVideoHandle <> 0 then
    begin
      T_libvlc_media_player_set_hwnd(FPlayer, Pointer(FVideoHandle));
      Log('Handle окна установлен: ' + IntToStr(FVideoHandle));

      // Обновляем позицию картинки
      UpdateLogoPosition;
    end;

    if Assigned(T_libvlc_audio_set_volume) then
      T_libvlc_audio_set_volume(FPlayer, FVolume);

    if Assigned(T_libvlc_audio_set_mute) then
      T_libvlc_audio_set_mute(FPlayer, Integer(FMuted));

    UpdateLoadingProgress;

    Log('Медиа успешно загружено');

    if FAutoPlay then
      Play
    else
      SetState(vlcPaused);

  except
    on E: Exception do
    begin
      SetState(vlcError);
      FIsLoading := False;
      FLoadingProgress := 0;
      SetLoadingStatusText('Ошибка загрузки');
      SendLoadingEvent('LOADING_ERROR', 0);
      Log('Ошибка загрузки медиа: ' + E.Message);
      if Assigned(FOnError) then
        FOnError(Self);
    end;
  end;
end;

procedure TVlcPlayerEx.Play;
var
  ResultCode: Integer;
begin
  if FPlayer = nil then
  begin
    Log('Ошибка: Плеер не инициализирован');
    Exit;
  end;

  Log('Запуск воспроизведения...');

  if FIsLoading then
    SetLoadingStatusText('Запуск воспроизведения...')
  else
    SetLoadingStatusText('Перезапуск...');

  SendLoadingEvent('PLAYBACK_STARTING');

  ResultCode := T_libvlc_media_player_play(FPlayer);

  if ResultCode = 0 then
  begin
    Log('Команда воспроизведения отправлена');
    Log('Проверка состояния воспроизведения: ' + GetPlayerStatus);
  end
  else
  begin
    SetState(vlcError);
    FIsLoading := False;
    FLoadingProgress := 0;
    SetLoadingStatusText('Ошибка воспроизведения');
    SendLoadingEvent('PLAYBACK_ERROR');
    Log('Ошибка воспроизведения, код: ' + IntToStr(ResultCode));
    if Assigned(FOnError) then
      FOnError(Self);
  end;
end;

procedure TVlcPlayerEx.Pause;
begin
  if FPlayer = nil then Exit;

  T_libvlc_media_player_pause(FPlayer);
  Log('Команда паузы отправлена');
  SetLoadingStatusText('Пауза');
  SendLoadingEvent('PLAYBACK_PAUSED');
end;

procedure TVlcPlayerEx.Stop;
begin
  StopCurrentStream;
  Log('Воспроизведение остановлено');
  SetLoadingStatusText('');
  SendLoadingEvent('PLAYBACK_STOPPED');
  if Assigned(FOnStopped) then
    FOnStopped(Self);
end;

end.
