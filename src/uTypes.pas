unit uTypes;

{$mode objfpc}{$H+}

interface

const
  APP_NAME = 'Библиотека';
  APP_VERSION = '1.1.3';
  DATA_SIGNATURE = 'LIBRA001';
  INDEX_SIGNATURE = 'LIBRAIDX';
  FORMAT_VERSION = 3;
  DEFAULT_ADMIN_LOGIN = 'admin';
  DEFAULT_ADMIN_PASSWORD = 'admin';
  DEFAULT_LOAN_DAYS = 14;
  DEFAULT_MAX_BOOKS = 5;
  DEFAULT_MAX_RENEWALS = 2;
  DEFAULT_UI_FONT_SIZE = 9;
  MIN_UI_FONT_SIZE = 8;
  MAX_UI_FONT_SIZE = 16;
  DEFAULT_INVENTORY_START_NO = 1;
  BACKUP_INTERVAL_DAYS = 7;
  COPY_CONDITION_BAD = 'Плохое';
  COPY_CONDITION_MEDIUM = 'Среднее';
  COPY_CONDITION_GOOD = 'Хорошее';
  DEFAULT_COPY_CONDITION = COPY_CONDITION_MEDIUM;

function EffectiveLibraryTitle(const ALibraryName: string): string;
function ApplicationWindowTitle(const ALibraryName: string): string;
function ClampUIFontSize(ASize: Integer): Integer;

type
  TUserRole = (urLibrarian, urAdmin);

  TCopyStatus = (csAvailable, csLoaned, csLost, csWrittenOff);

  TReaderStatus = (rsActive, rsBlocked);

  TLoanState = (lsLoaned, lsReturned, lsLost);

  TObjectKind = (
    okNone, okBook, okCopy, okReader, okLoan, okCategory, okUser, okSettings, okBackup, okLocation
  );

  TActionType = (
    atLogin, atLogout,
    atCreate, atUpdate, atDelete, atRestore,
    atLoan, atReturn, atRenew,
    atBackup, atRestoreBackup,
    atSettings, atDenied
  );

  TId = Int64;

function RoleToStr(ARole: TUserRole): string;
function StrToRole(const S: string): TUserRole;
function CopyStatusToStr(AStatus: TCopyStatus): string;
function StrToCopyStatus(const S: string): TCopyStatus;
function ReaderStatusToStr(AStatus: TReaderStatus): string;
function StrToReaderStatus(const S: string): TReaderStatus;
function LoanStateToStr(AState: TLoanState): string;
function StrToLoanState(const S: string): TLoanState;
function ObjectKindToStr(AKind: TObjectKind): string;
function ActionTypeToStr(AType: TActionType): string;
function NormalizeCopyCondition(const S: string): string;
function FormatDateRu(const ADate: TDateTime): string;
function FormatDateTimeRu(const ADate: TDateTime): string;
function ParseDateRu(const S: string; out ADate: TDateTime): Boolean;
function NormalizeKey(const S: string): string;
function NormalizeISBNFormat(const S: string): string;

implementation

uses
  SysUtils, DateUtils;

function EffectiveLibraryTitle(const ALibraryName: string): string;
begin
  Result := Trim(ALibraryName);
  if Result = '' then
    Result := APP_NAME;
end;

function ApplicationWindowTitle(const ALibraryName: string): string;
begin
  Result := EffectiveLibraryTitle(ALibraryName) + ' — ' + APP_VERSION;
end;

function ClampUIFontSize(ASize: Integer): Integer;
begin
  if ASize < MIN_UI_FONT_SIZE then
    Result := MIN_UI_FONT_SIZE
  else if ASize > MAX_UI_FONT_SIZE then
    Result := MAX_UI_FONT_SIZE
  else
    Result := ASize;
end;

function RoleToStr(ARole: TUserRole): string;
begin
  case ARole of
    urAdmin: Result := 'admin';
  else
    Result := 'librarian';
  end;
end;

function StrToRole(const S: string): TUserRole;
begin
  if SameText(S, 'admin') then
    Result := urAdmin
  else
    Result := urLibrarian;
end;

function CopyStatusToStr(AStatus: TCopyStatus): string;
begin
  case AStatus of
    csLoaned: Result := 'выдан';
    csLost: Result := 'утрачен';
    csWrittenOff: Result := 'списан';
  else
    Result := 'доступен';
  end;
end;

function StrToCopyStatus(const S: string): TCopyStatus;
begin
  if S = 'выдан' then Result := csLoaned
  else if S = 'утрачен' then Result := csLost
  else if S = 'списан' then Result := csWrittenOff
  else Result := csAvailable;
end;

function ReaderStatusToStr(AStatus: TReaderStatus): string;
begin
  if AStatus = rsBlocked then
    Result := 'заблокирован'
  else
    Result := 'активен';
end;

function StrToReaderStatus(const S: string): TReaderStatus;
begin
  if S = 'заблокирован' then
    Result := rsBlocked
  else
    Result := rsActive;
end;

function LoanStateToStr(AState: TLoanState): string;
begin
  case AState of
    lsReturned: Result := 'возвращено';
    lsLost: Result := 'утрачено';
  else
    Result := 'выдано';
  end;
