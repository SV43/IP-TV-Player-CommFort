unit uImageTrackBar;

interface

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, Winapi.Messages,
  Vcl.Controls, Vcl.Graphics, Vcl.Imaging.pngimage;

type
  TImageTrackBar = class(TCustomControl)
  private
    FMin, FMax, FPosition: Integer;
    FThumbFile: string;
    FTrackFile: string;
    FThumbImg: TPngImage;
    FTrackImg: TPngImage;
    FOnChange: TNotifyEvent;
    FDragging: Boolean;

    procedure SetMin(const Value: Integer);
    procedure SetMax(const Value: Integer);
    procedure SetPosition(const Value: Integer);
    procedure SetThumbFile(const Value: string);
    procedure SetTrackFile(const Value: string);

    function GetRange: Integer;
    function GetThumbWidth: Integer;
    function ValueToX(AValue: Integer): Integer;
    function XToValue(X: Integer): Integer;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure Resize; override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    // стандартные свойства
    property Align;
    property Anchors;
    property Constraints;
    property Visible;
    property Enabled;
    property ShowHint;
    property Hint;
    property TabStop default True;

    // собственные свойства
    property Min: Integer read FMin write SetMin default 0;
    property Max: Integer read FMax write SetMax default 100;
    property Position: Integer read FPosition write SetPosition default 0;
    property ThumbFile: string read FThumbFile write SetThumbFile;
    property TrackFile: string read FTrackFile write SetTrackFile;

    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('Samples', [TImageTrackBar]);
end;

{ TImageTrackBar }

constructor TImageTrackBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 200;
  Height := 40;
  DoubleBuffered := True;
  TabStop := True;
  ControlStyle := ControlStyle + [csOpaque]; // убираем собственную заливку

  FMin := 0;
  FMax := 100;
  FPosition := 0;

  FThumbImg := TPngImage.Create;
  FTrackImg := TPngImage.Create;
  FThumbFile := '';
  FTrackFile := '';
  FDragging := False;
end;

destructor TImageTrackBar.Destroy;
begin
  FreeAndNil(FThumbImg);
  FreeAndNil(FTrackImg);
  inherited;
end;

procedure TImageTrackBar.Loaded;
begin
  inherited;
  if (FThumbFile <> '') and FileExists(FThumbFile) then
    try FThumbImg.LoadFromFile(FThumbFile) except end;
  if (FTrackFile <> '') and FileExists(FTrackFile) then
    try FTrackImg.LoadFromFile(FTrackFile) except end;
end;

procedure TImageTrackBar.Resize;
begin
  inherited;
  Invalidate;
end;

procedure TImageTrackBar.SetMin(const Value: Integer);
begin
  if Value >= FMax then Exit;
  FMin := Value;
  if FPosition < FMin then
    SetPosition(FMin);
  Invalidate;
end;

procedure TImageTrackBar.SetMax(const Value: Integer);
begin
  if Value <= FMin then Exit;
  FMax := Value;
  if FPosition > FMax then
    SetPosition(FMax);
  Invalidate;
end;

procedure TImageTrackBar.SetPosition(const Value: Integer);
var
  NewPos: Integer;
begin
  NewPos := Value;
  if NewPos < FMin then NewPos := FMin;
  if NewPos > FMax then NewPos := FMax;
  if NewPos = FPosition then Exit;
  FPosition := NewPos;
  Invalidate;
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TImageTrackBar.SetThumbFile(const Value: string);
begin
  if Value = FThumbFile then Exit;
  FThumbFile := Value;
  if (FThumbFile <> '') and FileExists(FThumbFile) then
    try FThumbImg.LoadFromFile(FThumbFile) except end;
  Invalidate;
end;

procedure TImageTrackBar.SetTrackFile(const Value: string);
begin
  if Value = FTrackFile then Exit;
  FTrackFile := Value;
  if (FTrackFile <> '') and FileExists(FTrackFile) then
    try FTrackImg.LoadFromFile(FTrackFile) except end;
  Invalidate;
end;

function TImageTrackBar.GetRange: Integer;
var
  R: Integer;
begin
  R := FMax - FMin;
  if R < 1 then
    Result := 1
  else
    Result := R;
end;

