unit FullScreenFormUnit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls,
  Vcl.Imaging.pngimage, System.Actions, Vcl.ActnList, Vcl.Touch.GestureMgr,
  Vcl.Buttons, Vcl.ComCtrls, VlcVisualComponent;

type
  TFullScreenForm = class(TForm)
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
    FOnKeyDown: TKeyEvent;
    FOnDblClick: TNotifyEvent;
    procedure CloseFFullScreen(Sender: TObject);
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

end;

procedure TFullScreenForm.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin

end;

procedure TFullScreenForm.CloseFFullScreen(Sender: TObject);
begin

    if Assigned(aFullScreenForm) then
      aFullScreenForm.Close;
end;

procedure TFullScreenForm.FormCreate(Sender: TObject);
begin
  BorderStyle := bsNone;
  FormStyle := fsStayOnTop;
  Color := clBlack;
  KeyPreview := True;
  frmStickyForm.FVlc.OnDblClick := frmStickyForm.sbFullScreenClick;

end;

procedure TFullScreenForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  // Выход по Escape
  if Key = VK_ESCAPE then
  begin
    if Assigned(aFullScreenForm) then
      aFullScreenForm.Close;
  end
end;

end.
