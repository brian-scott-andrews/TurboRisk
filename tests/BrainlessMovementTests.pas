unit BrainlessMovementTests;

{$MODE Delphi}

interface

procedure RunBrainlessMovementTests;

implementation

uses Classes, SysUtils, Variants, Globals, ExpSubr, Territ;

type
  TBoard = array[1..MAXTERRITORIES] of Integer;

const
  // Saved action-log failure states from original-setup replay cases 56, 77, 75, 146.
  Owners: array[0..3] of TBoard = (
    (1,1,2,1,1,1,1,1,1,1,1,1,1,1,1,1,2,2,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1),
    (2,2,2,2,2,3,2,3,2,1,1,1,1,1,1,1,1,1,1,3,3,1,1,1,1,1,3,2,3,3,3,3,2,3,3,3,2,3,3,3,2,3),
    (2,2,2,2,2,2,2,2,2,4,4,2,4,2,1,1,1,1,1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,4,4,4),
    (1,1,1,1,1,1,1,1,1,1,2,1,1,1,1,1,1,2,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,1));
  Armies: array[0..3] of TBoard = (
    (1,1,1,1,1,1,13,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,22,14,1,1,1,1,1,3,1,27,1,1,1,1,2),
    (1,1,1,1,1,1,1,1,1,2,1,1,1,1,6,5,1,1,1,52,1,1,35,1,1,1,10,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1),
    (1,1,3,1,1,1,1,1,1,3,1,3,1,57,1,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,18,27,1,1),
    (1,1,1,1,1,1,1,1,1,1,3,3,1,7,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,3,1,1,1,1,1));
  CurrentPlayer: array[0..3] of Integer = (2,3,2,1);

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then raise Exception.Create(MessageText);
end;

procedure Initialize(out Context: TTRCompContext);
var
  I: Integer;
  Card: TCard;
begin
  Context.CurrentPlayer := 1;
  Context.Conquest := False;
  Context.CardTradeByCombination := False;
  Context.Message := '';
  for I := 1 to MAXTERRITORIES do begin
    Context.TerritoryOwner[I] := 2;
    Context.TerritoryArmies[I] := 1;
  end;
  for I := 1 to MAXPLAYERS do begin
    Context.PlayerActive[I] := I <= 4;
    Context.PlayerName[I] := 'Player ' + IntToStr(I);
    Context.PlayerProgram[I] := 'test.trp';
    Context.PlayerNewArmies[I] := 0;
    for Card := Low(TCard) to High(TCard) do
      Context.PlayerCards[I, Card] := 0;
  end;
  for I := 1 to MAXBUFFER do Context.Buffers[I] := 0;
end;

procedure Execute(const Name, Source, Routine: string;
  var Context: TTRCompContext; var Params: array of Variant);
var
  ReturnValue, Diagnostics: string;
begin
  Check(RunTRPRoutine(Name, Source, Routine, Context, Params,
    ReturnValue, Diagnostics), Name + ' ' + Routine + ': ' + Diagnostics);
end;

procedure CheckFortification(const Name, Source: string;
  var Context: TTRCompContext; ExpectMove: Boolean; ExpectedSource: Integer = 0);
var
  Params: array[0..2] of Variant;
  FT, TT, A: Integer;
begin
  Params[0] := 0; Params[1] := 0; Params[2] := 0;
  Execute(Name, Source, 'Fortification', Context, Params);
  FT := Params[0]; TT := Params[1]; A := Params[2];
  if FT = 0 then begin
    Check((TT = 0) and (A = 0), Name + ': inconsistent no-move output');
    Check(not ExpectMove, Name + ': discarded an available legal fortification');
    Exit;
  end;
  Check((FT >= 1) and (FT <= 42) and (TT >= 1) and (TT <= 42) and
    (FT <> TT), Name + ': invalid fortification territories');
  Check((Context.TerritoryOwner[FT] = Context.CurrentPlayer) and
    (Context.TerritoryOwner[TT] = Context.CurrentPlayer) and TIsBordering(FT, TT),
    Name + ': fortification must join adjacent owned territories');
  Check((A > 0) and (A < Context.TerritoryArmies[FT]),
    Name + ': invalid fortification armies');
  if ExpectedSource > 0 then
    Check(FT = ExpectedSource, Name + ': a stronger invalid candidate hid a legal move');
end;

procedure CheckOccupation(const Name, Source: string;
  var Context: TTRCompContext; FT, TT, Expected: Integer);
