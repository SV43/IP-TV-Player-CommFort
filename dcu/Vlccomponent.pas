unit VlcComponent;

interface

uses
  Windows, Messages, SysUtils, Classes, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Dialogs,
  TypInfo, Vcl.Graphics, Vcl.Controls, Vcl.Imaging.pngimage, Math;

type
  // Объявления типов VLC
  Plibvlc_instance_t = Pointer;
  Plibvlc_media_t = Pointer;
  Plibvlc_media_player_t = Pointer;
  Plibvlc_event_manager_t = Pointer;

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
    FOriginalParent: TWinControl;  // Исходный родительский контрол
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
    FStatusLabel: TLabel;          // Label для статуса в левом нижнем углу
    FStatusWindow: HWND;           // Окно для статуса поверх VLC

    // Переменные для рисования картинки
    FLogoBitmap: TBitmap;          // Битовой образ картинки
    FLogoVisible: Boolean;         // Видимость картинки
    FLogoFileName: string;         // Имя файла картинки
    FLogoPaintTimer: TTimer;       // Таймер для перерисовки картинки
    FLogoWindow: HWND;             // Окно для картинки поверх VLC

    // Указатели на объекты VLC
    FInstance: Plibvlc_instance_t;      // Экземпляр VLC
    FMedia: Plibvlc_media_t;         // Медиа-объект
    FPlayer: Plibvlc_media_player_t;        // Плеер
    FEventManager: Plibvlc_event_manager_t;  // Менеджер событий

    // Объявления функций библиотеки VLC
    T_libvlc_new: function(argc: Integer; argv: PPAnsiChar): Plibvlc_instance_t; cdecl;
    T_libvlc_release: procedure(p_instance: Plibvlc_instance_t); cdecl;
    T_libvlc_media_new_path: function(p_instance: Plibvlc_instance_t; path: PAnsiChar): Plibvlc_media_t; cdecl;
    T_libvlc_media_new_location: function(p_instance: Plibvlc_instance_t; psz_mrl: PAnsiChar): Plibvlc_media_t; cdecl;
    T_libvlc_media_release: procedure(p_media: Plibvlc_media_t); cdecl;
    T_libvlc_media_player_new_from_media: function(p_media: Plibvlc_media_t): Plibvlc_media_player_t; cdecl;
    T_libvlc_media_player_release: procedure(p_player: Plibvlc_media_player_t); cdecl;
    T_libvlc_media_player_play: function(p_player: Plibvlc_media_player_t): Integer; cdecl;
    T_libvlc_media_player_pause: procedure(p_player: Plibvlc_media_player_t); cdecl;
    T_libvlc_media_player_stop: procedure(p_player: Plibvlc_media_player_t); cdecl;
    T_libvlc_media_player_set_hwnd: procedure(p_player: Plibvlc_media_player_t; hwnd: Pointer); cdecl;
    T_libvlc_audio_set_volume: procedure(p_player: Plibvlc_media_player_t; volume: Integer); cdecl;
    T_libvlc_media_add_option: procedure(p_media: Plibvlc_media_t; psz_options: PAnsiChar); cdecl;
    T_libvlc_media_player_get_length: function(p_player: Plibvlc_media_player_t): Int64; cdecl;
    T_libvlc_media_player_get_time: function(p_player: Plibvlc_media_player_t): Int64; cdecl;
    T_libvlc_media_player_get_position: function(p_player: Plibvlc_media_player_t): Single; cdecl;
    T_libvlc_event_attach: procedure(p_event_manager: Plibvlc_event_manager_t; event_type: Integer; callback: Pointer; user_data: Pointer); cdecl;
    T_libvlc_media_player_event_manager: function(p_player: Plibvlc_media_player_t): Plibvlc_event_manager_t; cdecl;
    T_libvlc_audio_set_mute: procedure(p_player: Plibvlc_media_player_t; status: Integer); cdecl;
    T_libvlc_audio_get_mute: function(p_player: Plibvlc_media_player_t): Integer; cdecl;
    T_libvlc_media_player_is_playing: function(p_player: Plibvlc_media_player_t): Integer; cdecl;

    // НОВЫЕ ОБЪЯВЛЕНИЯ ФУНКЦИЙ VLC
    T_libvlc_media_player_get_buffer: function(p_mi: Plibvlc_media_player_t): Single; cdecl;
    T_libvlc_media_player_get_media: function(p_mi: Plibvlc_media_player_t): Plibvlc_media_t; cdecl;
    T_libvlc_media_get_mrl: function(p_md: Plibvlc_media_t): PAnsiChar; cdecl;

    // НОВЫЕ ПОЛЯ ДЛЯ РЕАЛЬНОГО ПРОГРЕССА
    FLoadStartTime: Cardinal;       // Время начала загрузки
    FLastProgressUpdate: Cardinal;  // Время последнего обновления прогресса
    FProgressTimer: TTimer;         // Таймер для обновления прогресса

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
    procedure ApplyQualitySettings;
    function GetQualityOptions: TStringList;

    // Методы для управления статусом
    procedure CreateStatusLabel;
    procedure DestroyStatusLabel;
    procedure UpdateStatusLayout;

    // Методы для рисования картинки на handle
    procedure CreateLogoBitmap;
    procedure DestroyLogoBitmap;
    procedure UpdateLogoPosition;
    procedure SetLogoVisible(const Value: Boolean);
    procedure LogoPaintTimer(Sender: TObject);
    procedure DrawLogoOnHandle;
    procedure ForceRedrawLogo;

    // НОВЫЕ МЕТОДЫ ДЛЯ ЗАПИСИ СОБЯТИЙ
    procedure SendLoadingEvent(const AEvent: string; AProgress: Integer = -1);
    procedure SendStateEvent(const AState: string);

    // НОВЫЕ МЕТОДЫ ДЛЯ БУФЕРИЗАЦИИ И СЕТЕВЫХ ПОТОКОВ
    function GetBufferingLevel: Integer;
    function IsNetworkStream: Boolean;

    // НОВЫЕ МЕТОДЫ ДЛЯ РЕАЛЬНОГО ПРОГРЕССА
    function GetActualLoadingProgress: Integer;
    procedure UpdateRealLoadingProgress;
    procedure ProgressTimerTick(Sender: TObject);

    // НОВЫЕ МЕТОДЫ ДЛЯ РАБОТЫ С PNG
    function IsLogoReady: Boolean;
    procedure LoadLogoFromPNGFile(const AFileName: string);

    // НОВЫЕ МЕТОДЫ ДЛЯ ОКНА КАРТИНКИ
    procedure CreateLogoWindow;
    procedure DestroyLogoWindow;
    procedure UpdateLogoWindowPosition;
    procedure SetLogoWindowVisible(Visible: Boolean);

    // НОВЫЕ МЕТОДЫ ДЛЯ УПРАВЛЕНИЯ РОДИТЕЛЬСКИМ КОНТРОЛОМ
    procedure SaveOriginalParent;
    procedure TransferToVideoParent;
    procedure TransferBackToOriginalParent;

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
    procedure UpdateLogo; // НОВЫЙ МЕТОД для принудительного обновления

    // НОВЫЙ МЕТОД ДЛЯ ОБНОВЛЕНИЯ LAYOUT
    procedure UpdateVideoLayout;

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

    // ПРОСТЫЕ МЕТОДЫ ДЛЯ УПРАВЛЕНИЯ STATUS LABEL
    procedure SetStatusText(const AText: string);
    procedure ClearStatus;
    function GetStatusText: string;
    procedure ShowStatus;
    procedure HideStatus;

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
        // Останавливаем таймер прогресса
        Player.FProgressTimer.Enabled := False;

        Player.SetState(vlcPlaying);

        // Устанавливаем 100% прогресс при начале воспроизведения
        Player.FLoadingProgress := 100;
        Player.FIsLoading := False;

        // Запускаем таймер перерисовки если картинка видима
        if Player.FLogoVisible and Player.IsLogoReady then
          Player.FLogoPaintTimer.Enabled := True;

        if Assigned(Player.FOnLoadingProgress) then
          Player.FOnLoadingProgress(Player, 100);

        // Скрываем статус загрузки
        Player.SetStatusText('');

        // ПЕРЕНОСИМ STATUS LABEL НА ВИДЕО
        Player.TransferToVideoParent;

        Player.SendLoadingEvent('PLAYING');
        Player.SendStateEvent('PLAYING');
        Player.Log('Воспроизведение началось');
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
        // Останавливаем таймер прогресса
        Player.FProgressTimer.Enabled := False;

        Player.SetState(vlcStopped);
        Player.FIsLoading := False;
        Player.FLoadingProgress := 0;
        Player.Log('Воспроизведение остановлено');
        Player.SetStatusText('');
        // Останавливаем таймер перерисовки
        Player.FLogoPaintTimer.Enabled := False;

        // ВОЗВРАЩАЕМ STATUS LABEL ОБРАТНО
        Player.TransferBackToOriginalParent;

        Player.SendLoadingEvent('STOPPED');
        Player.SendStateEvent('STOPPED');
      end;

    libvlc_MediaPlayerEndReached:
      begin
        Player.Log('Воспроизведение завершено');
        // Останавливаем таймер перерисовки
        Player.FLogoPaintTimer.Enabled := False;

        // ВОЗВРАЩАЕМ STATUS LABEL ОБРАТНО
        Player.TransferBackToOriginalParent;

        Player.SendLoadingEvent('END_REACHED');
        if Assigned(Player.FOnEndReached) then
          Player.FOnEndReached(Player);
      end;

    libvlc_MediaPlayerEncounteredError:
      begin
        // Останавливаем таймер прогресса
        Player.FProgressTimer.Enabled := False;

        Player.SetState(vlcError);
        Player.Log('Ошибка воспроизведения');
        Player.FIsLoading := False;
        Player.FLoadingProgress := 0;
        Player.SetStatusText('Ошибка загрузки');
        // Останавливаем таймер перерисовки
        Player.FLogoPaintTimer.Enabled := False;

        // ВОЗВРАЩАЕМ STATUS LABEL ОБРАТНО ПРИ ОШИБКЕ
        Player.TransferBackToOriginalParent;

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

  FStatusLabel := nil;
  FStatusWindow := 0;
  FOriginalParent := nil;
  FLogoVisible := False;
  FLogoBitmap := nil;
  FLogoWindow := 0;

  // Инициализация новых полей для прогресса
  FLoadStartTime := 0;
  FLastProgressUpdate := 0;

  // Создаем таймер для перерисовки картинки
  FLogoPaintTimer := TTimer.Create(Self);
  FLogoPaintTimer.Interval := 100;
  FLogoPaintTimer.Enabled := False;
  FLogoPaintTimer.OnTimer := LogoPaintTimer;

  // Создаем таймер для обновления прогресса загрузки
  FProgressTimer := TTimer.Create(Self);
  FProgressTimer.Interval := 500; // Обновление каждые 500ms
  FProgressTimer.Enabled := False;
  FProgressTimer.OnTimer := ProgressTimerTick;

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

  // Останавливаем таймеры
  FLogoPaintTimer.Enabled := False;
  FProgressTimer.Enabled := False;

  // Уничтожаем окно картинки
  DestroyLogoWindow;

  // Уничтожаем окно статуса
  DestroyStatusLabel;

  // Освобождаем ресурсы VLC
  FreeVLC;

  // Освобождаем элементы интерфейса
  if Assigned(FStatusLabel) then
  begin
    FStatusLabel.Free;
    FStatusLabel := nil;
  end;

  // Освобождаем объекты
  FHttpHeaders.Free;
  FLogoPaintTimer.Free;
  FProgressTimer.Free;

  inherited Destroy;
