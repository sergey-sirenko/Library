unit uDatabase;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, uTypes, uAppPaths, uTechLog, uSafeIO, uBinaryIO,
  uIndex, uEntities, uCrypto, uAppLock;

type
  TLibraryDB = class
  private
    FPaths: TAppPaths;
    FLog: TTechLog;
    FSafeIO: TSafeIO;
    FLock: TAppLock;
    FBooks: TEntityList;
    FCopies: TEntityList;
    FReaders: TEntityList;
    FLoans: TEntityList;
    FCategories: TEntityList;
    FLocations: TEntityList;
    FUsers: TEntityList;
    FActions: TObjectList;
    FSettings: TSettings;
    FNextBookID: TId;
    FNextCopyID: TId;
    FNextReaderID: TId;
    FNextLoanID: TId;
    FNextCategoryID: TId;
    FNextLocationID: TId;
    FNextUserID: TId;
    FBooksIdx: TSearchIndex;
    FCopiesIdx: TSearchIndex;
    FReadersIdx: TSearchIndex;
    FCurrentUser: TUser;
    FRestoring: Boolean;
    procedure InitDefaults;
    procedure EnsureSeedData;
    procedure Touch(E: TEntity);
    function NewID(var Counter: TId): TId;
    procedure BeginTxn(const Files: array of string);
    procedure CommitTxn;
    procedure RecoverTxnIfNeeded;
    procedure WriteBooksStream(Sender: TObject);
    procedure WriteCopiesStream(Sender: TObject);
    procedure WriteReadersStream(Sender: TObject);
    procedure WriteLoansStream(Sender: TObject);
    procedure WriteCategoriesStream(Sender: TObject);
    procedure WriteLocationsStream(Sender: TObject);
    procedure WriteUsersStream(Sender: TObject);
    procedure WriteSettingsStream(Sender: TObject);
    function ValidateDataStream(AStream: TStream): Boolean;
    procedure LoadTable(const AFile: string; ALoader: TNotifyEvent);
    procedure LoadBooksStream(Sender: TObject);
    procedure LoadCopiesStream(Sender: TObject);
    procedure LoadReadersStream(Sender: TObject);
    procedure LoadLoansStream(Sender: TObject);
    procedure LoadCategoriesStream(Sender: TObject);
    procedure LoadLocationsStream(Sender: TObject);
    procedure LoadUsersStream(Sender: TObject);
    procedure LoadSettingsStream(Sender: TObject);
    procedure SaveBooks;
    procedure SaveCopies;
    procedure SaveReaders;
    procedure SaveLoans;
    procedure SaveCategories;
    procedure SaveLocations;
    procedure SaveUsers;
    procedure SaveSettings;
    procedure RebuildBookIndex;
    procedure RebuildCopyIndex;
    procedure RebuildReaderIndex;
    procedure LoadOrRebuildIndexes;
    procedure AppendAction(AAction: TActionType; AKind: TObjectKind; AID: TId;
      const ADesc, ABefore, AAfter: string);
    procedure LoadActions;
    procedure SaveActions;
    function ActiveAdminCount: Integer;
    function ReaderActiveLoans(AReaderID: TId): Integer;
    function BookHasLoanedCopies(ABookID: TId): Boolean;
    function CategoryHasBooks(ACategoryID: TId): Boolean;
    function LocationHasCopies(ALocationID: TId): Boolean;
    function FindCopyByInventory(const AInv: string; AExcludeID: TId): TCopy;
    function FindActiveLocationByName(const AName: string): TLocation;
  public
    constructor Create(const ARoot: string = '');
    destructor Destroy; override;
    function Open(out AError: string): Boolean;
    procedure Close;
    function Login(const ALogin, APassword: string; out AError: string): Boolean;
    procedure Logout;

    function AddCategory(const AName, ACode, ADesc: string; out AError: string): TCategory;
    function UpdateCategory(ACat: TCategory; const AName, ACode, ADesc: string; out AError: string): Boolean;
    function DeleteCategory(ACat: TCategory; out AError: string): Boolean;
    function RestoreCategory(ACat: TCategory; out AError: string): Boolean;

    function AddLocation(const AName, ADesc: string; out AError: string): TLocation;
    function UpdateLocation(ALoc: TLocation; const AName, ADesc: string; out AError: string): Boolean;
    function DeleteLocation(ALoc: TLocation; out AError: string): Boolean;
    function RestoreLocation(ALoc: TLocation; out AError: string): Boolean;

    function AddBook(const ATitle, AAuthors: string; AYear: Integer;
      const APublisher, AISBN: string; ACategoryID: TId; const ADesc, ACoverSrc: string;
      out AError: string): TBook;
    function UpdateBook(ABook: TBook; const ATitle, AAuthors: string; AYear: Integer;
      const APublisher, AISBN: string; ACategoryID: TId; const ADesc, ACoverSrc: string;
      out AError: string): Boolean;
    function DeleteBook(ABook: TBook; out AError: string): Boolean;
    function RestoreBook(ABook: TBook; out AError: string): Boolean;

    function AddCopy(ABookID: TId; const AInv, ACond: string; ALocationID: TId; const ANote: string;
      AReceived: TDateTime; out AError: string): TCopy;
    function UpdateCopy(ACopy: TCopy; const AInv, ACond: string; ALocationID: TId; const ANote: string;
      AReceived: TDateTime; AStatus: TCopyStatus; out AError: string): Boolean;
    function DeleteCopy(ACopy: TCopy; out AError: string): Boolean;
    function RestoreCopy(ACopy: TCopy; out AError: string): Boolean;

    function AddReader(const AName, APhone, AAddress, AContacts, ANote: string;
      ABirth: TDateTime; out AError: string): TReader;
    function UpdateReader(AReader: TReader; const AName, APhone, AAddress, AContacts,
      ANote: string; ABirth: TDateTime; AStatus: TReaderStatus; const ABlockReason: string;
      out AError: string): Boolean;
    function DeleteReader(AReader: TReader; out AError: string): Boolean;
    function RestoreReader(AReader: TReader; out AError: string): Boolean;

    function IssueLoan(ACopyID, AReaderID: TId; const ANote: string; out AError: string): TLoan;
    function ReturnLoan(ALoan: TLoan; const ANote: string; out AError: string): Boolean;
    function RenewLoan(ALoan: TLoan; out AError: string): Boolean;
    function UpdateLoanDueDate(ALoan: TLoan; ADueAt: TDateTime; out AError: string): Boolean;
    function UpdateLoanIssuedDate(ALoan: TLoan; AIssuedAt: TDateTime; out AError: string): Boolean;

    function AddUser(const ALogin, ADisplay, APassword: string; ARole: TUserRole;
      out AError: string): TUser;
    function UpdateUser(AUser: TUser; const ADisplay, APassword: string; ARole: TUserRole;
      AActive: Boolean; out AError: string): Boolean;
    function DeleteUser(AUser: TUser; out AError: string): Boolean;
    function RestoreUser(AUser: TUser; out AError: string): Boolean;

    function UpdateSettings(const ALibName: string; ALoanDays, AMaxBooks, AMaxRenew: Integer;
      AAutoBackup: Boolean; AUIFontSize: Integer; AInventoryStartNo: Int64;
      const AOpenRouterModel, AOpenRouterApiKey: string;
      out AError: string): Boolean;

    function ImportRecognizedBooks(AItems: TList; const ALocationName: string;
      out ASavedCount: Integer; out AError: string): Boolean;

    function CreateBackup(out APath, AError: string): Boolean;
    function RestoreBackup(const ABackupDir: string; out AError: string): Boolean;
    function MaybeAutoBackup(out APath, AError: string): Boolean;

    procedure SearchBooks(const ATitleQuery: string; const AInventoryQuery: string;
      AOut: TList; AIncludeDeleted: Boolean = False);
    procedure SearchReaders(const AQuery: string; AOut: TList; AIncludeDeleted: Boolean = False);
    function FindBook(AID: TId): TBook;
    function FindCopy(AID: TId): TCopy;
    function FindReader(AID: TId): TReader;
    function FindLoan(AID: TId): TLoan;
    function FindCategory(AID: TId): TCategory;
    function FindLocation(AID: TId): TLocation;
    function FindUser(AID: TId): TUser;
    function FindCopyByInv(const AInv: string): TCopy;
    function SuggestNextInventoryNo: string;
    procedure CollectOverdue(AOut: TList);
    function IntegrityCheck(out AError: string): Boolean;
    function CopyCover(const ASource: string; ABookID: TId): string;

    property Paths: TAppPaths read FPaths;
    property Books: TEntityList read FBooks;
    property Copies: TEntityList read FCopies;
    property Readers: TEntityList read FReaders;
    property Loans: TEntityList read FLoans;
    property Categories: TEntityList read FCategories;
    property Locations: TEntityList read FLocations;
    property Users: TEntityList read FUsers;
    property Actions: TObjectList read FActions;
    property Settings: TSettings read FSettings;
    property CurrentUser: TUser read FCurrentUser;
    property Restoring: Boolean read FRestoring;
    property TechLog: TTechLog read FLog;
  end;

implementation

uses
  FileUtil, DateUtils, StrUtils;

constructor TLibraryDB.Create(const ARoot: string);
begin
  inherited Create;
  FPaths := TAppPaths.Create(ARoot);
  FLog := TTechLog.Create(FPaths);
  FSafeIO := TSafeIO.Create(FLog);
  FLock := TAppLock.Create(FPaths);
  FBooks := TEntityList.Create(True);
  FCopies := TEntityList.Create(True);
  FReaders := TEntityList.Create(True);
  FLoans := TEntityList.Create(True);
  FCategories := TEntityList.Create(True);
  FLocations := TEntityList.Create(True);
  FUsers := TEntityList.Create(True);
  FActions := TObjectList.Create(True);
  FSettings := TSettings.Create;
  FBooksIdx := TSearchIndex.Create(FPaths.IndexFile('Books.idx'), FSafeIO, FLog);
  FCopiesIdx := TSearchIndex.Create(FPaths.IndexFile('Copies.idx'), FSafeIO, FLog);
  FReadersIdx := TSearchIndex.Create(FPaths.IndexFile('Readers.idx'), FSafeIO, FLog);
  InitDefaults;
end;

destructor TLibraryDB.Destroy;
begin
  Close;
  FBooksIdx.Free;
  FCopiesIdx.Free;
  FReadersIdx.Free;
  FSettings.Free;
  FActions.Free;
  FUsers.Free;
  FLocations.Free;
  FCategories.Free;
  FLoans.Free;
  FReaders.Free;
  FCopies.Free;
  FBooks.Free;
  FLock.Free;
  FSafeIO.Free;
  FLog.Free;
  FPaths.Free;
  inherited Destroy;
end;

procedure TLibraryDB.InitDefaults;
begin
  FSettings.LibraryName := APP_NAME;
  FSettings.LoanDays := DEFAULT_LOAN_DAYS;
  FSettings.MaxBooksPerReader := DEFAULT_MAX_BOOKS;
  FSettings.MaxRenewals := DEFAULT_MAX_RENEWALS;
  FSettings.AutoBackupEnabled := True;
  FSettings.LastBackupAt := 0;
  FSettings.UIFontSize := DEFAULT_UI_FONT_SIZE;
  FSettings.InventoryStartNo := DEFAULT_INVENTORY_START_NO;
  FSettings.OpenRouterModel := '';
  FSettings.OpenRouterApiKey := '';
  FNextBookID := 1;
  FNextCopyID := 1;
  FNextReaderID := 1;
  FNextLoanID := 1;
  FNextCategoryID := 1;
  FNextLocationID := 1;
  FNextUserID := 1;
  FCurrentUser := nil;
  FRestoring := False;
end;

procedure TLibraryDB.Touch(E: TEntity);
begin
  E.ModifiedAt := Now;
  if E.CreatedAt <= 0 then
    E.CreatedAt := E.ModifiedAt;
end;

function TLibraryDB.NewID(var Counter: TId): TId;
begin
  Result := Counter;
  Inc(Counter);
end;

