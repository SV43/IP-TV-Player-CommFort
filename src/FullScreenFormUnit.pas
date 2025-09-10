unit FullScreenFormUnit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls,
  Vcl.Imaging.pngimage, System.Actions, Vcl.ActnList, Vcl.Touch.GestureMgr,
  Vcl.Buttons,uStickyForm, Vcl.ComCtrls;

type
  TFullScreenForm = class(TForm)
    ActionList1: TActionList;
    Action1: TAction;
    GestureManager1: TGestureManager;
    procedure FormKeyPress(Sender: TObject; var Key: Char);
  private
    { Private declarations }
    procedure AppBarResize;
    procedure AppBarShow(mode: integer);
  public
    { Public declarations }
  end;

var
  FullScreenForm: TFullScreenForm;


implementation

{$R *.dfm}

Uses  Unit1;



procedure TFullScreenForm.AppBarResize;
begin

end;

procedure TFullScreenForm.AppBarShow(mode: integer);
begin

end;

procedure TFullScreenForm.FormKeyPress(Sender: TObject; var Key: Char);
begin
 Close;
end;

end.
