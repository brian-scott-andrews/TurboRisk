unit ActionHistory;

{$MODE Delphi}

interface

uses Classes, IniFiles;

const
  AK_ASSIGNMENT = 1;
  AK_PLACEMENT = 2;
  AK_ATTACK = 3;
  AK_OCCUPATION = 4;
  AK_FORTIFICATION = 5;
  AK_TURN_START = 6;
  AK_TURN_END = 7;
  AK_REINFORCEMENT = 8;
  AK_CARD_TRADE = 9;
  AK_ELIMINATION = 10;
  AK_GAME_END = 11;

  AF_KIND = 1;
  AF_TURN = 2;
  AF_PLAYER = 3;
  AF_OPPONENT = 4;
  AF_FROM = 5;
  AF_TO = 6;
  AF_ARMIES = 7;
  AF_ATTACKER_LOSS = 8;
  AF_DEFENDER_LOSS = 9;
  AF_CAPTURED = 10;
  AF_FROM_BEFORE = 11;
  AF_TO_BEFORE = 12;
  AF_FROM_AFTER = 13;
  AF_TO_AFTER = 14;
  ACTION_FIELD_COUNT = 14;
  ACTION_KIND_COUNT = 11;

  ActionFieldConstants: array[1..ACTION_FIELD_COUNT] of string =
    ('AF_KIND', 'AF_TURN', 'AF_PLAYER', 'AF_OPPONENT', 'AF_FROM', 'AF_TO',
     'AF_ARMIES', 'AF_ATTACKER_LOSS', 'AF_DEFENDER_LOSS', 'AF_CAPTURED',
     'AF_FROM_BEFORE', 'AF_TO_BEFORE', 'AF_FROM_AFTER', 'AF_TO_AFTER');
  ActionKindConstants: array[1..ACTION_KIND_COUNT] of string =
    ('AK_ASSIGNMENT', 'AK_PLACEMENT', 'AK_ATTACK', 'AK_OCCUPATION',
     'AK_FORTIFICATION', 'AK_TURN_START', 'AK_TURN_END', 'AK_REINFORCEMENT',
     'AK_CARD_TRADE', 'AK_ELIMINATION', 'AK_GAME_END');

type
  TActionEvent = array[1..ACTION_FIELD_COUNT] of Integer;

procedure BeginActionHistory(const Metadata: string);
procedure RecordAction(const Event: TActionEvent);
procedure EndActionHistory(Turn, Winner, Status: Integer);
function ActionCount: Integer;
function ActionValue(Index, Field: Integer): Integer;
procedure SaveActionHistory(Ini: TCustomIniFile);
procedure LoadActionHistory(Ini: TCustomIniFile; const Metadata: string);
procedure StartActionLog(const FileName: string; IncludeCurrentHistory: Boolean = True);
procedure StopActionLog;
function ActionLogFileName: string;

implementation

uses SysUtils, fpjson, jsonparser;

const
  FieldNames: array[1..ACTION_FIELD_COUNT] of string =
    ('kind', 'turn', 'player', 'opponent', 'from', 'to', 'armies',
     'attacker_loss', 'defender_loss', 'captured', 'from_before', 'to_before',
     'from_after', 'to_after');

var
  Events: array of TActionEvent;
  EventCount: Integer;
  GameID, ParentGameID, GameMetadata, LogFileName, LogSegmentID: string;
  HistoryFromStart: Boolean;
  LogStream: TFileStream;

function ActionCount: Integer;
begin
  Result := EventCount;
end;

function ActionValue(Index, Field: Integer): Integer;
begin
  if (Index < 1) or (Index > EventCount) then
    raise ERangeError.CreateFmt('Action index %d is outside 1..%d', [Index, EventCount]);
  if (Field < 1) or (Field > ACTION_FIELD_COUNT) then
    raise ERangeError.CreateFmt('Action field %d is outside 1..%d',
      [Field, ACTION_FIELD_COUNT]);
  Result := Events[Index - 1][Field];
end;

function EventObject(const Event: TActionEvent): TJSONObject;
var
  I: Integer;
begin
  Result := TJSONObject.Create;
  for I := 1 to ACTION_FIELD_COUNT do Result.Add(FieldNames[I], Event[I]);
end;

function UniqueID: string;
var
  ID: TGUID;
begin
  if CreateGUID(ID) <> 0 then raise Exception.Create('Cannot create action-history ID');
  Result := GUIDToString(ID);
