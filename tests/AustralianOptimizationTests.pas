unit AustralianOptimizationTests;

{$MODE Delphi}

interface

procedure RunAustralianOptimizationTests;
procedure RunEnemyCostOptimizationTests;
procedure RunLegacyOptimizationTests;

implementation

uses Classes, SysUtils, Variants, Globals, Territ;

function LegacyProbe(const Script: string): string;
var
  Position: Integer;
begin
  Result := Script;
  Position := Length(Result);
  while (Position > 0) and (Copy(Result, Position, 5) <> 'begin') do Dec(Position);
  if Position = 0 then raise Exception.Create('Legacy initialization not found.');
  Insert(
    'procedure TestLegacy(var Stage,Mode,Placed,FromT,ToT,Moved:integer);' + LineEnding +
    'var LegacyIndex,LegacyContinent,LegacySlot:integer; LegacyValue:double;' + LineEnding +
    'begin SetArrayLength(ValIndex,43); ValIndex[0]:=83278; ' +
    'routine:=1+Mode; mrsecondarmies:=300; AverageEnemyArmies:=75; ' +
    'aalive:=Mode; dalive:=1-Mode; CNT2:=17; CNX:=19; CNY:=23; T2:=93; ' +
    'if Stage=0 then begin for LegacyContinent:=1 to 6 do begin ' +
    'LegacyValue:=ContinentValuation(LegacyContinent); LegacySlot:=700+LegacyContinent*10; ' +
    'UBufferSet(LegacySlot,LegacyValue); UBufferSet(LegacySlot+1,CValX); ' +
    'UBufferSet(LegacySlot+2,CNT); UBufferSet(LegacySlot+3,CNT2); ' +
    'UBufferSet(LegacySlot+4,CNM); UBufferSet(LegacySlot+5,CNX); ' +
    'UBufferSet(LegacySlot+6,CNY); UBufferSet(LegacySlot+7,PT); ' +
    'UBufferSet(LegacySlot+8,PA); UBufferSet(LegacySlot+9,EA); end; end; ' +
    'if Stage=1 then begin for LegacyIndex:=1 to 42 do begin ' +
    'LegacyValue:=LoneTerritoryValue(LegacyIndex); ' +
    'UBufferSet(700+LegacyIndex,LegacyValue); UBufferSet(750+LegacyIndex,T2); end; end; ' +
    'if Stage=2 then minnowWhere(FromT,ToT); ' +
    'if Stage=3 then conquestAttack(FromT,ToT); ' +
    'if Stage=4 then begin Placement(Placed); Placement(Placed); Attack(FromT,ToT); end; ' +
    'if Stage=5 then begin Placement(Placed); Attack(FromT,ToT); ' +
    'Fortification(FromT,ToT,Moved); end; ' +
    'if Stage=6 then begin Placement(Placed); Occupation(FromT,ToT,Moved); end; ' +
    'if Stage=7 then Assignment(Placed); ' +
    'if (Stage>=2) then begin UBufferSet(800,T2); ' +
    'for LegacyIndex:=0 to 42 do UBufferSet(850+LegacyIndex,ValIndex[LegacyIndex]); end; end;' +
    LineEnding, Result, Position);
end;

function Instrument(const Script: string): string;
var
  Position: Integer;
  Probe: string;