function TLibraryDB.Open(out AError: string): Boolean;
begin
  Result := False;
  AError := '';
  try
    FPaths.EnsureStructure;
    RecoverTxnIfNeeded;
    if not FLock.TryAcquire(AError) then
      Exit;
    LoadTable(FPaths.DataFile('Categories.dat'), @LoadCategoriesStream);
    LoadTable(FPaths.DataFile('Locations.dat'), @LoadLocationsStream);
    LoadTable(FPaths.DataFile('Books.dat'), @LoadBooksStream);
    LoadTable(FPaths.DataFile('Copies.dat'), @LoadCopiesStream);
    LoadTable(FPaths.DataFile('Readers.dat'), @LoadReadersStream);
    LoadTable(FPaths.DataFile('Loans.dat'), @LoadLoansStream);
    LoadTable(FPaths.DataFile('Users.dat'), @LoadUsersStream);
    LoadTable(FPaths.DataFile('Settings.dat'), @LoadSettingsStream);
    LoadActions;
    EnsureSeedData;
    if not IntegrityCheck(AError) then
    begin
      FLog.Write('Ошибка целостности при открытии: ' + AError);
      { не перезаписываем повреждённые данные молча }
    end
    else
      AError := '';
    LoadOrRebuildIndexes;
    Result := True;
  except
    on E: Exception do
    begin
      AError := 'Не удалось открыть данные: ' + E.Message;
      FLog.Write(AError);
      FLock.Release;
    end;
  end;
end;

procedure TLibraryDB.Close;
begin
  if FCurrentUser <> nil then
    Logout;
  FLock.Release;
end;

procedure TLibraryDB.EnsureSeedData;
var
  U: TUser;
  C: TCategory;
  Err: string;
begin
  if FUsers.Count = 0 then
  begin
    U := TUser.Create;
    U.ID := NewID(FNextUserID);
    U.Login := DEFAULT_ADMIN_LOGIN;
    U.DisplayName := 'Администратор';
    U.Role := urAdmin;
    U.Salt := GenerateSalt;
    U.PasswordHash := HashPassword(DEFAULT_ADMIN_PASSWORD, U.Salt);
    U.Active := True;
    Touch(U);
    FUsers.Add(U);
    SaveUsers;
  end;
  if FCategories.Count = 0 then
  begin
    C := AddCategory('Общее', '', 'Категория по умолчанию', Err);
    if C = nil then
      FLog.Write('Не удалось создать категорию по умолчанию: ' + Err);
  end;
  if not FileExists(FPaths.DataFile('Settings.dat')) then
    SaveSettings;
end;

procedure TLibraryDB.BeginTxn(const Files: array of string);
var
  SL: TStringList;
  I: Integer;
begin
  SL := TStringList.Create;
  try
    SL.Add('BEGIN');
    SL.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    for I := 0 to High(Files) do
      SL.Add(Files[I]);
    SL.SaveToFile(FPaths.TxnFile);
  finally
    SL.Free;
  end;
end;

procedure TLibraryDB.CommitTxn;
begin
  if FileExists(FPaths.TxnFile) then
    DeleteFile(FPaths.TxnFile);
end;

procedure TLibraryDB.RecoverTxnIfNeeded;
var
  SL: TStringList;
  I: Integer;
  Fn, Bak: string;
begin
  if not FileExists(FPaths.TxnFile) then
    Exit;
  FLog.Write('Обнаружен незавершённый журнал транзакции, выполняется восстановление.');
  SL := TStringList.Create;
  try
    SL.LoadFromFile(FPaths.TxnFile);
    for I := 2 to SL.Count - 1 do
    begin
      Fn := FPaths.DataFile(ExtractFileName(SL[I]));
      Bak := Fn + '.bak';
      if (not FileExists(Fn)) and FileExists(Bak) then
        RenameFile(Bak, Fn);
      if FileExists(Fn + '.tmp') then
        DeleteFile(Fn + '.tmp');
    end;
  finally
    SL.Free;
  end;
  DeleteFile(FPaths.TxnFile);
end;

function TLibraryDB.ValidateDataStream(AStream: TStream): Boolean;
var
  H: TDataHeader;
  CRC: LongWord;
begin
  Result := False;
  if AStream.Size < SizeOf(H) then
    Exit;
  AStream.Position := 0;
  AStream.ReadBuffer(H, SizeOf(H));
  if not CheckDataHeader(H) then
    Exit;
  CRC := CalcCRC32(AStream, SizeOf(H), AStream.Size - SizeOf(H));
  Result := CRC = H.PayloadCRC;
end;

procedure TLibraryDB.LoadTable(const AFile: string; ALoader: TNotifyEvent);
var
  FS: TFileStream;
begin
  if not FileExists(AFile) then
    Exit;
  FS := TFileStream.Create(AFile, fmOpenRead or fmShareDenyWrite);
  try
    if not ValidateDataStream(FS) then
      raise Exception.Create('Повреждён файл данных: ' + ExtractFileName(AFile) +
        '. Восстановите каталог Data из резервной копии.');
    FS.Position := 0;
    ALoader(FS);
  finally
    FS.Free;
  end;
end;

procedure TLibraryDB.WriteBooksStream(Sender: TObject);
var
  S: TStream;
  Payload: TMemoryStream;
  H: TDataHeader;
  I: Integer;
  B: TBook;
  CRC: LongWord;
begin
  S := TStream(Sender);
  Payload := TMemoryStream.Create;
  try
    for I := 0 to FBooks.Count - 1 do
    begin
      B := TBook(FBooks[I]);
      WriteInt64(Payload, B.ID);
      WriteDateTime(Payload, B.CreatedAt);
      WriteDateTime(Payload, B.ModifiedAt);
      WriteBool(Payload, B.Deleted);
      WriteDateTime(Payload, B.DeletedAt);
      WriteInt64(Payload, B.DeletedBy);
      WriteString(Payload, B.Title);
      WriteString(Payload, B.Authors);
      WriteInteger(Payload, B.Year);
      WriteString(Payload, B.Publisher);
      WriteString(Payload, B.ISBN);
      WriteInt64(Payload, B.CategoryID);
      WriteString(Payload, B.Description);
      WriteString(Payload, B.CoverFile);
    end;
    CRC := CalcCRC32(Payload, 0, Payload.Size);
    FillDataHeader(H, FBooks.Count, FNextBookID, CRC);
    S.WriteBuffer(H, SizeOf(H));
    Payload.Position := 0;
    S.CopyFrom(Payload, Payload.Size);
  finally
    Payload.Free;
  end;
end;

procedure TLibraryDB.LoadBooksStream(Sender: TObject);
var
  S: TStream;
  H: TDataHeader;
  I: Integer;
  B: TBook;
begin
  S := TStream(Sender);
  S.ReadBuffer(H, SizeOf(H));
  FNextBookID := H.NextID;
  FBooks.Clear;
  for I := 1 to H.RecordCount do
  begin
    B := TBook.Create;
    B.ID := ReadInt64(S);
    B.CreatedAt := ReadDateTime(S);
    B.ModifiedAt := ReadDateTime(S);
    B.Deleted := ReadBool(S);
    B.DeletedAt := ReadDateTime(S);
    B.DeletedBy := ReadInt64(S);
    B.Title := ReadString(S);
    B.Authors := ReadString(S);
    B.Year := ReadInteger(S);
    B.Publisher := ReadString(S);
    B.ISBN := ReadString(S);
    B.CategoryID := ReadInt64(S);
    B.Description := ReadString(S);
    B.CoverFile := ReadString(S);
    FBooks.Add(B);
  end;
end;

procedure TLibraryDB.WriteCopiesStream(Sender: TObject);
var
  S: TStream;
  Payload: TMemoryStream;
  H: TDataHeader;
  I: Integer;
  C: TCopy;
  CRC: LongWord;
begin
  S := TStream(Sender);
  Payload := TMemoryStream.Create;
  try
    for I := 0 to FCopies.Count - 1 do
    begin
      C := TCopy(FCopies[I]);
      WriteInt64(Payload, C.ID);
      WriteDateTime(Payload, C.CreatedAt);
      WriteDateTime(Payload, C.ModifiedAt);
      WriteBool(Payload, C.Deleted);
      WriteDateTime(Payload, C.DeletedAt);
      WriteInt64(Payload, C.DeletedBy);
      WriteInt64(Payload, C.BookID);
      WriteString(Payload, C.InventoryNo);
      WriteDateTime(Payload, C.ReceivedAt);
      WriteString(Payload, C.Condition);
      WriteInt64(Payload, C.LocationID);
      WriteString(Payload, C.Note);
      WriteInteger(Payload, Ord(C.Status));
    end;
    CRC := CalcCRC32(Payload, 0, Payload.Size);
    FillDataHeader(H, FCopies.Count, FNextCopyID, CRC);
    S.WriteBuffer(H, SizeOf(H));
    Payload.Position := 0;
    S.CopyFrom(Payload, Payload.Size);
  finally
    Payload.Free;
  end;
end;

procedure TLibraryDB.LoadCopiesStream(Sender: TObject);
var
  S: TStream;
  H: TDataHeader;
  I: Integer;
  C: TCopy;
begin
  S := TStream(Sender);
  S.ReadBuffer(H, SizeOf(H));
  FNextCopyID := H.NextID;
  FCopies.Clear;
  for I := 1 to H.RecordCount do
  begin
    C := TCopy.Create;
    C.ID := ReadInt64(S);
    C.CreatedAt := ReadDateTime(S);
    C.ModifiedAt := ReadDateTime(S);
    C.Deleted := ReadBool(S);
    C.DeletedAt := ReadDateTime(S);
    C.DeletedBy := ReadInt64(S);
    C.BookID := ReadInt64(S);
    C.InventoryNo := ReadString(S);
    C.ReceivedAt := ReadDateTime(S);
    C.Condition := NormalizeCopyCondition(ReadString(S));
    if H.Version < 2 then
    begin
      ReadString(S);
      C.LocationID := 0;
    end
    else
      C.LocationID := ReadInt64(S);
    C.Note := ReadString(S);
    C.Status := TCopyStatus(ReadInteger(S));
    FCopies.Add(C);
  end;
end;

procedure TLibraryDB.WriteReadersStream(Sender: TObject);
var
  S: TStream;
  Payload: TMemoryStream;
  H: TDataHeader;
  I: Integer;
  R: TReader;
  CRC: LongWord;
begin
  S := TStream(Sender);
  Payload := TMemoryStream.Create;
  try
    for I := 0 to FReaders.Count - 1 do
    begin
      R := TReader(FReaders[I]);
      WriteInt64(Payload, R.ID);
      WriteDateTime(Payload, R.CreatedAt);
      WriteDateTime(Payload, R.ModifiedAt);
      WriteBool(Payload, R.Deleted);
      WriteDateTime(Payload, R.DeletedAt);
      WriteInt64(Payload, R.DeletedBy);
      WriteString(Payload, R.FullName);
      WriteDateTime(Payload, R.BirthDate);
      WriteString(Payload, R.Phone);
      WriteString(Payload, R.Address);
      WriteString(Payload, R.Contacts);
      WriteDateTime(Payload, R.RegisteredAt);
      WriteString(Payload, R.Note);
      WriteInteger(Payload, Ord(R.Status));
      WriteString(Payload, R.BlockReason);
    end;
    CRC := CalcCRC32(Payload, 0, Payload.Size);
    FillDataHeader(H, FReaders.Count, FNextReaderID, CRC);
    S.WriteBuffer(H, SizeOf(H));
    Payload.Position := 0;
    S.CopyFrom(Payload, Payload.Size);
  finally
    Payload.Free;
  end;
end;

procedure TLibraryDB.LoadReadersStream(Sender: TObject);
var
  S: TStream;
  H: TDataHeader;
  I: Integer;
  R: TReader;
begin
  S := TStream(Sender);
  S.ReadBuffer(H, SizeOf(H));
  FNextReaderID := H.NextID;
  FReaders.Clear;
  for I := 1 to H.RecordCount do
  begin
    R := TReader.Create;
    R.ID := ReadInt64(S);
    R.CreatedAt := ReadDateTime(S);
    R.ModifiedAt := ReadDateTime(S);
    R.Deleted := ReadBool(S);
    R.DeletedAt := ReadDateTime(S);
    R.DeletedBy := ReadInt64(S);
    R.FullName := ReadString(S);
    R.BirthDate := ReadDateTime(S);
    R.Phone := ReadString(S);
    R.Address := ReadString(S);
    R.Contacts := ReadString(S);
    R.RegisteredAt := ReadDateTime(S);
    R.Note := ReadString(S);
    R.Status := TReaderStatus(ReadInteger(S));
    R.BlockReason := ReadString(S);
    FReaders.Add(R);
  end;
end;

procedure TLibraryDB.WriteLoansStream(Sender: TObject);
var
  S: TStream;
  Payload: TMemoryStream;
  H: TDataHeader;
  I: Integer;
  L: TLoan;
  CRC: LongWord;
