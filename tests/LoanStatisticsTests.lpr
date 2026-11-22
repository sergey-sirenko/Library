program LoanStatisticsTests;

{$mode objfpc}{$H+}

uses Classes, SysUtils, DateUtils, uDatabase, uEntities, uTypes, uReports, uReportTotals;

var Checks: Integer;

procedure Check(Value: Boolean; const Msg: string);
begin
  Inc(Checks);
  if not Value then raise Exception.Create(Msg);
end;

function Book(DB: TLibraryDB; ID, CategoryID: TId; const Title: string): TBook;
begin
  Result := TBook.Create;
  Result.ID := ID;
  Result.CategoryID := CategoryID;
  Result.Title := Title;
  Result.Authors := 'Автор';
  DB.Books.Add(Result);
end;

function CopyOf(DB: TLibraryDB; ID, BookID: TId): TCopy;
begin
  Result := TCopy.Create;
  Result.ID := ID;
  Result.BookID := BookID;
  DB.Copies.Add(Result);
end;

function Loan(DB: TLibraryDB; CopyID, ReaderID: TId; Issued: TDateTime): TLoan;
begin
  Result := TLoan.Create;
  Result.ID := DB.Loans.Count + 1;
  Result.CopyID := CopyID;
  Result.ReaderID := ReaderID;
  Result.IssuedAt := Issued;
  Result.State := lsLoaned;
  DB.Loans.Add(Result);
end;

procedure Category(DB: TLibraryDB; ID: TId; const Name: string);
var C: TCategory;
begin
  C := TCategory.Create;
  C.ID := ID;
  C.Name := Name;
  DB.Categories.Add(C);
end;

function Field(Lines: TStrings; Row, Col: Integer): string;
var Parts: TStringList;
begin
  Parts := TStringList.Create;
  try
    Parts.StrictDelimiter := True;
    Parts.Delimiter := ';';
    Parts.QuoteChar := '"';
    Parts.DelimitedText := Lines[Row];
    Result := Parts[Col];
  finally
    Parts.Free;
  end;
end;

procedure TestStatistics;
var DB: TLibraryDB; Reports: TReportService; Lines, CSV: TStringList;
  Summary: TLoanStatisticsSummary; Day: TDateTime; L: TLoan; Rejected: Boolean;
