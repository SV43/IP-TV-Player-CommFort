unit VlcVisualComponent;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  System.Types, System.Math, System.Generics.Collections, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls,
  System.SyncObjs, System.DateUtils, System.IOUtils, Vcl.Imaging.pngimage,
  Vcl.Imaging.jpeg;

type
  Plibvlc_instance_t = Pointer;
  Plibvlc_media_t = Pointer;
  Plibvlc_media_player_t = Pointer;
  Plibvlc_event_manager_t = Pointer;

  TVlcState = (vlcIdle, vlcLoading, vlcPlaying, vlcPaused, vlcStopped, vlcError, vlcBuffering);

  // Callback types for memory rendering
  TLockCallback = function(opaque: Pointer; planes: PPointer): Pointer; cdecl;
  TUnlockCallback = procedure(opaque: Pointer; picture: Pointer; planes: PPointer); cdecl;
  TDisplayCallback = procedure(opaque: Pointer; picture: Pointer); cdecl;

  TVlcNotifyEvent = procedure(Sender: TObject) of object;
  TVlcLogEvent = procedure(Sender: TObject; const Msg: string) of object;
  TVlcProgressEvent = procedure(Sender: TObject; Progress: Integer) of object;
  TVlcPositionEvent = procedure(Sender: TObject; Position: Single) of object;
  TVlcTimeEvent = procedure(Sender: TObject; Time: Int64) of object;
  TVlcFrameEvent = procedure(Sender: TObject; Bitmap: TBitmap) of object;
  TVlcMouseEvent = procedure(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer) of object;
  TVlcMouseMoveEvent = procedure(Sender: TObject; Shift: TShiftState; X, Y: Integer) of object;
  TVlcMouseWheelEvent = procedure(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint) of object;

  TVlcVisualComponent = class(TCustomControl)
  private
    FLibPath: string;
    FLibHandle: HMODULE;

    FStatusBarVisible: Boolean;
    FStatusBarText: string;
    FStatusBarFontSize: Integer;
    FStatusBarBackground: TColor;
    FStatusBarTextColor: TColor;
    FStatusBarCornerRadius: Integer;

    // поля для верхнего изображения
    FShowTopImage: Boolean;
    FTopImagePath: string;
    FTopImage: TBitmap;
    FTopImageRect: TRect;
    FTopImageCornerRadius: Integer;
    FTopImageOpacity: Byte;

    // Monitoring variables
    FHealthTimer: TTimer;
    FLastFrameUpdateTime: Cardinal;
    FLastMemoryCheck: Cardinal;
    FAdjustedCache: Boolean;
    FStreamStartTime: TDateTime;
    FAutoRestartEnabled: Boolean;
    FAutoRestartInterval: Integer;

    // Loading animation
    FShowLoading: Boolean;
    FFirstFrameTime: Cardinal;
    FAnimationHideDelay: Integer;
    FAnimationTimer: TTimer;
    FAnimationAngle: Single;

    // Audio management
    FAudioEnabled: Boolean;
    FVideoStarted: Boolean;

    // Synchronization
    FAudioSyncEnabled: Boolean;
    FLastAudioTime: Int64;
    FAudioDelay: Integer;
    FSyncTimer: TTimer;
    FFallbackTimer: TTimer;

    FLastVideoWidth: Integer;
    FLastVideoHeight: Integer;

    FVideoChroma: string;
    FHighQuality: Boolean;

    FState: TVlcState;
    FVolume: Integer;
    FAutoPlay: Boolean;
    FUserAgent: string;
    FReferer: string;
    FHttpHeaders: TStringList;
    FIsLoading: Boolean;
    FLoadingStage: string;
    FMuted: Boolean;
    FLoopPlayback: Boolean;

    // Memory rendering variables
    FVideoWidth: Integer;
    FVideoHeight: Integer;
    FVideoPitch: Integer;
    FVideoBuffer: array[0..1] of Pointer;
    FCurrentBuffer: Integer;
    FBackBuffer: Pointer;
    FVideoBufferSize: Integer;
    FCurrentBitmap: TBitmap;
    FFrameReady: Boolean;
    FBufferLock: TCriticalSection;
    FFrameTimer: TTimer;
    FBufferValid: Boolean;

    // FPS adaptation
    FLastFrameTime: Cardinal;
    FFrameCount: Integer;
    FLastFpsTime: Cardinal;
    FCurrentFPS: Integer;
    FTargetFPS: Integer;

    // Event fields
    FOnVideoMouseDown: TVlcMouseEvent;
    FOnVideoMouseUp: TVlcMouseEvent;
    FOnVideoMouseMove: TVlcMouseMoveEvent;
    FOnVideoClick: TVlcNotifyEvent;
    FOnVideoDblClick: TVlcNotifyEvent;
    FOnVideoMouseWheel: TVlcMouseWheelEvent;

    FInstance: Plibvlc_instance_t;
    FMedia: Plibvlc_media_t;
    FPlayer: Plibvlc_media_player_t;
    FEventManager: Plibvlc_event_manager_t;

    // VLC function pointers
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
    T_libvlc_audio_set_volume: procedure(p_player: Plibvlc_media_player_t; volume: Integer); cdecl;
    T_libvlc_media_add_option: procedure(p_media: Plibvlc_media_t; psz_options: PAnsiChar); cdecl;
    T_libvlc_media_player_get_length: function(p_player: Plibvlc_media_player_t): Int64; cdecl;
    T_libvlc_media_player_get_time: function(p_player: Plibvlc_media_player_t): Int64; cdecl;
    T_libvlc_media_player_set_time: procedure(p_player: Plibvlc_media_player_t; time: Int64); cdecl;
    T_libvlc_media_player_get_position: function(p_player: Plibvlc_media_player_t): Single; cdecl;
    T_libvlc_media_player_set_position: procedure(p_player: Plibvlc_media_player_t; position: Single); cdecl;
    T_libvlc_event_attach: procedure(p_event_manager: Plibvlc_event_manager_t; event_type: Integer; callback: Pointer; user_data: Pointer); cdecl;
    T_libvlc_media_player_event_manager: function(p_player: Plibvlc_media_player_t): Plibvlc_event_manager_t; cdecl;
    T_libvlc_audio_set_mute: procedure(p_player: Plibvlc_media_player_t; status: Integer); cdecl;
    T_libvlc_audio_get_mute: function(p_player: Plibvlc_media_player_t): Integer; cdecl;
    T_libvlc_media_player_is_playing: function(p_player: Plibvlc_media_player_t): Integer; cdecl;
    T_libvlc_video_set_callbacks: procedure(p_player: Plibvlc_media_player_t; lock: TLockCallback;
      unlock: TUnlockCallback; display: TDisplayCallback; opaque: Pointer); cdecl;
    T_libvlc_video_set_format: procedure(p_player: Plibvlc_media_player_t; chroma: PAnsiChar;
      width, height: Cardinal; pitch: Cardinal); cdecl;
    T_libvlc_video_get_width: function(p_player: Plibvlc_media_player_t): Integer; cdecl;
    T_libvlc_video_get_height: function(p_player: Plibvlc_media_player_t): Integer; cdecl;
    T_libvlc_video_set_adjust_int: procedure(p_player: Plibvlc_media_player_t; option: Integer; value: Integer); cdecl;
    T_libvlc_video_set_adjust_float: procedure(p_player: Plibvlc_media_player_t; option: Integer; value: Single); cdecl;

    FPositionTimer: TTimer;
    FShutdownMode: Boolean;

    FOnPlaying: TVlcNotifyEvent;
    FOnPaused: TVlcNotifyEvent;
    FOnStopped: TVlcNotifyEvent;
    FOnEndReached: TVlcNotifyEvent;
    FOnError: TVlcNotifyEvent;
    FOnLoading: TVlcNotifyEvent;
    FOnLog: TVlcLogEvent;
    FOnLoadingProgress: TVlcProgressEvent;
    FOnBuffering: TVlcProgressEvent;
    FOnPositionChanged: TVlcPositionEvent;
    FOnTimeChanged: TVlcTimeEvent;
    FOnVideoStarted: TVlcNotifyEvent;
    FOnVideoSizeChanged: TVlcNotifyEvent;
    FOnFrameReady: TVlcFrameEvent;

    FCursorHideTimer: TTimer;
    FCursorHidden: Boolean;
    FLastMouseMoveTime: Cardinal;

    FShowCurrentTime: Boolean;
    FTimeDisplayTimer: TTimer;

    FTimeAutoHide: Boolean;
    FTimeVisible: Boolean;
    FLastActivityTime: Cardinal;
    FTimeAutoHideTimer: TTimer;
    FTimeAutoHideDelay: Integer;

    // Методы для работы с изображением
    procedure SetShowTopImage(const Value: Boolean);
    procedure SetTopImagePath(const Value: string);
    procedure SetTopImageCornerRadius(const Value: Integer);
    procedure SetTopImage(const ImagePath: string; Show: Boolean = True);
    procedure LoadTopImage;
    procedure DrawTopImage(Canvas: TCanvas);
    procedure ClearTopImage;
    procedure SetTopImageOpacity(const Value: Byte);
    function IsTopImageLoaded: Boolean;


    procedure SetMediaURL(const Value: string);
    procedure SetVolume(Value: Integer);
    procedure SetUserAgent(const Value: string);
    procedure SetReferer(const Value: string);
    procedure SetHttpHeaders(const Value: TStringList);
    function GetMuted: Boolean;
    procedure SetMuted(const Value: Boolean);
    procedure SetLoopPlayback(const Value: Boolean);
    procedure SetHighQuality(const Value: Boolean);
    procedure FallbackTimerTick(Sender: TObject);
    procedure SyncTimerTick(Sender: TObject);
    procedure EnableAudio;

    // Stability methods
    procedure StartStreamHealthMonitor;
    procedure HealthCheckTimerTick(Sender: TObject);
    procedure CheckMemoryUsage;
    procedure AdjustPerformanceSettings;
    procedure AutoRestartCheck;
    procedure EnhancedFreeVideoBuffer;
    procedure ResetStreamState;
    procedure TryAlternativeFormats;

    // Memory rendering callbacks
    function LockCallback(opaque: Pointer; planes: PPointer): Pointer; cdecl;
    procedure UnlockCallback(opaque: Pointer; picture: Pointer; planes: PPointer); cdecl;
    procedure UpdateLoadingStage(const Stage: string);
    procedure FrameTimerTick(Sender: TObject);
    procedure UpdateBitmapFromBuffer;
    procedure AllocateVideoBuffer(AWidth, AHeight: Integer);
    procedure SafeInvalidate;
    procedure SwapBuffers;
    procedure CalculateFPS;
    procedure ClearVideoBuffer;
    function CalculateAspectRatioFit: TRect;
    procedure AnimationTimerTick(Sender: TObject);
    procedure PositionTimerTick(Sender: TObject);
    procedure InitVLC;
    procedure LoadFunctions;
    procedure SetState(Value: TVlcState);
    function BuildVlcOptions: TStringList;
    procedure SetupEventHandlers;
    procedure SetupMemoryRendering;
    function IsNetworkStream(const AUrl: string): Boolean;
    procedure ForceVideoUpdate;
    procedure DrawLoadingAnimation(Canvas: TCanvas);
    procedure HandleLoadMediaError(const ErrorMsg: string);
    procedure DrawDebugInfo(Canvas: TCanvas);
    procedure StopAllTimers;
    procedure StopVLCPlayback;
    procedure FreeVLCResources;
    procedure SetupCursorHideTimer;
    procedure CursorHideTimerTick(Sender: TObject);
    procedure HideCursor;
    procedure ShowCursor;
    procedure ResetCursorTimer;
    procedure SetupTimeDisplayTimer;
    procedure TimeDisplayTimerTick(Sender: TObject);
    procedure DrawCurrentTime(Canvas: TCanvas);
    procedure SetupTimeAutoHideTimer;
    procedure TimeAutoHideTimerTick(Sender: TObject);
    procedure ResetTimeAutoHideTimer;
    procedure ShowTimeTemporarily;
    procedure SetStatusBarVisible(const Value: Boolean);
    procedure SetStatusBarText(const Value: string);
    procedure SetStatusBarFontSize(const Value: Integer);
    procedure SetStatusBarBackground(const Value: TColor);
    procedure SetStatusBarTextColor(const Value: TColor);
    procedure SetStatusBarCornerRadius(const Value: Integer);
    procedure ForceVideoRecovery;
    procedure EmergencyMemoryOptimization;
    procedure ApplyVideoQualitySettings;
    procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);

  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure DblClick; override;
    procedure DrawStatusBar(Canvas: TCanvas);

  public
    FMediaURL: string;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure ForceRedrawTopImage;

    procedure EnableAudioSync(Enabled: Boolean);
    procedure SetAudioDelay(DelayMs: Integer);
    procedure SetTargetFPS(FPS: Integer);
    function GetCurrentFPS: Integer;
    procedure EnableHighPerformanceMode(Enabled: Boolean);
    procedure EnableAutoRestart(Enabled: Boolean; IntervalMinutes: Integer = 60);
    procedure ForceSoftRestart;
    procedure ResetPerformanceSettings;
    procedure ShowLoadingAnimationProc;
    procedure HideLoadingAnimationProc;
    procedure Play;
    procedure Pause;
    procedure Stop;
    procedure LoadMedia(const AUrl: string);
    procedure SeekToPosition(APosition: Single);
    procedure SeekToTime(ATime: Int64);
    function IsInitialized: Boolean;
    function IsPlaying: Boolean;
    function IsPaused: Boolean;
    function IsSeekable: Boolean;
    function CanPause: Boolean;
    function GetDuration: Int64;
    function GetPosition: Int64;
    function GetPlaybackPosition: Single;
    function GetVideoWidth: Integer;
    function GetVideoHeight: Integer;
    function HasVideo: Boolean;
    function GetPlayerStatus: string;
    procedure AddHttpHeader(const AName, AValue: string);
    procedure ClearHttpHeaders;
    procedure SetWinkHeaders;
    procedure SetBasicHeaders;
    procedure Mute;
    procedure Unmute;
    procedure ToggleMute;
    function IsMuted: Boolean;
    procedure ClearBuffer;
    procedure ShowTimeDisplay;
    procedure HideTimeDisplay;
    procedure ToggleTimeDisplay;
    procedure SetTimeAutoHide(Enabled: Boolean; HideDelay: Integer = 3000);
    procedure ShowStatusBar(const AText: string = '');
    procedure HideStatusBar;
    procedure UpdateStatusBar(const AText: string);
    procedure SetStatusBarStyle(FontSize: Integer; BackgroundColor, TextColor: TColor; CornerRadius: Integer = 8);
    procedure SetVideoQuality(Quality: Integer); // 0-100

    property CurrentBitmap: TBitmap read FCurrentBitmap;
    function GetTopImageInfo: string;
    procedure LoadTopImageFromResource(const ResName: string);

  published
    property LibPath: string read FLibPath write FLibPath;
    property MediaURL: string read FMediaURL write SetMediaURL;
    property AutoPlay: Boolean read FAutoPlay write FAutoPlay;
    property Volume: Integer read FVolume write SetVolume;
    property UserAgent: string read FUserAgent write SetUserAgent;
    property Referer: string read FReferer write SetReferer;
    property HttpHeaders: TStringList read FHttpHeaders write SetHttpHeaders;
    property State: TVlcState read FState;
    property Muted: Boolean read GetMuted write SetMuted;
    property LoopPlayback: Boolean read FLoopPlayback write SetLoopPlayback;
    property HighQuality: Boolean read FHighQuality write SetHighQuality default True;
    property AudioSyncEnabled: Boolean read FAudioSyncEnabled write EnableAudioSync default True;
    property AudioDelay: Integer read FAudioDelay write SetAudioDelay default 0;
    property AutoRestartEnabled: Boolean read FAutoRestartEnabled write FAutoRestartEnabled default False;
    property AutoRestartInterval: Integer read FAutoRestartInterval write FAutoRestartInterval default 60;
    property ShowCurrentTime: Boolean read FShowCurrentTime write FShowCurrentTime default True;
    property StatusBarVisible: Boolean read FStatusBarVisible write SetStatusBarVisible;
    property StatusBarText: string read FStatusBarText write SetStatusBarText;
    property StatusBarFontSize: Integer read FStatusBarFontSize write SetStatusBarFontSize;
    property StatusBarBackground: TColor read FStatusBarBackground write SetStatusBarBackground;
    property StatusBarTextColor: TColor read FStatusBarTextColor write SetStatusBarTextColor;
    property StatusBarCornerRadius: Integer read FStatusBarCornerRadius write SetStatusBarCornerRadius;

    // Cвойства для изображения
    property ShowTopImage: Boolean read FShowTopImage write SetShowTopImage;
    property TopImagePath: string read FTopImagePath write SetTopImagePath;
    property TopImageCornerRadius: Integer read FTopImageCornerRadius write SetTopImageCornerRadius;
    property TopImageOpacity: Byte read FTopImageOpacity write SetTopImageOpacity;


    // VCL properties
    property Align;
    property Anchors;
    property AutoSize;
    property BiDiMode;
    property Caption;
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
    property Font;
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
    property Visible;
    property OnAlignInsertBefore;
    property OnAlignPosition;
    property OnCanResize;
    property OnClick;
    property OnConstrainedResize;
    property OnContextPopup;
    property OnDblClick;
    property OnDockDrop;
    property OnDockOver;
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

    // VLC events
    property OnLoading: TVlcNotifyEvent read FOnLoading write FOnLoading;
    property OnPlaying: TVlcNotifyEvent read FOnPlaying write FOnPlaying;
    property OnPaused: TVlcNotifyEvent read FOnPaused write FOnPaused;
    property OnStopped: TVlcNotifyEvent read FOnStopped write FOnStopped;
    property OnEndReached: TVlcNotifyEvent read FOnEndReached write FOnEndReached;
    property OnError: TVlcNotifyEvent read FOnError write FOnError;
    property OnLog: TVlcLogEvent read FOnLog write FOnLog;
    property OnLoadingProgress: TVlcProgressEvent read FOnLoadingProgress write FOnLoadingProgress;
    property OnBuffering: TVlcProgressEvent read FOnBuffering write FOnBuffering;
    property OnPositionChanged: TVlcPositionEvent read FOnPositionChanged write FOnPositionChanged;
    property OnTimeChanged: TVlcTimeEvent read FOnTimeChanged write FOnTimeChanged;
    property OnVideoStarted: TVlcNotifyEvent read FOnVideoStarted write FOnVideoStarted;
    property OnVideoSizeChanged: TVlcNotifyEvent read FOnVideoSizeChanged write FOnVideoSizeChanged;
    property OnFrameReady: TVlcFrameEvent read FOnFrameReady write FOnFrameReady;
    property OnVideoMouseDown: TVlcMouseEvent read FOnVideoMouseDown write FOnVideoMouseDown;
    property OnVideoMouseUp: TVlcMouseEvent read FOnVideoMouseUp write FOnVideoMouseUp;
    property OnVideoMouseMove: TVlcMouseMoveEvent read FOnVideoMouseMove write FOnVideoMouseMove;
    property OnVideoClick: TVlcNotifyEvent read FOnVideoClick write FOnVideoClick;
    property OnVideoDblClick: TVlcNotifyEvent read FOnVideoDblClick write FOnVideoDblClick;
    property OnVideoMouseWheel: TVlcMouseWheelEvent read FOnVideoMouseWheel write FOnVideoMouseWheel;
  end;