function TImageTrackBar.GetThumbWidth: Integer;
begin
  if Assigned(FThumbImg) and (FThumbImg.Width > 0) then
    Result := FThumbImg.Width
  else
    Result := 12;
end;

function TImageTrackBar.ValueToX(AValue: Integer): Integer;
var
  ThumbW, LeftMargin, RightMargin, avail: Integer;
  frac: Double;
begin
  ThumbW := GetThumbWidth;
  LeftMargin := 4 + ThumbW div 2;
  RightMargin := Width - 4 - ThumbW div 2;

  avail := RightMargin - LeftMargin;
  if avail < 1 then avail := 1;

  frac := (AValue - FMin) / GetRange;
  Result := LeftMargin + Round(frac * avail);
end;

function TImageTrackBar.XToValue(X: Integer): Integer;
var
  ThumbW, LeftMargin, RightMargin, avail: Integer;
  frac: Double;
begin
  ThumbW := GetThumbWidth;
  LeftMargin := 4 + ThumbW div 2;
  RightMargin := Width - 4 - ThumbW div 2;

  avail := RightMargin - LeftMargin;
  if avail < 1 then avail := 1;

  if X < LeftMargin then X := LeftMargin;
  if X > RightMargin then X := RightMargin;

  frac := (X - LeftMargin) / avail;
  Result := FMin + Round(frac * GetRange);
  if Result < FMin then Result := FMin;
  if Result > FMax then Result := FMax;
end;

procedure TImageTrackBar.Paint;
var
  TrackH: Integer;
  trackRect: TRect;
  xThumb, yThumb, thumbLeft, thumbTop: Integer;
begin
  // нарисовать фон родителя (делает фон прозрачным)
  if Parent <> nil then
    Parent.Perform(WM_ERASEBKGND, Canvas.Handle, 0);

  // track
  if Assigned(FTrackImg) and (FTrackImg.Width > 0) and (FTrackImg.Height > 0) then
  begin
    TrackH := FTrackImg.Height;
    if TrackH > Height - 6 then TrackH := Height - 6;
    trackRect := Rect(4, (Height - TrackH) div 2, Width - 4, (Height - TrackH) div 2 + TrackH);
    Canvas.StretchDraw(trackRect, FTrackImg);
  end
  else
  begin
    yThumb := Height div 2;
    Canvas.Pen.Color := clBtnShadow;
    Canvas.MoveTo(6, yThumb);
    Canvas.LineTo(Width - 6, yThumb);
  end;

  // thumb
  xThumb := ValueToX(FPosition);
  if Assigned(FThumbImg) and (FThumbImg.Width > 0) and (FThumbImg.Height > 0) then
  begin
    thumbLeft := xThumb - FThumbImg.Width div 2;
    thumbTop := (Height - FThumbImg.Height) div 2;
    Canvas.Draw(thumbLeft, thumbTop, FThumbImg);
  end
  else
  begin
    thumbLeft := xThumb - 6;
    thumbTop := (Height div 2) - 6;
    Canvas.Brush.Color := clHighlight;
    Canvas.Pen.Color := clBlack;
    Canvas.Ellipse(thumbLeft, thumbTop, thumbLeft + 12, thumbTop + 12);
  end;
end;

procedure TImageTrackBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if Button = mbLeft then
  begin
    SetFocus;
    FDragging := True;
    Position := XToValue(X);
  end;
end;

procedure TImageTrackBar.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if FDragging then
    Position := XToValue(X);
end;

procedure TImageTrackBar.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if (Button = mbLeft) and FDragging then
  begin
    FDragging := False;
    Position := XToValue(X);
  end;
end;

procedure TImageTrackBar.KeyDown(var Key: Word; Shift: TShiftState);
var
  step: Integer;
begin
  inherited;
  step := GetRange div 10;
  if step < 1 then step := 1;

  case Key of
    VK_LEFT:
      if FPosition > FMin then Position := FPosition - 1 else Position := FMin;
    VK_RIGHT:
      if FPosition < FMax then Position := FPosition + 1 else Position := FMax;
    VK_PRIOR: // PageUp
      if FPosition + step > FMax then Position := FMax else Position := FPosition + step;
    VK_NEXT: // PageDown
      if FPosition - step < FMin then Position := FMin else Position := FPosition - step;
  end;
end;

end.
