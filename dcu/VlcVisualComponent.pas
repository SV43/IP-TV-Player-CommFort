unit VlcVisualComponent;

interface

uses
  Windows, Messages, SysUtils, Classes, Vcl.StdCtrls, Vcl.ExtCtrls, TypInfo,
  Vcl.Graphics, Vcl.Controls, Vcl.Imaging.pngimage, Math, Vcl.Imaging.jpeg,
  Vcl.Menus, SyncObjs, DateUtils, Vcl.Forms, Winapi.MMSystem, System.StrUtils,
  System.Generics.Collections, System.Types, System.UITypes;

type
  TVlcState = (vlcIdle, vlcLoading, vlcPlaying, vlcPaused, vlcStopped, vlcError, vlcBuffering);

  TVlcNotifyEvent = procedure(Sender: TObject) of object;
  TVlcErrorEvent = procedure(Sender: TObject; ErrorCode: Integer; const ErrorMessage: string) of object;
  TVlcMouseEvent = procedure(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer) of object;
  TVlcMouseMoveEvent = procedure(Sender: TObject; Shift: TShiftState; X, Y: Integer) of object;
  TVlcLogEvent = procedure(Sender: TObject; const Msg: string) of object;
  TVlcProgressEvent = procedure(Sender: TObject; Progress: Integer) of object;
  TVlcPositionEvent = procedure(Sender: TObject; Position: Single) of object;
  TVlcTimeEvent = procedure(Sender: TObject; Time: Int64) of object;
  TVlcMouseWheelEvent = procedure(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint) of object;

  Plibvlc_instance_t = Pointer;
  Plibvlc_media_t = Pointer;
  Plibvlc_media_player_t = Pointer;
  Plibvlc_event_manager_t = Pointer;

  TLockCallback = function(opaque: Pointer; planes: PPointer): Pointer; cdecl;
  TUnlockCallback = procedure(opaque: Pointer; picture: Pointer; planes: PPointer); cdecl;
  TDisplayCallback = procedure(opaque: Pointer; picture: Pointer); cdecl;
  TVlcEventCallback = procedure(p_event: Pointer; user_data: Pointer); cdecl;

  TVlcPlayer = class(TCustomPanel)
  private
    FLibPath: string;
    FLibHandle: THandle;
    FInstance: Plibvlc_instance_t;
    FMedia: Plibvlc_media_t;
    FPlayer: Plibvlc_media_player_t;
    FEventManager: Plibvlc_event_manager_t;

    FState: TVlcState;
    FMediaURL: string;
    FVolume: Integer;
    FAutoPlay: Boolean;
    FUserAgent: string;
    FReferer: string;
    FHttpHeaders: TStringList;
    FMuted: Boolean;
    FLoopPlayback: Boolean;
    FHighQuality: Boolean;

    FVideoWidth: Integer;
    FVideoHeight: Integer;
    FVideoPitch: Integer;
    FVideoBuffer: array[0..1] of Pointer;
    FCurrentBuffer: Integer;
    FBackBuffer: Pointer;
    FVideoBufferSize: Cardinal;
    FVideoBitmap: TBitmap;
    FFrameReady: Boolean;
    FFrameLock: TCriticalSection;
    FBufferValid: Boolean;

    FFrameTimer: TTimer;
    FPositionTimer: TTimer;
    FHealthTimer: TTimer;
    FSyncTimer: TTimer;
    FFallbackTimer: TTimer;

    FOriginalWndProc: TWndMethod;
    FMouseCapture: Boolean;
    FLastMouseMoveTime: Cardinal;

    FLastFrameTime: Cardinal;
    FFrameCount: Integer;
    FLastFpsTime: Cardinal;
    FCurrentFPS: Integer;
    FTargetFPS: Integer;

    FAudioSyncEnabled: Boolean;
    FLastAudioTime: Int64;
    FAudioDelay: Integer;

    FAdjustedCache: Boolean;
    FAutoRestartEnabled: Boolean;
    FAutoRestartInterval: Integer;
    FLastFrameUpdateTime: Cardinal;
    FLastMemoryCheck: Cardinal;
    FStreamStartTime: TDateTime;

    FShowLoading: Boolean;
    FFirstFrameTime: Cardinal;
    FAnimationHideDelay: Integer;
    FLoadingStage: string;

    FStatusBarVisible: Boolean;
    FStatusBarText: string;
    FStatusBarFontSize: Integer;
    FStatusBarBackground: TColor;
    FStatusBarTextColor: TColor;
    FStatusBarCornerRadius: Integer;

    FTempRestartURL: string;
    FTempRestartPosition: Single;

    FAudioEnabled: Boolean;
    FVideoStarted: Boolean;
    FIsLoading: Boolean;
    FShutdownMode: Boolean;

    FDisplayText: string;
    FDisplayTextVisible: Boolean;
    FDisplayTextFontSize: Integer;
    FDisplayTextColor: TColor;
    FDisplayTextBackground: TColor;
    FDisplayTextBackgroundAlpha: Integer;
    FDisplayTextCornerRadius: Integer;

    FShowTopImage: Boolean;
    FTopImage: TPNGImage;
    FTopImagePath: string;
    FTopImageWidth: Integer;
    FTopImageHeight: Integer;
    FTopImageMargin: Integer;

    T_libvlc_new: function(argc: Integer; argv: PPAnsiChar): Plibvlc_instance_t; cdecl;
    T_libvlc_release: procedure(p_instance: Plibvlc_instance_t); cdecl;
    T_libvlc_media_new_location: function(p_instance: Plibvlc_instance_t; psz_mrl: PAnsiChar): Plibvlc_media_t; cdecl;
    T_libvlc_media_new_path: function(p_instance: Plibvlc_instance_t; path: PAnsiChar): Plibvlc_media_t; cdecl;
    T_libvlc_media_release: procedure(p_media: Plibvlc_media_t); cdecl;
    T_libvlc_media_player_new_from_media: function(p_media: Plibvlc_media_t): Plibvlc_media_player_t; cdecl;
    T_libvlc_media_player_release: procedure(p_player: Plibvlc_media_player_t); cdecl;
    T_libvlc_media_player_play: function(p_player: Plibvlc_media_player_t): Integer; cdecl;
    T_libvlc_media_player_pause: procedure(p_player: Plibvlc_media_player_t); cdecl;
    T_libvlc_media_player_stop: procedure(p_player: Plibvlc_media_player_t); cdecl;
    T_libvlc_audio_set_volume: procedure(p_player: Plibvlc_media_player_t; volume: Integer); cdecl;
    T_libvlc_media_add_option: procedure(p_media: Plibvlc_media_t; psz_options: PAnsiChar); cdecl;
    T_libvlc_media_player_get_time: function(p_player: Plibvlc_media_player_t): Int64; cdecl;
    T_libvlc_media_player_set_time: procedure(p_player: Plibvlc_media_player_t; time: Int64); cdecl;
    T_libvlc_media_player_get_position: function(p_player: Plibvlc_media_player_t): Single; cdecl;
    T_libvlc_media_player_set_position: procedure(p_player: Plibvlc_media_player_t; position: Single); cdecl;
    T_libvlc_event_attach: procedure(p_event_manager: Plibvlc_event_manager_t; event_type: Integer; callback: TVlcEventCallback; user_data: Pointer); cdecl;
    T_libvlc_media_player_event_manager: function(p_player: Plibvlc_media_player_t): Plibvlc_event_manager_t; cdecl;
    T_libvlc_audio_set_mute: procedure(p_player: Plibvlc_media_player_t; status: Integer); cdecl;
    T_libvlc_audio_get_mute: function(p_player: Plibvlc_media_player_t): Integer; cdecl;
    T_libvlc_media_player_is_playing: function(p_player: Plibvlc_media_player_t): Integer; cdecl;
    T_libvlc_video_set_callbacks: procedure(p_player: Plibvlc_media_player_t; lock: TLockCallback;
      unlock: TUnlockCallback; display: TDisplayCallback; opaque: Pointer); cdecl;
    T_libvlc_video_set_format: procedure(p_player: Plibvlc_media_player_t; chroma: PAnsiChar;
      width, height: Cardinal; pitch: Cardinal); cdecl;
    T_libvlc_video_get_size: function(p_player: Plibvlc_media_player_t; num: Integer; var px, py: Cardinal): Integer; cdecl;
    T_libvlc_media_player_set_hwnd: procedure(p_player: Plibvlc_media_player_t; drawable: Pointer); cdecl;
    T_libvlc_media_player_get_length: function(p_player: Plibvlc_media_player_t): Int64; cdecl;

    FOnPlaying: TVlcNotifyEvent;
    FOnPaused: TVlcNotifyEvent;
    FOnStopped: TVlcNotifyEvent;
    FOnEndReached: TVlcNotifyEvent;
    FOnError: TVlcErrorEvent;
    FOnStateChanged: TVlcNotifyEvent;
    FOnLog: TVlcLogEvent;
    FOnLoading: TVlcNotifyEvent;
    FOnLoadingProgress: TVlcProgressEvent;
    FOnBuffering: TVlcProgressEvent;
    FOnPositionChanged: TVlcPositionEvent;
    FOnTimeChanged: TVlcTimeEvent;
    FOnVideoStarted: TVlcNotifyEvent;
    FOnVideoSizeChanged: TVlcNotifyEvent;

    FOnVideoMouseDown: TVlcMouseEvent;
    FOnVideoMouseUp: TVlcMouseEvent;
    FOnVideoMouseMove: TVlcMouseMoveEvent;
    FOnVideoClick: TVlcNotifyEvent;
    FOnVideoDblClick: TVlcNotifyEvent;
    FOnVideoMouseWheel: TVlcMouseWheelEvent;

    procedure HandlePlayingEvent;
    procedure HandlePausedEvent;
    procedure HandleStoppedEvent;
    procedure HandleEndReachedEvent;
    procedure HandleErrorEvent;
    procedure HandleBufferingEvent;
    procedure HandleOpeningEvent;
    procedure HandleTimeChangedEvent;
    procedure HandlePositionChangedEvent;

    procedure SetMediaURL(const Value: string);
    procedure SetVolume(Value: Integer);
    procedure SetMuted(const Value: Boolean);
    procedure SetLibPath(const Value: string);
    procedure SetLoopPlayback(const Value: Boolean);
    procedure SetHighQuality(const Value: Boolean);
    procedure SetUserAgent(const Value: string);
    procedure SetReferer(const Value: string);
    procedure SetHttpHeaders(const Value: TStringList);
    function GetMuted: Boolean;
    function GetPlaying: Boolean;
    function GetPaused: Boolean;
    function GetStopped: Boolean;
    function GetPosition: Int64;
    function GetPlaybackPosition: Single;

    procedure SetStatusBarVisible(const Value: Boolean);
    procedure SetStatusBarText(const Value: string);
    procedure SetStatusBarFontSize(const Value: Integer);
    procedure SetStatusBarBackground(const Value: TColor);
    procedure SetStatusBarTextColor(const Value: TColor);
    procedure SetStatusBarCornerRadius(const Value: Integer);

    procedure SetShowTopImage(const Value: Boolean);
    procedure SetTopImagePath(const Value: string);
    procedure SetTopImageWidth(const Value: Integer);
    procedure SetTopImageHeight(const Value: Integer);
    procedure SetTopImageMargin(const Value: Integer);

    procedure UpdateVideoSize(Width, Height: Integer);
    procedure SetupMemoryRendering;
    procedure GetVideoSize(var Width, Height: Integer);
    procedure AllocateVideoBuffer(Width, Height: Integer);
    procedure SwapBuffers;
    procedure ClearVideoBuffer;
    procedure UpdateBitmapFromBuffer;
    procedure CalculateFPS;

    procedure InitVLC;
    procedure LoadFunctions;
    procedure FreeVLC;
    procedure SetState(Value: TVlcState);
    function BuildVlcOptions: TStringList;
    procedure SetupEventHandlers;
    procedure TryAlternativeFormats;

    function LockCallback(opaque: Pointer; planes: PPointer): Pointer; cdecl;
    procedure UnlockCallback(opaque: Pointer; picture: Pointer; planes: PPointer); cdecl;

    procedure FrameTimerTick(Sender: TObject);
    procedure PositionTimerTick(Sender: TObject);
    procedure HealthCheckTimerTick(Sender: TObject);
    procedure SyncTimerTick(Sender: TObject);
    procedure FallbackTimerTick(Sender: TObject);

    procedure MainWndProc(var Message: TMessage);
    function GetShiftState: TShiftState;

    procedure SafeInvalidate;
    procedure DrawLoadingAnimation(Canvas: TCanvas);
    procedure DrawStatusBar(Canvas: TCanvas);
    procedure DrawDisplayText(Canvas: TCanvas);
    procedure DrawTopImage(Canvas: TCanvas);
    function CalculateAspectRatioFit: TRect;

    function IsNetworkStream(const AUrl: string): Boolean;
    procedure EnableAudio;
    procedure ForceVideoUpdate;
    procedure LoadTopImage;

    procedure StartStreamHealthMonitor;
    procedure CheckMemoryUsage;
    procedure AdjustPerformanceSettings;
    procedure AutoRestartCheck;
    procedure EnhancedFreeVideoBuffer;
    procedure ResetStreamState;
    procedure ForceVideoRecovery;
    procedure EmergencyMemoryOptimization;

    procedure StopAllTimers;
    procedure StopVLCPlayback;
    procedure FreeVLCResources;

  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure DblClick; override;
    procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint);

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Play;
    procedure Pause;
    procedure Stop;
    procedure LoadMedia(const AUrl: string);

    procedure SetDisplayText(const Value: string);
    procedure SetDisplayTextVisible(const Value: Boolean);
    procedure SetDisplayTextFontSize(const Value: Integer);
    procedure SetDisplayTextColor(const Value: TColor);
    procedure SetDisplayTextBackground(const Value: TColor);
    procedure SetDisplayTextBackgroundAlpha(const Value: Integer);
    procedure SetDisplayTextCornerRadius(const Value: Integer);

    function IsInitialized: Boolean;
    function IsPlaying: Boolean;
    function IsPaused: Boolean;
    function IsSeekable: Boolean;
    function CanPause: Boolean;
    function GetDuration: Int64;
    function GetVideoWidth: Integer;
    function GetVideoHeight: Integer;
    function HasVideo: Boolean;
    function GetPlayerStatus: string;

    // Новый метод для получения текущего URL медиа
    function GetCurrentMediaURL: string;

    procedure Mute;
    procedure Unmute;
    procedure ToggleMute;
    function IsMuted: Boolean;

    procedure SeekTo(Position: Single);
    procedure SeekToTime(TimeMs: Int64);

    procedure AddHttpHeader(const AName, AValue: string);
    procedure ClearHttpHeaders;
    procedure SetWinkHeaders;
    procedure SetBasicHeaders;

    procedure EnableAudioSync(Enabled: Boolean);
    procedure SetAudioDelay(DelayMs: Integer);
    procedure SetTargetFPS(FPS: Integer);
    function GetCurrentFPS: Integer;
    procedure EnableHighPerformanceMode(Enabled: Boolean);
    procedure ClearBuffer;

    procedure EnableAutoRestart(Enabled: Boolean; IntervalMinutes: Integer = 60);
    procedure ForceSoftRestart;
    procedure ResetPerformanceSettings;

    procedure ShowStatusBar(const AText: string = '');
    procedure HideStatusBar;
    procedure UpdateStatusBar(const AText: string);
    procedure SetStatusBarStyle(FontSize: Integer; BackgroundColor, TextColor: TColor; CornerRadius: Integer = 8);

    procedure ShowDisplayText(const AText: string = '');
    procedure HideDisplayText;
    procedure SetDisplayTextStyle(FontSize: Integer; TextColor, BackgroundColor: TColor;
      BackgroundAlpha: Integer = 180; CornerRadius: Integer = 8);

    procedure SetTopImage(const AImagePath: string; Show: Boolean = True);
    procedure HideTopImage;

    procedure TakeSnapshot(const AFileName: string);

    procedure ForceRepaint;

    property State: TVlcState read FState;
    property Muted: Boolean read GetMuted write SetMuted;
    property Playing: Boolean read GetPlaying;
    property Paused: Boolean read GetPaused;
    property Stopped: Boolean read GetStopped;
    property Position: Int64 read GetPosition;
    property PlaybackPosition: Single read GetPlaybackPosition;
    property VideoBitmap: TBitmap read FVideoBitmap;

  published
    property LibPath: string read FLibPath write SetLibPath;
    property MediaURL: string read FMediaURL write SetMediaURL;
    // Свойство для получения текущего URL медиа
    property CurrentMediaURL: string read GetCurrentMediaURL;
    property AutoPlay: Boolean read FAutoPlay write FAutoPlay default True;
    property Volume: Integer read FVolume write SetVolume default 100;
    property UserAgent: string read FUserAgent write SetUserAgent;
    property Referer: string read FReferer write SetReferer;
    property HttpHeaders: TStringList read FHttpHeaders write SetHttpHeaders;
    property LoopPlayback: Boolean read FLoopPlayback write SetLoopPlayback default False;
    property HighQuality: Boolean read FHighQuality write SetHighQuality default True;

    property AutoRestartEnabled: Boolean read FAutoRestartEnabled write FAutoRestartEnabled default False;
    property AutoRestartInterval: Integer read FAutoRestartInterval write FAutoRestartInterval default 60;

    property StatusBarVisible: Boolean read FStatusBarVisible write SetStatusBarVisible;
    property StatusBarText: string read FStatusBarText write SetStatusBarText;
    property StatusBarFontSize: Integer read FStatusBarFontSize write SetStatusBarFontSize;
    property StatusBarBackground: TColor read FStatusBarBackground write SetStatusBarBackground;
    property StatusBarTextColor: TColor read FStatusBarTextColor write SetStatusBarTextColor;
    property StatusBarCornerRadius: Integer read FStatusBarCornerRadius write SetStatusBarCornerRadius;

    property DisplayText: string read FDisplayText write SetDisplayText;
    property DisplayTextVisible: Boolean read FDisplayTextVisible write SetDisplayTextVisible;
    property DisplayTextFontSize: Integer read FDisplayTextFontSize write SetDisplayTextFontSize;
    property DisplayTextColor: TColor read FDisplayTextColor write SetDisplayTextColor;
    property DisplayTextBackground: TColor read FDisplayTextBackground write SetDisplayTextBackground;
    property DisplayTextBackgroundAlpha: Integer read FDisplayTextBackgroundAlpha write SetDisplayTextBackgroundAlpha;
    property DisplayTextCornerRadius: Integer read FDisplayTextCornerRadius write SetDisplayTextCornerRadius;

    property ShowTopImage: Boolean read FShowTopImage write SetShowTopImage;
    property TopImagePath: string read FTopImagePath write SetTopImagePath;
    property TopImageWidth: Integer read FTopImageWidth write SetTopImageWidth;
    property TopImageHeight: Integer read FTopImageHeight write SetTopImageHeight;
    property TopImageMargin: Integer read FTopImageMargin write SetTopImageMargin;

    property OnLoading: TVlcNotifyEvent read FOnLoading write FOnLoading;
    property OnPlaying: TVlcNotifyEvent read FOnPlaying write FOnPlaying;
    property OnPaused: TVlcNotifyEvent read FOnPaused write FOnPaused;
    property OnStopped: TVlcNotifyEvent read FOnStopped write FOnStopped;
    property OnEndReached: TVlcNotifyEvent read FOnEndReached write FOnEndReached;
    property OnError: TVlcErrorEvent read FOnError write FOnError;
    property OnStateChanged: TVlcNotifyEvent read FOnStateChanged write FOnStateChanged;
    property OnLog: TVlcLogEvent read FOnLog write FOnLog;
    property OnLoadingProgress: TVlcProgressEvent read FOnLoadingProgress write FOnLoadingProgress;
    property OnBuffering: TVlcProgressEvent read FOnBuffering write FOnBuffering;
    property OnPositionChanged: TVlcPositionEvent read FOnPositionChanged write FOnPositionChanged;
    property OnTimeChanged: TVlcTimeEvent read FOnTimeChanged write FOnTimeChanged;
    property OnVideoStarted: TVlcNotifyEvent read FOnVideoStarted write FOnVideoStarted;
    property OnVideoSizeChanged: TVlcNotifyEvent read FOnVideoSizeChanged write FOnVideoSizeChanged;

    property OnVideoMouseDown: TVlcMouseEvent read FOnVideoMouseDown write FOnVideoMouseDown;
    property OnVideoMouseUp: TVlcMouseEvent read FOnVideoMouseUp write FOnVideoMouseUp;
    property OnVideoMouseMove: TVlcMouseMoveEvent read FOnVideoMouseMove write FOnVideoMouseMove;
    property OnVideoClick: TVlcNotifyEvent read FOnVideoClick write FOnVideoClick;
    property OnVideoDblClick: TVlcNotifyEvent read FOnVideoDblClick write FOnVideoDblClick;
    property OnVideoMouseWheel: TVlcMouseWheelEvent read FOnVideoMouseWheel write FOnVideoMouseWheel;

    property Align;
    property Anchors;
    property Color;
    property Constraints;
    property Ctl3D;
    property DoubleBuffered;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Font;
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
    property Visible;
    property OnClick;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDock;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
  end;

