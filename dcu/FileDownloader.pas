unit FileDownloader;

interface

uses
  SysUtils, Classes, System.Net.HttpClient, IOUtils;

type
  TDownloadProgressEvent = procedure(Sender: TObject; ContentLength, ReadCount: Int64) of object;

  TFileDownloader = class
  private
    FHttpClient: THTTPClient;
    FDownloadPath: string;
    FOnProgress: TDownloadProgressEvent;
    function IsURL(const FilePath: string): Boolean;
    function GetLocalFilePath(const URL: string): string;
    function GetFileSize(const FilePath: string): Int64;
    function DownloadFile(const URL, LocalPath: string): Boolean;
    function CheckRemoteFileChanged(const URL: string; const LocalPath: string): Boolean;
    procedure HTTPClientReceiveData(const Sender: TObject; AContentLength, AReadCount: Int64;
      var Abort: Boolean);
    function SanitizeFileName(const FileName: string): string;
    function SanitizeDomain(const Domain: string): string;
    function ExtractSafeFileNameFromURL(const URL: string): string;
    function FindExistingFile(const URL: string): string;
    function CacheLocalFile(const LocalFilePath: string): string;
    function GetLocalFileCachePath(const OriginalPath: string): string;
    function FindCachedLocalFile(const OriginalPath: string): string;
  public
    constructor Create;
    constructor CreateWithPath(const DownloadPath: string);
    destructor Destroy; override;

    function EnsureFileAvailable(const FilePath: string): string; overload;
    function EnsureFileAvailable(const FilePath, CustomDownloadPath: string): string; overload;
    function EnsureFileAvailableEx(const FilePath: string; out WasDownloaded: Boolean): string; overload;
    function EnsureFileAvailableEx(const FilePath: string; out WasDownloaded: Boolean;
      const CustomDownloadPath: string): string; overload;

    property DownloadPath: string read FDownloadPath write FDownloadPath;
    property OnProgress: TDownloadProgressEvent read FOnProgress write FOnProgress;
  end;

// Вспомогательные функции
function IsRemoteFile(const FilePath: string): Boolean;
function DownloadFileToPath(const URL, LocalPath: string; OnProgress: TDownloadProgressEvent = nil): Boolean;

implementation

function IsRemoteFile(const FilePath: string): Boolean;
begin
  Result := False;
  if FilePath = '' then
    Exit;

  Result := (Pos('http://', LowerCase(FilePath)) = 1) or
            (Pos('https://', LowerCase(FilePath)) = 1) or
            (Pos('ftp://', LowerCase(FilePath)) = 1);
end;

function DownloadFileToPath(const URL, LocalPath: string; OnProgress: TDownloadProgressEvent = nil): Boolean;
var
  Downloader: TFileDownloader;
begin
  Downloader := TFileDownloader.Create;
  try
    Downloader.OnProgress := OnProgress;
    Result := Downloader.DownloadFile(URL, LocalPath);
  finally
    Downloader.Free;
  end;
end;

{ TFileDownloader }

constructor TFileDownloader.Create;
begin
  inherited Create;
  FHttpClient := THTTPClient.Create;
  FHttpClient.UserAgent := 'Mozilla/5.0 (compatible; Delphi HTTPClient)';
  FHttpClient.ConnectionTimeout := 10000;
  FHttpClient.ResponseTimeout := 30000;
  FHttpClient.OnReceiveData := HTTPClientReceiveData;

  // Путь по умолчанию - папка downloads рядом с exe
  FDownloadPath := ExtractFilePath(ParamStr(0)) + 'downloads\';
end;

constructor TFileDownloader.CreateWithPath(const DownloadPath: string);
begin
  Create;
  if DownloadPath <> '' then
    FDownloadPath := IncludeTrailingPathDelimiter(DownloadPath);
end;

destructor TFileDownloader.Destroy;
begin
  FHttpClient.Free;
  inherited;
