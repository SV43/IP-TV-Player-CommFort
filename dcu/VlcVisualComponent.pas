unit VlcVisualComponent;

interface

uses
  Windows, Messages, SysUtils, Classes, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Dialogs,
  TypInfo, Vcl.Graphics, Vcl.Controls, Vcl.Imaging.pngimage, Math, Vcl.Imaging.jpeg, Vcl.Menus;

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

  // События мыши
  TVlcMouseEvent = procedure(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer) of object;
  TVlcMouseMoveEvent = procedure(Sender: TObject; Shift: TShiftState; X, Y: Integer) of object;
  TVlcMouseWheelEvent = procedure(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint) of object;

  // Текстовая информация для отображения
  TDisplayTextItem = class(TPersistent)
  private
    FText: string;
    FFontSize: Integer;
    FFontColor: TColor;
    FFontStyle: TFontStyles;
    FX: Integer;
    FY: Integer;
    FVisible: Boolean;
    FOnChange: TNotifyEvent;
    procedure SetText(const Value: string);
    procedure SetFontSize(const Value: Integer);
    procedure SetFontColor(const Value: TColor);
    procedure SetFontStyle(const Value: TFontStyles);
    procedure SetX(const Value: Integer);
    procedure SetY(const Value: Integer);
    procedure SetVisible(const Value: Boolean);
  protected
    procedure Changed;
  public
    constructor Create;
    procedure Assign(Source: TPersistent); override;
  published
    property Text: string read FText write SetText;
    property FontSize: Integer read FFontSize write SetFontSize default 12;
    property FontColor: TColor read FFontColor write SetFontColor default clWhite;
    property FontStyle: TFontStyles read FFontStyle write SetFontStyle default [];
    property X: Integer read FX write SetX default 20;
    property Y: Integer read FY write SetY default 20;
    property Visible: Boolean read FVisible write SetVisible default True;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  TVlcPlayer = class(TCustomPanel)
  private
    FLibPath: string;              // Путь к библиотеке VLC
    FLibHandle: THandle;           // Хэндл загруженной библиотеки
    FState: TVlcState;             // Текущее состояние плеера
    FMediaURL: string;             // URL медиа-потока
    FVolume: Integer;              // Громкость (0-100)
    FAutoPlay: Boolean;            // Автоматическое воспроизведение
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

    // Дочерняя панель для видео с отступами

    FVideoTopMargin: Integer;      // Отступ сверху для видео
    FVideoBottomMargin: Integer;   // Отступ снизу для видео

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

    // НОВЫЕ СОБЫТИЯ МЫШИ
    FOnVideoMouseDown: TVlcMouseEvent;
    FOnVideoMouseUp: TVlcMouseEvent;
    FOnVideoMouseMove: TVlcMouseMoveEvent;
    FOnVideoClick: TVlcNotifyEvent;
    FOnVideoDblClick: TVlcNotifyEvent;
    FOnVideoMouseWheel: TVlcMouseWheelEvent;

    // Текстовые элементы для отображения
    FInfoText: TDisplayTextItem;
    FShowTextWhenIdle: Boolean;

    // Изображения
    FTopImage: TPicture;
    FShowTopImage: Boolean;

    // Для перехвата сообщений мыши
    FOriginalWndProc: TWndMethod;
    FLastMousePos: TPoint;
    FMouseCapture: Boolean;

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

    // Методы для записи событий
    procedure SendLoadingEvent(const AEvent: string; AProgress: Integer = -1);
    procedure SendStateEvent(const AState: string);

    // Методы для буферизации и сетевых потоков
    function GetBufferingLevel: Integer;
    function IsNetworkStream: Boolean;

    // Методы для реального прогресса
    procedure UpdateRealLoadingProgress;
    procedure ProgressTimerTick(Sender: TObject);

    // Методы для видео панели с отступами
    procedure CreateVideoPanel;
    procedure DestroyVideoPanel;
    procedure UpdateVideoPanelMargins;

    // Методы для текста и изображений
    procedure SetInfoText(const Value: TDisplayTextItem);
    procedure SetShowTextWhenIdle(const Value: Boolean);
    procedure TextItemChanged(Sender: TObject);
    procedure SetTopImage(const Value: TPicture);
    procedure SetShowTopImage(const Value: Boolean);
    procedure CreateHandle;
    procedure DestroyWnd;

    // НОВЫЕ МЕТОДЫ ДЛЯ ПЕРЕХВАТА СОБЫТИЙ МЫШИ
    procedure MainWndProc(var Message: TMessage);
    function GetShiftState: TShiftState;
    function ScreenToVideo(const ScreenPos: TPoint): TPoint;
    function IsPointInVideoPanel(const P: TPoint): Boolean;

  protected
    procedure Paint; override;
    procedure WndProc(var Message: TMessage); override;
    procedure Resize; override;

  public
    FVideoHandle: HWND;            // Хэндл окна для вывода видео
    FVideoPanel: TPanel;           // Панель для вывода видео
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    // Основные методы управления
    procedure Play;
    procedure Pause;
    procedure Stop;
    procedure LoadMedia(const APath: string);
    procedure UpdateVideoHandle;

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

    // Методы для исправления видео вывода
    procedure ReattachVideo;
    procedure FixVideoOutput;

    // Методы для управления отступами видео
    procedure SetVideoMargins(TopMargin, BottomMargin: Integer);
    procedure ResetVideoMargins;

    // Методы для работы с текстом и изображениями
    procedure SetDisplayText(const Info: string);
    procedure UpdateInfo(const Text: string);
    procedure SetTextPositionXY(X, Y: Integer);
    procedure SetTextFont(Size: Integer; Color: TColor; Style: TFontStyles);
    procedure ShowAll;
    procedure HideAll;

    // Методы для работы с мышью
    procedure EnableMouseEvents;

    // Публичные свойства
    property Handle: HWND read FVideoHandle;
    property AutoDetectProtectedStreams: Boolean read FAutoDetectProtectedStreams write FAutoDetectProtectedStreams default True;
    property ForceWinkHeaders: Boolean read FForceWinkHeaders write FForceWinkHeaders default False;
    property LoadingProgress: Integer read FLoadingProgress;
    property IsLoading: Boolean read FIsLoading;
    property QualityMode: TVlcQualityMode read FQualityMode write SetQualityMode;
    property ForcedBitrate: Integer read FForcedBitrate write SetForcedBitrate;
    property ForcedResolution: string read FForcedResolution write SetForcedResolution;
    property Muted: Boolean read GetMuted write SetMuted;
    property VideoTopMargin: Integer read FVideoTopMargin;
    property VideoBottomMargin: Integer read FVideoBottomMargin;

    function GetCurrentMediaURL: string;
    procedure SetNewParent(NewParent: TWinControl);
    function GetActualLoadingProgress: Integer;
    function IsPointInVideoArea(const P: TPoint): Boolean;

    procedure ForceRehookMouseEvents;
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

    // Текстовые элементы
    property InfoText: TDisplayTextItem read FInfoText write SetInfoText;
    property ShowTextWhenIdle: Boolean read FShowTextWhenIdle write SetShowTextWhenIdle default True;

    // Изображения
    property TopImage: TPicture read FTopImage write SetTopImage;
    property ShowTopImage: Boolean read FShowTopImage write SetShowTopImage default True;

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

    // НОВЫЕ СОБЫТИЯ МЫШИ ДЛЯ ВИДЕО ПОТОКА
    property OnVideoMouseDown: TVlcMouseEvent read FOnVideoMouseDown write FOnVideoMouseDown;
    property OnVideoMouseUp: TVlcMouseEvent read FOnVideoMouseUp write FOnVideoMouseUp;
    property OnVideoMouseMove: TVlcMouseMoveEvent read FOnVideoMouseMove write FOnVideoMouseMove;
    property OnVideoClick: TVlcNotifyEvent read FOnVideoClick write FOnVideoClick;
    property OnVideoDblClick: TVlcNotifyEvent read FOnVideoDblClick write FOnVideoDblClick;
    property OnVideoMouseWheel: TVlcMouseWheelEvent read FOnVideoMouseWheel write FOnVideoMouseWheel;

    // Свойства TCustomPanel
    property Align;
    property Alignment;
    property Anchors;
    property BevelEdges;
    property BevelInner;
    property BevelKind;
    property BevelOuter;
    property BevelWidth;
    property BiDiMode;
    property BorderWidth;
    property BorderStyle;
    property Color;
    property Constraints;
    property Ctl3D;
    property UseDockManager default True;
    property DockSite;
    property DoubleBuffered;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property FullRepaint;
    property Font;
    property Locked;
    property Padding;
    property ParentBiDiMode;
    property ParentBackground;
    property ParentColor;
    property ParentCtl3D;
    property ParentDoubleBuffered;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Touch;
    property VerticalAlignment;
    property Visible;
    property StyleElements;
    property OnAlignInsertBefore;
    property OnAlignPosition;
    property OnCanResize;
    property OnClick;
    property OnConstrainedResize;
    property OnContextPopup;
    property OnDockDrop;
    property OnDockOver;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDock;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnGesture;
    property OnGetSiteInfo;
    property OnMouseActivate;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
    property OnStartDock;
    property OnStartDrag;
    property OnUnDock;
  end;