end;

// МЕТОДЫ ДЛЯ УПРАВЛЕНИЯ STATUS LABEL

procedure TVlcPlayerEx.CreateStatusLabel;
begin
  if FVideoHandle = 0 then Exit;

  // Создаем отдельное окно для статуса поверх VLC
  if FStatusWindow = 0 then
  begin
    FStatusWindow := CreateWindowEx(
      WS_EX_LAYERED or WS_EX_TRANSPARENT or WS_EX_TOPMOST or WS_EX_NOACTIVATE,
      'STATIC',
      PChar(''),
      WS_POPUP,
      0, 0, 300, 25,
      FVideoHandle, 0, HInstance, nil
    );

    if FStatusWindow <> 0 then
    begin
      SetLayeredWindowAttributes(FStatusWindow, RGB(0, 0, 0), 180, LWA_ALPHA or LWA_COLORKEY);
      Log('Окно статуса создано: ' + IntToStr(FStatusWindow));
    end
    else
    begin
      Log('Ошибка создания окна статуса');
    end;
  end;
end;

procedure TVlcPlayerEx.DestroyStatusLabel;
begin
  if FStatusWindow <> 0 then
  begin
    DestroyWindow(FStatusWindow);
    FStatusWindow := 0;
  end;
end;

procedure TVlcPlayerEx.UpdateStatusLayout;
var
  ParentRect: TRect;
