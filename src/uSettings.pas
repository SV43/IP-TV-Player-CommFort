unit uSettings;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls,
  Vcl.StdCtrls, Vcl.Mask,Winapi.ShellAPI, Winapi.UrlMon,
  Vcl.Buttons,  Vcl.ComCtrls, Vcl.Imaging.pngimage, FileCtrl;

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
    sbPathVLC: TSpeedButton;
    sbPathTheme: TSpeedButton;
    leDebygLogPath: TLabeledEdit;
    procedure FormShow(Sender: TObject);
    procedure btSaveClick(Sender: TObject);
    procedure sbPathVLCClick(Sender: TObject);
    procedure sbPathThemeClick(Sender: TObject);

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
  leDebygLogPath.Text := path+'IPTV_Plugin\debug.log';
end;



procedure TfrmSettings.sbPathVLCClick(Sender: TObject);
var
  Dir: string;
begin
  if SelectDirectory('”кажите путь до модулей VLC', '', Dir) then
     dePachVLC.Text := Dir;
end;

procedure TfrmSettings.sbPathThemeClick(Sender: TObject);
var
  Dir: string;
begin
  if SelectDirectory('”кажите путь до шаблона', '', Dir) then
     lePachStyle.Text := Dir;
end;

end.