procedure Register;

implementation

const
  libvlc_MediaPlayerPlaying = 0;
  libvlc_MediaPlayerPaused = 1;
  libvlc_MediaPlayerStopped = 2;
  libvlc_MediaPlayerEndReached = 3;
  libvlc_MediaPlayerEncounteredError = 4;
  libvlc_MediaPlayerTimeChanged = 5;
  libvlc_MediaPlayerPositionChanged = 6;
  libvlc_MediaPlayerBuffering = 27;
  libvlc_MediaPlayerOpening = 28;

  // Video adjustment options
  libvlc_adjust_Enable = 0;
  libvlc_adjust_Contrast = 1;
  libvlc_adjust_Brightness = 2;
  libvlc_adjust_Hue = 3;
  libvlc_adjust_Saturation = 4;
  libvlc_adjust_Gamma = 5;

var
  GDestroyedPlayers: TList<Pointer>;

// VLC Event Callback
procedure VlcEventCallback(p_event: Pointer; user_data: Pointer); cdecl; forward;
function VlcLockCallback(opaque: Pointer; planes: PPointer): Pointer; cdecl; forward;
procedure VlcUnlockCallback(opaque: Pointer; picture: Pointer; planes: PPointer); cdecl; forward;
procedure VlcDisplayCallback(opaque: Pointer; picture: Pointer); cdecl; forward;

{ TVlcVisualComponent }

constructor TVlcVisualComponent.Create(AOwner: TComponent);
var
  I: Integer;
begin
  inherited Create(AOwner);

  // Remove from destroyed list
  if GDestroyedPlayers <> nil then
    GDestroyedPlayers.Remove(Self);

  // Initialize state flags
  FFirstFrameTime := 0;
  FAnimationHideDelay := 1000;
  FAudioEnabled := False;
  FVideoStarted := False;
  FFrameReady := False;
  FBufferValid := False;
  FShowLoading := False;
  FIsLoading := False;
  FMuted := False;
  FLoopPlayback := False;
  FAutoPlay := True;
  FAudioSyncEnabled := True;
  FShutdownMode := False;
  FAnimationAngle := 0;

  // Status bar initialization - НИЖНИЙ статус
  FStatusBarVisible := False;
  FStatusBarText := '';
  FStatusBarFontSize := 10;  // Уменьшили в 2 раза (было 16)
  // Полностью прозрачный фон и серый текст для статуса внизу
  FStatusBarBackground := $00000000;  // Полностью прозрачный
  FStatusBarTextColor := $888888;     // Серый цвет (не жирный)
  FStatusBarCornerRadius := 8;        // Уменьшили радиус

  // Cursor hide initialization
  FCursorHidden := False;
  FLastMouseMoveTime := 0;

  // Time display initialization
  FShowCurrentTime := True;
  FTimeVisible := True;
  FTimeAutoHide := False;
  FTimeAutoHideDelay := 3000;
  FLastActivityTime := GetTickCount;

  // Stability variables
  FAdjustedCache := False;
  FAutoRestartEnabled := False;
  FAutoRestartInterval := 60;
  FLastFrameUpdateTime := 0;
  FLastMemoryCheck := 0;
  FStreamStartTime := 0;

  // VCL Control settings
  Width := 640;
  Height := 360;
  ParentBackground := False;
  Color := clBlack;
  DoubleBuffered := True;

  // Video variables
  FVideoWidth := 0;
  FVideoHeight := 0;
  FVideoPitch := 0;
  FVideoBufferSize := 0;
  FVideoChroma := '';
  FVolume := 100;
  FLastAudioTime := 0;
  FAudioDelay := 0;
  FLastVideoWidth := 0;
  FLastVideoHeight := 0;
  FHighQuality := True;

  // Double buffering
  for I := 0 to 1 do
    FVideoBuffer[I] := nil;
  FBackBuffer := nil;
  FCurrentBuffer := 0;

  // FPS system
  FLastFrameTime := 0;
  FFrameCount := 0;
  FLastFpsTime := 0;
  FCurrentFPS := 0;
  FTargetFPS := 30;

  // Create critical section
  FBufferLock := TCriticalSection.Create;

  // Create bitmap for video display
  FCurrentBitmap := TBitmap.Create;
  FCurrentBitmap.PixelFormat := pf32bit;
  FCurrentBitmap.HandleType := bmDIB;
  FCurrentBitmap.IgnorePalette := True;

  // Create frame timer
  FFrameTimer := TTimer.Create(Self);
  FFrameTimer.Interval := 33; // ~30 FPS
  FFrameTimer.OnTimer := FrameTimerTick;
  FFrameTimer.Enabled := False;

  // Create loading animation timer
  FAnimationTimer := TTimer.Create(Self);
  FAnimationTimer.Interval := 16; // Быстрая анимация (~60 FPS)
  FAnimationTimer.OnTimer := AnimationTimerTick;
  FAnimationTimer.Enabled := False;

  // Create position timer
  FPositionTimer := TTimer.Create(Self);
  FPositionTimer.Interval := 200;
  FPositionTimer.Enabled := False;
  FPositionTimer.OnTimer := PositionTimerTick;

  // Create fallback timer
  FFallbackTimer := TTimer.Create(Self);
  FFallbackTimer.Interval := 15000;
  FFallbackTimer.OnTimer := FallbackTimerTick;
  FFallbackTimer.Enabled := False;

  // Create audio/video sync timer
  FSyncTimer := TTimer.Create(Self);
  FSyncTimer.Interval := 100;
  FSyncTimer.OnTimer := SyncTimerTick;
  FSyncTimer.Enabled := False;

  // Create health monitor timer
  FHealthTimer := TTimer.Create(Self);
  FHealthTimer.Interval := 30000; // 30 seconds
  FHealthTimer.OnTimer := HealthCheckTimerTick;
  FHealthTimer.Enabled := True;

  // Инициализация изображения
  FShowTopImage := False;
  FTopImagePath := '';
  FTopImage := TBitmap.Create;
  FTopImage.PixelFormat := pf32bit;
  FTopImage.HandleType := bmDIB;
  FTopImageRect := Rect(0, 0, 45, 45);
  FTopImageCornerRadius := 8;
  FTopImageOpacity := 255;

  // Create cursor hide timer
  SetupCursorHideTimer;

  // Create time display timers
  SetupTimeDisplayTimer;
  SetupTimeAutoHideTimer;

  // Create HTTP headers list
  FHttpHeaders := TStringList.Create;

  // Set basic headers
  SetBasicHeaders;

  // Initialize state
  FState := vlcIdle;
end;

destructor TVlcVisualComponent.Destroy;
begin
  FShutdownMode := True;

  // Show cursor
  ShowCursor;

  // Stop all timers
  StopAllTimers;

  // Stop VLC playback
  StopVLCPlayback;

  // Free VLC resources
  FreeVLCResources;

  // Безопасно освобождаем блокировку перед уничтожением буферов
  if FBufferLock <> nil then
  begin
    if FBufferLock.TryEnter then
    try
      // Free video buffers
      EnhancedFreeVideoBuffer;
    finally
      FBufferLock.Leave;
    end;
  end
  else
  begin
    EnhancedFreeVideoBuffer;
  end;

  // Free other resources
  FreeAndNil(FHttpHeaders);
  FreeAndNil(FCurrentBitmap);
  FreeAndNil(FBufferLock);

  // Free timers
  FreeAndNil(FHealthTimer);
  FreeAndNil(FAnimationTimer);
  FreeAndNil(FFrameTimer);
  FreeAndNil(FFallbackTimer);
  FreeAndNil(FSyncTimer);
  FreeAndNil(FPositionTimer);
  FreeAndNil(FCursorHideTimer);
  FreeAndNil(FTimeDisplayTimer);
  FreeAndNil(FTimeAutoHideTimer);

  // Освобождаем изображение
  if FTopImage <> nil then
    FreeAndNil(FTopImage);

  inherited Destroy;
end;

procedure TVlcVisualComponent.Paint;
var
  SourceRect, DestRect: TRect;
begin
  inherited Paint;

  // Черный фон
  Canvas.Brush.Color := clBlack;
  Canvas.FillRect(ClientRect);

  // Отображаем видео если есть данные
  if (FCurrentBitmap <> nil) and not FCurrentBitmap.Empty and FBufferValid then
  begin
    SourceRect := Rect(0, 0, FCurrentBitmap.Width, FCurrentBitmap.Height);
    DestRect := CalculateAspectRatioFit;

    // Используем высококачественный рендеринг
    Canvas.CopyMode := cmSrcCopy;
    SetStretchBltMode(Canvas.Handle, HALFTONE);
    SetBrushOrgEx(Canvas.Handle, 0, 0, nil);

    Canvas.CopyRect(DestRect, FCurrentBitmap.Canvas, SourceRect);
  end;

  // Время в левом верхнем углу
  DrawCurrentTime(Canvas);

  // Изображение в правом верхнем углу
  DrawTopImage(Canvas);

  // Анимация загрузки если нужно
  if FShowLoading then
    DrawLoadingAnimation(Canvas);

  // Строка состояния внизу
  DrawStatusBar(Canvas);

  // Отладочная информация
  {$IFDEF DEBUG}
  DrawDebugInfo(Canvas);
  {$ENDIF}
end;

function TVlcVisualComponent.IsTopImageLoaded: Boolean;
begin
  Result := FShowTopImage and
            Assigned(FTopImage) and
            not FTopImage.Empty and
            (FTopImage.Width > 0) and
            (FTopImage.Height > 0);
end;

