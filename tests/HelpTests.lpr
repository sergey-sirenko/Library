program HelpTests;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, Classes, SysUtils, LazUTF8, uHelpContent, uHelpView;

var
  Checks: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  Inc(Checks);
  if not ACondition then raise Exception.Create(AMessage);
end;

function HasTopic(const AHits: THelpSearchHits; const AID: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(AHits) do
    if HelpTopic(AHits[I].TopicIndex).ID = AID then Exit(True);
end;

procedure CheckContent;
const
  Reports: array[0..9] of string = ('report-catalog', 'report-copies',
    'report-available', 'report-free-numbers', 'report-on-hands', 'report-overdue',
    'report-history', 'report-readers', 'report-journal', 'report-statistics');
  Sections: array[0..12] of string = ('start', 'books', 'copies', 'search', 'ai',
    'readers', 'loans', 'overdue', 'directories', 'reports', 'tables', 'service',
    'quick-help');
var
  IDs, Links: TStringList;
  T: THelpTopic;
  I, J, P: Integer;
  Hits: THelpSearchHits;
  Raised: Boolean;
begin
  IDs := TStringList.Create;
  Links := TStringList.Create;
  try
    IDs.CaseSensitive := True;
    Links.Delimiter := '|';
    Links.StrictDelimiter := True;
    for I := 0 to HelpTopicCount - 1 do
    begin
      T := HelpTopic(I);
      Check((T.ID <> '') and (IDs.IndexOf(T.ID) < 0), 'Повтор ID: ' + T.ID);
      IDs.Add(T.ID);
      Check((Trim(T.Title) <> '') and (UTF8Length(T.Body) > 120),
        'Пустой раздел: ' + T.ID);
      Check(FindHelpTopic(T.ID) = I, 'Нарушен поиск ID: ' + T.ID);
      if T.ParentID <> '' then
      begin
        P := FindHelpTopic(T.ParentID);
        Check((P >= 0) and (P < I), 'Нет родителя перед подразделом: ' + T.ID);
      end;
      Links.DelimitedText := T.Links;
      for J := 0 to Links.Count - 1 do
        Check((FindHelpTopic(Links[J]) >= 0) and (Links[J] <> T.ID),
          'Неверная ссылка: ' + T.ID + ' -> ' + Links[J]);
      Hits := SearchHelp(UTF8UpperCase(T.Title));
      Check(HasTopic(Hits, T.ID), 'Название не находится: ' + T.ID);
    end;
    for I := Low(Reports) to High(Reports) do
    begin
      P := FindHelpTopic(Reports[I]);
      Check(P >= 0, 'Нет отчёта ' + Reports[I]);
      Check(HelpTopic(P).ParentID = 'reports', 'Отчёт вне раздела');
    end;
    for I := Low(Sections) to High(Sections) do
    begin
      P := FindHelpTopic(Sections[I]);
      Check(P >= 0, 'Нет раздела ' + Sections[I]);
      Check(HelpTopic(P).ParentID = '', 'Основной раздел вложен');
    end;
    Check(FindHelpTopic('missing-topic') = -1, 'Неизвестный ID');
    Raised := False;
    try
      HelpTopic(-1);
    except
      on E: ERangeError do Raised := True;
    end;
    Check(Raised, 'Защита отрицательного индекса');
    Raised := False;
    try
      HelpTopic(HelpTopicCount);
    except
      on E: ERangeError do Raised := True;
    end;
    Check(Raised, 'Защита верхней границы');
  finally
    Links.Free;
    IDs.Free;
  end;
end;

procedure CheckSearch;
var
  Hits, Other: THelpSearchHits;
  I: Integer;
begin
  Check(Length(SearchHelp('')) = 0, 'Пустой запрос');
  Check(Length(SearchHelp(' ' + #9 + #13#10)) = 0, 'Пробельный запрос');
  Check(Length(SearchHelp('несуществующееслово123')) = 0, 'Нет совпадений');
  Hits := SearchHelp('СТРАХОВОЧН');
  Check(HasTopic(Hits, 'glossary'), 'Поиск внутри текста, не только в названии');
  Check(HasTopic(Hits, 'backup-restore'), 'Русский регистр');
  Hits := SearchHelp('номер   уникаль');
  Other := SearchHelp('НОМЕР' + #9 + 'УНИКАЛЬ');
  Check(Length(Hits) > 0, 'Поиск нескольких частей слов');
  Check(Length(Hits) = Length(Other), 'Пробелы и табуляция');
  for I := 0 to High(Hits) do
  begin
    Check(Hits[I].TopicIndex = Other[I].TopicIndex, 'Стабильный порядок поиска');
    Check(Pos('номер', UTF8LowerCase(HelpTopic(Hits[I].TopicIndex).Title + ' ' +
      HelpTopic(Hits[I].TopicIndex).Body)) > 0, 'Первое слово');
    Check(Pos('уникаль', UTF8LowerCase(HelpTopic(Hits[I].TopicIndex).Title + ' ' +
      HelpTopic(Hits[I].TopicIndex).Body)) > 0, 'Второе слово');
    Check((UTF8Length(Hits[I].Snippet) > 0) and
      (UTF8Length(Hits[I].Snippet) <= 202), 'Длина фрагмента');
    Check(Pos(#10, Hits[I].Snippet) = 0, 'Фрагмент без переводов строк');
  end;
  Check(Length(SearchHelp('номер несуществующееслово123')) = 0,
    'Все слова обязательны');
  Check(HasTopic(SearchHelp('ВПЕРЁД'), 'start'), 'Буква Ё');
end;

procedure CheckNavigation;
var
  N: THelpNavigation;
  Start, Books, Readers, Loans: Integer;
begin
  Start := FindHelpTopic('start');
  Books := FindHelpTopic('books');
  Readers := FindHelpTopic('readers');
  Loans := FindHelpTopic('loans');
  N := THelpNavigation.Create;
  try
    Check(N.Current = Start, 'Начальный раздел');
    Check(not N.Back and not N.Forward, 'Границы начальной истории');
    Check(N.OpenTopic(Books) and N.OpenTopic(Readers), 'Переходы');
    Check(N.Back and (N.Current = Books), 'Назад');
    Check(N.Back and (N.Current = Start), 'Назад до начала');
    Check(not N.Back and (N.Current = Start), 'Нельзя выйти за начало');
    Check(N.Forward and (N.Current = Books), 'Вперёд');
    Check(N.OpenTopic(Books) and N.CanForward, 'Повтор не обрезает историю');
    Check(N.Forward and (N.Current = Readers), 'Сохранённый следующий раздел');
    Check(not N.Forward, 'Нельзя выйти за конец');
    Check(N.Back and N.OpenTopic(Loans), 'Новая ветвь истории');
    Check(not N.CanForward, 'Старая ветвь отброшена');
    Check(not N.OpenTopic(-1) and (N.Current = Loans), 'Неверный переход');
    Check(not N.OpenTopic(HelpTopicCount), 'Верхняя граница перехода');
    Check(N.Back and (N.Current = Books), 'После ветвления назад');
    Check(N.OpenTopic(Start) and N.Back and (N.Current = Books),
      'Начало работы — обычный переход в истории');
  finally
    N.Free;
  end;
end;

procedure CheckConstruction;
var
  Host: TForm;
  View: THelpView;
begin
  // Только создание/освобождение компонентов: без Show, ввода, кликов, БД и сети.
  Host := TForm.CreateNew(nil);
  try
    View := THelpView.Create(Host);
    Check(View.Parent = Host, 'Встраивание справки');
    Check(View.ControlCount > 0, 'Состав компонента создан');
    View.Free;
    View := THelpView.Create(Host);
    Check(View <> nil, 'Повторное создание после уничтожения');
  finally
    Host.Free;
  end;
end;

begin
  try
    Application.Initialize;
    CheckContent;
    CheckSearch;
    CheckNavigation;
    CheckConstruction;
    WriteLn('HelpTests: ', Checks, ' checks passed; topics: ', HelpTopicCount);
  except
    on E: Exception do
    begin
      WriteLn('FAIL: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