procedure Register;

implementation

uses
  System.AnsiStrings;

const
  libvlc_MediaPlayerPlaying = 0;
  libvlc_MediaPlayerPaused = 1;
  libvlc_MediaPlayerStopped = 2;
  libvlc_MediaPlayerEndReached = 3;
  libvlc_MediaPlayerEncounteredError = 4;
  libvlc_MediaPlayerTimeChanged = 5;
  libvlc_MediaPlayerPositionChanged = 6;
  libvlc_MediaPlayerVideoSizeChanged = 7;
  libvlc_MediaPlayerBuffering = 27;
  libvlc_MediaPlayerOpening = 28;

var
  GDestroyedPlayers: TList<TVlcPlayer>;

procedure VlcEventCallback(p_event: Pointer; user_data: Pointer); cdecl; forward;
function VlcLockCallback(opaque: Pointer; planes: PPointer): Pointer; cdecl; forward;
procedure VlcUnlockCallback(opaque: Pointer; picture: Pointer; planes: PPointer); cdecl; forward;
procedure VlcDisplayCallback(opaque: Pointer; picture: Pointer); cdecl; forward;

{ TVlcPlayer }

constructor TVlcPlayer.Create(AOwner: TComponent);
var
  I: Integer;
begin
  inherited Create(AOwner);

  Width := 320;
  Height := 240;
  Color := clBlack;
  BevelOuter := bvNone;
  DoubleBuffered := True;
  ParentBackground := False;

  FLibPath := 'libvlc.dll';
  FHttpHeaders := TStringList.Create;
  FAutoPlay := True;
  FVolume := 100;
  FState := vlcIdle;
  FMuted := False;
  FLoopPlayback := False;
  FHighQuality := True;

  for I := 0 to 1 do
    FVideoBuffer[I] := nil;
  FBackBuffer := nil;

  FVideoWidth := 0;
  FVideoHeight := 0;
  FVideoPitch := 0;
  FVideoBufferSize := 0;
  FCurrentBuffer := 0;
  FFrameReady := False;
  FBufferValid := False;

  FLastFrameTime := 0;
  FFrameCount := 0;
  FLastFpsTime := 0;
  FCurrentFPS := 0;
  FTargetFPS := 30;

  FAdjustedCache := False;
  FAutoRestartEnabled := False;
  FAutoRestartInterval := 60;
  FLastFrameUpdateTime := 0;
  FLastMemoryCheck := 0;
  FStreamStartTime := 0;

  FShowLoading := False;
  FFirstFrameTime := 0;
  FAnimationHideDelay := 1000;
  FLoadingStage := 'Подключение...';

  FAudioSyncEnabled := True;
  FLastAudioTime := 0;
  FAudioDelay := 0;

  FStatusBarVisible := False;
  FStatusBarText := '';
  FStatusBarFontSize := 12;
  FStatusBarBackground := clBlack;
  FStatusBarTextColor := clWhite;
  FStatusBarCornerRadius := 4;

  FDisplayText := '';
  FDisplayTextVisible := False;
  FDisplayTextFontSize := 14;
  FDisplayTextColor := clWhite;
  FDisplayTextBackground := clBlack;
  FDisplayTextBackgroundAlpha := 180;
  FDisplayTextCornerRadius := 8;

  FShowTopImage := False;
  FTopImage := TPNGImage.Create;
  FTopImagePath := '';
  FTopImageWidth := 45;
  FTopImageHeight := 45;
  FTopImageMargin := 10;

  FTempRestartURL := '';
  FTempRestartPosition := 0;

  FAudioEnabled := False;
  FVideoStarted := False;
  FIsLoading := False;
  FShutdownMode := False;

  FOriginalWndProc := nil;
  FMouseCapture := False;
  FLastMouseMoveTime := 0;

  FFrameLock := TCriticalSection.Create;

  FVideoBitmap := TBitmap.Create;
  FVideoBitmap.PixelFormat := pf32bit;
  FVideoBitmap.Width := 1;
  FVideoBitmap.Height := 1;

  FFrameTimer := TTimer.Create(Self);
  FFrameTimer.Interval := 33;
  FFrameTimer.OnTimer := FrameTimerTick;
  FFrameTimer.Enabled := False;

  FPositionTimer := TTimer.Create(Self);
  FPositionTimer.Interval := 200;
  FPositionTimer.OnTimer := PositionTimerTick;
  FPositionTimer.Enabled := False;

  FHealthTimer := TTimer.Create(Self);
  FHealthTimer.Interval := 30000;
  FHealthTimer.OnTimer := HealthCheckTimerTick;
  FHealthTimer.Enabled := False;

  FSyncTimer := TTimer.Create(Self);
  FSyncTimer.Interval := 100;
  FSyncTimer.OnTimer := SyncTimerTick;
  FSyncTimer.Enabled := False;

  FFallbackTimer := TTimer.Create(Self);
  FFallbackTimer.Interval := 15000;
  FFallbackTimer.OnTimer := FallbackTimerTick;
  FFallbackTimer.Enabled := False;

  SetBasicHeaders;