procedure TVlcVisualComponent.Resize;
begin
  inherited Resize;
  Invalidate;
end;

procedure TVlcVisualComponent.SetTopImage(const ImagePath: string; Show: Boolean = True);
begin
  TopImagePath := ImagePath;
  ShowTopImage := Show;
end;

// Очистка изображения
procedure TVlcVisualComponent.ClearTopImage;
begin
  FTopImagePath := '';
  FTopImage.Width := 0;
  FTopImage.Height := 0;
  FShowTopImage := False;
  Invalidate;
end;

// Получение информации об изображении
function TVlcVisualComponent.GetTopImageInfo: string;
begin
  if FTopImagePath = '' then
    Result := '[No image loaded]'
  else if FTopImage.Empty then
    Result := Format('[Image failed to load: %s]', [ExtractFileName(FTopImagePath)])
  else
    Result := Format('%s (%dx%d)',
      [ExtractFileName(FTopImagePath), FTopImage.Width, FTopImage.Height]);
end;

procedure TVlcVisualComponent.ForceRedrawTopImage;
begin
  if FShowTopImage and (FTopImagePath <> '') then
  begin
    LoadTopImage; // Принудительно перезагружаем
    Invalidate;   // Принудительно перерисовываем
  end;
end;

// Загрузка изображения из ресурсов
procedure TVlcVisualComponent.LoadTopImageFromResource(const ResName: string);
var
  Stream: TResourceStream;
begin
  try
    Stream := TResourceStream.Create(HInstance, ResName, RT_RCDATA);
    try
      FTopImage.LoadFromStream(Stream);
      FTopImagePath := '[Resource: ' + ResName + ']';
      FShowTopImage := True;
      Invalidate;
    finally
      Stream.Free;
    end;
  except
    on E: Exception do

  end;
end;

// Загрузка изображения
procedure TVlcVisualComponent.LoadTopImage;
var
  PNG: TPNGImage;
  JPG: TJPEGImage;
  TempBitmap: TBitmap;
begin
  if FTopImagePath = '' then
  begin
    if Assigned(FTopImage) then
    begin
      FTopImage.Width := 0;
      FTopImage.Height := 0;
    end;
    Exit;
  end;

  try
    // Проверяем существование файла
    if not FileExists(FTopImagePath) then
    begin
      Exit;
    end;

    var Ext := LowerCase(ExtractFileExt(FTopImagePath));

    // Очищаем текущее изображение
    if Assigned(FTopImage) then
    begin
      FTopImage.Width := 0;
      FTopImage.Height := 0;
    end;

    // Загружаем в зависимости от формата
    if Ext = '.png' then
    begin
      // Загрузка PNG
      PNG := TPNGImage.Create;
      try
        PNG.LoadFromFile(FTopImagePath);

        // Конвертируем PNG в Bitmap
        FTopImage.Assign(PNG);
      finally
        PNG.Free;
      end;
    end
    else if (Ext = '.jpg') or (Ext = '.jpeg') then
    begin
      // Загрузка JPEG
      JPG := TJPEGImage.Create;
      try
        JPG.LoadFromFile(FTopImagePath);
        FTopImage.Assign(JPG);
      finally
        JPG.Free;
      end;
    end
    else if Ext = '.bmp' then
    begin
      // Загрузка BMP
      FTopImage.LoadFromFile(FTopImagePath);
    end
    else
    begin
      // Неподдерживаемый формат
      Exit;
    end;

    // Проверяем успешность загрузки
    if FTopImage.Empty then
      Exit;

    // Масштабируем до 45x45px с сохранением пропорций
    TempBitmap := TBitmap.Create;
    try
      TempBitmap.PixelFormat := pf32bit;
      TempBitmap.HandleType := bmDIB;
      TempBitmap.Width := 45;
      TempBitmap.Height := 45;

      // Прозрачный фон
      TempBitmap.Canvas.Brush.Color := clBlack;
      TempBitmap.Canvas.FillRect(Rect(0, 0, 45, 45));

      // Вычисляем размеры с сохранением пропорций
      var SourceRect := Rect(0, 0, FTopImage.Width, FTopImage.Height);

      // Рассчитываем размер для сохранения пропорций
      var RatioX := 45 / FTopImage.Width;
      var RatioY := 45 / FTopImage.Height;
      var Ratio := Min(RatioX, RatioY);

      var NewWidth := Round(FTopImage.Width * Ratio);
      var NewHeight := Round(FTopImage.Height * Ratio);

      var DestRect := Rect(
        (45 - NewWidth) div 2,
        (45 - NewHeight) div 2,
        (45 - NewWidth) div 2 + NewWidth,
        (45 - NewHeight) div 2 + NewHeight
      );

      // Используем высококачественное растяжение
      SetStretchBltMode(TempBitmap.Canvas.Handle, HALFTONE);
      SetBrushOrgEx(TempBitmap.Canvas.Handle, 0, 0, nil);

      // Копируем с растяжением
      TempBitmap.Canvas.CopyRect(DestRect, FTopImage.Canvas, SourceRect);

      // Присваиваем обратно
      FTopImage.Assign(TempBitmap);

    finally
      TempBitmap.Free;
    end;

    // Обновляем прямоугольник изображения
    FTopImageRect := Rect(0, 0, 45, 45);

  except
    on E: Exception do
    begin
      // Очищаем изображение при ошибке
      if Assigned(FTopImage) then
      begin
        FTopImage.Width := 0;
        FTopImage.Height := 0;
        FTopImageRect := Rect(0, 0, 0, 0);
      end;
    end;
  end;
end;

// Отрисовка изображения
procedure TVlcVisualComponent.DrawTopImage(Canvas: TCanvas);
begin
  // Проверяем условия отображения
  if not FShowTopImage or not Assigned(FTopImage) or FTopImage.Empty then
    Exit;

  // Проверяем размеры
  if (FTopImage.Width <= 0) or (FTopImage.Height <= 0) then
    Exit;

  try
    // Позиция в правом верхнем углу
    var ImageRect := TRect.Create(
      Width - 55,  // 45px + 10px отступ
      0,
      Width - 5,
      55           // 45px + 10px отступ
    );

    // Обновляем прямоугольник
    FTopImageRect := ImageRect;

    // Для отладки: рисуем рамку вокруг области
    Canvas.Pen.Color := clRed;
    Canvas.Pen.Style := psSolid;
    Canvas.Brush.Style := bsClear;
    Canvas.Rectangle(ImageRect);

    // Рисуем изображение
    Canvas.CopyRect(ImageRect, FTopImage.Canvas,
      Rect(0, 0, FTopImage.Width, FTopImage.Height));

    // Рамка с скругленными углами
    if FTopImageCornerRadius > 0 then
    begin
      Canvas.Pen.Color := $FF666666;
      Canvas.Pen.Width := 1;
      Canvas.Pen.Style := psSolid;
      Canvas.Brush.Style := bsClear;
      Canvas.RoundRect(ImageRect, FTopImageCornerRadius, FTopImageCornerRadius);
    end;

  except
    on E: Exception do
    begin
      // Игнорируем ошибки отрисовки
    end;
  end;
end;

// Сеттеры свойств
procedure TVlcVisualComponent.SetShowTopImage(const Value: Boolean);
begin
  if FShowTopImage <> Value then
  begin
    FShowTopImage := Value;
    Invalidate;

  end;
end;

procedure TVlcVisualComponent.SetTopImagePath(const Value: string);
begin
  if FTopImagePath <> Value then
  begin
    FTopImagePath := Value;

    // Если путь не пустой, сразу загружаем изображение
    if Value <> '' then
    begin
      LoadTopImage;
      // Автоматически показываем изображение, если оно успешно загружено
      if not FTopImage.Empty then
        FShowTopImage := True;
    end
    else
    begin
      // Если путь пустой, очищаем изображение
      if Assigned(FTopImage) then
      begin
        FTopImage.Width := 0;
        FTopImage.Height := 0;
      end;
      FShowTopImage := False;
    end;

    Invalidate;
  end;
end;

procedure TVlcVisualComponent.SetTopImageCornerRadius(const Value: Integer);
begin
  if FTopImageCornerRadius <> Value then
  begin
    FTopImageCornerRadius := Max(0, Value);
    Invalidate;
  end;
end;

procedure TVlcVisualComponent.SetTopImageOpacity(const Value: Byte);
begin
  if FTopImageOpacity <> Value then
  begin
    FTopImageOpacity := Value;
    Invalidate;
  end;
end;

procedure TVlcVisualComponent.AllocateVideoBuffer(AWidth, AHeight: Integer);
var
  I: Integer;
begin
  if (csDestroying in ComponentState) then
    Exit;

  if FBufferLock = nil then
    Exit;

  FBufferLock.Enter;
  try
    // Сохраняем реальные размеры видео
    if AWidth > 0 then
      FVideoWidth := AWidth;
    if AHeight > 0 then
      FVideoHeight := AHeight;

    // Если размеры не указаны, используем значения по умолчанию
    if FVideoWidth <= 0 then FVideoWidth := 1280;
    if FVideoHeight <= 0 then FVideoHeight := 720;

    // Рассчитываем pitch (длина строки в байтах)
    // Для формата BGRA: 4 байта на пиксель
    FVideoPitch := FVideoWidth * 4;
    // Выравниваем pitch до 16 байт (для лучшей производительности)
    FVideoPitch := (FVideoPitch + 15) and not 15;

    // Рассчитываем общий размер буфера
    FVideoBufferSize := FVideoHeight * FVideoPitch;

    // Освобождаем старые буферы если они существуют
    for I := 0 to 1 do
    begin
      if FVideoBuffer[I] <> nil then
      begin
        FreeMem(FVideoBuffer[I]);
        FVideoBuffer[I] := nil;
      end;
    end;

    if FBackBuffer <> nil then
    begin
      FreeMem(FBackBuffer);
      FBackBuffer := nil;
    end;

    // Выделяем память для буферов с выравниванием
    try
      // Два буфера для двойной буферизации
      for I := 0 to 1 do
      begin
        FVideoBuffer[I] := AllocMem(FVideoBufferSize);
        if FVideoBuffer[I] <> nil then
        begin
          // Инициализируем черным цветом
          FillChar(FVideoBuffer[I]^, FVideoBufferSize, 0);
        end;
      end;

      // Back buffer
      FBackBuffer := AllocMem(FVideoBufferSize);
      if FBackBuffer <> nil then
      begin
        FillChar(FBackBuffer^, FVideoBufferSize, 0);
      end;

      // Проверяем успешность выделения
      FBufferValid := (FVideoBuffer[0] <> nil) and
                     (FVideoBuffer[1] <> nil) and
                     (FBackBuffer <> nil);

      FCurrentBuffer := 0;

    except
      on E: Exception do
      begin
        FBufferValid := False;
        // Освобождаем всё что успели выделить
        for I := 0 to 1 do
        begin
          if FVideoBuffer[I] <> nil then
          begin
            FreeMem(FVideoBuffer[I]);
            FVideoBuffer[I] := nil;
          end;
        end;
        if FBackBuffer <> nil then
        begin
          FreeMem(FBackBuffer);
          FBackBuffer := nil;
        end;
        Exit;
      end;
    end;

    // Обновляем VCL bitmap для отображения
    if FCurrentBitmap = nil then
      FCurrentBitmap := TBitmap.Create;

    try
      FCurrentBitmap.PixelFormat := pf32bit;
      FCurrentBitmap.HandleType := bmDIB;
      FCurrentBitmap.IgnorePalette := True;

      // Устанавливаем размеры битмапа
      FCurrentBitmap.Width := FVideoWidth;
      FCurrentBitmap.Height := FVideoHeight;

      // Очищаем битмап черным цветом
      FCurrentBitmap.Canvas.Brush.Color := clBlack;
      FCurrentBitmap.Canvas.FillRect(Rect(0, 0, FVideoWidth, FVideoHeight));

    except
      on E: Exception do
      begin
        FBufferValid := False;
      end;
    end;

  finally
    FBufferLock.Leave;
  end;
end;

procedure TVlcVisualComponent.ApplyVideoQualitySettings;
begin
  if (FPlayer = nil) or not Assigned(T_libvlc_video_set_adjust_int) then
    Exit;

  try
    // Включаем корректировку видео
    T_libvlc_video_set_adjust_int(FPlayer, libvlc_adjust_Enable, 1);

    // Настройки качества
    if FHighQuality then
    begin
      // Высокое качество
      T_libvlc_video_set_adjust_float(FPlayer, libvlc_adjust_Contrast, 1.0);
      T_libvlc_video_set_adjust_float(FPlayer, libvlc_adjust_Brightness, 1.0);
      T_libvlc_video_set_adjust_float(FPlayer, libvlc_adjust_Saturation, 1.2);
      T_libvlc_video_set_adjust_float(FPlayer, libvlc_adjust_Gamma, 1.1);
    end
    else
    begin
      // Нормальное качество
      T_libvlc_video_set_adjust_float(FPlayer, libvlc_adjust_Contrast, 1.0);
      T_libvlc_video_set_adjust_float(FPlayer, libvlc_adjust_Brightness, 1.0);
      T_libvlc_video_set_adjust_float(FPlayer, libvlc_adjust_Saturation, 1.0);
      T_libvlc_video_set_adjust_float(FPlayer, libvlc_adjust_Gamma, 1.0);
    end;

  except
    on E: Exception do
    begin
      // Игнорируем ошибки при настройке качества
    end;
  end;
end;

procedure TVlcVisualComponent.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;

  // Reset cursor timer
  if IsPlaying then
    ResetCursorTimer;

  // Show time temporarily if auto-hide enabled
  if FTimeAutoHide then
    ResetTimeAutoHideTimer;

  if Assigned(FOnVideoMouseDown) then
    FOnVideoMouseDown(Self, Button, Shift, X, Y);
end;

procedure TVlcVisualComponent.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;

  if IsPlaying then
    ResetCursorTimer;

  if FTimeAutoHide then
    ResetTimeAutoHideTimer;

  if Assigned(FOnVideoMouseUp) then
    FOnVideoMouseUp(Self, Button, Shift, X, Y);

  if Assigned(FOnVideoClick) and (Button = mbLeft) then
    FOnVideoClick(Self);
end;

procedure TVlcVisualComponent.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited;

  // Reset cursor hide timer
  if IsPlaying then
    ResetCursorTimer;

  // Show time temporarily if auto-hide enabled
  if FTimeAutoHide then
    ResetTimeAutoHideTimer;

  if Assigned(FOnVideoMouseMove) then
    FOnVideoMouseMove(Self, Shift, X, Y);