procedure Register;

implementation

{ TDisplayTextItem }

constructor TDisplayTextItem.Create;
begin
  inherited Create;
  FText := '';
  FFontSize := 12;
  FFontColor := clWhite;
  FFontStyle := [];
  FX := 20;
  FY := 20;
  FVisible := True;
end;

procedure TDisplayTextItem.Assign(Source: TPersistent);
begin
  if Source is TDisplayTextItem then
  begin
    FText := TDisplayTextItem(Source).Text;
    FFontSize := TDisplayTextItem(Source).FontSize;
    FFontColor := TDisplayTextItem(Source).FontColor;
    FFontStyle := TDisplayTextItem(Source).FontStyle;
    FX := TDisplayTextItem(Source).X;
    FY := TDisplayTextItem(Source).Y;
    FVisible := TDisplayTextItem(Source).Visible;
    Changed;
  end
  else
    inherited Assign(Source);
end;

procedure TDisplayTextItem.Changed;
begin
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TDisplayTextItem.SetText(const Value: string);
begin
  if FText <> Value then
  begin
    FText := Value;
    Changed;
  end;
end;

procedure TDisplayTextItem.SetFontSize(const Value: Integer);
begin
  if FFontSize <> Value then
  begin
    FFontSize := Value;
    Changed;
  end;
end;

procedure TDisplayTextItem.SetFontColor(const Value: TColor);
begin
  if FFontColor <> Value then
  begin
    FFontColor := Value;
    Changed;
  end;
end;

procedure TDisplayTextItem.SetFontStyle(const Value: TFontStyles);
begin
  if FFontStyle <> Value then
  begin
    FFontStyle := Value;
    Changed;
  end;
end;

procedure TDisplayTextItem.SetX(const Value: Integer);
begin
  if FX <> Value then
  begin
    FX := Value;
    Changed;
  end;
end;

procedure TDisplayTextItem.SetY(const Value: Integer);
begin
  if FY <> Value then
  begin
    FY := Value;
    Changed;
  end;
end;

procedure TDisplayTextItem.SetVisible(const Value: Boolean);
begin
  if FVisible <> Value then
  begin
    FVisible := Value;
    Changed;
  end;
end;

procedure Register;
begin
  RegisterComponents('Samples', [TVlcPlayer]);
end;

// Константы событий VLC
const
  libvlc_MediaPlayerBuffering = 3;
  libvlc_MediaPlayerPlaying = 4;
  libvlc_MediaPlayerPaused = 5;
  libvlc_MediaPlayerStopped = 6;
  libvlc_MediaPlayerEndReached = 7;
  libvlc_MediaPlayerEncounteredError = 8;

// Callback функция для обработки событий VLC
procedure VlcEventCallback(p_event: Pointer; user_data: Pointer); cdecl;
var
  Player: TVlcPlayer;
  EventType: Integer;
begin
  Player := TVlcPlayer(user_data);
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

        if Assigned(Player.FOnLoadingProgress) then
          Player.FOnLoadingProgress(Player, 100);

        Player.SendLoadingEvent('PLAYING');
        Player.SendStateEvent('PLAYING');
        Player.Log('Воспроизведение началось');
      end;

    libvlc_MediaPlayerPaused:
      begin
        Player.SetState(vlcPaused);
        Player.Log('Воспроизведение приостановлено');
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

        Player.SendLoadingEvent('STOPPED');
        Player.SendStateEvent('STOPPED');
      end;

    libvlc_MediaPlayerEndReached:
      begin
        Player.Log('Воспроизведение завершено');

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

        Player.SendLoadingEvent('ERROR');
        Player.SendStateEvent('ERROR');
      end;
  end;