begin
  // База только в памяти: Open/Save и реальный каталог библиотеки не используются.
  DB := TLibraryDB.Create;
  Reports := TReportService.Create(DB);
  try
    Day := EncodeDate(2026, 10, 18);
    Category(DB, 1, 'Богословие; "Учение"');
    Category(DB, 2, 'История');
    Book(DB, 9000000000, 1, 'Свет; "Вера"' + #10 + 'Том 1');
    Book(DB, 2, 1, 'Другая');
    Book(DB, 3, 2, 'История');
    Book(DB, 4, 999, 'Без категории');
    Book(DB, 5, 2, 'Не брали');
    CopyOf(DB, 1, 9000000000);
    CopyOf(DB, 2, 9000000000).Deleted := True;
    CopyOf(DB, 3, 2);
    CopyOf(DB, 4, 3);
    CopyOf(DB, 5, 4);
    CopyOf(DB, 6, 999); // Повреждённая связь, отдельное предупреждение.
    L := Loan(DB, 1, 1, Day);
    L.State := lsReturned;
    L.ReturnedAt := Day + 10;
    L.RenewCount := 9;
    Loan(DB, 2, 1, Day + EncodeTime(23, 59, 59, 999));
    Loan(DB, 1, 9000000000, Day + 0.5);
    Loan(DB, 3, 1, Day + 0.3);
    Loan(DB, 4, 2, Day + 0.4);
    Loan(DB, 5, 2, Day + 0.6);
    Loan(DB, 1, 55, Day - 1 / 86400);
    Loan(DB, 1, 56, Day + 1);
    Loan(DB, 1, 57, Day + 1 / 86400).Deleted := True;
    L := Loan(DB, 1, 58, Day - 10);
    L.ReturnedAt := Day;
    L.State := lsReturned;
    Loan(DB, 999, 59, Day);
    Loan(DB, 6, 60, Day);
    DB.FindBook(9000000000).Deleted := True;
    DB.FindCategory(1).Deleted := True;
    Lines := Reports.LoansStatistics(Day, Day, False, Summary);
    try
      Check(Summary.Loans = 6, 'границы дня, возвраты и продления учитываются по дате выдачи');
      Check(Summary.Books = 4, 'разные экземпляры объединены в книгу');
      Check(Summary.Readers = 3, 'уникальные читатели по ID, включая Int64');
      Check(Summary.UnlinkedLoans = 2, 'нарушенные связи отмечены явно');
      Check(Lines.Count = 5, 'книги без выдач не включаются');
      Check(Field(Lines, 1, 0) = DB.FindBook(9000000000).Title, 'наиболее популярная книга первая');
      Check(Field(Lines, 1, 3) = '3', 'несколько экземпляров и удалённая книга учитываются');
      Check(Field(Lines, 1, 4) = '2', 'повторные выдачи одному читателю не дублируют читателя');
      Check(Field(Lines, 1, 2) = 'Богословие; "Учение"', 'удалённая категория и экранирование CSV');
      Check(Field(Lines, 1, 5) = FormatDateTimeRu(Day + EncodeTime(23, 59, 59, 999)),
        'дата последней выдачи внутри периода');
      CSV := Reports.LoansStatisticsExport(Lines, Day, Day, False, Summary);
      try
        Check(CSV[0] = 'Статистика выдач', 'согласованное название отчёта');
        Check(Pos('18.10.2026;по;18.10.2026', CSV[1]) > 0, 'CSV содержит включительный период');
        Check(CSV.IndexOf('Всего выдач;6') >= 0, 'итоги CSV соответствуют таблице');
        Check(CSV.IndexOf('Разных книг;4') >= 0, 'CSV содержит число книг');
        Check(CSV.IndexOf('Уникальных читателей;3') >= 0, 'CSV содержит число читателей');
        Check(Pos('не включены);2', CSV.Text) > 0, 'предупреждение о связях включено в CSV');
        Check(CSV[CSV.Count - 1] = Lines[Lines.Count - 1], 'экспорт сохраняет строки без изменения');
      finally CSV.Free; end;
    finally Lines.Free; end;
    Lines := Reports.LoansStatistics(Day + 0.2, Day + 0.8, True, Summary);
    try
      Check(Summary.Loans = 6, 'время в границах нормализуется до календарных дней');
      Check(Lines.Count = 4, 'группы по категориям, включая отсутствующую');
      Check(Field(Lines, 1, 0) = DB.FindCategory(1).Name, 'категории упорядочены по числу выдач');
      Check(Field(Lines, 1, 1) = '4', 'выдачи книг категории суммируются');
      Check(Field(Lines, 1, 2) = '2', 'число разных книг категории');
      Check(Field(Lines, 1, 3) = '2', 'читатель разных книг одной категории посчитан один раз');
      Check(Field(Lines, 2, 0) = 'Без категории', 'нет категории — явная отдельная группа');
      CSV := Reports.LoansStatisticsExport(Lines, Day, Day, True, Summary);
      try Check(CSV.IndexOf('Группировка;По категориям') >= 0, 'CSV отмечает представление');
      finally CSV.Free; end;
    finally Lines.Free; end;
    DB.FindBook(2).CategoryID := 2;
    Lines := Reports.LoansStatistics(Day, Day, True, Summary);
    try Check(Field(Lines, 1, 1) = '3', 'категория учитывается текущая');
    finally Lines.Free; end;
    Lines := Reports.LoansStatistics(Day + 2, Day + 2, False, Summary);
    try
      Check((Lines.Count = 1) and (Summary.Loans = 0) and (Summary.Books = 0) and
        (Summary.Readers = 0), 'пустой период — заголовок и нулевые итоги');
    finally Lines.Free; end;
    Rejected := False;
    try
      Lines := Reports.LoansStatistics(Day + 1, Day, False, Summary);
      Lines.Free;
    except on E: Exception do Rejected := True; end;
    Check(Rejected, 'обратный период отклоняется');
    Rejected := False;
    try
      Lines := Reports.LoansStatistics(0, Day, False, Summary);
      Lines.Free;
    except on E: Exception do Rejected := True; end;
    Check(Rejected, 'пустая дата отклоняется');
  finally
    Reports.Free;
    DB.Free;
  end;
end;

procedure TestDistinctBooks;
var DB: TLibraryDB; Reports: TReportService; Lines, Exported: TStringList;
  Summary: TLoanStatisticsSummary; Totals: TReportTotals; Day: TDateTime;
  ByCategory: Boolean; ReaderColumn, Row: Integer;
begin
  DB := TLibraryDB.Create;
  Reports := TReportService.Create(DB);
  try
    Day := EncodeDate(2026, 1, 31);
    Category(DB, 1, 'Одинаковая');
    Category(DB, 2, 'Одинаковая');
    Book(DB, 1, 1, 'Одинаковая');
    Book(DB, 2, 2, 'Одинаковая');
    CopyOf(DB, 1, 1);
    CopyOf(DB, 2, 2);
    Loan(DB, 1, 1, Day);
    Loan(DB, 2, 1, Day);
    for ByCategory := False to True do
    begin
      Lines := Reports.LoansStatistics(Day, Day, ByCategory, Summary);
      try
        Check((Lines.Count = 3) and (Summary.Books = 2), 'одинаковые названия не объединяют разные ID');
        Check(Summary.Readers = 1, 'один читатель учтён в общем итоге один раз');
        Lines[0] := '№ п/п;' + Lines[0];
        for Row := 1 to Lines.Count - 1 do
          Lines[Row] := IntToStr(Row) + ';' + Lines[Row];
        if ByCategory then
          ReaderColumn := 4
        else
          ReaderColumn := 5;
        Check((Field(Lines, 1, ReaderColumn) = '1') and (Field(Lines, 2, ReaderColumn) = '1'),
          'читатель учтён в каждой из двух групп');
        Totals := CalculateReportTotals(Lines, Summary.Readers);
        Check((Totals.Caption = 'Итого') and (Totals.Cells[ReaderColumn] = '1') and
          (Totals.Cells[ReaderColumn - 1] = '2'), 'в подвале уникальные читатели и сумма соседней колонки');
        Exported := ReportWithTotals(Lines, Summary.Readers);
        try
          Check((Field(Exported, 3, 0) = 'Итого') and (Field(Exported, 3, ReaderColumn) = '1'),
            'в итоговой строке CSV один читатель');
        finally
          Exported.Free;
        end;
      finally
        Lines.Free;
      end;
    end;
  finally Reports.Free; DB.Free; end;
end;

procedure TestReaderHistory;
var
  DB: TLibraryDB;
  Reports: TReportService;
  Reader: TReader;
  Returned: TLoan;
  Lines, Exported: TStringList;
  Day: TDateTime;
begin
  DB := TLibraryDB.Create;
  Reports := TReportService.Create(DB);
  Reader := TReader.Create;
  try
    Reader.ID := 9000000000;
    Reader.FullName := 'Тестовый; читатель';
    Day := EncodeDate(2026, 1, 31);
    Category(DB, 1, 'Категория; раздел');
    Book(DB, 1, 1, 'Первая книга');
    Book(DB, 2, 0, 'Вторая книга');
    CopyOf(DB, 1, 1).InventoryNo := '001';
    CopyOf(DB, 2, 2).InventoryNo := '002';
    Loan(DB, 1, Reader.ID, Day).DueAt := Day + 14;
    Returned := Loan(DB, 2, Reader.ID, Day + 1);
    Returned.State := lsReturned;
    Returned.DueAt := Day + 15;
    Returned.ReturnedAt := Day + 3;
    Loan(DB, 1, 1, Day);
    Loan(DB, 2, Reader.ID, Day).Deleted := True;
    Loan(DB, 999, Reader.ID, Day);
    Lines := Reports.ReaderHistory(Reader);
    try
      Check(Lines.Count = 4, 'формуляр выбирает только неудалённые выдачи читателя');
      Check((Field(Lines, 1, 0) = FormatDateTimeRu(Day)) and
        (Field(Lines, 1, 2) = 'Первая книга') and (Field(Lines, 1, 3) = 'Категория; раздел'),
        'дата выдачи, название и категория с разделителем');
      Check((Field(Lines, 1, 5) = FormatDateRu(Day + 14)) and (Field(Lines, 1, 6) = ''),
        'у открытой выдачи есть срок возврата');
      Check((Field(Lines, 2, 3) = '') and (Field(Lines, 2, 5) = '') and
        (Field(Lines, 2, 6) = FormatDateTimeRu(Day + 3)), 'у завершённой выдачи есть фактическая дата');
      Check(Field(Lines, 3, 2) = '', 'утраченная связь с экземпляром оставляет название пустым');
      Exported := Reports.ReaderHistoryExport(Lines, Reader);
      try
        Check((Field(Exported, 1, 1) = Reader.FullName) and
          (Field(Exported, 1, 3) = IntToStr(Reader.ID)), 'CSV идентифицирует читателя');
        Check(Exported[Exported.Count - 1] = Lines[Lines.Count - 1], 'CSV сохраняет выдачи');
      finally
        Exported.Free;
      end;
    finally
      Lines.Free;
    end;
  finally
    Reader.Free;
    Reports.Free;
    DB.Free;
  end;
end;

procedure TestPeriodTotals;
var
  DB: TLibraryDB;
  Reports: TReportService;
  Lines, Detailed, Exported: TStringList;
  Reader: TReader;
  Entry: TLoan;
  Day: TDateTime;
  I: Integer;
begin
  DB := TLibraryDB.Create;
  Reports := TReportService.Create(DB);
  try
    Day := EncodeDate(2026, 1, 31);
    for I := 1 to 3 do
    begin
      Reader := TReader.Create;
      Reader.ID := I;
      Reader.RegisteredAt := Day;
      if I = 2 then
        Reader.RegisteredAt := Day - 1;
      DB.Readers.Add(Reader);
    end;
    Category(DB, 1, 'Книги; раздел');
    Book(DB, 1, 1, 'Первая книга');
    Book(DB, 2, 0, 'Вторая книга');
    for I := 1 to 9 do
      CopyOf(DB, I, 1);
    DB.FindCopy(3).BookID := 2;

    Entry := Loan(DB, 1, 1, Day);
    Entry.State := lsReturned;
    Entry.ReturnedAt := Day + 0.5;
    Entry.RenewCount := 4;
    Entry := Loan(DB, 2, 1, Day + 1 + EncodeTime(23, 59, 59, 999));
    Entry.State := lsReturned;
    Entry.ReturnedAt := Day + 2;
    Loan(DB, 3, 2, Day + 1);
    Entry := Loan(DB, 4, 2, Day - 1);
    Entry.State := lsReturned;
    Entry.ReturnedAt := Day;
    Loan(DB, 5, 2, Day - 1);
    Loan(DB, 6, 3, Day + 2);
    Loan(DB, 7, 3, Day).Deleted := True;
    Entry := Loan(DB, 8, 2, Day - 3);
    Entry.State := lsReturned;
    Entry.ReturnedAt := Day - 1;
    Loan(DB, 9, 2, Day - 2).State := lsLost;

    Lines := Reports.PeriodTotals(Day, Day + 1, False);
    try
      Check(Lines.Count = 4, 'краткий отчёт содержит три показателя');
      Check(Lines[1] = 'Итого читателей;2', 'читатель с несколькими выдачами учитывается один раз');
      Check(Lines[2] = 'Из них новых;1', 'только получившие книгу новые читатели');
      Check(Lines[3] = 'Итого выдано книг;3', 'выдачи по границам, без продлений и удалённых выдач');
      Detailed := Reports.PeriodTotals(Day, Day + 1, True);
      try
        for I := 0 to Lines.Count - 1 do
          Check(Detailed[I] = Lines[I], 'подробный режим сохраняет общие итоги');
        Check(Detailed.Count = 9, 'разбивка по двум категориям, возвраты и остаток');
        Check((Trim(Field(Detailed, 5, 0)) = 'Без категории') and
          (Field(Detailed, 5, 1) = '1'), 'выдача книги без категории входит в разбивку');
        Check((Trim(Field(Detailed, 6, 0)) = 'Книги; раздел') and
          (Field(Detailed, 6, 1) = '2'), 'категория с разделителем и две выдачи');
        Check(Detailed[7] = 'Итого возвращено книг;2', 'возврат до полуночи, включая более раннюю выдачу');
        Check(Detailed[8] = 'Итого на руках книг;3', 'остаток включает раннюю выдачу и возврат после периода');
        Exported := Reports.PeriodTotalsExport(Detailed, Day, Day + 1);
        try
          Check(Exported[1] = 'Период с;31.01.2026;по;01.02.2026', 'CSV содержит период');
          Check(Exported[Exported.Count - 1] = Detailed[8], 'CSV сохраняет итог на руках');
        finally
          Exported.Free;
        end;
      finally
        Detailed.Free;
      end;
    finally
      Lines.Free;
    end;

    Lines := Reports.PeriodTotals(Day + 3, Day + 3, True);
    try
      Check(Lines[3] = 'Итого выдано книг;0', 'период без выдач');
      Check(Lines[Lines.Count - 1] = 'Итого на руках книг;3', 'остаток доступен в периоде без выдач');
    finally
      Lines.Free;
    end;
  finally
    Reports.Free;
    DB.Free;
  end;
end;

begin
  SetMultiByteConversionCodePage(CP_UTF8);
  try
    TestStatistics;
    TestDistinctBooks;
    TestReaderHistory;
    TestPeriodTotals;
    WriteLn('OK: ', Checks, ' checks');
  except
    on E: Exception do
    begin
      WriteLn('FAIL: ', E.Message);
      Halt(1);
    end;
  end;
end.
