unit uSettings;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls,
  Vcl.StdCtrls, Vcl.Mask,Winapi.ShellAPI, Winapi.UrlMon,
  Vcl.Buttons,  Vcl.ComCtrls, Vcl.Imaging.pngimage;

type
  TfrmSettings = class(TForm)
    pcSettings: TPageControl;
    tsSettings: TTabSheet;
    tsAbout: TTabSheet;
    dePachVLC: TLabeledEdit;
    lbCCaptionChanel: TLabel;
    cbIPTVchan: TComboBox;
    edURLM3U: TLabeledEdit;
    pnButton: TPanel;
    btSave: TButton;
    lePachStyle: TLabeledEdit;
    iVLC: TImage;
    lbNamePlug: TLabel;
    lbAutor: TLabel;
    llEmail: TLinkLabel;
    llGitHubSource: TLinkLabel;
    edGitHub: TEdit;
    lbYer: TLabel;
    cbJTV: TCheckBox;
    Label1: TLabel;
    procedure FormShow(Sender: TObject);
    procedure btSaveClick(Sender: TObject);

  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmSettings: TfrmSettings;

implementation

{$R *.dfm}

uses uPlugin, uStickyForm;

procedure TfrmSettings.btSaveClick(Sender: TObject);
begin
  reenter;
  Save;
  Close;
end;

procedure TfrmSettings.FormShow(Sender: TObject);
begin
  GetChannels;
end;



end.