begin
  if FStatusWindow = 0 then Exit;

  if GetWindowRect(FVideoHandle, ParentRect) then
  begin
    SetWindowPos(
      FStatusWindow, HWND_TOPMOST,
      ParentRect.Left + 10,
      ParentRect.Bottom - 35,
      300, 25,
      SWP_NOACTIVATE or SWP_SHOWWINDOW
    );
    UpdateWindow(FStatusWindow);
  end;
end;

// ПРОСТЫЕ ПУБЛИЧНЫЕ МЕТОДЫ ДЛЯ STATUS LABEL

procedure TVlcPlayerEx.SetStatusText(const AText: string);
var
  DC: HDC;
  Rect: TRect;
  OldFont, NewFont: HGDIOBJ;
begin
  if FVideoHandle = 0 then Exit;

  // Создаем окно статуса если нужно
  if FStatusWindow = 0 then
    CreateStatusLabel;

  if FStatusWindow <> 0 then
  begin
    // Обновляем позицию
    UpdateStatusLayout;

    // Рисуем текст
    DC := GetDC(FStatusWindow);
    try
      // Очищаем область
      GetClientRect(FStatusWindow, Rect);
      FillRect(DC, Rect, GetStockObject(BLACK_BRUSH));

      // Рисуем текст если он есть
      if AText <> '' then
      begin
        SetBkMode(DC, TRANSPARENT);
        SetTextColor(DC, RGB(255, 255, 255));

        // Создаем шрифт
        NewFont := CreateFont(16, 0, 0, 0, FW_BOLD, 0, 0, 0, DEFAULT_CHARSET,
          OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY,
          DEFAULT_PITCH or FF_DONTCARE, 'Arial');
        OldFont := SelectObject(DC, NewFont);

        // Рисуем текст
        DrawText(DC, PChar(AText), -1, Rect, DT_LEFT or DT_VCENTER or DT_SINGLELINE);

        // Восстанавливаем шрифт
        SelectObject(DC, OldFont);
        DeleteObject(NewFont);
      end;
    finally
      ReleaseDC(FStatusWindow, DC);
    end;

    // Показываем/скрываем окно
    if AText <> '' then
      ShowWindow(FStatusWindow, SW_SHOWNA)
    else
      ShowWindow(FStatusWindow, SW_HIDE);

    Log('Статус установлен: ' + AText);
  end;