begin
  S := TStream(Sender);
  Payload := TMemoryStream.Create;
  try
    for I := 0 to FLoans.Count - 1 do
    begin
      L := TLoan(FLoans[I]);
      WriteInt64(Payload, L.ID);
      WriteDateTime(Payload, L.CreatedAt);
      WriteDateTime(Payload, L.ModifiedAt);
      WriteBool(Payload, L.Deleted);
      WriteDateTime(Payload, L.DeletedAt);
      WriteInt64(Payload, L.DeletedBy);
      WriteInt64(Payload, L.CopyID);
      WriteInt64(Payload, L.ReaderID);
      WriteDateTime(Payload, L.IssuedAt);
      WriteDateTime(Payload, L.DueAt);
      WriteDateTime(Payload, L.ReturnedAt);
      WriteInteger(Payload, L.RenewCount);
      WriteInt64(Payload, L.IssuedBy);
      WriteInt64(Payload, L.ReturnedBy);
      WriteInteger(Payload, Ord(L.State));
      WriteString(Payload, L.Note);
    end;
    CRC := CalcCRC32(Payload, 0, Payload.Size);
    FillDataHeader(H, FLoans.Count, FNextLoanID, CRC);
    S.WriteBuffer(H, SizeOf(H));
    Payload.Position := 0;
    S.CopyFrom(Payload, Payload.Size);
  finally
    Payload.Free;
  end;
end;

procedure TLibraryDB.LoadLoansStream(Sender: TObject);
var
  S: TStream;
  H: TDataHeader;
  I: Integer;
  L: TLoan;
begin
  S := TStream(Sender);
  S.ReadBuffer(H, SizeOf(H));
  FNextLoanID := H.NextID;
  FLoans.Clear;
  for I := 1 to H.RecordCount do
  begin
    L := TLoan.Create;
    L.ID := ReadInt64(S);
    L.CreatedAt := ReadDateTime(S);
    L.ModifiedAt := ReadDateTime(S);
    L.Deleted := ReadBool(S);
    L.DeletedAt := ReadDateTime(S);
    L.DeletedBy := ReadInt64(S);
    L.CopyID := ReadInt64(S);
    L.ReaderID := ReadInt64(S);
    L.IssuedAt := ReadDateTime(S);
    L.DueAt := ReadDateTime(S);
    L.ReturnedAt := ReadDateTime(S);
    L.RenewCount := ReadInteger(S);
    L.IssuedBy := ReadInt64(S);
    L.ReturnedBy := ReadInt64(S);
    L.State := TLoanState(ReadInteger(S));
    L.Note := ReadString(S);
    FLoans.Add(L);
  end;
end;

procedure TLibraryDB.WriteCategoriesStream(Sender: TObject);
var
  S: TStream;
  Payload: TMemoryStream;
  H: TDataHeader;
  I: Integer;
  C: TCategory;
  CRC: LongWord;
begin
  S := TStream(Sender);
  Payload := TMemoryStream.Create;
  try
    for I := 0 to FCategories.Count - 1 do
    begin
      C := TCategory(FCategories[I]);
      WriteInt64(Payload, C.ID);
      WriteDateTime(Payload, C.CreatedAt);
      WriteDateTime(Payload, C.ModifiedAt);
      WriteBool(Payload, C.Deleted);
      WriteDateTime(Payload, C.DeletedAt);
      WriteInt64(Payload, C.DeletedBy);
      WriteString(Payload, C.Name);
      { С версии формата 3 в запись категории добавлен шифр. }
      WriteString(Payload, C.Code);
      WriteString(Payload, C.Description);
    end;
    CRC := CalcCRC32(Payload, 0, Payload.Size);
    FillDataHeader(H, FCategories.Count, FNextCategoryID, CRC);
    S.WriteBuffer(H, SizeOf(H));
    Payload.Position := 0;
    S.CopyFrom(Payload, Payload.Size);
  finally
    Payload.Free;
  end;
end;

procedure TLibraryDB.LoadCategoriesStream(Sender: TObject);
var
  S: TStream;
  H: TDataHeader;
  I: Integer;
  C: TCategory;
  HasCode: Boolean;
begin
  S := TStream(Sender);
  S.ReadBuffer(H, SizeOf(H));
  FNextCategoryID := H.NextID;
  FCategories.Clear;
  { Совместимость: файлы версии 1-2 не содержат шифр в записи. }
  HasCode := H.Version >= 3;
  for I := 1 to H.RecordCount do
  begin
    C := TCategory.Create;
    C.ID := ReadInt64(S);
    C.CreatedAt := ReadDateTime(S);
    C.ModifiedAt := ReadDateTime(S);
    C.Deleted := ReadBool(S);
    C.DeletedAt := ReadDateTime(S);
    C.DeletedBy := ReadInt64(S);
    C.Name := ReadString(S);
    if HasCode then
      C.Code := ReadString(S)
    else
      C.Code := '';
    C.Description := ReadString(S);
    FCategories.Add(C);
  end;
end;

procedure TLibraryDB.WriteLocationsStream(Sender: TObject);
var
  S: TStream;
  Payload: TMemoryStream;
  H: TDataHeader;
  I: Integer;
  L: TLocation;
  CRC: LongWord;
begin
  S := TStream(Sender);
  Payload := TMemoryStream.Create;
  try
    for I := 0 to FLocations.Count - 1 do
    begin
      L := TLocation(FLocations[I]);
      WriteInt64(Payload, L.ID);
      WriteDateTime(Payload, L.CreatedAt);
      WriteDateTime(Payload, L.ModifiedAt);
      WriteBool(Payload, L.Deleted);
      WriteDateTime(Payload, L.DeletedAt);
      WriteInt64(Payload, L.DeletedBy);
      WriteString(Payload, L.Name);
      WriteString(Payload, L.Description);
    end;
    CRC := CalcCRC32(Payload, 0, Payload.Size);
    FillDataHeader(H, FLocations.Count, FNextLocationID, CRC);
    S.WriteBuffer(H, SizeOf(H));
    Payload.Position := 0;
    S.CopyFrom(Payload, Payload.Size);
  finally
    Payload.Free;
  end;
end;

procedure TLibraryDB.LoadLocationsStream(Sender: TObject);
var
  S: TStream;
  H: TDataHeader;
  I: Integer;
  L: TLocation;
begin
  S := TStream(Sender);
  S.ReadBuffer(H, SizeOf(H));
  FNextLocationID := H.NextID;
  FLocations.Clear;
  for I := 1 to H.RecordCount do
  begin
    L := TLocation.Create;
    L.ID := ReadInt64(S);
    L.CreatedAt := ReadDateTime(S);
    L.ModifiedAt := ReadDateTime(S);
    L.Deleted := ReadBool(S);
    L.DeletedAt := ReadDateTime(S);
    L.DeletedBy := ReadInt64(S);
    L.Name := ReadString(S);
    L.Description := ReadString(S);
    FLocations.Add(L);
  end;
end;

procedure TLibraryDB.WriteUsersStream(Sender: TObject);
var
  S: TStream;
  Payload: TMemoryStream;
  H: TDataHeader;
  I: Integer;
  U: TUser;
  CRC: LongWord;
begin
  S := TStream(Sender);
  Payload := TMemoryStream.Create;
  try
    for I := 0 to FUsers.Count - 1 do
    begin
      U := TUser(FUsers[I]);
      WriteInt64(Payload, U.ID);
      WriteDateTime(Payload, U.CreatedAt);
      WriteDateTime(Payload, U.ModifiedAt);
      WriteBool(Payload, U.Deleted);
      WriteDateTime(Payload, U.DeletedAt);
      WriteInt64(Payload, U.DeletedBy);
      WriteString(Payload, U.Login);
      WriteString(Payload, U.DisplayName);
      WriteInteger(Payload, Ord(U.Role));
      WriteString(Payload, U.Salt);
      WriteString(Payload, U.PasswordHash);
      WriteBool(Payload, U.Active);
      WriteDateTime(Payload, U.LastLoginAt);
    end;
    CRC := CalcCRC32(Payload, 0, Payload.Size);
    FillDataHeader(H, FUsers.Count, FNextUserID, CRC);
    S.WriteBuffer(H, SizeOf(H));
    Payload.Position := 0;
    S.CopyFrom(Payload, Payload.Size);
  finally
    Payload.Free;
  end;
end;

procedure TLibraryDB.LoadUsersStream(Sender: TObject);
var
  S: TStream;
  H: TDataHeader;
  I: Integer;
  U: TUser;
begin
  S := TStream(Sender);
  S.ReadBuffer(H, SizeOf(H));
  FNextUserID := H.NextID;
  FUsers.Clear;
  for I := 1 to H.RecordCount do
  begin
    U := TUser.Create;
    U.ID := ReadInt64(S);
    U.CreatedAt := ReadDateTime(S);
    U.ModifiedAt := ReadDateTime(S);
    U.Deleted := ReadBool(S);
    U.DeletedAt := ReadDateTime(S);
    U.DeletedBy := ReadInt64(S);
    U.Login := ReadString(S);
    U.DisplayName := ReadString(S);
    U.Role := TUserRole(ReadInteger(S));
    U.Salt := ReadString(S);
    U.PasswordHash := ReadString(S);
    U.Active := ReadBool(S);
    U.LastLoginAt := ReadDateTime(S);
    FUsers.Add(U);
  end;
end;

procedure TLibraryDB.WriteSettingsStream(Sender: TObject);
var
  S: TStream;
  Payload: TMemoryStream;
  H: TDataHeader;
  CRC: LongWord;
begin
  S := TStream(Sender);
  Payload := TMemoryStream.Create;
  try
    WriteString(Payload, FSettings.LibraryName);
    WriteInteger(Payload, FSettings.LoanDays);
    WriteInteger(Payload, FSettings.MaxBooksPerReader);
    WriteInteger(Payload, FSettings.MaxRenewals);
    WriteBool(Payload, FSettings.AutoBackupEnabled);
    WriteDateTime(Payload, FSettings.LastBackupAt);
    WriteInteger(Payload, FSettings.UIFontSize);
    WriteInt64(Payload, FSettings.InventoryStartNo);
    WriteString(Payload, FSettings.OpenRouterModel);
    WriteString(Payload, FSettings.OpenRouterApiKey);
    CRC := CalcCRC32(Payload, 0, Payload.Size);
    FillDataHeader(H, 1, 4, CRC);
    S.WriteBuffer(H, SizeOf(H));
    Payload.Position := 0;
    S.CopyFrom(Payload, Payload.Size);
  finally
    Payload.Free;
  end;
end;

procedure TLibraryDB.LoadSettingsStream(Sender: TObject);
var
  S: TStream;
  H: TDataHeader;
begin
  S := TStream(Sender);
  S.ReadBuffer(H, SizeOf(H));
  FSettings.LibraryName := ReadString(S);
  FSettings.LoanDays := ReadInteger(S);
  FSettings.MaxBooksPerReader := ReadInteger(S);
  FSettings.MaxRenewals := ReadInteger(S);
  FSettings.AutoBackupEnabled := ReadBool(S);
  FSettings.LastBackupAt := ReadDateTime(S);
  { NextID >= 2 — схема с UIFontSize; иначе остаток потока для старых файлов }
  if (H.NextID >= 2) or ((S.Size - S.Position) >= SizeOf(Integer)) then
    FSettings.UIFontSize := ReadInteger(S)
  else
    FSettings.UIFontSize := DEFAULT_UI_FONT_SIZE;
  FSettings.UIFontSize := ClampUIFontSize(FSettings.UIFontSize);
  { NextID >= 3 — схема с InventoryStartNo; иначе дефолт }
  if (H.NextID >= 3) or ((S.Size - S.Position) >= SizeOf(Int64)) then
    FSettings.InventoryStartNo := ReadInt64(S)
  else
    FSettings.InventoryStartNo := DEFAULT_INVENTORY_START_NO;
  if FSettings.InventoryStartNo < 1 then
    FSettings.InventoryStartNo := 1;
  { NextID >= 4 — настройки OpenRouter; старые файлы остаются совместимыми. }
  if (H.NextID >= 4) or ((S.Size - S.Position) >= SizeOf(LongWord)) then
    FSettings.OpenRouterModel := ReadString(S)
  else
    FSettings.OpenRouterModel := '';
  if (S.Size - S.Position) >= SizeOf(LongWord) then
    FSettings.OpenRouterApiKey := ReadString(S)
  else
    FSettings.OpenRouterApiKey := '';
end;

procedure TLibraryDB.SaveBooks;
begin
  if not FSafeIO.WriteAtomically(FPaths.DataFile('Books.dat'), @WriteBooksStream, @ValidateDataStream) then
    raise Exception.Create('Не удалось сохранить Books.dat');
  RebuildBookIndex;
end;

procedure TLibraryDB.SaveCopies;
begin
  if not FSafeIO.WriteAtomically(FPaths.DataFile('Copies.dat'), @WriteCopiesStream, @ValidateDataStream) then
    raise Exception.Create('Не удалось сохранить Copies.dat');
  RebuildCopyIndex;
end;

