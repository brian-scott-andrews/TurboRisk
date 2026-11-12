unit ErasorMovementTests;

{$MODE Delphi}

interface

procedure RunErasorMovementTests;

implementation

uses Classes, SysUtils, Variants, Globals, Territ;

procedure RunErasorMovementTests;
var
  Context: TTRCompContext;
  Source: TStringList;
  Name: string;
  I, Enemy, Strength: Integer;

  procedure Initialize;
  var
    T, P, B: Integer;
    Card: TCard;
  begin
    Context.CurrentPlayer := 1;
    Context.Conquest := True;
    Context.CardTradeByCombination := False;
    Context.Message := '';
    for T := 1 to MAXTERRITORIES do begin
      Context.TerritoryOwner[T] := 2;
      Context.TerritoryArmies[T] := 1;
    end;
    Context.TerritoryOwner[1] := 1;
    Context.TerritoryOwner[2] := 1;
    for P := 1 to MAXPLAYERS do begin
      Context.PlayerActive[P] := P <= 2;
      Context.PlayerName[P] := 'Player ' + IntToStr(P);
      Context.PlayerProgram[P] := 'test.trp';
      Context.PlayerNewArmies[P] := 0;
      for Card := Low(TCard) to High(TCard) do
        Context.PlayerCards[P, Card] := 0;
    end;
    for B := 1 to MAXBUFFER do Context.Buffers[B] := 0;
  end;

  procedure CheckMove(const Scenario: string; FromArmy, ToArmy, Expected: Integer;
    FT: Integer = 1; TT: Integer = 2);
  var
    Params: array[0..2] of Variant;
    ReturnValue, Diagnostics: string;
    Amount: Integer;
  begin
    Context.TerritoryArmies[FT] := FromArmy;
    Context.TerritoryArmies[TT] := ToArmy;
    Params[0] := FT;
    Params[1] := TT;
    Params[2] := 0;
    if not RunTRPRoutine(Name, Source.Text, 'Occupation', Context, Params,
      ReturnValue, Diagnostics) then
      raise Exception.Create(Scenario + ': ' + Diagnostics);
    Amount := Params[2];
    if Amount <> Expected then
      raise Exception.CreateFmt('%s: returned %d, expected %d',
        [Scenario, Amount, Expected]);
    if (Amount < 0) or (Amount >= FromArmy) then
      raise Exception.Create(Scenario + ': illegal additional occupation');
  end;

begin
  SetupTerritories;
  Name := 'players' + PathDelim + 'era$or-bot.trp';
  Source := TStringList.Create;
  try
    Source.LoadFromFile(Name);
    Initialize;
    CheckMove('Both fronts, one-army source', 1, 1, 0);
    CheckMove('Both fronts, one-army destination', 4, 1, 3);
    CheckMove('Both fronts, existing legal transfer', 4, 3, 3);
    CheckMove('Both fronts, preserve original distribution', 10, 4, 8);
    CheckMove('Both fronts, no negative transfer', 2, 10, 0);

    // Only the source is a front; enemy ID must not affect equal-strength boards.
    for Enemy := 0 to 1 do begin
      for Strength := 1 to 3 do begin
        Initialize;
        for I := 1 to MAXTERRITORIES do Context.TerritoryOwner[I] := 1;
        if Enemy = 0 then I := 3 else I := 5;
        Context.TerritoryOwner[I] := 2;
        Context.TerritoryArmies[I] := Strength * 2;
        if Strength = 1 then
          CheckMove('Source front, weaker enemy', 4, 3, 2, 2, 1)
        else if Strength = 2 then
          CheckMove('Source front, equal enemy', 4, 3, 0, 2, 1)
        else
          CheckMove('Source front, stronger enemy', 4, 3, 1, 2, 1);
        CheckMove('Source front, one-army source', 1, 1, 0, 2, 1);
      end;
    end;

    Initialize;
    for I := 1 to MAXTERRITORIES do Context.TerritoryOwner[I] := 1;
    CheckMove('Neither front, one-army source', 1, 1, 0);
    CheckMove('Neither front, two-army source', 2, 1, 0);
    CheckMove('Neither front, preserve two-army reserve', 6, 1, 4);

    Initialize;
    Context.TerritoryOwner[4] := 1;
    Context.TerritoryOwner[37] := 1;
    CheckMove('Destination-only front', 6, 3, 4);
  finally
    Source.Free;
  end;
  WriteLn('PASS: Era$or-bot occupation bounds and enemy-strength decisions.');
end;

end.
