unit ChannelCard;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Graphics, Winapi.Windows,
  Vcl.ExtCtrls, Vcl.Imaging.pngimage, System.Generics.Collections,
  System.DateUtils, System.Math;

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
    TVGShift: Integer;
    GroupTitle: string;
    CurrentTitle: string;
    CurrentStart: TDateTime;
    CurrentStop: TDateTime;
    EPG: TList<TEPGItem>;
    constructor Create;
    destructor Destroy; override;
  end;

  TChannelCard = class(TCustomControl)
  private
    FChannel: TChannelInfo;
    FLogo: TPngImage;
    FLogoPath: string;
    FSelected: Boolean;
    FOnChannelClick: TNotifyEvent;
    procedure SetChannel(const Value: TChannelInfo);
    procedure SetSelected(const Value: Boolean);
    procedure DrawLogo(Canvas: TCanvas; const Rect: TRect);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LoadLogo(const LogoPath: string);
  published
    property Channel: TChannelInfo read FChannel write SetChannel;
    property Selected: Boolean read FSelected write SetSelected;
    property OnChannelClick: TNotifyEvent read FOnChannelClick write FOnChannelClick;
    property Align;
    property Anchors;
    property Enabled;
    property Visible;
    property OnClick;
    property OnDblClick;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
  end;

  TChannelCards = class(TCustomControl)
  private
    FChannels: TList<TChannelInfo>;
    FSelectedIndex: Integer;
    FItemHeight: Integer;
    FOnChannelClick: TNotifyEvent;
    procedure SetSelectedIndex(const Value: Integer);
    procedure SetItemHeight(const Value: Integer);
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AddChannel(Channel: TChannelInfo);
    procedure Clear;
    function GetChannelAtPos(X, Y: Integer): TChannelInfo;
    procedure UpdateCard(Index: Integer);
  published
    property Channels: TList<TChannelInfo> read FChannels;
    property SelectedIndex: Integer read FSelectedIndex write SetSelectedIndex;
    property ItemHeight: Integer read FItemHeight write SetItemHeight default 80;
    property OnChannelClick: TNotifyEvent read FOnChannelClick write FOnChannelClick;
    property Align;
    property Anchors;
    property Enabled;
    property Visible;
    property Color;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('IPTV', [TChannelCards]);
end;

{ TChannelInfo }

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

{ TChannelCard }

constructor TChannelCard.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FLogo := TPngImage.Create;
  FSelected := False;
  Width := 300;
  Height := 80;
  DoubleBuffered := True;
end;

destructor TChannelCard.Destroy;
begin
  FLogo.Free;
  inherited;
end;

procedure TChannelCard.DrawLogo(Canvas: TCanvas; const Rect: TRect);
var
  ScaleX, ScaleY, Scale: Double;
  NewWidth, NewHeight: Integer;
  X, Y: Integer;
  DestRect: TRect;
begin
  if (FLogo = nil) or FLogo.Empty then
    Exit;

  // Рассчитываем масштаб для сохранения пропорций
  ScaleX := (Rect.Right - Rect.Left) / FLogo.Width;
  ScaleY := (Rect.Bottom - Rect.Top) / FLogo.Height;
  Scale := System.Math.Min(ScaleX, ScaleY);

  NewWidth := Round(FLogo.Width * Scale);
  NewHeight := Round(FLogo.Height * Scale);

  // Центрируем изображение
  X := Rect.Left + ((Rect.Right - Rect.Left) - NewWidth) div 2;
  Y := Rect.Top + ((Rect.Bottom - Rect.Top) - NewHeight) div 2;

  DestRect := System.Classes.Rect(X, Y, X + NewWidth, Y + NewHeight);

  // Устанавливаем высокое качество отрисовки
  SetStretchBltMode(Canvas.Handle, HALFTONE);
  SetBrushOrgEx(Canvas.Handle, 0, 0, nil);

  // Рисуем PNG
  FLogo.Draw(Canvas, DestRect);
end;

procedure TChannelCard.LoadLogo(const LogoPath: string);
begin
  if FileExists(LogoPath) then
  begin
    try
      FLogo.LoadFromFile(LogoPath);
      FLogoPath := LogoPath;
      Invalidate;
    except
      on E: Exception do
      begin
        // Логируем ошибку загрузки логотипа
      end;
    end;
  end;
end;

procedure TChannelCard.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if Assigned(FOnChannelClick) then
    FOnChannelClick(Self);
end;

