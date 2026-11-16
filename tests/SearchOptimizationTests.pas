unit SearchOptimizationTests;

{$MODE Delphi}

interface

procedure RunSearchOptimizationTests;

implementation

uses Classes, SysUtils, Variants, Globals, Territ;

// Exact routines from the runtime frozen before these optimizations.
{$I SearchOptimizationReferences.inc}

var ComparisonCount: Integer;

function ReplaceRoutine(const Source, StartMarker, EndMarker, Reference: string): string;
var First, Last: Integer;
begin
  First := Pos(StartMarker, Source);
  Last := Pos(EndMarker, Source);
  if (First = 0) or (Last <= First) then
    raise Exception.Create('Search optimization reference marker missing: ' + StartMarker);
  Result := Copy(Source, 1, First - 1) + Reference + Copy(Source, Last, MaxInt);
  if Result = Source then
    raise Exception.Create('Search optimization reference replacement did not change source: ' + StartMarker);
end;

function Inject(const Source, Probe: string): string;
var Position: Integer;
begin
  Result := Source;
  Position := Length(Result);
  while (Position > 0) and (Copy(Result, Position, 5) <> 'begin') do Dec(Position);
  if Position = 0 then raise Exception.Create('Search optimization initialization missing');
  Insert(Probe + LineEnding, Result, Position);
end;

procedure Initialize(var Context: TTRCompContext; Board: Integer);
var T, P, Players: Integer; Card: TCard;
begin
  Players := 2 + Board mod 5;
  Context.CurrentPlayer := 1;
  Context.Conquest := Board mod 2 = 0;
  Context.CardTradeByCombination := Board mod 3 = 0;
  Context.Message := '';
  for P := 1 to MAXPLAYERS do begin
    Context.PlayerActive[P] := P <= Players;
    Context.PlayerName[P] := 'Player ' + IntToStr(P);
    Context.PlayerProgram[P] := 'simple.trp';
    Context.PlayerNewArmies[P] := (Board * 7) mod 50;
    for Card := Low(TCard) to High(TCard) do Context.PlayerCards[P, Card] := 0;
    Context.PlayerCards[P, caInf] := (P + Board) mod 4;
  end;
  for T := 1 to MAXBUFFER do Context.Buffers[T] := (T + Board) mod 7;
  for T := 1 to MAXTERRITORIES do begin
    case Board mod 4 of
      0: Context.TerritoryOwner[T] := 1 + (T - 1) mod Players;
      1: Context.TerritoryOwner[T] := 1 + (T - 1) * Players div 42;
      2: if T mod 8 = 0 then Context.TerritoryOwner[T] := 2
         else Context.TerritoryOwner[T] := 1 + (T * 13 + Board) mod Players;
      3: if T <= 30 then Context.TerritoryOwner[T] := 1
         else Context.TerritoryOwner[T] := 2 + (T + Board) mod (Players - 1);
    end;
    case Board mod 4 of
      0: Context.TerritoryArmies[T] := 1;
      1: Context.TerritoryArmies[T] := 5;
      2: Context.TerritoryArmies[T] := 1 + (T * 17 + Board * 7) mod 40;
      3: Context.TerritoryArmies[T] := 1 + (T * 11 + Board) mod 12;
    end;
  end;
end;

procedure Compare(const Name, Script, Reference, Routine: string;
  const Initial: TTRCompContext; const Inputs: array of Integer; Board: Integer);
var
  Actual, Expected: TTRCompContext;
  A, B: array of Variant;
  ActualValue, ExpectedValue, Diagnostics: string;
  I: Integer;
begin
  Inc(ComparisonCount);
  Actual := Initial; Expected := Initial;
  SetLength(A, Length(Inputs)); SetLength(B, Length(Inputs));
  for I := 0 to High(Inputs) do begin A[I] := Inputs[I]; B[I] := Inputs[I] end;
  if not RunTRPRoutine(Name, Reference, Routine, Expected, B, ExpectedValue, Diagnostics) then
    raise Exception.Create(Name + ' reference ' + Routine + ': ' + Diagnostics);
  if not RunTRPRoutine(Name, Script, Routine, Actual, A, ActualValue, Diagnostics) then
    raise Exception.Create(Name + ' optimized ' + Routine + ': ' + Diagnostics);
  if ActualValue <> ExpectedValue then
    raise Exception.CreateFmt('%s board %d %s result changed: %s vs %s',
      [Name, Board, Routine, ActualValue, ExpectedValue]);
  for I := 0 to High(A) do
    if A[I] <> B[I] then
      raise Exception.CreateFmt('%s board %d %s parameter %d changed', [Name, Board, Routine, I]);
  for I := 1 to MAXBUFFER do
    if Actual.Buffers[I] <> Expected.Buffers[I] then
      raise Exception.CreateFmt('%s board %d %s buffer %d changed', [Name, Board, Routine, I]);
