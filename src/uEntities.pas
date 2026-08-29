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
  end;

  TRecognizedBook = class
  public
    SourceFile: string;
    Title: string;
    InventoryNo: string;
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

implementation

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