end;

destructor TVlcPlayer.Destroy;
begin
  FShutdownMode := True;

  StopAllTimers;

  StopVLCPlayback;

  FreeVLCResources;

  EnhancedFreeVideoBuffer;

  FreeAndNil(FHttpHeaders);
  FreeAndNil(FVideoBitmap);
  FreeAndNil(FFrameLock);

  FreeAndNil(FTopImage);

  FreeAndNil(FHealthTimer);
  FreeAndNil(FFrameTimer);
  FreeAndNil(FPositionTimer);
  FreeAndNil(FSyncTimer);
  FreeAndNil(FFallbackTimer);

  inherited Destroy;
end;

procedure TVlcPlayer.HandlePlayingEvent;
begin
  if (csDestroying in ComponentState) then Exit;

  if not FAudioEnabled then
    EnableAudio();

  SetState(vlcPlaying);
  FIsLoading := False;
  FShowLoading := False;

  if FSyncTimer <> nil then
    FSyncTimer.Enabled := True;

  if Assigned(FOnVideoStarted) then
    FOnVideoStarted(Self);

  if Assigned(FOnPlaying) then
    FOnPlaying(Self);
end;

procedure TVlcPlayer.HandlePausedEvent;
begin
  if (csDestroying in ComponentState) then Exit;

  SetState(vlcPaused);

  if FSyncTimer <> nil then
    FSyncTimer.Enabled := False;

  if Assigned(FOnPaused) then
    FOnPaused(Self);
end;

procedure TVlcPlayer.HandleStoppedEvent;
begin
  if (csDestroying in ComponentState) then Exit;

  if FSyncTimer <> nil then
    FSyncTimer.Enabled := False;

  SetState(vlcStopped);
  FIsLoading := False;
  FShowLoading := False;

  if Assigned(FOnStopped) then
    FOnStopped(Self);
end;

procedure TVlcPlayer.HandleEndReachedEvent;
begin
  if (csDestroying in ComponentState) then Exit;

  if FLoopPlayback then
  begin
    FFirstFrameTime := 0;
    SeekTo(0);
    Sleep(100);
    Play;
  end
  else
  begin
    if Assigned(FOnEndReached) then
      FOnEndReached(Self);
  end;
end;

procedure TVlcPlayer.HandleErrorEvent;
begin
  if (csDestroying in ComponentState) then Exit;

  if FSyncTimer <> nil then
    FSyncTimer.Enabled := False;

  SetState(vlcError);
  FIsLoading := False;
  FShowLoading := False;

  if Assigned(FOnError) then
      FOnError(Self, -1, 'VLC error event');
end;

procedure TVlcPlayer.HandleBufferingEvent;
begin
  if (csDestroying in ComponentState) then Exit;

  SetState(vlcBuffering);

  if not FShowLoading then
  begin
    FShowLoading := True;
    Invalidate;
  end;

  if Assigned(FOnBuffering) then
    FOnBuffering(Self, 0);
end;

procedure TVlcPlayer.HandleOpeningEvent;
begin
  if (csDestroying in ComponentState) then Exit;

  SetState(vlcLoading);
  FIsLoading := True;
  FFirstFrameTime := 0;

  FShowLoading := True;
  Invalidate;
end;

procedure TVlcPlayer.HandleTimeChangedEvent;
begin
  if (csDestroying in ComponentState) then Exit;

  FLastAudioTime := GetPosition;

  if Assigned(FOnTimeChanged) then
    FOnTimeChanged(Self, FLastAudioTime);
end;

procedure TVlcPlayer.HandlePositionChangedEvent;
begin
  if (csDestroying in ComponentState) then Exit;

  if Assigned(FOnPositionChanged) then
    FOnPositionChanged(Self, GetPlaybackPosition);
end;

function TVlcPlayer.IsPlaying: Boolean;
begin
  Result := FState = vlcPlaying;
end;

function TVlcPlayer.IsPaused: Boolean;
begin
  Result := FState = vlcPaused;
end;

procedure TVlcPlayer.SetLibPath(const Value: string);
begin
  if FLibPath <> Value then
  begin
    FLibPath := Value;
    if IsInitialized then
    begin
      FreeVLC;
      InitVLC;
    end;
  end;
end;

procedure TVlcPlayer.SetMediaURL(const Value: string);
begin
  if FMediaURL <> Value then
  begin
    FMediaURL := Value;
    if (Value <> '') and not (csLoading in ComponentState) then
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

    if Assigned(FPlayer) and Assigned(T_libvlc_audio_set_volume) and not FShutdownMode then
    begin
      try
        T_libvlc_audio_set_volume(FPlayer, Value);
      except
      end;
    end;
  end;
end;

procedure TVlcPlayer.SetMuted(const Value: Boolean);
begin
  if FMuted <> Value then
  begin
    FMuted := Value;

    if Assigned(FPlayer) and Assigned(T_libvlc_audio_set_mute) and not FShutdownMode then
    begin
      try
        T_libvlc_audio_set_mute(FPlayer, Integer(FMuted));
      except
      end;
    end;
  end;
end;

procedure TVlcPlayer.SetLoopPlayback(const Value: Boolean);
begin
  if FLoopPlayback <> Value then
  begin
    FLoopPlayback := Value;
    Invalidate;
  end;
end;

procedure TVlcPlayer.SetHighQuality(const Value: Boolean);
begin
  if FHighQuality <> Value then
  begin
    FHighQuality := Value;
    Invalidate;
  end;
end;

procedure TVlcPlayer.SetUserAgent(const Value: string);
begin
  FUserAgent := Value;
end;

procedure TVlcPlayer.SetReferer(const Value: string);
begin
  FReferer := Value;
end;

procedure TVlcPlayer.SetHttpHeaders(const Value: TStringList);
begin
  if FHttpHeaders <> nil then
    FHttpHeaders.Assign(Value);
end;

procedure TVlcPlayer.SetStatusBarVisible(const Value: Boolean);
begin
  if FStatusBarVisible <> Value then
  begin
    FStatusBarVisible := Value;
    Invalidate;
  end;
end;

procedure TVlcPlayer.SetStatusBarText(const Value: string);
begin
  if FStatusBarText <> Value then
  begin
    FStatusBarText := Value;
    if FStatusBarVisible then
      Invalidate;
  end;
end;

procedure TVlcPlayer.SetStatusBarFontSize(const Value: Integer);
begin
  if FStatusBarFontSize <> Value then
  begin
    FStatusBarFontSize := Value;
    if FStatusBarVisible then
      Invalidate;
  end;
end;

procedure TVlcPlayer.SetStatusBarBackground(const Value: TColor);
begin
  if FStatusBarBackground <> Value then
  begin
    FStatusBarBackground := Value;
    if FStatusBarVisible then
      Invalidate;
  end;
end;

procedure TVlcPlayer.SetStatusBarTextColor(const Value: TColor);
begin
  if FStatusBarTextColor <> Value then
  begin
    FStatusBarTextColor := Value;
    if FStatusBarVisible then
      Invalidate;
  end;
end;

procedure TVlcPlayer.SetStatusBarCornerRadius(const Value: Integer);
begin
  if FStatusBarCornerRadius <> Value then
  begin
    FStatusBarCornerRadius := Value;
    if FStatusBarVisible then
      Invalidate;
  end;
end;

procedure TVlcPlayer.SetDisplayText(const Value: string);
begin
  if FDisplayText <> Value then
  begin
    FDisplayText := Value;
    if FDisplayTextVisible then
      Invalidate;
  end;