begin
  Result := StringReplace(Script, 'PArmiesCount(', 'TestCountedArmies(', [rfReplaceAll]);
  Result := StringReplace(Result, '  control:=calculatevuln();',
    '  TestVulnCalls:=TestVulnCalls+1;' + LineEnding + '  control:=calculatevuln();', [rfReplaceAll]);
  Position := Pos('procedure m(', Result);
  if Position = 0 then raise Exception.Create('Australian logging helper not found.');
  Probe :=
    'var TestArmyCalls, TestVulnCalls: integer;' + LineEnding +
    'function TestCountedArmies(P: integer): integer;' + LineEnding +
    'begin TestArmyCalls:=TestArmyCalls+1; Result:=PArmiesCount(P); end;' + LineEnding;
  Insert(Probe, Result, Position);
  // Add probes before the script's final initialization block.
  Position := Length(Result);
  while (Position > 0) and (Copy(Result, Position, 5) <> 'begin') do Dec(Position);
  if Position = 0 then raise Exception.Create('Australian initialization block not found.');
  Probe :=
    'procedure TestTotals(var Biggest, Largest, Second, Reads: integer);' + LineEnding +
    'begin TestArmyCalls:=0; calculatebigarmies(); Biggest:=mrbig; ' +
    'Largest:=mrbigarmies; Second:=mrsecondarmies; Reads:=TestArmyCalls; end;' + LineEnding +
    'procedure TestDecisions(var Placed, FromT, ToT: integer);' + LineEnding +
    'begin Placement(Placed); Attack(FromT,ToT); end;' + LineEnding +
    'procedure TestCachedDecisions(var Placed, FromT, ToT: integer);' + LineEnding +
    'begin Placement(Placed); Placement(Placed); Attack(FromT,ToT); end;' + LineEnding +
    'procedure TestFortification(var FromT, ToT, Moved: integer);' + LineEnding +
    'var Placed, AttackFrom, AttackTo: integer;' + LineEnding +
    'begin Placement(Placed); Attack(AttackFrom,AttackTo); Fortification(FromT,ToT,Moved); end;' + LineEnding +
    'procedure TestInvalidNative(var BadInput: integer);' + LineEnding +
    'var BadArmies, OutputMap: TA09ArmyMap; BadMine: TA09MineMap;' + LineEnding +
    'begin SetArrayLength(BadArmies,43); SetArrayLength(BadMine,43); ' +
    'if BadInput=0 then SetArrayLength(BadArmies,42) else SetArrayLength(BadMine,42); ' +
    'if A09Vulnerability(BadArmies,BadMine,2,2,0,0,0,OutputMap) then BadInput:=99; end;' + LineEnding +
    'procedure TestReducedAttack(var FromT, ToT, Reads: integer);' + LineEnding +
    'var ProbeIndex: integer;' + LineEnding +
    'begin SetArrayLength(MyArmiesMap,43); SetArrayLength(MineArmies,43); ' +
    'SetArrayLength(AttackArmies,43); AttackArmies[0]:=12345; MyArmiesMap[0]:=2468; MineArmies[0]:=True; ' +
    'MyAttackC:=2; PlayersCount:=SAlivePlayersCount; AverageEnemyArmies:=0; ' +
    'calculatebigarmies(); TestVulnCalls:=0; ReduceVulnAttack(FromT,ToT); ' +
    'Reads:=TestVulnCalls; ' +
    'for ProbeIndex:=1 to 42 do begin UBufferSet(300+ProbeIndex,MyArmiesMap[ProbeIndex]); ' +
    'if MineArmies[ProbeIndex] then UBufferSet(350+ProbeIndex,1) else UBufferSet(350+ProbeIndex,0); ' +
    'if Length(AttackArmies)=43 then UBufferSet(400+ProbeIndex,AttackArmies[ProbeIndex]); end; ' +
    'UBufferSet(490,C); UBufferSet(297,AttackArmies[0]); UBufferSet(298,MyArmiesMap[0]); ' +
    'if MineArmies[0] then UBufferSet(299,1) else UBufferSet(299,0); end;' + LineEnding;
  Insert(Probe, Result, Position);
end;

function RestoreAttackBaseline(const Script: string): string;
begin
  Result := StringReplace(Script, '  BaselineReady:boolean;' + LineEnding, '', []);
  Result := StringReplace(Result, '  BaselineReady:=False;' + LineEnding, '', []);
  Result := StringReplace(Result,
    '            if not BaselineReady then begin' + LineEnding +
    '              calculateoverallvuln(overallvuln,maxvuln);' + LineEnding +
    '              BaselineReady:=True;' + LineEnding +
    '            end;',
    '            calculateoverallvuln(overallvuln,maxvuln);', []);
