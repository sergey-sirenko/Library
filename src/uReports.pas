unit uReports;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, uDatabase, uEntities, uTypes;

type
  TLoanStatisticsSummary = record
    Loans, Books, Readers, UnlinkedLoans: Integer;
  end;

  TReportService = class
  private
    FDB: TLibraryDB;
    function CsvEscape(const S: string): string;
  public
    constructor Create(ADB: TLibraryDB);
    function BooksCatalog: TStringList;
    function CopiesByStatus: TStringList;
    function AvailableCopies: TStringList;
    function FreeInventoryNumbers: TStringList;
    function BooksOnHands: TStringList;
    function OverdueLoans: TStringList;
    function LoansHistory(AFrom, ATo: TDateTime): TStringList;
    function LoansStatistics(AFrom, ATo: TDateTime; AByCategory: Boolean;
      out ASummary: TLoanStatisticsSummary): TStringList;
    function LoansStatisticsExport(ALines: TStrings; AFrom, ATo: TDateTime;
      AByCategory: Boolean; const ASummary: TLoanStatisticsSummary): TStringList;
    function PeriodTotals(AFrom, ATo: TDateTime; ADetailed: Boolean): TStringList;
    function PeriodTotalsExport(ALines: TStrings; AFrom, ATo: TDateTime): TStringList;
    function ReaderHistory(AReader: TReader): TStringList;
    function ReaderHistoryExport(ALines: TStrings; AReader: TReader): TStringList;
    function ReadersList: TStringList;
    function ActionsLog(AFrom, ATo: TDateTime): TStringList;
    procedure ExportToFile(ALines: TStrings; const AFile: string);
  end;

implementation

uses
  StrUtils, DateUtils, LazUTF8, Math, fgl;

type
  TCategoryIssueCounts = specialize TFPGMap<TId, Integer>;

  TLoanStatisticsGroup = class
    ID: TId;
    Title, Authors, Category: string;
    Loans: Integer;
    LastIssue: TDateTime;
    Books, Readers: TStringList;
    constructor Create;
    destructor Destroy; override;
  end;

function NewIDSet: TStringList;
begin
  Result := TStringList.Create;
  Result.Sorted := True;
  Result.Duplicates := dupIgnore;
end;

constructor TLoanStatisticsGroup.Create;
begin
  inherited Create;
  Books := NewIDSet;
  Readers := NewIDSet;
end;

destructor TLoanStatisticsGroup.Destroy;
begin
  Books.Free;
  Readers.Free;
  inherited Destroy;
end;

function CompareStatisticsGroups(P1, P2: Pointer): Integer;
var A, B: TLoanStatisticsGroup;
begin
  A := TLoanStatisticsGroup(P1);
  B := TLoanStatisticsGroup(P2);
  if A.Loans > B.Loans then Exit(-1);
  if A.Loans < B.Loans then Exit(1);
  Result := UTF8CompareText(A.Title, B.Title);
  if Result <> 0 then Exit;
  if A.ID < B.ID then Exit(-1);
  if A.ID > B.ID then Exit(1);
end;

procedure NormalizeReportPeriod(var AFrom, ATo: TDateTime);
begin
  if IsNan(AFrom) or IsInfinite(AFrom) or IsNan(ATo) or IsInfinite(ATo) or
    (AFrom < 1) or (ATo < 1) or (AFrom > 2958465) or (ATo > 2958465) then
    raise Exception.Create('Укажите корректные даты периода.');
  AFrom := DateOf(AFrom);
  ATo := DateOf(ATo);
  if AFrom > ATo then raise Exception.Create('Дата начала периода позже даты окончания.');
end;

function TReportService.LoansStatistics(AFrom, ATo: TDateTime; AByCategory: Boolean;
  out ASummary: TLoanStatisticsSummary): TStringList;
var Groups: TObjectList; Index, Books, Readers: TStringList;
  I, N: Integer; Key: string; Group: TLoanStatisticsGroup;
  Loan: TLoan; Copy: TCopy; Book: TBook; Category: TCategory;