end;

procedure TVlcPlayer.SetDisplayTextVisible(const Value: Boolean);
begin
  if FDisplayTextVisible <> Value then
  begin
    FDisplayTextVisible := Value;
    Invalidate;
  end;
end;

procedure TVlcPlayer.SetDisplayTextFontSize(const Value: Integer);
begin
  if FDisplayTextFontSize <> Value then
  begin
    FDisplayTextFontSize := Value;
    if FDisplayTextVisible then
      Invalidate;
  end;
end;

procedure TVlcPlayer.SetDisplayTextColor(const Value: TColor);
begin
  if FDisplayTextColor <> Value then
  begin
    FDisplayTextColor := Value;
    if FDisplayTextVisible then
      Invalidate;
  end;
end;

procedure TVlcPlayer.SetDisplayTextBackground(const Value: TColor);
begin
  if FDisplayTextBackground <> Value then
  begin
    FDisplayTextBackground := Value;
    if FDisplayTextVisible then
      Invalidate;
  end;
end;

procedure TVlcPlayer.SetDisplayTextBackgroundAlpha(const Value: Integer);
begin
  if FDisplayTextBackgroundAlpha <> Value then
  begin
    FDisplayTextBackgroundAlpha := Max(0, Min(255, Value));
    if FDisplayTextVisible then
      Invalidate;
  end;
end;

procedure TVlcPlayer.SetDisplayTextCornerRadius(const Value: Integer);
begin
  if FDisplayTextCornerRadius <> Value then
  begin
    FDisplayTextCornerRadius := Value;
    if FDisplayTextVisible then
      Invalidate;
  end;
end;

procedure TVlcPlayer.SetShowTopImage(const Value: Boolean);
begin
  if FShowTopImage <> Value then
  begin
    FShowTopImage := Value;
    if FShowTopImage and (FTopImagePath <> '') then
      LoadTopImage;
    Invalidate;
  end;
end;

procedure TVlcPlayer.SetTopImagePath(const Value: string);
begin
  if FTopImagePath <> Value then
  begin
    FTopImagePath := Value;
    if FShowTopImage and (FTopImagePath <> '') then
      LoadTopImage;
    Invalidate;
  end;
end;

procedure TVlcPlayer.SetTopImageWidth(const Value: Integer);
begin
  if FTopImageWidth <> Value then
  begin
    FTopImageWidth := Max(8, Value);
    Invalidate;
  end;
end;

procedure TVlcPlayer.SetTopImageHeight(const Value: Integer);
begin
  if FTopImageHeight <> Value then
  begin
    FTopImageHeight := Max(8, Value);
    Invalidate;
  end;
end;

procedure TVlcPlayer.SetTopImageMargin(const Value: Integer);
begin
  if FTopImageMargin <> Value then
  begin
    FTopImageMargin := Max(0, Value);
    Invalidate;
  end;
end;

function TVlcPlayer.GetMuted: Boolean;
begin
  Result := FMuted;
end;

function TVlcPlayer.GetPlaying: Boolean;
begin
  if Assigned(FPlayer) and Assigned(T_libvlc_media_player_is_playing) then
  begin
    try
      Result := T_libvlc_media_player_is_playing(FPlayer) <> 0;
    except
      Result := False;
    end;
  end
  else
    Result := FState = vlcPlaying;
end;

function TVlcPlayer.GetPaused: Boolean;
begin
  Result := FState = vlcPaused;
end;

function TVlcPlayer.GetStopped: Boolean;
begin
  Result := FState = vlcStopped;
end;

function TVlcPlayer.GetPosition: Int64;
begin
  Result := 0;
  if Assigned(FPlayer) and Assigned(T_libvlc_media_player_get_time) then
  begin
    try
      Result := T_libvlc_media_player_get_time(FPlayer);
    except
      Result := 0;
    end;
  end;
end;

function TVlcPlayer.GetPlaybackPosition: Single;
begin
  Result := 0;
  if Assigned(FPlayer) and Assigned(T_libvlc_media_player_get_position) then
  begin
    try
      Result := T_libvlc_media_player_get_position(FPlayer);
    except
      Result := 0;
    end;
  end;
end;

// Новый метод для получения текущего URL медиа
function TVlcPlayer.GetCurrentMediaURL: string;
begin
  Result := FMediaURL;
end;

procedure TVlcPlayer.CreateWnd;
begin
  inherited CreateWnd;
  if not (csDesigning in ComponentState) then
  begin
    FOriginalWndProc := WindowProc;
    WindowProc := MainWndProc;
  end;
end;

procedure TVlcPlayer.DestroyWnd;
begin
  if not (csDesigning in ComponentState) then
  begin
    if Assigned(FOriginalWndProc) then
      WindowProc := FOriginalWndProc;
  end;
  inherited DestroyWnd;
end;

procedure TVlcPlayer.Paint;
var
  VideoRect: TRect;
begin
  inherited Paint;

  Canvas.Brush.Color := clBlack;
  Canvas.FillRect(ClientRect);

  if FBufferValid and Assigned(FVideoBitmap) and
     (FVideoBitmap.Width > 1) and (FVideoBitmap.Height > 1) then
  begin
    try
      VideoRect := CalculateAspectRatioFit;
      Canvas.StretchDraw(VideoRect, FVideoBitmap);
    except
      Canvas.Brush.Color := clBlack;
      Canvas.FillRect(ClientRect);
    end;
  end
  else
  begin
    Canvas.Brush.Color := clGray;
    Canvas.FillRect(ClientRect);

    if csDesigning in ComponentState then
    begin
      Canvas.Font.Color := clWhite;
      Canvas.TextOut(10, 10, 'TVlcPlayer');
      Canvas.TextOut(10, 30, 'No video loaded');
    end;
  end;

  if FDisplayTextVisible then
    DrawDisplayText(Canvas);

  if FShowTopImage then
    DrawTopImage(Canvas);

  if FStatusBarVisible and (FStatusBarText <> '') then
    DrawStatusBar(Canvas);

  if FShowLoading then
    DrawLoadingAnimation(Canvas);

  if FCurrentFPS > 0 then
  begin
    Canvas.Font.Color := clWhite;
    Canvas.Font.Size := 8;
    Canvas.TextOut(5, Height - 20, Format('FPS: %d', [FCurrentFPS]));
  end;
end;

procedure TVlcPlayer.Resize;
begin
  inherited Resize;
  Invalidate;
end;

procedure TVlcPlayer.DrawStatusBar(Canvas: TCanvas);
var
  TextWidth, TextHeight: Integer;
  StatusRect: TRect;
  OldMode: Integer;
begin
  if not FStatusBarVisible or (FStatusBarText = '') then Exit;

  Canvas.Font.Color := FStatusBarTextColor;
  Canvas.Font.Size := FStatusBarFontSize;
  Canvas.Font.Style := [fsBold];

  TextWidth := Canvas.TextWidth(FStatusBarText);
  TextHeight := Canvas.TextHeight(FStatusBarText);

  StatusRect := Rect(10, 10, 10 + TextWidth + 20, 10 + TextHeight + 10);

  OldMode := SetBkMode(Canvas.Handle, TRANSPARENT);

  try
    Canvas.Brush.Color := FStatusBarBackground;
    Canvas.Pen.Color := FStatusBarBackground;
    Canvas.RoundRect(StatusRect.Left, StatusRect.Top, StatusRect.Right, StatusRect.Bottom,
      FStatusBarCornerRadius, FStatusBarCornerRadius);

    Canvas.Font.Color := FStatusBarTextColor;
    Canvas.TextOut(StatusRect.Left + 10, StatusRect.Top + 5, FStatusBarText);
  finally
    SetBkMode(Canvas.Handle, OldMode);
  end;
end;

procedure TVlcPlayer.DrawDisplayText(Canvas: TCanvas);
var
  TextWidth, TextHeight: Integer;
  TextRect: TRect;
  OldMode: Integer;
begin
  if not FDisplayTextVisible or (FDisplayText = '') then Exit;

  Canvas.Font.Color := FDisplayTextColor;
  Canvas.Font.Size := FDisplayTextFontSize;
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Name := 'Segoe UI';

  TextWidth := Canvas.TextWidth(FDisplayText);
  TextHeight := Canvas.TextHeight(FDisplayText);

  TextRect.Left := (ClientWidth - TextWidth) div 2;
  TextRect.Top := ClientHeight - TextHeight - 20;
  TextRect.Right := TextRect.Left + TextWidth + 20;
  TextRect.Bottom := TextRect.Top + TextHeight + 10;

  if FDisplayTextBackgroundAlpha > 0 then
  begin
    Canvas.Brush.Color := FDisplayTextBackground;

    if FDisplayTextCornerRadius > 0 then
    begin
      Canvas.Pen.Color := FDisplayTextBackground;
      Canvas.Pen.Width := 1;
      Canvas.RoundRect(TextRect.Left, TextRect.Top, TextRect.Right, TextRect.Bottom,
        FDisplayTextCornerRadius, FDisplayTextCornerRadius);
    end
    else
    begin
      Canvas.FillRect(TextRect);
    end;
  end;

  OldMode := SetBkMode(Canvas.Handle, TRANSPARENT);
  try
    Canvas.Font.Color := FDisplayTextColor;
    Canvas.TextOut(TextRect.Left + 10, TextRect.Top + 5, FDisplayText);
  finally
    SetBkMode(Canvas.Handle, OldMode);
  end;
end;

procedure TVlcPlayer.DrawTopImage(Canvas: TCanvas);
var
  DestRect: TRect;
begin
  if not FShowTopImage or (FTopImage = nil) or (FTopImage.Width = 0) or (FTopImage.Height = 0) then Exit;

  try
    DestRect.Right := ClientWidth - FTopImageMargin;
    DestRect.Top := FTopImageMargin;
    DestRect.Left := DestRect.Right - FTopImageWidth;
    DestRect.Bottom := DestRect.Top + FTopImageHeight;

    Canvas.StretchDraw(DestRect, FTopImage);

  except
  end;
end;

procedure TVlcPlayer.DrawLoadingAnimation(Canvas: TCanvas);
var
  CenterX, CenterY, Radius: Integer;
  I, TotalDots, ActiveDots: Integer;
  Angle: Double;
  X, Y: Integer;
  CurrentTime: Cardinal;
  AnimationPhase: Integer;
  OldBrushColor, OldPenColor: TColor;
  RunningIndex: Integer;
  RunningAngle: Double;
  RunningX, RunningY: Integer;
  Pulse: Double;
  RunningSize: Integer;