end;

{ TVlcPlayer }

function TVlcPlayer.IsPointInVideoArea(const P: TPoint): Boolean;
begin
  Result := False;
  if FVideoPanel = nil then Exit;

  Result := (P.X >= FVideoPanel.Left) and
            (P.Y >= FVideoPanel.Top) and
            (P.X < FVideoPanel.Left + FVideoPanel.Width) and
            (P.Y < FVideoPanel.Top + FVideoPanel.Height);
end;

procedure TVlcPlayer.ForceRehookMouseEvents;
begin
  Log('ForceRehookMouseEvents: Starting forced mouse hook reinitialization...');

  try
    // 1. Временно отключаем перехват
    if Assigned(FOriginalWndProc) then
    begin
      WindowProc := FOriginalWndProc;
      Log('ForceRehookMouseEvents: Original WndProc restored temporarily');
    end;

    // 2. Ждем немного для стабильности
    Sleep(10);

    // 3. Принудительно обновляем видео handle
    UpdateVideoHandle;

    if FVideoHandle <> 0 then
    begin
      Log(Format('ForceRehookMouseEvents: Video handle updated to %d', [FVideoHandle]));
    end
    else
    begin
      Log('ForceRehookMouseEvents: WARNING - Video handle is zero!');
    end;

    // 4. Снова включаем перехват
    FOriginalWndProc := WindowProc;
    WindowProc := MainWndProc;

    // 5. Принудительно обновляем геометрию
    UpdateVideoPanelMargins;

    // 6. Логируем состояние
    if FVideoPanel <> nil then
    begin
      Log(Format('ForceRehookMouseEvents: Video panel at [%d,%d,%d,%d]',
        [FVideoPanel.Left, FVideoPanel.Top, FVideoPanel.Width, FVideoPanel.Height]));
    end
    else
    begin
      Log('ForceRehookMouseEvents: WARNING - Video panel is nil!');
    end;

    Log('ForceRehookMouseEvents: Mouse hook force re-established successfully');

  except
    on E: Exception do
    begin
      Log(Format('ForceRehookMouseEvents: ERROR - %s', [E.Message]));
      // Пытаемся восстановить перехват даже при ошибке
      if Assigned(FOriginalWndProc) then
      begin
        FOriginalWndProc := WindowProc;
        WindowProc := MainWndProc;
        Log('ForceRehookMouseEvents: Emergency mouse hook restoration attempted');
      end;
    end;
  end;
end;

// НОВЫЕ МЕТОДЫ ДЛЯ ПЕРЕХВАТА СОБЫТИЙ МЫШИ
procedure TVlcPlayer.MainWndProc(var Message: TMessage);
var
  Shift: TShiftState;
  WheelDelta: Integer;
  MousePos, VideoPos: TPoint;
  Handled: Boolean;

  function GetMouseButton: TMouseButton;
  begin
    case Message.Msg of
      WM_LBUTTONDOWN, WM_LBUTTONUP, WM_LBUTTONDBLCLK: Result := mbLeft;
      WM_RBUTTONDOWN, WM_RBUTTONUP, WM_RBUTTONDBLCLK: Result := mbRight;
      WM_MBUTTONDOWN, WM_MBUTTONUP, WM_MBUTTONDBLCLK: Result := mbMiddle;
    else
      Result := mbLeft;
    end;
  end;

begin
  Handled := False;
  Shift := GetShiftState;

  case Message.Msg of
    WM_MOUSEWHEEL:
      begin
        if IsPointInVideoPanel(SmallPointToPoint(TSmallPoint(Message.LParam))) then
        begin
          WheelDelta := SmallInt(Message.WParam shr 16);
          MousePos := SmallPointToPoint(TSmallPoint(Message.LParam));
          VideoPos := ScreenToVideo(MousePos);

          Log(Format('MAIN MOUSEWHEEL: Delta=%d, Screen(%d,%d) -> Video(%d,%d)',
            [WheelDelta, MousePos.X, MousePos.Y, VideoPos.X, VideoPos.Y]));

          if Assigned(FOnVideoMouseWheel) then
            FOnVideoMouseWheel(Self, Shift, WheelDelta, VideoPos);

          Message.Result := 1;
          Handled := True;
        end;
      end;

    WM_LBUTTONDOWN, WM_RBUTTONDOWN, WM_MBUTTONDOWN:
      begin
        if IsPointInVideoPanel(SmallPointToPoint(TSmallPoint(Message.LParam))) then
        begin
          MousePos := SmallPointToPoint(TSmallPoint(Message.LParam));
          VideoPos := ScreenToVideo(MousePos);

          Log(Format('MAIN MOUSEDOWN: Button=%d, Screen(%d,%d) -> Video(%d,%d)',
            [Ord(GetMouseButton), MousePos.X, MousePos.Y, VideoPos.X, VideoPos.Y]));

          if Assigned(FOnVideoMouseDown) then
            FOnVideoMouseDown(Self, GetMouseButton, Shift, VideoPos.X, VideoPos.Y);

          // Захватываем мышь для отслеживания перемещения
          SetCapture(Handle);
          FMouseCapture := True;
          FLastMousePos := MousePos;

          Handled := True;
        end;
      end;

    WM_LBUTTONUP, WM_RBUTTONUP, WM_MBUTTONUP:
      begin
        if FMouseCapture then
        begin
          ReleaseCapture;
          FMouseCapture := False;

          MousePos := SmallPointToPoint(TSmallPoint(Message.LParam));
          VideoPos := ScreenToVideo(MousePos);

          Log(Format('MAIN MOUSEUP: Button=%d, Screen(%d,%d) -> Video(%d,%d)',
            [Ord(GetMouseButton), MousePos.X, MousePos.Y, VideoPos.X, VideoPos.Y]));

          if Assigned(FOnVideoMouseUp) then
            FOnVideoMouseUp(Self, GetMouseButton, Shift, VideoPos.X, VideoPos.Y);

          // Вызываем Click для левой кнопки
          if (GetMouseButton = mbLeft) and Assigned(FOnVideoClick) then
            FOnVideoClick(Self);

          Handled := True;
        end;
      end;

    WM_LBUTTONDBLCLK, WM_RBUTTONDBLCLK, WM_MBUTTONDBLCLK:
      begin
        if IsPointInVideoPanel(SmallPointToPoint(TSmallPoint(Message.LParam))) then
        begin
          MousePos := SmallPointToPoint(TSmallPoint(Message.LParam));
          VideoPos := ScreenToVideo(MousePos);

          Log(Format('MAIN MOUSEDBLCLK: Button=%d, Screen(%d,%d) -> Video(%d,%d)',
            [Ord(GetMouseButton), MousePos.X, MousePos.Y, VideoPos.X, VideoPos.Y]));

          // Вызываем двойной клик для левой кнопки
          if (GetMouseButton = mbLeft) and Assigned(FOnVideoDblClick) then
            FOnVideoDblClick(Self);

          Handled := True;
        end;
      end;

    WM_MOUSEMOVE:
      begin
        if FMouseCapture then
        begin
          MousePos := SmallPointToPoint(TSmallPoint(Message.LParam));

          // Фильтруем частые сообщения
          if (Abs(MousePos.X - FLastMousePos.X) > 2) or
             (Abs(MousePos.Y - FLastMousePos.Y) > 2) then
          begin
            VideoPos := ScreenToVideo(MousePos);

            if Random(5) = 0 then // Логируем каждое 5-е сообщение
              Log(Format('MAIN MOUSEMOVE: Screen(%d,%d) -> Video(%d,%d)',
                [MousePos.X, MousePos.Y, VideoPos.X, VideoPos.Y]));

            if Assigned(FOnVideoMouseMove) then
              FOnVideoMouseMove(Self, Shift, VideoPos.X, VideoPos.Y);

            FLastMousePos := MousePos;
          end;
        end;
      end;

    WM_CAPTURECHANGED:
      begin
        FMouseCapture := False;
        Log('Mouse capture lost');
      end;
  end;

  if not Handled then
  begin
    // Передаем сообщение оригинальному обработчику
    if Assigned(FOriginalWndProc) then
      FOriginalWndProc(Message)
    else
      inherited WndProc(Message);
  end;
