program GridSortingTests;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, Classes, SysUtils, Grids, uGridSorting;

type
  TKeySource = class
    function Key(ACol, ARow: Integer): string;
  end;

var
  Checks: Integer;

function TKeySource.Key(ACol, ARow: Integer): string;
begin
  if ARow = 1 then Result := '0.1002' else Result := '0.1001';
end;

procedure Check(Value: Boolean; const MessageText: string);
begin
  Inc(Checks);
  if not Value then raise Exception.Create(MessageText);
end;

procedure TestValues;
begin
  Check(CompareGridValues('Азбука', 'азБУКА', gskText) = 0, 'Регистр кириллицы');
  Check(CompareGridValues('Библиотека', 'Язык', gskText) < 0, 'Порядок кириллицы');
  Check(CompareGridValues('2', '10', gskNumber) < 0, 'Числа');
  Check(CompareGridValues('0,25', '0.3', gskNumber) < 0, 'Дробные числа');
  Check(CompareGridValues('01.02.2025', '31.01.2026', gskDate) < 0, 'Даты');
  Check(CompareGridValues('10.09.2026 09:05:00', '10.09.2026 10:00:00', gskDate) < 0,
    'Время');
  Check(CompareGridValues('', '0', gskNumber) < 0, 'Пустое число');
  Check(CompareGridValues(' ', '', gskText) = 0, 'Пустые строки');
  Check(CompareGridValues('001', '01', gskText) < 0, 'Текстовый идентификатор');
  Check(CompareGridValues('10', '2', gskText) < 0, 'Текст не превращается в число');
  Check(CompareGridValues('2', 'ошибка', gskNumber) < 0, 'Некорректное число');
  Check(CompareGridValues('01.01.2026', 'не дата', gskDate) < 0, 'Некорректная дата');
  Check(GridSortKind('ISBN') = gskText, 'Тип ISBN');
  Check(GridSortKind('Телефон') = gskText, 'Тип телефона');
  Check(GridSortKind('Инв. №') = gskText, 'Тип инвентарного номера');
  Check(GridSortKind('Дата регистрации') = gskDate, 'Тип даты отчёта');
  Check(GridSortKind('Дней просрочки') = gskNumber, 'Тип числа отчёта');
end;

procedure TestRows;
var
  G: TStringGrid;
  S: TGridSorting;
  A, B, C: TObject;
begin
  G := TStringGrid.Create(nil);
  A := TObject.Create;
  B := TObject.Create;
  C := TObject.Create;
  try
    G.FixedCols := 0;
    G.ColCount := 4;
    G.RowCount := 4;
    G.FixedRows := 1;
    G.Cells[1, 0] := 'Название';
    G.Cells[2, 0] := 'Год';
    G.Cells[3, 0] := 'ISBN';
    G.Cells[1, 1] := 'Язык';
    G.Cells[1, 2] := 'Азбука';
    G.Cells[1, 3] := 'азбука';
    G.Cells[2, 1] := '10';
    G.Cells[2, 2] := '2';
    G.Cells[2, 3] := '2';
    G.Objects[0, 1] := A;
    G.Objects[0, 2] := B;
    G.Objects[0, 3] := C;
    G.Objects[3, 2] := B;
    G.RowHeights[2] := 63;
    G.Row := 2;
    S := TGridSorting.CreateFor(G, 1, nil);
    S.Apply;
    Check(S.Column = 1, 'Начальная колонка');
    Check(not S.Descending, 'Начальное направление');
    Check(G.Cells[1, 0] = 'Название ▲', 'Стрелка возрастания');
    Check(G.Objects[0, 1] = B, 'Привязка записи');
    Check(G.Objects[3, 1] = B, 'Объекты во всех ячейках');
    Check(G.RowHeights[1] = 63, 'Высота следует за строкой');
    Check(G.Objects[0, G.Row] = B, 'Выделение следует за записью');
    Check(G.Objects[0, 2] = C, 'Стабильность одинакового текста');
    S.ClickColumn(0);
    Check(S.Column = 1, 'Служебная колонка не сортируется');
    S.ClickColumn(1);
    Check(S.Descending, 'Повторный клик');
    Check(G.Cells[1, 0] = 'Название ▼', 'Стрелка убывания');
    Check(G.Objects[0, 1] = A, 'Убывание');
    Check((G.Objects[0, 2] = B) and (G.Objects[0, 3] = C), 'Стабильность убывания');
    S.ClickColumn(2);
    Check(not S.Descending, 'Новая колонка — возрастание');
    Check(G.Objects[0, 1] = B, 'Числовая сортировка строк');
    Check(G.Cells[1, 0] = 'Название', 'Удаление прежней стрелки');
    S.ClickColumn(2);
    G.RowCount := 3;
    G.Cells[2, 1] := '2';
    G.Cells[2, 2] := '10';
    S.Apply;
    Check(S.Descending and (G.Cells[2, 1] = '10'), 'Обновление сохраняет сортировку');
    G.Cells[1, 0] := 'ФИО';
    G.Cells[2, 0] := 'Телефон';
    S.Apply;
    Check((S.Column = 1) and not S.Descending, 'Новая схема отчёта сбрасывает порядок');
    G.RowCount := 1;
    S.Apply;
    G.RowCount := 2;
    G.Rows[1].Clear;
    S.Apply;
    Check(G.Cells[1, 1] = '', 'Пустая таблица');
  finally
    G.Free;
    A.Free;
    B.Free;
    C.Free;
  end;