procedure TLibraryDB.SaveReaders;
begin
  if not FSafeIO.WriteAtomically(FPaths.DataFile('Readers.dat'), @WriteReadersStream, @ValidateDataStream) then
    raise Exception.Create('Не удалось сохранить Readers.dat');
  RebuildReaderIndex;
end;

procedure TLibraryDB.SaveLoans;
begin
  if not FSafeIO.WriteAtomically(FPaths.DataFile('Loans.dat'), @WriteLoansStream, @ValidateDataStream) then
    raise Exception.Create('Не удалось сохранить Loans.dat');
end;

procedure TLibraryDB.SaveCategories;
begin
  if not FSafeIO.WriteAtomically(FPaths.DataFile('Categories.dat'), @WriteCategoriesStream, @ValidateDataStream) then
    raise Exception.Create('Не удалось сохранить Categories.dat');
end;

procedure TLibraryDB.SaveLocations;
begin
  if not FSafeIO.WriteAtomically(FPaths.DataFile('Locations.dat'), @WriteLocationsStream, @ValidateDataStream) then
    raise Exception.Create('Не удалось сохранить Locations.dat');
end;

procedure TLibraryDB.SaveUsers;
begin
  if not FSafeIO.WriteAtomically(FPaths.DataFile('Users.dat'), @WriteUsersStream, @ValidateDataStream) then
    raise Exception.Create('Не удалось сохранить Users.dat');
end;

procedure TLibraryDB.SaveSettings;
begin
  if not FSafeIO.WriteAtomically(FPaths.DataFile('Settings.dat'), @WriteSettingsStream, @ValidateDataStream) then
    raise Exception.Create('Не удалось сохранить Settings.dat');
end;

procedure TLibraryDB.RebuildBookIndex;
var
  I: Integer;
  B: TBook;
begin
  FBooksIdx.Clear;
  for I := 0 to FBooks.Count - 1 do
  begin
    B := TBook(FBooks[I]);
    if B.Deleted then
      Continue;
    FBooksIdx.Add(B.Title, B.ID);
    FBooksIdx.Add(B.Authors, B.ID);
    FBooksIdx.Add(B.ISBN, B.ID);
  end;
  FBooksIdx.Save;
end;

procedure TLibraryDB.RebuildCopyIndex;
var
  I: Integer;
  C: TCopy;
begin
  FCopiesIdx.Clear;
  for I := 0 to FCopies.Count - 1 do
  begin
    C := TCopy(FCopies[I]);
    if C.Deleted then
      Continue;
    FCopiesIdx.Add(C.InventoryNo, C.ID);
    FCopiesIdx.Add(IntToStr(C.BookID), C.ID);
  end;
  FCopiesIdx.Save;
end;

procedure TLibraryDB.RebuildReaderIndex;
var
  I: Integer;
  R: TReader;
begin
  FReadersIdx.Clear;
  for I := 0 to FReaders.Count - 1 do
  begin
    R := TReader(FReaders[I]);
    if R.Deleted then
      Continue;
    FReadersIdx.Add(R.FullName, R.ID);
    FReadersIdx.Add(R.Phone, R.ID);
  end;
  FReadersIdx.Save;
end;

procedure TLibraryDB.LoadOrRebuildIndexes;
begin
  if not FBooksIdx.Load then
  begin
    FLog.Write('Индекс Books.idx перестраивается.');
    RebuildBookIndex;
  end;
  if not FCopiesIdx.Load then
  begin
    FLog.Write('Индекс Copies.idx перестраивается.');
    RebuildCopyIndex;
  end;
  if not FReadersIdx.Load then
  begin
    FLog.Write('Индекс Readers.idx перестраивается.');
    RebuildReaderIndex;
  end;
end;

procedure TLibraryDB.AppendAction(AAction: TActionType; AKind: TObjectKind; AID: TId;
  const ADesc, ABefore, AAfter: string);
var
  Item: TActionLogItem;
begin
  Item := TActionLogItem.Create;
  Item.When := Now;
  if FCurrentUser <> nil then
  begin
    Item.UserID := FCurrentUser.ID;
    Item.UserName := FCurrentUser.DisplayName;
  end
  else
  begin
    Item.UserID := 0;
    Item.UserName := 'система';
  end;
  Item.Action := AAction;
  Item.ObjectKind := AKind;
  Item.ObjectID := AID;
  Item.Description := ADesc;
  Item.DetailsBefore := ABefore;
  Item.DetailsAfter := AAfter;
  FActions.Add(Item);
  SaveActions;
end;

procedure TLibraryDB.SaveActions;
var
  SL: TStringList;
  I: Integer;
  A: TActionLogItem;
begin
  SL := TStringList.Create;
  try
    for I := 0 to FActions.Count - 1 do
    begin
      A := TActionLogItem(FActions[I]);
      SL.Add(Format('%.10f|%d|%s|%d|%d|%d|%s|%s|%s',
        [A.When, A.UserID, StringReplace(A.UserName, '|', '/', [rfReplaceAll]),
         Ord(A.Action), Ord(A.ObjectKind), A.ObjectID,
         StringReplace(A.Description, '|', '/', [rfReplaceAll]),
         StringReplace(A.DetailsBefore, '|', '/', [rfReplaceAll]),
         StringReplace(A.DetailsAfter, '|', '/', [rfReplaceAll])]));
    end;
    SL.SaveToFile(FPaths.ActionLogFile);
  finally
    SL.Free;
  end;
end;

procedure TLibraryDB.LoadActions;
var
  SL: TStringList;
  I: Integer;
  Parts: TStringList;
  A: TActionLogItem;
begin
  FActions.Clear;
  if not FileExists(FPaths.ActionLogFile) then
    Exit;
  SL := TStringList.Create;
  Parts := TStringList.Create;
  try
    SL.LoadFromFile(FPaths.ActionLogFile);
    Parts.Delimiter := '|';
    Parts.StrictDelimiter := True;
    for I := 0 to SL.Count - 1 do
    begin
      Parts.DelimitedText := SL[I];
      if Parts.Count < 7 then
        Continue;
      A := TActionLogItem.Create;
      A.When := StrToFloatDef(Parts[0], 0);
      A.UserID := StrToInt64Def(Parts[1], 0);
      A.UserName := Parts[2];
      A.Action := TActionType(StrToIntDef(Parts[3], 0));
      A.ObjectKind := TObjectKind(StrToIntDef(Parts[4], 0));
      A.ObjectID := StrToInt64Def(Parts[5], 0);
      A.Description := Parts[6];
      if Parts.Count > 7 then A.DetailsBefore := Parts[7];
      if Parts.Count > 8 then A.DetailsAfter := Parts[8];
      FActions.Add(A);
    end;
  finally
    Parts.Free;
    SL.Free;
  end;
end;

function TLibraryDB.Login(const ALogin, APassword: string; out AError: string): Boolean;
var
  I: Integer;
  U: TUser;
begin
  Result := False;
  AError := '';
  for I := 0 to FUsers.Count - 1 do
  begin
    U := TUser(FUsers[I]);
    if U.Deleted or (not U.Active) then
      Continue;
    if SameText(U.Login, ALogin) and VerifyPassword(APassword, U.Salt, U.PasswordHash) then
    begin
      FCurrentUser := U;
      U.LastLoginAt := Now;
      SaveUsers;
      AppendAction(atLogin, okUser, U.ID, 'Вход пользователя ' + U.DisplayName, '', '');
      Result := True;
      Exit;
    end;
  end;
  AError := 'Неверное имя пользователя или пароль.';
  AppendAction(atDenied, okUser, 0, 'Отказ во входе: ' + ALogin, '', '');
end;

procedure TLibraryDB.Logout;
begin
  if FCurrentUser <> nil then
  begin
    AppendAction(atLogout, okUser, FCurrentUser.ID, 'Выход пользователя ' + FCurrentUser.DisplayName, '', '');
    FCurrentUser := nil;
  end;
end;

function TLibraryDB.FindBook(AID: TId): TBook;
begin
  Result := TBook(FBooks.FindByID(AID));
end;

function TLibraryDB.FindCopy(AID: TId): TCopy;
begin
  Result := TCopy(FCopies.FindByID(AID));
end;

function TLibraryDB.FindReader(AID: TId): TReader;
begin
  Result := TReader(FReaders.FindByID(AID));
end;

function TLibraryDB.FindLoan(AID: TId): TLoan;
begin
  Result := TLoan(FLoans.FindByID(AID));
end;

function TLibraryDB.FindCategory(AID: TId): TCategory;
begin
  Result := TCategory(FCategories.FindByID(AID));
end;

function TLibraryDB.FindLocation(AID: TId): TLocation;
begin
  Result := TLocation(FLocations.FindByID(AID));
end;

function TLibraryDB.FindActiveLocationByName(const AName: string): TLocation;
var
  I: Integer;
  L: TLocation;
begin
  for I := 0 to FLocations.Count - 1 do
  begin
    L := TLocation(FLocations[I]);
    if (not L.Deleted) and SameText(L.Name, Trim(AName)) then
    begin
      Result := L;
      Exit;
    end;
  end;
  Result := nil;
end;

function TLibraryDB.FindUser(AID: TId): TUser;
begin
  Result := TUser(FUsers.FindByID(AID));
end;

function TLibraryDB.FindCopyByInventory(const AInv: string; AExcludeID: TId): TCopy;
var
  I: Integer;
  C: TCopy;
begin
  for I := 0 to FCopies.Count - 1 do
  begin
    C := TCopy(FCopies[I]);
    if (C.ID <> AExcludeID) and SameText(C.InventoryNo, Trim(AInv)) then
    begin
      Result := C;
      Exit;
    end;
  end;
  Result := nil;
end;

function TLibraryDB.SuggestNextInventoryNo: string;
{ Ищет первый свободный целочисленный инвентарный номер, начиная
  с FSettings.InventoryStartNo. Среди неудалённых копий собирает только
  номера, которые парсятся как Int64, и возвращает минимальное число
  в диапазоне [StartNo; ...), которое не занято. Если все числа подряд
  от StartNo заняты — возвращает max+1 (следующий за самым большим).
  Номера нечислового вида (например, «Б-1») не учитываются при поиске. }
var
  I, J, Count: Integer;
  C: TCopy;
  StartNo, V, Expected, Tmp: Int64;
  Used: array of Int64;
begin
  StartNo := FSettings.InventoryStartNo;
  if StartNo < 1 then
    StartNo := 1;
  Count := 0;
  if FCopies.Count > 0 then
  begin
    SetLength(Used, FCopies.Count);
    for I := 0 to FCopies.Count - 1 do
    begin
      C := TCopy(FCopies[I]);
      if C.Deleted then
        Continue;
      if (C.InventoryNo <> '') and TryStrToInt64(Trim(C.InventoryNo), V) and (V >= StartNo) then
      begin
        Used[Count] := V;
        Inc(Count);
      end;
    end;
  end;
  if Count = 0 then
  begin
    Result := IntToStr(StartNo);
    Exit;
  end;
  SetLength(Used, Count);
  { Сортировка вставками — массив обычно маленький, этого достаточно. }
  for I := 1 to Count - 1 do
  begin
    Tmp := Used[I];
    J := I - 1;
    while (J >= 0) and (Used[J] > Tmp) do
    begin
      Used[J + 1] := Used[J];
      Dec(J);
    end;
    Used[J + 1] := Tmp;
  end;
  Expected := StartNo;
  for I := 0 to Count - 1 do
  begin
    V := Used[I];
    if V > Expected then
    begin
      { найдена «дырка» в последовательности }
      Result := IntToStr(Expected);
      Exit;
    end;
    if V + 1 > Expected then
      Expected := V + 1;
  end;
  { все числа подряд — следующий за максимальным }
  Result := IntToStr(Expected);
end;

function TLibraryDB.FindCopyByInv(const AInv: string): TCopy;
begin
  Result := FindCopyByInventory(AInv, 0);
end;

function TLibraryDB.ActiveAdminCount: Integer;
var
  I: Integer;
  U: TUser;
begin
  Result := 0;
  for I := 0 to FUsers.Count - 1 do
  begin
    U := TUser(FUsers[I]);
    if (not U.Deleted) and U.Active and (U.Role = urAdmin) then
      Inc(Result);
  end;
end;

function TLibraryDB.ReaderActiveLoans(AReaderID: TId): Integer;
var
  I: Integer;
  L: TLoan;
begin
  Result := 0;
  for I := 0 to FLoans.Count - 1 do
  begin
    L := TLoan(FLoans[I]);
    if (not L.Deleted) and (L.ReaderID = AReaderID) and (L.State = lsLoaned) then
      Inc(Result);
  end;
end;

function TLibraryDB.BookHasLoanedCopies(ABookID: TId): Boolean;
var
  I: Integer;
  C: TCopy;