end;

procedure TFileDownloader.HTTPClientReceiveData(const Sender: TObject;
  AContentLength, AReadCount: Int64; var Abort: Boolean);
begin
  if Assigned(FOnProgress) then
    FOnProgress(Sender, AContentLength, AReadCount);
end;

function TFileDownloader.SanitizeFileName(const FileName: string): string;
begin
  Result := FileName;
  if Result = '' then
    Exit;

  // Удаляем недопустимые символы из имени файла
  Result := StringReplace(Result, '\', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '/', '_', [rfReplaceAll]);
  Result := StringReplace(Result, ':', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '*', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '?', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '|', '_', [rfReplaceAll]);

  // Ограничиваем длину имени файла
  if Length(Result) > 100 then
    Result := Copy(Result, 1, 100);
end;

function TFileDownloader.SanitizeDomain(const Domain: string): string;
begin
  Result := Domain;
  if Result = '' then
    Exit;

  // Заменяем точку в домене на подчеркивание
  Result := StringReplace(Result, '.', '_', [rfReplaceAll]);

  // Также очищаем от других недопустимых символов
  Result := StringReplace(Result, '\', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '/', '_', [rfReplaceAll]);
  Result := StringReplace(Result, ':', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '*', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '?', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '|', '_', [rfReplaceAll]);
end;

function TFileDownloader.ExtractSafeFileNameFromURL(const URL: string): string;
var
  Domain, Path, FileName, Ext: string;
  i: Integer;
begin
  Result := 'downloaded_file.tmp'; // значение по умолчанию

  if URL = '' then
    Exit;

  try
    Domain := '';
    Path := '';
    FileName := '';

    // Удаляем протокол - БЕЗОПАСНО
    if Pos('http://', LowerCase(URL)) = 1 then
    begin
      if Length(URL) > 7 then
        Domain := Copy(URL, 8, MaxInt)
      else
        Domain := URL;
    end
    else if Pos('https://', LowerCase(URL)) = 1 then
    begin
      if Length(URL) > 8 then
        Domain := Copy(URL, 9, MaxInt)
      else
        Domain := URL;
    end
    else
      Domain := URL;

    // Разделяем домен и путь - БЕЗОПАСНО
    i := Pos('/', Domain);
    if i > 0 then
    begin
      if i < Length(Domain) then
        Path := Copy(Domain, i + 1, MaxInt)
      else
        Path := '';
      Domain := Copy(Domain, 1, i - 1);
    end;

    // Извлекаем имя файла из пути
    if Path <> '' then
    begin
      FileName := ExtractFileName(Path);

      // Удаляем параметры после ?
      i := Pos('?', FileName);
      if i > 0 then
        FileName := Copy(FileName, 1, i - 1);

      // Удаляем якоря после #
      i := Pos('#', FileName);
      if i > 0 then
        FileName := Copy(FileName, 1, i - 1);
    end;

    // Если имя файла не извлеклось, создаем стандартное
    if FileName = '' then
    begin
      FileName := 'downloaded_file';
      // Пытаемся определить расширение из URL
      Ext := ExtractFileExt(URL);
      if Ext <> '' then
      begin
        i := Pos('?', Ext);
        if i > 0 then
          Ext := Copy(Ext, 1, i - 1);
        i := Pos('#', Ext);
        if i > 0 then
          Ext := Copy(Ext, 1, i - 1);
        FileName := FileName + Ext;
      end
      else
        FileName := FileName + '.tmp';
    end;

    // Очищаем имя файла
    FileName := SanitizeFileName(FileName);

    // Создаем безопасный путь: sanitized_domain/sanitized_filename
    if Domain <> '' then
    begin
      // Заменяем точку в домене на подчеркивание
      Domain := SanitizeDomain(Domain);
      Result := Domain + '\' + FileName;
    end
    else
      Result := FileName;

  except
    on E: Exception do
    begin
      // В случае любой ошибки возвращаем безопасное имя
      Result := 'downloaded_file_' + FormatDateTime('yyyymmddhhnnss', Now) + '.tmp';
    end;
  end;
end;

function TFileDownloader.FindExistingFile(const URL: string): string;
var
  SearchRec: TSearchRec;
  SafeFileName, BasePath: string;
  Domain, FileName, SearchPath: string;
begin
  Result := '';

  if URL = '' then
    Exit;

  try
    // Генерируем базовое имя файла из URL
    SafeFileName := ExtractSafeFileNameFromURL(URL);
    BasePath := IncludeTrailingPathDelimiter(FDownloadPath);

    // Сначала проверяем точный путь
    if FileExists(BasePath + SafeFileName) then
    begin
      Result := BasePath + SafeFileName;
      Exit;
    end;

    // Разделяем на домен и имя файла
    Domain := ExtractFilePath(SafeFileName);
    FileName := ExtractFileName(SafeFileName);

    // Если есть домен, ищем в папке домена
    if (Domain <> '') and DirectoryExists(BasePath + Domain) then
    begin
      SearchPath := BasePath + Domain;

      // Ищем все файлы в папке домена
      if FindFirst(SearchPath + '\*.*', faAnyFile, SearchRec) = 0 then
      begin
        try
          repeat
            // Пропускаем папки . и ..
            if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') and
               ((SearchRec.Attr and faDirectory) = 0) then // Только файлы
            begin
              // Проверяем, похоже ли имя файла на ожидаемое
              // Сравниваем базовые имена файлов без расширений
              if SameText(ChangeFileExt(SearchRec.Name, ''), ChangeFileExt(FileName, '')) then
              begin
                Result := SearchPath + '\' + SearchRec.Name;
                Break;
              end;
            end;
          until FindNext(SearchRec) <> 0;
        finally
          FindClose(SearchRec);
        end;
      end;
    end;

    // Если не нашли по домену, ищем во всей папке загрузок
    if Result = '' then
    begin
      if FindFirst(BasePath + '*.*', faAnyFile, SearchRec) = 0 then
      begin
        try
          repeat
            if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') and
               ((SearchRec.Attr and faDirectory) = 0) then // Только файлы, не папки
            begin
              // Сравниваем базовые имена файлов
              if SameText(ChangeFileExt(SearchRec.Name, ''), ChangeFileExt(FileName, '')) then
              begin
                Result := BasePath + SearchRec.Name;
                Break;
              end;
            end;
          until FindNext(SearchRec) <> 0;
        finally
          FindClose(SearchRec);
        end;
      end;
    end;

  except
    // В случае ошибки возвращаем пустую строку
    Result := '';
  end;
end;

function TFileDownloader.GetLocalFileCachePath(const OriginalPath: string): string;
var
  FileName, SafeFileName, LocalCachePath: string;
begin
  if OriginalPath = '' then
  begin
    Result := '';
    Exit;
  end;

  try
    // Извлекаем имя файла из оригинального пути
    FileName := ExtractFileName(OriginalPath);

    // Очищаем имя файла
    SafeFileName := SanitizeFileName(FileName);

    // Создаем путь в папке local
    LocalCachePath := IncludeTrailingPathDelimiter(FDownloadPath) + 'local\';

    // Добавляем подпапку на основе хеша для распределения файлов
    // Это предотвращает слишком много файлов в одной папке
    if SafeFileName <> '' then
    begin
      // Используем первый символ имени файла как подпапку
      var SubFolder := '';
      if Length(SafeFileName) > 0 then
      begin
        SubFolder := LowerCase(SafeFileName[1]);
        if not CharInSet(SafeFileName[1], ['a'..'z', 'A'..'Z', '0'..'9']) then
          SubFolder := 'other';
      end
      else
        SubFolder := 'other';

      LocalCachePath := LocalCachePath + SubFolder + '\';
    end;

    Result := LocalCachePath + SafeFileName;

  except
    on E: Exception do
    begin
      // В случае ошибки создаем временное имя
      Result := IncludeTrailingPathDelimiter(FDownloadPath) + 'local\temp_' +
                FormatDateTime('yyyymmddhhnnss', Now) + '.tmp';
    end;
  end;
end;

function TFileDownloader.FindCachedLocalFile(const OriginalPath: string): string;
var
  SearchRec: TSearchRec;
  CachePath, SearchFileName, LocalCacheBase: string;
begin
  Result := '';

  if OriginalPath = '' then
    Exit;

  try
    var OriginalFileName := ExtractFileName(OriginalPath);
    var SafeFileName := SanitizeFileName(OriginalFileName);

    if SafeFileName = '' then
      Exit;

    LocalCacheBase := IncludeTrailingPathDelimiter(FDownloadPath) + 'local\';

    // Ищем файл во всех подпапках local
    if FindFirst(LocalCacheBase + '*.*', faDirectory, SearchRec) = 0 then
    begin
      try
        repeat
          if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') and
             ((SearchRec.Attr and faDirectory) <> 0) then // Только папки
          begin
            CachePath := LocalCacheBase + SearchRec.Name + '\' + SafeFileName;
            if FileExists(CachePath) then
            begin
              Result := CachePath;
              Break;
            end;
          end;
        until FindNext(SearchRec) <> 0;
      finally
        FindClose(SearchRec);
      end;
    end;

  except
    // В случае ошибки возвращаем пустую строку
    Result := '';
  end;
end;

function TFileDownloader.CacheLocalFile(const LocalFilePath: string): string;
var
  CachePath, TempPath: string;
  SourceStream, DestStream: TFileStream;
begin
  Result := '';

  if (LocalFilePath = '') or (not FileExists(LocalFilePath)) then
    Exit;

  try
    // Получаем путь для кэширования
    CachePath := GetLocalFileCachePath(LocalFilePath);

    // Если файл уже есть в кэше, проверяем его актуальность
    if FileExists(CachePath) then
    begin
      var OriginalSize := GetFileSize(LocalFilePath);
      var CachedSize := GetFileSize(CachePath);

      // Если размеры совпадают, считаем файл актуальным
      if (OriginalSize = CachedSize) and (OriginalSize > 0) then
      begin
        Result := CachePath;
        Exit;
      end;
    end;

    // Создаем папки для кэша
    ForceDirectories(ExtractFilePath(CachePath));

    // Создаем временный файл для безопасного копирования
    TempPath := CachePath + '.copying';

    // Копируем файл
    SourceStream := TFileStream.Create(LocalFilePath, fmOpenRead or fmShareDenyWrite);
    try
      DestStream := TFileStream.Create(TempPath, fmCreate);
      try
        DestStream.CopyFrom(SourceStream, 0);
      finally
        DestStream.Free;
      end;
    finally
      SourceStream.Free;
    end;

    // Заменяем старый кэшированный файл
    if FileExists(CachePath) then
      DeleteFile(PChar(CachePath));

    if RenameFile(TempPath, CachePath) then
      Result := CachePath
    else
    begin
      // Если переименование не удалось, удаляем временный файл
      if FileExists(TempPath) then
        DeleteFile(PChar(TempPath));
      Result := '';
    end;

  except
    on E: Exception do
    begin
      // Удаляем временный файл в случае ошибки
      if FileExists(TempPath) then
        DeleteFile(PChar(TempPath));
      Result := '';
    end;
  end;
end;

function TFileDownloader.IsURL(const FilePath: string): Boolean;
begin
  Result := IsRemoteFile(FilePath);
end;

function TFileDownloader.GetLocalFilePath(const URL: string): string;
var
  SafeFileName: string;
  Path: string;
  ExistingFile: string;
begin
  if URL = '' then
  begin
    Result := '';
    Exit;
  end;

  try
    if IsURL(URL) then
    begin
      // Сначала ищем существующий файл
      ExistingFile := FindExistingFile(URL);
      if ExistingFile <> '' then
      begin
        Result := ExistingFile;
        Exit;
      end;

      // Если существующий файл не найден, создаем новый путь
      SafeFileName := ExtractSafeFileNameFromURL(URL);
      Path := IncludeTrailingPathDelimiter(FDownloadPath);
      Result := Path + SafeFileName;

      // Создаем папки если их нет
      ForceDirectories(ExtractFilePath(Result));
    end
    else
    begin
      // Для локального файла используем кэширование
      Result := GetLocalFileCachePath(URL);
    end;
  except
    on E: Exception do
    begin
      // В случае ошибки создаем временное имя
      Result := FDownloadPath + 'temp_' + FormatDateTime('yyyymmddhhnnss', Now) + '.tmp';
    end;
  end;
end;

function TFileDownloader.GetFileSize(const FilePath: string): Int64;
var
  FileStream: TFileStream;
begin
  Result := 0;
  if (FilePath = '') or (not FileExists(FilePath)) then
    Exit;

  try
    FileStream := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyNone);
    try
      Result := FileStream.Size;
    finally
      FileStream.Free;
    end;
  except
    Result := 0;
  end;
end;

function TFileDownloader.CheckRemoteFileChanged(const URL: string; const LocalPath: string): Boolean;
var
  HeadResponse: IHTTPResponse;
  LocalSize, RemoteSize: Int64;
begin
  Result := True; // По умолчанию считаем, что файл изменился

  if (URL = '') or (not FileExists(LocalPath)) then
    Exit(True);

  try
    // Отправляем HEAD запрос для получения информации о файле
    HeadResponse := FHttpClient.Head(URL);

    if HeadResponse.StatusCode = 200 then
    begin
      // Проверяем размер файла
      LocalSize := GetFileSize(LocalPath);
      RemoteSize := HeadResponse.ContentLength;

      // Если размер разный, файл точно изменился
      Result := (LocalSize <> RemoteSize);
    end;

  except
    // В случае сетевой ошибки считаем, что файл не изменился (используем локальную версию)
    Result := False;
  end;
end;

function TFileDownloader.DownloadFile(const URL, LocalPath: string): Boolean;
var
  Response: IHTTPResponse;
  Stream: TFileStream;
  TempPath: string;
  SourceStream, DestStream: TFileStream;
begin
  Result := False;

  if (URL = '') or (LocalPath = '') then
    Exit;

  // Создаем безопасное имя для временного файла
  TempPath := ChangeFileExt(LocalPath, '.downloading');

  try
    // Создаем папку, если её нет (рекурсивно)
    ForceDirectories(ExtractFilePath(LocalPath));

    // Скачиваем во временный файл
    Stream := TFileStream.Create(TempPath, fmCreate);
    try
      Response := FHttpClient.Get(URL, Stream);
      Result := (Response.StatusCode >= 200) and (Response.StatusCode < 300);

      if not Result then
        raise Exception.CreateFmt('HTTP error %d: %s',
          [Response.StatusCode, Response.StatusText]);
    finally
      Stream.Free;
    end;

    // Если скачивание успешно, заменяем старый файл
    if Result then
    begin
      // Удаляем старый файл если существует
      if FileExists(LocalPath) then
        DeleteFile(PChar(LocalPath));

      // Переименовываем временный файл
      if not RenameFile(TempPath, LocalPath) then
      begin
        // Если переименование не удалось, копируем файл вручную
        SourceStream := TFileStream.Create(TempPath, fmOpenRead or fmShareDenyWrite);
        try
          DestStream := TFileStream.Create(LocalPath, fmCreate);
          try
            DestStream.CopyFrom(SourceStream, 0);
          finally
            DestStream.Free;
          end;
        finally
          SourceStream.Free;
        end;
        DeleteFile(PChar(TempPath));
      end;
    end;

  except
    on E: Exception do
    begin
      // Удаляем временный файл в случае ошибки
      if FileExists(TempPath) then
        DeleteFile(PChar(TempPath));
      raise;
    end;
  end;
end;

function TFileDownloader.EnsureFileAvailable(const FilePath: string): string;
var
  WasDownloaded: Boolean;
begin
  Result := EnsureFileAvailableEx(FilePath, WasDownloaded);
end;

function TFileDownloader.EnsureFileAvailable(const FilePath, CustomDownloadPath: string): string;
var
  WasDownloaded: Boolean;
  OldPath: string;
begin
  if FilePath = '' then
  begin
    Result := '';
    Exit;
  end;

  // Сохраняем текущий путь и временно устанавливаем новый
  OldPath := FDownloadPath;
  try
    if CustomDownloadPath <> '' then
      FDownloadPath := IncludeTrailingPathDelimiter(CustomDownloadPath);
    Result := EnsureFileAvailableEx(FilePath, WasDownloaded);
  finally
    FDownloadPath := OldPath;
  end;
end;

function TFileDownloader.EnsureFileAvailableEx(const FilePath: string;
  out WasDownloaded: Boolean): string;
var
  LocalPath: string;
  IsRemote: Boolean;
  OldSize, NewSize: Int64;
  NeedsDownload: Boolean;
  CachedLocalFile: string;
begin
  WasDownloaded := False;
  Result := '';

  if FilePath = '' then
    Exit;

  try
    IsRemote := IsURL(FilePath);

    if IsRemote then
    begin
      // Логика для удаленных файлов (без изменений)
      LocalPath := GetLocalFilePath(FilePath);

      if FileExists(LocalPath) then
      begin
        NeedsDownload := CheckRemoteFileChanged(FilePath, LocalPath);

        if NeedsDownload then
        begin
          OldSize := GetFileSize(LocalPath);
          if DownloadFile(FilePath, LocalPath) then
          begin
            NewSize := GetFileSize(LocalPath);
            WasDownloaded := (OldSize <> NewSize);
          end;
        end;
      end
      else
      begin
        if DownloadFile(FilePath, LocalPath) then
          WasDownloaded := True;
      end;

      Result := LocalPath;
    end
    else
    begin
      // Локальный файл - простая логика
      if FileExists(FilePath) then
      begin
        // Файл существует - используем его и обновляем кэш
        Result := CacheLocalFile(FilePath);
        WasDownloaded := (Result <> '');

        // Если кэширование не удалось, все равно возвращаем оригинальный путь
        if Result = '' then
          Result := FilePath;
      end
      else
      begin
        // Файл не существует - ищем в кэше
        CachedLocalFile := FindCachedLocalFile(FilePath);

        if (CachedLocalFile <> '') and FileExists(CachedLocalFile) then
        begin
          // Нашли в кэше - используем его
          Result := CachedLocalFile;
          WasDownloaded := False;
        end
        else
        begin
          // Не нашли ни в оригинале, ни в кэше
          Result := '';
        end;
      end;
    end;

  except
    on E: Exception do
    begin
      Result := '';
    end;
  end;
end;

function TFileDownloader.EnsureFileAvailableEx(const FilePath: string;
  out WasDownloaded: Boolean; const CustomDownloadPath: string): string;
var
  OldPath: string;
begin
  Result := '';

  if FilePath = '' then
    Exit;

  // Сохраняем текущий путь и временно устанавливаем новый
  OldPath := FDownloadPath;
  try
    if CustomDownloadPath <> '' then
      FDownloadPath := IncludeTrailingPathDelimiter(CustomDownloadPath);
    Result := EnsureFileAvailableEx(FilePath, WasDownloaded);
  finally
    FDownloadPath := OldPath;
  end;
end;

end.
