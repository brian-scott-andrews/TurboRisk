unit CooperationRecognitionTests;

{$MODE Delphi}

interface

procedure RunCooperationRecognitionTests;

implementation

uses Classes, SysUtils, Variants, Globals, Territ, ExpSubr;

procedure RunCooperationRecognitionTests;
const
  Bots: array[0..9] of string =
    ('borg', 'Walker2', 'Walker3', 'digger', 'defender', 'hunter',
     'pitbull', 'slave', 'frank', 'frank+');
  Boards: array[0..9] of string =
    ('easy-copy', 'copy-only-front', 'placement-fortification',
     'outsiders-eliminated', 'close-choice', 'prey-master-copy',
     'prey-master-outsider', 'neutral-target-close-choice',
     'frank-three-player-default', 'frank-three-player-cooperative');
  Routines: array[0..2] of string = ('Attack', 'Placement', 'Fortification');
var
  Source, Report: TStringList;
  Base, Context: TTRCompContext;
  Params: array of Variant;
  Name, Diagnostics, ReturnValue, Decision, PairDecision: string;
  Bot, Board, Phase, Recognized, FT, TT, A, Calls: Integer;
  SavedRandom: TURandomState;
  Changed: array[0..9, 0..2] of Integer;
  Paired: array[0..9] of Integer;

  procedure Check(Condition: Boolean; const Detail: string);
  begin
    if not Condition then
      raise Exception.Create(Name + ' / ' + Boards[Board] + ' / ' +
        Routines[Phase] + ': ' + Detail);
  end;

  function Border(FromT, ToT: Integer): Boolean;
  var B: Integer;
  begin
    Result := False;
    for B := 1 to arTerritory[FromT].NBord do
      if arTerritory[FromT].Bord[B] = ToT then Result := True;
  end;

  procedure InitializeBoard;
  var
    I, P: Integer;
    Card: TCard;
  begin
    Base.CurrentPlayer := 1;
    Base.Conquest := False;
    Base.CardTradeByCombination := False;
    Base.Message := '';
    for I := 1 to MAXTERRITORIES do begin
      Base.TerritoryOwner[I] := 3;
      Base.TerritoryArmies[I] := 100;
    end;
    for P := 1 to MAXPLAYERS do begin
      Base.PlayerActive[P] := P <= 3;
      Base.PlayerName[P] := 'Player ' + IntToStr(P);
      Base.PlayerProgram[P] := 'simple.trp';
      Base.PlayerNewArmies[P] := 0;
      for Card := Low(TCard) to High(TCard) do Base.PlayerCards[P, Card] := 0;
    end;
    for I := 1 to MAXBUFFER do Base.Buffers[I] := 0;
    Base.PlayerProgram[1] := Bots[Bot] + '.trp';
    Base.PlayerNewArmies[1] := 5;
    Base.TerritoryOwner[1] := 1;
    Base.TerritoryArmies[1] := 30;
    Base.TerritoryOwner[2] := 2;
    Base.TerritoryArmies[2] := 2;
    Base.TerritoryArmies[4] := 6;
    case Board of
      1: begin
        for I := 1 to MAXTERRITORIES do Base.TerritoryOwner[I] := 2;
        Base.TerritoryOwner[1] := 1;
        Base.TerritoryOwner[42] := 3;
      end;
      2: begin
        Base.TerritoryOwner[4] := 1;
        Base.TerritoryArmies[1] := 40;
        Base.TerritoryArmies[4] := 2;
        Base.TerritoryOwner[37] := 2;
        Base.TerritoryArmies[37] := 2;
      end;
      3: begin
        for I := 1 to MAXTERRITORIES do Base.TerritoryOwner[I] := 2;
        Base.TerritoryOwner[1] := 1;
        Base.TerritoryOwner[4] := 1;
        Base.TerritoryOwner[23] := 1;
        Base.TerritoryArmies[1] := 40;
        Base.TerritoryArmies[4] := 2;
        Base.TerritoryArmies[23] := 1;
        Base.PlayerActive[3] := False;
      end;
      4: begin
        Base.TerritoryArmies[1] := 70;
        Base.TerritoryArmies[2] := 19;
        Base.TerritoryArmies[4] := 20;
        Base.TerritoryOwner[42] := 2;
      end;
      7: begin
        Base.TerritoryArmies[1] := 70;
        Base.TerritoryArmies[2] := 19;
        Base.TerritoryArmies[4] := 20;
        Base.TerritoryOwner[41] := 2;
        Base.TerritoryOwner[42] := 4;
        Base.PlayerActive[4] := True;
      end;
      8, 9: begin
        Base.TerritoryOwner[1] := 3;
        Base.TerritoryArmies[1] := 100;
        Base.TerritoryOwner[2] := 3;
        Base.TerritoryArmies[2] := 100;
        Base.TerritoryArmies[4] := 100;
        Base.TerritoryOwner[31] := 1;
        Base.TerritoryArmies[31] := 30;
        Base.TerritoryArmies[30] := 6;
        for I := 39 to 42 do begin
          Base.TerritoryOwner[I] := 2;
          Base.TerritoryArmies[I] := 2;
        end;
        Base.Buffers[39] := 3;
        if Board = 9 then Base.Buffers[29] := 1;
      end;
    end;
    // Targets are fixed before either arm, not randomly reselected by Assignment.
    if Bot = 5 then Base.Buffers[1] := 3;
    if Bot = 7 then Base.Buffers[50] := 3;
    if Board = 5 then begin
      if Bot = 5 then Base.Buffers[1] := 2;
      if Bot = 7 then Base.Buffers[50] := 2;
    end;
    if Board = 7 then begin
      if Bot = 5 then Base.Buffers[1] := 4;
      if Bot = 7 then Base.Buffers[50] := 4;
    end;
  end;

  procedure Execute;
  var
    I: Integer;
  begin
    Context := Base;
    if Recognized = 1 then Context.PlayerProgram[2] := Context.PlayerProgram[1];
    case Phase of
      0: SetLength(Params, 2);
      1: SetLength(Params, 1);
      2: SetLength(Params, 3);
    end;
    for I := 0 to High(Params) do Params[I] := 0;
    SavedRandom := CaptureURandomState;
    try
      SetURandomSeed(1729);
      Check(RunTRPRoutine(Name, Source.Text, Routines[Phase], Context,
        Params, ReturnValue, Diagnostics), Diagnostics);
    finally
      RestoreURandomState(SavedRandom);
    end;
    Inc(Calls);
    FT := 0;
    TT := 0;
    A := 0;
    if Phase = 1 then begin
      TT := Params[0];
      Check((TT >= 1) and (TT <= MAXTERRITORIES), 'placement out of range');
      Check(Base.TerritoryOwner[TT] = 1, 'placement is not owned');
      Decision := IntToStr(TT);
    end else begin
      FT := Params[0];
      TT := Params[1];
      if Phase = 2 then A := Params[2];
      // Computer.pas uses the source, not the army count, as the pass sentinel.
      if FT <> 0 then begin
        Check((FT >= 1) and (FT <= MAXTERRITORIES) and
          (TT >= 1) and (TT <= MAXTERRITORIES), 'endpoints out of range');
        Check(Base.TerritoryOwner[FT] = 1, 'source is not owned');
        Check(Border(FT, TT), 'endpoints are not adjacent');
        Check(Base.TerritoryArmies[FT] > 1, 'source cannot supply armies');
        if Phase = 0 then
          Check(Base.TerritoryOwner[TT] <> 1, 'attack target is owned')
        else begin
          Check(Base.TerritoryOwner[TT] = 1, 'move destination is not owned');
          Check((A > 0) and (A < Base.TerritoryArmies[FT]), 'illegal move count');
        end;
      end;
      Decision := IntToStr(FT) + '>' + IntToStr(TT);
      if Phase = 2 then Decision := Decision + ':' + IntToStr(A);
    end;
    if Bot = 5 then Decision := Decision + ' prey=' + FloatToStr(Context.Buffers[1]);
    if Bot = 7 then Decision := Decision + ' master=' +
      FloatToStr(Context.Buffers[50]) + ' dead=' + FloatToStr(Context.Buffers[51]);
  end;