begin
  ASummary := Default(TLoanStatisticsSummary);
  NormalizeReportPeriod(AFrom, ATo);
  Groups := TObjectList.Create(True);
  Index := TStringList.Create;
  Index.Sorted := True;
  Books := NewIDSet;
  Readers := NewIDSet;
  Result := TStringList.Create;
  try
    try
      if AByCategory then Result.Add('Категория;Выдач;Книг;Читателей')
      else Result.Add('Книга;Автор;Категория;Выдач;Читателей;Дата последней выдачи');
      for I := 0 to FDB.Loans.Count - 1 do
      begin
        Loan := TLoan(FDB.Loans[I]);
        if Loan.Deleted or (Loan.IssuedAt < AFrom) or (Loan.IssuedAt >= ATo + 1) then Continue;
        Copy := FDB.FindCopy(Loan.CopyID);
        Book := nil;
        if Copy <> nil then Book := FDB.FindBook(Copy.BookID);
        if Book = nil then
        begin
          Inc(ASummary.UnlinkedLoans);
          Continue;
        end;
        Category := FDB.FindCategory(Book.CategoryID);
        if AByCategory then
        begin
          if Category <> nil then Key := IntToStr(Category.ID) else Key := '0';
        end
        else Key := IntToStr(Book.ID);
        N := Index.IndexOf(Key);
        if N < 0 then
        begin
          Group := TLoanStatisticsGroup.Create;
          Groups.Add(Group);
          Group.ID := StrToInt64(Key);
          if Category <> nil then Group.Category := Category.Name
          else Group.Category := 'Без категории';
          if AByCategory then Group.Title := Group.Category
          else
          begin
            Group.Title := Book.Title;
            Group.Authors := Book.Authors;
          end;
          Index.AddObject(Key, Group);
        end
        else Group := TLoanStatisticsGroup(Index.Objects[N]);
        Inc(Group.Loans);
        if Loan.ReaderID > 0 then
        begin
          Group.Readers.Add(IntToStr(Loan.ReaderID));
          Readers.Add(IntToStr(Loan.ReaderID));
        end;
        Group.Books.Add(IntToStr(Book.ID));
        Books.Add(IntToStr(Book.ID));
        if Loan.IssuedAt > Group.LastIssue then Group.LastIssue := Loan.IssuedAt;
        Inc(ASummary.Loans);
      end;
      ASummary.Books := Books.Count;
      ASummary.Readers := Readers.Count;
      Groups.Sort(@CompareStatisticsGroups);
      for I := 0 to Groups.Count - 1 do
      begin
        Group := TLoanStatisticsGroup(Groups[I]);
        if AByCategory then
          Result.Add(Format('%s;%d;%d;%d', [CsvEscape(Group.Title), Group.Loans,
            Group.Books.Count, Group.Readers.Count]))
        else
          Result.Add(Format('%s;%s;%s;%d;%d;%s', [CsvEscape(Group.Title),
            CsvEscape(Group.Authors), CsvEscape(Group.Category), Group.Loans,
            Group.Readers.Count, FormatDateTimeRu(Group.LastIssue)]));
      end;
    except
      Result.Free;
      raise;
    end;
  finally
    Readers.Free;
    Books.Free;
    Index.Free;
    Groups.Free;
  end;
end;

function TReportService.LoansStatisticsExport(ALines: TStrings; AFrom, ATo: TDateTime;
  AByCategory: Boolean; const ASummary: TLoanStatisticsSummary): TStringList;
begin
  Result := TStringList.Create;
  Result.Add('Статистика выдач');
  Result.Add('Период с;' + FormatDateRu(DateOf(AFrom)) + ';по;' + FormatDateRu(DateOf(ATo)));
  if AByCategory then Result.Add('Группировка;По категориям')
  else Result.Add('Группировка;По книгам');
  Result.Add('Всего выдач;' + IntToStr(ASummary.Loans));
  Result.Add('Разных книг;' + IntToStr(ASummary.Books));
  Result.Add('Уникальных читателей;' + IntToStr(ASummary.Readers));
  if ASummary.UnlinkedLoans > 0 then
    Result.Add('Не удалось связать с книгой (не включены);' + IntToStr(ASummary.UnlinkedLoans));
  Result.Add('');
  Result.AddStrings(ALines);
end;

function TReportService.PeriodTotals(AFrom, ATo: TDateTime; ADetailed: Boolean): TStringList;
var
  DayAfter: TDateTime;
  ReaderIDs, CopiesOnHands: TStringList;
  CategoryCounts: TCategoryIssueCounts;
  I, Index, Issued, Returned, NewReaders: Integer;
  CategoryID: TId;
  Loan: TLoan;
  Reader: TReader;
  Copy: TCopy;
  Book: TBook;
  Category: TCategory;
  CategoryName: string;