begin
  if not FShowLoading then Exit;

  CenterX := Width div 2;
  CenterY := Height div 2;

  Radius := Min(Width, Height) div 24;
  Radius := Max(8, Min(23, Radius));

  TotalDots := 12;

  CurrentTime := GetTickCount;
  AnimationPhase := (CurrentTime div 100) mod (TotalDots + 1);
  ActiveDots := AnimationPhase;

  OldBrushColor := Canvas.Brush.Color;
  OldPenColor := Canvas.Pen.Color;

  try
    for I := 0 to TotalDots - 1 do
    begin
      Angle := 2 * Pi * I / TotalDots;
      X := CenterX + Round(Cos(Angle) * Radius);
      Y := CenterY + Round(Sin(Angle) * Radius);

      if I < ActiveDots then
      begin
        Canvas.Brush.Color := clWhite;
        Canvas.Pen.Color := clGray;
        Canvas.Ellipse(X - 2, Y - 2, X + 2, Y + 2);
      end
      else
      begin
        Canvas.Brush.Color := $50666666;
        Canvas.Pen.Color := $50666666;
        Canvas.Ellipse(X - 1, Y - 1, X + 1, Y + 1);
      end;
    end;

    if ActiveDots > 0 then
    begin
      RunningIndex := ActiveDots - 1;
      RunningAngle := 2 * Pi * RunningIndex / TotalDots;
      RunningX := CenterX + Round(Cos(RunningAngle) * Radius);
      RunningY := CenterY + Round(Sin(RunningAngle) * Radius);

      Pulse := (Sin(DegToRad(CurrentTime / 20)) + 1) / 2;
      RunningSize := 2 + Round(1 * Pulse);

      Canvas.Brush.Color := clWhite;
      Canvas.Pen.Color := clGray;
      Canvas.Ellipse(RunningX - RunningSize, RunningY - RunningSize,
                     RunningX + RunningSize, RunningY + RunningSize);
    end;

  finally
    Canvas.Brush.Color := OldBrushColor;
    Canvas.Pen.Color := OldPenColor;
  end;
end;

function TVlcPlayer.CalculateAspectRatioFit: TRect;
var
  AspectRatio: Double;
  ScaledWidth, ScaledHeight: Integer;
  X, Y: Integer;
begin
  if (FVideoBitmap = nil) or (FVideoBitmap.Width = 0) or (FVideoBitmap.Height = 0) then
  begin
    Result := ClientRect;
    Exit;
  end;

  AspectRatio := FVideoBitmap.Width / FVideoBitmap.Height;
  ScaledHeight := ClientHeight;
  ScaledWidth := Round(ScaledHeight * AspectRatio);

  if ScaledWidth > ClientWidth then
  begin
    ScaledWidth := ClientWidth;
    ScaledHeight := Round(ScaledWidth / AspectRatio);
  end;

  X := (ClientWidth - ScaledWidth) div 2;
  Y := (ClientHeight - ScaledHeight) div 2;

  Result := Rect(X, Y, X + ScaledWidth, Y + ScaledHeight);
end;

procedure TVlcPlayer.LoadTopImage;
begin
  if (FTopImagePath <> '') and FileExists(FTopImagePath) then
  begin
    try
      FTopImage.LoadFromFile(FTopImagePath);
    except
      FTopImage.Free;
      FTopImage := TPNGImage.Create;
    end;
  end
  else
  begin
    FTopImage.Free;
    FTopImage := TPNGImage.Create;
  end;
end;

procedure TVlcPlayer.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;

  if Assigned(FOnVideoMouseDown) then
    FOnVideoMouseDown(Self, Button, Shift, X, Y);
end;

procedure TVlcPlayer.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;

  if Assigned(FOnVideoMouseUp) then
    FOnVideoMouseUp(Self, Button, Shift, X, Y);

  if Assigned(FOnVideoClick) and (Button = mbLeft) then
    FOnVideoClick(Self);
end;

procedure TVlcPlayer.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited;

  FLastMouseMoveTime := GetTickCount;

  if Assigned(FOnVideoMouseMove) then
    FOnVideoMouseMove(Self, Shift, X, Y);
end;

procedure TVlcPlayer.DblClick;
begin
  inherited;

  if Assigned(FOnVideoDblClick) then
    FOnVideoDblClick(Self);
end;

procedure TVlcPlayer.MouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint);
var
  ActualMousePos: TPoint;
begin
  inherited;

  // Преобразуем координаты, если MousePos указан относительно экрана
  ActualMousePos := ScreenToClient(MousePos);

  if Assigned(FOnVideoMouseWheel) then
    FOnVideoMouseWheel(Self, Shift, WheelDelta, ActualMousePos);
end;

procedure TVlcPlayer.MainWndProc(var Message: TMessage);
var
  Shift: TShiftState;
  MousePos: TPoint;
  Handled: Boolean;
  Button: TMouseButton;
begin
  Handled := False;

  case Message.Msg of
    WM_LBUTTONDOWN, WM_RBUTTONDOWN, WM_MBUTTONDOWN:
      begin
        if Assigned(FOnVideoMouseDown) then
        begin
          MousePos.X := SmallInt(Message.LParamLo);
          MousePos.Y := SmallInt(Message.LParamHi);
          Shift := GetShiftState;

          case Message.Msg of
            WM_LBUTTONDOWN: Button := mbLeft;
            WM_RBUTTONDOWN: Button := mbRight;
            WM_MBUTTONDOWN: Button := mbMiddle;
          else
            Button := mbLeft;
          end;

          FOnVideoMouseDown(Self, Button, Shift, MousePos.X, MousePos.Y);
          Handled := True;
        end;
      end;

    WM_LBUTTONUP, WM_RBUTTONUP, WM_MBUTTONUP:
      begin
        if Assigned(FOnVideoMouseUp) then
        begin
          MousePos.X := SmallInt(Message.LParamLo);
          MousePos.Y := SmallInt(Message.LParamHi);
          Shift := GetShiftState;

          case Message.Msg of
            WM_LBUTTONUP: Button := mbLeft;
            WM_RBUTTONUP: Button := mbRight;
            WM_MBUTTONUP: Button := mbMiddle;
          else
            Button := mbLeft;
          end;

          FOnVideoMouseUp(Self, Button, Shift, MousePos.X, MousePos.Y);
          Handled := True;
        end;
      end;

    WM_MOUSEMOVE:
      begin
        if Assigned(FOnVideoMouseMove) then
        begin
          MousePos.X := SmallInt(Message.LParamLo);
          MousePos.Y := SmallInt(Message.LParamHi);
          Shift := GetShiftState;
          FOnVideoMouseMove(Self, Shift, MousePos.X, MousePos.Y);
          Handled := True;
        end;
      end;

    WM_MOUSEWHEEL:
      begin
        if Assigned(FOnVideoMouseWheel) then
        begin
          var WheelDelta := SmallInt(Message.WParamHi);
          MousePos.X := SmallInt(Message.LParamLo);
          MousePos.Y := SmallInt(Message.LParamHi);
          Shift := GetShiftState;
          FOnVideoMouseWheel(Self, Shift, WheelDelta, MousePos);
          Handled := True;
        end;
      end;
  end;

  if not Handled then
  begin
    if Assigned(FOriginalWndProc) then
      FOriginalWndProc(Message)
    else
      inherited;
  end;
end;

function TVlcPlayer.GetShiftState: TShiftState;
begin
  Result := [];

  if GetKeyState(VK_SHIFT) < 0 then
    Include(Result, ssShift);
  if GetKeyState(VK_CONTROL) < 0 then
    Include(Result, ssCtrl);
  if GetKeyState(VK_MENU) < 0 then
    Include(Result, ssAlt);
  if GetKeyState(VK_LBUTTON) < 0 then
    Include(Result, ssLeft);
  if GetKeyState(VK_RBUTTON) < 0 then
    Include(Result, ssRight);
  if GetKeyState(VK_MBUTTON) < 0 then
    Include(Result, ssMiddle);
end;

procedure TVlcPlayer.ForceRepaint;
begin
  if HandleAllocated then
  begin
    InvalidateRect(Handle, nil, False);
    UpdateWindow(Handle);
  end;
end;

procedure TVlcPlayer.SafeInvalidate;
begin
  if TThread.Current.ThreadID = MainThreadID then
  begin
    if not (csDestroying in ComponentState) and HandleAllocated then
      Invalidate;
  end
  else
  begin
    PostMessage(Handle, WM_USER + 1, 0, 0);
  end;
end;

function TVlcPlayer.IsNetworkStream(const AUrl: string): Boolean;
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

procedure TVlcPlayer.EnableAudio;
begin
  if FAudioEnabled or FShutdownMode then Exit;

  if (FPlayer <> nil) and Assigned(T_libvlc_audio_set_volume) then
  begin
    try
      T_libvlc_audio_set_volume(FPlayer, FVolume);
    except
    end;
  end;

  if (FPlayer <> nil) and Assigned(T_libvlc_audio_set_mute) then
  begin
    try
      T_libvlc_audio_set_mute(FPlayer, Integer(FMuted));
    except
    end;
  end;

  FAudioEnabled := True;
end;

procedure TVlcPlayer.ForceVideoUpdate;
begin
  if FFrameReady and FBufferValid then
  begin
    try
      UpdateBitmapFromBuffer;
      FFrameReady := False;
      Invalidate;
    except
    end;
  end;
end;

procedure TVlcPlayer.Play;
var
  ResultCode: Integer;
begin
  if not IsInitialized then
    Exit;

  if FPlayer = nil then
    Exit;

  StartStreamHealthMonitor;

  if FFrameTimer <> nil then
    FFrameTimer.Enabled := True;

  ResultCode := T_libvlc_media_player_play(FPlayer);

  if ResultCode <> 0 then
  begin
    SetState(vlcError);
    FIsLoading := False;

    if Assigned(FOnError) then
      FOnError(Self, ResultCode, 'Playback failed');
  end;
end;

procedure TVlcPlayer.Pause;
begin
  if FShutdownMode or (FPlayer = nil) then Exit;

  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_pause) then
  begin
    if IsPlaying then
      T_libvlc_media_player_pause(FPlayer);
  end;
end;

procedure TVlcPlayer.Stop;
begin
  if FShutdownMode then Exit;
  if (csDestroying in ComponentState) then Exit;

  if FHealthTimer <> nil then
    FHealthTimer.Enabled := False;

  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_stop) then
  begin
    try
      T_libvlc_media_player_stop(FPlayer);
    except
    end;
  end;

  if FFrameTimer <> nil then
    FFrameTimer.Enabled := False;

  if FSyncTimer <> nil then
    FSyncTimer.Enabled := False;

  SetState(vlcStopped);
  FIsLoading := False;

  ClearVideoBuffer;
end;

procedure TVlcPlayer.LoadMedia(const AUrl: string);
var
  Options: TStringList;
  I: Integer;