begin
  SetupTerritories;
  Calls := 0;
  FillChar(Changed, SizeOf(Changed), 0);
  FillChar(Paired, SizeOf(Paired), 0);
  Source := TStringList.Create;
  Report := TStringList.Create;
  try
    Report.Add('CONTROLLED SAME-PROGRAM RECOGNITION PROBES');
    Report.Add('Generated by tests\CooperationRecognitionTests.pas against current players.');
    Report.Add('Each pair uses byte-identical source and identical context except PlayerProgram[2].');
    Report.Add('Unrecognized arm: simple.trp. Recognized arm: exact PlayerProgram[1] filename.');
    Report.Add('Player 2 still represents the second copy in both arms: only its exposed identity changes.');
    Report.Add('Each routine starts from the same fresh board/buffers, with RandSeed=1729.');
    Report.Add('No attacks, reinforcements, or fortifications are applied between calls.');
    Report.Add('Player 1 is the bot; players 1..3 active unless stated; all others inactive.');
    Report.Add('All cards zero; new armies=5 for player 1, zero for others; conquest=false.');
    Report.Add('All buffers zero except Hunter prey[1]=3 and Slave master[50]=3, dead[51]=0.');
    Report.Add('All unspecified territories: owner 3, 100 armies.');
    Report.Add('Notation below: territory=owner/armies; overrides apply after defaults.');
    Report.Add('easy-copy: 1=1/30, 2=2/2, 4=3/6. Alaska borders 2,4,37.');
    Report.Add('copy-only-front: as easy-copy armies, but all owners=2 except 1=1,42=3.');
    Report.Add('placement-fortification: easy-copy plus 1=1/40,4=1/2,37=2/2.');
    Report.Add('outsiders-eliminated: all owners=2; 1=1/40,4=1/2,23=1/1; player 3 inactive.');
    Report.Add('  Other armies remain easy-copy defaults (2=2, unspecified=100).');
    Report.Add('  Territory 23 belongs to self to exercise Walker coalition endgame convention.');
    Report.Add('close-choice: easy-copy plus 1=1/70,2=2/19,4=3/20,42=2/100.');
    Report.Add('prey-master-copy: easy-copy, but Hunter prey=2 / Slave master=2.');
    Report.Add('prey-master-outsider: easy-copy, prey/master=3 (explicit target control).');
    Report.Add('neutral-target-close-choice (Hunter/Slave only): easy-copy plus 1=1/70,2=2/19,');
    Report.Add('  4=3/20,41=2/100,42=4/100; player 4 active, prey/master=4 (neither local target).');
    Report.Add('frank-three-player-default (Frank/Frank+ only): all territories=3/100 except');
    Report.Add('  31=1/30,30=3/6,39..42=2/2; buffer[39]=3, buffer[29]=0.');
    Report.Add('frank-three-player-cooperative: same as preceding board, buffer[29]=1 in both arms.');
    Report.Add('  Buffer[39] models Assignment initial player count; [29] is the cooperation toggle.');
    Report.Add('');
    Report.Add('Raw output: Attack FT>TT; Placement TT; Fortification FT>TT:armies.');
    Report.Add('FT=0 is a pass in both phases (Computer.pas); unused endpoints/counts shown literally.');
    Report.Add('Each row: bot | board | phase | unrecognized | recognized | observed comparison');
    for Bot := Low(Bots) to High(Bots) do begin
      Name := 'players' + PathDelim + Bots[Bot] + '.trp';
      Source.LoadFromFile(Name);
      if not ValidateTRPSource(Name, Source.Text, Diagnostics) then
        raise Exception.Create(Name + ': ' + Diagnostics);
      for Board := Low(Boards) to High(Boards) do begin
        if (Board in [5, 6, 7]) and (Bot <> 5) and (Bot <> 7) then Continue;
        if (Board >= 8) and (Bot <> 8) and (Bot <> 9) then Continue;
        InitializeBoard;
        for Phase := Low(Routines) to High(Routines) do begin
          Recognized := 0;
          Execute;
          PairDecision := Decision;
          Recognized := 1;
          Execute;
          if PairDecision = Decision then Diagnostics := 'same'
          else begin
            Diagnostics := 'DIFFERENT';
            Inc(Changed[Bot, Phase]);
          end;
          Inc(Paired[Bot]);
          Report.Add(Bots[Bot] + ' | ' + Boards[Board] + ' | ' + Routines[Phase] +
            ' | ' + PairDecision + ' | ' + Decision + ' | ' + Diagnostics);
        end;
      end;
    end;
    Report.Add('');
    Report.Add('OBSERVED SUMMARY (raw-output differences, not assigned cooperation classes)');
    for Bot := Low(Bots) to High(Bots) do
      Report.Add(Bots[Bot] + ': ' + IntToStr(Paired[Bot]) +
        ' paired routine calls; different Attack=' + IntToStr(Changed[Bot, 0]) +
        ', Placement=' + IntToStr(Changed[Bot, 1]) +
        ', Fortification=' + IntToStr(Changed[Bot, 2]) + '.');
    Report.Add('');
    Report.Add('INTERPRETATION AND LIMITATIONS');
    Report.Add('These are observed decisions, not assertions that a bot must belong to a predetermined class.');
    Report.Add('The assertions check successful execution and legal selected actions, not preferred victims.');
    Report.Add('Same decisions on a finite set of boards do not establish universal absence of recognition.');
    Report.Add('A soft ratio penalty can leave the strongest attack unchanged; close-choice probes are included.');
    Report.Add('Raw differences can also include unused pass endpoints; read FT before interpreting a target.');
    Report.Add('Borg can override friend status for a one-army target with >5 attacking armies; easy-copy uses 2.');
    Report.Add('Hunter prey is held fixed across identity arms: prey preference can outweigh its copy penalty.');
    Report.Add('Slave master is held fixed too: its master exclusion is independent of program recognition.');
    Report.Add('The neutral-target board removes local prey/master weighting, without clearing target state.');
    Report.Add('In endgame master/prey=3 has no land: Slave can mark dead[51]=1; Hunter can stop hunting.');
    Report.Add('prey-master-copy isolates protecting/targeting player 2 from recognizing its filename.');
    Report.Add('Frank/Frank+ include both zero-buffer probes and three-player [39]=3 probes with [29]=0/1.');
    Report.Add('Frank/Frank+ contain context- and buffer-gated recognition; these isolated calls do not');
    Report.Add('reproduce complete Assignment/turn histories, all continents, toggles, or every cooperation mode.');
    Report.Add('The eliminated board has no third player; in its unrecognized arm player 2 itself is an outsider.');
    Report.Add('Only direct routine calls are measured: no wins, shared victory, tournament strength, or diplomacy.');
    Report.Add('No playable program is modified, and this is distinct from same-filename ablation.');
    Report.Add('Build command: C:\lazarus\lazbuild.exe tests\TRCompWorkflowTests.lpi');
    Report.Add('Run command from repository root: tests\TRCompWorkflowTests.exe');
    Report.Add('Recognition validation result: PASS, ' + IntToStr(Calls) +
      ' outputs across ' + IntToStr(Calls div 2) + ' identity pairs.');
    Report.Add('This report is saved only after all recognition probes compile, execute and pass legality checks.');
    ForceDirectories('Doc' + PathDelim + 'Tournament');
    Report.SaveToFile('Doc' + PathDelim + 'Tournament' + PathDelim + 'cooperation-mechanisms.txt');
    WriteLn('PASS: controlled recognition probes: ', Calls,
      ' legal routine outputs; report Doc\Tournament\cooperation-mechanisms.txt.');
  finally
    Report.Free;
    Source.Free;
  end;
end;

end.
