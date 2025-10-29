unit uSettings;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls,
  Vcl.StdCtrls, Vcl.Mask,Winapi.ShellAPI, Winapi.UrlMon,
  Vcl.Buttons,  Vcl.ComCtrls, Vcl.Imaging.pngimage, FileCtrl, FileDownloader,
  System.IOUtils;

type
  TfrmSettings = class(TForm)
    pcSettings: TPageControl;
    tsSettings: TTabSheet;
    tsAbout: TTabSheet;
    deEpg: TLabeledEdit;
    lbCCaptionChanel: TLabel;
    cbIPTVchan: TComboBox;
    edURLM3U: TLabeledEdit;
    pnButton: TPanel;
    btSave: TButton;
    iVLC: TImage;
    lbNamePlug: TLabel;
    lbAutor: TLabel;
    llEmail: TLinkLabel;
    llGitHubSource: TLinkLabel;
    edGitHub: TEdit;
    lbYer: TLabel;
    cbJTV: TCheckBox;
    Label1: TLabel;
    leDebygLogPath: TLabeledEdit;
    Label2: TLabel;
    Label3: TLabel;
    cbLog: TCheckBox;
    lbLog: TLabel;
    btCacheClear: TButton;
    btOpenM3u: TButton;
    odM3u: TOpenDialog;
    procedure FormShow(Sender: TObject);
    procedure btSaveClick(Sender: TObject);
    procedure btCacheClearClick(Sender: TObject);
    procedure btOpenM3uClick(Sender: TObject);

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

function DeleteFolder(const FolderPath: string): Boolean;
begin
  try
    if TDirectory.Exists(FolderPath) then
    begin
      TDirectory.Delete(FolderPath, True);
      Result := True;
    end
    else
      Result := False;
  except
    Result := False;
  end;
end;

function SafeDeleteFile(const FileName: string): Boolean;
begin
  if FileExists(FileName) then
    Result := DeleteFile(FileName)
  else
    Result := True; // Файла нет - считаем что удален
end;

procedure TfrmSettings.btCacheClearClick(Sender: TObject);
begin
   DeleteFolder(path + '\IPTV_Plugin\m3u');
   DeleteFolder(path + '\IPTV_Plugin\logo-channels');
   DeleteFolder(path + '\IPTV_Plugin\epg');
   SafeDeleteFile(path + '\IPTV_Plugin\debug.log');
   ShowMessage('Кэш полностью очищен!!!');
end;

procedure TfrmSettings.btOpenM3uClick(Sender: TObject);
begin
  odM3u.Filter := 'Текстовые файлы (*.m3u)|*.m3u|Все файлы (*.*)|*.*';
  odM3u.FilterIndex := 1;
  odM3u.InitialDir := 'C:\';
  odM3u.Options := [ofFileMustExist, ofEnableSizing];

  if odM3u.Execute then
    edURLM3U.Text :=  odM3u.FileName;
end;

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



end.