end;

procedure TVlcPlayerEx.ClearStatus;
begin
  SetStatusText('');
  Log('Статус очищен');
end;

function TVlcPlayerEx.GetStatusText: string;
begin
  // Для оконного статуса возвращаем пустую строку
  // так как текст рисуется непосредственно в окне
  Result := '';
end;

procedure TVlcPlayerEx.ShowStatus;
begin
  if FStatusWindow <> 0 then
    ShowWindow(FStatusWindow, SW_SHOWNA);
end;

procedure TVlcPlayerEx.HideStatus;
begin
  if FStatusWindow <> 0 then
    ShowWindow(FStatusWindow, SW_HIDE);
end;

// НОВЫЕ МЕТОДЫ ДЛЯ УПРАВЛЕНИЯ РОДИТЕЛЬСКИМ КОНТРОЛОМ

procedure TVlcPlayerEx.SaveOriginalParent;
begin
  // Не используется для оконного статуса
end;

procedure TVlcPlayerEx.TransferToVideoParent;
begin
  // Обновляем позицию статуса поверх видео
  UpdateStatusLayout;
  Log('Status Label перенесен на видео');
end;

procedure TVlcPlayerEx.TransferBackToOriginalParent;
begin
  // Скрываем статус при остановке
  HideStatus;
  Log('Status Label скрыт');
end;

// НОВЫЙ МЕТОД ДЛЯ ОБНОВЛЕНИЯ LAYOUT
procedure TVlcPlayerEx.UpdateVideoLayout;
begin
  // Обновляем позицию картинки
  UpdateLogoWindowPosition;

  // Обновляем позицию статуса
  UpdateStatusLayout;

  Log('Layout видеоплеера обновлен');
end;

// МЕТОДЫ ДЛЯ РИСОВАНИЯ КАРТИНКИ НА HANDLE

procedure TVlcPlayerEx.CreateLogoBitmap;
begin
  if FLogoBitmap = nil then
  begin
    FLogoBitmap := TBitmap.Create;
    FLogoBitmap.PixelFormat := pf32bit;
    FLogoBitmap.HandleType := bmDIB;
    FLogoBitmap.Transparent := False;
  end;
end;

procedure TVlcPlayerEx.DestroyLogoBitmap;
begin
  if Assigned(FLogoBitmap) then
  begin
    FLogoPaintTimer.Enabled := False;
    FLogoBitmap.Free;
    FLogoBitmap := nil;
  end;
end;

procedure TVlcPlayerEx.UpdateLogoPosition;
begin
  UpdateLogoWindowPosition;
end;

