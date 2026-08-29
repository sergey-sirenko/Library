unit uAppPaths;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TAppPaths = class
  private
    FRoot: string;
  public
    constructor Create(const ARoot: string = '');
    procedure EnsureStructure;
    property Root: string read FRoot;
    function DataDir: string;
    function CoversDir: string;
    function BackupDir: string;
    function LogsDir: string;
    function DataFile(const AName: string): string;
    function IndexFile(const AName: string): string;
    function LockFile: string;
    function TxnFile: string;
    function ActionLogFile: string;
    function TechLogFile: string;
    function GridLayoutFile: string;
    function UserLayoutFile: string;
  end;

implementation

constructor TAppPaths.Create(const ARoot: string);
begin
  inherited Create;
  if ARoot <> '' then
    FRoot := IncludeTrailingPathDelimiter(ExpandFileName(ARoot))
  else
    FRoot := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
end;

procedure TAppPaths.EnsureStructure;
begin
  ForceDirectories(DataDir);
  ForceDirectories(CoversDir);
  ForceDirectories(BackupDir);
  ForceDirectories(LogsDir);
end;

function TAppPaths.DataDir: string;
begin
  Result := FRoot + 'Data' + PathDelim;
end;

function TAppPaths.CoversDir: string;
begin
  Result := FRoot + 'Covers' + PathDelim;
end;

function TAppPaths.BackupDir: string;
begin
  Result := FRoot + 'Backup' + PathDelim;
end;

function TAppPaths.LogsDir: string;
begin
  Result := FRoot + 'Logs' + PathDelim;
end;

function TAppPaths.DataFile(const AName: string): string;
begin
  Result := DataDir + AName;
end;

function TAppPaths.IndexFile(const AName: string): string;
begin
  Result := DataDir + AName;
end;

function TAppPaths.LockFile: string;
begin
  Result := DataDir + 'Library.lock';
end;

function TAppPaths.TxnFile: string;
begin
  Result := DataDir + 'Library.txn';
end;

function TAppPaths.ActionLogFile: string;
begin
  Result := LogsDir + 'actions.log';
end;

function TAppPaths.TechLogFile: string;
begin
  Result := LogsDir + 'tech.log';
end;

function TAppPaths.GridLayoutFile: string;
begin
  Result := FRoot + 'GridLayout.cfg';
end;

function TAppPaths.UserLayoutFile: string;
begin
  Result := FRoot + 'UserLayout.cfg';
end;

end.
