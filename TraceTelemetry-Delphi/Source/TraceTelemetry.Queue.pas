unit TraceTelemetry.Queue;

interface

uses
  System.Classes,
  System.SysUtils,
  System.IOUtils,
  System.JSON,
  System.Math,
  System.DateUtils,
  System.SyncObjs,
  TraceTelemetry.Models,
  TraceTelemetry.Options;

type
  /// <summary>
  /// Interface for telemetry queue implementations
  /// </summary>
  ITelemetryQueue = interface
    ['{12345678-1234-1234-1234-123456789ABC}']
    function Enqueue(AEvent: TTelemetryEvent): Boolean;
    function PeekBatch(ABatchSize: Integer): TArray<TTelemetryEvent>;
    function RemoveFirst(ACount: Integer): Boolean;
    function PeekCount: Integer;
  end;

  /// <summary>
  /// File-based NDJSON telemetry queue implementation
  /// </summary>
  TFileTelemetryQueue = class(TInterfacedObject, ITelemetryQueue)
  private
    FQueuePath: string;
    FLock: TCriticalSection;
  public
    constructor Create(AOptions: TTelemetryOptions);
    destructor Destroy; override;
    
    function Enqueue(AEvent: TTelemetryEvent): Boolean;
    function PeekBatch(ABatchSize: Integer): TArray<TTelemetryEvent>;
    function RemoveFirst(ACount: Integer): Boolean;
    function PeekCount: Integer;
  end;

implementation

{ TFileTelemetryQueue }

constructor TFileTelemetryQueue.Create(AOptions: TTelemetryOptions);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  
  if AOptions.QueuePath.IsEmpty then
    FQueuePath := TPath.Combine(TPath.GetTempPath, 'trace_telemetry_queue.ndjson')
  else
    FQueuePath := AOptions.QueuePath;
    
  // Ensure directory exists
  if not TDirectory.Exists(TPath.GetDirectoryName(FQueuePath)) then
    TDirectory.CreateDirectory(TPath.GetDirectoryName(FQueuePath));
end;

destructor TFileTelemetryQueue.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

function TFileTelemetryQueue.Enqueue(AEvent: TTelemetryEvent): Boolean;
var
  StringList: TStringList;
begin
  Result := False;
  if not Assigned(AEvent) then
    Exit;
    
  FLock.Enter;
  try
    try
      StringList := TStringList.Create;
      try
        if TFile.Exists(FQueuePath) then
          StringList.LoadFromFile(FQueuePath, TEncoding.UTF8);
          
        StringList.Add(AEvent.ToJsonString);
        StringList.SaveToFile(FQueuePath, TEncoding.UTF8);
        Result := True;
      finally
        StringList.Free;
      end;
    except
      Result := False;
    end;
  finally
    FLock.Leave;
  end;
end;

function TFileTelemetryQueue.PeekBatch(ABatchSize: Integer): TArray<TTelemetryEvent>;
var
  StringList: TStringList;
  i, Count: Integer;
  Line: string;
  JsonObj: TJSONObject;
  Event: TTelemetryEvent;
begin
  SetLength(Result, 0);
  
  if ABatchSize <= 0 then
    Exit;
    
  FLock.Enter;
  try
    try
      if not TFile.Exists(FQueuePath) then
        Exit;
        
      StringList := TStringList.Create;
      try
        StringList.LoadFromFile(FQueuePath, TEncoding.UTF8);
        
        Count := System.Math.Min(ABatchSize, StringList.Count);
        SetLength(Result, Count);
        
        for i := 0 to Count - 1 do
        begin
          Line := StringList[i].Trim;
          if Line.IsEmpty then
            Continue;
            
          try
            JsonObj := TJSONObject.ParseJSONValue(Line) as TJSONObject;
            if Assigned(JsonObj) then
            try
              Event := TTelemetryEvent.Create;
              Event.Id := JsonObj.GetValue<string>('id', '');
              Event.Name := JsonObj.GetValue<string>('name', '');
              Event.ApplicationName := JsonObj.GetValue<string>('applicationName', '');
              Event.ApplicationVersion := JsonObj.GetValue<string>('applicationVersion', '');
              Event.MachineName := JsonObj.GetValue<string>('machineName', '');
              Event.OsDescription := JsonObj.GetValue<string>('osDescription', '');
              Event.IpAddress := JsonObj.GetValue<string>('ipAddress', '');
              Event.CountryCode := JsonObj.GetValue<string>('countryCode', '');
              
              // Parse timestamp
              if JsonObj.TryGetValue<string>('timestampUtc', Line) then
              begin
                try
                  Event.TimestampUtc := ISO8601ToDate(Line);
                except
                  Event.TimestampUtc := Now;
                end;
              end;
              
              // Parse data
              if JsonObj.TryGetValue<TJSONObject>('data', JsonObj) then
                Event.Data := JsonObj.Clone as TJSONObject;
                
              Result[i] := Event;
            finally
              JsonObj.Free;
            end;
          except
            // Skip malformed JSON lines
            Continue;
          end;
        end;
      finally
        StringList.Free;
      end;
    except
      SetLength(Result, 0);
    end;
  finally
    FLock.Leave;
  end;
end;

function TFileTelemetryQueue.RemoveFirst(ACount: Integer): Boolean;
var
  StringList: TStringList;
  NewList: TStringList;
  i: Integer;
begin
  Result := False;
  if ACount <= 0 then
    Exit;
    
  FLock.Enter;
  try
    try
      if not TFile.Exists(FQueuePath) then
        Exit;
        
      StringList := TStringList.Create;
      try
        StringList.LoadFromFile(FQueuePath, TEncoding.UTF8);
        
        if ACount >= StringList.Count then
        begin
          // Remove all entries
          TFile.Delete(FQueuePath);
          Result := True;
          Exit;
        end;
        
        // Keep only the lines after the first ACount
        NewList := TStringList.Create;
        try
          for i := ACount to StringList.Count - 1 do
            NewList.Add(StringList[i]);
            
          NewList.SaveToFile(FQueuePath, TEncoding.UTF8);
          Result := True;
        finally
          NewList.Free;
        end;
      finally
        StringList.Free;
      end;
    except
      Result := False;
    end;
  finally
    FLock.Leave;
  end;
end;

function TFileTelemetryQueue.PeekCount: Integer;
var
  StringList: TStringList;
begin
  Result := 0;
  
  FLock.Enter;
  try
    try
      if not TFile.Exists(FQueuePath) then
        Exit;
        
      StringList := TStringList.Create;
      try
        StringList.LoadFromFile(FQueuePath, TEncoding.UTF8);
        Result := StringList.Count;
      finally
        StringList.Free;
      end;
    except
      Result := 0;
    end;
  finally
    FLock.Leave;
  end;
end;

end.