end;

function TVlcPlayer.GetShiftState: TShiftState;
begin
  Result := [];
  if GetKeyState(VK_SHIFT) < 0 then Include(Result, ssShift);
  if GetKeyState(VK_CONTROL) < 0 then Include(Result, ssCtrl);
  if GetKeyState(VK_MENU) < 0 then Include(Result, ssAlt);
  if GetKeyState(VK_LBUTTON) < 0 then Include(Result, ssLeft);
  if GetKeyState(VK_RBUTTON) < 0 then Include(Result, ssRight);
  if GetKeyState(VK_MBUTTON) < 0 then Include(Result, ssMiddle);
end;

function TVlcPlayer.ScreenToVideo(const ScreenPos: TPoint): TPoint;
begin
  Result := ScreenToClient(ScreenPos);
  if FVideoPanel <> nil then
  begin
    // Преобразуем координаты компонента в координаты видео панели
    Result.X := Result.X - FVideoPanel.Left;
    Result.Y := Result.Y - FVideoPanel.Top;

    // Ограничиваем координаты размерами видео панели
    Result.X := Max(0, Min(Result.X, FVideoPanel.Width - 1));
    Result.Y := Max(0, Min(Result.Y, FVideoPanel.Height - 1));
  end;
end;

function TVlcPlayer.IsPointInVideoPanel(const P: TPoint): Boolean;
begin
  Result := False;
  if FVideoPanel = nil then Exit;

  var LocalPoint := ScreenToClient(P);
  Result := PtInRect(FVideoPanel.BoundsRect, LocalPoint);
end;

procedure TVlcPlayer.EnableMouseEvents;
begin
  Log('Активация перехвата событий мыши...');

  // Принудительно обновляем handle
  UpdateVideoHandle;

  // Убедимся что перехват активен
  if not Assigned(FOriginalWndProc) then
  begin
    FOriginalWndProc := WindowProc;
    WindowProc := MainWndProc;
  end;

  Log('Перехват событий мыши активирован');
end;

procedure TVlcPlayer.SetNewParent(NewParent: TWinControl);
begin
  if FPlayer = nil then Exit;

  // Останавливаем воспроизведение
  if IsPlaying then
    T_libvlc_media_player_stop(FPlayer);

  // Меняем родителя
  Parent := NewParent;

  // Обновляем видео handle
  if NewParent <> nil then
  begin
    UpdateVideoHandle;
    if FVideoHandle <> 0 then
    begin
      T_libvlc_media_player_set_hwnd(FPlayer, Pointer(FVideoHandle));
      Log('Video output установлен на новый parent');
    end;
  end;

  // Перезапускаем воспроизведение, если было запущено
  if FState = vlcPlaying then
    T_libvlc_media_player_play(FPlayer);
end;

procedure TVlcPlayer.CreateVideoPanel;
begin
  if FVideoPanel = nil then
  begin
    FVideoPanel := TPanel.Create(Self);
    FVideoPanel.Parent := Self;

    // Устанавливаем отступы
    FVideoTopMargin := 50;
    FVideoBottomMargin := 20;
    UpdateVideoPanelMargins;

    FVideoPanel.BevelOuter := bvNone;
    FVideoPanel.Color := clBlack; // Сделаем красным для тестирования видимости
    FVideoPanel.ParentBackground := False;
    FVideoPanel.Visible := True;

    // ВАЖНО: Отключаем стандартную обработку мыши для видео панели
    FVideoPanel.Enabled := False; // Это предотвратит конфликты с VLC

    FVideoPanel.HandleNeeded;
    FVideoHandle := FVideoPanel.Handle;

    Log('Видео панель создана (красная для теста), Handle: ' + IntToStr(FVideoHandle));
    Log('Мышь: события будут перехватываться основным компонентом');
  end;
end;

procedure TVlcPlayer.DestroyVideoPanel;
begin
  if FVideoPanel <> nil then
  begin
    FVideoPanel.Free;
    FVideoPanel := nil;
    FVideoHandle := 0;
  end;
end;

procedure TVlcPlayer.UpdateVideoHandle;
begin
  if FVideoPanel = nil then
    CreateVideoPanel;

  if FVideoPanel <> nil then
  begin
    FVideoHandle := FVideoPanel.Handle;

    // Убедимся, что окно действительно создано
    if IsWindow(FVideoHandle) then
    begin
      Log('Video handle обновлен: ' + IntToStr(FVideoHandle));
    end
    else
    begin
      Log('Ошибка: Video handle невалиден');
    end;
  end;
