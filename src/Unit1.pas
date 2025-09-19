unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls,
  Vcl.StdCtrls, Vcl.Mask,
  Vcl.Buttons,  Vcl.ComCtrls;

type
  TForm1 = class(TForm)
    pcSettings: TPageControl;
    tsSettings: TTabSheet;
    tsAbout: TTabSheet;
    dePachVLC: TLabeledEdit;
    lbCCaptionChanel: TLabel;
    cbIPTVchan: TComboBox;
    edURLM3U: TLabeledEdit;
    edURLJTV: TLabeledEdit;
    pnButton: TPanel;
    btSave: TButton;
    lePachStyle: TLabeledEdit;
    procedure FormShow(Sender: TObject);
    procedure btSaveClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

uses uPlugin, uStickyForm;

procedure TForm1.btSaveClick(Sender: TObject);
begin
  reenter;
  Save;
  Close;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  GetChannels;
end;

end.