begin
  for I := 0 to FCopies.Count - 1 do
  begin
    C := TCopy(FCopies[I]);
    if (not C.Deleted) and (C.BookID = ABookID) and (C.Status = csLoaned) then
    begin
      Result := True;
      Exit;
    end;
  end;
  Result := False;
end;

function TLibraryDB.CategoryHasBooks(ACategoryID: TId): Boolean;
var
  I: Integer;
  B: TBook;
begin
  for I := 0 to FBooks.Count - 1 do
  begin
    B := TBook(FBooks[I]);
    if (not B.Deleted) and (B.CategoryID = ACategoryID) then
    begin
      Result := True;
      Exit;
    end;
  end;
  Result := False;
end;

function TLibraryDB.LocationHasCopies(ALocationID: TId): Boolean;
var
  I: Integer;
  C: TCopy;
begin
  for I := 0 to FCopies.Count - 1 do
  begin
    C := TCopy(FCopies[I]);
    if (not C.Deleted) and (C.LocationID = ALocationID) then
    begin
      Result := True;
      Exit;
    end;
  end;
  Result := False;
end;

function TLibraryDB.CopyCover(const ASource: string; ABookID: TId): string;
var
  Ext, Dest: string;
begin
  Result := '';
  if (ASource = '') or (not FileExists(ASource)) then
    Exit;
  Ext := LowerCase(ExtractFileExt(ASource));
  if (Ext <> '.jpg') and (Ext <> '.jpeg') and (Ext <> '.png') then
    raise Exception.Create('Обложка должна быть в формате JPEG или PNG.');
  if Ext = '.jpeg' then
    Ext := '.jpg';
  Dest := Format('%.6d%s', [ABookID, Ext]);
  CopyFile(ASource, FPaths.CoversDir + Dest);
  Result := Dest;
end;

function NormalizeCategoryCode(const S: string): string;
begin
  Result := Trim(S);
end;

function IsValidCategoryCode(const S: string; out AError: string): Boolean;
var
  I: Integer;
  Ch: Char;
begin
  Result := True;
  AError := '';
  if S = '' then
    Exit; { Шифр необязательный. }
  for I := 1 to Length(S) do
  begin
    Ch := S[I];
    if not (((Ch >= 'A') and (Ch <= 'Z')) or
            ((Ch >= 'a') and (Ch <= 'z')) or
            ((Ch >= '0') and (Ch <= '9')) or
            ((Ch >= 'А') and (Ch <= 'Я')) or
            ((Ch >= 'а') and (Ch <= 'я')) or
            (Ch = 'Ё') or (Ch = 'ё') or
            (Ch = '-') or (Ch = '.')) then
    begin
      AError := 'Шифр содержит недопустимый символ: «' + Ch + '». ' +
        'Допускаются латиница, кириллица, цифры, дефис и точка.';
      Result := False;
      Exit;
    end;
  end;
end;

function TLibraryDB.AddCategory(const AName, ACode, ADesc: string; out AError: string): TCategory;
var
  I: Integer;
  C: TCategory;
  CleanCode: string;
begin
  Result := nil;
  AError := '';
  if Trim(AName) = '' then
  begin
    AError := 'Укажите наименование категории.';
    Exit;
  end;
  CleanCode := NormalizeCategoryCode(ACode);
  if not IsValidCategoryCode(CleanCode, AError) then
    Exit;
  for I := 0 to FCategories.Count - 1 do
  begin
    C := TCategory(FCategories[I]);
    if (not C.Deleted) and SameText(C.Name, Trim(AName)) then
    begin
      AError := 'Категория с таким наименованием уже существует.';
      Exit;
    end;
  end;
  C := TCategory.Create;
  C.ID := NewID(FNextCategoryID);
  C.Name := Trim(AName);
  C.Code := CleanCode;
  C.Description := ADesc;
  Touch(C);
  FCategories.Add(C);
  SaveCategories;
  AppendAction(atCreate, okCategory, C.ID, 'Создана категория: ' + C.Name, '', C.Name + ' [' + C.Code + ']');
  Result := C;
end;

function TLibraryDB.UpdateCategory(ACat: TCategory; const AName, ACode, ADesc: string; out AError: string): Boolean;
var
  I: Integer;
  C: TCategory;
  Before, CleanCode: string;
begin
  Result := False;
  AError := '';
  if ACat = nil then
  begin
    AError := 'Категория не найдена.';
    Exit;
  end;
  CleanCode := NormalizeCategoryCode(ACode);
  if not IsValidCategoryCode(CleanCode, AError) then
    Exit;
  for I := 0 to FCategories.Count - 1 do
  begin
    C := TCategory(FCategories[I]);
    if (C <> ACat) and (not C.Deleted) and SameText(C.Name, Trim(AName)) then
    begin
      AError := 'Категория с таким наименованием уже существует.';
      Exit;
    end;
  end;
  Before := ACat.Name + ' [' + ACat.Code + ']';
  ACat.Name := Trim(AName);
  ACat.Code := CleanCode;
  ACat.Description := ADesc;
  Touch(ACat);
  SaveCategories;
  AppendAction(atUpdate, okCategory, ACat.ID, 'Изменена категория', Before, ACat.Name + ' [' + ACat.Code + ']');
  Result := True;
end;

function TLibraryDB.DeleteCategory(ACat: TCategory; out AError: string): Boolean;
begin
  Result := False;
  AError := '';
  if ACat = nil then
  begin
    AError := 'Категория не найдена.';
    Exit;
  end;
  if CategoryHasBooks(ACat.ID) then
  begin
    AError := 'Нельзя удалить категорию: в ней есть книги.';
    AppendAction(atDenied, okCategory, ACat.ID, AError, '', '');
    Exit;
  end;
  ACat.Deleted := True;
  ACat.DeletedAt := Now;
  if FCurrentUser <> nil then
    ACat.DeletedBy := FCurrentUser.ID;
  Touch(ACat);
  SaveCategories;
  AppendAction(atDelete, okCategory, ACat.ID, 'Удалена категория: ' + ACat.Name, '', '');
  Result := True;
end;

function TLibraryDB.RestoreCategory(ACat: TCategory; out AError: string): Boolean;
begin
  Result := False;
  AError := '';
  if ACat = nil then Exit;
  ACat.Deleted := False;
  ACat.DeletedAt := 0;
  ACat.DeletedBy := 0;
  Touch(ACat);
  SaveCategories;
  AppendAction(atRestore, okCategory, ACat.ID, 'Восстановлена категория: ' + ACat.Name, '', '');
  Result := True;
end;

function TLibraryDB.AddLocation(const AName, ADesc: string; out AError: string): TLocation;
var
  I: Integer;
  L: TLocation;
begin
  Result := nil;
  AError := '';
  if Trim(AName) = '' then
  begin
    AError := 'Укажите наименование места хранения.';
    Exit;
  end;
  for I := 0 to FLocations.Count - 1 do
  begin
    L := TLocation(FLocations[I]);
    if (not L.Deleted) and SameText(L.Name, Trim(AName)) then
    begin
      AError := 'Место хранения с таким наименованием уже существует.';
      Exit;
    end;
  end;
  L := TLocation.Create;
  L.ID := NewID(FNextLocationID);
  L.Name := Trim(AName);
  L.Description := ADesc;
  Touch(L);
  FLocations.Add(L);
  SaveLocations;
  AppendAction(atCreate, okLocation, L.ID, 'Создано место хранения: ' + L.Name, '', L.Name);
  Result := L;
end;

function TLibraryDB.UpdateLocation(ALoc: TLocation; const AName, ADesc: string; out AError: string): Boolean;
var
  I: Integer;
  L: TLocation;
  Before: string;
begin
  Result := False;
  AError := '';
  if ALoc = nil then
  begin
    AError := 'Место хранения не найдено.';
    Exit;
  end;
  if Trim(AName) = '' then
  begin
    AError := 'Укажите наименование места хранения.';
    Exit;
  end;
  for I := 0 to FLocations.Count - 1 do
  begin
    L := TLocation(FLocations[I]);
    if (L <> ALoc) and (not L.Deleted) and SameText(L.Name, Trim(AName)) then
    begin
      AError := 'Место хранения с таким наименованием уже существует.';
      Exit;
    end;
  end;
  Before := ALoc.Name;
  ALoc.Name := Trim(AName);
  ALoc.Description := ADesc;
  Touch(ALoc);
  SaveLocations;
  AppendAction(atUpdate, okLocation, ALoc.ID, 'Изменено место хранения', Before, ALoc.Name);
  Result := True;
end;

function TLibraryDB.DeleteLocation(ALoc: TLocation; out AError: string): Boolean;
begin
  Result := False;
  AError := '';
  if ALoc = nil then
  begin
    AError := 'Место хранения не найдено.';
    Exit;
  end;
  if LocationHasCopies(ALoc.ID) then
  begin
    AError := 'Нельзя удалить место хранения: оно указано у экземпляров.';
    AppendAction(atDenied, okLocation, ALoc.ID, AError, '', '');
    Exit;
  end;
  ALoc.Deleted := True;
  ALoc.DeletedAt := Now;
  if FCurrentUser <> nil then
    ALoc.DeletedBy := FCurrentUser.ID;
  Touch(ALoc);
  SaveLocations;
  AppendAction(atDelete, okLocation, ALoc.ID, 'Удалено место хранения: ' + ALoc.Name, '', '');
  Result := True;
end;

function TLibraryDB.RestoreLocation(ALoc: TLocation; out AError: string): Boolean;
begin
  Result := False;
  AError := '';
  if ALoc = nil then Exit;
  ALoc.Deleted := False;
  ALoc.DeletedAt := 0;
  ALoc.DeletedBy := 0;
  Touch(ALoc);
  SaveLocations;
  AppendAction(atRestore, okLocation, ALoc.ID, 'Восстановлено место хранения: ' + ALoc.Name, '', '');
  Result := True;
end;

function TLibraryDB.AddBook(const ATitle, AAuthors: string; AYear: Integer;
  const APublisher, AISBN: string; ACategoryID: TId; const ADesc, ACoverSrc: string;
  out AError: string): TBook;
var
  B: TBook;
begin
  Result := nil;
  AError := '';
  if Trim(ATitle) = '' then
  begin
    AError := 'Укажите название книги.';
    Exit;
  end;
  if (ACategoryID <> 0) and ((FindCategory(ACategoryID) = nil) or FindCategory(ACategoryID).Deleted) then
  begin
    AError := 'Указанная категория не найдена.';
    Exit;
  end;
  B := TBook.Create;
  B.ID := NewID(FNextBookID);
  B.Title := Trim(ATitle);
  B.Authors := Trim(AAuthors);
  B.Year := AYear;
  B.Publisher := APublisher;
  B.ISBN := Trim(AISBN);
  B.CategoryID := ACategoryID;
  B.Description := ADesc;
  Touch(B);
  if ACoverSrc <> '' then
    B.CoverFile := CopyCover(ACoverSrc, B.ID);
  FBooks.Add(B);
  SaveBooks;
  AppendAction(atCreate, okBook, B.ID, 'Добавлена книга: ' + B.Title, '', B.Title);
  Result := B;
end;

function TLibraryDB.UpdateBook(ABook: TBook; const ATitle, AAuthors: string; AYear: Integer;
  const APublisher, AISBN: string; ACategoryID: TId; const ADesc, ACoverSrc: string;
  out AError: string): Boolean;
var
  Before: string;
begin
  Result := False;
  AError := '';
  if ABook = nil then
  begin
    AError := 'Книга не найдена.';
    Exit;
  end;
  if Trim(ATitle) = '' then
  begin
    AError := 'Укажите название книги.';
    Exit;
  end;
  Before := ABook.Title;
  ABook.Title := Trim(ATitle);
  ABook.Authors := Trim(AAuthors);
  ABook.Year := AYear;
  ABook.Publisher := APublisher;
  ABook.ISBN := Trim(AISBN);
  ABook.CategoryID := ACategoryID;
  ABook.Description := ADesc;
  if ACoverSrc <> '' then
    ABook.CoverFile := CopyCover(ACoverSrc, ABook.ID);
  Touch(ABook);
  SaveBooks;
  AppendAction(atUpdate, okBook, ABook.ID, 'Изменена книга', Before, ABook.Title);
  Result := True;
end;

function TLibraryDB.DeleteBook(ABook: TBook; out AError: string): Boolean;
begin
  Result := False;
  AError := '';
  if ABook = nil then Exit;
  if BookHasLoanedCopies(ABook.ID) then
  begin
    AError := 'Нельзя удалить книгу: хотя бы один экземпляр находится на руках.';
    AppendAction(atDenied, okBook, ABook.ID, AError, '', '');
    Exit;
  end;
  ABook.Deleted := True;
  ABook.DeletedAt := Now;
  if FCurrentUser <> nil then ABook.DeletedBy := FCurrentUser.ID;
  Touch(ABook);
  SaveBooks;
  AppendAction(atDelete, okBook, ABook.ID, 'Удалена книга: ' + ABook.Title, '', '');
  Result := True;