procedure TVlcPlayerEx.SetLogoVisible(const Value: Boolean);
begin
  if FLogoVisible <> Value then
  begin
    FLogoVisible := Value;

    if FLogoVisible then
    begin
      if IsLogoReady then
      begin
        if FLogoWindow = 0 then
          CreateLogoWindow;

        FLogoPaintTimer.Enabled := True;
        SetLogoWindowVisible(True);
        Log('Картинка показана');
      end
      else
      begin
        Log('Не удалось показать картинку: не готова');
      end;
    end
    else
    begin
      FLogoPaintTimer.Enabled := False;
      SetLogoWindowVisible(False);
      Log('Картинка скрыта');
    end;
  end;
end;

procedure TVlcPlayerEx.LogoPaintTimer(Sender: TObject);
begin
  if FLogoVisible and IsLogoReady then
  begin
    DrawLogoOnHandle;
  end
  else
  begin
    FLogoPaintTimer.Enabled := False;
  end;
end;

procedure TVlcPlayerEx.DrawLogoOnHandle;
var
  DC: HDC;
  BlendFunction: TBlendFunction;
  LogoDC: HDC;
  Bitmap: HBITMAP;
  OldBitmap: HGDIOBJ;
begin
  if not IsLogoReady then Exit;

  if FLogoWindow = 0 then
    CreateLogoWindow;

  if FLogoWindow = 0 then Exit;

  try
    DC := GetDC(FLogoWindow);
    if DC = 0 then Exit;

    try
      var ClearBrush := CreateSolidBrush(RGB(0, 0, 0));
      var OldBrush := SelectObject(DC, ClearBrush);
      PatBlt(DC, 0, 0, 50, 50, PATCOPY);
      SelectObject(DC, OldBrush);
      DeleteObject(ClearBrush);

      LogoDC := CreateCompatibleDC(DC);
      if LogoDC = 0 then Exit;

      try
        Bitmap := FLogoBitmap.Handle;
        OldBitmap := SelectObject(LogoDC, Bitmap);

        BlendFunction.BlendOp := AC_SRC_OVER;
        BlendFunction.BlendFlags := 0;
        BlendFunction.SourceConstantAlpha := 255;
        BlendFunction.AlphaFormat := AC_SRC_ALPHA;

        Windows.AlphaBlend(
          DC, 0, 0, 50, 50,
          LogoDC, 0, 0, FLogoBitmap.Width, FLogoBitmap.Height,
          BlendFunction
        );

        SelectObject(LogoDC, OldBitmap);

      finally
        DeleteDC(LogoDC);
      end;

    finally
      ReleaseDC(FLogoWindow, DC);
    end;

  except
    on E: Exception do
    begin
      Log('Ошибка рисования картинки: ' + E.Message);
    end;
  end;
end;

procedure TVlcPlayerEx.ForceRedrawLogo;
begin
  if FLogoVisible and IsLogoReady then
  begin
    UpdateLogoWindowPosition;
    DrawLogoOnHandle;
    if FLogoWindow <> 0 then
      UpdateWindow(FLogoWindow);
  end;
end;

procedure TVlcPlayerEx.UpdateLogo;
begin
  if FLogoVisible and IsLogoReady then
  begin
    UpdateLogoPosition;
    ForceRedrawLogo;
  end;
end;

// МЕТОДЫ ДЛЯ ОКНА КАРТИНКИ

procedure TVlcPlayerEx.CreateLogoWindow;
begin
  if FLogoWindow <> 0 then Exit;

  FLogoWindow := CreateWindowEx(
    WS_EX_LAYERED or WS_EX_TOPMOST or WS_EX_NOACTIVATE,
    'STATIC', nil, WS_POPUP,
    0, 0, 50, 50,
    FVideoHandle, 0, HInstance, nil
  );

  if FLogoWindow <> 0 then
  begin
    SetLayeredWindowAttributes(FLogoWindow, RGB(0, 0, 0), 0, LWA_COLORKEY);
    Log('Окно для картинки создано: ' + IntToStr(FLogoWindow));
  end
  else
  begin
    Log('Ошибка создания окна для картинки');
  end;
end;

procedure TVlcPlayerEx.DestroyLogoWindow;
begin
  if FLogoWindow <> 0 then
  begin
    DestroyWindow(FLogoWindow);
    FLogoWindow := 0;
  end;
end;

procedure TVlcPlayerEx.UpdateLogoWindowPosition;
var
  ParentRect: TRect;
begin
  if (FVideoHandle = 0) or (FLogoWindow = 0) then Exit;

  if not GetWindowRect(FVideoHandle, ParentRect) then Exit;

  SetWindowPos(
    FLogoWindow, HWND_TOPMOST,
    ParentRect.Right - 60, ParentRect.Top + 10,
    50, 50, SWP_NOACTIVATE or SWP_SHOWWINDOW
  );

  UpdateWindow(FLogoWindow);