end;

procedure TVlcVisualComponent.DblClick;
begin
  inherited;

  // Reset cursor timer
  if IsPlaying then
    ResetCursorTimer;

  if Assigned(FOnVideoDblClick) then
    FOnVideoDblClick(Self);
end;

procedure TVlcVisualComponent.MouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  inherited;

  if IsPlaying then
    ResetCursorTimer;

  if FTimeAutoHide then
    ResetTimeAutoHideTimer;

  if Assigned(FOnVideoMouseWheel) then
    FOnVideoMouseWheel(Self, Shift, WheelDelta, ScreenToClient(MousePos));
  Handled := True;
end;

procedure TVlcVisualComponent.DrawLoadingAnimation(Canvas: TCanvas);
var
  CenterX, CenterY: Integer;
  OuterRadius, DotRadius: Single;
  TotalDots, ActiveDots, I: Integer;
  Angle: Single;
  DotPos: TPoint;
  CurrentTime: Cardinal;
  AnimationPhase: Integer;
begin
  if not FShowLoading then Exit;

  CurrentTime := GetTickCount;

  // Центр компонента
  CenterX := Width div 2;
  CenterY := Height div 2;

  // Параметры анимации - УВЕЛИЧЕНЫ В 2 РАЗА
  OuterRadius := Min(Width, Height) * 0.05; // УВЕЛИЧЕНО (было 0.05)
  OuterRadius := Max(40.0, Min(100.0, OuterRadius));
  DotRadius := OuterRadius * 0.02; // Размер точки
  DotRadius := Max(3.0, Min(8.0, DotRadius));
  TotalDots := 16;

  // Вычисляем активные точки
  AnimationPhase := (CurrentTime div 80) mod (TotalDots + 1); // Быстрее анимация
  ActiveDots := AnimationPhase;

  // Рисуем точки по кругу
  for I := 0 to TotalDots - 1 do
  begin
    Angle := 2 * Pi * I / TotalDots;

    DotPos := Point(
      Round(CenterX + Cos(Angle) * OuterRadius),
      Round(CenterY + Sin(Angle) * OuterRadius)
    );

    var IsActive := I < ActiveDots;

    if IsActive then
    begin
      // Активная точка - градиент яркости
      var Brightness := 0.6 + 0.4 * (I / TotalDots);
      var GrayValue := Trunc(Brightness * 255);
      var DotColor := RGB(GrayValue, GrayValue, GrayValue);

      // Большая активная точка
      Canvas.Brush.Color := DotColor;
      Canvas.Pen.Color := clWhite;
      Canvas.Pen.Width := 1;
      Canvas.Pen.Style := psSolid;
      Canvas.Brush.Style := bsSolid;

      var ActiveSize := DotRadius * 0.8;
      Canvas.Ellipse(
        DotPos.X - Round(ActiveSize),
        DotPos.Y - Round(ActiveSize),
        DotPos.X + Round(ActiveSize),
        DotPos.Y + Round(ActiveSize)
      );
    end
    else
    begin
      // Неактивная точка - маленькая и светлая
      Canvas.Brush.Color := $00CCCCCC; // Полупрозрачный светлый серый
      Canvas.Pen.Style := psClear;
      Canvas.Brush.Style := bsSolid;

      var InactiveSize := DotRadius * 0.6;
      Canvas.Ellipse(
        DotPos.X - Round(InactiveSize),
        DotPos.Y - Round(InactiveSize),
        DotPos.X + Round(InactiveSize),
        DotPos.Y + Round(InactiveSize)
      );
    end;
  end;

  // Бегающая точка (главная анимация)
  if ActiveDots > 0 then
  begin
    var RunningIndex := ActiveDots - 1;
    if RunningIndex < TotalDots then
    begin
      var RunningAngle := 2 * Pi * RunningIndex / TotalDots;
      var RunningPos := Point(
        Round(CenterX + Cos(RunningAngle) * OuterRadius),
        Round(CenterY + Sin(RunningAngle) * OuterRadius)
      );

      // Пульсация бегающей точки
      var Pulse := (Sin(DegToRad(CurrentTime / 15)) + 1) / 2;
      var RunningSize := DotRadius * (1.0 + 0.2 * Pulse);

      // Белая бегающая точка
      Canvas.Brush.Color := clWhite;
      Canvas.Pen.Color := $888888; // Темно-серая обводка
      Canvas.Pen.Width := 1;
      Canvas.Brush.Style := bsSolid;

      Canvas.Ellipse(
        RunningPos.X - Round(RunningSize),
        RunningPos.Y - Round(RunningSize),
        RunningPos.X + Round(RunningSize),
        RunningPos.Y + Round(RunningSize)
      );
    end;
  end;
end;

procedure TVlcVisualComponent.DrawStatusBar(Canvas: TCanvas);
var
  TextWidth, TextHeight: Integer;
  StatusRect: TRect;
  ActualText: string;
begin
  if not FStatusBarVisible or (FStatusBarText = '') then Exit;

  // Use only user text (without time)
  ActualText := FStatusBarText;

  // Configure font
  Canvas.Font.Color := FStatusBarTextColor;
  Canvas.Font.Size := 10;  // 8 вместо 16
  Canvas.Font.Style := [];  // Пустой стиль (не жирный)
  Canvas.Font.Name := 'Arial';

  // Calculate status text size
  TextWidth := Canvas.TextWidth(ActualText);
  TextHeight := Canvas.TextHeight(ActualText);

  // Create rectangle for status bar background (BOTTOM center)
  StatusRect := Rect(
    (Width - TextWidth - 10) div 2,  // Center horizontally
    Height - TextHeight - 30,         // Bottom with 8px margin (уменьшили)
    (Width + TextWidth + 10) div 2,  // Center horizontally
    Height - 3                       // Bottom with 3px margin (уменьшили)
  );

  // Полностью прозрачный фон - не рисуем прямоугольник
  // Просто рисуем текст

  // Draw status text
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := ClWhite;  // Серый цвет (не жирный)
  Canvas.TextOut(StatusRect.Left + 5, StatusRect.Top + 3, ActualText);
end;

procedure TVlcVisualComponent.DrawCurrentTime(Canvas: TCanvas);
var
  CurrentTime: TDateTime;
  TimeStr: string;
  TextWidth, TextHeight: Integer;
begin
  // Check if time should be shown
  if not FShowCurrentTime then Exit;
  if FTimeAutoHide and not FTimeVisible then Exit;

  CurrentTime := Now;
  TimeStr := FormatDateTime('hh:nn:ss', CurrentTime);

  // Серый цвет текста для времени
  Canvas.Font.Color := $888888;
  Canvas.Font.Size := 10;  // Уменьшили в 2 раза (было 14)
  Canvas.Font.Style := [];  // Не жирный
  Canvas.Font.Name := 'Arial';

  // Calculate time text size
  TextWidth := Canvas.TextWidth(TimeStr);
  TextHeight := Canvas.TextHeight(TimeStr);

  // Просто рисуем текст в левом верхнем углу без фона
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := ClWhite;
  Canvas.TextOut(20, 20, TimeStr);  // Уменьшили отступы
end;

procedure TVlcVisualComponent.DrawDebugInfo(Canvas: TCanvas);
var
  InfoText: string;
begin
  if FCurrentFPS = 0 then Exit;

  // Move debug info to bottom left (above status if visible)
  InfoText := Format('FPS: %d | %dx%d | %s',
    [FCurrentFPS, FVideoWidth, FVideoHeight, GetPlayerStatus]);

  // Уменьшили текст в 2 раза, не жирный
  Canvas.Font.Color := $888888;
  Canvas.Font.Size := 10;  // Уменьшили
  Canvas.Font.Style := [];  // Не жирный
  Canvas.Font.Name := 'Arial';

  // Text in серый цвет без фона
  Canvas.Brush.Style := bsClear;

  if FStatusBarVisible then
    Canvas.TextOut(3, Height - 45, InfoText)  // Above status bar
  else
    Canvas.TextOut(3, Height - 25, InfoText); // Bottom left
end;

function TVlcVisualComponent.CalculateAspectRatioFit: TRect;
var
  VideoRatio, ControlRatio: Single;
  ScaledWidth, ScaledHeight: Integer;
begin
  if (FCurrentBitmap = nil) or FCurrentBitmap.Empty or
     (FCurrentBitmap.Width = 0) or (FCurrentBitmap.Height = 0) then
  begin
    Result := ClientRect;
    Exit;
  end;

  VideoRatio := FCurrentBitmap.Width / FCurrentBitmap.Height;
  ControlRatio := Width / Height;

  if VideoRatio > ControlRatio then
  begin
    ScaledWidth := Width;
    ScaledHeight := Round(Width / VideoRatio);
    Result := Rect(
      0,
      (Height - ScaledHeight) div 2,
      ScaledWidth,
      (Height - ScaledHeight) div 2 + ScaledHeight
    );
  end
  else
  begin
    ScaledHeight := Height;
    ScaledWidth := Round(Height * VideoRatio);
    Result := Rect(
      (Width - ScaledWidth) div 2,
      0,
      (Width - ScaledWidth) div 2 + ScaledWidth,
      ScaledHeight
    );
  end;
end;

procedure TVlcVisualComponent.CalculateFPS;
var
  CurrentTime: Cardinal;
begin
  Inc(FFrameCount);
  CurrentTime := GetTickCount;

  if CurrentTime - FLastFpsTime >= 1000 then
  begin
    FCurrentFPS := FFrameCount;
    FFrameCount := 0;
    FLastFpsTime := CurrentTime;
  end;
end;

function TVlcVisualComponent.LockCallback(opaque: Pointer; planes: PPointer): Pointer; cdecl;
begin
  Result := nil;
  if (opaque = nil) or (GDestroyedPlayers = nil) then Exit;
  if GDestroyedPlayers.Contains(opaque) then Exit;

  try
    with TVlcVisualComponent(opaque) do
    begin
      if FShutdownMode or (csDestroying in ComponentState) then Exit;
      if FBackBuffer = nil then Exit;

      // INSTANT - без блокировок!
      Result := FBackBuffer;
      if planes <> nil then
        planes^ := FBackBuffer;
    end;
  except
    Result := nil;
  end;
end;

procedure TVlcVisualComponent.UnlockCallback(opaque: Pointer; picture: Pointer; planes: PPointer); cdecl;
begin
  if (opaque = nil) or (GDestroyedPlayers = nil) then Exit;
  if GDestroyedPlayers.Contains(opaque) then Exit;

  try
    with TVlcVisualComponent(opaque) do
    begin
      if FShutdownMode or (csDestroying in ComponentState) then Exit;

      // FAST BUFFER SWITCH WITH SHORT LOCK
      if FBufferLock.TryEnter then
      try
        SwapBuffers;
        FFrameReady := True;
        FLastFrameUpdateTime := GetTickCount;
      finally
        FBufferLock.Leave;
      end;
    end;
  except
    // Ignore errors in callback
  end;
end;

procedure TVlcVisualComponent.SwapBuffers;
var
  Temp: Pointer;
begin
  if FBufferLock = nil then Exit;

  if FBufferLock.TryEnter then
  try
    // Simple buffer swap
    Temp := FVideoBuffer[FCurrentBuffer];
    FVideoBuffer[FCurrentBuffer] := FBackBuffer;
    FBackBuffer := Temp;

    // Switch current buffer
    FCurrentBuffer := (FCurrentBuffer + 1) mod 2;

  finally
    FBufferLock.Leave;
  end;
end;

procedure TVlcVisualComponent.UpdateBitmapFromBuffer;
var
  Y: Integer;
  SourcePtr: PByte;
  DestPtr: PByte;
  BytesToCopy: Integer;
begin
  if (csDestroying in ComponentState) or
     (FCurrentBitmap = nil) or
     (FVideoBuffer[FCurrentBuffer] = nil) or
     (FVideoBufferSize = 0) then
  begin
    Exit;
  end;

  try
    // Check and set bitmap dimensions
    if (FCurrentBitmap.Width <> FVideoWidth) or (FCurrentBitmap.Height <> FVideoHeight) then
    begin
      FCurrentBitmap.PixelFormat := pf32bit;
      FCurrentBitmap.HandleType := bmDIB;
      FCurrentBitmap.IgnorePalette := True;
      FCurrentBitmap.Width := FVideoWidth;
      FCurrentBitmap.Height := FVideoHeight;
    end;

    // Check dimensions
    if (FCurrentBitmap.Width <= 0) or (FCurrentBitmap.Height <= 0) or
       (FVideoWidth <= 0) or (FVideoHeight <= 0) then
    begin
      Exit;
    end;

    // Calculate number of bytes to copy
    BytesToCopy := Min(FVideoWidth * 4, FCurrentBitmap.Width * 4);

    // Copy data line by line
    for Y := 0 to Min(FVideoHeight, FCurrentBitmap.Height) - 1 do
    begin
      // Get pointer to line in VLC buffer
      SourcePtr := PByte(FVideoBuffer[FCurrentBuffer]);
      Inc(SourcePtr, Y * FVideoPitch);

      // Get pointer to line in VCL bitmap
      DestPtr := FCurrentBitmap.ScanLine[Y];

      // Copy line data
      Move(SourcePtr^, DestPtr^, BytesToCopy);
    end;

    CalculateFPS;

  except
    on E: Exception do
    begin
      OutputDebugString(PChar('Error in UpdateBitmapFromBuffer: ' + E.Message));
    end;
  end;
end;

procedure TVlcVisualComponent.FrameTimerTick(Sender: TObject);
var
  CurrentTime: Cardinal;
  TimeSinceFirstFrame: Cardinal;
begin
  if (csDestroying in ComponentState) then Exit;

  CurrentTime := GetTickCount;

  // CHECK BUFFER VALIDITY BEFORE WORKING
  if not FBufferValid then
  begin
    // Try to restore buffers if video dimensions exist
    if (FVideoWidth > 0) and (FVideoHeight > 0) and IsPlaying then
    begin
      AllocateVideoBuffer(FVideoWidth, FVideoHeight);
    end;
    Exit;
  end;

  // SHORT LOCK ONLY FOR COPYING TIME
  if FBufferLock.TryEnter then
  try
    if FFrameReady and FBufferValid then
    begin
      // ADDITIONAL INTEGRITY CHECK
      if (FVideoBuffer[FCurrentBuffer] = nil) or (FVideoBufferSize = 0) then
      begin
        FBufferValid := False;
        Exit;
      end;

      UpdateBitmapFromBuffer;
      FFrameReady := False;

      // IMPORTANT CHANGE: Track first frame and delay
      if FFirstFrameTime = 0 then
      begin
        FFirstFrameTime := CurrentTime;
      end;

      // Check if 1 second has passed since first frame
      if FFirstFrameTime > 0 then
      begin
        TimeSinceFirstFrame := CurrentTime - FFirstFrameTime;
        if (TimeSinceFirstFrame >= FAnimationHideDelay) and FShowLoading then
        begin
          HideLoadingAnimationProc;
          FFirstFrameTime := 0; // Reset for next time
        end;
      end;

      SafeInvalidate;
    end;
  finally
    FBufferLock.Leave;
  end;