end;

function TLibraryDB.RestoreBook(ABook: TBook; out AError: string): Boolean;
begin
  Result := False;
  AError := '';
  if ABook = nil then Exit;
  ABook.Deleted := False;
  ABook.DeletedAt := 0;
  ABook.DeletedBy := 0;
  Touch(ABook);
  SaveBooks;
  AppendAction(atRestore, okBook, ABook.ID, 'Восстановлена книга: ' + ABook.Title, '', '');
  Result := True;
end;

function TLibraryDB.AddCopy(ABookID: TId; const AInv, ACond: string; ALocationID: TId; const ANote: string;
  AReceived: TDateTime; out AError: string): TCopy;
var
  C: TCopy;
  B: TBook;
  L: TLocation;
begin
  Result := nil;
  AError := '';
  B := FindBook(ABookID);
  if (B = nil) or B.Deleted then
  begin
    AError := 'Книга для экземпляра не найдена.';
    Exit;
  end;
  if Trim(AInv) = '' then
  begin
    AError := 'Укажите инвентарный номер.';
    Exit;
  end;
  if FindCopyByInventory(AInv, 0) <> nil then
  begin
    AError := 'Инвентарный номер уже существует.';
    Exit;
  end;
  L := FindLocation(ALocationID);
  if (L = nil) or L.Deleted then
  begin
    AError := 'Укажите место хранения.';
    Exit;
  end;
  C := TCopy.Create;
  C.ID := NewID(FNextCopyID);
  C.BookID := ABookID;
  C.InventoryNo := Trim(AInv);
  C.Condition := NormalizeCopyCondition(ACond);
  C.LocationID := ALocationID;
  C.Note := ANote;
  if AReceived > 0 then C.ReceivedAt := AReceived else C.ReceivedAt := Date;
  C.Status := csAvailable;
  Touch(C);
  FCopies.Add(C);
  SaveCopies;
  AppendAction(atCreate, okCopy, C.ID, 'Добавлен экземпляр инв. № ' + C.InventoryNo, '', '');
  Result := C;
end;

function TLibraryDB.UpdateCopy(ACopy: TCopy; const AInv, ACond: string; ALocationID: TId; const ANote: string;
  AReceived: TDateTime; AStatus: TCopyStatus; out AError: string): Boolean;
var
  L: TLocation;
begin
  Result := False;
  AError := '';
  if ACopy = nil then Exit;
  if Trim(AInv) = '' then
  begin
    AError := 'Укажите инвентарный номер.';
    Exit;
  end;
  if FindCopyByInventory(AInv, ACopy.ID) <> nil then
  begin
    AError := 'Инвентарный номер уже существует.';
    Exit;
  end;
  L := FindLocation(ALocationID);
  if (L = nil) or L.Deleted then
  begin
    AError := 'Укажите место хранения.';
    Exit;
  end;
  ACopy.InventoryNo := Trim(AInv);
  ACopy.Condition := NormalizeCopyCondition(ACond);
  ACopy.LocationID := ALocationID;
  ACopy.Note := ANote;
  ACopy.ReceivedAt := AReceived;
  if ACopy.Status <> csLoaned then
    ACopy.Status := AStatus;
  Touch(ACopy);
  SaveCopies;
  AppendAction(atUpdate, okCopy, ACopy.ID, 'Изменён экземпляр инв. № ' + ACopy.InventoryNo, '', '');
  Result := True;
end;

function TLibraryDB.DeleteCopy(ACopy: TCopy; out AError: string): Boolean;
begin
  Result := False;
  AError := '';
  if ACopy = nil then Exit;
  if ACopy.Status = csLoaned then
  begin
    AError := 'Нельзя удалить экземпляр, находящийся на руках.';
    AppendAction(atDenied, okCopy, ACopy.ID, AError, '', '');
    Exit;
  end;
  ACopy.Deleted := True;
  ACopy.DeletedAt := Now;
  if FCurrentUser <> nil then ACopy.DeletedBy := FCurrentUser.ID;
  Touch(ACopy);
  SaveCopies;
  AppendAction(atDelete, okCopy, ACopy.ID, 'Удалён экземпляр инв. № ' + ACopy.InventoryNo, '', '');
  Result := True;
end;

function TLibraryDB.RestoreCopy(ACopy: TCopy; out AError: string): Boolean;
begin
  Result := False;
  AError := '';
  if ACopy = nil then Exit;
  if FindCopyByInventory(ACopy.InventoryNo, ACopy.ID) <> nil then
  begin
    AError := 'Инвентарный номер уже существует.';
    Exit;
  end;
  ACopy.Deleted := False;
  ACopy.DeletedAt := 0;
  ACopy.DeletedBy := 0;
  Touch(ACopy);
  SaveCopies;
  AppendAction(atRestore, okCopy, ACopy.ID, 'Восстановлен экземпляр инв. № ' + ACopy.InventoryNo, '', '');
  Result := True;
end;

function TLibraryDB.AddReader(const AName, APhone, AAddress, AContacts, ANote: string;
  ABirth: TDateTime; out AError: string): TReader;
var
  R: TReader;
begin
  Result := nil;
  AError := '';
  if Trim(AName) = '' then
  begin
    AError := 'Укажите Ф. И. О. читателя.';
    Exit;
  end;
  R := TReader.Create;
  R.ID := NewID(FNextReaderID);
  R.FullName := Trim(AName);
  R.Phone := Trim(APhone);
  R.Address := AAddress;
  R.Contacts := AContacts;
  R.Note := ANote;
  R.BirthDate := ABirth;
  R.RegisteredAt := Date;
  R.Status := rsActive;
  Touch(R);
  FReaders.Add(R);
  SaveReaders;
  AppendAction(atCreate, okReader, R.ID, 'Зарегистрирован читатель: ' + R.FullName, '', '');
  Result := R;
end;

function TLibraryDB.UpdateReader(AReader: TReader; const AName, APhone, AAddress, AContacts,
  ANote: string; ABirth: TDateTime; AStatus: TReaderStatus; const ABlockReason: string;
  out AError: string): Boolean;
var
  Before: string;
begin
  Result := False;
  AError := '';
  if AReader = nil then Exit;
  if Trim(AName) = '' then
  begin
    AError := 'Укажите Ф. И. О. читателя.';
    Exit;
  end;
  Before := AReader.FullName;
  AReader.FullName := Trim(AName);
  AReader.Phone := Trim(APhone);
  AReader.Address := AAddress;
  AReader.Contacts := AContacts;
  AReader.Note := ANote;
  AReader.BirthDate := ABirth;
  AReader.Status := AStatus;
  AReader.BlockReason := ABlockReason;
  Touch(AReader);
  SaveReaders;
  AppendAction(atUpdate, okReader, AReader.ID, 'Изменён читатель', Before, AReader.FullName);
  Result := True;
end;

function TLibraryDB.DeleteReader(AReader: TReader; out AError: string): Boolean;
begin
  Result := False;
  AError := '';
  if AReader = nil then Exit;
  if ReaderActiveLoans(AReader.ID) > 0 then
  begin
    AError := 'Нельзя удалить читателя с невозвращёнными книгами.';
    AppendAction(atDenied, okReader, AReader.ID, AError, '', '');
    Exit;
  end;
  AReader.Deleted := True;
  AReader.DeletedAt := Now;
  if FCurrentUser <> nil then AReader.DeletedBy := FCurrentUser.ID;
  Touch(AReader);
  SaveReaders;
  AppendAction(atDelete, okReader, AReader.ID, 'Удалён читатель: ' + AReader.FullName, '', '');
  Result := True;
end;

function TLibraryDB.RestoreReader(AReader: TReader; out AError: string): Boolean;
begin
  Result := False;
  AError := '';
  if AReader = nil then Exit;
  AReader.Deleted := False;
  AReader.DeletedAt := 0;
  AReader.DeletedBy := 0;
  Touch(AReader);
  SaveReaders;
  AppendAction(atRestore, okReader, AReader.ID, 'Восстановлен читатель: ' + AReader.FullName, '', '');
  Result := True;
end;

function TLibraryDB.IssueLoan(ACopyID, AReaderID: TId; const ANote: string; out AError: string): TLoan;
var
  C: TCopy;
  R: TReader;
  L: TLoan;
  I: Integer;
begin
  Result := nil;
  AError := '';
  C := FindCopy(ACopyID);
  R := FindReader(AReaderID);
  if (C = nil) or C.Deleted then
  begin
    AError := 'Экземпляр не найден.';
    Exit;
  end;
  if (R = nil) or R.Deleted then
  begin
    AError := 'Читатель не найден.';
    Exit;
  end;
  if R.Status = rsBlocked then
  begin
    AError := 'Читатель заблокирован: ' + R.BlockReason;
    Exit;
  end;
  if C.Status <> csAvailable then
  begin
    AError := 'Экземпляр недоступен для выдачи.';
    Exit;
  end;
  for I := 0 to FLoans.Count - 1 do
  begin
    L := TLoan(FLoans[I]);
    if (not L.Deleted) and (L.CopyID = ACopyID) and (L.State = lsLoaned) then
    begin
      AError := 'У экземпляра уже есть незавершённая выдача.';
      Exit;
    end;
  end;
  if ReaderActiveLoans(AReaderID) >= FSettings.MaxBooksPerReader then
  begin
    AError := Format('Превышен лимит книг на руках (%d).', [FSettings.MaxBooksPerReader]);
    Exit;
  end;
  BeginTxn(['Loans.dat', 'Copies.dat']);
  try
    L := TLoan.Create;
    L.ID := NewID(FNextLoanID);
    L.CopyID := ACopyID;
    L.ReaderID := AReaderID;
    L.IssuedAt := Now;
    L.DueAt := Date + FSettings.LoanDays;
    L.RenewCount := 0;
    if FCurrentUser <> nil then L.IssuedBy := FCurrentUser.ID;
    L.State := lsLoaned;
    L.Note := ANote;
    Touch(L);
    FLoans.Add(L);
    C.Status := csLoaned;
    Touch(C);
    SaveLoans;
    SaveCopies;
    CommitTxn;
    AppendAction(atLoan, okLoan, L.ID,
      Format('выдал книгу, инв. № %s; читатель: %s', [C.InventoryNo, R.FullName]), '', '');
    Result := L;
  except
    on E: Exception do
    begin
      RecoverTxnIfNeeded;
      AError := E.Message;
    end;
  end;
end;

function TLibraryDB.ReturnLoan(ALoan: TLoan; const ANote: string; out AError: string): Boolean;
var
  C: TCopy;
  R: TReader;
begin
  Result := False;
  AError := '';
  if (ALoan = nil) or (ALoan.State <> lsLoaned) then
  begin
    AError := 'Выдача не найдена или уже закрыта.';
    Exit;
  end;
  C := FindCopy(ALoan.CopyID);
  R := FindReader(ALoan.ReaderID);
  BeginTxn(['Loans.dat', 'Copies.dat']);
  try
    ALoan.State := lsReturned;
    ALoan.ReturnedAt := Now;
    if FCurrentUser <> nil then ALoan.ReturnedBy := FCurrentUser.ID;
    if ANote <> '' then ALoan.Note := ANote;
    Touch(ALoan);
    if C <> nil then
    begin
      C.Status := csAvailable;
      Touch(C);
    end;
    SaveLoans;
    SaveCopies;
    CommitTxn;
    AppendAction(atReturn, okLoan, ALoan.ID,
      Format('возврат книги, инв. № %s; читатель: %s',
        [IfThen(C <> nil, C.InventoryNo, '?'), IfThen(R <> nil, R.FullName, '?')]), '', '');
    Result := True;
  except
    on E: Exception do
    begin
      RecoverTxnIfNeeded;
      AError := E.Message;
    end;
  end;
end;

function TLibraryDB.RenewLoan(ALoan: TLoan; out AError: string): Boolean;
var
  R: TReader;
  C: TCopy;
  Before: string;