end;

procedure TVlcPlayer.UpdateVideoPanelMargins;
begin
  if FVideoPanel <> nil then
  begin
    // ИСПОЛЬЗУЕМ ClientWidth вместо Width!
    var NewWidth := ClientWidth;
    var NewHeight := ClientHeight - FVideoTopMargin - FVideoBottomMargin;

    if NewWidth < 10 then NewWidth := 10;
    if NewHeight < 10 then NewHeight := 10;

    FVideoPanel.SetBounds(
      0,
      FVideoTopMargin,
      NewWidth,
      NewHeight
    );

    Log(Format('VIDEO PANEL UPDATED: [L:%d,T:%d,W:%d,H:%d] (Client: %dx%d, Bounds: %dx%d)',
      [FVideoPanel.Left, FVideoPanel.Top, FVideoPanel.Width, FVideoPanel.Height,
       ClientWidth, ClientHeight, Width, Height]));
  end;
end;
procedure TVlcPlayer.SetVideoMargins(TopMargin, BottomMargin: Integer);
begin
  if (FVideoTopMargin <> TopMargin) or (FVideoBottomMargin <> BottomMargin) then
  begin
    FVideoTopMargin := TopMargin;
    FVideoBottomMargin := BottomMargin;

    Log(Format('Установлены новые отступы: верх=%dpx, низ=%dpx', [TopMargin, BottomMargin]));

    // Обновляем положение видео панели
    UpdateVideoPanelMargins;

    // Перерисовываем компонент
    Invalidate;
  end;
end;

procedure TVlcPlayer.ResetVideoMargins;
begin
  SetVideoMargins(60, 60); // 60px сверху и снизу по умолчанию
end;

constructor TVlcPlayer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  // Настройка внешнего вида панели
  Width := 320;
  Height := 240;
  Color := clBlack;
  BevelOuter := bvNone;
  ParentBackground := False;

  // Устанавливаем стиль для корректного отображения видео
  ControlStyle := ControlStyle + [csOpaque, csAcceptsControls];

  // Инициализация видео панели
  FVideoPanel := nil;

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

  // Инициализация отступов
  FVideoTopMargin := 60;
  FVideoBottomMargin := 60;

  // Инициализация новых полей для прогресса
  FLoadStartTime := 0;
  FLastProgressUpdate := 0;

  // Создаем таймер для обновления прогресса загрузки
  FProgressTimer := TTimer.Create(Self);
  FProgressTimer.Interval := 500;
  FProgressTimer.Enabled := False;
  FProgressTimer.OnTimer := ProgressTimerTick;

  // Инициализация текстовых элементов
  FInfoText := TDisplayTextItem.Create;
  FInfoText.Text := '';
  FInfoText.FontSize := 10;
  FInfoText.FontColor := clWhite;
  FInfoText.X := 20;
  FInfoText.Y := Height - 20;
  FInfoText.OnChange := TextItemChanged;

  FShowTextWhenIdle := True;

  // Инициализация изображений
  FTopImage := TPicture.Create;
  FShowTopImage := True;

  // Инициализация перехвата мыши
  FOriginalWndProc := nil;
  FMouseCapture := False;
  FLastMousePos := Point(0, 0);

  // ПЕРЕХВАТЫВАЕМ СООБЩЕНИЯ НА УРОВНЕ ОСНОВНОГО КОМПОНЕНТА
  FOriginalWndProc := WindowProc;
  WindowProc := MainWndProc;

  // Устанавливаем базовые заголовки по умолчанию
  SetBasicHeaders;

  Log('VLC Player создан. Перехват событий мыши активирован.');
end;



destructor TVlcPlayer.Destroy;
begin
  // Обнуляем события для избежания access violation
  FOnLog := nil;
  FOnLoadingProgress := nil;
  FOnBuffering := nil;
  FOnQualityChanged := nil;

  // ОБНУЛЯЕМ СОБЫТИЯ МЫШИ
  FOnVideoMouseDown := nil;
  FOnVideoMouseUp := nil;
  FOnVideoMouseMove := nil;
  FOnVideoClick := nil;
  FOnVideoDblClick := nil;
  FOnVideoMouseWheel := nil;

  // Восстанавливаем оригинальный WndProc
  if Assigned(FOriginalWndProc) then
    WindowProc := FOriginalWndProc;

  // Останавливаем таймер
  FProgressTimer.Enabled := False;

  // Уничтожаем видео панель
  DestroyVideoPanel;

  // Освобождаем ресурсы VLC
  FreeVLC;

  // Освобождаем текстовые элементы и изображения
  FInfoText.Free;
  FTopImage.Free;

  // Освобождаем объекты
  FHttpHeaders.Free;
  FProgressTimer.Free;

  inherited Destroy;
end;



procedure TVlcPlayer.TextItemChanged(Sender: TObject);
begin
  Invalidate;
end;

procedure TVlcPlayer.SetInfoText(const Value: TDisplayTextItem);
begin
  FInfoText.Assign(Value);
end;

procedure TVlcPlayer.SetShowTextWhenIdle(const Value: Boolean);
begin
  if FShowTextWhenIdle <> Value then
  begin
    FShowTextWhenIdle := Value;
    Invalidate;
  end;
end;

procedure TVlcPlayer.SetTopImage(const Value: TPicture);
begin
  FTopImage.Assign(Value);
  Invalidate;
end;

procedure TVlcPlayer.SetShowTopImage(const Value: Boolean);
begin
  if FShowTopImage <> Value then
  begin
    FShowTopImage := Value;
    Invalidate;
  end;
end;

procedure TVlcPlayer.CreateHandle;
begin
  inherited CreateHandle;

  // Создаем видео панель при создании handle
  UpdateVideoHandle;

  if FVideoHandle <> 0 then
  begin
    // Устанавливаем стили окна для корректного отображения видео
    SetWindowLong(FVideoHandle, GWL_STYLE,
      GetWindowLong(FVideoHandle, GWL_STYLE) or WS_CLIPCHILDREN or WS_CLIPSIBLINGS);

    Log('Handle компонента создан и настроен для видео: ' + IntToStr(FVideoHandle));
  end;
end;

procedure TVlcPlayer.DestroyWnd;
begin
  // Останавливаем воспроизведение перед уничтожением окна
  Stop;
  inherited DestroyWnd;
end;

