unit BrainlessRouteTests;
{$MODE Delphi}
interface
procedure RunBrainlessRouteTests;
implementation
uses Classes, SysUtils, Variants, Globals, Territ;

procedure RunBrainlessRouteTests;
var
  Context: TTRCompContext;
  Source: TStringList;
  Params: array of Variant;
  Name, Diagnostics, ReturnValue: string;
  I, P, StartArmy, Expected: Integer;
  Card: TCard;
begin
  SetupTerritories;
  Name := 'players' + PathDelim + 'brainless vi.trp';
  Source := TStringList.Create;
  try
    Source.LoadFromFile(Name);
    Context.CurrentPlayer := 1;
    Context.Conquest := True;
    Context.CardTradeByCombination := False;
    Context.Message := '';
    for I := 1 to MAXTERRITORIES do begin
      Context.TerritoryOwner[I] := 2;
      Context.TerritoryArmies[I] := 100;
    end;
    Context.TerritoryOwner[1] := 1;
    Context.TerritoryOwner[5] := 3;
    Context.TerritoryArmies[5] := 1;
    Context.TerritoryArmies[2] := 1;
    Context.TerritoryArmies[4] := 10;
    for P := 1 to MAXPLAYERS do begin
      Context.PlayerActive[P] := P <= 3;
      Context.PlayerName[P] := 'Player ' + IntToStr(P);
      Context.PlayerProgram[P] := 'test.trp';
      Context.PlayerNewArmies[P] := 0;
      for Card := Low(TCard) to High(TCard) do
        Context.PlayerCards[P, Card] := 0;
    end;
    for I := 1 to MAXBUFFER do Context.Buffers[I] := 0;
    for StartArmy := 4 to 5 do begin
      Context.TerritoryArmies[1] := StartArmy;
      SetLength(Params, 2);
      Params[0] := 1;
      Params[1] := -1;
      if not RunTRPRoutine(Name, Source.Text, 'FindEliminationRoute',
        Context, Params, ReturnValue, Diagnostics) then
        raise Exception.Create(Diagnostics);
      if StartArmy = 4 then Expected := 0 else Expected := 2;
      if Integer(Params[1]) <> Expected then
        raise Exception.Create('VI route budget/cheapest first step mismatch');
      if (ReturnValue = 'True') <> (Expected > 0) then
        raise Exception.Create('VI route success mismatch');
    end;
    Context.TerritoryOwner[2] := 1;
    Context.TerritoryOwner[4] := 1;
    Context.TerritoryOwner[37] := 1;
    Params[0] := 1;
    Params[1] := -1;
    if not RunTRPRoutine(Name, Source.Text, 'FindEliminationRoute',
      Context, Params, ReturnValue, Diagnostics) then
      raise Exception.Create(Diagnostics);
    if (ReturnValue <> 'False') or (Integer(Params[1]) <> 0) then
      raise Exception.Create('VI routed through owned territories');
    WriteLn('PASS: VI weighted route first step, strict army budget, and blocked route.');
  finally
    Source.Free;
  end;
end;
end.