begin
  Result := False;
  AError := '';
  if (ALoan = nil) or (ALoan.State <> lsLoaned) then
  begin
    AError := 'Выдача не найдена или уже закрыта.';
    Exit;
  end;
  R := FindReader(ALoan.ReaderID);
  if (R <> nil) and (R.Status = rsBlocked) then
  begin
    AError := 'Нельзя продлить: читатель заблокирован.';
    Exit;
  end;
  if ALoan.RenewCount >= FSettings.MaxRenewals then
  begin
    AError := 'Превышено допустимое число продлений.';
    Exit;
  end;
  Before := FormatDateRu(ALoan.DueAt);
  ALoan.DueAt := ALoan.DueAt + FSettings.LoanDays;
  Inc(ALoan.RenewCount);
  Touch(ALoan);
  SaveLoans;
  C := FindCopy(ALoan.CopyID);
  AppendAction(atRenew, okLoan, ALoan.ID,
    Format('продление, инв. № %s; новый срок: %s',
      [IfThen(C <> nil, C.InventoryNo, '?'), FormatDateRu(ALoan.DueAt)]), Before, FormatDateRu(ALoan.DueAt));
  Result := True;
end;

function TLibraryDB.UpdateLoanDueDate(ALoan: TLoan; ADueAt: TDateTime; out AError: string): Boolean;
var
  C: TCopy;
  Before: string;
begin
  Result := False;
  AError := '';
  if (ALoan = nil) or ALoan.Deleted then
  begin
    AError := 'Выдача не найдена.';
    Exit;
  end;
  if ALoan.State <> lsLoaned then
  begin
    AError := 'Срок можно изменять только для открытой выдачи.';
    Exit;
  end;
  if ADueAt <= 0 then
  begin
    AError := 'Укажите корректную дату срока возврата.';
    Exit;
  end;
  if Trunc(ADueAt) < Trunc(ALoan.IssuedAt) then
  begin
    AError := Format(
      'Срок возврата (%s) не может быть раньше даты выдачи (%s).' + LineEnding +
      'Сначала измените колонку «Выдана», затем снова укажите срок.',
      [FormatDateRu(ADueAt), FormatDateRu(ALoan.IssuedAt)]);
    Exit;
  end;
  if Trunc(ADueAt) = Trunc(ALoan.DueAt) then
  begin
    Result := True;
    Exit;
  end;
  Before := FormatDateRu(ALoan.DueAt);
  ALoan.DueAt := Trunc(ADueAt);
  Touch(ALoan);
  SaveLoans;
  C := FindCopy(ALoan.CopyID);
  AppendAction(atUpdate, okLoan, ALoan.ID,
    Format('изменён срок, инв. № %s; новый срок: %s',
      [IfThen(C <> nil, C.InventoryNo, '?'), FormatDateRu(ALoan.DueAt)]),
    Before, FormatDateRu(ALoan.DueAt));
  Result := True;
end;

function TLibraryDB.UpdateLoanIssuedDate(ALoan: TLoan; AIssuedAt: TDateTime; out AError: string): Boolean;
var
  C: TCopy;
  Before: string;
begin
  Result := False;
  AError := '';
  if (ALoan = nil) or ALoan.Deleted then
  begin
    AError := 'Выдача не найдена.';
    Exit;
  end;
  if ALoan.State <> lsLoaned then
  begin
    AError := 'Дату выдачи можно изменять только для открытой выдачи.';
    Exit;
  end;
  if AIssuedAt <= 0 then
  begin
    AError := 'Укажите корректную дату выдачи.';
    Exit;
  end;
  if Trunc(AIssuedAt) > Trunc(ALoan.DueAt) then
  begin
    AError := 'Дата выдачи не может быть позже срока возврата.';
    Exit;
  end;
  if Trunc(AIssuedAt) = Trunc(ALoan.IssuedAt) then
  begin
    Result := True;
    Exit;
  end;
  Before := FormatDateRu(ALoan.IssuedAt);
  ALoan.IssuedAt := Trunc(AIssuedAt);
  Touch(ALoan);
  SaveLoans;
  C := FindCopy(ALoan.CopyID);
  AppendAction(atUpdate, okLoan, ALoan.ID,
    Format('изменена дата выдачи, инв. № %s; новая дата: %s',
      [IfThen(C <> nil, C.InventoryNo, '?'), FormatDateRu(ALoan.IssuedAt)]),
    Before, FormatDateRu(ALoan.IssuedAt));
  Result := True;
end;

function TLibraryDB.AddUser(const ALogin, ADisplay, APassword: string; ARole: TUserRole;
  out AError: string): TUser;
var
  I: Integer;
  U: TUser;
begin
  Result := nil;
  AError := '';
  if (FCurrentUser = nil) or (FCurrentUser.Role <> urAdmin) then
  begin
    AError := 'Управление пользователями доступно только администратору.';
    Exit;
  end;
  if Trim(ALogin) = '' then
  begin
    AError := 'Укажите имя входа.';
    Exit;
  end;
  for I := 0 to FUsers.Count - 1 do
  begin
    U := TUser(FUsers[I]);
    if (not U.Deleted) and SameText(U.Login, Trim(ALogin)) then
    begin
      AError := 'Пользователь с таким именем входа уже существует.';
      Exit;
    end;
  end;
  U := TUser.Create;
  U.ID := NewID(FNextUserID);
  U.Login := Trim(ALogin);
  U.DisplayName := Trim(ADisplay);
  if U.DisplayName = '' then U.DisplayName := U.Login;
  U.Role := ARole;
  U.Salt := GenerateSalt;
  U.PasswordHash := HashPassword(APassword, U.Salt);
  U.Active := True;
  Touch(U);
  FUsers.Add(U);
  SaveUsers;
  AppendAction(atCreate, okUser, U.ID, 'Создан пользователь: ' + U.Login, '', '');
  Result := U;
end;

function TLibraryDB.UpdateUser(AUser: TUser; const ADisplay, APassword: string; ARole: TUserRole;
  AActive: Boolean; out AError: string): Boolean;
begin
  Result := False;
  AError := '';
  if (FCurrentUser = nil) or (FCurrentUser.Role <> urAdmin) then
  begin
    AError := 'Управление пользователями доступно только администратору.';
    Exit;
  end;
  if AUser = nil then Exit;
  if (AUser.Role = urAdmin) and AUser.Active and (not AActive) and (ActiveAdminCount <= 1) then
  begin
    AError := 'Нельзя деактивировать единственного активного администратора.';
    AppendAction(atDenied, okUser, AUser.ID, AError, '', '');
    Exit;
  end;
  if (AUser.Role = urAdmin) and (ARole <> urAdmin) and AUser.Active and (ActiveAdminCount <= 1) then
  begin
    AError := 'Нельзя снять роль единственного активного администратора.';
    AppendAction(atDenied, okUser, AUser.ID, AError, '', '');
    Exit;
  end;
  AUser.DisplayName := Trim(ADisplay);
  AUser.Role := ARole;
  AUser.Active := AActive;
  if APassword <> '' then
  begin
    AUser.Salt := GenerateSalt;
    AUser.PasswordHash := HashPassword(APassword, AUser.Salt);
  end;
  Touch(AUser);
  SaveUsers;
  AppendAction(atUpdate, okUser, AUser.ID, 'Изменён пользователь: ' + AUser.Login, '', '');
  Result := True;
end;

function TLibraryDB.DeleteUser(AUser: TUser; out AError: string): Boolean;
begin
  Result := False;
  AError := '';
  if (FCurrentUser = nil) or (FCurrentUser.Role <> urAdmin) then
  begin
    AError := 'Управление пользователями доступно только администратору.';
    Exit;
  end;
  if AUser = nil then Exit;
  if (AUser.Role = urAdmin) and AUser.Active and (ActiveAdminCount <= 1) then
  begin
    AError := 'Нельзя удалить единственного активного администратора.';
    AppendAction(atDenied, okUser, AUser.ID, AError, '', '');
    Exit;
  end;
  AUser.Deleted := True;
  AUser.Active := False;
  AUser.DeletedAt := Now;
  if FCurrentUser <> nil then AUser.DeletedBy := FCurrentUser.ID;
  Touch(AUser);
  SaveUsers;
  AppendAction(atDelete, okUser, AUser.ID, 'Удалён пользователь: ' + AUser.Login, '', '');
  Result := True;
end;

function TLibraryDB.RestoreUser(AUser: TUser; out AError: string): Boolean;
begin
  Result := False;
  AError := '';
  if AUser = nil then Exit;
  AUser.Deleted := False;
  AUser.DeletedAt := 0;
  AUser.DeletedBy := 0;
  AUser.Active := True;
  Touch(AUser);
  SaveUsers;
  AppendAction(atRestore, okUser, AUser.ID, 'Восстановлен пользователь: ' + AUser.Login, '', '');
  Result := True;
end;

function TLibraryDB.ImportRecognizedBooks(AItems: TList; const ALocationName: string;
  out ASavedCount: Integer; out AError: string): Boolean;
var
  I: Integer;
  Item: TRecognizedBook;
  Seen: TStringList;
  Loc: TLocation;
  Book: TBook;
  CopyItem: TCopy;
  Err: string;
begin
  Result := False;
  ASavedCount := 0;
  AError := '';
  if (AItems = nil) or (AItems.Count = 0) then
  begin
    AError := 'Нет строк для сохранения.';
    Exit;
  end;
  if Trim(ALocationName) = '' then
  begin
    AError := 'Укажите место хранения.';
    Exit;
  end;

  Seen := TStringList.Create;
  try
    Seen.Sorted := True;
    Seen.CaseSensitive := False;
    Seen.Duplicates := dupIgnore;
    for I := 0 to AItems.Count - 1 do
    begin
      Item := TRecognizedBook(AItems[I]);
      if (Item = nil) or (Trim(Item.Title) = '') then
      begin
        AError := 'Укажите наименование для каждой сохраняемой строки.';
        Exit;
      end;
      if Trim(Item.InventoryNo) = '' then
      begin
        AError := 'Укажите инвентарный номер для каждой сохраняемой строки.';
        Exit;
      end;
      if Seen.IndexOf(Trim(Item.InventoryNo)) >= 0 then
      begin
        AError := 'В списке есть повторяющийся инвентарный номер: ' + Trim(Item.InventoryNo) + '.';
        Exit;
      end;
      if FindCopyByInventory(Item.InventoryNo, 0) <> nil then
      begin
        AError := 'Инвентарный номер уже существует: ' + Trim(Item.InventoryNo) + '.';
        Exit;
      end;
      Seen.Add(Trim(Item.InventoryNo));
    end;

    Loc := FindActiveLocationByName(ALocationName);
    BeginTxn(['Locations.dat', 'Books.dat', 'Copies.dat']);
    try
      if Loc = nil then
      begin
        Loc := AddLocation(Trim(ALocationName), '', Err);
        if Loc = nil then
          raise Exception.Create(Err);
      end;
      for I := 0 to AItems.Count - 1 do
      begin
        Item := TRecognizedBook(AItems[I]);
        Book := AddBook(Item.Title, '', 0, '', '', 0, '', '', Err);
        if Book = nil then
          raise Exception.Create(Err);
        CopyItem := AddCopy(Book.ID, Item.InventoryNo, DEFAULT_COPY_CONDITION,
          Loc.ID, '', Date, Err);
        if CopyItem = nil then
          raise Exception.Create(Err);
        Inc(ASavedCount);
      end;
      CommitTxn;
      Result := True;
    except
      on E: Exception do
      begin
        AError := 'Не удалось сохранить импорт: ' + E.Message;
        ASavedCount := 0;
      end;
    end;
  finally
    Seen.Free;
  end;
end;

function TLibraryDB.UpdateSettings(const ALibName: string; ALoanDays, AMaxBooks, AMaxRenew: Integer;
  AAutoBackup: Boolean; AUIFontSize: Integer; AInventoryStartNo: Int64;
  const AOpenRouterModel, AOpenRouterApiKey: string;
  out AError: string): Boolean;
begin
  Result := False;
  AError := '';
  if ALoanDays < 1 then
  begin
    AError := 'Срок выдачи должен быть не меньше 1 дня.';
    Exit;
  end;
  FSettings.LibraryName := ALibName;
  FSettings.LoanDays := ALoanDays;
  FSettings.MaxBooksPerReader := AMaxBooks;
  FSettings.MaxRenewals := AMaxRenew;
  FSettings.AutoBackupEnabled := AAutoBackup;
  FSettings.UIFontSize := ClampUIFontSize(AUIFontSize);
  if AInventoryStartNo < 1 then
    FSettings.InventoryStartNo := 1
  else
    FSettings.InventoryStartNo := AInventoryStartNo;
  FSettings.OpenRouterModel := Trim(AOpenRouterModel);
  FSettings.OpenRouterApiKey := Trim(AOpenRouterApiKey);
  SaveSettings;
  AppendAction(atSettings, okSettings, 0, 'Изменены настройки', '', '');
  Result := True;
end;

function ShouldSkipBackupFile(const AFileName: string): Boolean;
var
  Ext, NameOnly: string;
