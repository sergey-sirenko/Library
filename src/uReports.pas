unit uReports;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, uDatabase, uEntities, uTypes;

type
  TReportService = class
  private
    FDB: TLibraryDB;
    function CsvEscape(const S: string): string;
  public
    constructor Create(ADB: TLibraryDB);
    function BooksCatalog: TStringList;
    function CopiesByStatus: TStringList;
    function AvailableCopies: TStringList;
    function BooksOnHands: TStringList;
    function OverdueLoans: TStringList;
    function LoansHistory(AFrom, ATo: TDateTime): TStringList;
    function ReaderHistory(AReader: TReader): TStringList;
    function ReadersList: TStringList;
    function ActionsLog(AFrom, ATo: TDateTime): TStringList;
    procedure ExportToFile(ALines: TStrings; const AFile: string);
  end;

implementation

uses
  StrUtils;

constructor TReportService.Create(ADB: TLibraryDB);
begin
  inherited Create;
  FDB := ADB;
end;

function TReportService.CsvEscape(const S: string): string;
begin
  Result := S;
  if (Pos(';', Result) > 0) or (Pos('"', Result) > 0) or (Pos(#10, Result) > 0) or (Pos(#13, Result) > 0) then
  begin
    Result := StringReplace(Result, '"', '""', [rfReplaceAll]);
    Result := '"' + Result + '"';
  end;
end;

procedure TReportService.ExportToFile(ALines: TStrings; const AFile: string);
begin
  ALines.SaveToFile(AFile);
end;

function TReportService.BooksCatalog: TStringList;
var
  I: Integer;
  B: TBook;
  C: TCategory;
  CatName: string;
begin
  Result := TStringList.Create;
  Result.Add('Название;Автор;Категория;Год;Издательство;ISBN');
  for I := 0 to FDB.Books.Count - 1 do
  begin
    B := TBook(FDB.Books[I]);
    if B.Deleted then Continue;
    C := FDB.FindCategory(B.CategoryID);
    if C <> nil then CatName := C.Name else CatName := '';
    Result.Add(Format('%s;%s;%s;%d;%s;%s',
      [CsvEscape(B.Title), CsvEscape(B.Authors), CsvEscape(CatName), B.Year,
       CsvEscape(B.Publisher), CsvEscape(B.ISBN)]));
  end;
end;

function TReportService.CopiesByStatus: TStringList;
var
  I: Integer;
  C: TCopy;
  B: TBook;
  L: TLocation;
  Title, LocationName: string;
begin
  Result := TStringList.Create;
  Result.Add('Инв.№;Книга;Статус;Место;Состояние');
  for I := 0 to FDB.Copies.Count - 1 do
  begin
    C := TCopy(FDB.Copies[I]);
    if C.Deleted then Continue;
    B := FDB.FindBook(C.BookID);
    if B <> nil then Title := B.Title else Title := '';
    L := FDB.FindLocation(C.LocationID);
    if L <> nil then LocationName := L.Name else LocationName := '';
    Result.Add(Format('%s;%s;%s;%s;%s',
      [CsvEscape(C.InventoryNo), CsvEscape(Title), CsvEscape(CopyStatusToStr(C.Status)),
       CsvEscape(LocationName), CsvEscape(C.Condition)]));
  end;
end;

function CompareCopyByInv(P1, P2: Pointer): Integer;
var
  C1, C2: TCopy;
begin
  C1 := TCopy(P1);
  C2 := TCopy(P2);
  Result := AnsiCompareStr(C1.InventoryNo, C2.InventoryNo);
end;

function TReportService.AvailableCopies: TStringList;
var
  I: Integer;
  C: TCopy;
  B: TBook;
  L: TLocation;
  Title, LocationName: string;
  List: TList;
begin
  Result := TStringList.Create;
  Result.Add('Инв.№;Книга;Место хранения;Состояние;Дата поступления');
  List := TList.Create;
  try
    for I := 0 to FDB.Copies.Count - 1 do
    begin
      C := TCopy(FDB.Copies[I]);
      if C.Deleted then Continue;
      if C.Status <> csAvailable then Continue;
      List.Add(C);
    end;
    List.Sort(@CompareCopyByInv);
    for I := 0 to List.Count - 1 do
    begin
      C := TCopy(List[I]);
      B := FDB.FindBook(C.BookID);
      if B <> nil then Title := B.Title else Title := '';
      L := FDB.FindLocation(C.LocationID);
      if L <> nil then LocationName := L.Name else LocationName := '';
      Result.Add(Format('%s;%s;%s;%s;%s',
        [CsvEscape(C.InventoryNo), CsvEscape(Title), CsvEscape(LocationName),
         CsvEscape(C.Condition), FormatDateRu(C.ReceivedAt)]));
    end;
  finally
    List.Free;
  end;
end;

function TReportService.BooksOnHands: TStringList;
var
  I: Integer;
  L: TLoan;
  C: TCopy;
  R: TReader;
  B: TBook;
begin
  Result := TStringList.Create;
  Result.Add('Инв.№;Книга;Читатель;Дата выдачи;Срок возврата');
  for I := 0 to FDB.Loans.Count - 1 do
  begin
    L := TLoan(FDB.Loans[I]);
    if L.Deleted or (L.State <> lsLoaned) then Continue;
    C := FDB.FindCopy(L.CopyID);
    R := FDB.FindReader(L.ReaderID);
    B := nil;
    if C <> nil then B := FDB.FindBook(C.BookID);
    Result.Add(Format('%s;%s;%s;%s;%s',
      [CsvEscape(IfThen(C <> nil, C.InventoryNo, '')),
       CsvEscape(IfThen(B <> nil, B.Title, '')),
       CsvEscape(IfThen(R <> nil, R.FullName, '')),
       FormatDateRu(L.IssuedAt), FormatDateRu(L.DueAt)]));
  end;
end;

function TReportService.OverdueLoans: TStringList;
var
  List: TList;
  I: Integer;
  L: TLoan;
  C: TCopy;
  R: TReader;
  B: TBook;
  Days: Integer;
begin
  Result := TStringList.Create;
  Result.Add('Инв.№;Книга;Читатель;Срок;Дней просрочки');
  List := TList.Create;
  try
    FDB.CollectOverdue(List);
    for I := 0 to List.Count - 1 do
    begin
      L := TLoan(List[I]);
      C := FDB.FindCopy(L.CopyID);
      R := FDB.FindReader(L.ReaderID);
      B := nil;
      if C <> nil then B := FDB.FindBook(C.BookID);
      Days := Trunc(Date - Trunc(L.DueAt));
      Result.Add(Format('%s;%s;%s;%s;%d',
        [CsvEscape(IfThen(C <> nil, C.InventoryNo, '')),
         CsvEscape(IfThen(B <> nil, B.Title, '')),
         CsvEscape(IfThen(R <> nil, R.FullName, '')),
         FormatDateRu(L.DueAt), Days]));
    end;
  finally
    List.Free;
  end;
end;

function TReportService.LoansHistory(AFrom, ATo: TDateTime): TStringList;
var
  I: Integer;
  L: TLoan;
  C: TCopy;
  R: TReader;
begin
  Result := TStringList.Create;
  Result.Add('Дата выдачи;Инв.№;Читатель;Состояние;Дата возврата');
  for I := 0 to FDB.Loans.Count - 1 do
  begin
    L := TLoan(FDB.Loans[I]);
    if L.Deleted then Continue;
    if (AFrom > 0) and (L.IssuedAt < AFrom) then Continue;
    if (ATo > 0) and (L.IssuedAt > ATo + 1) then Continue;
    C := FDB.FindCopy(L.CopyID);
    R := FDB.FindReader(L.ReaderID);
    Result.Add(Format('%s;%s;%s;%s;%s',
      [FormatDateTimeRu(L.IssuedAt),
       CsvEscape(IfThen(C <> nil, C.InventoryNo, '')),
       CsvEscape(IfThen(R <> nil, R.FullName, '')),
       LoanStateToStr(L.State), FormatDateTimeRu(L.ReturnedAt)]));
  end;
end;

function TReportService.ReaderHistory(AReader: TReader): TStringList;
var
  I: Integer;
  L: TLoan;
  C: TCopy;
  B: TBook;
begin
  Result := TStringList.Create;
  Result.Add('Дата;Инв.№;Книга;Состояние;Срок;Возврат');
  if AReader = nil then Exit;
  for I := 0 to FDB.Loans.Count - 1 do
  begin
    L := TLoan(FDB.Loans[I]);
    if L.Deleted or (L.ReaderID <> AReader.ID) then Continue;
    C := FDB.FindCopy(L.CopyID);
    B := nil;
    if C <> nil then B := FDB.FindBook(C.BookID);
    Result.Add(Format('%s;%s;%s;%s;%s;%s',
      [FormatDateTimeRu(L.IssuedAt),
       CsvEscape(IfThen(C <> nil, C.InventoryNo, '')),
       CsvEscape(IfThen(B <> nil, B.Title, '')),
       LoanStateToStr(L.State), FormatDateRu(L.DueAt), FormatDateTimeRu(L.ReturnedAt)]));
  end;
end;

function TReportService.ReadersList: TStringList;
var
  I: Integer;
  R: TReader;
begin
  Result := TStringList.Create;
  Result.Add('ФИО;Телефон;Статус;Дата регистрации;Адрес');
  for I := 0 to FDB.Readers.Count - 1 do
  begin
    R := TReader(FDB.Readers[I]);
    if R.Deleted then Continue;
    Result.Add(Format('%s;%s;%s;%s;%s',
      [CsvEscape(R.FullName), CsvEscape(R.Phone), ReaderStatusToStr(R.Status),
       FormatDateRu(R.RegisteredAt), CsvEscape(R.Address)]));
  end;
end;

function TReportService.ActionsLog(AFrom, ATo: TDateTime): TStringList;
var
  I: Integer;
  A: TActionLogItem;
begin
  Result := TStringList.Create;
  Result.Add('Дата;Пользователь;Действие;Описание');
  for I := 0 to FDB.Actions.Count - 1 do
  begin
    A := TActionLogItem(FDB.Actions[I]);
    if (AFrom > 0) and (A.When < AFrom) then Continue;
    if (ATo > 0) and (A.When > ATo + 1) then Continue;
    Result.Add(Format('%s;%s;%s;%s',
      [FormatDateTimeRu(A.When), CsvEscape(A.UserName),
       CsvEscape(ActionTypeToStr(A.Action)), CsvEscape(A.Description)]));
  end;
end;

end.