procedure TVlcPlayer.Resize;
begin
  inherited Resize;

  Log(Format('RESIZE: Client=%dx%d, Bounds=%dx%d',
    [ClientWidth, ClientHeight, Width, Height]));

  // Обновляем размер видео панели с учетом отступов
  UpdateVideoPanelMargins;

  // Обновляем позицию текста
  FInfoText.Y := ClientHeight - 20;

  ForceRehookMouseEvents;

  // Принудительно переустанавливаем видео вывод при изменении размера
  if (FPlayer <> nil) and (FVideoHandle <> 0) and IsPlaying then
  begin
    Sleep(50);
    T_libvlc_media_player_set_hwnd(FPlayer, Pointer(FVideoHandle));
  end;
end;

procedure TVlcPlayer.WndProc(var Message: TMessage);
begin
  if Message.Msg = WM_USER + 1 then
  begin
    if (FPlayer <> nil) and (FVideoHandle <> 0) then
    begin
      T_libvlc_media_player_set_hwnd(FPlayer, Pointer(FVideoHandle));
      Log('Повторная установка video output после начала воспроизведения');
    end;
  end
  else
    inherited WndProc(Message);
end;

procedure TVlcPlayer.ReattachVideo;
begin
  if (FPlayer <> nil) and (FVideoHandle <> 0) then
  begin
    Log('Принудительная переустановка видео вывода');
    T_libvlc_media_player_set_hwnd(FPlayer, Pointer(FVideoHandle));

    // Даем время на применение изменений
    Sleep(100);

    Invalidate;
  end;
end;

procedure TVlcPlayer.FixVideoOutput;
begin
  if FPlayer = nil then Exit;

  Log('Исправление видео вывода...');

  // Останавливаем воспроизведение
  T_libvlc_media_player_stop(FPlayer);
  Sleep(100);

  // Переустанавливаем handle
  if FVideoHandle <> 0 then
  begin
    T_libvlc_media_player_set_hwnd(FPlayer, Pointer(FVideoHandle));
    Log('Video output переустановлен на handle: ' + IntToStr(FVideoHandle));
  end;

  // Запускаем воспроизведение
  Sleep(100);
  T_libvlc_media_player_play(FPlayer);
end;

procedure TVlcPlayer.Paint;
var
  ImgRect: TRect;
begin
  inherited Paint;

  // Рисуем черный фон если видео не воспроизводится
  if FState = vlcIdle then
  begin
    Canvas.Brush.Color := clBlack;
    Canvas.FillRect(ClientRect);
  end;

  // Верхнее изображение (всегда отображается)
  if FShowTopImage and (FTopImage.Width > 0) and (FTopImage.Height > 0) then
  begin
    // Располагаем изображение в правом верхнем углу
    ImgRect := Rect(Width - 45, 0, Width, 45);
    Canvas.StretchDraw(ImgRect, FTopImage.Graphic);
  end;

  // Нижний текст (всегда отображается)
  if FShowTextWhenIdle and FInfoText.Visible and (FInfoText.Text <> '') then
  begin
    Canvas.Font.Size := FInfoText.FontSize;
    Canvas.Font.Color := FInfoText.FontColor;
    Canvas.Font.Style := FInfoText.FontStyle;
    Canvas.TextOut(FInfoText.X, FInfoText.Y, FInfoText.Text);
  end;
end;

procedure TVlcPlayer.SetDisplayText(const Info: string);
begin
  FInfoText.Text := Info;
  Invalidate;
end;

procedure TVlcPlayer.UpdateInfo(const Text: string);
begin
  FInfoText.Text := Text;
  Invalidate;
end;

procedure TVlcPlayer.SetTextPositionXY(X, Y: Integer);
begin
  FInfoText.X := X;
  FInfoText.Y := Y;
  Invalidate;
end;

procedure TVlcPlayer.SetTextFont(Size: Integer; Color: TColor; Style: TFontStyles);
begin
  FInfoText.FontSize := Size;
  FInfoText.FontColor := Color;
  FInfoText.FontStyle := Style;
  Invalidate;
end;

procedure TVlcPlayer.ShowAll;
begin
  FInfoText.Visible := True;
  FShowTopImage := True;
  Invalidate;
end;

procedure TVlcPlayer.HideAll;
begin
  FInfoText.Visible := False;
  FShowTopImage := False;
  Invalidate;
end;

procedure TVlcPlayer.SetMediaURL(const Value: string);
begin
  if FMediaURL <> Value then
  begin
    FMediaURL := Value;
    if Value <> '' then
      LoadMedia(Value);
  end;
end;

procedure TVlcPlayer.SetVolume(Value: Integer);
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

procedure TVlcPlayer.SetUserAgent(const Value: string);
begin
  if FUserAgent <> Value then
  begin
    FUserAgent := Value;
    Log('User-Agent установлен: ' + Value);
  end;
end;

procedure TVlcPlayer.SetReferer(const Value: string);
begin
  if FReferer <> Value then
  begin
    FReferer := Value;
    Log('Referer установлен: ' + Value);
  end;
end;

procedure TVlcPlayer.SetHttpHeaders(const Value: TStringList);
begin
  FHttpHeaders.Assign(Value);
end;

procedure TVlcPlayer.SetQualityMode(const Value: TVlcQualityMode);
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

procedure TVlcPlayer.SetForcedBitrate(const Value: Integer);
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

procedure TVlcPlayer.SetForcedResolution(const Value: string);
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

function TVlcPlayer.GetMuted: Boolean;
begin
  Result := FMuted;
end;

procedure TVlcPlayer.SetMuted(const Value: Boolean);
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

function TVlcPlayer.GetCurrentMediaURL: string;
var
  Media: Plibvlc_media_t;
  MRL: PAnsiChar;
begin
  Result := FMediaURL; // Возвращаем сохраненный URL по умолчанию

  if not IsInitialized or (FPlayer = nil) then
    Exit;

  try
    if Assigned(T_libvlc_media_player_get_media) and
       Assigned(T_libvlc_media_get_mrl) then
    begin
      Media := T_libvlc_media_player_get_media(FPlayer);
      if Media <> nil then
      begin
        MRL := T_libvlc_media_get_mrl(Media);
        if MRL <> nil then
        begin
          Result := UTF8ToString(MRL);
        end;
      end;
    end;
  except
    on E: Exception do
    begin
      // В случае ошибки возвращаем сохраненный URL
      Result := FMediaURL;
    end;
  end;
end;