end;

function StrToLoanState(const S: string): TLoanState;
begin
  if S = 'возвращено' then Result := lsReturned
  else if S = 'утрачено' then Result := lsLost
  else Result := lsLoaned;
end;

function ObjectKindToStr(AKind: TObjectKind): string;
begin
  case AKind of
    okBook: Result := 'книга';
    okCopy: Result := 'экземпляр';
    okReader: Result := 'читатель';
    okLoan: Result := 'выдача';
    okCategory: Result := 'категория';
    okLocation: Result := 'место хранения';
    okUser: Result := 'пользователь';
    okSettings: Result := 'настройки';
    okBackup: Result := 'резервная копия';
  else
    Result := '';
  end;
end;

function ActionTypeToStr(AType: TActionType): string;
begin
  case AType of
    atLogin: Result := 'вход';
    atLogout: Result := 'выход';
    atCreate: Result := 'создание';
    atUpdate: Result := 'изменение';
    atDelete: Result := 'удаление';
    atRestore: Result := 'восстановление';
    atLoan: Result := 'выдача';
    atReturn: Result := 'возврат';
    atRenew: Result := 'продление';
    atBackup: Result := 'резервное копирование';
    atRestoreBackup: Result := 'восстановление из копии';
    atSettings: Result := 'настройки';
    atDenied: Result := 'отказ';
  else
    Result := '';
  end;
end;

function NormalizeCopyCondition(const S: string): string;
begin
  if SameText(Trim(S), COPY_CONDITION_BAD) then
    Result := COPY_CONDITION_BAD
  else if SameText(Trim(S), COPY_CONDITION_GOOD) then
    Result := COPY_CONDITION_GOOD
  else
    Result := DEFAULT_COPY_CONDITION;
end;

function FormatDateRu(const ADate: TDateTime): string;
begin
  if ADate <= 0 then
    Result := ''
  else
    Result := FormatDateTime('dd.mm.yyyy', ADate);
end;

function FormatDateTimeRu(const ADate: TDateTime): string;
begin
  if ADate <= 0 then
    Result := ''
  else
    Result := FormatDateTime('dd.mm.yyyy hh:nn', ADate);
end;

function ParseDateRu(const S: string; out ADate: TDateTime): Boolean;
var
  T: string;
  P1, P2: Integer;
  Day, Month, Year: Integer;
  FS: TFormatSettings;
begin
  ADate := 0;
  T := Trim(S);
  T := StringReplace(T, '/', '.', [rfReplaceAll]);
  T := StringReplace(T, '-', '.', [rfReplaceAll]);
  T := StringReplace(T, ',', '.', [rfReplaceAll]);
  Result := False;
  if T = '' then
    Exit;

  P1 := Pos('.', T);
  if P1 <= 1 then
    Exit;
  P2 := Pos('.', Copy(T, P1 + 1, MaxInt));
  if P2 <= 0 then
  begin
    { формат ДД.ММ — год текущий }
    Day := StrToIntDef(Copy(T, 1, P1 - 1), -1);
    Month := StrToIntDef(Copy(T, P1 + 1, MaxInt), -1);
    Year := YearOf(Date);
  end
  else
  begin
    P2 := P1 + P2;
    Day := StrToIntDef(Copy(T, 1, P1 - 1), -1);
    Month := StrToIntDef(Copy(T, P1 + 1, P2 - P1 - 1), -1);
    Year := StrToIntDef(Copy(T, P2 + 1, MaxInt), -1);
    if (Year >= 0) and (Year <= 99) then
      if Year >= 50 then
        Year := 1900 + Year
      else
        Year := 2000 + Year;
  end;

  if (Day < 1) or (Day > 31) or (Month < 1) or (Month > 12) or (Year < 1900) or (Year > 2100) then
  begin
    FS := DefaultFormatSettings;
    FS.ShortDateFormat := 'dd.mm.yyyy';
    FS.DateSeparator := '.';
    Result := TryStrToDate(T, ADate, FS);
  end
  else
    Result := TryEncodeDate(Year, Month, Day, ADate);

  if Result then
    ADate := Trunc(ADate);
end;

function NormalizeKey(const S: string): string;
var
  I: Integer;
  U: UnicodeString;
  Ch: UnicodeChar;
begin
  U := UnicodeLowerCase(UnicodeString(S));
  Result := '';
  for I := 1 to Length(U) do
  begin
    Ch := U[I];
    if (Ch = #9) or (Ch = #10) or (Ch = #13) or (Ch = ' ') then
      Continue;
    Result := Result + string(Ch);
  end;
end;

function NormalizeISBNFormat(const S: string): string;
var
  I: Integer;
  Ch: Char;
  Input: string;
begin
  Result := '';
  Input := Trim(S);
  for I := 1 to Length(Input) do
  begin
    Ch := Input[I];
    if (Ch = '-') or (Ch = ' ') or (Ch = #9) then
      Continue;
    if UpCase(Ch) = 'X' then
      Result := Result + 'X'
    else
      Result := Result + Ch;
  end;
end;

end.