begin
  if (csDestroying in ComponentState) then
    Exit;

  ResetStreamState;

  if IsPlaying or IsPaused then
    Stop;

  Sleep(100);

  FAudioEnabled := False;
  FVideoStarted := False;
  FBufferValid := False;
  FFrameReady := False;

  SetState(vlcLoading);
  FIsLoading := True;

  FShowLoading := True;

  if FFallbackTimer <> nil then
    FFallbackTimer.Enabled := True;

  if not IsInitialized then
    InitVLC;

  if not IsInitialized then
  begin
    SetState(vlcError);
    if Assigned(FOnError) then
      FOnError(Self, -100, 'VLC not initialized');
    Exit;
  end;

  if AUrl = '' then
  begin
    SetState(vlcError);
    if Assigned(FOnError) then
      FOnError(Self, -101, 'Empty media URL');
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

    Sleep(100);

    if IsNetworkStream(AUrl) then
      FMedia := T_libvlc_media_new_location(FInstance, PAnsiChar(AnsiString(AUrl)))
    else
      FMedia := T_libvlc_media_new_path(FInstance, PAnsiChar(AnsiString(AUrl)));

    if FMedia = nil then
      raise Exception.Create('Failed to create media object');

    if Assigned(T_libvlc_media_add_option) then
    begin
      Options := BuildVlcOptions;
      try
        for I := 0 to Options.Count - 1 do
          T_libvlc_media_add_option(FMedia, PAnsiChar(AnsiString(Options[I])));
      finally
        Options.Free;
      end;
    end;

    Sleep(100);

    FPlayer := T_libvlc_media_player_new_from_media(FMedia);
    if FPlayer = nil then
      raise Exception.Create('Failed to create media player');

    Sleep(50);

    SetupEventHandlers;

    Sleep(50);

    SetupMemoryRendering;

    if FFrameTimer <> nil then
      FFrameTimer.Enabled := True;

    StartStreamHealthMonitor;

    if (FPlayer <> nil) and Assigned(T_libvlc_audio_set_mute) then
    begin
      try
        T_libvlc_audio_set_mute(FPlayer, Integer(FMuted));
      except
      end;
    end;

    if FAutoPlay then
    begin
      Sleep(200);
      Play;
    end
    else
    begin
      SetState(vlcPaused);
    end;

  except
    on E: Exception do
    begin
      SetState(vlcError);
      FIsLoading := False;
      FAudioEnabled := False;
      FVideoStarted := False;

      FShowLoading := False;
      Invalidate;

      if Assigned(FOnError) then
        FOnError(Self, -1, E.Message);
    end;
  end;
end;

procedure TVlcPlayer.SeekTo(Position: Single);
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_set_position) then
  begin
    Position := Max(0, Min(1, Position));
    T_libvlc_media_player_set_position(FPlayer, Position);
  end;
end;

procedure TVlcPlayer.SeekToTime(TimeMs: Int64);
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_set_time) then
  begin
    TimeMs := Max(0, TimeMs);
    T_libvlc_media_player_set_time(FPlayer, TimeMs);
  end;
end;

function TVlcPlayer.IsInitialized: Boolean;
begin
  Result := (FInstance <> nil) and (FLibHandle <> 0);
end;

function TVlcPlayer.IsSeekable: Boolean;
begin
  Result := (FPlayer <> nil) and (GetDuration > 0);
end;

function TVlcPlayer.CanPause: Boolean;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_is_playing) then
    Result := IsPlaying
  else
    Result := True;
end;

function TVlcPlayer.GetDuration: Int64;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_get_length) then
    Result := T_libvlc_media_player_get_length(FPlayer)
  else
    Result := 0;
end;

function TVlcPlayer.GetVideoWidth: Integer;
begin
  Result := FVideoWidth;
end;

function TVlcPlayer.GetVideoHeight: Integer;
begin
  Result := FVideoHeight;
end;

function TVlcPlayer.HasVideo: Boolean;
begin
  Result := (FVideoWidth > 0) and (FVideoHeight > 0) and
            (FVideoBitmap <> nil) and not FVideoBitmap.Empty;
end;

function TVlcPlayer.GetPlayerStatus: string;
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

procedure TVlcPlayer.AddHttpHeader(const AName, AValue: string);
begin
  if FHttpHeaders <> nil then
    FHttpHeaders.Values[AName] := AValue;
end;

procedure TVlcPlayer.ClearHttpHeaders;
begin
  if FHttpHeaders <> nil then
    FHttpHeaders.Clear;
end;

procedure TVlcPlayer.SetWinkHeaders;
begin
  FUserAgent := 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
  FReferer := 'https://wink.ru/';
  ClearHttpHeaders;
  AddHttpHeader('Accept', '*/*');
  AddHttpHeader('Accept-Language', 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7');
  AddHttpHeader('Origin', 'https://wink.ru');
end;

procedure TVlcPlayer.SetBasicHeaders;
begin
  FUserAgent := 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
  FReferer := '';
  ClearHttpHeaders;
  AddHttpHeader('Accept', '*/*');
  AddHttpHeader('Accept-Language', 'en-US,en;q=0.9');
end;

procedure TVlcPlayer.Mute;
begin
  SetMuted(True);
end;

procedure TVlcPlayer.Unmute;
begin
  SetMuted(False);
end;

procedure TVlcPlayer.ToggleMute;
begin
  SetMuted(not FMuted);
end;

function TVlcPlayer.IsMuted: Boolean;
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

procedure TVlcPlayer.EnableAudioSync(Enabled: Boolean);
begin
  FAudioSyncEnabled := Enabled;
  if FSyncTimer <> nil then
    FSyncTimer.Enabled := Enabled and IsPlaying;
end;

procedure TVlcPlayer.SetAudioDelay(DelayMs: Integer);
begin
  FAudioDelay := DelayMs;
end;

procedure TVlcPlayer.SetTargetFPS(FPS: Integer);
begin
  FTargetFPS := Max(15, Min(60, FPS));
  if FFrameTimer <> nil then
    FFrameTimer.Interval := 1000 div FTargetFPS;
end;

function TVlcPlayer.GetCurrentFPS: Integer;
begin
  Result := FCurrentFPS;
end;

procedure TVlcPlayer.EnableHighPerformanceMode(Enabled: Boolean);
begin
  if Enabled then
    SetTargetFPS(30)
  else
    SetTargetFPS(60);
end;

procedure TVlcPlayer.ClearBuffer;
begin
  ClearVideoBuffer;
end;

procedure TVlcPlayer.ShowStatusBar(const AText: string = '');
begin
  if AText <> '' then
    FStatusBarText := AText;

  FStatusBarVisible := True;
  Invalidate;
end;

procedure TVlcPlayer.HideStatusBar;
begin
  FStatusBarVisible := False;
  Invalidate;
end;

procedure TVlcPlayer.UpdateStatusBar(const AText: string);
begin
  if FStatusBarText <> AText then
  begin
    FStatusBarText := AText;
    if FStatusBarVisible then
      Invalidate;
  end;
end;

procedure TVlcPlayer.SetStatusBarStyle(FontSize: Integer; BackgroundColor, TextColor: TColor; CornerRadius: Integer = 8);
begin
  FStatusBarFontSize := FontSize;
  FStatusBarBackground := BackgroundColor;
  FStatusBarTextColor := TextColor;
  FStatusBarCornerRadius := CornerRadius;

  if FStatusBarVisible then
    Invalidate;
end;

procedure TVlcPlayer.ShowDisplayText(const AText: string = '');
begin
  if AText <> '' then
    FDisplayText := AText;
  FDisplayTextVisible := True;
  Invalidate;
end;

procedure TVlcPlayer.HideDisplayText;
begin
  FDisplayTextVisible := False;
  Invalidate;
end;

procedure TVlcPlayer.SetDisplayTextStyle(FontSize: Integer; TextColor, BackgroundColor: TColor;
  BackgroundAlpha: Integer = 180; CornerRadius: Integer = 8);
begin
  FDisplayTextFontSize := FontSize;
  FDisplayTextColor := TextColor;
  FDisplayTextBackground := BackgroundColor;
  FDisplayTextBackgroundAlpha := BackgroundAlpha;
  FDisplayTextCornerRadius := CornerRadius;

  if FDisplayTextVisible then
    Invalidate;
end;

procedure TVlcPlayer.SetTopImage(const AImagePath: string; Show: Boolean = True);
begin
  FTopImagePath := AImagePath;
  FShowTopImage := Show;

  if Show then
    LoadTopImage;

  Invalidate;
end;

procedure TVlcPlayer.HideTopImage;
begin
  FShowTopImage := False;
  Invalidate;
end;

procedure TVlcPlayer.TakeSnapshot(const AFileName: string);
begin
  if (FVideoBitmap <> nil) and not FVideoBitmap.Empty then
  begin
    try
      FVideoBitmap.SaveToFile(AFileName);
    except
    end;
  end;
end;

procedure TVlcPlayer.StartStreamHealthMonitor;
begin
  if FHealthTimer = nil then
  begin
    FHealthTimer := TTimer.Create(Self);
    FHealthTimer.Interval := 30000;
    FHealthTimer.OnTimer := HealthCheckTimerTick;
  end;
  FHealthTimer.Enabled := True;
  FStreamStartTime := Now;
end;

procedure TVlcPlayer.HealthCheckTimerTick(Sender: TObject);
var
  CurrentTime: Cardinal;
  TimeSinceLastFrame: Cardinal;
begin
  if not IsPlaying then Exit;

  CurrentTime := GetTickCount;
  TimeSinceLastFrame := CurrentTime - FLastFrameUpdateTime;

  if (TimeSinceLastFrame > 3000) and (FState = vlcPlaying) then
  begin
    if not FShowLoading then
    begin
      if not FBufferValid then
        ForceVideoRecovery
      else
      begin
        FShowLoading := True;
        Invalidate;
      end;
    end;
  end;

  if FAutoRestartEnabled then
  begin
    var MinutesRunning := MinutesBetween(Now, FStreamStartTime);
    if MinutesRunning >= FAutoRestartInterval then
      AutoRestartCheck;
  end;

  CheckMemoryUsage;
end;

procedure TVlcPlayer.CheckMemoryUsage;
var
  MemStatus: TMemoryStatus;
  CurrentTime: Cardinal;
begin
  CurrentTime := GetTickCount;

  if CurrentTime - FLastMemoryCheck < 30000 then Exit;

  GlobalMemoryStatus(MemStatus);

  if MemStatus.dwMemoryLoad > 90 then
  begin
    if IsPlaying then
      EmergencyMemoryOptimization
    else
      ClearVideoBuffer;
  end
  else if MemStatus.dwMemoryLoad > 85 then
  begin
    if IsPlaying then
      AdjustPerformanceSettings;
  end
  else if FAdjustedCache then
  begin
    FAdjustedCache := False;
  end;

  FLastMemoryCheck := CurrentTime;
end;

procedure TVlcPlayer.EmergencyMemoryOptimization;
begin
  if (FVideoBitmap <> nil) and (FVideoBitmap.Width > 0) and (FVideoBitmap.Height > 0) then
  begin
    try
      var TempWidth := Max(640, FVideoBitmap.Width div 2);
      var TempHeight := Max(480, FVideoBitmap.Height div 2);

      if (TempWidth < FVideoBitmap.Width) or (TempHeight < FVideoBitmap.Height) then
      begin
        FVideoBitmap.Width := TempWidth;
        FVideoBitmap.Height := TempHeight;
      end;
    except
    end;
  end;

  try
    SetProcessWorkingSetSize(GetCurrentProcess, SIZE_T(-1), SIZE_T(-1));
  except
  end;

  if FVideoBufferSize > (8 * 1024 * 1024) then
    ClearVideoBuffer;

  if FFrameTimer <> nil then
  begin
    var OriginalInterval := FFrameTimer.Interval;
    var MemStatus: TMemoryStatus;
    GlobalMemoryStatus(MemStatus);

    var NewInterval: Integer;
    if MemStatus.dwMemoryLoad > 95 then
      NewInterval := 66
    else if MemStatus.dwMemoryLoad > 90 then
      NewInterval := 50
    else
      NewInterval := 33;

    if NewInterval > OriginalInterval then
      FFrameTimer.Interval := NewInterval;
  end;
end;

procedure TVlcPlayer.AdjustPerformanceSettings;
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
            T_libvlc_media_add_option(FMedia, PAnsiChar(AnsiString(Options[I])));
        end;
      finally
        Options.Free;
      end;
    except
    end;
  end;

  FAdjustedCache := True;
end;

procedure TVlcPlayer.AutoRestartCheck;
begin
  if not FAutoRestartEnabled or not IsPlaying then Exit;
  ForceSoftRestart;
end;

procedure TVlcPlayer.ForceSoftRestart;
var
  CurrentURL: string;
  CurrentPosition: Single;
begin
  if not IsPlaying then Exit;

  CurrentURL := FMediaURL;
  CurrentPosition := GetPlaybackPosition;

  PostMessage(Handle, WM_USER + 500, 0, 0);

  FTempRestartURL := CurrentURL;
  FTempRestartPosition := CurrentPosition;
end;

procedure TVlcPlayer.ResetPerformanceSettings;
begin
  FAdjustedCache := False;
  if FFrameTimer <> nil then
    FFrameTimer.Interval := 33;
end;

procedure TVlcPlayer.EnableAutoRestart(Enabled: Boolean; IntervalMinutes: Integer = 60);
begin
  FAutoRestartEnabled := Enabled;
  FAutoRestartInterval := IntervalMinutes;
end;

procedure TVlcPlayer.ResetStreamState;
begin
  FAdjustedCache := False;
  FLastFrameUpdateTime := GetTickCount;
  FStreamStartTime := Now;
end;

procedure TVlcPlayer.ForceVideoRecovery;
begin
  if not IsPlaying then Exit;

  try
    var WasPlaying := IsPlaying;

    if WasPlaying then
      Pause;

    EnhancedFreeVideoBuffer;

    if (FVideoWidth > 0) and (FVideoHeight > 0) then
      AllocateVideoBuffer(FVideoWidth, FVideoHeight);

    if WasPlaying and IsPaused then
      Play;

  except
  end;
end;

procedure TVlcPlayer.StopAllTimers;
begin
  try
    if FHealthTimer <> nil then
    begin
      FHealthTimer.Enabled := False;
      FHealthTimer.OnTimer := nil;
    end;
  except end;

  try
    if FFrameTimer <> nil then
    begin
      FFrameTimer.Enabled := False;
      FFrameTimer.OnTimer := nil;
    end;
  except end;

  try
    if FPositionTimer <> nil then
    begin
      FPositionTimer.Enabled := False;
      FPositionTimer.OnTimer := nil;
    end;
  except end;

  try
    if FSyncTimer <> nil then
    begin
      FSyncTimer.Enabled := False;
      FSyncTimer.OnTimer := nil;
    end;
  except end;

  try
    if FFallbackTimer <> nil then
    begin
      FFallbackTimer.Enabled := False;
      FFallbackTimer.OnTimer := nil;
    end;
  except end;
end;

procedure TVlcPlayer.StopVLCPlayback;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_stop) then
  begin
    try
      T_libvlc_media_player_stop(FPlayer);
      Sleep(100);
    except
    end;
  end;
