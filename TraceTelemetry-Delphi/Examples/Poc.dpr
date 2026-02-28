program Poc;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.IOUtils,
  System.Math,
  System.StrUtils,
  TraceTelemetry.Client,
  TraceTelemetry.Options;

var
  Client: TTelemetryClient;
  Options: TTelemetryOptions;
  ApiBase, ApiKey, QueuePath: string;
  RunLoop: Boolean;
  LoopInterval, BatchSize, FlushInterval: Integer;
  RoundNum: Integer;
  Data: TJSONObject;
  ExceptionData: TJSONObject;
begin
  try
    ApiBase := 'https://boscobecker.fun/';
    ApiBase := ApiBase.Trim(['/']);
    ApiKey := '***';
    RunLoop := True;
    LoopInterval := System.Math.Max(1, StrToIntDef(GetEnvironmentVariable('LOOP_INTERVAL'), 5));
    BatchSize := System.Math.Max(1, StrToIntDef(GetEnvironmentVariable('BATCH_SIZE'), 5));
    FlushInterval := System.Math.Max(1, StrToIntDef(GetEnvironmentVariable('FLUSH_INTERVAL'), 3));
    QueuePath := TPath.Combine(TPath.GetTempPath, 'trace_telemetry_poc_queue.ndjson');
    
    // Configure options
    Options := TTelemetryOptions.Create;
    try
      Options.EndpointUrl := ApiBase + '/telemetry';
      Options.ApiKey := ApiKey;
      Options.QueuePath := QueuePath;
      Options.BatchSize := BatchSize;
      Options.FlushIntervalSeconds := FlushInterval;
      Options.ApplicationName := 'PocAppDelphi';
      Options.ApplicationVersion := '1.0.0';
      
      // Create and start client
      Client := TTelemetryClient.Create(Options);
      try
        Client.Start;
        
        WriteLn('Telemetry started. API: ' + Options.EndpointUrl);
        WriteLn('Queue: ' + QueuePath);
        WriteLn('RunLoop: ' + RunLoop.ToString + IfThen(RunLoop, Format(' (\interval: %ds)', [LoopInterval]), ''));

        if RunLoop then
        begin
          // Loop mode
          RoundNum := 0;
          while True do
          begin
            Inc(RoundNum);
            
            // Track various events
            Client.Track('poc_loop', 'round', RoundNum);
            Client.Track('order_created', TJSONObject.ParseJSONValue(Format('{"order_id": %d, "amount": %.1f}', [1000 + RoundNum, 10.0 * RoundNum])) as TJSONObject);
            Client.Track('screen_view', TJSONObject.ParseJSONValue(Format('{"screen": "Loop", "round": %d}', [RoundNum])) as TJSONObject);
            Client.Track('app_heartbeat', 'queued_count', Client.QueuedCount);
            
            Client.Flush;
            WriteLn(Format('[%s] Round %d enviado. QueuedCount = %d', 
              [FormatDateTime('hh:nn:ss', Now), RoundNum, Client.QueuedCount]));
            
            // Wait for next iteration
            Sleep(LoopInterval * 1000);
          end;
        end
        else
        begin
          // One-shot mode
          Data := TJSONObject.Create;
          try
            Data.AddPair('collected_at', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', Now));
            Client.Track('machine_info', Data);
          finally
            Data.Free;
          end;
          
          // Track order events
          Data := TJSONObject.Create;
          try
            Data.AddPair('order_id', TJSONNumber.Create(123));
            Data.AddPair('amount', TJSONNumber.Create(99.90));
            Client.Track('order_created', Data);
          finally
            Data.Free;
          end;
          
          Data := TJSONObject.Create;
          try
            Data.AddPair('order_id', TJSONNumber.Create(124));
            Client.Track('order_created', Data);
          finally
            Data.Free;
          end;
          
          // Track screen view
          Data := TJSONObject.Create;
          try
            Data.AddPair('screen', 'Dashboard');
            Client.Track('screen_view', Data);
          finally
            Data.Free;
          end;
          
          // Track button click
          Client.Track('button_click', 'button_name', 'Save');
          
          // Track app start
          Client.Track('app_start');
          
          // Track exception
          try
            raise Exception.Create('Simulated POC exception for dashboard testing.');
          except
            on E: Exception do
            begin
              ExceptionData := TJSONObject.Create;
              try
                ExceptionData.AddPair('source', 'PocAppDelphi');
                ExceptionData.AddPair('Erro', E.Message);
                Client.TrackException(E, 'exception', ExceptionData);
                WriteLn('Exception tracked (stacktrace in dashboard).');
              finally
                ExceptionData.Free;
              end;
            end;
          end;
          
          WriteLn('Queued 7 events. QueuedCount = ' + Client.QueuedCount.ToString);
          Sleep(4000);
          Client.Flush;
          WriteLn('After first flush, QueuedCount = ' + Client.QueuedCount.ToString);
          
          // Track one more event
          Data := TJSONObject.Create;
          try
            Data.AddPair('order_id', TJSONNumber.Create(125));
            Client.Track('order_created', Data);
          finally
            Data.Free;
          end;
          
          Sleep(4000);
          Client.Stop;
          WriteLn('Stopped.');
        end;
        
      finally
        Client.Free;
      end;
      
    finally
      Options.Free;
    end;
    
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  
  // Keep console open for a moment
  if not RunLoop then
  begin
    WriteLn('Press Enter to exit...');
    ReadLn;
  end;
end.
