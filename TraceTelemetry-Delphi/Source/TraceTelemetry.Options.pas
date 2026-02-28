unit TraceTelemetry.Options;

interface

type
  /// <summary>
  /// Configuration options for TraceTelemetry client
  /// </summary>
  TTelemetryOptions = class
  private
    FEndpointUrl: string;
    FApiKey: string;
    FQueuePath: string;
    FBatchSize: Integer;
    FFlushIntervalSeconds: Integer;
    FApplicationName: string;
    FApplicationVersion: string;
    FEnableCountryLookup: Boolean;
  public
    constructor Create;
    
    /// <summary>
    /// API endpoint URL for sending telemetry data
    /// </summary>
    property EndpointUrl: string read FEndpointUrl write FEndpointUrl;
    
    /// <summary>
    /// API key for authentication (optional)
    /// </summary>
    property ApiKey: string read FApiKey write FApiKey;
    
    /// <summary>
    /// Path to the NDJSON queue file
    /// </summary>
    property QueuePath: string read FQueuePath write FQueuePath;
    
    /// <summary>
    /// Number of events to send in each batch (default: 5)
    /// </summary>
    property BatchSize: Integer read FBatchSize write FBatchSize;
    
    /// <summary>
    /// Interval in seconds for automatic flush (default: 3)
    /// </summary>
    property FlushIntervalSeconds: Integer read FFlushIntervalSeconds write FFlushIntervalSeconds;
    
    /// <summary>
    /// Name of the application sending telemetry
    /// </summary>
    property ApplicationName: string read FApplicationName write FApplicationName;
    
    /// <summary>
    /// Version of the application
    /// </summary>
    property ApplicationVersion: string read FApplicationVersion write FApplicationVersion;
    
    /// <summary>
    /// Enable country code lookup from IP address (default: False)
    /// </summary>
    property EnableCountryLookup: Boolean read FEnableCountryLookup write FEnableCountryLookup;
  end;

implementation

constructor TTelemetryOptions.Create;
begin
  ReportMemoryLeaksOnShutdown := True;
  inherited Create;
  FEndpointUrl := 'https://boscobecker.fun/telemetry';
  FApiKey := '';
  FQueuePath := '';
  FBatchSize := 5;
  FFlushIntervalSeconds := 3;
  FApplicationName := '';
  FApplicationVersion := '';
  FEnableCountryLookup := False;
end;

end.