end;

procedure TVlcPlayer.FreeVLCResources;
begin
  if FPlayer <> nil then
  begin
    try
      if Assigned(T_libvlc_media_player_release) then
        T_libvlc_media_player_release(FPlayer);
    except
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

procedure TVlcPlayer.EnhancedFreeVideoBuffer;
var
  I: Integer;
begin
  if FFrameLock = nil then Exit;

  if FFrameLock.TryEnter then
  try
    for I := 0 to 1 do
    begin
      if (FVideoBuffer[I] <> nil) and (FVideoBufferSize > 0) then
      begin
        try
          FreeMem(FVideoBuffer[I], FVideoBufferSize);
        except
        end;
        FVideoBuffer[I] := nil;
      end;
    end;

    if (FBackBuffer <> nil) and (FVideoBufferSize > 0) then
    begin
      try
        FreeMem(FBackBuffer, FVideoBufferSize);
      except
      end;
      FBackBuffer := nil;
    end;

    FBufferValid := False;
    FFrameReady := False;

  finally
    FFrameLock.Leave;
  end;
end;

procedure TVlcPlayer.UpdateVideoSize(Width, Height: Integer);
begin
  if (Width <= 0) or (Height <= 0) then Exit;

  if (FVideoWidth <> Width) or (FVideoHeight <> Height) then
  begin
    FFrameLock.Enter;
    try
      FVideoWidth := Width;
      FVideoHeight := Height;
      AllocateVideoBuffer(Width, Height);

      if Assigned(FPlayer) and Assigned(T_libvlc_video_set_format) then
      begin
        T_libvlc_video_set_format(
          FPlayer,
          'BGRA',
          Width,
          Height,
          FVideoPitch
        );
      end;
    finally
      FFrameLock.Leave;
    end;

    Invalidate;
  end;
end;

procedure TVlcPlayer.SetupMemoryRendering;
var
  Chroma: AnsiString;
begin
  if (FPlayer = nil) or not Assigned(T_libvlc_video_set_callbacks) then
    Exit;

  T_libvlc_video_set_callbacks(FPlayer,
    @VlcLockCallback,
    @VlcUnlockCallback,
    @VlcDisplayCallback,
    Self);

  FVideoWidth := 1920;
  FVideoHeight := 1080;
  FVideoPitch := FVideoWidth * 4;

  AllocateVideoBuffer(FVideoWidth, FVideoHeight);

  if FBackBuffer = nil then
    Exit;

  Chroma := 'BGRA';
  try
    T_libvlc_video_set_format(FPlayer, PAnsiChar(Chroma),
      FVideoWidth, FVideoHeight, FVideoPitch);
  except
    TryAlternativeFormats;
  end;

  if FFrameTimer <> nil then
  begin
    FFrameTimer.Interval := 16;
    FFrameTimer.Enabled := True;
  end;
end;

procedure TVlcPlayer.GetVideoSize(var Width, Height: Integer);
var
  W, H: Cardinal;
begin
  Width := 0;
  Height := 0;

  if not Assigned(FPlayer) or not Assigned(T_libvlc_video_get_size) then
    Exit;

  try
    if T_libvlc_video_get_size(FPlayer, 0, W, H) = 0 then
    begin
      Width := W;
      Height := H;
    end;
  except
    Width := 640;
    Height := 480;
  end;
end;

procedure TVlcPlayer.AllocateVideoBuffer(Width, Height: Integer);
var
  I: Integer;
begin
  if (csDestroying in ComponentState) then Exit;

  if FFrameLock = nil then Exit;

  FFrameLock.Enter;
  try
    if (Width * Height) > (1920 * 1080) then
    begin
      Width := 1920;
      Height := 1080;
    end;

    if (Width <= 0) then Width := 1920;
    if (Height <= 0) then Height := 1080;

    FVideoPitch := Width * 4;
    FVideoPitch := (FVideoPitch + 3) and not 3;

    FVideoBufferSize := Height * FVideoPitch;

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

    FVideoWidth := Width;
    FVideoHeight := Height;

    try
      for I := 0 to 1 do
      begin
        FVideoBuffer[I] := AllocMem(FVideoBufferSize);
        if FVideoBuffer[I] <> nil then
          FillChar(FVideoBuffer[I]^, FVideoBufferSize, 0);
      end;

      FBackBuffer := AllocMem(FVideoBufferSize);
      if FBackBuffer <> nil then
        FillChar(FBackBuffer^, FVideoBufferSize, 0);

      FBufferValid := True;
      FCurrentBuffer := 0;

    except
      FBufferValid := False;
    end;

    if FVideoBitmap = nil then
      FVideoBitmap := TBitmap.Create;

    try
      if (FVideoBitmap.Width <> Width) or (FVideoBitmap.Height <> Height) then
      begin
        FVideoBitmap.PixelFormat := pf32bit;
        FVideoBitmap.Width := Width;
        FVideoBitmap.Height := Height;
      end;
    except
    end;

  finally
    FFrameLock.Leave;
  end;
end;

procedure TVlcPlayer.SwapBuffers;
var
  Temp: Pointer;
begin
  if FFrameLock = nil then Exit;

  if FFrameLock.TryEnter then
  try
    Temp := FVideoBuffer[FCurrentBuffer];
    FVideoBuffer[FCurrentBuffer] := FBackBuffer;
    FBackBuffer := Temp;

    FCurrentBuffer := (FCurrentBuffer + 1) mod 2;

  finally
    FFrameLock.Leave;
  end;
end;

procedure TVlcPlayer.ClearVideoBuffer;
var
  I: Integer;
  WasPlaying: Boolean;
  VideoWidth, VideoHeight: Integer;
begin
  if FFrameLock = nil then Exit;

  WasPlaying := IsPlaying;

  VideoWidth := FVideoWidth;
  VideoHeight := FVideoHeight;

  if FFrameLock.TryEnter then
  try
    for I := 0 to 1 do
    begin
      if FVideoBuffer[I] <> nil then
        FillChar(FVideoBuffer[I]^, FVideoBufferSize, 0);
    end;

    if FBackBuffer <> nil then
      FillChar(FBackBuffer^, FVideoBufferSize, 0);

    if FVideoBitmap <> nil then
    begin
      try
        FVideoBitmap.Canvas.Brush.Color := clBlack;
        FVideoBitmap.Canvas.FillRect(Rect(0, 0, FVideoBitmap.Width, FVideoBitmap.Height));
      except
      end;
    end;

    FFrameReady := False;
    if not WasPlaying then
      FBufferValid := False;

    FCurrentBuffer := 0;

  finally
    FFrameLock.Leave;
  end;

  SafeInvalidate;

  if WasPlaying and (VideoWidth > 0) and (VideoHeight > 0) then
  begin
    PostMessage(Handle, WM_USER + 100, VideoWidth, VideoHeight);
  end;
end;

procedure TVlcPlayer.UpdateBitmapFromBuffer;
var
  Y: Integer;
  SrcLine, DstLine: PByte;
begin
  if (csDestroying in ComponentState) or
     (FVideoBitmap = nil) or
     (FVideoBuffer[FCurrentBuffer] = nil) then
    Exit;

  if not FFrameLock.TryEnter then
    Exit;

  try
    if not FBufferValid or not FFrameReady then
      Exit;

    if (FVideoBitmap.Width <> FVideoWidth) or (FVideoBitmap.Height <> FVideoHeight) then
    begin
      FVideoBitmap.PixelFormat := pf32bit;
      FVideoBitmap.Width := FVideoWidth;
      FVideoBitmap.Height := FVideoHeight;
    end;

    for Y := 0 to FVideoHeight - 1 do
    begin
      SrcLine := PByte(FVideoBuffer[FCurrentBuffer]);
      Inc(SrcLine, Y * FVideoPitch);

      DstLine := FVideoBitmap.ScanLine[Y];

      Move(SrcLine^, DstLine^, FVideoWidth * 4);
    end;

    FFrameReady := False;
    FLastFrameUpdateTime := GetTickCount;

    CalculateFPS;

  finally
    FFrameLock.Leave;
  end;
end;

procedure TVlcPlayer.CalculateFPS;
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

procedure TVlcPlayer.FrameTimerTick(Sender: TObject);
var
  CurrentTime: Cardinal;
  TimeSinceFirstFrame: Cardinal;