end;

procedure TVlcVisualComponent.SafeInvalidate;
begin
  if (csDestroying in ComponentState) or not Visible then
    Exit;

  if not HandleAllocated then
    Exit;

  // Always use InvalidateRect - it's thread-safe
  InvalidateRect(Handle, nil, False);
end;

procedure TVlcVisualComponent.ClearVideoBuffer;
begin
  if (FBufferLock = nil) or (csDestroying in ComponentState) then
    Exit;

  FBufferLock.Enter;
  try
    // Clear VCL bitmap
    if FCurrentBitmap <> nil then
    begin
      FCurrentBitmap.Canvas.Brush.Color := clBlack;
      FCurrentBitmap.Canvas.FillRect(Rect(0, 0, FCurrentBitmap.Width, FCurrentBitmap.Height));
    end;

    // Clear buffers
    for var I := 0 to 1 do
    begin
      if (FVideoBuffer[I] <> nil) and (FVideoBufferSize > 0) then
      begin
        FillChar(FVideoBuffer[I]^, FVideoBufferSize, 0);
      end;
    end;

    if (FBackBuffer <> nil) and (FVideoBufferSize > 0) then
    begin
      FillChar(FBackBuffer^, FVideoBufferSize, 0);
    end;

    FFrameReady := False;
    FCurrentBuffer := 0;

  finally
    FBufferLock.Leave;
  end;

  SafeInvalidate;
end;

procedure TVlcVisualComponent.ClearBuffer;
begin
  ClearVideoBuffer;
end;

procedure TVlcVisualComponent.SetMediaURL(const Value: string);
begin
  if FMediaURL <> Value then
  begin
    FMediaURL := Value;
    if (Value <> '') and not (csLoading in ComponentState) then
      LoadMedia(Value);
  end;
end;

procedure TVlcVisualComponent.SetVolume(Value: Integer);
begin
  if Value < 0 then Value := 0;
  if Value > 100 then Value := 100;

  if FVolume <> Value then
  begin
    FVolume := Value;

    if (FPlayer <> nil) and Assigned(T_libvlc_audio_set_volume) and not FShutdownMode then
    begin
      try
        T_libvlc_audio_set_volume(FPlayer, Value);
      except
        on E: Exception do
        begin
        end;
      end;
    end;
  end;
end;

procedure TVlcVisualComponent.SetUserAgent(const Value: string);
begin
  if FUserAgent <> Value then
  begin
    FUserAgent := Value;
  end;
end;

procedure TVlcVisualComponent.SetReferer(const Value: string);
begin
  if FReferer <> Value then
  begin
    FReferer := Value;
  end;
end;

procedure TVlcVisualComponent.SetHttpHeaders(const Value: TStringList);
begin
  if FHttpHeaders <> nil then
    FHttpHeaders.Assign(Value);
end;

function TVlcVisualComponent.GetMuted: Boolean;
begin
  Result := FMuted;
end;

procedure TVlcVisualComponent.SetMuted(const Value: Boolean);
begin
  if FMuted <> Value then
  begin
    FMuted := Value;

    if (FPlayer <> nil) and Assigned(T_libvlc_audio_set_mute) and not FShutdownMode then
    begin
      try
        T_libvlc_audio_set_mute(FPlayer, Integer(FMuted));
      except
        on E: Exception do
        begin
        end;
      end;
    end;
  end;
end;

procedure TVlcVisualComponent.SetLoopPlayback(const Value: Boolean);
begin
  if FLoopPlayback <> Value then
  begin
    FLoopPlayback := Value;
  end;
end;

procedure TVlcVisualComponent.SetHighQuality(const Value: Boolean);
begin
  if FHighQuality <> Value then
  begin
    FHighQuality := Value;

    // Apply quality settings immediately if player exists
    if FPlayer <> nil then
      ApplyVideoQualitySettings;

    Invalidate;
  end;
end;

procedure TVlcVisualComponent.SetVideoQuality(Quality: Integer);
begin
  // Quality from 0 to 100
  Quality := Max(0, Min(100, Quality));

  if (FPlayer <> nil) and Assigned(T_libvlc_video_set_adjust_float) then
  begin
    try
      // Включаем корректировку
      if Assigned(T_libvlc_video_set_adjust_int) then
        T_libvlc_video_set_adjust_int(FPlayer, libvlc_adjust_Enable, 1);

      // Настраиваем параметры в зависимости от качества
      var Contrast := 0.8 + (Quality * 0.004); // 0.8 - 1.2
      var Brightness := 0.9 + (Quality * 0.002); // 0.9 - 1.1
      var Saturation := 0.8 + (Quality * 0.006); // 0.8 - 1.4
      var Gamma := 0.9 + (Quality * 0.003); // 0.9 - 1.2

      T_libvlc_video_set_adjust_float(FPlayer, libvlc_adjust_Contrast, Contrast);
      T_libvlc_video_set_adjust_float(FPlayer, libvlc_adjust_Brightness, Brightness);
      T_libvlc_video_set_adjust_float(FPlayer, libvlc_adjust_Saturation, Saturation);
      T_libvlc_video_set_adjust_float(FPlayer, libvlc_adjust_Gamma, Gamma);

    except
      on E: Exception do
      begin
      end;
    end;
  end;
end;

procedure TVlcVisualComponent.SetStatusBarVisible(const Value: Boolean);
begin
  if FStatusBarVisible <> Value then
  begin
    FStatusBarVisible := Value;
    Invalidate;
  end;
end;

procedure TVlcVisualComponent.SetStatusBarText(const Value: string);
begin
  if FStatusBarText <> Value then
  begin
    FStatusBarText := Value;
    if FStatusBarVisible then
      Invalidate;
  end;
end;

procedure TVlcVisualComponent.SetStatusBarFontSize(const Value: Integer);
begin
  if FStatusBarFontSize <> Value then
  begin
    FStatusBarFontSize := Value;
    if FStatusBarVisible then
      Invalidate;
  end;
end;

procedure TVlcVisualComponent.SetStatusBarBackground(const Value: TColor);
begin
  if FStatusBarBackground <> Value then
  begin
    FStatusBarBackground := Value;
    if FStatusBarVisible then
      Invalidate;
  end;
end;

procedure TVlcVisualComponent.SetStatusBarTextColor(const Value: TColor);
begin
  if FStatusBarTextColor <> Value then
  begin
    FStatusBarTextColor := Value;
    if FStatusBarVisible then
      Invalidate;
  end;
end;

procedure TVlcVisualComponent.SetStatusBarCornerRadius(const Value: Integer);
begin
  if FStatusBarCornerRadius <> Value then
  begin
    FStatusBarCornerRadius := Value;
    if FStatusBarVisible then
      Invalidate;
  end;
end;

procedure TVlcVisualComponent.AnimationTimerTick(Sender: TObject);
begin
  if FShowLoading and not (csDestroying in ComponentState) and (FState <> vlcPlaying) then
  begin
    // Эта анимация не использует FAnimationAngle - она основана на времени
    Invalidate;
  end
  else if FState = vlcPlaying then
  begin
    if FAnimationTimer <> nil then
      FAnimationTimer.Enabled := False;
  end;
end;

procedure TVlcVisualComponent.PositionTimerTick(Sender: TObject);
begin
  // Position updates handled by VLC events
end;

procedure TVlcVisualComponent.ShowLoadingAnimationProc;
begin
  if FShowLoading then Exit;

  FShowLoading := True;
  FFirstFrameTime := 0; // Сбрасываем время первого кадра
  FAnimationAngle := 0; // Сбрасываем угол анимации

  // Запускаем таймер анимации
  if FAnimationTimer <> nil then
    FAnimationTimer.Enabled := True;

  Invalidate;
end;

procedure TVlcVisualComponent.HideLoadingAnimationProc;
begin
  if not FShowLoading then Exit;

  FShowLoading := False;
  FFirstFrameTime := 0; // Сбрасываем время первого кадра
  FAnimationAngle := 0; // Сбрасываем угол анимации

  // Останавливаем таймер анимации
  if FAnimationTimer <> nil then
    FAnimationTimer.Enabled := False;

  // Принудительное обновление экрана чтобы убрать анимацию
  SafeInvalidate;
end;

procedure TVlcVisualComponent.UpdateLoadingStage(const Stage: string);
begin
  FLoadingStage := Stage;

  if FShowLoading and FFrameReady and FBufferValid then
    UpdateBitmapFromBuffer;
end;

procedure TVlcVisualComponent.EnableAudio;
begin
  if FAudioEnabled or FShutdownMode then Exit;

  if (FPlayer <> nil) and Assigned(T_libvlc_audio_set_volume) then
  begin
    try
      T_libvlc_audio_set_volume(FPlayer, FVolume);
      FVolume := 100;
    except
      on E: Exception do
      begin
      end;
    end;
  end;

  if (FPlayer <> nil) and Assigned(T_libvlc_audio_set_mute) then
  begin
    try
      T_libvlc_audio_set_mute(FPlayer, Integer(FMuted));
    except
      on E: Exception do
      begin
      end;
    end;
  end;

  FAudioEnabled := True;
end;

procedure TVlcVisualComponent.ForceVideoUpdate;
begin
  if FFrameReady and FBufferValid then
  begin
    try
      UpdateBitmapFromBuffer;
      FFrameReady := False;
      Invalidate;
    except
      on E: Exception do
      begin
      end;
    end;
  end;
end;

procedure TVlcVisualComponent.EnableAudioSync(Enabled: Boolean);
begin
  if FAudioSyncEnabled <> Enabled then
  begin
    FAudioSyncEnabled := Enabled;
    FSyncTimer.Enabled := Enabled and IsPlaying;
  end;
end;

procedure TVlcVisualComponent.SetAudioDelay(DelayMs: Integer);
begin
  if FAudioDelay <> DelayMs then
  begin
    FAudioDelay := DelayMs;
  end;
end;

procedure TVlcVisualComponent.SetTargetFPS(FPS: Integer);
begin
  FTargetFPS := Max(15, Min(60, FPS));
  if FFrameTimer <> nil then
    FFrameTimer.Interval := 1000 div FTargetFPS;
end;

function TVlcVisualComponent.GetCurrentFPS: Integer;
begin
  Result := FCurrentFPS;
end;

procedure TVlcVisualComponent.EnableHighPerformanceMode(Enabled: Boolean);
begin
  if Enabled then
  begin
    SetTargetFPS(30);
  end
  else
  begin
    SetTargetFPS(60);
  end;
end;

procedure TVlcVisualComponent.Play;
var
  ResultCode: Integer;
begin
  if not IsInitialized then
  begin
    Exit;
  end;

  if FPlayer = nil then
  begin
    Exit;
  end;

  // Start health monitoring
  StartStreamHealthMonitor;

  // Start cursor hide timer for inactivity
  FCursorHideTimer.Enabled := True;
  ResetCursorTimer; // Reset timer and show cursor

  if FFrameTimer <> nil then
  begin
    FFrameTimer.Enabled := True;
  end;

  ResultCode := T_libvlc_media_player_play(FPlayer);

  if ResultCode = 0 then
  begin
  end
  else
  begin
    SetState(vlcError);
    FIsLoading := False;
    HideLoadingAnimationProc;

    // Stop cursor hide timer on error
    FCursorHideTimer.Enabled := False;

    if Assigned(FOnError) then
      FOnError(Self);
  end;
end;

procedure TVlcVisualComponent.Pause;
begin
  if FShutdownMode or (FPlayer = nil) then Exit;
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_pause) then
  begin
    if IsPlaying then
    begin
      T_libvlc_media_player_pause(FPlayer);

      // Show cursor on pause
      ShowCursor;
      FCursorHideTimer.Enabled := False;
    end;
  end;
end;

procedure TVlcVisualComponent.Stop;
begin
  if FShutdownMode then Exit;
  if (csDestroying in ComponentState) then Exit;

  // Stop health monitoring
  if FHealthTimer <> nil then
    FHealthTimer.Enabled := False;

  // Show cursor and stop timer on stop
  ShowCursor;
  FCursorHideTimer.Enabled := False;

  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_stop) then
  begin
    try
      T_libvlc_media_player_stop(FPlayer);
    except
      on E: Exception do
      begin
      end;
    end;
  end;

  if FFrameTimer <> nil then
    FFrameTimer.Enabled := False;

  if FSyncTimer <> nil then
    FSyncTimer.Enabled := False;

  SetState(vlcStopped);
  FIsLoading := False;

  // Clear buffers only on full stop
  ClearVideoBuffer;
end;

procedure TVlcVisualComponent.LoadMedia(const AUrl: string);
var
  Options: TStringList;
  I: Integer;