procedure TChannelCard.Paint;
var
  LogoRect, TextRect: TRect;
  OldFontSize: Integer;
  TextColor, GrayTextColor: TColor;
  i: Integer;
  NowDT: TDateTime;
  CurrEPG, NextEPG: TEPGItem;
  HasCurr: Boolean;
  ShiftText, TimeRange: string;
  EPGStartDT, EPGStopDT: TDateTime;
begin
  // Фон
  if FSelected then
  begin
    Canvas.Brush.Color := clHighlight;
    TextColor := clHighlightText;
    GrayTextColor := clSilver;
  end
  else
  begin
    Canvas.Brush.Color := Color;
    TextColor := clWindowText;
    GrayTextColor := clGrayText;
  end;

  Canvas.FillRect(ClientRect);

  // Область для логотипа
  LogoRect := ClientRect;
  LogoRect.Right := LogoRect.Left + 50;
  LogoRect.Bottom := LogoRect.Top + 50;
  LogoRect.Top := LogoRect.Top + (ClientRect.Bottom - ClientRect.Top - 50) div 2;
  LogoRect.Bottom := LogoRect.Top + 50;

  // Рисуем логотип
  DrawLogo(Canvas, LogoRect);

  // Область для текста
  TextRect := ClientRect;
  TextRect.Left := LogoRect.Right + 8;

  OldFontSize := Canvas.Font.Size;

  // Название канала
  Canvas.Font.Color := TextColor;
  Canvas.Font.Style := [fsBold];
  Canvas.TextOut(TextRect.Left, TextRect.Top + 6, FChannel.Name);

  // Группа канала
  Canvas.Font.Size := OldFontSize - 1;
  Canvas.Font.Style := [];
  Canvas.Font.Color := GrayTextColor;

  if FChannel.GroupTitle <> '' then
    Canvas.TextOut(TextRect.Left, TextRect.Top + 24, 'Группа: ' + FChannel.GroupTitle)
  else
    Canvas.TextOut(TextRect.Left, TextRect.Top + 24, 'Группа: не указана');

  // Восстанавливаем размер шрифта
  Canvas.Font.Size := OldFontSize;

  // Обработка EPG
  HasCurr := False;
  NowDT := Now;

  // Форматируем текст сдвига
  if FChannel.TVGShift <> 0 then
  begin
    if FChannel.TVGShift > 0 then
      ShiftText := Format('+%d ч', [FChannel.TVGShift])
    else
      ShiftText := Format('%d ч', [FChannel.TVGShift]);
  end
  else
    ShiftText := '';

  CurrEPG := Default(TEPGItem);
  NextEPG := Default(TEPGItem);

  if Assigned(FChannel.EPG) then
  begin
    for i := 0 to FChannel.EPG.Count - 1 do
    begin
      EPGStartDT := IncHour(FChannel.EPG[i].StartDT, FChannel.TVGShift);
      EPGStopDT := IncHour(FChannel.EPG[i].StopDT, FChannel.TVGShift);

      if (EPGStartDT <= NowDT) and (EPGStopDT > NowDT) then
      begin
        CurrEPG := FChannel.EPG[i];
        CurrEPG.StartDT := EPGStartDT;
        CurrEPG.StopDT := EPGStopDT;

        if i + 1 < FChannel.EPG.Count then
        begin
          NextEPG := FChannel.EPG[i + 1];
          NextEPG.StartDT := IncHour(NextEPG.StartDT, FChannel.TVGShift);
          NextEPG.StopDT := IncHour(NextEPG.StopDT, FChannel.TVGShift);
        end;

        HasCurr := True;
        Break;
      end;
    end;
  end;

  // Уменьшаем шрифт для EPG
  Canvas.Font.Size := OldFontSize - 1;
  Canvas.Font.Style := [];
  Canvas.Font.Color := GrayTextColor;

  TextRect.Top := TextRect.Top + 42;

  if HasCurr then
  begin
    TimeRange := FormatDateTime('hh:nn', CurrEPG.StartDT) + ' - ' +
                 FormatDateTime('hh:nn', CurrEPG.StopDT);

    if FChannel.TVGShift <> 0 then
    begin
      Canvas.TextOut(TextRect.Left, TextRect.Top,
        Format('%s (%s) [сдвиг %s]', [CurrEPG.Title, TimeRange, ShiftText]));
    end
    else
    begin
      Canvas.TextOut(TextRect.Left, TextRect.Top,
        Format('%s (%s)', [CurrEPG.Title, TimeRange]));
    end;

    if (NextEPG.Title <> '') and (TextRect.Top + 32 <= ClientRect.Bottom) then
      Canvas.TextOut(TextRect.Left, TextRect.Top + 16,
        Format('Следом: %s (%s)', [NextEPG.Title, FormatDateTime('hh:nn', NextEPG.StartDT)]));
  end
  else
  begin
    if FChannel.TVGShift <> 0 then
      Canvas.TextOut(TextRect.Left, TextRect.Top,
        Format('Нет актуальных данных [сдвиг %s]', [ShiftText]))
    else
      Canvas.TextOut(TextRect.Left, TextRect.Top, 'Нет актуальных данных');
  end;

  // Восстанавливаем размер шрифта
  Canvas.Font.Size := OldFontSize;

  // Рамка если выделено
  if FSelected then
  begin
    Canvas.Pen.Color := clHighlight;
    Canvas.Pen.Width := 2;
    Canvas.Brush.Style := bsClear;
    Canvas.Rectangle(ClientRect);
    Canvas.Brush.Style := bsSolid;
  end;