end;

procedure Initialize(var Context: TTRCompContext; Board: Integer);
var
  T, P, Players: Integer;
  Card: TCard;
begin
  Players := 2 + Board mod 9;
  Context.CurrentPlayer := 1 + Board mod Players;
  Context.Conquest := Board mod 2 = 0;
  Context.CardTradeByCombination := Board mod 3 = 0;
  Context.Message := '';
  for P := 1 to MAXPLAYERS do begin
    Context.PlayerActive[P] := P <= Players;
    Context.PlayerName[P] := 'Player ' + IntToStr(P);
    case (P + Board div 9) mod 9 of
      0: Context.PlayerProgram[P] := 'descartes09.trp';
      1: Context.PlayerProgram[P] := 'australian09.trp';
      2: Context.PlayerProgram[P] := 'vexer.trp';
      3: Context.PlayerProgram[P] := 'simple.trp';
      4: Context.PlayerProgram[P] := 'endeavour09.trp';
      5: Context.PlayerProgram[P] := 'frank.trp';
      6: Context.PlayerProgram[P] := 'descartes.trp';
      7: Context.PlayerProgram[P] := 'endeavour.trp';
      8: Context.PlayerProgram[P] := 'zotob.trp';
    end;
    Context.PlayerNewArmies[P] := 1 + Board mod 100;
    for Card := Low(TCard) to High(TCard) do Context.PlayerCards[P, Card] := 0;
  end;
  for T := 1 to MAXBUFFER do Context.Buffers[T] := 0;
  for T := 1 to MAXTERRITORIES do begin
    if Board mod 3 = 0 then
      Context.TerritoryOwner[T] := 1 + (T - 1) mod Players
    else
      Context.TerritoryOwner[T] := 1 + ((T - 1) * Players div MAXTERRITORIES);
    case Board mod 4 of
      0: Context.TerritoryArmies[T] := 1;
      1: Context.TerritoryArmies[T] := 5;
      2: Context.TerritoryArmies[T] := 1 + (T * 17 + Board * 13) mod 101;
      3: Context.TerritoryArmies[T] := 1 + (T * 37 + Board * 19) mod 1001;
    end;
  end;
end;

procedure RunLegacyOptimizationTests;
const
  Bots: array[0..1] of string = ('australian09.trp', 'endeavour09.trp');
var
  Lines: TStringList;
  Script, Reference, Raw, Diagnostics, Value: string;
  Saved, Actual, Expected: TTRCompContext;
  Params, ExpectedParams: array of Variant;
  Bot, Board, Stage, Mode, I, Cases: Integer;
