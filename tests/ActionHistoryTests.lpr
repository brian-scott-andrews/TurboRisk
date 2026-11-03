program ActionHistoryTests;

{$MODE Delphi}

uses SysUtils, Classes, IniFiles, fpjson, jsonparser, ActionHistory;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then raise Exception.Create(MessageText);
end;

procedure RejectIndex(Index, Field: Integer);
begin
  try
    ActionValue(Index, Field);
  except
    on E: ERangeError do Exit;
  end;
  raise Exception.Create('Invalid action index/field was accepted');
end;

procedure Run;
var
  TempName, LogName, BadName, SavedName, FirstID: string;
  Event: TActionEvent;
  Ini: TMemIniFile;
  Lines: TStringList;
  Obj: TJSONData;
  I: Integer;
begin
  TempName := GetTempFileName(GetTempDir(False), 'tra');
  LogName := TempName + '.jsonl';
  BadName := TempName + '.txt';
  SavedName := TempName + '.ini';
  Lines := TStringList.Create;
  Ini := TMemIniFile.Create(SavedName);
  try
    BeginActionHistory('{"players":[{"id":1,"name":"A, \"quoted\" bot"}]}');
    Check(ActionCount = 0, 'New game retained previous history');
    FillChar(Event, SizeOf(Event), 0);
    Event[AF_KIND] := AK_PLACEMENT;
    Event[AF_PLAYER] := 1;
    Event[AF_TO] := 5;
    Event[AF_ARMIES] := 3;
    Event[AF_TO_BEFORE] := 2;
    Event[AF_TO_AFTER] := 5;
    for I := 1 to 300 do begin
      Event[AF_TURN] := I;
      RecordAction(Event);
    end;
    Check((ActionCount = 300) and (ActionValue(300, AF_TURN) = 300) and
      (ActionValue(1, AF_ARMIES) = 3), 'History growth changed events');
    RejectIndex(0, AF_KIND);
    RejectIndex(301, AF_KIND);
    RejectIndex(1, 0);
    RejectIndex(1, ACTION_FIELD_COUNT + 1);
    SaveActionHistory(Ini);
    Ini.UpdateFile;
    StartActionLog(LogName);
    Event[AF_KIND] := AK_TURN_END;
    RecordAction(Event);
    StopActionLog;
    Lines.LoadFromFile(LogName);
    Check(Lines.Count = 302, 'Late logging omitted earlier events or live action');
    for I := 0 to Lines.Count - 1 do begin
      Obj := GetJSON(Lines[I]);
      try
        if I = 0 then begin
          FirstID := TJSONObject(Obj).Get('game', '');
          Check(TJSONObject(Obj).Get('history_from_start', False),
            'New-game history incorrectly marked incomplete');
          Check(Obj.FindPath('metadata.players[0].name').AsString = 'A, "quoted" bot',
            'Roster escaping corrupted a name');
        end
        else begin
          Check(TJSONObject(Obj).Get('sequence', 0) = I, 'Log sequence is not ordered');
          Check(TJSONObject(Obj).Get('game', '') = FirstID, 'Event has wrong game ID');
        end;
      finally
        Obj.Free;
      end;
    end;
    Ini.Free;
    Ini := TMemIniFile.Create(SavedName);
    BeginActionHistory('{}');
    StartActionLog(LogName, False);
    LoadActionHistory(Ini, '{}');
    Check((ActionCount = 300) and (ActionValue(300, AF_TURN) = 300),
      'Saved action history did not round trip');
    StopActionLog;
    Lines.LoadFromFile(LogName);
    Check(Lines.Count = 603, 'Restored log did not contain a complete new segment');
    Obj := GetJSON(Lines[302]);
    try
      Check(TJSONObject(Obj).Get('parent_game', '') = FirstID,
        'Restored segment lost its parent ID');
      Check(TJSONObject(Obj).Get('game', '') <> FirstID,
        'Restoring reused a game ID and introduced ambiguous sequences');
    finally
      Obj.Free;
    end;
    Ini.WriteString('ActionHistory', 'Event2', '{"kind":3}');
    try
      LoadActionHistory(Ini, '{}');
      raise Exception.Create('Malformed saved event accepted');
    except
      on E: EConvertError do
        Check(ActionCount = 300, 'Malformed history replaced current history');
    end;
    Ini.EraseSection('ActionHistory');
    LoadActionHistory(Ini, '{}');
    Check(ActionCount = 0, 'Legacy save inherited a previous game''s history');
    StartActionLog(LogName);
    try
      StartActionLog(LogName);
      raise Exception.Create('Already-open log accepted');
    except
      on E: Exception do
        Check(Pos('already open', E.Message) > 0, E.Message);
    end;
    StopActionLog;
    Lines.Text := 'Not an action log';
    Lines.SaveToFile(BadName);
    try
      StartActionLog(BadName);
      raise Exception.Create('Non-action log accepted');
    except
      on E: EJSONParser do ;
      on E: EConvertError do ;
    end;
    Lines.LoadFromFile(BadName);
    Check(Trim(Lines.Text) = 'Not an action log', 'Invalid log was overwritten');
    BeginActionHistory('{}');
    Check(ActionCount = 0, 'History did not reset between games');
    WriteLn('PASS: indexed history, growth, validation, JSONL snapshot/stream/append, save/load and legacy saves.');
  finally
    StopActionLog;
    Ini.Free;
    Lines.Free;
    DeleteFile(LogName);
    DeleteFile(BadName);
    DeleteFile(SavedName);
    DeleteFile(TempName);
  end;
end;

begin
  try
    Run;
  except
    on E: Exception do begin
      WriteLn(StdErr, E.ClassName + ': ' + E.Message);
      Halt(1);
    end;
  end;
end.