begin
  NameOnly := ExtractFileName(AFileName);
  Ext := LowerCase(ExtractFileExt(NameOnly));
  Result := SameText(NameOnly, 'Library.lock') or
            SameText(NameOnly, 'Library.txn') or
            (Ext = '.tmp') or
            (Ext = '.bak');
end;

function CopyDataFiles(const SrcDir, DstDir: string; out ACopied: Integer; out AError: string): Boolean;
var
  SR: TSearchRec;
  Src, Dst: string;
begin
  Result := False;
  ACopied := 0;
  AError := '';
  if not DirectoryExists(SrcDir) then
  begin
    AError := 'Исходный каталог Data не найден.';
    Exit;
  end;
  ForceDirectories(DstDir);
  if FindFirst(IncludeTrailingPathDelimiter(SrcDir) + '*', faAnyFile, SR) = 0 then
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;
      if (SR.Attr and faDirectory) <> 0 then
        Continue;
      if ShouldSkipBackupFile(SR.Name) then
        Continue;
      Src := IncludeTrailingPathDelimiter(SrcDir) + SR.Name;
      Dst := IncludeTrailingPathDelimiter(DstDir) + SR.Name;
      if not CopyFile(Src, Dst, [cffOverwriteFile, cffPreserveTime]) then
      begin
        AError := 'Не удалось скопировать файл: ' + SR.Name;
        Exit;
      end;
      Inc(ACopied);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
  if ACopied = 0 then
  begin
    AError := 'В каталоге Data нет файлов для копирования.';
    Exit;
  end;
  Result := True;
end;

function TLibraryDB.CreateBackup(out APath, AError: string): Boolean;
var
  Name, Dest, DestData, Manifest: string;
  SL: TStringList;
  SR: TSearchRec;
  Copied: Integer;
  CopyErr: string;
begin
  Result := False;
  APath := '';
  AError := '';
  Dest := '';
  try
    Name := 'Data_' + FormatDateTime('yyyymmdd_hhnnss', Now);
    Dest := FPaths.BackupDir + Name + PathDelim;
    DestData := Dest + 'Data' + PathDelim;
    ForceDirectories(DestData);
    if not CopyDataFiles(FPaths.DataDir, DestData, Copied, CopyErr) then
    begin
      AError := 'Не удалось скопировать каталог Data.';
      if CopyErr <> '' then
        AError := AError + LineEnding + CopyErr;
      if DirectoryExists(Dest) then
        DeleteDirectory(Dest, False);
      Exit;
    end;
    SL := TStringList.Create;
    try
      SL.Add('BackupTime=' + FormatDateTimeRu(Now));
      SL.Add('AppVersion=' + APP_VERSION);
      SL.Add('FormatVersion=' + IntToStr(FORMAT_VERSION));
      SL.Add('FilesCopied=' + IntToStr(Copied));
      if FindFirst(DestData + '*.*', faAnyFile, SR) = 0 then
      try
        repeat
          if (SR.Attr and faDirectory) = 0 then
            SL.Add('File=' + SR.Name + ';Size=' + IntToStr(SR.Size));
        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;
      Manifest := Dest + 'manifest.txt';
      SL.SaveToFile(Manifest);
    finally
      SL.Free;
    end;
    FSettings.LastBackupAt := Now;
    SaveSettings;
    APath := Dest;
    AppendAction(atBackup, okBackup, 0, 'Создана резервная копия: ' + Name, '', '');
    Result := True;
  except
    on E: Exception do
    begin
      AError := 'Ошибка резервного копирования: ' + E.Message;
      FLog.Write(AError);
      if (Dest <> '') and DirectoryExists(Dest) then
        DeleteDirectory(Dest, False);
    end;
  end;
end;

function TLibraryDB.RestoreBackup(const ABackupDir: string; out AError: string): Boolean;
var
  Safety, SrcData: string;
  PathDummy: string;
  Copied: Integer;
  CopyErr: string;
begin
  Result := False;
  AError := '';
  SrcData := IncludeTrailingPathDelimiter(ABackupDir) + 'Data';
  if not DirectoryExists(SrcData) then
  begin
    AError := 'В выбранной копии отсутствует каталог Data.';
    Exit;
  end;
  FRestoring := True;
  try
    if not CreateBackup(PathDummy, AError) then
    begin
      AError := 'Не удалось создать страховочную копию перед восстановлением: ' + AError;
      Exit;
    end;
    Safety := FPaths.DataDir;
    if not CopyDataFiles(SrcData, Safety, Copied, CopyErr) then
    begin
      AError := 'Не удалось восстановить файлы данных.';
      if CopyErr <> '' then
        AError := AError + LineEnding + CopyErr;
      Exit;
    end;
    FBooks.Clear;
    FCopies.Clear;
    FReaders.Clear;
    FLoans.Clear;
    FCategories.Clear;
    FLocations.Clear;
    FUsers.Clear;
    LoadTable(FPaths.DataFile('Categories.dat'), @LoadCategoriesStream);
    LoadTable(FPaths.DataFile('Locations.dat'), @LoadLocationsStream);
    LoadTable(FPaths.DataFile('Books.dat'), @LoadBooksStream);
    LoadTable(FPaths.DataFile('Copies.dat'), @LoadCopiesStream);
    LoadTable(FPaths.DataFile('Readers.dat'), @LoadReadersStream);
    LoadTable(FPaths.DataFile('Loans.dat'), @LoadLoansStream);
    LoadTable(FPaths.DataFile('Users.dat'), @LoadUsersStream);
    LoadTable(FPaths.DataFile('Settings.dat'), @LoadSettingsStream);
    LoadOrRebuildIndexes;
    AppendAction(atRestoreBackup, okBackup, 0, 'Восстановление из копии: ' + ABackupDir, '', '');
    Result := True;
  except
    on E: Exception do
    begin
      AError := 'Ошибка восстановления: ' + E.Message;
      FLog.Write(AError);
    end;
  end;
  FRestoring := False;
end;

function TLibraryDB.MaybeAutoBackup(out APath, AError: string): Boolean;
begin
  Result := False;
  APath := '';
  AError := '';
  if not FSettings.AutoBackupEnabled then
    Exit;
  if (FSettings.LastBackupAt > 0) and (DaysBetween(Now, FSettings.LastBackupAt) < BACKUP_INTERVAL_DAYS) then
    Exit;
  Result := CreateBackup(APath, AError);
end;

procedure TLibraryDB.SearchBooks(const ATitleQuery: string;
  const AInventoryQuery: string; AOut: TList; AIncludeDeleted: Boolean);
var
  TitleQ, InvQ, InvQLow: string;
  IDs, CopyIDs: TList;
  I: Integer;
  B: TBook;
  C: TCopy;
begin
  TitleQ := Trim(ATitleQuery);
  InvQ := Trim(AInventoryQuery);

  { пустой запрос по обоим полям — все книги (с учётом флага удалённых) }
  if (TitleQ = '') and (InvQ = '') then
  begin
    for I := 0 to FBooks.Count - 1 do
    begin
      B := TBook(FBooks[I]);
      if B.Deleted and (not AIncludeDeleted) then Continue;
      AOut.Add(B);
    end;
    Exit;
  end;

  IDs := TList.Create;
  CopyIDs := TList.Create;
  try
    { 1) поиск по текстовым полям книги (название, автор, ISBN) }
    if TitleQ <> '' then
    begin
      FBooksIdx.FindContains(TitleQ, IDs);
      for I := 0 to IDs.Count - 1 do
      begin
        B := FindBook(TId(IDs[I]));
        if B = nil then Continue;
        if B.Deleted and (not AIncludeDeleted) then Continue;
        if AOut.IndexOf(B) < 0 then AOut.Add(B);
      end;
    end;

    { 2) поиск по инвентарному номеру экземпляра.
       FCopiesIdx содержит и InventoryNo, и IntToStr(BookID), поэтому
       FindContains может вернуть копию, у которой BookID содержит подстроку,
       но инв.№ — нет. Делаем явную проверку по InventoryNo. }
    if InvQ <> '' then
    begin
      InvQLow := LowerCase(InvQ);
      FCopiesIdx.FindContains(InvQ, CopyIDs);
      for I := 0 to CopyIDs.Count - 1 do
      begin
        C := FindCopy(TId(CopyIDs[I]));
        if (C = nil) or C.Deleted then Continue;
        if Pos(InvQLow, LowerCase(C.InventoryNo)) = 0 then Continue;
        B := FindBook(C.BookID);
        if B = nil then Continue;
        if B.Deleted and (not AIncludeDeleted) then Continue;
        if AOut.IndexOf(B) < 0 then AOut.Add(B);
      end;
    end;
  finally
    CopyIDs.Free;
    IDs.Free;
  end;
end;

procedure TLibraryDB.SearchReaders(const AQuery: string; AOut: TList; AIncludeDeleted: Boolean);
var
  IDs: TList;
  I: Integer;
  ID: TId;
  R: TReader;
begin
  if AQuery = '' then
  begin
    for I := 0 to FReaders.Count - 1 do
    begin
      R := TReader(FReaders[I]);
      if R.Deleted and (not AIncludeDeleted) then Continue;
      AOut.Add(R);
    end;
    Exit;
  end;
  IDs := TList.Create;
  try
    FReadersIdx.FindContains(AQuery, IDs);
    if TryStrToInt64(Trim(AQuery), ID) then
      IDs.Add(Pointer(ID));
    for I := 0 to IDs.Count - 1 do
    begin
      R := FindReader(TId(IDs[I]));
      if R = nil then Continue;
      if R.Deleted and (not AIncludeDeleted) then Continue;
      if AOut.IndexOf(R) < 0 then AOut.Add(R);
    end;
  finally
    IDs.Free;
  end;
end;

procedure TLibraryDB.CollectOverdue(AOut: TList);
var
  I: Integer;
  L: TLoan;
begin
  for I := 0 to FLoans.Count - 1 do
  begin
    L := TLoan(FLoans[I]);
    if (not L.Deleted) and (L.State = lsLoaned) and (Date > Trunc(L.DueAt)) then
      AOut.Add(L);
  end;
end;

function TLibraryDB.IntegrityCheck(out AError: string): Boolean;
var
  I, J: Integer;
  B: TBook;
  C: TCopy;
  L: TLoan;
  SeenInv: TStringList;
  ActiveLoan: Boolean;
begin
  Result := False;
  AError := '';
  SeenInv := TStringList.Create;
  try
    SeenInv.Sorted := True;
    SeenInv.Duplicates := dupError;
    for I := 0 to FCopies.Count - 1 do
    begin
      C := TCopy(FCopies[I]);
      try
        SeenInv.Add(NormalizeKey(C.InventoryNo));
      except
        AError := 'Нарушена уникальность инвентарных номеров.';
        Exit;
      end;
      if (C.BookID <> 0) and (FindBook(C.BookID) = nil) then
      begin
        AError := Format('Экземпляр %s ссылается на отсутствующую книгу.', [C.InventoryNo]);
        Exit;
      end;
    end;
    for I := 0 to FLoans.Count - 1 do
    begin
      L := TLoan(FLoans[I]);
      if L.Deleted then Continue;
      if FindCopy(L.CopyID) = nil then
      begin
        AError := 'Выдача ссылается на отсутствующий экземпляр.';
        Exit;
      end;
      if FindReader(L.ReaderID) = nil then
      begin
        AError := 'Выдача ссылается на отсутствующего читателя.';
        Exit;
      end;
    end;
    for I := 0 to FCopies.Count - 1 do
    begin
      C := TCopy(FCopies[I]);
      if C.Deleted then Continue;
      ActiveLoan := False;
      for J := 0 to FLoans.Count - 1 do
      begin
        L := TLoan(FLoans[J]);
        if (not L.Deleted) and (L.CopyID = C.ID) and (L.State = lsLoaned) then
        begin
          if ActiveLoan then
          begin
            AError := 'У экземпляра несколько активных выдач: ' + C.InventoryNo;
            Exit;
          end;
          ActiveLoan := True;
        end;
      end;
      if ActiveLoan and (C.Status <> csLoaned) then
      begin
        AError := 'Статус экземпляра не соответствует активной выдаче: ' + C.InventoryNo;
        Exit;
      end;
      if (not ActiveLoan) and (C.Status = csLoaned) then
      begin
        AError := 'Экземпляр помечен как выданный без активной выдачи: ' + C.InventoryNo;
        Exit;
      end;
    end;
    for I := 0 to FBooks.Count - 1 do
    begin
      B := TBook(FBooks[I]);
      if (not B.Deleted) and (B.CategoryID <> 0) and (FindCategory(B.CategoryID) = nil) then
      begin
        AError := 'Книга ссылается на отсутствующую категорию: ' + B.Title;
        Exit;
      end;
    end;
    Result := True;
  finally
    SeenInv.Free;
  end;
end;

end.