begin
  SetupTerritories;
  Cases := 0;
  for Bot := Low(Bots) to High(Bots) do begin
    Lines := TStringList.Create;
    try
      Lines.LoadFromFile('players' + PathDelim + Bots[Bot]);
      Raw := Lines.Text;
    finally
      Lines.Free;
    end;
    Reference := StringReplace(Raw, 'A09NativeLegacy=True', 'A09NativeLegacy=False', []);
    if Reference = Raw then raise Exception.Create('Legacy reference switch not found.');
    Script := LegacyProbe(Raw);
    Reference := LegacyProbe(Reference);
    for Board := 0 to 71 do begin
      Initialize(Saved, Board);
      Saved.PlayerProgram[Saved.CurrentPlayer] := Bots[Bot];
      if Board mod 12 = 0 then
        for I := 1 to MAXTERRITORIES do Saved.TerritoryOwner[I] := Saved.CurrentPlayer;
      if Board mod 12 = 1 then
        for I := 1 to MAXTERRITORIES do begin
          if I mod 2 = 0 then Saved.TerritoryOwner[I] := Saved.CurrentPlayer
          else Saved.TerritoryOwner[I] := 1 + Saved.CurrentPlayer mod (2 + Board mod 9);
          Saved.TerritoryArmies[I] := 1 + I mod 5;
        end;
      for Stage := 0 to 7 do
        for Mode := 0 to 1 do begin
          if (Stage >= 4) and (Board mod 12 = 0) then Continue;
          Actual := Saved;
          Expected := Saved;
          if Stage = 7 then
            for I := 1 to MAXTERRITORIES do
              if I mod 11 = 0 then begin
                Actual.TerritoryOwner[I] := 0;
                Expected.TerritoryOwner[I] := 0;
              end;
          SetLength(Params, 6);
          Params[0] := Stage;
          Params[1] := Mode;
          Params[2] := 0;
          Params[3] := 0;
          Params[4] := 0;
          Params[5] := 0;
          if Stage = 6 then begin Params[3] := 1; Params[4] := 2 end;
          ExpectedParams := Copy(Params);
          if not RunTRPRoutine(Bots[Bot], Reference, 'TestLegacy', Expected,
            ExpectedParams, Value, Diagnostics) then
            raise Exception.CreateFmt('%s reference board %d stage %d mode %d: %s',
              [Bots[Bot], Board, Stage, Mode, Diagnostics]);
          if not RunTRPRoutine(Bots[Bot], Script, 'TestLegacy', Actual,
            Params, Value, Diagnostics) then
            raise Exception.CreateFmt('%s optimized board %d stage %d mode %d: %s',
              [Bots[Bot], Board, Stage, Mode, Diagnostics]);
          for I := 0 to High(Params) do
            if Params[I] <> ExpectedParams[I] then
              raise Exception.CreateFmt('%s legacy board %d stage %d mode %d output %d differs.',
                [Bots[Bot], Board, Stage, Mode, I]);
          for I := 1 to MAXBUFFER do
            if Actual.Buffers[I] <> Expected.Buffers[I] then
              raise Exception.CreateFmt('%s legacy board %d stage %d mode %d buffer %d differs: %.0f / %.0f.',
                [Bots[Bot], Board, Stage, Mode, I, Actual.Buffers[I], Expected.Buffers[I]]);
          Inc(Cases);
        end;
    end;
  end;
  Script := 'procedure TestBadValues(var Size:integer); var Values:TA09ArmyMap;' +
    ' begin SetArrayLength(Values,Size); A09RelaxValues(Values); end; begin end.';
  for I := 42 to 44 do
    if I <> 43 then begin
      Initialize(Actual, 1);
      SetLength(Params, 1);
      Params[0] := I;
      if RunTRPRoutine('legacy-invalid-map.trp', Script, 'TestBadValues', Actual,
        Params, Value, Diagnostics) then raise Exception.Create('Invalid legacy value map accepted.');
      if Pos('requires a 43-element value map', Diagnostics) = 0 then
        raise Exception.Create('Legacy invalid-map error was not explicit: ' + Diagnostics);
    end;
  WriteLn('09 legacy native/reference decisions, maps and global side effects matched in ', Cases, ' cases.');
end;

procedure RunOptimizationTestsForBot(const BotFile: string);
var
  Lines: TStringList;
  Script, Reference, RawScript, Name, Routine, Diagnostics, Value: string;
  Context, Expected, Saved: TTRCompContext;
  Params, ExpectedParams: array of Variant;
  Board, Stage, TestCase, Count, OutputCount, I, OriginalReads, OptimizedReads,
    ReducedCases: Integer;