begin
  if (csDestroying in ComponentState) then
  begin
    Exit;
  end;

  // Reset state for new stream
  ResetStreamState;

  if IsPlaying or IsPaused then
  begin
    Stop;
  end;

  Sleep(100);

  FAudioEnabled := False;
  FVideoStarted := False;
  FBufferValid := False;
  FFrameReady := False;

  SetState(vlcLoading);
  FIsLoading := True;

  ShowLoadingAnimationProc;
  UpdateLoadingStage('Инициализация...');

  if FAnimationTimer <> nil then
    FAnimationTimer.Enabled := True;

  if FFallbackTimer <> nil then
    FFallbackTimer.Enabled := True;

  if not IsInitialized then
  begin
    InitVLC;
  end;

  if not IsInitialized then
  begin
    SetState(vlcError);
    HideLoadingAnimationProc;
    if FFallbackTimer <> nil then
      FFallbackTimer.Enabled := False;
    Exit;
  end;

  if AUrl = '' then
  begin
    SetState(vlcError);
    HideLoadingAnimationProc;
    if FFallbackTimer <> nil then
      FFallbackTimer.Enabled := False;
    Exit;
  end;

  if Assigned(FOnLoading) then
    FOnLoading(Self);

  try
    if FPlayer <> nil then
    begin
      try
        if Assigned(T_libvlc_media_player_stop) then
          T_libvlc_media_player_stop(FPlayer);
        Sleep(100);

        if Assigned(T_libvlc_media_player_release) then
          T_libvlc_media_player_release(FPlayer);
      except
        on E: Exception do
        begin
        end;
      end;
      FPlayer := nil;
    end;

    if FMedia <> nil then
    begin
      try
        if Assigned(T_libvlc_media_release) then
          T_libvlc_media_release(FMedia);
      except
        on E: Exception do
        begin
        end;
      end;
      FMedia := nil;
    end;

    Sleep(100);

    UpdateLoadingStage('Создание медиа...');

    FMediaURL := AUrl;

    if IsNetworkStream(AUrl) then
    begin
      FMedia := T_libvlc_media_new_location(FInstance, PAnsiChar(UTF8Encode(AUrl)));
    end
    else
    begin
      FMedia := T_libvlc_media_new_path(FInstance, PAnsiChar(UTF8Encode(AUrl)));
    end;

    if FMedia = nil then
    begin
      raise Exception.Create('Failed to create media object');
    end;

    if Assigned(T_libvlc_media_add_option) then
    begin
      Options := BuildVlcOptions;
      try
        for I := 0 to Options.Count - 1 do
        begin
          T_libvlc_media_add_option(FMedia, PAnsiChar(UTF8Encode(Options[I])));
        end;
      finally
        Options.Free;
      end;
    end;

    Sleep(100);

    UpdateLoadingStage('Создание плеера...');

    FPlayer := T_libvlc_media_player_new_from_media(FMedia);
    if FPlayer = nil then
    begin
      raise Exception.Create('Failed to create media player');
    end;

    Sleep(50);

    UpdateLoadingStage('Настройка событий...');

    SetupEventHandlers;

    Sleep(50);

    UpdateLoadingStage('Настройка видеовыхода...');

    SetupMemoryRendering;

    // Apply quality settings
    ApplyVideoQualitySettings;

    if FFrameTimer <> nil then
    begin
      FFrameTimer.Enabled := True;
    end;

    // Start stream health monitoring
    StartStreamHealthMonitor;

    if (FPlayer <> nil) and Assigned(T_libvlc_audio_set_mute) then
    begin
      try
        T_libvlc_audio_set_mute(FPlayer, Integer(FMuted));
      except
        on E: Exception do
        begin
        end;
      end;
    end;

    UpdateLoadingStage('Готово к воспроизведению...');

    if FAutoPlay then
    begin
      Sleep(200);
      Play;
    end
    else
    begin
      SetState(vlcPaused);
      UpdateLoadingStage('Готово к воспроизведению');
    end;

  except
    on E: Exception do
    begin
      HandleLoadMediaError(E.Message);
    end;
  end;
end;



procedure TVlcVisualComponent.SeekToPosition(APosition: Single);
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_set_position) then
  begin
    APosition := Max(0, Min(1, APosition));
    T_libvlc_media_player_set_position(FPlayer, APosition);
  end;
end;

procedure TVlcVisualComponent.SeekToTime(ATime: Int64);
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_set_time) then
  begin
    ATime := Max(0, ATime);
    T_libvlc_media_player_set_time(FPlayer, ATime);
  end;
end;

function TVlcVisualComponent.IsInitialized: Boolean;
begin
  Result := (FInstance <> nil);
end;

function TVlcVisualComponent.IsPlaying: Boolean;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_is_playing) then
    Result := (T_libvlc_media_player_is_playing(FPlayer) <> 0)
  else
    Result := FState = vlcPlaying;
end;

function TVlcVisualComponent.IsPaused: Boolean;
begin
  Result := FState = vlcPaused;
end;

function TVlcVisualComponent.IsSeekable: Boolean;
begin
  Result := (FPlayer <> nil) and (GetDuration > 0);
end;

function TVlcVisualComponent.CanPause: Boolean;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_is_playing) then
    Result := IsPlaying
  else
    Result := True;
end;

function TVlcVisualComponent.GetDuration: Int64;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_get_length) then
    Result := T_libvlc_media_player_get_length(FPlayer)
  else
    Result := 0;
end;

function TVlcVisualComponent.GetPosition: Int64;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_get_time) then
    Result := T_libvlc_media_player_get_time(FPlayer)
  else
    Result := 0;
end;

function TVlcVisualComponent.GetPlaybackPosition: Single;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_get_position) then
    Result := T_libvlc_media_player_get_position(FPlayer)
  else
    Result := 0;
end;

function TVlcVisualComponent.GetVideoWidth: Integer;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_video_get_width) then
    Result := T_libvlc_video_get_width(FPlayer)
  else
    Result := FVideoWidth;
end;

function TVlcVisualComponent.GetVideoHeight: Integer;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_video_get_height) then
    Result := T_libvlc_video_get_height(FPlayer)
  else
    Result := FVideoHeight;
end;

function TVlcVisualComponent.HasVideo: Boolean;
begin
  Result := (FVideoWidth > 0) and (FVideoHeight > 0) and
            (FCurrentBitmap <> nil) and not FCurrentBitmap.Empty;
end;

function TVlcVisualComponent.GetPlayerStatus: string;
begin
  case FState of
    vlcIdle: Result := 'Idle';
    vlcLoading: Result := 'Loading';
    vlcPlaying: Result := 'Playing';
    vlcPaused: Result := 'Paused';
    vlcStopped: Result := 'Stopped';
    vlcError: Result := 'Error';
    vlcBuffering: Result := 'Buffering';
  else
    Result := 'Unknown';
  end;
end;

procedure TVlcVisualComponent.AddHttpHeader(const AName, AValue: string);
begin
  if FHttpHeaders <> nil then
    FHttpHeaders.Values[AName] := AValue;
end;

procedure TVlcVisualComponent.ClearHttpHeaders;
begin
  if FHttpHeaders <> nil then
    FHttpHeaders.Clear;
end;

procedure TVlcVisualComponent.SetWinkHeaders;
begin
  FUserAgent := 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
  FReferer := 'https://wink.ru/';
  ClearHttpHeaders;
  AddHttpHeader('Accept', '*/*');
  AddHttpHeader('Accept-Language', 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7');
  AddHttpHeader('Origin', 'https://wink.ru');
end;

procedure TVlcVisualComponent.SetBasicHeaders;
begin
  FUserAgent := 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
  FReferer := '';
  ClearHttpHeaders;
  AddHttpHeader('Accept', '*/*');
  AddHttpHeader('Accept-Language', 'en-US,en;q=0.9');
end;

procedure TVlcVisualComponent.Mute;
begin
  SetMuted(True);
end;

procedure TVlcVisualComponent.Unmute;
begin
  SetMuted(False);
end;

procedure TVlcVisualComponent.ToggleMute;
begin
  SetMuted(not FMuted);
end;

function TVlcVisualComponent.IsMuted: Boolean;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_audio_get_mute) and not FShutdownMode then
  begin
    try
      FMuted := T_libvlc_audio_get_mute(FPlayer) <> 0;
      Result := FMuted;
    except
      Result := FMuted;
    end;
  end
  else
    Result := FMuted;
end;



procedure TVlcVisualComponent.ShowTimeDisplay;
begin
  FShowCurrentTime := True;
  FTimeAutoHide := False; // Disable auto-hide
  FTimeVisible := True;   // Guarantee time is visible
  if FTimeDisplayTimer <> nil then
    FTimeDisplayTimer.Enabled := True;
  Invalidate;
end;

procedure TVlcVisualComponent.HideTimeDisplay;
begin
  FShowCurrentTime := False;
  FTimeVisible := False;
  if FTimeDisplayTimer <> nil then
    FTimeDisplayTimer.Enabled := False;
  Invalidate;
end;

procedure TVlcVisualComponent.ToggleTimeDisplay;
begin
  if FTimeVisible then
    HideTimeDisplay
  else
    ShowTimeDisplay;
end;

procedure TVlcVisualComponent.SetTimeAutoHide(Enabled: Boolean; HideDelay: Integer = 3000);
begin
  FTimeAutoHide := Enabled;
  FTimeAutoHideDelay := HideDelay;

  if Enabled then
  begin
    // When enabling auto-hide, show time immediately
    FTimeVisible := True;
    FShowCurrentTime := True;
    ResetTimeAutoHideTimer;
  end;
end;

procedure TVlcVisualComponent.ShowStatusBar(const AText: string = '');
begin
  if AText <> '' then
    FStatusBarText := AText;

  FStatusBarVisible := True;
  Invalidate;
end;

procedure TVlcVisualComponent.HideStatusBar;
begin
  FStatusBarVisible := False;
  Invalidate;
end;

procedure TVlcVisualComponent.UpdateStatusBar(const AText: string);
begin
  if FStatusBarText <> AText then
  begin
    FStatusBarText := AText;
    if FStatusBarVisible then
      Invalidate;
  end;
end;

procedure TVlcVisualComponent.SetStatusBarStyle(FontSize: Integer; BackgroundColor, TextColor: TColor; CornerRadius: Integer = 8);
begin
  FStatusBarFontSize := FontSize;
  FStatusBarBackground := BackgroundColor;
  FStatusBarTextColor := TextColor;
  FStatusBarCornerRadius := CornerRadius;

  if FStatusBarVisible then
    Invalidate;
end;

function TVlcVisualComponent.BuildVlcOptions: TStringList;
begin
  Result := TStringList.Create;
  try
    // Main options
    Result.Add('--no-video-title-show');
    Result.Add('--quiet');
    Result.Add('--no-stats');

    // HIGH QUALITY SETTINGS
    Result.Add('--avcodec-hw=dxva2');        // Hardware acceleration for Windows
    Result.Add('--avcodec-fast');
    Result.Add('--avcodec-skip-frame=0');    // Don't skip frames
    Result.Add('--avcodec-skip-idct=0');     // Don't skip IDCT
    Result.Add('--avcodec-threads=0');       // Automatic thread count
    Result.Add('--avcodec-fast');            // Fast decoder mode
    Result.Add('--swscale-mode=4');          // High-quality scaling

    // Video quality settings
    Result.Add('--video-filter=deinterlace'); // Deinterlace for better quality
    Result.Add(':deinterlace-mode=blend');    // Blend deinterlace mode
    Result.Add('--sout-x264-preset=fast');    // Fast x264 preset
    Result.Add('--sout-x264-tune=film');      // Film tuning for better quality
    Result.Add('--sout-x264-profile=high');   // High profile

    // Decoder settings for better quality
    Result.Add('--avcodec-skiploopfilter=0'); // Don't skip loop filter
    Result.Add('--avcodec-skipidct=0');       // Don't skip IDCT
    Result.Add('--avcodec-skipframe=0');      // Don't skip frames

    // Network settings for stable streaming
    Result.Add(':network-caching=3000');      // Network cache
    Result.Add(':live-caching=3000');         // Live stream cache
    Result.Add(':file-caching=3000');         // File cache
    Result.Add(':clock-jitter=0');            // Disable jitter
    Result.Add(':clock-synchro=0');           // Disable clock synchronization

    // Prevent frame drops
    Result.Add('--drop-late-frames');         // Drop late frames
    Result.Add('--skip-frames');              // Skip frames when needed

    // HTTP settings
    Result.Add(':http-reconnect');            // Auto-reconnect
    Result.Add(':rtsp-tcp');                  // Force TCP for RTSP
    Result.Add(':tcp-timeout=600000');        // TCP timeout
    Result.Add(':ipv4-timeout=600000');       // IPv4 timeout

    // HTTP headers
    if FUserAgent <> '' then
      Result.Add(':http-user-agent=' + FUserAgent);

    if FReferer <> '' then
      Result.Add(':http-referrer=' + FReferer);

    if FHttpHeaders <> nil then
    begin
      for var I := 0 to FHttpHeaders.Count - 1 do
      begin
        if FHttpHeaders.Names[I] <> '' then
          Result.Add(':http-extra-header=' + FHttpHeaders.Names[I] + ': ' + FHttpHeaders.ValueFromIndex[I]);
      end;
    end;

  except
    Result.Free;
    raise;
  end;
end;

procedure TVlcVisualComponent.InitVLC;
var
  VlcOptions: TStringList;
  VlcArgs: array of PAnsiChar;
  I: Integer;
  LibName: string;
begin
  if FInstance <> nil then
    Exit;

  if FLibPath = '' then
  begin
    LibName := 'libvlc.dll';
  end
  else
    LibName := FLibPath;

  SetDllDirectory(PChar(FLibPath));
  FLibHandle := LoadLibrary('libvlc.dll');
  SetDllDirectory(nil);
  if FLibHandle = 0 then
  begin
    FLibHandle := LoadLibrary(PChar(ExtractFilePath(ParamStr(0)) + LibName));
    if FLibHandle = 0 then
    begin
      Exit;
    end;
  end;

  LoadFunctions;

  VlcOptions := BuildVlcOptions;

  try
    SetLength(VlcArgs, VlcOptions.Count);
    for I := 0 to VlcOptions.Count - 1 do
      VlcArgs[I] := PAnsiChar(UTF8Encode(VlcOptions[I]));

    FInstance := T_libvlc_new(Length(VlcArgs), @VlcArgs[0]);

    if FInstance = nil then
    begin
      if FLibHandle <> 0 then
      begin
        FreeLibrary(FLibHandle);
        FLibHandle := 0;
      end;
    end;

  finally
    VlcOptions.Free;
  end;
end;