end;

procedure WriteJSONLine(const Line: string);
var
  Data: UTF8String;
begin
  if LogStream = nil then Exit;
  Data := UTF8String(Line + #10);
  try
    LogStream.WriteBuffer(Data[1], Length(Data));
  except
    on E: Exception do begin
      FreeAndNil(LogStream);
      Data := UTF8String('Cannot write action log "' + LogFileName + '": ' + E.Message);
      LogFileName := '';
      raise EWriteError.Create(string(Data));
    end;
  end;
end;

procedure WriteGameHeader;
var
  Obj: TJSONObject;
begin
  if (LogStream = nil) or (GameID = '') then Exit;
  LogSegmentID := UniqueID;
  Obj := TJSONObject.Create;
  try
    Obj.Add('format', 'TurboRisk.actions');
    Obj.Add('version', 1);
    Obj.Add('type', 'game');
    Obj.Add('game', GameID);
    Obj.Add('segment', LogSegmentID);
    Obj.Add('parent_game', ParentGameID);
    Obj.Add('history_from_start', HistoryFromStart);
    Obj.Add('metadata', GetJSON(GameMetadata));
    WriteJSONLine(Obj.AsJSON);
  finally
    Obj.Free;
  end;
end;

procedure WriteEvent(Index: Integer);
var
  Obj: TJSONObject;
begin
  if LogStream = nil then Exit;
  Obj := EventObject(Events[Index - 1]);
  try
    Obj.Add('type', 'action');
    Obj.Add('game', GameID);
    Obj.Add('segment', LogSegmentID);
    Obj.Add('sequence', Index);
    WriteJSONLine(Obj.AsJSON);
  finally
    Obj.Free;
  end;
end;

procedure NewGameID;
begin
  GameID := UniqueID;
end;

procedure ValidateEvent(const Event: TActionEvent);
var
  I: Integer;
begin
  for I := 1 to ACTION_FIELD_COUNT do
    if Event[I] < 0 then
      raise EConvertError.CreateFmt('Negative action-history field %s', [FieldNames[I]]);
  if (Event[AF_KIND] < 1) or (Event[AF_KIND] > ACTION_KIND_COUNT) or
     (Event[AF_PLAYER] > 10) or (Event[AF_OPPONENT] > 10) or
     (Event[AF_FROM] > 42) or (Event[AF_TO] > 42) or
     (Event[AF_CAPTURED] > 1) then
    raise EConvertError.Create('Invalid action-history kind, player or territory');
end;

procedure BeginActionHistory(const Metadata: string);
begin
  EventCount := 0;
  SetLength(Events, 0);
  ParentGameID := '';
  GameMetadata := Metadata;
  HistoryFromStart := True;
  NewGameID;
  WriteGameHeader;
end;

procedure RecordAction(const Event: TActionEvent);
begin
  if GameID = '' then Exit;
  ValidateEvent(Event);
  if EventCount = Length(Events) then begin
    if EventCount > (MaxInt div 2) - 128 then
      raise ERangeError.Create('Action history capacity exceeded');
    SetLength(Events, EventCount * 2 + 128);
  end;
  Events[EventCount] := Event;
  Inc(EventCount);
  WriteEvent(EventCount);
end;

procedure EndActionHistory(Turn, Winner, Status: Integer);
var
  Event: TActionEvent;
begin
  if GameID = '' then Exit;
  if (EventCount > 0) and (Events[EventCount - 1][AF_KIND] = AK_GAME_END) then Exit;
  FillChar(Event, SizeOf(Event), 0);
  Event[AF_KIND] := AK_GAME_END;
  Event[AF_TURN] := Turn;
  Event[AF_PLAYER] := Winner;
  Event[AF_ARMIES] := Status;
  RecordAction(Event);
end;

procedure SaveActionHistory(Ini: TCustomIniFile);
var
  I: Integer;
  Obj: TJSONObject;
begin
  Ini.EraseSection('ActionHistory');
  Ini.WriteInteger('ActionHistory', 'Version', 1);
  Ini.WriteString('ActionHistory', 'GameID', GameID);
  Ini.WriteBool('ActionHistory', 'FromStart', HistoryFromStart);
  Ini.WriteInteger('ActionHistory', 'Count', EventCount);
  for I := 1 to EventCount do begin
    Obj := EventObject(Events[I - 1]);
    try
      Ini.WriteString('ActionHistory', 'Event' + IntToStr(I), Obj.AsJSON);
    finally
      Obj.Free;
    end;
  end;
end;

procedure LoadActionHistory(Ini: TCustomIniFile; const Metadata: string);
var
  Loaded: array of TActionEvent;
  Count, I, J: Integer;
  Keys: TStringList;
  Data, Value: TJSONData;
begin
  Count := Ini.ReadInteger('ActionHistory', 'Count', 0);
  Keys := TStringList.Create;
  try
    Ini.ReadSection('ActionHistory', Keys);
    if (Count < 0) or (Count > Keys.Count) then
      raise EConvertError.Create('Invalid saved action-history count');
  finally
    Keys.Free;
  end;
  if Ini.SectionExists('ActionHistory') and
     (Ini.ReadInteger('ActionHistory', 'Version', 0) <> 1) then
    raise EConvertError.Create('Unsupported saved action-history version');
  SetLength(Loaded, Count);
  for I := 1 to Count do begin
    Data := GetJSON(Ini.ReadString('ActionHistory', 'Event' + IntToStr(I), ''));
    try
      if not (Data is TJSONObject) then
        raise EConvertError.CreateFmt('Invalid saved action %d', [I]);
      for J := 1 to ACTION_FIELD_COUNT do begin
        Value := TJSONObject(Data).Find(FieldNames[J]);
        if (Value = nil) or (Value.JSONType <> jtNumber) then
          raise EConvertError.CreateFmt('Missing numeric field %s in action %d',
            [FieldNames[J], I]);
        if not TryStrToInt(Value.AsJSON, Loaded[I - 1][J]) then
          raise EConvertError.CreateFmt('Invalid integer field %s in action %d',
            [FieldNames[J], I]);
      end;
      ValidateEvent(Loaded[I - 1]);
    finally
      Data.Free;
    end;
  end;
  Events := Loaded;
  EventCount := Count;
  ParentGameID := Ini.ReadString('ActionHistory', 'GameID', '');
  HistoryFromStart := Ini.ReadBool('ActionHistory', 'FromStart', False);
  GameMetadata := Metadata;
  NewGameID;
  WriteGameHeader;
  for I := 1 to EventCount do WriteEvent(I);
end;

procedure StartActionLog(const FileName: string; IncludeCurrentHistory: Boolean);
var
  Candidate: TFileStream;
  FirstLine: string;
  Header: TJSONData;
  LastByte: Byte;
  I: Integer;
begin
  if (LogStream <> nil) and SameFileName(ExpandFileName(FileName), LogFileName) then
    raise Exception.Create('This action log is already open');
  Candidate := nil;
  try
    if FileExists(FileName) then begin
      Candidate := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyWrite);
      if Candidate.Size > 0 then begin
        FirstLine := '';
        while Candidate.Position < Candidate.Size do begin
          Candidate.ReadBuffer(LastByte, 1);
          if LastByte = 10 then Break;
          FirstLine := FirstLine + Chr(LastByte);
          if Length(FirstLine) > 1024 * 1024 then
            raise EConvertError.Create('Action log header is too large');
        end;
        Header := GetJSON(FirstLine);
        try
          if not (Header is TJSONObject) then
            raise EConvertError.Create('Not a TurboRisk action log');
          if (TJSONObject(Header).Get('format', '') <> 'TurboRisk.actions') or
             (TJSONObject(Header).Get('version', 0) <> 1) then
            raise EConvertError.Create('Unsupported action log format');
        finally
          Header.Free;
        end;
        Candidate.Seek(-1, soEnd);
        Candidate.ReadBuffer(LastByte, 1);
        if LastByte <> 10 then
          raise EConvertError.Create('Action log has an incomplete final line');
      end;
      Candidate.Seek(0, soEnd);
    end
    else Candidate := TFileStream.Create(FileName, fmCreate or fmShareDenyWrite);
    StopActionLog;
    LogStream := Candidate;
    Candidate := nil;
    LogFileName := ExpandFileName(FileName);
    if IncludeCurrentHistory then begin
      WriteGameHeader;
      for I := 1 to EventCount do WriteEvent(I);
    end;
  finally
    Candidate.Free;
  end;
end;

procedure StopActionLog;
begin
  FreeAndNil(LogStream);
  LogFileName := '';
end;

function ActionLogFileName: string;
begin
  Result := LogFileName;
end;

finalization
  StopActionLog;
end.