end;

procedure TVlcPlayerEx.SetLogoWindowVisible(Visible: Boolean);
begin
  if FLogoWindow = 0 then Exit;

  if Visible then
  begin
    UpdateLogoWindowPosition;
    ShowWindow(FLogoWindow, SW_SHOWNA);
    DrawLogoOnHandle;
  end
  else
  begin
    ShowWindow(FLogoWindow, SW_HIDE);
  end;
end;

// НОВЫЕ МЕТОДЫ ДЛЯ РАБОТЫ С PNG

function TVlcPlayerEx.IsLogoReady: Boolean;
begin
  Result := (FLogoBitmap <> nil) and (not FLogoBitmap.Empty) and
            (FVideoHandle <> 0) and IsWindow(FVideoHandle) and
            (FLogoBitmap.Width > 0) and (FLogoBitmap.Height > 0);
end;

procedure TVlcPlayerEx.LoadLogoFromPNGFile(const AFileName: string);
var
  PNG: TPNGImage;
begin
  if not FileExists(AFileName) then
  begin
    Log('Файл PNG не найден: ' + AFileName);
    Exit;
  end;

  try
    if FLogoBitmap <> nil then
      DestroyLogoBitmap;

    CreateLogoBitmap;

    PNG := TPNGImage.Create;
    try
      PNG.LoadFromFile(AFileName);

      var OriginalWidth := PNG.Width;
      var OriginalHeight := PNG.Height;
      var Ratio := Math.Min(50 / OriginalWidth, 50 / OriginalHeight);
      var NewWidth := Round(OriginalWidth * Ratio);
      var NewHeight := Round(OriginalHeight * Ratio);

      FLogoBitmap.Width := NewWidth;
      FLogoBitmap.Height := NewHeight;
      FLogoBitmap.PixelFormat := pf32bit;

      FLogoBitmap.Canvas.Brush.Color := clBlack;
      FLogoBitmap.Canvas.FillRect(Rect(0, 0, NewWidth, NewHeight));

      var DestRect := Rect(0, 0, NewWidth, NewHeight);
      FLogoBitmap.Canvas.StretchDraw(DestRect, PNG);

      Log('PNG картинка загружена: ' + AFileName +
          ' Оригинал: ' + IntToStr(OriginalWidth) + 'x' + IntToStr(OriginalHeight) +
          ' Масштаб: ' + IntToStr(NewWidth) + 'x' + IntToStr(NewHeight));

    finally
      PNG.Free;
    end;

    FLogoFileName := AFileName;
    UpdateLogoPosition;

    if FLogoVisible then
    begin
      ForceRedrawLogo;
      FLogoPaintTimer.Enabled := True;
    end;

  except
    on E: Exception do
    begin
      Log('Ошибка загрузки PNG картинки: ' + E.Message);
      if FLogoBitmap <> nil then
        DestroyLogoBitmap;
    end;
  end;
end;

// Публичные методы для управления картинкой

procedure TVlcPlayerEx.LoadLogoFromFile(const AFileName: string);
var
  Ext: string;
begin
  if not FileExists(AFileName) then
  begin
    Log('Файл картинки не найден: ' + AFileName);
    Exit;
  end;

  Ext := LowerCase(ExtractFileExt(AFileName));

  if Ext = '.png' then
  begin
    LoadLogoFromPNGFile(AFileName);
  end
  else
  begin
    try
      if FLogoBitmap <> nil then
        DestroyLogoBitmap;

      CreateLogoBitmap;

      var TempBitmap := TBitmap.Create;
      try
        TempBitmap.LoadFromFile(AFileName);
        TempBitmap.PixelFormat := pf32bit;

        var Ratio := Math.Min(50 / TempBitmap.Width, 50 / TempBitmap.Height);
        var NewWidth := Round(TempBitmap.Width * Ratio);
        var NewHeight := Round(TempBitmap.Height * Ratio);

        FLogoBitmap.Width := NewWidth;
        FLogoBitmap.Height := NewHeight;
        FLogoBitmap.PixelFormat := pf32bit;

        FLogoBitmap.Canvas.Brush.Color := clBlack;
        FLogoBitmap.Canvas.FillRect(Rect(0, 0, NewWidth, NewHeight));
        FLogoBitmap.Canvas.StretchDraw(Rect(0, 0, NewWidth, NewHeight), TempBitmap);

      finally
        TempBitmap.Free;
      end;

      FLogoFileName := AFileName;
      UpdateLogoPosition;
      Log('Картинка загружена: ' + AFileName);

    except
      on E: Exception do
        Log('Ошибка загрузки картинки: ' + E.Message);
    end;
  end;

  if FLogoVisible then
    ForceRedrawLogo;
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