procedure TVlcVisualComponent.LoadFunctions;
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
  @T_libvlc_audio_set_volume := GetProcAddress(FLibHandle, 'libvlc_audio_set_volume');
  @T_libvlc_media_add_option := GetProcAddress(FLibHandle, 'libvlc_media_add_option');
  @T_libvlc_media_player_get_length := GetProcAddress(FLibHandle, 'libvlc_media_player_get_length');
  @T_libvlc_media_player_get_time := GetProcAddress(FLibHandle, 'libvlc_media_player_get_time');
  @T_libvlc_media_player_set_time := GetProcAddress(FLibHandle, 'libvlc_media_player_set_time');
  @T_libvlc_media_player_get_position := GetProcAddress(FLibHandle, 'libvlc_media_player_get_position');
  @T_libvlc_media_player_set_position := GetProcAddress(FLibHandle, 'libvlc_media_player_set_position');
  @T_libvlc_event_attach := GetProcAddress(FLibHandle, 'libvlc_event_attach');
  @T_libvlc_media_player_event_manager := GetProcAddress(FLibHandle, 'libvlc_media_player_event_manager');
  @T_libvlc_audio_set_mute := GetProcAddress(FLibHandle, 'libvlc_audio_set_mute');
  @T_libvlc_audio_get_mute := GetProcAddress(FLibHandle, 'libvlc_audio_get_mute');
  @T_libvlc_media_player_is_playing := GetProcAddress(FLibHandle, 'libvlc_media_player_is_playing');
  @T_libvlc_video_set_callbacks := GetProcAddress(FLibHandle, 'libvlc_video_set_callbacks');
  @T_libvlc_video_set_format := GetProcAddress(FLibHandle, 'libvlc_video_set_format');
  @T_libvlc_video_get_width := GetProcAddress(FLibHandle, 'libvlc_video_get_width');
  @T_libvlc_video_get_height := GetProcAddress(FLibHandle, 'libvlc_video_get_height');
  @T_libvlc_video_set_adjust_int := GetProcAddress(FLibHandle, 'libvlc_video_set_adjust_int');
  @T_libvlc_video_set_adjust_float := GetProcAddress(FLibHandle, 'libvlc_video_set_adjust_float');

  if not Assigned(T_libvlc_new) or not Assigned(T_libvlc_media_new_location) then
  begin
    raise Exception.Create('Failed to load VLC functions');
  end;
end;

procedure TVlcVisualComponent.SetupEventHandlers;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_event_manager) then
  begin
    FEventManager := T_libvlc_media_player_event_manager(FPlayer);
    if (FEventManager <> nil) and Assigned(T_libvlc_event_attach) then
    begin
      T_libvlc_event_attach(FEventManager, libvlc_MediaPlayerPlaying, @VlcEventCallback, Self);
      T_libvlc_event_attach(FEventManager, libvlc_MediaPlayerPaused, @VlcEventCallback, Self);
      T_libvlc_event_attach(FEventManager, libvlc_MediaPlayerStopped, @VlcEventCallback, Self);
      T_libvlc_event_attach(FEventManager, libvlc_MediaPlayerEndReached, @VlcEventCallback, Self);
      T_libvlc_event_attach(FEventManager, libvlc_MediaPlayerEncounteredError, @VlcEventCallback, Self);
      T_libvlc_event_attach(FEventManager, libvlc_MediaPlayerBuffering, @VlcEventCallback, Self);
      T_libvlc_event_attach(FEventManager, libvlc_MediaPlayerTimeChanged, @VlcEventCallback, Self);
      T_libvlc_event_attach(FEventManager, libvlc_MediaPlayerPositionChanged, @VlcEventCallback, Self);
      T_libvlc_event_attach(FEventManager, libvlc_MediaPlayerOpening, @VlcEventCallback, Self);
    end;
  end;
end;

procedure TVlcVisualComponent.TryAlternativeFormats;
const
  Formats: array[0..3] of AnsiString = ('RV32', 'RV24', 'I420', 'YUY2');
var
  I: Integer;
begin
  for I := 0 to High(Formats) do
  begin
    try
      T_libvlc_video_set_format(FPlayer, PAnsiChar(Formats[I]),
        FVideoWidth, FVideoHeight, FVideoPitch);
      FVideoChroma := string(Formats[I]);
      Exit;
    except
      on E: Exception do
      begin
      end;
    end;
  end;
end;

procedure TVlcVisualComponent.SetupMemoryRendering;
var
  Chroma: AnsiString;
begin
  if (FPlayer = nil) or not Assigned(T_libvlc_video_set_callbacks) then
  begin
    Exit;
  end;

  // Сначала устанавливаем коллбэки
  T_libvlc_video_set_callbacks(FPlayer,
    @VlcLockCallback,
    @VlcUnlockCallback,
    @VlcDisplayCallback,
    Self);

  // Потом устанавливаем формат видео
  // Используем BGRA - нативный формат для Windows
  Chroma := 'BGRA';
  try
    // Устанавливаем временные размеры
    FVideoWidth := 1280;
    FVideoHeight := 720;
    FVideoPitch := FVideoWidth * 4;
    FVideoPitch := (FVideoPitch + 15) and not 15; // Выравнивание до 16 байт

    T_libvlc_video_set_format(FPlayer, PAnsiChar(Chroma),
      FVideoWidth, FVideoHeight, FVideoPitch);
    FVideoChroma := string(Chroma);
  except
    on E: Exception do
    begin
      // Пробуем другие форматы
      TryAlternativeFormats;
    end;
  end;

  // Выделяем буферы
  AllocateVideoBuffer(FVideoWidth, FVideoHeight);

  if FFrameTimer <> nil then
  begin
    FFrameTimer.Interval := 33; // ~30 FPS
    FFrameTimer.Enabled := True;
  end;
end;

procedure TVlcVisualComponent.SetState(Value: TVlcState);
begin
  if FState <> Value then
  begin
    FState := Value;

    case Value of
      vlcLoading:
        begin
          if Assigned(FOnLoading) then FOnLoading(Self);
        end;
      vlcPlaying:
        begin
          FFrameTimer.Enabled := True;
          if Assigned(FOnPlaying) then FOnPlaying(Self);
        end;
      vlcPaused:
        begin
          FFrameTimer.Enabled := False;
          if Assigned(FOnPaused) then FOnPaused(Self);
        end;
      vlcStopped:
        begin
          FFrameTimer.Enabled := False;
          if Assigned(FOnStopped) then FOnStopped(Self);
        end;
      vlcError:
        begin
          FFrameTimer.Enabled := False;
          if Assigned(FOnError) then FOnError(Self);
        end;
    end;
  end;
end;

function TVlcVisualComponent.IsNetworkStream(const AUrl: string): Boolean;
var
  LowerUrl: string;
begin
  LowerUrl := LowerCase(AUrl);
  Result := (Pos('http://', LowerUrl) = 1) or
            (Pos('https://', LowerUrl) = 1) or
            (Pos('rtsp://', LowerUrl) = 1) or
            (Pos('udp://', LowerUrl) = 1) or
            (Pos('rtmp://', LowerUrl) = 1) or
            (Pos('mms://', LowerUrl) = 1);
end;

procedure TVlcVisualComponent.FallbackTimerTick(Sender: TObject);
begin
  if FShowLoading and FIsLoading then
  begin
    HideLoadingAnimationProc;

    if (FPlayer <> nil) and Assigned(T_libvlc_media_player_is_playing) then
    begin
      if T_libvlc_media_player_is_playing(FPlayer) <> 0 then
      begin
        SetState(vlcPlaying);
        FIsLoading := False;
      end
      else
      begin
        SetState(vlcError);
        FIsLoading := False;
        if Assigned(FOnError) then
          FOnError(Self);
      end;
    end;

    FFallbackTimer.Enabled := False;
  end;
end;

procedure TVlcVisualComponent.SyncTimerTick(Sender: TObject);
var
  AudioTime, VideoTime: Int64;
  TimeDiff: Int64;
const
  SYNC_THRESHOLD = 40; // 40ms threshold
begin
  if not FAudioSyncEnabled or (FPlayer <> nil) or not IsPlaying then
    Exit;

  try
    if Assigned(T_libvlc_media_player_get_time) then
    begin
      AudioTime := T_libvlc_media_player_get_time(FPlayer);
      VideoTime := FLastAudioTime;

      TimeDiff := Abs(AudioTime - VideoTime);

      if TimeDiff > SYNC_THRESHOLD then
      begin
        if AudioTime > VideoTime then
          FFrameTimer.Interval := Max(16, 33 - (TimeDiff div 3))
        else
          FFrameTimer.Interval := Min(50, 33 + (TimeDiff div 3));
      end
      else
      begin
        FFrameTimer.Interval := 33;
      end;

      FLastAudioTime := AudioTime;
    end;
  except
    on E: Exception do
    begin
    end;
  end;
end;

procedure TVlcVisualComponent.HandleLoadMediaError(const ErrorMsg: string);
begin
  if FFallbackTimer <> nil then
    FFallbackTimer.Enabled := False;

  if FAnimationTimer <> nil then
    FAnimationTimer.Enabled := False;

  if FFrameTimer <> nil then
    FFrameTimer.Enabled := False;

  SetState(vlcError);
  FIsLoading := False;
  FAudioEnabled := False;
  FVideoStarted := False;

  HideLoadingAnimationProc;

  if Assigned(FOnError) then
    FOnError(Self);

  if FPlayer <> nil then
  begin
    try
      if Assigned(T_libvlc_media_player_stop) then
        T_libvlc_media_player_stop(FPlayer);
      Sleep(100);
      if Assigned(T_libvlc_media_player_release) then
        T_libvlc_media_player_release(FPlayer);
    except
      on Ex: Exception do
      begin
      end;
    end;
    FPlayer := nil;
  end;

  if FMedia <> nil then
  begin
    try
      if Assigned(T_libvlc_media_release) then
        T_libvlc_media_release(FMedia);
    except
      on Ex: Exception do
      begin
      end;
    end;
    FMedia := nil;
  end;
end;

procedure TVlcVisualComponent.StopVLCPlayback;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_stop) then
  begin
    try
      T_libvlc_media_player_stop(FPlayer);
      Sleep(100);
    except
      on E: Exception do
      begin
      end;
    end;
  end;
end;

procedure TVlcVisualComponent.FreeVLCResources;
begin
  if FPlayer <> nil then
  begin
    try
      if Assigned(T_libvlc_media_player_release) then
      begin
        T_libvlc_media_player_release(FPlayer);
        Sleep(50);
      end;
    except
      on E: Exception do
      begin
      end;
    end;
    FPlayer := nil;
  end;

  if FMedia <> nil then
  begin
    try
      if Assigned(T_libvlc_media_release) then
        T_libvlc_media_release(FMedia);
    except
    end;
    FMedia := nil;
  end;

  if FInstance <> nil then
  begin
    try
      if Assigned(T_libvlc_release) then
        T_libvlc_release(FInstance);
    except
    end;
    FInstance := nil;
  end;

  FEventManager := nil;
end;

procedure TVlcVisualComponent.StopAllTimers;
begin
  // Stream health timer
  try
    if FHealthTimer <> nil then
    begin
      FHealthTimer.Enabled := False;
      FHealthTimer.OnTimer := nil;
    end;
  except
    on E: Exception do
    begin
    end;
  end;

  // Loading animation timer
  try
    if FAnimationTimer <> nil then
    begin
      FAnimationTimer.Enabled := False;
      FAnimationTimer.OnTimer := nil;
    end;
  except
    on E: Exception do
    begin
    end;
  end;

  // Frame update timer
  try
    if FFrameTimer <> nil then
    begin
      FFrameTimer.Enabled := False;
      FFrameTimer.OnTimer := nil;
    end;
  except
    on E: Exception do
    begin
    end;
  end;

  // Fallback timer
  try
    if FFallbackTimer <> nil then
    begin
      FFallbackTimer.Enabled := False;
      FFallbackTimer.OnTimer := nil;
    end;
  except
    on E: Exception do
    begin
    end;
  end;

  // Audio/video sync timer
  try
    if FSyncTimer <> nil then
    begin
      FSyncTimer.Enabled := False;
      FSyncTimer.OnTimer := nil;
    end;
  except
    on E: Exception do
    begin
    end;
  end;

  // Position timer
  try
    if FPositionTimer <> nil then
    begin
      FPositionTimer.Enabled := False;
      FPositionTimer.OnTimer := nil;
    end;
  except
    on E: Exception do
    begin
    end;
  end;

  // Cursor hide timer
  try
    if FCursorHideTimer <> nil then
    begin
      FCursorHideTimer.Enabled := False;
      FCursorHideTimer.OnTimer := nil;
    end;
  except
    on E: Exception do
    begin
    end;
  end;

  // Time display timer
  try
    if FTimeDisplayTimer <> nil then
    begin
      FTimeDisplayTimer.Enabled := False;
      FTimeDisplayTimer.OnTimer := nil;
    end;
  except
    on E: Exception do
    begin
    end;
  end;

  // Time auto-hide timer
  try
    if FTimeAutoHideTimer <> nil then
    begin
      FTimeAutoHideTimer.Enabled := False;
      FTimeAutoHideTimer.OnTimer := nil;
    end;
  except
    on E: Exception do
    begin
    end;
  end;
end;

procedure TVlcVisualComponent.SetupCursorHideTimer;
begin
  FCursorHideTimer := TTimer.Create(Self);
  FCursorHideTimer.Interval := 5000; // Check every 5 seconds
  FCursorHideTimer.OnTimer := CursorHideTimerTick;
  FCursorHideTimer.Enabled := False;
end;

procedure TVlcVisualComponent.CursorHideTimerTick(Sender: TObject);
var
  CurrentTime: Cardinal;
  TimeSinceLastMove: Cardinal;
begin
  if not IsPlaying or FCursorHidden then Exit;

  CurrentTime := GetTickCount;
  TimeSinceLastMove := CurrentTime - FLastMouseMoveTime;

  // Hide cursor if more than 5 seconds without movement
  if TimeSinceLastMove >= 5000 then
  begin
    HideCursor;
  end;
end;

procedure TVlcVisualComponent.HideCursor;
begin
  if not FCursorHidden then
  begin
    Cursor := crNone;
    FCursorHidden := True;
  end;
end;

procedure TVlcVisualComponent.ShowCursor;
begin
  if FCursorHidden then
  begin
    Cursor := crDefault;
    FCursorHidden := False;
  end;
end;

procedure TVlcVisualComponent.ResetCursorTimer;
begin
  FLastMouseMoveTime := GetTickCount;

  // Show cursor immediately on movement
  ShowCursor;
end;

procedure TVlcVisualComponent.SetupTimeDisplayTimer;
begin
  FTimeDisplayTimer := TTimer.Create(Self);
  FTimeDisplayTimer.Interval := 1000; // Update every second
  FTimeDisplayTimer.OnTimer := TimeDisplayTimerTick;
  FTimeDisplayTimer.Enabled := True; // Always enabled if time is shown
end;

procedure TVlcVisualComponent.TimeDisplayTimerTick(Sender: TObject);
begin
  // UPDATE: Update only if time should be visible
  if FShowCurrentTime and not (csDestroying in ComponentState) then
  begin
    // If auto-hide enabled, check visibility
    if FTimeAutoHide and not FTimeVisible then Exit;

    // Just invalidate area for repaint
    Invalidate;
  end;
end;

