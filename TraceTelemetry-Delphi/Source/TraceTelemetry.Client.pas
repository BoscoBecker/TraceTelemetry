unit TraceTelemetry.Client;

interface

uses
  System.Classes,
  System.SysUtils,
  System.JSON,
  System.Net.HttpClient,
  System.DateUtils,
  System.Variants,
  System.Math,
  Winapi.Windows,
  System.SyncObjs,
  Vcl.ExtCtrls,
  TraceTelemetry.Options,
  TraceTelemetry.Models,
  TraceTelemetry.Queue,
  TraceTelemetry.Transport;

type
  /// <summary>
  /// Offline-first telemetry client: enqueues to NDJSON file, flushes in batches on a timer. Thread-safe.
  /// </summary>
  TTelemetryClient = class
  private
    FOptions: TTelemetryOptions;
    FQueue: ITelemetryQueue;
    FTransport: ITelemetryTransport;
    FTimer: TTimer;
    FFlushLock: TCriticalSection;
    FStarted: Boolean;
    FDisposed: Boolean;
    
    procedure OnTimerTick(Sender: TObject);
    function GetMachineName: string;
    function GetOsDescription: string;
    function GetLocalIpAddress: string;
    function BuildEvent(const AName: string; AData: TJSONObject = nil): TTelemetryEvent;
    function GenerateEventId: string;
    function GetQueuedCount: Integer;

  public
    constructor Create(AOptions: TTelemetryOptions); overload;
    constructor Create(AOptions: TTelemetryOptions; AQueue: ITelemetryQueue; ATransport: ITelemetryTransport); overload;
    destructor Destroy; override;
    
    /// <summary>
    /// Starts the automatic flush timer. Call once after creating the client.
    /// </summary>
    procedure Start;
    
    /// <summary>
    /// Stops the timer. Does not flush remaining events (call Flush first if needed).
    /// </summary>
    procedure Stop;
    
    /// <summary>
    /// Tries to send one batch to the API. Removes from queue only on success. Never raises.
    /// </summary>
    procedure Flush;
    
    /// <summary>
    /// Track an event by name. Thread-safe, offline-first (writes to NDJSON queue).
    /// </summary>
    procedure Track(const AName: string); overload;
    
    /// <summary>
    /// Track an event with data payload.
    /// </summary>
    procedure Track(const AName: string; AData: TJSONObject); overload;
    
    /// <summary>
    /// Track an event with a single property.
    /// </summary>
    procedure Track(const AName, APropertyName: string; APropertyValue: Variant); overload;
    
    /// <summary>
    /// Track an exception with message, stack trace and type. Never raises.
    /// </summary>
    procedure TrackException(AException: Exception; const AEventName: string = 'exception'; AExtraData: TJSONObject = nil);
    
    /// <summary>
    /// Current number of events in the queue (approximate, for diagnostics).
    /// </summary>
    property QueuedCount: Integer read GetQueuedCount;
  end;

implementation

{ TTelemetryClient }

constructor TTelemetryClient.Create(AOptions: TTelemetryOptions);
begin
  Create(AOptions, nil, nil);
end;

constructor TTelemetryClient.Create(AOptions: TTelemetryOptions; AQueue: ITelemetryQueue; ATransport: ITelemetryTransport);
begin
  inherited Create;
  
  if not Assigned(AOptions) then
    raise Exception.Create('Options is required');
    
  FOptions := AOptions;
  FQueue := AQueue;
  FTransport := ATransport;
  
  if not Assigned(FQueue) then
    FQueue := TFileTelemetryQueue.Create(FOptions);
    
  if not Assigned(FTransport) then
    FTransport := THttpTelemetryTransport.Create(FOptions);
    
  FFlushLock := TCriticalSection.Create;
  FTimer := TTimer.Create(nil);
  FTimer.Enabled := False;
  FTimer.OnTimer := OnTimerTick;
  FStarted := False;
  FDisposed := False;
end;

destructor TTelemetryClient.Destroy;
begin
  Stop;
  FTimer.Free;
  FFlushLock.Free;
  inherited Destroy;
end;

procedure TTelemetryClient.Start;
var
  IntervalMs: Integer;
begin
  if FStarted or FDisposed then
    Exit;
    
  FStarted := True;
  IntervalMs := System.Math.Max(1000, FOptions.FlushIntervalSeconds) * 1000;
  FTimer.Interval := IntervalMs;
  FTimer.Enabled := True;
end;

procedure TTelemetryClient.Stop;
begin
  FStarted := False;
  FDisposed := True;
  FTimer.Enabled := False;
end;

procedure TTelemetryClient.OnTimerTick(Sender: TObject);
begin
  if FFlushLock.TryEnter then
  try
    try
      Flush;
    except
      // Avoid killing the timer thread; events stay in queue for next flush
    end;
  finally
    FFlushLock.Leave;
  end;
end;

