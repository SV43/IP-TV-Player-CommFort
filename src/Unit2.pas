unit Unit2;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, IdComponent, IdBaseComponent,
  IdTCPConnection, IdTCPClient, IdHTTP, Vcl.ComCtrls, acProgressBar,
  Vcl.StdCtrls, sLabel, Vcl.ExtCtrls, sevenzip;

type
  TForm2 = class(TForm)
    sLabel1: TsLabel;
    sProgressBar1: TsProgressBar;
    IdHTTP1: TIdHTTP;
    Timer1: TTimer;
    procedure IdHTTP1Work(ASender: TObject; AWorkMode: TWorkMode;
      AWorkCount: Int64);
    procedure IdHTTP1WorkBegin(ASender: TObject; AWorkMode: TWorkMode;
      AWorkCountMax: Int64);
    procedure IdHTTP1WorkEnd(ASender: TObject; AWorkMode: TWorkMode);
    procedure Timer1Timer(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form2: TForm2;
  URL_DLL:String='http://4it.denfofanov.pe.hu/VLC.rar';

implementation

{$R *.dfm}

uses Unit1;

function OpenZip(Dir:String):String;
begin
   with CreateInArchive(CLSID_CFormatZip) do
   begin
     OpenFile(Dir+'VLC.rar');
     ExtractTo(Dir);
   end;
end;


procedure TForm2.IdHTTP1Work(ASender: TObject; AWorkMode: TWorkMode;
  AWorkCount: Int64);
begin
 sProgressBar1.Position:=AWorkCount;//количество скачаного на данный момент
end;

procedure TForm2.IdHTTP1WorkBegin(ASender: TObject; AWorkMode: TWorkMode;
  AWorkCountMax: Int64);
begin
sProgressBar1.Position:=0;
sProgressBar1.max:=AWorkCountMax;//Размер файла
end;

procedure TForm2.IdHTTP1WorkEnd(ASender: TObject; AWorkMode: TWorkMode);
begin
sProgressBar1.Position:=0;
end;

procedure TForm2.Timer1Timer(Sender: TObject);
var
LoadStream:TMemoryStream;
begin
 LoadStream := TMemoryStream.Create; // выделение памяти под переменную
 idHTTP1.Get(URL_DLL, LoadStream); // загрузка в поток данных из сети
 LoadStream.SaveToFile(Form1.sDirectoryEdit1.text+'\VLC.rar'); // сохраняем данные из потока на жестком диске
 LoadStream.Free; // освобождаем память
 OpenZip(Form1.sDirectoryEdit1.text+'\VLC\');
 Timer1.Enabled:=false;
 Close;
end;

end.
