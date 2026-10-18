program ReportTotalsTests;

{$mode objfpc}{$H+}

uses Interfaces, Forms, Classes, SysUtils, Controls, FileUtil,
  uReportTotals, uReportFooter, uMainForm, uDatabase, uEntities, uTypes,
  uGridSorting, uReports;

var Checks: Integer;

procedure Check(Value: Boolean; const Msg: string);
begin
  Inc(Checks);
  if not Value then raise Exception.Create(Msg);
end;

procedure TestValues;
var Lines, Exported, Wrapped: TStringList; Totals: TReportTotals;
  Summary: TLoanStatisticsSummary; Service: TReportService;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('№ п/п;Книга;Выдач;Книг;Читателей;Дней просрочки;Год;ISBN;Инв.№;Телефон;Дата');
    Lines.Add('1;"Книга; ""Свет""";2;3;2;4;2025;123;456;789;01.01.2026');
    Lines.Add('2;Другая;10;5;2;6;2026;999;888;777;02.01.2026');
    Totals := CalculateReportTotals(Lines);
    Check(Totals.HasTotals, 'числовые показатели найдены');
    Check(Totals.Cells[2] = '12', 'сумма выдач');
    Check(Totals.Cells[3] = '8', 'сумма книг');
    Check(Totals.Cells[4] = '4', 'сумма читателей по строкам');
    Check(Totals.Cells[5] = '10', 'сумма дней просрочки');
    Check((Totals.Cells[0] = '') and (Totals.Cells[6] = '') and
      (Totals.Cells[7] = '') and (Totals.Cells[8] = '') and (Totals.Cells[9] = '') and
      (Totals.Cells[10] = ''), 'номера, годы, идентификаторы, телефоны и даты не суммируются');
    Exported := ReportWithTotals(Lines);
    try
      Check(Exported.Count = 4, 'CSV содержит одну строку сумм');
      Check(Pos('Сумма по строкам', Exported[3]) > 0, 'CSV обозначает смысл сумм');
      Check(Exported[0] = Lines[0], 'заголовок CSV сохранён');
      Check(Exported[1] = Lines[1], 'кавычки и разделители строки сохранены');
      Check(Lines.Count = 3, 'исходный отчёт не изменён');
      Summary := Default(TLoanStatisticsSummary);
      Summary.Readers := 1;
      Summary.Loans := 12;
      Service := TReportService.Create(nil);
      try
        Wrapped := Service.LoansStatisticsExport(Exported, Date, Date, False, Summary);
        try
          Check(Wrapped.IndexOf('Уникальных читателей;1') >= 0, 'общий уникальный итог не подменён суммой');
          Check(Wrapped[Wrapped.Count - 1] = Exported[Exported.Count - 1], 'статистика CSV сохраняет строку сумм');
        finally Wrapped.Free; end;
      finally Service.Free; end;
    finally Exported.Free; end;
    Lines.Clear;
    Lines.Add('№ п/п;Книга;Выдач;Читателей');
    Totals := CalculateReportTotals(Lines);
    Check(Totals.HasTotals and (Totals.Cells[2] = '0') and (Totals.Cells[3] = '0'),
      'пустая таблица с показателями имеет нулевые суммы');
    Lines.Add('1;Книга;9007199254740992;');
    Lines.Add('2;Другая;1;3');
    Totals := CalculateReportTotals(Lines);
    Check(Totals.Cells[2] = '9007199254740993', 'Int64 суммируется без округления Double');
    Check(Totals.Cells[3] = '3', 'пустые значения пропускаются');
    Lines[1] := '1;Книга;9223372036854775807;2';
    Totals := CalculateReportTotals(Lines);
    Check(Totals.Cells[2] = 'Переполнение', 'переполнение не выдаётся за правильную сумму');
    Lines[1] := '1;Книга;ошибка;2';
    Totals := CalculateReportTotals(Lines);
    Check(Totals.Cells[2] = 'Ошибка данных', 'некорректное число не скрывается');
    Lines[1] := '1;Книга;-9223372036854775808;2';
    Lines[2] := '2;Другая;-1;2';
    Check(CalculateReportTotals(Lines).Cells[2] = 'Переполнение', 'переполнение отрицательных значений');
    Lines.Clear;
    Lines.Add('№ п/п;Книга;Год;ISBN;Свободные номера');
    Lines.Add('1;Книга;2026;123;1-500');
    Check(not CalculateReportTotals(Lines).HasTotals, 'отчёты без суммируемых показателей не получают подвал');
    Exported := ReportWithTotals(Lines);
    try Check(Exported.Text = Lines.Text, 'CSV без показателей остаётся прежним');
    finally Exported.Free; end;
    Check(not CalculateReportTotals(nil).HasTotals, 'не сформированный отчёт не имеет сумм');
    Exported := ReportWithTotals(nil);
    try Check(Exported.Count = 0, 'пустой экспорт безопасен');
    finally Exported.Free; end;
    Lines.Clear;
    Check(not CalculateReportTotals(Lines).HasTotals, 'очищенные условия удаляют суммы');
    Lines.Add('№ п/п;Книга;Дней');
    Lines.Add('1;А;-2');
    Lines.Add('2;Б;5');
    Check(CalculateReportTotals(Lines).Cells[2] = '3', 'целые значения со знаком');
  finally Lines.Free; end;
end;