end;

procedure RunSearchOptimizationTests;
const
  CampaignProbe = 'function TestCampaign(Extra: integer; var Source,Target: integer): double;' +
    ' var I: integer; begin Result:=Campaign(Extra,Source,Target);' +
    ' for I:=1 to 42 do if Owned[I] then UBufferSet(200+I,1) else UBufferSet(200+I,0);' +
    ' for I:=1 to 10 do UBufferSet(250+I,Counts[I]);' +
    ' UBufferSet(261,SearchSource); UBufferSet(262,FirstTarget); UBufferSet(263,BestScore); end;';
  GainProbe = 'function TestGain(E: integer): double;' +
    ' var Source,Target: integer; Ignored: double;' +
    ' begin Ignored:=Campaign(0,Source,Target); Result:=Gain(E); end;';
  DecisionProbe = 'procedure TestDecisions(var Placed, FromT, ToT: integer);' +
    ' begin Placement(Placed); Attack(FromT,ToT); end;';
  RouteProbe = 'procedure TestRoutes(var Start, Budget: integer);' +
    ' var P,B,First,Cost,I: integer; Good: boolean;' +
    ' begin I:=10; for P:=0 to 11 do for B:=0 to 3 do begin' +
    ' First:=99; Cost:=99; if B=0 then Cost:=0;' +
    ' if B=0 then Good:=EliminationRoute(Start,P,0,First,Cost)' +
    ' else if B=1 then Good:=EliminationRoute(Start,P,Budget,First,Cost)' +
    ' else if B=2 then Good:=EliminationRoute(Start,P,100,First,Cost)' +
    ' else Good:=EliminationRoute(Start,P,1000,First,Cost);' +
    ' UBufferSet(I,First); UBufferSet(I+1,Cost);' +
    ' if Good then UBufferSet(I+2,1) else UBufferSet(I+2,0); I:=I+3; end; end;';
var
  Lines: TStringList;
  Name, Script, Reference, Raw: string;
  Context: TTRCompContext;
  Params: array of Variant;
  Value, Diagnostics: string;
  Bot, Board, Mutation, T, Start: Integer;