end;

procedure TChannelCard.SetChannel(const Value: TChannelInfo);
begin
  FChannel := Value;
  Invalidate;
end;

procedure TChannelCard.SetSelected(const Value: Boolean);
begin
  if FSelected <> Value then
  begin
    FSelected := Value;
    Invalidate;
  end;
end;

{ TChannelCards }

constructor TChannelCards.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FChannels := TList<TChannelInfo>.Create;
  FSelectedIndex := -1;
  FItemHeight := 80;
  DoubleBuffered := True;
  ControlStyle := ControlStyle + [csOpaque];
  Width := 300;
  Height := 400;
end;

destructor TChannelCards.Destroy;
begin
  Clear;
  FChannels.Free;
  inherited;
end;

procedure TChannelCards.AddChannel(Channel: TChannelInfo);
begin
  FChannels.Add(Channel);
  Invalidate;
end;

procedure TChannelCards.Clear;
var
  i: Integer;
begin
  for i := 0 to FChannels.Count - 1 do
    FChannels[i].Free;
  FChannels.Clear;
  FSelectedIndex := -1;
  Invalidate;
end;

function TChannelCards.GetChannelAtPos(X, Y: Integer): TChannelInfo;
var
  Index: Integer;
begin
  Result := nil;
  Index := Y div FItemHeight;
  if (Index >= 0) and (Index < FChannels.Count) then
    Result := FChannels[Index];
end;

procedure TChannelCards.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Channel: TChannelInfo;
begin
  inherited;
  Channel := GetChannelAtPos(X, Y);
  if Channel <> nil then
  begin
    SelectedIndex := Y div FItemHeight;
    if Assigned(FOnChannelClick) then
      FOnChannelClick(Self);
  end;
end;

procedure TChannelCards.Paint;
var
  i: Integer;
  CardRect: TRect;
  TempCard: TChannelCard;
begin
  // Фон
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);

  // Рисуем карточки
  for i := 0 to FChannels.Count - 1 do
  begin
    CardRect := System.Classes.Rect(0, i * FItemHeight, Width, (i + 1) * FItemHeight);

    // Создаем временную карточку для отрисовки
    TempCard := TChannelCard.Create(nil);
    try
      TempCard.Width := CardRect.Right - CardRect.Left;
      TempCard.Height := CardRect.Bottom - CardRect.Top;
      TempCard.Channel := FChannels[i];
      TempCard.Selected := (i = FSelectedIndex);
      TempCard.Color := Color;

      // Отрисовываем карточку на канвасе
      TempCard.PaintTo(Canvas, CardRect.Left, CardRect.Top);
    finally
      TempCard.Free;
    end;
  end;
end;

procedure TChannelCards.Resize;
begin
  inherited;
  Invalidate;
end;

procedure TChannelCards.SetItemHeight(const Value: Integer);
begin
  if FItemHeight <> Value then
  begin
    FItemHeight := Value;
    Invalidate;
  end;
end;

procedure TChannelCards.SetSelectedIndex(const Value: Integer);
begin
  if FSelectedIndex <> Value then
  begin
    FSelectedIndex := Value;
    Invalidate;
  end;
end;

procedure TChannelCards.UpdateCard(Index: Integer);
begin
  if (Index >= 0) and (Index < FChannels.Count) then
    Invalidate;
end;

end.