begin
  if (csDestroying in ComponentState) then Exit;

  CurrentTime := GetTickCount;

  if not FBufferValid then
  begin
    if (FVideoWidth > 0) and (FVideoHeight > 0) and IsPlaying then
      AllocateVideoBuffer(FVideoWidth, FVideoHeight);
    Exit;
  end;

  if FFrameReady and FBufferValid then
  begin
    UpdateBitmapFromBuffer;

    if FFirstFrameTime = 0 then
      FFirstFrameTime := CurrentTime;

    if FFirstFrameTime > 0 then
    begin
      TimeSinceFirstFrame := CurrentTime - FFirstFrameTime;
      if (TimeSinceFirstFrame >= FAnimationHideDelay) and FShowLoading then
      begin
        FShowLoading := False;
        FFirstFrameTime := 0;
        Invalidate;
      end;
    end;

    Invalidate;
  end;
end;

procedure TVlcPlayer.PositionTimerTick(Sender: TObject);
begin
end;

procedure TVlcPlayer.SyncTimerTick(Sender: TObject);
var
  AudioTime, VideoTime: Int64;
  TimeDiff: Int64;
const
  SYNC_THRESHOLD = 40;
begin
  if not FAudioSyncEnabled or (FPlayer = nil) or not IsPlaying then
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
  end;
end;

procedure TVlcPlayer.FallbackTimerTick(Sender: TObject);
begin
  if FShowLoading and FIsLoading then
  begin
    FShowLoading := False;
    Invalidate;

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
          FOnError(Self, -1, 'Playback timeout');
      end;
    end;

    FFallbackTimer.Enabled := False;
  end;
end;

function TVlcPlayer.LockCallback(opaque: Pointer; planes: PPointer): Pointer; cdecl;
begin
  Result := nil;
  if (opaque = nil) or (GDestroyedPlayers = nil) then Exit;
  if GDestroyedPlayers.Contains(TVlcPlayer(opaque)) then Exit;

  try
    with TVlcPlayer(opaque) do
    begin
      if FShutdownMode or (csDestroying in ComponentState) then Exit;
      if FBackBuffer = nil then Exit;

      Result := FBackBuffer;
      if planes <> nil then
        planes^ := FBackBuffer;
    end;
  except
    Result := nil;
  end;
end;

procedure TVlcPlayer.UnlockCallback(opaque: Pointer; picture: Pointer; planes: PPointer); cdecl;
begin
  if (opaque = nil) or (GDestroyedPlayers = nil) then Exit;
  if GDestroyedPlayers.Contains(TVlcPlayer(opaque)) then Exit;

  try
    with TVlcPlayer(opaque) do
    begin
      if FShutdownMode or (csDestroying in ComponentState) then Exit;

      if FFrameLock.TryEnter then
      try
        SwapBuffers;
        FFrameReady := True;
      finally
        FFrameLock.Leave;
      end;
    end;
  except
  end;
end;

procedure TVlcPlayer.InitVLC;
var
  VlcOptions: TStringList;
  VlcArgs: array of PAnsiChar;
  I: Integer;
  LibName: string;
begin
  if Assigned(FInstance) then
    Exit;

  if FLibPath = '' then
    LibName := 'libvlc.dll'
  else
    LibName := FLibPath;

  SetDllDirectory(PChar(FLibPath));
  FLibHandle := LoadLibrary('libvlc.dll');
  SetDllDirectory(nil);

  if FLibHandle = 0 then
  begin
    SetState(vlcError);
    if Assigned(FOnError) then
      FOnError(Self, -100, 'Не удалось загрузить libvlc.dll');
    Exit;
  end;

  try
    LoadFunctions;
  except
    FreeLibrary(FLibHandle);
    FLibHandle := 0;
    SetState(vlcError);
    Exit;
  end;

  VlcOptions := BuildVlcOptions;
  try
    SetLength(VlcArgs, VlcOptions.Count);
    for I := 0 to VlcOptions.Count - 1 do
      VlcArgs[I] := PAnsiChar(AnsiString(VlcOptions[I]));

    if VlcOptions.Count > 0 then
      FInstance := T_libvlc_new(Length(VlcArgs), @VlcArgs[0])
    else
      FInstance := T_libvlc_new(0, nil);

    if FInstance = nil then
    begin
      FreeLibrary(FLibHandle);
      FLibHandle := 0;
      SetState(vlcError);
    end
    else
    begin
      SetState(vlcIdle);
    end;
  finally
    VlcOptions.Free;
  end;

  SetDllDirectory(nil);
end;

procedure TVlcPlayer.LoadFunctions;
begin
  @T_libvlc_new := GetProcAddress(FLibHandle, 'libvlc_new');
  @T_libvlc_release := GetProcAddress(FLibHandle, 'libvlc_release');
  @T_libvlc_media_new_location := GetProcAddress(FLibHandle, 'libvlc_media_new_location');
  @T_libvlc_media_new_path := GetProcAddress(FLibHandle, 'libvlc_media_new_path');
  @T_libvlc_media_release := GetProcAddress(FLibHandle, 'libvlc_media_release');
  @T_libvlc_media_player_new_from_media := GetProcAddress(FLibHandle, 'libvlc_media_player_new_from_media');
  @T_libvlc_media_player_release := GetProcAddress(FLibHandle, 'libvlc_media_player_release');
  @T_libvlc_media_player_play := GetProcAddress(FLibHandle, 'libvlc_media_player_play');
  @T_libvlc_media_player_pause := GetProcAddress(FLibHandle, 'libvlc_media_player_pause');
  @T_libvlc_media_player_stop := GetProcAddress(FLibHandle, 'libvlc_media_player_stop');
  @T_libvlc_audio_set_volume := GetProcAddress(FLibHandle, 'libvlc_audio_set_volume');
  @T_libvlc_media_add_option := GetProcAddress(FLibHandle, 'libvlc_media_add_option');
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
  @T_libvlc_video_get_size := GetProcAddress(FLibHandle, 'libvlc_video_get_size');
  @T_libvlc_media_player_set_hwnd := GetProcAddress(FLibHandle, 'libvlc_media_player_set_hwnd');
  @T_libvlc_media_player_get_length := GetProcAddress(FLibHandle, 'libvlc_media_player_get_length');

  if not Assigned(T_libvlc_new) or not Assigned(T_libvlc_media_new_location) then
    raise Exception.Create('Не удалось загрузить основные функции VLC');
end;

function TVlcPlayer.BuildVlcOptions: TStringList;
begin
  Result := TStringList.Create;
  try
    Result.Add('--no-video-title-show');
    Result.Add('--quiet');
    Result.Add('--no-stats');

    Result.Add(':network-caching=5000');
    Result.Add(':live-caching=5000');
    Result.Add(':file-caching=5000');

    Result.Add('--avcodec-hw=none');
    Result.Add('--drop-late-frames');
    Result.Add('--skip-frames');

    Result.Add(':avcodec-fast');
    Result.Add(':avcodec-skip-frame=0');
    Result.Add(':avcodec-skip-idct=0');

    Result.Add(':clock-synchro=0');
    Result.Add(':clock-jitter=0');

    Result.Add(':rtsp-tcp');
    Result.Add(':tcp-timeout=600000');
    Result.Add(':ipv4-timeout=600000');

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

    if FAdjustedCache then
    begin
      Result.Add(':network-caching=8000');
      Result.Add(':live-caching=8000');
    end;

  except
    Result.Free;
    raise;
  end;
end;

procedure TVlcPlayer.SetupEventHandlers;
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

procedure TVlcPlayer.TryAlternativeFormats;
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
      Exit;
    except
    end;
  end;
end;

procedure TVlcPlayer.SetState(Value: TVlcState);
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
          if FFrameTimer <> nil then
            FFrameTimer.Enabled := True;
          if Assigned(FOnPlaying) then FOnPlaying(Self);
        end;
      vlcPaused:
        begin
          if FFrameTimer <> nil then
            FFrameTimer.Enabled := False;
          if Assigned(FOnPaused) then FOnPaused(Self);
        end;
      vlcStopped:
        begin
          if FFrameTimer <> nil then
            FFrameTimer.Enabled := False;
          if Assigned(FOnStopped) then FOnStopped(Self);
        end;
      vlcError:
        begin
          if FFrameTimer <> nil then
            FFrameTimer.Enabled := False;
        end;
    end;

    if Assigned(FOnStateChanged) then
      FOnStateChanged(Self);
  end;
end;

procedure TVlcPlayer.FreeVLC;
begin
  if Assigned(FFrameTimer) then
    FFrameTimer.Enabled := False;

  Stop;

  if Assigned(FPlayer) then
  begin
    try
      T_libvlc_media_player_release(FPlayer);
    except
    end;
    FPlayer := nil;
  end;

  if Assigned(FMedia) then
  begin
    try
      T_libvlc_media_release(FMedia);
    except
    end;
    FMedia := nil;
  end;

  if Assigned(FInstance) then
  begin
    try
      T_libvlc_release(FInstance);
    except
    end;
    FInstance := nil;
  end;

  if FLibHandle <> 0 then
  begin
    FreeLibrary(FLibHandle);
    FLibHandle := 0;
  end;

  ClearVideoBuffer;

  SetState(vlcIdle);
end;

procedure VlcEventCallback(p_event: Pointer; user_data: Pointer); cdecl;
var
  Player: TVlcPlayer;
  EventType: Integer;
begin
  if (user_data = nil) then
    Exit;

  Player := TVlcPlayer(user_data);

  if Assigned(GDestroyedPlayers) and GDestroyedPlayers.Contains(Player) then
    Exit;

  if (Player = nil) or (csDestroying in Player.ComponentState) then
    Exit;

  try
    EventType := PInteger(p_event)^;
  except
    Exit;
  end;

  case EventType of
    libvlc_MediaPlayerPlaying:
      Player.HandlePlayingEvent;

    libvlc_MediaPlayerPaused:
      Player.HandlePausedEvent;

    libvlc_MediaPlayerStopped:
      Player.HandleStoppedEvent;

    libvlc_MediaPlayerEndReached:
      Player.HandleEndReachedEvent;

    libvlc_MediaPlayerEncounteredError:
      Player.HandleErrorEvent;

    libvlc_MediaPlayerBuffering:
      Player.HandleBufferingEvent;

    libvlc_MediaPlayerOpening:
      Player.HandleOpeningEvent;

    libvlc_MediaPlayerTimeChanged:
      Player.HandleTimeChangedEvent;

    libvlc_MediaPlayerPositionChanged:
      Player.HandlePositionChangedEvent;

    else
      begin
      end;
  end;
end;

function VlcLockCallback(opaque: Pointer; planes: PPointer): Pointer; cdecl;
begin
  Result := TVlcPlayer(opaque).LockCallback(opaque, planes);
end;

procedure VlcUnlockCallback(opaque: Pointer; picture: Pointer; planes: PPointer); cdecl;
begin
  TVlcPlayer(opaque).UnlockCallback(opaque, picture, planes);
end;

procedure VlcDisplayCallback(opaque: Pointer; picture: Pointer); cdecl;
begin
end;

procedure Register;
begin
  RegisterComponents('VLC', [TVlcPlayer]);
end;

initialization
  GDestroyedPlayers := TList<TVlcPlayer>.Create;

finalization
  if GDestroyedPlayers <> nil then
  begin
    GDestroyedPlayers.Clear;
    FreeAndNil(GDestroyedPlayers);
  end;

end.