begin
  SetupTerritories;
  Name := 'players' + PathDelim + BotFile;
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(Name);
    RawScript := Lines.Text;
    ReducedCases := 0;
    RawScript := StringReplace(RawScript, 'A09NativeVulnerability=True', 'A09NativeVulnerability=False', []);
    for Stage := -1 to 6 do begin
      if Stage = -1 then begin
        Script := RawScript;
        Reference := StringReplace(RawScript,
          '              setupmymaps();' + LineEnding +
          '              MyArmiesMap[T]:=MyArmiesMap[T]-1;',
          '              setupmymaps();' + LineEnding +
          '              calculateoverallvuln(overallvuln,maxvuln);' + LineEnding +
          '              MyArmiesMap[T]:=MyArmiesMap[T]-1;', []);
      end else if Stage = 0 then begin
        Script := RestoreAttackBaseline(RawScript);
        Reference := StringReplace(Script, 'T,CachedArmies:integer;', 'T:integer;', []);
        Reference := StringReplace(Reference, '      CachedArmies:=PArmiesCount(T);' + LineEnding, '', []);
        Reference := StringReplace(Reference, 'CachedArmies', 'PArmiesCount(T)', [rfReplaceAll]);
      end else if Stage = 1 then begin
        Script := RawScript;
        Reference := RestoreAttackBaseline(RawScript);
      end else if Stage = 2 then begin
        Script := RawScript;
        Reference := StringReplace(RawScript, '  preparevulnfacts();' + LineEnding, '', []);
        Reference := StringReplace(Reference, 'VulnScores[P]', 'PlayerScore(P)', [rfReplaceAll]);
        Reference := StringReplace(Reference, 'VulnPrograms[P]', 'lowercase(PProgram(P))', [rfReplaceAll]);
        Reference := StringReplace(Reference, 'VulnArmyTotals[TOwner(T)]', 'PArmiesCount(TOwner(T))', [rfReplaceAll]);
        Reference := StringReplace(Reference, 'VulnArmyTotals[PMe]', 'PArmiesCount(PMe)', [rfReplaceAll]);
        Reference := StringReplace(Reference, 'VulnHumans[P]', 'PHuman(P)', [rfReplaceAll]);
      end else if Stage = 3 then begin
        Script := RawScript;
        Reference := StringReplace(RawScript, '  if CachedPlacement(ToTerritory) then exit;' + LineEnding, '', []);
      end else if Stage = 4 then begin
        Script := RawScript;
        Reference := StringReplace(RawScript, 'if A09LogEnabled then l(', 'l(', [rfReplaceAll]);
        Reference := StringReplace(Reference, 'if A09SnapshotsEnabled then sn(', 'sn(', [rfReplaceAll]);
      end else if Stage = 5 then begin
        Script := RawScript;
        Reference := StringReplace(RawScript, 'MyArmiesMap[T]:=MapArmyBaseline[T]', 'MyArmiesMap[T]:=TArmies(T)', [rfReplaceAll]);
        Reference := StringReplace(Reference, 'MineArmies[T]:=MapMineBaseline[T]', 'MineArmies[T]:=TIsMine(T)', [rfReplaceAll]);
      end else begin
        Script := StringReplace(RawScript, 'A09NativeVulnerability=False', 'A09NativeVulnerability=True', []);
        Reference := RawScript;
      end;
      if Script = Reference then
        raise Exception.CreateFmt('Australian stage %d reference transformation did not apply.', [Stage]);
      Script := Instrument(Script);
      Reference := Instrument(Reference);
      for Board := 0 to 71 do begin
        Initialize(Saved, Board);
        for TestCase := Ord(Stage > 0) to 1 + Ord(Stage > 0) + Ord(Stage = 6) - Ord(Stage = -1) do begin
          OutputCount := 3;
          case TestCase of
            0: begin Routine := 'TestTotals'; Count := 4 end;
            1: begin Routine := 'TestDecisions'; Count := 3 end;
            2: begin Routine := 'TestReducedAttack'; Count := 3; OutputCount := 2 end;
            3: begin Routine := 'TestFortification'; Count := 3 end;
          end;
          if Stage = -1 then begin
            Routine := 'TestFortification';
            Count := 3;
          end;
          if (Stage >= 3) and (TestCase = 1) then Routine := 'TestCachedDecisions';
          Context := Saved;
          SetLength(Params, Count);
          for I := 0 to Count - 1 do Params[I] := 0;
          if not RunTRPRoutine(Name, Reference, Routine, Context, Params, Value, Diagnostics) then
            raise Exception.Create('Australian reference ' + Routine + ': ' + Diagnostics);
          Expected := Context;
          ExpectedParams := Copy(Params, 0, Length(Params));
          Context := Saved;
          for I := 0 to Count - 1 do Params[I] := 0;
          if not RunTRPRoutine(Name, Script, Routine, Context, Params, Value, Diagnostics) then
            raise Exception.Create('Australian optimized ' + Routine + ': ' + Diagnostics);
          for I := 0 to OutputCount - 1 do
            if Params[I] <> ExpectedParams[I] then
              raise Exception.CreateFmt('Australian board %d %s output %d changed', [Board, Routine, I]);
          for I := 1 to MAXBUFFER do
            if Context.Buffers[I] <> Expected.Buffers[I] then
              raise Exception.CreateFmt('Australian board %d %s buffer %d changed', [Board, Routine, I]);
          if (Stage = 0) and (TestCase = 0) then begin
            OriginalReads := ExpectedParams[3];
            OptimizedReads := Params[3];
            if (OptimizedReads > MAXPLAYERS) or (OptimizedReads >= OriginalReads) then
              raise Exception.CreateFmt('Australian board %d did not reduce repeated army reads (%d -> %d)',
                [Board, OriginalReads, OptimizedReads]);
          end;
          if (Stage = 1) and (TestCase = 2) then begin
            OriginalReads := ExpectedParams[2];
            OptimizedReads := Params[2];
            if OriginalReads = 0 then Count := 0 else Count := OriginalReads div 2 + 1;
            if OptimizedReads <> Count then
              raise Exception.CreateFmt('Australian board %d wrong vulnerability call count (%d -> %d, expected %d)',
                [Board, OriginalReads, OptimizedReads, Count]);
            if OriginalReads > OptimizedReads then Inc(ReducedCases);
          end;
        end;
      end;
    end;
    if ReducedCases = 0 then raise Exception.Create('No multi-candidate attack baseline reuse exercised.');
    for TestCase := 0 to 1 do begin
      Initialize(Context, 0);
      SetLength(Params, 1);
      Params[0] := TestCase;
      if RunTRPRoutine(Name, Instrument(RawScript), 'TestInvalidNative', Context, Params, Value, Diagnostics) or
        (Pos('43-element army and ownership maps', Diagnostics) = 0) then
        raise Exception.Create('Native evaluator invalid-map errors were not surfaced: ' + Diagnostics);
    end;
  finally
    Lines.Free;
  end;
  WriteLn('PASS: ', BotFile, ' independent fortification, army-total, attack-baseline, vulnerability-fact, cached-placement, diagnostic, map-baseline and native optimizations: 72 paired boards each, identical decisions, buffers and attack maps.');
