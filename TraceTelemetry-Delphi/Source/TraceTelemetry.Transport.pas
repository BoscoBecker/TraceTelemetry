unit TraceTelemetry.Transport;

interface

uses
  System.Classes,
  System.SysUtils,
  System.JSON,
  System.Net.HttpClient,
  TraceTelemetry.Models,
  TraceTelemetry.Options;

type
  /// <summary>
  /// Interface for telemetry transport implementations
  /// </summary>
  ITelemetryTransport = interface
    ['{87654321-4321-4321-4321-210987654321}']
    function SendBatch(AEvents: TArray<TTelemetryEvent>): Boolean;
  end;

  /// <summary>
  /// HTTP-based telemetry transport implementation
  /// </summary>
  THttpTelemetryTransport = class(TInterfacedObject, ITelemetryTransport)
  private
    FOptions: TTelemetryOptions;
    FHttpClient: THttpClient;
  public
    constructor Create(AOptions: TTelemetryOptions);
    destructor Destroy; override;
    
    function SendBatch(AEvents: TArray<TTelemetryEvent>): Boolean;
  end;

implementation

{ THttpTelemetryTransport }

constructor THttpTelemetryTransport.Create(AOptions: TTelemetryOptions);
begin
  inherited Create;
  FOptions := AOptions;
  FHttpClient := THttpClient.Create;
//  FHttpClient.Timeout := 30000; // 30 seconds timeout
end;

destructor THttpTelemetryTransport.Destroy;
begin
  FHttpClient.Free;
  inherited Destroy;
end;

function THttpTelemetryTransport.SendBatch(AEvents: TArray<TTelemetryEvent>): Boolean;
var
  RequestContent: TStringStream;
  ResponseContent: string;
  ResponseCode: Integer;
  Response: IHTTPResponse;
  JsonArray: TJSONArray;
  i: Integer;
  EventJson: string;
begin
  Result := False;
  
  if (Length(AEvents) = 0) or not Assigned(FOptions) then
    Exit;
    
  try
    // Create NDJSON content
    JsonArray := TJSONArray.Create;
    try
      for i := Low(AEvents) to High(AEvents) do
      begin
        if Assigned(AEvents[i]) then
        begin
          EventJson := AEvents[i].ToJsonString;
          JsonArray.AddElement(TJSONObject.ParseJSONValue(EventJson));
        end;
      end;
      
      RequestContent := TStringStream.Create(JsonArray.ToJSON, TEncoding.UTF8);
      try
        // Set up headers
        //FHttpClient.ClearHeaders;
        FHttpClient.ContentType := 'application/json';
        
        if not FOptions.ApiKey.IsEmpty then
          FHttpClient.CustomHeaders['X-API-Key'] := FOptions.ApiKey;
          
        FHttpClient.CustomHeaders['User-Agent'] :=
          Format('TraceTelemetry-Delphi/%s', [FOptions.ApplicationVersion]);
        
        // Send request
        try
          Response  := FHttpClient.Post(FOptions.EndpointUrl, RequestContent);
          ResponseContent := Response.ContentAsString(TEncoding.UTF8);
          ResponseCode :=Response.StatusCode;
          
          // Consider 2xx status codes as success
          Result := (ResponseCode >= 200) and (ResponseCode < 300);
        except
          Result := False;
        end;
      finally
        RequestContent.Free;
      end;
    finally
      JsonArray.Free;
    end;
  except
    Result := False;
  end;
end;

end.
