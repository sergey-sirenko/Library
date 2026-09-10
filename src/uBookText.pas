unit uBookText;

{$mode objfpc}{$H+}

interface

uses SysUtils;

function PlainBookText(const S: string): string;
function HTMLText(const S: string): string;
function DecodeEntities(const S: string): string;
function MatchHTML(const Pattern, S: string; AGroup: Integer = 1): string;
function CheckedYear(const S: string; out AWarning: string): Integer;
function TextWarning(const S: string): string;
function EncodingWarning(const S: string): string;
procedure AddBookWarning(var S: string; const Value: string);

implementation

uses RegExpr, htmldefs, DateUtils;

procedure AddBookWarning(var S: string; const Value: string);
begin
  if (Value = '') or (Pos(Value, S) > 0) then Exit;
  if S <> '' then S := S + LineEnding;
  S := S + Value;
end;

function MatchHTML(const Pattern, S: string; AGroup: Integer): string;
var R: TRegExpr;
begin
  Result := '';
  R := TRegExpr.Create;
  try
    R.Expression := '(?is)' + Pattern;
    if R.Exec(S) then Result := R.Match[AGroup];
  finally
    R.Free;
  end;
end;

function DecodeEntities(const S: string): string;
var I, J, Code: Integer; Name: string; C: WideChar;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if S[I] = '&' then
    begin
      J := I + 1;
      while (J <= Length(S)) and (J - I <= 12) and (S[J] <> ';') do Inc(J);
      if (J <= Length(S)) and (S[J] = ';') then
      begin
        Name := Copy(S, I + 1, J - I - 1);
        if (Length(Name) > 1) and (Name[1] = '#') then
        begin
          if (Length(Name) > 2) and (Name[2] in ['x', 'X']) then
            Code := StrToIntDef('$' + Copy(Name, 3, MaxInt), -1)
          else Code := StrToIntDef(Copy(Name, 2, MaxInt), -1);
          if (Code > $FFFF) and (Code <= $10FFFF) then
          begin
            Dec(Code, $10000);
            Result := Result + UTF8Encode(UnicodeString(WideChar($D800 + Code div 1024)) +
              WideChar($DC00 + Code mod 1024));
            I := J + 1;
            Continue;
          end;
          if (Code < 0) or (Code > $FFFF) or ((Code >= $D800) and (Code <= $DFFF)) then
            Name := '';
        end;
        if (Name <> '') and ResolveHTMLEntityReference(UTF8Decode(Name), C) then
        begin
          Result := Result + UTF8Encode(UnicodeString(C));
          I := J + 1;
          Continue;
        end;
      end;
    end;
    Result := Result + S[I];
    Inc(I);
  end;
end;

function PlainBookText(const S: string): string;
var U: UnicodeString; C: WideChar; Space: Boolean;
begin
  U := UTF8Decode(S);
  Result := '';
  Space := False;
  for C in U do
    if (Ord(C) <= 32) or (Ord(C) = 160) or (Ord(C) = $202F) then
      Space := Result <> ''
    else
    begin
      if Space then Result := Result + ' ';
      Result := Result + UTF8Encode(UnicodeString(C));
      Space := False;
    end;
end;

function HTMLText(const S: string): string;
var R: TRegExpr;
begin
  R := TRegExpr.Create;
  try
    R.Expression := '(?is)<(script|style)\b[^>]*>.*?</\1\s*>';
    Result := R.Replace(S, ' ', False);
    R.Expression := '(?is)<[^>]*>';
    Result := R.Replace(Result, ' ', False);
  finally
    R.Free;
  end;
  Result := PlainBookText(DecodeEntities(Result));
end;

function CheckedYear(const S: string; out AWarning: string): Integer;
var R: TRegExpr; Count, V: Integer;
begin
  Result := 0;
  AWarning := '';
  if Trim(S) = '' then Exit;
  if Copy(Trim(S), 1, 1) = '-' then
  begin
    AWarning := 'Год издания не заполнен: отрицательное значение.';
    Exit;
  end;
  R := TRegExpr.Create;
  try
    R.Expression := '[0-9]+';
    Count := 0;
    if R.Exec(S) then repeat
      if Length(R.Match[0]) >= 4 then
      begin
        Inc(Count);
        V := StrToIntDef(R.Match[0], 0);
        if (Length(R.Match[0]) <> 4) or (V = 0) then V := 0;
        Result := V;
      end;
    until not R.ExecNext;
    if (Count <> 1) or (Result = 0) or (Pos('?', S) > 0) then
    begin
      Result := 0;
      AWarning := 'Год издания не заполнен: значение отсутствует, неоднозначно или некорректно.';
    end
    else if Result > YearOf(Date) then
      AWarning := 'Год издания находится в будущем: проверьте запись.';
  finally
    R.Free;
  end;
end;

function EncodingWarning(const S: string): string;
var U: UnicodeString; C: WideChar;
begin
  Result := '';
  U := UTF8Decode(S);
  if UTF8Encode(U) <> S then
    AddBookWarning(Result, 'Текст содержит некорректную последовательность UTF-8.');
  for C in U do
    if (Ord(C) = $FFFD) or ((Ord(C) < 32) and not (Ord(C) in [9, 10, 13])) then
      AddBookWarning(Result, 'В тексте обнаружены повреждённые или управляющие символы.');
end;

function TextWarning(const S: string): string;
var U: UnicodeString; C: WideChar; Latin, Cyrillic, AnyLatin: Boolean;
begin
  Result := EncodingWarning(S);
  Latin := False;
  Cyrillic := False;
  AnyLatin := False;
  U := UTF8Decode(S) + ' ';
  for C in U do
  begin
    if ((C >= 'A') and (C <= 'Z')) or ((C >= 'a') and (C <= 'z')) then
    begin
      Latin := True;
      AnyLatin := True;
    end
    else if (Ord(C) >= $0400) and (Ord(C) <= $052F) then Cyrillic := True
    else
    begin
      if Latin and Cyrillic then
        AddBookWarning(Result, 'Внутри слова смешаны кириллица и латиница: проверьте написание.');
      Latin := False;
      Cyrillic := False;
    end;
  end;
  if AnyLatin then
    AddBookWarning(Result, 'Есть латинские фрагменты: возможен иностранный текст или транслитерация; проверьте вручную.');
end;

end.
