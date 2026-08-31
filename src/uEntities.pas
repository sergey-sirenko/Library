unit uEntities;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, uTypes;

type
  TEntity = class
  public
    ID: TId;
    CreatedAt: TDateTime;
    ModifiedAt: TDateTime;
    Deleted: Boolean;
    DeletedAt: TDateTime;
    DeletedBy: TId;
  end;

  TBook = class(TEntity)
  public
    Title: string;
    Authors: string;
    Year: Integer;
    Publisher: string;
    ISBN: string;
    CategoryID: TId;
    Description: string;
    CoverFile: string;
  end;

  TCopy = class(TEntity)
  public
    BookID: TId;
    InventoryNo: string;
    ReceivedAt: TDateTime;
    Condition: string;
    LocationID: TId;
    Note: string;
    Status: TCopyStatus;
  end;

  TReader = class(TEntity)
  public
    FullName: string;
    BirthDate: TDateTime;
    Phone: string;
    Address: string;
    Contacts: string;
    RegisteredAt: TDateTime;
    Note: string;
    Status: TReaderStatus;
    BlockReason: string;
  end;

  TLoan = class(TEntity)
  public
    CopyID: TId;
    ReaderID: TId;
    IssuedAt: TDateTime;
    DueAt: TDateTime;
    ReturnedAt: TDateTime;
    RenewCount: Integer;
    IssuedBy: TId;
    ReturnedBy: TId;
    State: TLoanState;
    Note: string;
  end;

  TCategory = class(TEntity)
  public
    Name: string;
    Code: string;
    Description: string;
  end;

  TLocation = class(TEntity)
  public
    Name: string;
    Description: string;
  end;

  TUser = class(TEntity)
  public
    Login: string;
    DisplayName: string;
    Role: TUserRole;
    Salt: string;
    PasswordHash: string;
    Active: Boolean;
    LastLoginAt: TDateTime;
  end;

  TSettings = class
  public
    LibraryName: string;
    LoanDays: Integer;
    MaxBooksPerReader: Integer;
    MaxRenewals: Integer;
    AutoBackupEnabled: Boolean;
    LastBackupAt: TDateTime;
    UIFontSize: Integer;
    InventoryStartNo: Int64;
    OpenRouterModel: string;
    OpenRouterApiKey: string;
    GoogleBooksApiKey: string;
    OpenRouterFavoriteModels: TStringList;
    constructor Create;
    destructor Destroy; override;
  end;

  TRecognizedBook = class
  public
    SourceFile: string;
    Title: string;
    InventoryNo: string;
    Authors: string;
    Year: string;
    Publisher: string;
    ISBN: string;
    Description: string;
    CategoryName: string;
  end;

  TRecognitionStats = record
    Models: string;
    PromptTokens: Int64;
    CompletionTokens: Int64;
    TotalTokens: Int64;
    RecognitionCost: Double;
    HasCost: Boolean;
  end;

  TActionLogItem = class
  public
    When: TDateTime;
    UserID: TId;
    UserName: string;
    Action: TActionType;
    ObjectKind: TObjectKind;
    ObjectID: TId;
    Description: string;
    DetailsBefore: string;
    DetailsAfter: string;
  end;

  TEntityList = class(TObjectList)
  public
    function FindByID(AID: TId): TEntity;
  end;

procedure ClearRecognitionStats(out AStats: TRecognitionStats);
procedure MergeRecognitionStats(var ATarget: TRecognitionStats;
  const ASource: TRecognitionStats);

implementation

procedure ClearRecognitionStats(out AStats: TRecognitionStats);
begin
  AStats.Models := '';
  AStats.PromptTokens := 0;
  AStats.CompletionTokens := 0;
  AStats.TotalTokens := 0;
  AStats.RecognitionCost := 0;
  AStats.HasCost := False;
end;

procedure AddRecognitionModel(var AModels: string; const AModel: string);
var
  Models: TStringList;
  I: Integer;
  CleanModel: string;
begin
  CleanModel := Trim(AModel);
  if CleanModel = '' then
    Exit;
  Models := TStringList.Create;
  try
    Models.StrictDelimiter := True;
    Models.Delimiter := ';';
    Models.DelimitedText := StringReplace(AModels, '; ', ';', [rfReplaceAll]);
    for I := 0 to Models.Count - 1 do
      if SameText(Trim(Models[I]), CleanModel) then
        Exit;
    if AModels = '' then
      AModels := CleanModel
    else
      AModels := AModels + '; ' + CleanModel;
  finally
    Models.Free;
  end;
end;

procedure MergeRecognitionStats(var ATarget: TRecognitionStats;
  const ASource: TRecognitionStats);
var
  Models: TStringList;
  I: Integer;
begin
  Models := TStringList.Create;
  try
    Models.StrictDelimiter := True;
    Models.Delimiter := ';';
    Models.DelimitedText := StringReplace(ASource.Models, '; ', ';', [rfReplaceAll]);
    for I := 0 to Models.Count - 1 do
      AddRecognitionModel(ATarget.Models, Models[I]);
  finally
    Models.Free;
  end;
  Inc(ATarget.PromptTokens, ASource.PromptTokens);
  Inc(ATarget.CompletionTokens, ASource.CompletionTokens);
  Inc(ATarget.TotalTokens, ASource.TotalTokens);
  if ASource.HasCost then
  begin
    ATarget.RecognitionCost := ATarget.RecognitionCost + ASource.RecognitionCost;
    ATarget.HasCost := True;
  end;
end;

constructor TSettings.Create;
begin
  inherited Create;
  OpenRouterFavoriteModels := TStringList.Create;
end;

destructor TSettings.Destroy;
begin
  OpenRouterFavoriteModels.Free;
  inherited Destroy;
end;

function TEntityList.FindByID(AID: TId): TEntity;
var
  I: Integer;
  E: TEntity;
begin
  for I := 0 to Count - 1 do
  begin
    E := TEntity(Items[I]);
    if E.ID = AID then
    begin
      Result := E;
      Exit;
    end;
  end;
  Result := nil;
end;

end.
