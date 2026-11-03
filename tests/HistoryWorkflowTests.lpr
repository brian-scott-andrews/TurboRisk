program HistoryWorkflowTests;

{$MODE Delphi}

uses
  Interfaces, Forms, Classes, SysUtils, StdCtrls, LCLType, Messages,
  GameResults, Globals, History, SimGameLog, Programs, ActionEngineTests;

const
  LegacyLine = '20261102,3,First Bot,second,third';
  CompleteLine = '20261102,131500,1,42,18,3,First Bot,18,100,42,second,17,0,0,third,12,0,0';
  TimeoutLine = '20261102,131501,4,180,25,2,first,25,40,20,second,25,30,22';
  ErrorLine = '20261102,131502,2,5,1,2,first,1,40,20,second,1,30,22';

procedure Check(Condition: boolean; const MessageText: string);
begin
  if not Condition then raise Exception.Create(MessageText);
end;

procedure Reject(const Line: string);
begin
  try
    ParseGameResult(Line);
  except
    on E: EConvertError do Exit;
  end;
  raise Exception.Create('Malformed result was accepted: ' + Line);
end;

procedure TestProgramPreview;
var
  Preview: TfPrograms;
  Source: TStringList;
  SavedAppPath, Header: string;
  I, FirstBrace, LastBrace: integer;
begin
  SavedAppPath := sG_AppPath;
  sG_AppPath := IncludeTrailingPathDelimiter(ExpandFileName('.'));
  Preview := TfPrograms.Create(nil);
  Source := TStringList.Create;
  try
    Preview.OnShow := nil;
    Preview.Show;
    Preview.lstPrgFile.Items.Clear;
    Preview.lstPrgFile.Items.Add('finisher.trp');
    Preview.lstPrgFile.Items.Add('actuary.trp');
    Preview.lstPrgFile.Items.Add('defender.trp');
    for I := 0 to Preview.lstPrgFile.Items.Count - 1 do begin
      Source.LoadFromFile(sG_AppPath + 'players' + PathDelim +
        Preview.lstPrgFile.Items[I]);
      FirstBrace := Pos('{', Source.Text);
      LastBrace := Pos('}', Source.Text);
      Header := Copy(Source.Text, FirstBrace + 1, LastBrace - FirstBrace - 1);
      Preview.lstPrgFile.ItemIndex := I;
      Preview.lstPrgFileClick(nil);
      Application.ProcessMessages;
      Check(Trim(Preview.txtPrgDesc.Text) = Trim(Header),
        'Program preview omitted header text.');
      Check(Preview.txtPrgDesc.SelStart = 0, 'Program preview caret is not at the top.');
      Check(Preview.txtPrgDesc.Perform(EM_GETFIRSTVISIBLELINE, 0, 0) = 0,
        'Program preview scrolled past the beginning.');
      Check(Preview.txtPrgDesc.ReadOnly and
        (Preview.txtPrgDesc.ScrollBars = ssVertical),
        'Program preview must be read-only and scrollable.');
      Preview.txtPrgDesc.SelStart := Length(Preview.txtPrgDesc.Text);
      Preview.txtPrgDesc.Perform(EM_SCROLLCARET, 0, 0);
    end;
  finally
    Source.Free;
    Preview.Free;
    sG_AppPath := SavedAppPath;
  end;
  WriteLn('PASS: complete program headers, top-of-preview reset and scrolling.');
end;

procedure Run;
var
  Game: TGameResult;
  Games: TGameResults;
  Lines: TStringList;
  TempName, InputName, OutputName, TenPlayerLine: string;
  Skipped, I, Exported: integer;
  HistoryForm: TfHistory;
  LogForm: TfSimGameLog;