procedure TVlcPlayer.InitVLC;
var
  VlcOptions: TStringList;
  VlcArgs: array of PAnsiChar;
  I: Integer;
  LibName: string;
  OldDir: string;
begin
  if FInstance <> nil then Exit;

  if FLibPath = '' then
    LibName := 'libvlc.dll'
  else
    LibName := FLibPath;

  // Сохраняем текущую директорию
  OldDir := GetCurrentDir;
  try
    // Устанавливаем директорию с библиотекой VLC
    if ExtractFilePath(LibName) <> '' then
    begin
     SetDllDirectory(PChar(FLibPath));
     FLibHandle := LoadLibrary('libvlc.dll');
     SetDllDirectory(nil);
    end;

    // Загружаем библиотеку
    FLibHandle := LoadLibrary(PChar(ExtractFileName(LibName)));

    if FLibHandle = 0 then
    begin
      // Пробуем загрузить из системных путей
      FLibHandle := LoadLibrary('libvlc.dll');
      if FLibHandle = 0 then
      begin
        Log('Ошибка загрузки библиотеки VLC: ' + LibName + '. Ошибка: ' + GetLastErrorText);
        Exit;
      end;
    end;

  finally
    // Восстанавливаем исходную директорию
    SetCurrentDir(OldDir);
  end;

  LoadFunctions;

  // Строим опции VLC
  VlcOptions := BuildVlcOptions;

  // Подготавливаем аргументы
  SetLength(VlcArgs, VlcOptions.Count);
  for I := 0 to VlcOptions.Count - 1 do
    VlcArgs[I] := PAnsiChar(AnsiString(VlcOptions[I]));

  // Создаем экземпляр VLC
  FInstance := T_libvlc_new(Length(VlcArgs), @VlcArgs[0]);

  if FInstance = nil then
  begin
    Log('Ошибка создания экземпляра VLC');
    FreeLibrary(FLibHandle);
    FLibHandle := 0;
  end
  else
  begin
    Log('VLC инициализирован успешно');
  end;

  VlcOptions.Free;
end;

procedure TVlcPlayer.LoadFunctions;
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

  // Загружаем новые функции VLC
  @T_libvlc_media_player_get_buffer := GetProcAddress(FLibHandle, 'libvlc_media_player_get_buffer');
  @T_libvlc_media_player_get_media := GetProcAddress(FLibHandle, 'libvlc_media_player_get_media');
  @T_libvlc_media_get_mrl := GetProcAddress(FLibHandle, 'libvlc_media_get_mrl');

  if not Assigned(T_libvlc_new) or not Assigned(T_libvlc_media_new_location) then
    raise Exception.Create('Не удалось загрузить основные функции VLC');
end;

procedure TVlcPlayer.FreeVLC;
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

procedure TVlcPlayer.SetState(Value: TVlcState);
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

function TVlcPlayer.GetLastErrorText: string;
var
  ErrorCode: Integer;
begin
  ErrorCode := GetLastError;
  if ErrorCode <> 0 then
    Result := SysErrorMessage(ErrorCode)
  else
    Result := 'Неизвестная ошибка';
end;

procedure TVlcPlayer.Log(const Msg: string);
begin
  if Assigned(FOnLog) then
    FOnLog(Self, Msg);
end;

function TVlcPlayer.BuildVlcOptions: TStringList;
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

function TVlcPlayer.IsProtectedStream(const AUrl: string): Boolean;
begin
  Result := (Pos('wink.', AUrl) > 0) or
            (Pos('protected.', AUrl) > 0) or
            (Pos('secure.', AUrl) > 0) or
            (Pos('premium.', AUrl) > 0);
end;

function TVlcPlayer.TestStreamProtection(const AUrl: string): Boolean;
begin
  Result := IsProtectedStream(AUrl);
end;

procedure TVlcPlayer.ApplyAppropriateHeaders(const AUrl: string);
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

procedure TVlcPlayer.StopCurrentStream;
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

procedure TVlcPlayer.SetupEventHandlers;
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

procedure TVlcPlayer.ApplyQualitySettings;
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

function TVlcPlayer.GetQualityOptions: TStringList;
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

procedure TVlcPlayer.SendLoadingEvent(const AEvent: string; AProgress: Integer = -1);
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

procedure TVlcPlayer.SendStateEvent(const AState: string);
begin
  SendLoadingEvent('STATE_' + AState);
end;

function TVlcPlayer.GetBufferingLevel: Integer;
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

function TVlcPlayer.IsNetworkStream: Boolean;
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

function TVlcPlayer.GetActualLoadingProgress: Integer;
var
  BufferLevel: Single;
begin
  Result := -1;

  if not IsInitialized or (FPlayer = nil) then
    Exit;

  try
    if Assigned(T_libvlc_media_player_get_buffer) then
    begin
      BufferLevel := T_libvlc_media_player_get_buffer(FPlayer);

      // VLC возвращает значение от 0.0 до 1.0
      if (BufferLevel >= 0) and (BufferLevel <= 1.0) then
      begin
        Result := Round(BufferLevel * 100);
        Log('Уровень буферизации: ' + IntToStr(Result) + '%');
      end
      else
      begin
        Log('Буферизация недоступна: ' + FloatToStr(BufferLevel));
      end;
    end
    else
    begin
      Log('Функция libvlc_media_player_get_buffer не доступна');
    end;

  except
    on E: Exception do
    begin
      Log('Ошибка получения буферизации: ' + E.Message);
      Result := -1;
    end;
  end;
end;

procedure TVlcPlayer.UpdateRealLoadingProgress;
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

        SendLoadingEvent('LOADING_PROGRESS', FLoadingProgress);
      end;
    end
    else
    begin
      FIsLoading := False;
      SetState(vlcError);
      SendLoadingEvent('LOADING_ERROR');
      Log('Таймаут загрузки - превышено время ожидания');
    end;
  end;

  if (FLoadingProgress >= 95) and (FState = vlcPlaying) then
  begin
    FIsLoading := False;
    FLoadingProgress := 100;
    SendLoadingEvent('LOADING_COMPLETE');
    Log('Загрузка завершена');
  end;
end;

procedure TVlcPlayer.ProgressTimerTick(Sender: TObject);
begin
  if FIsLoading then
    UpdateRealLoadingProgress;
end;

function TVlcPlayer.IsInitialized: Boolean;
begin
  Result := (FInstance <> nil) and (FLibHandle <> 0);
end;