begin
  NormalizeReportPeriod(AFrom, ATo);
  DayAfter := ATo + 1;
  ReaderIDs := NewIDSet;
  CopiesOnHands := nil;
  CategoryCounts := nil;
  try
    if ADetailed then
    begin
      CopiesOnHands := NewIDSet;
      CategoryCounts := TCategoryIssueCounts.Create;
      CategoryCounts.Sorted := True;
    end;
    Issued := 0;
    Returned := 0;
    NewReaders := 0;
    for I := 0 to FDB.Loans.Count - 1 do
    begin
      Loan := TLoan(FDB.Loans[I]);
      if Loan.Deleted or (Loan.IssuedAt < 1) or (Loan.IssuedAt >= DayAfter) then
        Continue;
      if ADetailed then
      begin
        if (Loan.State = lsReturned) and (Loan.ReturnedAt >= AFrom) and
          (Loan.ReturnedAt < DayAfter) and (Loan.ReturnedAt >= Loan.IssuedAt) then
          Inc(Returned);
        if (Loan.CopyID > 0) and (Loan.State <> lsLost) and
          ((Loan.ReturnedAt >= DayAfter) or ((Loan.State = lsLoaned) and (Loan.ReturnedAt = 0))) then
          CopiesOnHands.Add(IntToStr(Loan.CopyID));
      end;
      if Loan.IssuedAt < AFrom then
        Continue;

      Inc(Issued);
      if Loan.ReaderID > 0 then
        ReaderIDs.Add(IntToStr(Loan.ReaderID));
      if ADetailed then
      begin
        CategoryID := 0;
        Copy := FDB.FindCopy(Loan.CopyID);
        if Copy <> nil then
        begin
          Book := FDB.FindBook(Copy.BookID);
          if (Book <> nil) and (FDB.FindCategory(Book.CategoryID) <> nil) then
            CategoryID := Book.CategoryID;
        end;
        Index := CategoryCounts.IndexOf(CategoryID);
        if Index < 0 then
          CategoryCounts.Add(CategoryID, 1)
        else
          CategoryCounts.Data[Index] := CategoryCounts.Data[Index] + 1;
      end;
    end;

    for I := 0 to FDB.Readers.Count - 1 do
    begin
      Reader := TReader(FDB.Readers[I]);
      if (Reader.RegisteredAt >= AFrom) and (Reader.RegisteredAt < DayAfter) and
        (ReaderIDs.IndexOf(IntToStr(Reader.ID)) >= 0) then
        Inc(NewReaders);
    end;

    Result := TStringList.Create;
    try
      Result.Add('Показатель;Количество');
      Result.Add('Итого читателей;' + IntToStr(ReaderIDs.Count));
      Result.Add('Из них новых;' + IntToStr(NewReaders));
      Result.Add('Итого выдано книг;' + IntToStr(Issued));
      if ADetailed then
      begin
        Result.Add('Из них по категориям;');
        for I := 0 to CategoryCounts.Count - 1 do
        begin
          Category := FDB.FindCategory(CategoryCounts.Keys[I]);
          if Category <> nil then
            CategoryName := Category.Name
          else
            CategoryName := 'Без категории';
          Result.Add(CsvEscape('    ' + CategoryName) + ';' + IntToStr(CategoryCounts.Data[I]));
        end;
        Result.Add('Итого возвращено книг;' + IntToStr(Returned));
        Result.Add('Итого на руках книг;' + IntToStr(CopiesOnHands.Count));
      end;
    except
      Result.Free;
      raise;
    end;
  finally
    CategoryCounts.Free;
    CopiesOnHands.Free;
    ReaderIDs.Free;
  end;
end;

function TReportService.PeriodTotalsExport(ALines: TStrings; AFrom, ATo: TDateTime): TStringList;
begin
  Result := TStringList.Create;
  try
    Result.Add('Итоговый отчёт за период');
    Result.Add('Период с;' + FormatDateRu(DateOf(AFrom)) + ';по;' + FormatDateRu(DateOf(ATo)));
    Result.Add('');
    Result.AddStrings(ALines);
  except
    Result.Free;
    raise;
  end;
