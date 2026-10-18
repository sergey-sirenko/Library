program LoanStatisticsTests;

{$mode objfpc}{$H+}

uses Classes, SysUtils, DateUtils, uDatabase, uEntities, uTypes, uReports;

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
var DB: TLibraryDB; Reports: TReportService; Lines: TStringList;
  Summary: TLoanStatisticsSummary; Day: TDateTime;
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
    Lines := Reports.LoansStatistics(Day, Day, False, Summary);
    try Check((Lines.Count = 3) and (Summary.Books = 2), 'одинаковые названия не объединяют разные ID книг');
    finally Lines.Free; end;
    Lines := Reports.LoansStatistics(Day, Day, True, Summary);
    try
      Check(Lines.Count = 3, 'одноимённые категории с разными ID разделены');
      Check(Summary.Readers = 1, 'общий итог читателей не равен сумме по категориям');
    finally Lines.Free; end;
  finally Reports.Free; DB.Free; end;
end;

begin
  SetMultiByteConversionCodePage(CP_UTF8);
  try
    TestStatistics;
    TestDistinctBooks;
    WriteLn('OK: ', Checks, ' checks');
  except
    on E: Exception do
    begin
      WriteLn('FAIL: ', E.Message);
      Halt(1);
    end;
  end;
end.