end;

procedure TestEditableRows;
var
  G: TStringGrid;
  A, B: TStringList;
  Items: TList;
  S: TGridSorting;
begin
  G := TStringGrid.Create(nil);
  Items := TList.Create;
  A := TStringList.Create;
  B := TStringList.Create;
  try
    Items.Add(A);
    Items.Add(B);
    G.FixedCols := 0;
    G.ColCount := 3;
    G.RowCount := 3;
    G.FixedRows := 1;
    while G.Columns.Count < 3 do G.Columns.Add;
    G.Cells[0, 0] := 'Выбрать';
    G.Cells[1, 0] := 'Наименование';
    G.Cells[2, 0] := 'Инв. номер';
    G.Columns[0].ButtonStyle := cbsCheckboxColumn;
    G.Cells[0, 1] := '1';
    G.Cells[0, 2] := '0';
    G.Cells[1, 1] := 'Язык';
    G.Cells[1, 2] := 'Азбука';
    G.Cells[2, 1] := '001';
    G.Cells[2, 2] := '002';
    G.Objects[0, 1] := A;
    G.Objects[0, 2] := B;
    S := TGridSorting.CreateFor(G, 0, nil);
    S.Apply;
    Check(G.Columns[1].Title.Caption = 'Наименование ▲', 'Заголовки с Columns');
    Check(G.Cells[0, 2] = '1', 'Отметка следует за книгой');
    Check(G.Cells[2, 2] = '001', 'Инвентарный номер следует за книгой');
    G.Cells[1, 1] := 'Новая азбука';
    TStringList(G.Objects[0, 1]).Text := G.Cells[1, 1];
    Check(Trim(B.Text) = 'Новая азбука', 'Правка относится к правильной записи');
    Items.Remove(G.Objects[0, 2]);
    G.DeleteRow(2);
    Check((Items.Count = 1) and (TObject(Items[0]) = B), 'Удалена нужная запись');
    Check(G.Objects[0, 1] = B, 'Оставшаяся запись привязана');
    S.Apply;
    Check(G.Cells[1, 1] = 'Новая азбука', 'Правка сохранена после сортировки');
  finally
    G.Free;
    Items.Free;
    A.Free;
    B.Free;
  end;
end;

procedure TestDefaultsAndPrices;
const
  HEADERS: array[0..11] of string = (
    'Название;Автор;Год', 'Инв. №;Статус;Место', 'ФИО;Телефон;Регистрация',
    'Инв. №;Книга;Читатель;Выдана;Срок', 'Инв. №;Книга;Читатель;Срок;Дней',
    'Наименование;Шифр;Описание', 'Наименование;Описание',
    'Логин;Имя;Роль', 'Дата;Пользователь;Действие',
    'Инв.№;Книга;Дата поступления', '★;Модель;Вход $ / 1M;Выход $ / 1M',
    'Выбрать;Наименование;Инв. номер;Год');
  DEFAULT_COLS: array[0..11] of Integer = (0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 1);
var
  I, C: Integer;
  G: TStringGrid;
  Parts: TStringList;
  S: TGridSorting;
  Source: TKeySource;
begin
  Parts := TStringList.Create;
  try
    Parts.Delimiter := ';';
    Parts.StrictDelimiter := True;
    for I := 0 to High(HEADERS) do
    begin
      G := TStringGrid.Create(nil);
      try
        G.FixedCols := 0;
        Parts.DelimitedText := HEADERS[I];
        G.ColCount := Parts.Count;
        G.RowCount := 2;
        G.FixedRows := 1;
        for C := 0 to Parts.Count - 1 do G.Cells[C, 0] := Parts[C];
        S := TGridSorting.CreateFor(G, 0, nil);
        S.Apply;
        Check(S.Column = DEFAULT_COLS[I], 'Начальная сортировка таблицы ' + IntToStr(I));
      finally
        G.Free;
      end;
    end;
  finally
    Parts.Free;
  end;
  G := TStringGrid.Create(nil);
  Source := TKeySource.Create;
  try
    G.FixedCols := 0;
    G.ColCount := 2;
    G.RowCount := 3;
    G.FixedRows := 1;
    G.Cells[0, 0] := 'Модель';
    G.Cells[1, 0] := 'Вход $ / 1M';
    G.Cells[0, 1] := 'A';
    G.Cells[0, 2] := 'B';
    G.Cells[1, 1] := '$0.100';
    G.Cells[1, 2] := '$0.100';
    S := TGridSorting.CreateFor(G, 0, nil);
    S.Apply;
    S.OnKey := @Source.Key;
    S.ClickColumn(1);
    Check(G.Cells[0, 1] = 'B', 'Цены сравниваются до округления');
    G.RowCount := 1;
    S.Apply;
    G.RowCount := 3;
    G.Cells[0, 1] := 'A';
    G.Cells[0, 2] := 'B';
    S.Apply;
    Check((S.Column = 1) and (G.Cells[0, 1] = 'B'), 'Восстановление после пустого фильтра');
  finally
    G.Free;
    Source.Free;
  end;
end;

begin
  Application.Initialize;
  try
    TestValues;
    TestRows;
    TestEditableRows;
    TestDefaultsAndPrices;
    WriteLn('OK: ', Checks, ' checks');
  except
    on E: Exception do
    begin
      WriteLn('FAIL: ', E.Message);
      Halt(1);
    end;
  end;
end.
