unit uHelpContent;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  THelpTopic = record
    ID, ParentID, Title, Body, Links: string;
  end;
  THelpSearchHit = record
    TopicIndex: Integer;
    Snippet: string;
  end;
  THelpSearchHits = array of THelpSearchHit;

  THelpNavigation = class
  private
    FEntries: array of Integer;
    FPosition: Integer;
    function GetCurrent: Integer;
  public
    constructor Create;
    function OpenTopic(AIndex: Integer): Boolean;
    function Back: Boolean;
    function Forward: Boolean;
    function CanBack: Boolean;
    function CanForward: Boolean;
    property Current: Integer read GetCurrent;
  end;

function HelpTopicCount: Integer;
function HelpTopic(AIndex: Integer): THelpTopic;
function FindHelpTopic(const AID: string): Integer;
function SearchHelp(const AQuery: string): THelpSearchHits;

implementation

uses
  LazUTF8, Math;

var
  Topics: array of THelpTopic;
  SearchIndex: array of string;

procedure AddTopic(const AID, AParentID, ATitle, ALinks: string;
  const AParagraphs: array of string);
var
  N, I: Integer;
begin
  N := Length(Topics);
  SetLength(Topics, N + 1);
  Topics[N].ID := AID;
  Topics[N].ParentID := AParentID;
  Topics[N].Title := ATitle;
  Topics[N].Links := ALinks;
  for I := 0 to High(AParagraphs) do
  begin
    if I > 0 then Topics[N].Body := Topics[N].Body + LineEnding + LineEnding;
    Topics[N].Body := Topics[N].Body + AParagraphs[I];
  end;
end;

procedure BuildTopics;
var
  I: Integer;
begin
  {$I help/library-help.inc}
  SetLength(SearchIndex, Length(Topics));
  for I := 0 to High(Topics) do
    SearchIndex[I] := UTF8LowerCase(Topics[I].Title + ' ' + Topics[I].Body);
end;

function HelpTopicCount: Integer;
begin
  Result := Length(Topics);
end;

function HelpTopic(AIndex: Integer): THelpTopic;
begin
  if (AIndex < 0) or (AIndex >= Length(Topics)) then
    raise ERangeError.Create('Раздел справки не найден.');
  Result := Topics[AIndex];
end;

function FindHelpTopic(const AID: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(Topics) do
    if Topics[I].ID = AID then Exit(I);
  Result := -1;
end;

function SearchHelp(const AQuery: string): THelpSearchHits;
var
  Words: TStringList;
  Query, Body: string;
  I, J, N, P, Start: Integer;
  Matches: Boolean;
begin
  Result := nil;
  Query := UTF8LowerCase(Trim(AQuery));
  Query := StringReplace(Query, #9, ' ', [rfReplaceAll]);
  Query := StringReplace(Query, #10, ' ', [rfReplaceAll]);
  Query := StringReplace(Query, #13, ' ', [rfReplaceAll]);
  if Trim(Query) = '' then Exit;
  Words := TStringList.Create;
  try
    Words.Delimiter := ' ';
    Words.StrictDelimiter := True;
    Words.QuoteChar := #0;
    Words.DelimitedText := Query;
    for I := 0 to High(Topics) do
    begin
      Matches := True;
      for J := 0 to Words.Count - 1 do
        if (Words[J] <> '') and (Pos(Words[J], SearchIndex[I]) = 0) then
        begin
          Matches := False;
          Break;
        end;
      if not Matches then Continue;
      N := Length(Result);
      SetLength(Result, N + 1);
      Result[N].TopicIndex := I;
      Body := StringReplace(Topics[I].Body, LineEnding, ' ', [rfReplaceAll]);
      P := 0;
      for J := 0 to Words.Count - 1 do
        if Words[J] <> '' then
        begin
          P := UTF8Pos(Words[J], UTF8LowerCase(Body));
          if P > 0 then Break;
        end;
      Start := Max(1, P - 45);
      Result[N].Snippet := UTF8Copy(Body, Start, 200);
      if Start > 1 then Result[N].Snippet := '…' + Result[N].Snippet;
      if Start + 200 <= UTF8Length(Body) then
        Result[N].Snippet := Result[N].Snippet + '…';
    end;
  finally
    Words.Free;
  end;
end;

constructor THelpNavigation.Create;
begin
  inherited Create;
  FPosition := -1;
  OpenTopic(FindHelpTopic('start'));
end;

function THelpNavigation.GetCurrent: Integer;
begin
  if FPosition < 0 then Exit(-1);
  Result := FEntries[FPosition];
end;

function THelpNavigation.OpenTopic(AIndex: Integer): Boolean;
begin
  Result := (AIndex >= 0) and (AIndex < HelpTopicCount);
  if not Result or (Current = AIndex) then Exit;
  Inc(FPosition);
  SetLength(FEntries, FPosition + 1);
  FEntries[FPosition] := AIndex;
end;

function THelpNavigation.CanBack: Boolean;
begin
  Result := FPosition > 0;
end;

function THelpNavigation.CanForward: Boolean;
begin
  Result := FPosition < High(FEntries);
end;

function THelpNavigation.Back: Boolean;
begin
  Result := CanBack;
  if Result then Dec(FPosition);
end;

function THelpNavigation.Forward: Boolean;
begin
  Result := CanForward;
  if Result then Inc(FPosition);
end;

initialization
  BuildTopics;

end.