// НОВЫЕ МЕТОДЫ ДЛЯ РЕАЛЬНОГО ПРОГРЕССА

function TVlcPlayerEx.GetActualLoadingProgress: Integer;
var
  Duration, Position: Int64;
  BufferingLevel: Integer;
begin
  Result := -1;

  if not IsInitialized or (FPlayer = nil) then
    Exit;

  try
    BufferingLevel := GetBufferingLevel;

    if (BufferingLevel >= 0) and (BufferingLevel <= 100) then
    begin
      Result := BufferingLevel;
      Exit;
    end;

    Duration := GetDuration;
    Position := GetPosition;

    if (Duration > 0) and (Position >= 0) then
    begin
      Result := Round((Position / Duration) * 100);
      if Result > 100 then
        Result := 100;
    end
    else if (Duration = 0) and (FState = vlcLoading) then
    begin
      Result := 50;
    end;

  except
    on E: Exception do
    begin
      Log('Ошибка получения прогресса загрузки: ' + E.Message);
      Result := -1;
    end;
  end;
end;

procedure TVlcPlayerEx.UpdateRealLoadingProgress;
var
  ActualProgress: Integer;
  CurrentTime: Cardinal;
begin
  if not FIsLoading then Exit;

  ActualProgress := GetActualLoadingProgress;

  if ActualProgress >= 0 then
  begin
    if (ActualProgress > FLoadingProgress) or
       ((GetTickCount - FLastProgressUpdate) > 1000) then
    begin
      FLoadingProgress := ActualProgress;
      FLastProgressUpdate := GetTickCount;

      if (FLoadingProgress mod 25 = 0) or (FLoadingProgress = 100) then
        Log('Прогресс загрузки: ' + IntToStr(FLoadingProgress) + '%');

      if Assigned(FOnLoadingProgress) then
        FOnLoadingProgress(Self, FLoadingProgress);

      SetStatusText('Загрузка: ' + IntToStr(FLoadingProgress) + '%');
      SendLoadingEvent('LOADING_PROGRESS', FLoadingProgress);
    end;
  end
  else
  begin
    CurrentTime := GetTickCount;
    if (CurrentTime - FLoadStartTime) < 30000 then
    begin
      if (CurrentTime - FLastProgressUpdate) > 2000 then
      begin
        if FLoadingProgress < 80 then
          FLoadingProgress := FLoadingProgress + 10
        else if FLoadingProgress < 95 then
          FLoadingProgress := FLoadingProgress + 5;

        FLastProgressUpdate := CurrentTime;

        if Assigned(FOnLoadingProgress) then
          FOnLoadingProgress(Self, FLoadingProgress);

        SetStatusText('Подключение... ' + IntToStr(FLoadingProgress) + '%');
        SendLoadingEvent('LOADING_PROGRESS', FLoadingProgress);
      end;
    end
    else
    begin
      FIsLoading := False;
      SetState(vlcError);
      SetStatusText('Ошибка подключения');
      SendLoadingEvent('LOADING_ERROR');
      Log('Таймаут загрузки - превышено время ожидания');
    end;
  end;

  if (FLoadingProgress >= 95) and (FState = vlcPlaying) then
  begin
    FIsLoading := False;
    FLoadingProgress := 100;
    SetStatusText('');
    SendLoadingEvent('LOADING_COMPLETE');
    Log('Загрузка завершена');
  end;
end;

procedure TVlcPlayerEx.ProgressTimerTick(Sender: TObject);
begin
  if FIsLoading then
    UpdateRealLoadingProgress;
end;

// НОВЫЕ МЕТОДЫ ДЛЯ БУФЕРИЗАЦИИ И СЕТЕВЫХ ПОТОКОВ

function TVlcPlayerEx.GetBufferingLevel: Integer;
var
  BufferLevel: Single;
begin
  Result := -1;

  if not IsInitialized then
    Exit;

  if Assigned(T_libvlc_media_player_get_buffer) and (FPlayer <> nil) then
  begin
    try
      BufferLevel := T_libvlc_media_player_get_buffer(FPlayer);
      if BufferLevel >= 0 then
        Result := Round(BufferLevel * 100)
      else
        Result := -1;
    except
      Result := -1;
    end;
  end;
end;

function TVlcPlayerEx.IsNetworkStream: Boolean;
var
  Media: Plibvlc_media_t;
  MRL: PAnsiChar;
  MRLString: string;
