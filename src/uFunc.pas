unit uFunc;

interface

uses Windows, Classes, SysUtils;

type
  TCommFortProcess = procedure(dwPluginID : DWORD; dwID: DWORD; bOutBuffer : PAnsiChar; dwOutBufferSize : DWORD); stdcall;
  TCommFortGetData = function(dwPluginID : DWORD; dwID : DWORD; bInBuffer : PAnsiChar; dwInBufferSize : DWORD; bOutBuffer : PAnsiChar; dwOutBufferSize : DWORD): DWORD; stdcall;

  function  fReadInteger(bInBuffer : PAnsiChar; var iOffset : Integer): Integer;
  function  fReadText(bInBuffer : PAnsiChar; var iOffset : Integer): WideString;
  procedure fWriteInteger(var bOutBuffer : PAnsiChar; var iOffset  : Integer; iValue : Integer);
  procedure fWriteText(bOutBuffer : PAnsiChar; var iOffset  : Integer; uValue : WideString);
  function  fTextToAnsiString(uText : WideString) : AnsiString;
  function  fIntegerToAnsiString(iValue : Integer) : AnsiString;

  function GetCurrentChannelName(): WideString;

var
  dwPluginID : DWORD;
  CommFortProcess : TCommFortProcess;
  CommFortGetData : TCommFortGetData;

implementation


//---------------------------------------------------------------------------
function fReadInteger(bInBuffer : PAnsiChar; var iOffset : Integer): Integer; //вспомогательная функция для упрощения работы с чтением данных
begin
	CopyMemory(@Result, bInBuffer + iOffSet, 4);
	iOffset := iOffset + 4;
end;

function fReadText(bInBuffer : PAnsiChar; var iOffset : Integer): WideString; //вспомогательная функция для упрощения работы с чтением данных
 var iLength : Integer;
begin
	CopyMemory(@iLength, bInBuffer + iOffSet, 4);
	iOffset := iOffset + 4;
	SetLength(Result, iLength);
	CopyMemory(@Result[1], bInBuffer + iOffSet, iLength * 2);
	iOffset := iOffset + iLength * 2;
end;

//---------------------------------------------------------------------------
procedure fWriteInteger(var bOutBuffer : PAnsiChar; var iOffset  : Integer; iValue : Integer); //вспомогательная функция для упрощения работы с записью данных
begin
	CopyMemory(bOutBuffer + iOffSet, @iValue, 4);
	iOffset := iOffset + 4;
end;
//---------------------------------------------------------------------------
procedure fWriteText(bOutBuffer : PAnsiChar; var iOffset  : Integer; uValue : WideString); //вспомогательная функция для упрощения работы с записью данных
	var iLength : Integer;
begin
	iLength := Length(uValue);
	CopyMemory(bOutBuffer + iOffset, @iLength, 4);
	iOffset := iOffset + 4;

	CopyMemory(bOutBuffer + iOffSet, @uValue[1], iLength * 2);
	iOffset := iOffset + iLength * 2;
end;

//---------------------------------------------------------------------------
function fTextToAnsiString(uText : WideString) : AnsiString; //вспомогательная функция для упрощения работы с данными
	var iLength : Integer;
begin
	iLength := Length(uText);

	SetLength(Result, 4 + iLength * 2);

	CopyMemory(@Result[1], @iLength, 4);
	CopyMemory(PAnsiChar(Result) + 4, @uText[1], iLength * 2);
end;
//---------------------------------------------------------------------------
function fIntegerToAnsiString(iValue : Integer) : AnsiString; //вспомогательная функция для упрощения работы с данными
begin
	SetLength(Result, 4);
	CopyMemory(@Result[1], @iValue, 4);
end;

function GetCurrentChannelName(): WideString;
var iSize : Integer;
    aData : AnsiString;
    PaData : PAnsiChar;
    iReadOffset : Integer;
begin
  SetLength(Result, 0);
	iSize := CommFortGetData(dwPluginID, 14, nil, 0, nil, 0);
  if iSize > 0 then
    begin
      SetLength(aData, iSize);
      PaData := PAnsiChar(aData);
      iSize := CommFortGetData(dwPluginID, 14, PaData, iSize, nil, 0);
      SetLength(aData, iSize);
      iReadOffset := 0;
      Result := fReadText(PaData, iReadOffset);
    end;
end;

end.