begin
  ComparisonCount := 0;
  SetupTerritories;
  Lines := TStringList.Create;
  try
    for Bot := 0 to 1 do begin
      if Bot = 0 then Name := 'players' + PathDelim + 'counterweight.trp'
      else Name := 'players' + PathDelim + 'challenger.trp';
      Lines.LoadFromFile(Name); Raw := Lines.Text;
      if Bot = 0 then begin
        Reference := ReplaceRoutine(Raw, 'function Gain(', 'procedure Assignment(', CounterReference);
        Script := Inject(Raw, CampaignProbe + GainProbe + DecisionProbe);
        Reference := Inject(Reference, CampaignProbe + GainProbe + DecisionProbe);
      end else begin
        Reference := ReplaceRoutine(Raw, 'function EliminationRoute(', 'function ChooseElimination(', ChallengerRouteReference);
        Reference := ReplaceRoutine(Reference, 'procedure Attack(', 'procedure Occupation(', ChallengerAttackReference);
        Script := Inject(Raw, RouteProbe + DecisionProbe);
        Reference := Inject(Reference, RouteProbe + DecisionProbe);
      end;
      for Board := 0 to 23 do begin
        Initialize(Context, Board);
        for Mutation := 0 to 1 do begin
          if Mutation = 1 then begin
            T := 1 + (Board * 7) mod 42;
            Context.TerritoryOwner[T] := 1;
            Context.TerritoryArmies[T] := 2 + Board * 3;
            Context.TerritoryOwner[1 + T mod 42] := 0;
            Context.Conquest := not Context.Conquest;
            Context.PlayerNewArmies[1] := Context.PlayerNewArmies[1] + 8;
          end;
          Compare(Name, Script, Reference, 'Placement', Context, [0], Board);
          Compare(Name, Script, Reference, 'Attack', Context, [0, 0], Board);
          Compare(Name, Script, Reference, 'Assignment', Context, [0], Board);
          Compare(Name, Script, Reference, 'Occupation', Context, [39, 40, 0], Board);
          Compare(Name, Script, Reference, 'Fortification', Context, [0, 0, 0], Board);
          Compare(Name, Script, Reference, 'TestDecisions', Context, [0, 0, 0], Board);
          if Bot = 0 then begin
            Compare(Name, Script, Reference, 'TestCampaign', Context, [0, 0, 0], Board);
            Compare(Name, Script, Reference, 'TestCampaign', Context, [15, 0, 0], Board);
          end else begin
            Start := 1 + (Board * 7) mod 42;
            Compare(Name, Script, Reference, 'TestRoutes', Context, [Start, 20 + Board], Board);
          end;
        end;
      end;
        if Bot = 0 then begin
          Initialize(Context, 3);
          Context.TerritoryOwner[39] := 1;
          Context.TerritoryOwner[40] := 0;
          Context.TerritoryOwner[41] := 1;
          Context.TerritoryOwner[42] := 0;
          // Campaign excludes neutral captures; keep the actual frozen reference unchanged.
          Compare(Name, Script, Reference, 'TestCampaign', Context, [0, 0, 0], 103);
          Compare(Name, Script, Reference, 'TestCampaign', Context, [15, 0, 0], 103);
          Compare(Name, Script, Reference, 'TestGain', Context, [39], 103);
        end;
        if Bot = 1 then begin
          Initialize(Context, 3);
          for T := 1 to 5 do Context.PlayerActive[T] := True;
          Context.Conquest := True;
          Context.Buffers[1] := 0; Context.Buffers[2] := 0;
          for T := 1 to 42 do begin
            Context.TerritoryOwner[T] := 2 + T mod 4;
            Context.TerritoryArmies[T] := 30;
          end;
          for T := 39 to 41 do Context.TerritoryOwner[T] := 1;
          Context.TerritoryArmies[42] := 1;
          for Mutation := 0 to 1 do begin
            if Mutation = 1 then begin
              Context.TerritoryOwner[42] := 1;
              Context.TerritoryOwner[41] := 2;
              Context.TerritoryArmies[41] := 1;
            end;
            Compare(Name, Script, Reference, 'Attack', Context, [0, 0], 101 + Mutation);
            SetLength(Params, 2); Params[0] := 0; Params[1] := 0;
            if not RunTRPRoutine(Name, Script, 'Attack', Context, Params, Value, Diagnostics) then
              raise Exception.Create('Challenger completion fixture: ' + Diagnostics);
            if Integer(Params[1]) <> 42 - Mutation then
              raise Exception.Create('Challenger completion fixture did not exercise the missing territory');
          end;
          Initialize(Context, 1);
          for T := 1 to 42 do begin
            Context.TerritoryOwner[T] := 3;
            Context.TerritoryArmies[T] := 1;
          end;
          Context.PlayerActive[3] := True;
          Context.TerritoryOwner[39] := 1;
          Context.TerritoryArmies[39] := 50;
          for T := 40 to 42 do Context.TerritoryOwner[T] := 2;
          Compare(Name, Script, Reference, 'TestRoutes', Context, [39, 20], 100);
          SetLength(Params, 2); Params[0] := 39; Params[1] := 20;
          if not RunTRPRoutine(Name, Script, 'TestRoutes', Context, Params, Value, Diagnostics) then
            raise Exception.Create('Challenger route fixture: ' + Diagnostics);
          if (Context.Buffers[43] <> 40) or (Context.Buffers[45] <> 1) then
            raise Exception.Create('Challenger route fixture did not preserve the tied first step');
          if (Context.Buffers[34] <> 0) or (Context.Buffers[36] <> 0) then
            raise Exception.Create('Challenger route fixture did not exercise a budget failure');
          for T := 1 to 42 do Context.TerritoryOwner[T] := 3;
          Context.TerritoryOwner[39] := 1;
          Context.TerritoryOwner[31] := 2; Context.TerritoryOwner[41] := 2;
          Compare(Name, Script, Reference, 'TestRoutes', Context, [39, 20], 102);
          Params[0] := 39; Params[1] := 20;
          if not RunTRPRoutine(Name, Script, 'TestRoutes', Context, Params, Value, Diagnostics) then
            raise Exception.Create('Challenger trail fixture: ' + Diagnostics);
          if (Context.Buffers[43] <> 31) or (Context.Buffers[44] <> 3) or
              (Context.Buffers[45] <> 0) then
            raise Exception.Create('Challenger trail fixture did not exercise a partial-route failure');
      end;
    end;
  finally
    Lines.Free;
  end;
  Writeln('PASS: ', ComparisonCount,
    ' Counterweight and Challenger comparisons match frozen callback and route references.');
end;

end.
