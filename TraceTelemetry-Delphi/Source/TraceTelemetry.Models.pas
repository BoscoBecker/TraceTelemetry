unit TraceTelemetry.Models;

interface

uses
  System.JSON;

type
  /// <summary>
  /// Represents a telemetry event to be sent to the API
  /// </summary>
  TTelemetryEvent = class
  private
    FId: string;
    FName: string;
    FTimestampUtc: TDateTime;
    FData: TJSONObject;
    FApplicationName: string;
    FApplicationVersion: string;
    FMachineName: string;
    FOsDescription: string;
    FIpAddress: string;
    FCountryCode: string;
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>
    /// Unique identifier for the event
    /// </summary>
    property Id: string read FId write FId;
    
    /// <summary>
    /// Name of the event
    /// </summary>
    property Name: string read FName write FName;
    
    /// <summary>
    /// UTC timestamp when the event occurred
    /// </summary>
    property TimestampUtc: TDateTime read FTimestampUtc write FTimestampUtc;
    
    /// <summary>
    /// Event data payload (JSON object)
    /// </summary>
    property Data: TJSONObject read FData write FData;
    
    /// <summary>
    /// Name of the application sending the event
    /// </summary>
    property ApplicationName: string read FApplicationName write FApplicationName;
    
    /// <summary>
    /// Version of the application
    /// </summary>
    property ApplicationVersion: string read FApplicationVersion write FApplicationVersion;
    
    /// <summary>
    /// Machine name where the event originated
    /// </summary>
    property MachineName: string read FMachineName write FMachineName;
    
    /// <summary>
    /// Operating system description
    /// </summary>
    property OsDescription: string read FOsDescription write FOsDescription;
    
    /// <summary>
    /// IP address of the machine
    /// </summary>
    property IpAddress: string read FIpAddress write FIpAddress;
    
    /// <summary>
    /// Country code derived from IP address
    /// </summary>
    property CountryCode: string read FCountryCode write FCountryCode;
    
    /// <summary>
    /// Converts the event to a JSON string for NDJSON serialization
    /// </summary>
    function ToJsonString: string;
  end;

implementation

uses
  System.SysUtils,
  System.DateUtils;

constructor TTelemetryEvent.Create;
begin
  inherited Create;
  FId := '';
  FName := '';
  FTimestampUtc := Now;
  FData := TJSONObject.Create;
  FApplicationName := '';
  FApplicationVersion := '';
  FMachineName := '';
  FOsDescription := '';
  FIpAddress := '';
  FCountryCode := '';
end;

destructor TTelemetryEvent.Destroy;
begin
  FData.Free;
  inherited Destroy;
end;

function TTelemetryEvent.ToJsonString: string;
var
  JsonObj: TJSONObject;
begin
  JsonObj := TJSONObject.Create;
  try
    JsonObj.AddPair('id', FId);
    JsonObj.AddPair('name', FName);
    
    // Format timestamp as ISO8601 UTC
    JsonObj.AddPair('timestampUtc', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', FTimestampUtc));
    
    if Assigned(FData) then
      JsonObj.AddPair('data', FData.Clone as TJSONObject)
    else
      JsonObj.AddPair('data', TJSONObject.Create);
      
    JsonObj.AddPair('applicationName', FApplicationName);
    JsonObj.AddPair('applicationVersion', FApplicationVersion);
    JsonObj.AddPair('machineName', FMachineName);
    JsonObj.AddPair('osDescription', FOsDescription);
    JsonObj.AddPair('ipAddress', FIpAddress);
    JsonObj.AddPair('countryCode', FCountryCode);
    
    Result := JsonObj.ToJSON;
  finally
    JsonObj.Free;
  end;
end;

end.
