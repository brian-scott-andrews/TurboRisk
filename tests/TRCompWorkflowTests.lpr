program TRCompWorkflowTests;

{$MODE Delphi}

uses
  Interfaces, Forms, Classes, SysUtils, Variants, Grids, StdCtrls, Controls,
  uPSRuntime, Globals, ExpSubr, TRCompContextForm;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

function ValidScript: string;
begin
  Result :=
    'procedure Assignment(var Territory: integer); begin Territory := 1; end;' +
    LineEnding +
    'procedure Placement(var Territory: integer); begin Territory := 1; end;' +
    LineEnding +
    'procedure Attack(var FromTerritory, ToTerritory: integer); begin FromTerritory := 0; ToTerritory := 0; end;' +
    LineEnding +
    'procedure Occupation(FromTerritory, ToTerritory: integer; var Armies: integer); begin Armies := 1; end;' +
    LineEnding +
    'procedure Fortification(var FromTerritory, ToTerritory, Armies: integer); begin Armies := 0; end;' +
    LineEnding +
    'function ReturnAnswer: integer; begin Result := 42; end;' +
    LineEnding +
    'procedure AddFive(var Value: integer); begin Value := Value + 5; end;' +
    LineEnding +
    'procedure Mutate;' + LineEnding +
    'var RandomValue: double;' + LineEnding +
    'begin' + LineEnding +
    ' UBufferSet(1, 123); UMessageOn; UMessage(''isolated'');' + LineEnding +
    ' ULogOn; UDialogOn; USnapShotOn; UAbortGame;' + LineEnding +
    ' RandomValue := URandom(100);' + LineEnding +
    'end;' + LineEnding +
    'begin end.';
end;

procedure InitializeContext(out Context: TTRCompContext);
var
  I, P: Integer;
  Card: TCard;
begin
  Context.CurrentPlayer := 1;
  Context.Conquest := False;
  Context.CardTradeByCombination := False;
  Context.Message := '';
  for I := 1 to MAXTERRITORIES do begin
    Context.TerritoryOwner[I] := 0;
    Context.TerritoryArmies[I] := 1;
  end;
  for P := 1 to MAXPLAYERS do begin
    Context.PlayerActive[P] := P = 1;
    Context.PlayerName[P] := 'Player ' + IntToStr(P);
    Context.PlayerProgram[P] := 'test.trp';
    Context.PlayerNewArmies[P] := 0;
    for Card := Low(TCard) to High(TCard) do
      Context.PlayerCards[P, Card] := 0;
  end;
  for I := 1 to MAXBUFFER do
    Context.Buffers[I] := 0;
  Context.TerritoryOwner[1] := 1;
  Context.Buffers[1] := 10;
end;

procedure TestContextEditing;
var
  Form: TfTRCompContext;
  EditedContext: TTRCompContext;
  Grid: TStringGrid;
  I: Integer;
  bFoundPlayerGrid, bFoundTerritoryGrid, bFoundBufferGrid: Boolean;
begin
  InitializeContext(EditedContext);
  Form := TfTRCompContext.Create(nil);
  try
    Form.LoadContext(EditedContext);
    bFoundPlayerGrid := False;
    bFoundTerritoryGrid := False;
    bFoundBufferGrid := False;
    for I := 0 to Form.ComponentCount - 1 do
      if Form.Components[I] is TStringGrid then begin
        Grid := TStringGrid(Form.Components[I]);
        if Grid.Cells[0, 0] = 'Player' then begin
          Grid.Cells[2, 1] := 'Edited player';
          Grid.Cells[4, 1] := '7';
          bFoundPlayerGrid := True;
        end
        else if Grid.Cells[0, 0] = 'Territory' then begin
          Grid.Cells[1, 1] := '1';
          Grid.Cells[2, 1] := '4';
          bFoundTerritoryGrid := True;
        end
        else if Grid.Cells[0, 0] = 'Buffer' then begin
          Grid.Cells[1, 1] := FloatToStr(19.5);
          bFoundBufferGrid := True;
        end;
      end;
    Check(bFoundPlayerGrid and bFoundTerritoryGrid and bFoundBufferGrid,
      'Execution-context editor did not expose all editable grids.');
    Check(Form.SaveContext(EditedContext),
      'Execution-context editor rejected valid edited values.');
    Check((EditedContext.PlayerName[1] = 'Edited player') and
      (EditedContext.PlayerNewArmies[1] = 7),
      'Execution-context editor did not save player edits.');
    Check((EditedContext.TerritoryOwner[1] = 1) and
      (EditedContext.TerritoryArmies[1] = 4),
      'Execution-context editor did not save territory edits.');
    Check(Abs(EditedContext.Buffers[1] - 19.5) < 0.001,
      'Execution-context editor did not save buffer edits.');
  finally
    Form.Free;
  end;
end;

procedure TestRoutineExecution;
var
  Context: TTRCompContext;
  Parameters: array of Variant;
  Diagnostics, ReturnValue: string;
  Source: string;
  ExistingExec: TPSExec;
  ExpectedRandom, ActualRandom: Integer;
  bSuccess: Boolean;
