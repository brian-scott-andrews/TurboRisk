unit TectonicPlacementTests;

{$MODE Delphi}

interface

procedure RunTectonicPlacementTests;

implementation

uses Classes, SysUtils, Variants, Globals, Territ;

procedure RunTectonicPlacementTests;
const
  EnemyStrengths: array[0..2] of Integer = (1, 10000, 10001);
var
  Source: TStringList;
  Context: TTRCompContext;
  Params: array of Variant;
  Name, Diagnostics, ReturnValue: string;
  T, P, Owned, Mode, Strength, Selected, Cases: Integer;
  Card: TCard;

  procedure CheckPlacement;
  begin
    SetLength(Params, 1);
    Params[0] := 0;
    if not RunTRPRoutine(Name, Source.Text, 'Placement', Context, Params,
      ReturnValue, Diagnostics) then
      raise Exception.Create('Tectonic placement: ' + Diagnostics);
    Selected := Params[0];
    if (Selected < 1) or (Selected > MAXTERRITORIES) then
      raise Exception.Create('Tectonic returned an out-of-range placement');
    if Context.TerritoryOwner[Selected] <> Context.CurrentPlayer then
      raise Exception.Create('Tectonic placed on an unowned territory');
    Inc(Cases);
  end;

begin
  SetupTerritories;
  Cases := 0;
  Name := 'players' + PathDelim + 'Tectonic.trp';
  Source := TStringList.Create;
  try
    Source.LoadFromFile(Name);
    Context.CurrentPlayer := 1;
    Context.Conquest := False;
    Context.CardTradeByCombination := False;
    Context.Message := '';
    for P := 1 to MAXPLAYERS do begin
      Context.PlayerActive[P] := P <= 2;
      Context.PlayerName[P] := 'Player ' + IntToStr(P);
      Context.PlayerProgram[P] := 'Tectonic.trp';
      Context.PlayerNewArmies[P] := 0;
      for Card := Low(TCard) to High(TCard) do
        Context.PlayerCards[P, Card] := 0;
    end;
    for Owned := 1 to MAXTERRITORIES do
      for Mode := 0 to 2 do
        for Strength := Low(EnemyStrengths) to High(EnemyStrengths) do begin
          for T := 1 to MAXTERRITORIES do begin
            Context.TerritoryOwner[T] := 2;
            Context.TerritoryArmies[T] := EnemyStrengths[Strength];
          end;
          Context.TerritoryOwner[Owned] := 1;
          Context.TerritoryArmies[Owned] := 1;
          for T := 1 to MAXBUFFER do Context.Buffers[T] := 0;
          Context.Buffers[401] := Mode;
          CheckPlacement;
          if Selected <> Owned then
            raise Exception.Create('Tectonic did not reinforce its sole territory');
        end;
    WriteLn('PASS: Tectonic ', Cases,
      ' placement cases across every territory, all three strategy modes,',
      ' and enemy strengths 1/10000/10001.');
  finally
    Source.Free;
  end;
end;

end.
