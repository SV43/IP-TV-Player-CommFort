unit FullScreenFormUnit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls,
  Vcl.Imaging.pngimage, System.Actions, Vcl.ActnList, Vcl.Touch.GestureMgr,
  Vcl.Buttons, Vcl.ComCtrls, VlcVisualComponent;

type
  TFullScreenForm = class(TForm)
  private
    { Private declarations }
    FOnKeyDown: TKeyEvent;
    FOnDblClick: TNotifyEvent;
    procedure AppBarResize;
    procedure AppBarShow(mode: integer);
  protected
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    property OnKeyDown: TKeyEvent read FOnKeyDown write FOnKeyDown;
    property OnDblClick: TNotifyEvent read FOnDblClick write FOnDblClick;
  end;

var
  FullScreenForm: TFullScreenForm;


implementation

{$R *.dfm}

uses  uStickyForm;

procedure TFullScreenForm.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if Assigned(FOnKeyDown) then
    FOnKeyDown(Self, Key, Shift);
  inherited;
end;

procedure TFullScreenForm.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if (Button = mbLeft) and (ssDouble in Shift) then
  begin
   if Assigned(FOnDblClick) then
      FOnDblClick(Self);
  end;
  inherited;
end;

procedure TFullScreenForm.AppBarResize;
begin

end;

procedure TFullScreenForm.AppBarShow(mode: integer);
begin

end;

end.