procedure TTelemetryClient.Flush;
var
  Batch: TArray<TTelemetryEvent>;
  LinesToRemove: Integer;
begin
  Batch := FQueue.PeekBatch(FOptions.BatchSize);
  if (Length(Batch) = 0) then
    Exit;
    
  LinesToRemove := Length(Batch);
  
  try
    if FTransport.SendBatch(Batch) and (LinesToRemove > 0) then
      FQueue.RemoveFirst(LinesToRemove);
  except
    // Transport should handle errors; extra guard
  end;
end;

procedure TTelemetryClient.Track(const AName: string);
begin
  Track(AName, nil);
end;

procedure TTelemetryClient.Track(const AName: string; AData: TJSONObject);
var
  Event: TTelemetryEvent;
begin
  try
    Event := BuildEvent(AName, AData);
    try
      FQueue.Enqueue(Event);
    finally
      Event.Free;
    end;
  except
    // Silent fail - telemetry should never crash the application
  end;
end;

procedure TTelemetryClient.Track(const AName, APropertyName: string; APropertyValue: Variant);
var
  Data: TJSONObject;
begin
  Data := TJSONObject.Create;
  try
    case VarType(APropertyValue) of
      varString: Data.AddPair(APropertyName, VarToStr(APropertyValue));
      varInteger, varByte, varSmallint, varShortInt: 
        Data.AddPair(APropertyName, TJSONNumber.Create(Double(APropertyValue)));
      varSingle, varDouble, varCurrency:
        Data.AddPair(APropertyName, TJSONNumber.Create(Double(APropertyValue)));
      varBoolean: Data.AddPair(APropertyName, Bool(APropertyValue));
    else
      Data.AddPair(APropertyName, VarToStr(APropertyValue));
    end;
      
    Track(AName, Data);
  finally
    Data.Free;
  end;
end;

procedure TTelemetryClient.TrackException(AException: Exception; const AEventName: string; AExtraData: TJSONObject);
var
  Data: TJSONObject;
  i: Integer;
begin
  if not Assigned(AException) then
    Exit;
    
  try
    Data := TJSONObject.Create;
    try
      Data.AddPair('message', AException.Message);
      Data.AddPair('exceptionType', AException.ClassName);
      
      if AException <> nil then
        Data.AddPair('stackTrace', AException.StackTrace);
        
      if Assigned(AExtraData) then
      begin
        // Merge extra data into the main data object
        for i := 0 to AExtraData.Count - 1 do
          Data.AddPair(AExtraData.Pairs[i].JsonString.Value, AExtraData.Pairs[i].JsonValue.Clone as TJSONValue);
      end;
      
      Track(AEventName, Data);
    finally
      Data.Free;
    end;
  except
    // Silent fail
  end;
end;

function TTelemetryClient.GetQueuedCount: Integer;
begin
  Result := FQueue.PeekCount;
end;

function TTelemetryClient.GenerateEventId: string;
var
  Guid: TGUID;
begin
  CreateGUID(Guid);
  Result := GUIDToString(Guid).Replace('{', '').Replace('}', '').Replace('-', '');
end;

function TTelemetryClient.GetMachineName: string;
var
  Buffer: array[0..MAX_COMPUTERNAME_LENGTH] of Char;
  Size: DWORD;
begin
  Size := MAX_COMPUTERNAME_LENGTH + 1;
  if GetComputerName(Buffer, Size) then
    Result := Buffer
  else
    Result := '';
end;

function TTelemetryClient.GetOsDescription: string;
begin
  try
    Result := TOSVersion.ToString;
  except
    Result := '';
  end;
end;

function TTelemetryClient.GetLocalIpAddress: string;
var
  HttpClient: THttpClient;
  Response: string;
begin
  Result := '';
  try
    HttpClient := THttpClient.Create;
    try
      // Use a simple service to get external IP
      Response := HttpClient.Get('https://api.ipify.org').ContentAsString(TEncoding.UTF8);
      Result := Response.Trim;
    finally
      HttpClient.Free;
    end;
  except
    // Fallback to empty string
  end;
end;

function TTelemetryClient.BuildEvent(const AName: string; AData: TJSONObject): TTelemetryEvent;
var
  EventData: TJSONObject;
begin
  Result := TTelemetryEvent.Create;
  Result.Id := GenerateEventId;
  Result.Name := AName;
  Result.TimestampUtc := Now;
  Result.ApplicationName := FOptions.ApplicationName;
  Result.ApplicationVersion := FOptions.ApplicationVersion;
  Result.MachineName := GetMachineName;
  Result.OsDescription := GetOsDescription;
  Result.IpAddress := GetLocalIpAddress;
  Result.CountryCode := ''; // Could implement IP-to-country lookup if needed
  
  if Assigned(AData) then
    Result.Data := AData.Clone as TJSONObject
  else
    Result.Data := TJSONObject.Create;
end;

end.