begin
  Check(Ord(ssComplete) = RESULT_COMPLETE, 'Completed status mapping changed.');
  Game := ParseGameResult(LegacyLine);
  Check(not Game.HasDetails, 'Legacy metadata must be absent.');
  Check((Game.Duration = -1) and (Game.Players[0].Army = -1),
    'Unknown legacy metadata was fabricated.');
  Check(HistoryResultLine(Game) = LegacyLine, 'Legacy round trip changed names/order.');
  Game := ParseGameResult(CompleteLine);
  Check(Game.HasDetails and (Game.PlayerCount = 3) and (Game.Duration = 42),
    'Simulator metadata was not read.');
  Check(HistoryResultLine(Game) = LegacyLine, 'Simulator conversion changed finishing order.');
  TenPlayerLine := '20261102,131500,1,42,18,10';
  for I := 1 to 10 do
    TenPlayerLine := TenPlayerLine + ',bot' + IntToStr(I) + ',18,0,0';
  Game := ParseGameResult(TenPlayerLine);
  Check((Game.PlayerCount = 10) and (Game.Players[9].Name = 'bot10'),
    'Ten-player simulator result failed.');
  Game := ParseGameResult(HistoryResultLine(Game));
  Check((Game.PlayerCount = 10) and not Game.HasDetails,
    'Ten-player legacy result failed.');
  Game := ParseGameResult(CompleteLine);
  SetLength(Games, 6);
  Games[0] := Game;
  for I := 0 to 4 do begin
    Games[I + 1] := ParseGameResult(TimeoutLine);
    Games[I + 1].Status := I;
    if I = RESULT_COMPLETE then Games[I + 1].Status := 5;
  end;
  Lines := CompletedHistoryLines(Games, Skipped);
  try
    Check((Lines.Count = 1) and (Skipped = 5), 'Incomplete games entered history.');
  finally
    Lines.Free;
  end;
  Reject('20260230,2,a,b');
  Reject('20261102,1,a');
  Reject('20261102,11,a,b');
  Reject('20261102,2,a');
  Reject('20261102,2,a,b,extra');
  Reject('20261102,2,,b');
  Reject('20261102,250000,1,42,18,2,a,18,100,42,b,17,0,0');
  Reject('20261102,131500,6,42,18,2,a,18,100,42,b,17,0,0');
  Reject('20261102,131500,1,-1,18,2,a,18,100,42,b,17,0,0');
  Reject('20261102,131500,1,42,18,2,a,18,100,42,b,17,0');

  TempName := GetTempFileName(GetTempDir(false), 'trh');
  InputName := TempName + '.sgl';
  OutputName := TempName + '.txt';
  Lines := TStringList.Create;
  HistoryForm := TfHistory.Create(nil);
  LogForm := TfSimGameLog.Create(nil);
  try
    Lines.Add(CompleteLine);
    Lines.Add('');
    Lines.Add(TimeoutLine);
    Lines.Add(ErrorLine);
    Lines.SaveToFile(InputName);
    Games := ReadGameResults(InputName);
    Check(Length(Games) = 3, 'Blank-line handling failed.');
    HistoryForm.LoadHistoryFile(InputName);
    Check(HistoryForm.lstHistory.Items.Count = 1, 'History displayed unfinished games.');
    Check(HistoryForm.lstHistory.Items[0].SubItems[1] = 'first bot', 'Wrong history winner.');
    Check(HistoryForm.grdRanking.RowCount = 4, 'History ranking player count is wrong.');
    Check(HistoryForm.cboPlayer1.Items.Count = 3, 'History comparison roster is wrong.');
    Check((HistoryForm.grdRanking.Cells[1, 1] = '1') and
      (HistoryForm.grdRanking.Cells[2, 1] = '1') and
      (HistoryForm.grdRanking.Cells[4, 1] = '3'), 'Winner statistics changed.');
    HistoryForm.cboPlayer1.ItemIndex := HistoryForm.cboPlayer1.Items.IndexOf('first bot');
    HistoryForm.cboPlayer2.ItemIndex := HistoryForm.cboPlayer2.Items.IndexOf('second');
    HistoryForm.cmdAnalyzeClick(nil);
    Check(HistoryForm.prbPlayer1.Position = 100, 'History comparison order changed.');
    LogForm.sLogFileName := InputName;
    LogForm.FormShow(nil);
    Check(LogForm.lstGames.Items.Count = 3, 'Simulator viewer lost unfinished games.');
    Exported := LogForm.ExportHistoryFile(OutputName, Skipped);
    Check((Exported = 1) and (Skipped = 2), 'Export counts are wrong.');
    Lines.LoadFromFile(OutputName);
    Check((Lines.Count = 1) and (Lines[0] = LegacyLine), 'Export layout is not legacy-compatible.');
    Lines.LoadFromFile(InputName);
    Check((Lines.Count = 4) and (Lines[0] = CompleteLine), 'Export changed the source log.');
    HistoryForm.LoadHistoryFile(OutputName);
    Check(HistoryForm.lstHistory.Items.Count = 1, 'Export cannot be reopened as history.');
    try
      LogForm.ExportHistoryFile(InputName, Skipped);
      raise Exception.Create('Export allowed overwriting the source.');
    except
      on E: Exception do
        Check(Pos('source log must not be overwritten', E.Message) > 0, E.Message);
    end;
    Lines.Clear;
    Lines.Add(TimeoutLine);
    Lines.SaveToFile(OutputName);
    HistoryForm.LoadHistoryFile(OutputName);
    Check((HistoryForm.lstHistory.Items.Count = 0) and
      (HistoryForm.grdRanking.RowCount = 1) and
      (HistoryForm.cboPlayer1.Items.Count = 0), 'Empty import left stale rankings.');
    Lines.Add('invalid result');
    Lines.SaveToFile(OutputName);
    try
      ReadGameResults(OutputName);
      raise Exception.Create('Malformed file was accepted.');
    except
      on E: EConvertError do
        Check(Pos('line 2:', E.Message) > 0, 'Error lacks the source line number.');
    end;
    Lines.Clear;
    Lines.Add(LegacyLine);
    Lines.Add(CompleteLine);
    Lines.SaveToFile(OutputName);
    HistoryForm.LoadHistoryFile(OutputName);
    Check(HistoryForm.lstHistory.Items.Count = 2, 'Mixed history and simulator file failed.');
    Lines.Add('invalid result');
    Lines.SaveToFile(OutputName);
    try
      HistoryForm.LoadHistoryFile(OutputName);
      raise Exception.Create('Invalid history import was accepted.');
    except
      on E: EConvertError do
        Check(HistoryForm.lstHistory.Items.Count = 2, 'Invalid import discarded the displayed history.');
    end;
  finally
    LogForm.Free;
    HistoryForm.Free;
    Lines.Free;
    DeleteFile(InputName);
    DeleteFile(OutputName);
    DeleteFile(TempName);
  end;
  WriteLn('PASS: shared parser, history import/rankings, simulator viewer and legacy export.');
end;

begin
  Application.Initialize;
  try
    Run;
    TestProgramPreview;
    RunActionEngineTests;
  except
    on E: Exception do begin
      WriteLn(StdErr, E.ClassName + ': ' + E.Message);
      Halt(1);
    end;
  end;
end.