end;

procedure RunAustralianOptimizationTests;
begin
  RunOptimizationTestsForBot('australian09.trp');
  RunOptimizationTestsForBot('descartes09.trp');
  RunOptimizationTestsForBot('endeavour09.trp');
end;

function InstrumentEnemyCosts(const Source: string; Native: Boolean): string;
var
  Position: Integer;
  Probe, Sweep: string;
begin
  Result := StringReplace(Source, 'UPropagateEnemyCosts;', 'TestEnemyCosts;', [rfReplaceAll]);
  if Length(Source) - Length(Result) <> 2 *
    (Length('UPropagateEnemyCosts;') - Length('TestEnemyCosts;')) then
    raise Exception.Create('Expected two enemy-cost call sites.');
  if Native then
    Sweep := 'UPropagateEnemyCosts;'
  else begin
    Sweep :=
      'for X:=1 to 8 do begin' +
      ' for T:=1 to 42 do begin' +
      '  if not TIsMine(T) then begin' +
      '   Y:=TBordersCount(T);' +
      '   for Z:=1 to Y do begin' +
      '    T2:=TBorder(T,Z);' +
      '    if not TIsMine(T2) then begin' +
      '     D:=trunc(UBufferGet(T)); D2:=trunc(UBufferGet(T2));' +
      '     if D>D2+TArmies(T) then begin' +
      '      D:=D2+TArmies(T)+1; UBufferSet(T,D);' +
      '     end;' +
      '    end;' +
      '   end;' +
      '  end;' +
      ' end;' +
      'end;';
    // Keep the reference loop in its original caller so its local-variable effects are covered.
    Result := StringReplace(Result, 'TestEnemyCosts;',
      'begin TestEnemyCalls:=TestEnemyCalls+1; ' + Sweep + ' end;', [rfReplaceAll]);
  end;
  Probe := LineEnding +
    'var TestEnemyCalls: integer;' + LineEnding +
    'procedure TestEnemyCosts;' + LineEnding +
    'var X,T,Y,Z,T2,D,D2: integer;' + LineEnding +
    'begin TestEnemyCalls:=TestEnemyCalls+1; ' + Sweep + ' end;' + LineEnding;
  Position := Pos('}', Result);
  if Position = 0 then raise Exception.Create('Bot header not found.');
  Insert(Probe, Result, Position + 1);
  Position := Length(Result);
  while (Position > 0) and (Copy(Result, Position, 5) <> 'begin') do Dec(Position);
  if Position = 0 then raise Exception.Create('Bot initialization not found.');
  Probe :=
    'procedure TestEnemyDecision(var Stage,FromT,ToT,Moved,Calls: integer);' + LineEnding +
    'begin TestEnemyCalls:=0; if Stage=0 then Placement(FromT) ' +
    'else if Stage=1 then Attack(FromT,ToT) else if Stage=2 then TestEnemyCosts ' +
    'else Occupation(FromT,ToT,Moved); ' +
    'Calls:=TestEnemyCalls; end;' + LineEnding;
  Insert(Probe, Result, Position);