end;

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
  Category: TCategory;
  Title, LocationName, CategoryName: string;
begin
  Result := TStringList.Create;
  Result.Add('Инв.№;Книга;Статус;Место;Состояние;Категория');
  for I := 0 to FDB.Copies.Count - 1 do
  begin
    C := TCopy(FDB.Copies[I]);
    if C.Deleted then Continue;
    Title := '';
    CategoryName := '';
    B := FDB.FindBook(C.BookID);
    if B <> nil then
    begin
      Title := B.Title;
      Category := FDB.FindCategory(B.CategoryID);
      if Category <> nil then
        CategoryName := Category.Name;
    end;
    L := FDB.FindLocation(C.LocationID);
    if L <> nil then LocationName := L.Name else LocationName := '';
    Result.Add(Format('%s;%s;%s;%s;%s;%s',
      [CsvEscape(C.InventoryNo), CsvEscape(Title), CsvEscape(CopyStatusToStr(C.Status)),
       CsvEscape(LocationName), CsvEscape(C.Condition), CsvEscape(CategoryName)]));
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

function TReportService.FreeInventoryNumbers: TStringList;
{ Пропущенные целые номера от 1 до наибольшего уже заведённого.
  Логически удалённый экземпляр номер занимает. Нечисловые номера,
  например «Б-1», в диапазон не входят. }
var
  I, J, Count: Integer;
  C: TCopy;
  Value, Expected, Tmp: Int64;
  Used: array of Int64;
begin
  Result := TStringList.Create;
  Result.Add('Свободные номера');
  Count := 0;
  if FDB.Copies.Count > 0 then
  begin
    SetLength(Used, FDB.Copies.Count);
    for I := 0 to FDB.Copies.Count - 1 do
    begin
      C := TCopy(FDB.Copies[I]);
      if TryStrToInt64(Trim(C.InventoryNo), Value) and (Value >= 1) then
      begin
        Used[Count] := Value;
        Inc(Count);
      end;
    end;
  end;
  if Count = 0 then
    Exit;
  SetLength(Used, Count);
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
  Expected := 1;
  for I := 0 to Count - 1 do
  begin
    Value := Used[I];
    if Value < Expected then
      Continue;
    if Expected < Value then
    begin
      if Expected = Value - 1 then
        Result.Add(IntToStr(Expected))
      else
        Result.Add(IntToStr(Expected) + '-' + IntToStr(Value - 1));
    end;
    if Value = High(Int64) then
      Break;
    Expected := Value + 1;
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
  Category: TCategory;
  InventoryNo, Title, CategoryName, DueDate: string;
begin
  Result := TStringList.Create;
  Result.Add('Дата выдачи;Инв.№;Книга;Категория;Состояние;Срок возврата;Дата возврата');
  if AReader = nil then Exit;
  for I := 0 to FDB.Loans.Count - 1 do
  begin
    L := TLoan(FDB.Loans[I]);
    if L.Deleted or (L.ReaderID <> AReader.ID) then Continue;
    InventoryNo := '';
    Title := '';
    CategoryName := '';
    DueDate := '';
    C := FDB.FindCopy(L.CopyID);
    if C <> nil then
    begin
      InventoryNo := C.InventoryNo;
      B := FDB.FindBook(C.BookID);
      if B <> nil then
      begin
        Title := B.Title;
        Category := FDB.FindCategory(B.CategoryID);
        if Category <> nil then
          CategoryName := Category.Name;
      end;
    end;
    if L.State = lsLoaned then
      DueDate := FormatDateRu(L.DueAt);
    Result.Add(Format('%s;%s;%s;%s;%s;%s;%s',
      [FormatDateTimeRu(L.IssuedAt), CsvEscape(InventoryNo), CsvEscape(Title),
       CsvEscape(CategoryName), LoanStateToStr(L.State), DueDate, FormatDateTimeRu(L.ReturnedAt)]));
  end;
end;

function TReportService.ReaderHistoryExport(ALines: TStrings; AReader: TReader): TStringList;
begin
  Result := TStringList.Create;
  try
    Result.Add('Электронный формуляр');
    if AReader <> nil then
      Result.Add('Читатель;' + CsvEscape(AReader.FullName) + ';ID;' + IntToStr(AReader.ID));
    Result.Add('');
    Result.AddStrings(ALines);
  except
    Result.Free;
    raise;
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