begin
  Result := False;

  if (FPlayer <> nil) and
     Assigned(T_libvlc_media_player_get_media) and
     Assigned(T_libvlc_media_get_mrl) then
  begin
    Media := T_libvlc_media_player_get_media(FPlayer);
    if Media <> nil then
    begin
      MRL := T_libvlc_media_get_mrl(Media);
      if MRL <> nil then
      begin
        MRLString := LowerCase(string(MRL));
        Result := (Pos('http', MRLString) > 0) or
                  (Pos('rtsp', MRLString) > 0) or
                  (Pos('rtmp', MRLString) > 0) or
                  (Pos('udp', MRLString) > 0) or
                  (Pos('mms', MRLString) > 0) or
                  (Pos('rtp', MRLString) > 0);
      end;
    end;
  end;
end;

// НОВЫЕ МЕТОДЫ ДЛЯ ЗАПИСИ СОБЯТИЙ

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

procedure TVlcPlayerEx.SetQualityMode(const Value: TVlcQualityMode);
begin
  if FQualityMode <> Value then
  begin
    FQualityMode := Value;
    Log('Режим качества изменен');

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
  FProgressTimer.Enabled := False;

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
    Log('Состояние изменено');

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

  // ЗАГРУЗКА НОВЫХ ФУНКЦИЙ VLC
  @T_libvlc_media_player_get_buffer := GetProcAddress(FLibHandle, 'libvlc_media_player_get_buffer');
  @T_libvlc_media_player_get_media := GetProcAddress(FLibHandle, 'libvlc_media_player_get_media');
  @T_libvlc_media_get_mrl := GetProcAddress(FLibHandle, 'libvlc_media_get_mrl');

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
  FLoadStartTime := GetTickCount;
  FLastProgressUpdate := GetTickCount;

  FProgressTimer.Enabled := True;

  if Assigned(FOnLoading) then
    FOnLoading(Self);

  if Assigned(FOnLoadingProgress) then
    FOnLoadingProgress(Self, 0);

  SetStatusText('Подключение... 0%');

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

      UpdateVideoLayout;
    end;

    if Assigned(T_libvlc_audio_set_volume) then
      T_libvlc_audio_set_volume(FPlayer, FVolume);

    if Assigned(T_libvlc_audio_set_mute) then
      T_libvlc_audio_set_mute(FPlayer, Integer(FMuted));

    Log('Медиа успешно загружено');

    if FAutoPlay then
      Play
    else
      SetState(vlcPaused);

  except
    on E: Exception do
    begin
      FProgressTimer.Enabled := False;

      SetState(vlcError);
      FIsLoading := False;
      FLoadingProgress := 0;
      SetStatusText('Ошибка загрузки');
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
    SetStatusText('Запуск воспроизведения...')
  else
    SetStatusText('Перезапуск...');

  SendLoadingEvent('PLAYBACK_STARTING');

  ResultCode := T_libvlc_media_player_play(FPlayer);

  if ResultCode = 0 then
  begin
    Log('Команда воспроизведения отправлена');
    Log('Проверка состояния воспроизведения: ' + GetPlayerStatus);

    if FLogoVisible and IsLogoReady then
      FLogoPaintTimer.Enabled := True;
  end
  else
  begin
    SetState(vlcError);
    FIsLoading := False;
    FLoadingProgress := 0;
    SetStatusText('Ошибка воспроизведения');
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
  SetStatusText('Пауза');
  SendLoadingEvent('PLAYBACK_PAUSED');

  FLogoPaintTimer.Enabled := False;
end;

procedure TVlcPlayerEx.Stop;
begin
  if FPlayer = nil then Exit;

  Log('Остановка воспроизведения...');

  FProgressTimer.Enabled := False;
  T_libvlc_media_player_stop(FPlayer);

  SetState(vlcStopped);
  FIsLoading := False;
  FLoadingProgress := 0;

  FLogoPaintTimer.Enabled := False;

  SetStatusText('');
  SendLoadingEvent('PLAYBACK_STOPPED');
  Log('Воспроизведение остановлено');
end;

function TVlcPlayerEx.GetPlayerStatus: string;
begin
  case FState of
    vlcIdle: Result := 'Ожидание';
    vlcLoading: Result := 'Загрузка';
    vlcPlaying: Result := 'Воспроизведение';
    vlcPaused: Result := 'Пауза';
    vlcStopped: Result := 'Остановлен';
    vlcError: Result := 'Ошибка';
  else
    Result := 'Неизвестно';
  end;
end;

end.