end;

procedure CompareEnemyCosts(const Name, Script, Reference: string;
  const Saved: TTRCompContext; Stage, Board: Integer;
  out Actual: TTRCompContext; out Calls: Integer);
var
  Expected: TTRCompContext;
  Params, ExpectedParams: array of Variant;
  Value, Diagnostics: string;
  I: Integer;
begin
  Actual := Saved;
  Expected := Saved;
  SetLength(Params, 5);
  Params[0] := Stage;
  for I := 1 to 4 do Params[I] := 0;
  if Stage = 3 then begin
    Params[1] := 1;
    Params[2] := 2;
  end;
  ExpectedParams := Copy(Params, 0, Length(Params));
  if not RunTRPRoutine(Name, Reference, 'TestEnemyDecision', Expected,
    ExpectedParams, Value, Diagnostics) then
    raise Exception.Create(Name + ' interpreted costs: ' + Diagnostics);
  if not RunTRPRoutine(Name, Script, 'TestEnemyDecision', Actual,
    Params, Value, Diagnostics) then
    raise Exception.Create(Name + ' native costs: ' + Diagnostics);
  for I := 0 to High(Params) do
    if Params[I] <> ExpectedParams[I] then
      raise Exception.CreateFmt('%s board %d stage %d output %d changed',
        [Name, Board, Stage, I]);
  for I := 1 to MAXBUFFER do
    if Actual.Buffers[I] <> Expected.Buffers[I] then
      raise Exception.CreateFmt('%s board %d stage %d buffer %d changed (%g -> %g)',
        [Name, Board, Stage, I, Expected.Buffers[I], Actual.Buffers[I]]);
  Calls := Params[4];
end;

procedure RunEnemyCostTestsForBot(const BotFile: string; CheckMap: Boolean);
var
  Lines: TStringList;
  Name, Script, Reference: string;
  Saved, Actual, Next: TTRCompContext;
  Board, Stage, I, Calls, PlacementCalls, AttackCalls, OccupationCalls,
    SecondCalls: Integer;