procedure TestReport(const Root: string);
var DB: TLibraryDB; F: TMainForm; Footer: TReportFooter; B: TBook; C: TCopy; Reader: TReader;
  L: TLoan; I, Rows, FooterTop: Integer; Err: string;
  CloseAction: TCloseAction; Before, After: TRect;
begin
  DB := TLibraryDB.Create(Root);
  F := nil;
  try
    Check(DB.Open(Err), 'искусственная база создана: ' + Err);
    Check(DB.Login(DEFAULT_ADMIN_LOGIN, DEFAULT_ADMIN_PASSWORD, Err), 'вход в искусственную базу');
    DB.Settings.AutoBackupEnabled := False;
    Reader := TReader.Create;
    Reader.ID := 1;
    Reader.FullName := 'Тестовый читатель';
    DB.Readers.Add(Reader);
    for I := 1 to 2 do
    begin
      B := TBook.Create;
      B.ID := I;
      B.Title := 'Книга ' + IntToStr(I);
      DB.Books.Add(B);
      C := TCopy.Create;
      C.ID := I;
      C.BookID := B.ID;
      DB.Copies.Add(C);
      L := TLoan.Create;
      L.ID := I;
      L.CopyID := C.ID;
      L.ReaderID := 1;
      L.IssuedAt := Now;
      DB.Loans.Add(L);
    end;
    F := TMainForm.Create(nil);
    F.DB := DB;
    F.FormShow(nil);
    Footer := nil;
    for I := 0 to F.ComponentCount - 1 do
      if F.Components[I] is TReportFooter then Footer := TReportFooter(F.Components[I]);
    Check(Footer <> nil, 'закреплённый подвал создан');
    Check(not Footer.Visible, 'каталог без суммируемых показателей не имеет подвала');
    F.cbReport.ItemIndex := 9;
    F.ReportParametersChange(nil);
    F.btnReportShowClick(nil);
    Check(Footer.Visible, 'подвал показан в статистике');
    Check(not F.Visible, 'проверка без показа окна');
    Rows := F.gridReport.RowCount;
    Check(Rows = 3, 'суммы не добавляют строку данных');
    GridSorting(F.gridReport).ClickColumn(2);
    Check(F.gridReport.RowCount = Rows, 'сортировка не перемещает подвал в данные');
    Check(F.gridReport.Cells[1, 1] = '1', 'нумерация данных не включает подвал');
    Before := Footer.ColumnBounds(5); // Выдач: после номера, книги, автора, категории.
    F.gridReport.MoveField(5, 2);
    After := Footer.ColumnBounds(5);
    Check(After.Left < Before.Left, 'подвал следует перестановке суммируемого поля');
    Check(After.Left = F.gridReport.CellRect(F.gridReport.PhysicalColumn(5), 0).Left,
      'выравнивание использует физическое положение логической колонки');
    F.gridReport.SetFieldVisible(5, False);
    After := Footer.ColumnBounds(5);
    Check(After.Right = After.Left, 'скрытое поле не рисует сумму');
    F.gridReport.SetFieldVisible(5, True);
    Check(Footer.ColumnBounds(5).Right > Footer.ColumnBounds(5).Left, 'возвращённая колонка возвращает сумму');
    F.gridReport.ColWidths[5] := 175;
    After := Footer.ColumnBounds(5);
    Check(After.Right - After.Left >= 174, 'изменение ширины учтено подвалом');
    FooterTop := Footer.Top;
    F.gridReport.LeftCol := 2;
    After := Footer.ColumnBounds(5);
    Check(After.Left = F.gridReport.CellRect(F.gridReport.PhysicalColumn(5), 0).Left,
      'горизонтальная прокрутка сохраняет привязку');
    Check(Footer.Top = FooterTop, 'подвал закреплён отдельно от прокручиваемых данных');
    F.cbReportStatsView.ItemIndex := 1;
    F.ReportParametersChange(nil);
    Check(not Footer.Visible, 'изменение условий очищает суммы');
    F.btnReportShowClick(nil);
    Check(Footer.Visible, 'подвал восстановлен для представления категорий');
    F.cbReport.ItemIndex := 5;
    F.ReportParametersChange(nil);
    F.btnReportShowClick(nil);
    Check(Footer.Visible, 'подвал показан в отчёте просроченных выдач');
    F.cbReport.ItemIndex := 0;
    F.ReportParametersChange(nil);
    F.btnReportShowClick(nil);
    Check(not Footer.Visible, 'смена на обычный каталог убирает подвал');
  finally
    if F <> nil then
    begin
      CloseAction := caNone;
      F.FormClose(nil, CloseAction);
      F.OnClose := nil;
      F.Free;
    end;
    DB.Free;
  end;
end;

var Root: string; Failed: Boolean;
begin
  Application.Initialize;
  RequireDerivedFormResource := True;
  Root := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'LibraryReportTotalsTests-' + IntToStr(GetTickCount64) + PathDelim;
  ForceDirectories(Root);
  try
    try
      TestValues;
      TestReport(Root);
      WriteLn('OK: ', Checks, ' checks');
    except
      on E: Exception do
      begin
        WriteLn('FAIL after ', Checks, ' checks: ', E.ClassName, ': ', E.Message);
        DumpExceptionBackTrace(Output);
        Failed := True;
      end;
    end;
  finally
    if Pos(IncludeTrailingPathDelimiter(GetTempDir(False)) + 'LibraryReportTotalsTests-',
      ExpandFileName(Root)) = 1 then DeleteDirectory(Root, False);
  end;
  if Failed then Halt(1);
end.