begin
  Source := ValidScript;
  bSuccess := ValidateTRPSource('workflow-test.trp', Source, Diagnostics);
  Check(bSuccess,
    'Known-good TRP source was rejected: ' + Diagnostics);
  bSuccess := ValidateTRPSource('incomplete-test.trp',
    'procedure Assignment(var Territory: integer); begin Territory := 1; end;' +
    LineEnding + 'begin end.',
    Diagnostics);
  Check(not bSuccess, 'Incomplete TRP source passed legacy validation.');
  Check(Pos('PLACEMENT procedure not found', Diagnostics) > 0,
    'Incomplete-script diagnostics did not identify the missing routine.');

  InitializeContext(Context);
  ExistingExec := TPSExec.Create;
  ScriptExec := ExistingExec;
  arTerritory[1].Name := 'original territory';
  arTerritory[1].Owner := 9;
  arTerritory[1].Army := 77;
  arContinent[coNA].Name := 'original continent';
  arContinent[coNA].Owner := 8;
  arPlayer[1].Name := 'original player';
  arPlayer[1].Buffer[1] := 999;
  arPlayer[1].UMessageEnabled := False;
  arPlayer[1].ULogEnabled := False;
  arPlayer[1].UDialogEnabled := False;
  arPlayer[1].USnapShotEnabled := False;
  iTurnCounter := 321;
  iTurn := 4;
  iFirstTurn := 3;
  iNPlayers := 6;
  iToAssign := 5;
  iRank := 2;
  aiTurnList[1] := 7;
  GameState := gsDistributing;
  HumanPhase := hpAttack;
  bHumanTurn := True;
  bEliminatedPlayer := True;
  bStopASAP := False;
  bCloseASAP := True;
  sTRCompRuntimeLog := 'existing runtime output';
  SetURandomSeed(1729);
  ExpectedRandom := Random(1000);
  RandSeed := 1729;

  try
    SetLength(Parameters, 0);
    bSuccess := RunTRPRoutine('workflow-test.trp', Source, 'Mutate', Context,
      Parameters, ReturnValue, Diagnostics);
    Check(bSuccess,
      'TRP procedure execution failed: ' + Diagnostics);
    Check(Context.Buffers[1] = 123,
      'Routine execution did not return the edited player buffer.');
    Check(Pos('Message: isolated', Diagnostics) > 0,
      'TRP runtime messages were not captured.');
    Check((ScriptExec = ExistingExec) and
      (arTerritory[1].Name = 'original territory') and
      (arTerritory[1].Owner = 9) and (arTerritory[1].Army = 77),
      'Routine execution did not restore script runtime or territory state.');
    Check((arContinent[coNA].Name = 'original continent') and
      (arContinent[coNA].Owner = 8) and
      (arPlayer[1].Name = 'original player') and
      (arPlayer[1].Buffer[1] = 999),
      'Routine execution did not restore continent and player state.');
    Check(not arPlayer[1].UMessageEnabled and not arPlayer[1].ULogEnabled and
      not arPlayer[1].UDialogEnabled and not arPlayer[1].USnapShotEnabled,
      'Routine execution leaked changed player utility flags.');
    Check((iTurnCounter = 321) and (iTurn = 4) and (iFirstTurn = 3) and
      (iNPlayers = 6) and (iToAssign = 5) and (iRank = 2) and
      (aiTurnList[1] = 7),
      'Routine execution did not restore turn-order state.');
    Check((GameState = gsDistributing) and (HumanPhase = hpAttack) and
      bHumanTurn and bEliminatedPlayer and not bStopASAP and bCloseASAP,
      'Routine execution did not restore game-control flags.');
    Check(sTRCompRuntimeLog = 'existing runtime output',
      'Routine execution did not restore the prior runtime log.');
    ActualRandom := Random(1000);
    Check(ActualRandom = ExpectedRandom,
      'Routine execution changed the game random-number sequence.');

    bSuccess := RunTRPRoutine('workflow-test.trp', Source, 'ReturnAnswer',
      Context, Parameters, ReturnValue, Diagnostics);
    Check(bSuccess,
      'TRP function execution failed: ' + Diagnostics);
    Check(ReturnValue = '42', 'TRP function return value was not captured.');

    SetLength(Parameters, 1);
    Parameters[0] := 8;
    bSuccess := RunTRPRoutine('workflow-test.trp', Source, 'AddFive', Context,
      Parameters, ReturnValue, Diagnostics);
    Check(bSuccess,
      'TRP var-parameter execution failed: ' + Diagnostics);
    Check(Parameters[0] = 13,
      'TRP routine did not return its updated var parameter.');
  finally
    ScriptExec := nil;
    ExistingExec.Free;
  end;
end;

begin
  try
    Application.Initialize;
    TestContextEditing;
    TestRoutineExecution;
    WriteLn('TRComp validation, context-editing, and routine-execution tests passed.');
  except
    on E: Exception do begin
      WriteLn(StdErr, 'TRComp workflow test failed: ', E.Message);
      DumpExceptionBackTrace(StdErr);
      Halt(1);
    end;
  end;
end.