procedure TVlcVisualComponent.SetupTimeAutoHideTimer;
begin
  FTimeAutoHideTimer := TTimer.Create(Self);
  FTimeAutoHideTimer.Interval := 100; // Check every 100ms
  FTimeAutoHideTimer.OnTimer := TimeAutoHideTimerTick;
  FTimeAutoHideTimer.Enabled := True;
end;

procedure TVlcVisualComponent.TimeAutoHideTimerTick(Sender: TObject);
var
  CurrentTime: Cardinal;
  TimeSinceLastActivity: Cardinal;
begin
  if not FTimeAutoHide or not FTimeVisible then Exit;

  CurrentTime := GetTickCount;
  TimeSinceLastActivity := CurrentTime - FLastActivityTime;

  // Hide time if more than FTimeAutoHideDelay milliseconds have passed
  if TimeSinceLastActivity >= FTimeAutoHideDelay then
  begin
    FTimeVisible := False;
    FTimeDisplayTimer.Enabled := False; // Stop time updates
    Invalidate; // Repaint
  end;
end;

procedure TVlcVisualComponent.ResetTimeAutoHideTimer;
begin
  FLastActivityTime := GetTickCount;

  // Show time if it was hidden
  if not FTimeVisible then
  begin
    FTimeVisible := True;
    FTimeDisplayTimer.Enabled := True; // Start time updates
    Invalidate; // Repaint
  end;
end;

procedure TVlcVisualComponent.ShowTimeTemporarily;
begin
  ResetTimeAutoHideTimer;
end;

procedure TVlcVisualComponent.EnhancedFreeVideoBuffer;
var
  I: Integer;
begin
  if FBufferLock = nil then Exit;

  if FBufferLock.TryEnter then
  try
    for I := 0 to 1 do
    begin
      if (FVideoBuffer[I] <> nil) and (FVideoBufferSize > 0) then
      begin
        try
          FreeMem(FVideoBuffer[I], FVideoBufferSize);
        except
          on E: Exception do
          begin
          end;
        end;
        FVideoBuffer[I] := nil;
      end;
    end;

    if (FBackBuffer <> nil) and (FVideoBufferSize > 0) then
    begin
      try
        FreeMem(FBackBuffer, FVideoBufferSize);
      except
        on E: Exception do
        begin
        end;
      end;
      FBackBuffer := nil;
    end;

    // DON'T reset size - needed for restoration
    // FVideoBufferSize := 0;
    FBufferValid := False;
    FFrameReady := False;

  finally
    FBufferLock.Leave;
  end;
end;

procedure TVlcVisualComponent.StartStreamHealthMonitor;
begin
  if FHealthTimer = nil then
  begin
    FHealthTimer := TTimer.Create(Self);
    FHealthTimer.Interval := 30000; // 30 seconds
    FHealthTimer.OnTimer := HealthCheckTimerTick;
  end;
  FHealthTimer.Enabled := True;
  FStreamStartTime := Now;
end;

procedure TVlcVisualComponent.ForceVideoRecovery;
var
  WasPlaying: Boolean;
begin
  if not IsPlaying then
    Exit;

  WasPlaying := True;

  try
    // Останавливаем воспроизведение
    if Assigned(T_libvlc_media_player_pause) and (FPlayer <> nil) then
    begin
      T_libvlc_media_player_pause(FPlayer);
      Sleep(10);
    end;

    // Очищаем буферы
    EnhancedFreeVideoBuffer;
    Sleep(10);

    // Пересоздаем буферы если есть размеры
    if (FVideoWidth > 0) and (FVideoHeight > 0) then
    begin
      AllocateVideoBuffer(FVideoWidth, FVideoHeight);
    end;

    Sleep(10);

    // Возобновляем воспроизведение
    if WasPlaying and Assigned(T_libvlc_media_player_play) and (FPlayer <> nil) then
    begin
      T_libvlc_media_player_play(FPlayer);
    end;

  except
    on E: Exception do
    begin
    end;
  end;

  SafeInvalidate;
end;

procedure TVlcVisualComponent.HealthCheckTimerTick(Sender: TObject);
var
  CurrentTime: Cardinal;
  TimeSinceLastFrame: Cardinal;
begin
  if not IsPlaying then Exit;

  CurrentTime := GetTickCount;
  TimeSinceLastFrame := CurrentTime - FLastFrameUpdateTime;

  // If no frames for more than 3 seconds during playback
  if (TimeSinceLastFrame > 3000) and (FState = vlcPlaying) then
  begin
    if not FShowLoading then
    begin
      // CHECK BUFFERS
      if not FBufferValid then
      begin
        ForceVideoRecovery;
      end
      else
      begin
        ShowLoadingAnimationProc;
        UpdateLoadingStage('Восстановление...');
      end
    end;
  end;

  // Auto restart
  if FAutoRestartEnabled then
  begin
    var MinutesRunning := MinutesBetween(Now, FStreamStartTime);
    if MinutesRunning >= FAutoRestartInterval then
    begin
      AutoRestartCheck;
    end;
  end;

  CheckMemoryUsage;
end;

procedure TVlcVisualComponent.EmergencyMemoryOptimization;
var
  MemStatus: TMemoryStatusEx;
  TempWidth, TempHeight, CurrentWidth, CurrentHeight: Integer;
  NewWidth, NewHeight: Integer;
  NewInterval: Integer;
begin
  // 1. Временно уменьшаем разрешение битмапа
  if (FCurrentBitmap <> nil) and not FCurrentBitmap.Empty then
  begin
    try
      TempWidth := Max(640, FCurrentBitmap.Width div 2);
      TempHeight := Max(480, FCurrentBitmap.Height div 2);

      if (TempWidth < FCurrentBitmap.Width) or (TempHeight < FCurrentBitmap.Height) then
      begin
        FCurrentBitmap.Width := TempWidth;
        FCurrentBitmap.Height := TempHeight;
      end;
    except
      on E: Exception do
      begin
      end;
    end;
  end;

  // 2. Освобождаем системные ресурсы
  try
    SafeInvalidate;

    // Пересоздаем битмап для освобождения памяти
    if FCurrentBitmap <> nil then
    begin
      CurrentWidth := FCurrentBitmap.Width;
      CurrentHeight := FCurrentBitmap.Height;
      if (CurrentWidth > 0) and (CurrentHeight > 0) then
      begin
        FCurrentBitmap.FreeImage;
        FCurrentBitmap.Width := CurrentWidth;
        FCurrentBitmap.Height := CurrentHeight;
      end;
    end;

  except
    on E: Exception do
    begin
    end;
  end;

  // 3. ПРИНУДИТЕЛЬНОЕ ОСВОБОЖДЕНИЕ ПАМЯТИ WINDOWS
  try
    if SetProcessWorkingSetSize(GetCurrentProcess, SIZE_T(-1), SIZE_T(-1)) then
    else
    begin
    end;

    if FVideoBufferSize > (8 * 1024 * 1024) then
    begin
      ClearVideoBuffer;
    end;

  except
    on E: Exception do
    begin
    end;
  end;

  // 4. УМНАЯ ОПТИМИЗАЦИЯ ВИДЕОБУФЕРОВ
  try
    FillChar(MemStatus, SizeOf(TMemoryStatusEx), 0);
    MemStatus.dwLength := SizeOf(TMemoryStatusEx);

    if GlobalMemoryStatusEx(MemStatus) then
    begin
      if IsPlaying and (FVideoWidth > 0) and (FVideoHeight > 0) then
      begin
        NewWidth := FVideoWidth;
        NewHeight := FVideoHeight;

        if MemStatus.dwMemoryLoad > 95 then
        begin
          NewWidth := Max(640, FVideoWidth div 2);
          NewHeight := Max(480, FVideoHeight div 2);
        end
        else if MemStatus.dwMemoryLoad > 90 then
        begin
          NewWidth := Max(1280, FVideoWidth * 2 div 3);
          NewHeight := Max(720, FVideoHeight * 2 div 3);
        end;

        if (NewWidth <> FVideoWidth) or (NewHeight <> FVideoHeight) then
        begin
          AllocateVideoBuffer(NewWidth, NewHeight);
        end;
      end;
    end;

  except
    on E: Exception do
    begin
    end;
  end;

  // 5. АДАПТИВНОЕ УПРАВЛЕНИЕ FPS
  if FFrameTimer <> nil then
  begin
    FillChar(MemStatus, SizeOf(TMemoryStatusEx), 0);
    MemStatus.dwLength := SizeOf(TMemoryStatusEx);

    if GlobalMemoryStatusEx(MemStatus) then
    begin
      if MemStatus.dwMemoryLoad > 95 then
        NewInterval := 66
      else if MemStatus.dwMemoryLoad > 90 then
        NewInterval := 50
      else
        NewInterval := 33;

      if NewInterval > FFrameTimer.Interval then
      begin
        FFrameTimer.Interval := NewInterval;
      end;
    end;
  end;

  // 6. ОПТИМИЗАЦИЯ НАСТРОЕК VLC
  try
    if (FPlayer <> nil) and not FAdjustedCache then
    begin
      FAdjustedCache := True;
    end;
  except
    on E: Exception do
    begin
    end;
  end;

  // 7. ФИНАЛЬНЫЕ МЕРЫ
  try
    SafeInvalidate;
    Sleep(10);

  except
    on E: Exception do
    begin
    end;
  end;
end;

procedure TVlcVisualComponent.CheckMemoryUsage;
var
  MemStatus: TMemoryStatusEx;
  CurrentTime: Cardinal;
begin
  CurrentTime := GetTickCount;

  if CurrentTime - FLastMemoryCheck < 30000 then Exit;

  MemStatus.dwLength := SizeOf(TMemoryStatusEx);
  GlobalMemoryStatusEx(MemStatus);

  if MemStatus.dwMemoryLoad > 90 then
  begin
    if IsPlaying then
    begin
      EmergencyMemoryOptimization;
    end
    else
    begin
      ClearVideoBuffer;
    end;
  end
  else if MemStatus.dwMemoryLoad > 85 then
  begin
    if IsPlaying then
    begin
      AdjustPerformanceSettings;
    end;
  end
  else if MemStatus.dwMemoryLoad > 80 then
  begin
    if FAdjustedCache then
    begin
      FAdjustedCache := False;
    end;
  end
  else if FAdjustedCache then
  begin
    FAdjustedCache := False;
  end;

  FLastMemoryCheck := CurrentTime;
end;

procedure TVlcVisualComponent.AdjustPerformanceSettings;
begin
  if FAdjustedCache then Exit;

  if FPlayer <> nil then
  begin
    try
      var Options := TStringList.Create;
      try
        Options.Add(':network-caching=3000');
        Options.Add(':live-caching=3000');
        Options.Add(':file-caching=3000');
        Options.Add('--avcodec-skip-frame=3');
        Options.Add('--avcodec-skip-idct=3');
        Options.Add('--avcodec-fast');

        for var I := 0 to Options.Count - 1 do
        begin
          if Assigned(T_libvlc_media_add_option) and (FMedia <> nil) then
            T_libvlc_media_add_option(FMedia, PAnsiChar(UTF8Encode(Options[I])));
        end;

      finally
        Options.Free;
      end;
    except
      on E: Exception do
      begin
      end;
    end;
  end;

  if FCurrentBitmap <> nil then
  begin
    try
      FCurrentBitmap.Dormant;
    except
      on E: Exception do
      begin
      end;
    end;
  end;

  FAdjustedCache := True;
end;

procedure TVlcVisualComponent.AutoRestartCheck;
begin
  if not FAutoRestartEnabled or not IsPlaying then Exit;

  ForceSoftRestart;
end;

procedure TVlcVisualComponent.ForceSoftRestart;
var
  WasPlaying: Boolean;
begin
  WasPlaying := IsPlaying;

  if not WasPlaying then
    Exit;

  try
    if FMediaURL <> '' then
    begin
      var Pos := GetPlaybackPosition;

      Stop;
      Sleep(100);

      LoadMedia(FMediaURL);

      if Pos > 0 then
      begin
        Sleep(300);
        SeekToPosition(Pos);
      end;
    end;

  except
    on E: Exception do
    begin
    end;
  end;
end;

procedure TVlcVisualComponent.ResetPerformanceSettings;
begin
  FAdjustedCache := False;
  if FFrameTimer <> nil then
    FFrameTimer.Interval := 33;
end;

procedure TVlcVisualComponent.EnableAutoRestart(Enabled: Boolean; IntervalMinutes: Integer = 60);
begin
  FAutoRestartEnabled := Enabled;
  FAutoRestartInterval := IntervalMinutes;
end;

procedure TVlcVisualComponent.ResetStreamState;
begin
  FAdjustedCache := False;
  FLastFrameUpdateTime := GetTickCount;
  FStreamStartTime := Now;
end;

// VLC Event Callback
procedure VlcEventCallback(p_event: Pointer; user_data: Pointer); cdecl;
var
  Player: TVlcVisualComponent;
  EventType: Integer;
begin
  if (user_data = nil) or (p_event = nil) then
    Exit;

  if (GDestroyedPlayers <> nil) and GDestroyedPlayers.Contains(user_data) then
    Exit;

  Player := TVlcVisualComponent(user_data);

  try
    EventType := PInteger(p_event)^;

    case EventType of
      libvlc_MediaPlayerPlaying:
        begin
          Player.FState := vlcPlaying;
          Player.FIsLoading := False;
        end;

      libvlc_MediaPlayerTimeChanged:
        begin
          Player.FLastAudioTime := Player.GetPosition;
        end;

      libvlc_MediaPlayerEncounteredError:
        begin
          if Player.HandleAllocated then
            PostMessage(Player.Handle, WM_USER + 200, EventType, 0);
        end;
    end;

  except
  end;
end;

function VlcLockCallback(opaque: Pointer; planes: PPointer): Pointer; cdecl;
begin
  Result := TVlcVisualComponent(opaque).LockCallback(opaque, planes);
end;

procedure VlcUnlockCallback(opaque: Pointer; picture: Pointer; planes: PPointer); cdecl;
begin
  TVlcVisualComponent(opaque).UnlockCallback(opaque, picture, planes);
end;

procedure VlcDisplayCallback(opaque: Pointer; picture: Pointer); cdecl;
begin
  // Not used in this implementation
end;

procedure Register;
begin
  RegisterComponents('VLC Components', [TVlcVisualComponent]);
end;

initialization
  GDestroyedPlayers := TList<Pointer>.Create;

finalization
  if GDestroyedPlayers <> nil then
  begin
    GDestroyedPlayers.Free;
    GDestroyedPlayers := nil;
  end;

end.