var
  Params: array[0..2] of Variant;
begin
  Params[0] := FT; Params[1] := TT; Params[2] := 0;
  Execute(Name, Source, 'Occupation', Context, Params);
  Check(Integer(Params[2]) = Expected, Name + ': wrong occupation amount: ' +
    VarToStr(Params[2]) + ', expected ' + IntToStr(Expected));
  Check((Integer(Params[2]) >= 0) and
    (Integer(Params[2]) < Context.TerritoryArmies[FT]),
    Name + ': occupation must leave at least one source army');
end;

procedure RunBrainlessMovementTests;
var
  Context: TTRCompContext;
  Source: TStringList;
  Name: string;
  Bot, State, I: Integer;
begin
  SetupTerritories;
  Source := TStringList.Create;
  try
    for Bot := 0 to 1 do begin
      if Bot = 0 then Name := 'players' + PathDelim + 'brainless V.trp'
      else Name := 'players' + PathDelim + 'brainless vi.trp';
      Source.LoadFromFile(Name);
      for State := 0 to 3 do begin
        Initialize(Context);
        Context.CurrentPlayer := CurrentPlayer[State];
        Context.Conquest := State <> 0;
        for I := 1 to MAXTERRITORIES do begin
          Context.TerritoryOwner[I] := Owners[State, I];
          Context.TerritoryArmies[I] := Armies[State, I];
        end;
        if State < 2 then
          CheckFortification(Name, Source.Text, Context, False)
        else begin
          if State = 2 then I := 56 else I := 6;
          CheckOccupation(Name, Source.Text, Context, 14, 12, I);
        end;
      end;
      Context.TerritoryArmies[14] := 1;
      CheckOccupation(Name, Source.Text, Context, 14, 12, 0);

      Initialize(Context);
      Context.CurrentPlayer := 2;
      Context.Conquest := True;
      for I := 1 to MAXTERRITORIES do begin
        Context.TerritoryOwner[I] := Owners[2, I];
        Context.TerritoryArmies[I] := Armies[2, I];
      end;
      Context.TerritoryArmies[14] := 100;
      CheckOccupation(Name, Source.Text, Context, 14, 12, 63);

      // Australia: one enemy outside Australia, three inside; desired move is 11.
      Initialize(Context);
      for I := 1 to 42 do Context.TerritoryOwner[I] := 1;
      Context.TerritoryOwner[1] := 2;
      Context.TerritoryOwner[40] := 2;
      Context.TerritoryOwner[41] := 2;
      Context.TerritoryOwner[42] := 2;
      Context.TerritoryArmies[31] := 10;
      CheckOccupation(Name, Source.Text, Context, 31, 39, 9);
      Context.TerritoryArmies[31] := 20;
      CheckOccupation(Name, Source.Text, Context, 31, 39, 11);
      Context.TerritoryArmies[31] := 1;
      CheckOccupation(Name, Source.Text, Context, 31, 39, 0);

      Initialize(Context);
      Context.TerritoryOwner[1] := 1;
      Context.TerritoryOwner[2] := 1;
      Context.TerritoryArmies[1] := 10;
      CheckOccupation(Name, Source.Text, Context, 1, 2, 9);
      Context.TerritoryOwner[3] := 1;
      Context.TerritoryOwner[4] := 1;
      Context.TerritoryOwner[5] := 1;
      CheckOccupation(Name, Source.Text, Context, 1, 2, 0);
      Context.TerritoryOwner[3] := 2;
      Context.TerritoryOwner[4] := 2;
      Context.TerritoryOwner[5] := 2;
      CheckFortification(Name, Source.Text, Context, True);
      Context.Conquest := True;
      Context.TerritoryArmies[2] := 20;
      CheckFortification(Name, Source.Text, Context, True);

      Initialize(Context);
      Context.Conquest := True;
      Context.TerritoryOwner[1] := 1;
      Context.TerritoryOwner[2] := 1;
      Context.TerritoryOwner[3] := 1;
      Context.TerritoryOwner[8] := 1;
      Context.TerritoryArmies[1] := 5;
      Context.TerritoryArmies[3] := 10;
      Context.TerritoryArmies[8] := 8;
      CheckFortification(Name, Source.Text, Context, True, 1);
    end;
  finally
    Source.Free;
  end;
  WriteLn('PASS: Brainless V/VI captured movement failures and legal-move preservation.');
end;

end.