begin
  Name := 'players' + PathDelim + BotFile;
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(Name);
    Script := InstrumentEnemyCosts(Lines.Text, True);
    Reference := InstrumentEnemyCosts(Lines.Text, False);
  finally
    Lines.Free;
  end;
  PlacementCalls := 0;
  AttackCalls := 0;
  OccupationCalls := 0;
  for Board := 0 to 71 do begin
    Saved := Default(TTRCompContext);
    Initialize(Saved, Board);
    if CheckMap then
      for Stage := 0 to 2 do begin
        for I := 1 to MAXBUFFER do
          Saved.Buffers[I] := ((I * 31 + Board * 17) mod 4000) - 2000 +
            (Stage - 1) * 0.75;
        CompareEnemyCosts(Name, Script, Reference, Saved, 2, Board, Actual, Calls);
      end;
    Initialize(Saved, Board);
    Saved.Buffers[48] := Board mod 2;
    CompareEnemyCosts(Name, Script, Reference, Saved, 0, Board, Actual, Calls);
    Inc(PlacementCalls, Calls);
    Next := Actual;
    // A later callback must see changed armies and ownership, not a stale board cache.
    for I := 1 to MAXTERRITORIES do
      Inc(Next.TerritoryArmies[I], 1 + I mod 3);
    Next.TerritoryOwner[1] := Next.CurrentPlayer;
    CompareEnemyCosts(Name, Script, Reference, Next, 1, Board, Actual, Calls);
    Inc(AttackCalls, Calls);
    Next := Actual;
    Next.TerritoryOwner[1] := Next.CurrentPlayer;
    Next.TerritoryOwner[2] := Next.CurrentPlayer;
    if Next.TerritoryArmies[1] < 6 then Next.TerritoryArmies[1] := 6;
    Next.TerritoryArmies[2] := 1;
    CompareEnemyCosts(Name, Script, Reference, Next, 3, Board, Actual, Calls);
    Inc(OccupationCalls, Calls);
  end;
  SecondCalls := AttackCalls;
  if (BotFile = 'descartes.trp') or (BotFile = 'zotob.trp') then
    SecondCalls := OccupationCalls;
  if (PlacementCalls = 0) or (SecondCalls = 0) then
    raise Exception.Create(Name + ' did not exercise both optimized callbacks.');
  if CheckMap then begin
    Saved := Default(TTRCompContext);
    Initialize(Saved, 0);
    for I := 1 to MAXTERRITORIES do Saved.TerritoryOwner[I] := Saved.CurrentPlayer;
    Saved.TerritoryOwner[1] := 2;
    Saved.TerritoryOwner[2] := 2;
    Saved.TerritoryArmies[1] := 1;
    Saved.TerritoryArmies[2] := 100;
    Saved.Buffers[1] := 3.75;
    Saved.Buffers[2] := 1.99;
    Saved.Buffers[3] := -9.875;
    CompareEnemyCosts(Name, Script, Reference, Saved, 2, 72, Actual, Calls);
    if (Actual.Buffers[1] <> 3) or (Actual.Buffers[2] <> 1.99) or
      (Actual.Buffers[3] <> -9.875) then
      raise Exception.Create('Enemy costs changed the strict comparison or fractional-value semantics.');
  end;
  WriteLn('PASS: ', BotFile, ': 72 paired placement/attack/occupation boards; identical decisions and all buffers; native calls ',
    PlacementCalls, '/', AttackCalls, '/', OccupationCalls, '.');
end;

procedure RunEnemyCostOptimizationTests;
begin
  SetupTerritories;
  RunEnemyCostTestsForBot('australian+.trp', True);
  RunEnemyCostTestsForBot('australian.trp', False);
  RunEnemyCostTestsForBot('descartes.trp', False);
  RunEnemyCostTestsForBot('zotob.trp', False);
end;

end.