function TVlcPlayer.IsPlaying: Boolean;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_is_playing) then
    Result := (T_libvlc_media_player_is_playing(FPlayer) <> 0)
  else
    Result := FState = vlcPlaying;
end;

function TVlcPlayer.IsActuallyPlaying: Boolean;
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

function TVlcPlayer.GetDuration: Int64;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_get_length) then
    Result := T_libvlc_media_player_get_length(FPlayer)
  else
    Result := 0;
end;

function TVlcPlayer.GetPosition: Int64;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_get_time) then
    Result := T_libvlc_media_player_get_time(FPlayer)
  else
    Result := 0;
end;

function TVlcPlayer.GetPlaybackPosition: Single;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_get_position) then
    Result := T_libvlc_media_player_get_position(FPlayer)
  else
    Result := 0;
end;

function TVlcPlayer.GetPlayerStatus: string;
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

procedure TVlcPlayer.ForceBestQuality;
begin
  QualityMode := qmBest;
end;

procedure TVlcPlayer.ForceWorstQuality;
begin
  QualityMode := qmWorst;
end;

procedure TVlcPlayer.ForceAutoQuality;
begin
  QualityMode := qmAuto;
end;

procedure TVlcPlayer.ForceCustomQuality(Bitrate: Integer; const Resolution: string);
begin
  FForcedBitrate := Bitrate;
  FForcedResolution := Resolution;
  QualityMode := qmCustom;
end;

procedure TVlcPlayer.AddHttpHeader(const AName, AValue: string);
begin
  FHttpHeaders.Values[AName] := AValue;
end;

procedure TVlcPlayer.ClearHttpHeaders;
begin
  FHttpHeaders.Clear;
end;

procedure TVlcPlayer.SetWinkHeaders;
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

procedure TVlcPlayer.SetBasicHeaders;
begin
  FUserAgent := 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
  FReferer := '';
  ClearHttpHeaders;
  AddHttpHeader('Accept', '*/*');
  AddHttpHeader('Accept-Language', 'en-US,en;q=0.9');
  AddHttpHeader('Accept-Encoding', 'gzip, deflate, br');
end;

procedure TVlcPlayer.Mute;
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

procedure TVlcPlayer.Unmute;
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

procedure TVlcPlayer.ToggleMute;
begin
  if IsMuted then
    Unmute
  else
    Mute;
end;

function TVlcPlayer.IsMuted: Boolean;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_audio_get_mute) then
  begin
    FMuted := T_libvlc_audio_get_mute(FPlayer) <> 0;
    Result := FMuted;
  end
  else
    Result := FMuted;
end;

procedure TVlcPlayer.Play;
var
  ResultCode: Integer;
begin
  if not IsInitialized then
    InitVLC;

  if FPlayer = nil then
  begin
    Log('Ошибка: Плеер не инициализирован');
    Exit;
  end;

  Log('Запуск воспроизведения...');

  // Убедимся, что видео выводится на правильный handle
  if FVideoHandle <> 0 then
  begin
    Log('Проверка вывода видео: handle ' + IntToStr(FVideoHandle));
    T_libvlc_media_player_set_hwnd(FPlayer, Pointer(FVideoHandle));

    // Даем время на установку
    Sleep(50);
  end;

  SendLoadingEvent('PLAYBACK_STARTING');

  ResultCode := T_libvlc_media_player_play(FPlayer);

  if ResultCode = 0 then
  begin
    Log('Команда воспроизведения отправлена');

    // Дополнительная проверка через небольшую задержку
    if FVideoHandle <> 0 then
    begin
      // Используем PostMessage для отложенного вызова
      PostMessage(Handle, WM_USER + 1, 0, 0);
    end;
  end
  else
  begin
    SetState(vlcError);
    FIsLoading := False;
    FLoadingProgress := 0;
    SendLoadingEvent('PLAYBACK_ERROR');
    Log('Ошибка воспроизведения, код: ' + IntToStr(ResultCode));
    if Assigned(FOnError) then
      FOnError(Self);
  end;
end;

procedure TVlcPlayer.Pause;
begin
  if FPlayer = nil then Exit;

  T_libvlc_media_player_pause(FPlayer);
  Log('Команда паузы отправлена');
  SendLoadingEvent('PLAYBACK_PAUSED');
end;

procedure TVlcPlayer.Stop;
begin
  if FPlayer = nil then Exit;

  Log('Остановка воспроизведения...');

  FProgressTimer.Enabled := False;
  T_libvlc_media_player_stop(FPlayer);

  SetState(vlcStopped);
  FIsLoading := False;
  FLoadingProgress := 0;

  SendLoadingEvent('PLAYBACK_STOPPED');
  Log('Воспроизведение остановлено');
end;

procedure TVlcPlayer.LoadMedia(const APath: string);
var
  MediaType: string;
  Options: TStringList;
  I: Integer;
begin
  Log('=== ЗАГРУЗКА МЕДИА ===');
  Log('URL: ' + APath);

  if not IsInitialized then
    InitVLC;

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

  try
    // Создаем или обновляем видео панель
    UpdateVideoHandle;

    if FVideoHandle = 0 then
    begin
      Log('Критическая ошибка: Не удалось создать видео окно');
      raise Exception.Create('Не удалось инициализировать видео окно');
    end;

    // Освобождаем предыдущие ресурсы
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

    // Создаем медиа объект
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

    // КРИТИЧЕСКИ ВАЖНО: Устанавливаем handle ДО setup event handlers
    Log('Устанавливаем вывод видео на handle: ' + IntToStr(FVideoHandle));
    T_libvlc_media_player_set_hwnd(FPlayer, Pointer(FVideoHandle));

    // Даем время на инициализацию
    Sleep(100);

    SetupEventHandlers;

    // Убедимся, что компонент видим
    if not Visible then
      Show;

    if FVideoPanel <> nil then
      FVideoPanel.Show;

    Update;

    if Assigned(T_libvlc_audio_set_volume) then
      T_libvlc_audio_set_volume(FPlayer, FVolume);

    if Assigned(T_libvlc_audio_set_mute) then
      T_libvlc_audio_set_mute(FPlayer, Integer(FMuted));

    Log('Медиа успешно загружено, видео будет выводиться на компонент');

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
      SendLoadingEvent('LOADING_ERROR', 0);
      Log('Ошибка загрузки медиа: ' + E.Message);
      if Assigned(FOnError) then
        FOnError(Self);
    end;
  end;
end;

end.
