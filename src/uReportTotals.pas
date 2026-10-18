unit uReportTotals;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils;

type
  TReportTotals = record
    HasTotals: Boolean;
    Cells: array of string;
  end;

function CalculateReportTotals(ALines: TStrings): TReportTotals;
function ReportWithTotals(ALines: TStrings): TStringList;

implementation

function Summable(const Caption: string): Boolean;
begin
  Result := (Caption = 'Выдач') or (Caption = 'Книг') or
    (Caption = 'Читателей') or (Caption = 'Дней просрочки') or
    (Caption = 'Дней');
end;

function CSVParts: TStringList;
begin
  Result := TStringList.Create;
  Result.StrictDelimiter := True;
  Result.Delimiter := ';';
  Result.QuoteChar := '"';
end;

function CalculateReportTotals(ALines: TStrings): TReportTotals;
var Headers, Parts: TStringList; C, R: Integer;
  Sum, Value: Int64; Bad, Overflow: Boolean;
begin
  Result.HasTotals := False;
  Result.Cells := nil;
  if (ALines = nil) or (ALines.Count = 0) then Exit;
  Headers := CSVParts;
  Parts := CSVParts;
  try
    Headers.DelimitedText := ALines[0];
    SetLength(Result.Cells, Headers.Count);
    for C := 0 to Headers.Count - 1 do
    begin
      if not Summable(Headers[C]) then Continue;
      Result.HasTotals := True;
      Sum := 0;
      Bad := False;
      Overflow := False;
      for R := 1 to ALines.Count - 1 do
      begin
        Parts.DelimitedText := ALines[R];
        if (C >= Parts.Count) or (Trim(Parts[C]) = '') then Continue;
        if not TryStrToInt64(Trim(Parts[C]), Value) then
        begin
          Bad := True;
          Break;
        end;
        if ((Value > 0) and (Sum > High(Int64) - Value)) or
          ((Value < 0) and (Sum < Low(Int64) - Value)) then
        begin
          Overflow := True;
          Break;
        end;
        Sum := Sum + Value;
      end;
      if Bad then Result.Cells[C] := 'Ошибка данных'
      else if Overflow then Result.Cells[C] := 'Переполнение'
      else Result.Cells[C] := IntToStr(Sum);
    end;
  finally
    Parts.Free;
    Headers.Free;
  end;
end;

function ReportWithTotals(ALines: TStrings): TStringList;
var Totals: TReportTotals; Parts: TStringList; C: Integer;
begin
  Result := TStringList.Create;
  try
    if ALines <> nil then Result.Assign(ALines);
    Totals := CalculateReportTotals(ALines);
    if not Totals.HasTotals then Exit;
    Parts := CSVParts;
    try
      for C := 0 to High(Totals.Cells) do Parts.Add(Totals.Cells[C]);
      // В отчётах первая колонка — номер строки, его сумма не вычисляется.
      if Parts.Count > 0 then Parts[0] := 'Сумма по строкам';
      Result.Add(Parts.DelimitedText);
    finally
      Parts.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

end.
