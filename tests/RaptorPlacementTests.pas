unit RaptorPlacementTests;

{$MODE Delphi}

interface

procedure RunRaptorPlacementTests;

implementation

uses Classes, SysUtils, Variants, Globals, Territ;

procedure RunRaptorPlacementTests;
const
  Owners: array[1..42] of Integer =
    (4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,
     4,4,4,6,6,1,6,4,4,4,4,4,1,1,1,1);
  Armies: array[1..42] of Integer =
    (1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
     1602,3975,273,28640,3,53745,36119,5454,1,2180,2183,2186,1,1,1,1);
  Strengths: array[0..3] of Integer = (1,1000,100000,100001);
var
  Source: TStringList;
  Context: TTRCompContext;
  Params: array of Variant;
  Original, Diagnostics, ReturnValue: string;
  T, P, Owned, Strength, Selected, Previous, Cases: Integer;
  Card: TCard;

  function Place(const Script: string): Integer;
  begin
    SetLength(Params,1);
    Params[0] := 0;
    if not RunTRPRoutine('raptorbot.trp',Script,'Placement',Context,
      Params,ReturnValue,Diagnostics) then
      raise Exception.Create('Raptorbot placement: ' + Diagnostics);
    Result := Params[0];
  end;

  procedure Check;
  begin
    Selected := Place(Source.Text);
    if (Selected < 1) or (Selected > MAXTERRITORIES) then
      raise Exception.Create('Raptorbot returned invalid placement');
    if Context.TerritoryOwner[Selected] <> Context.CurrentPlayer then
      raise Exception.Create('Raptorbot placed on an unowned territory');
    Inc(Cases);
  end;

begin
  SetupTerritories;
  Cases := 0;
  Source := TStringList.Create;
  try
    Source.LoadFromFile('players' + PathDelim + 'raptorbot.trp');
    Original := StringReplace(Source.Text,
      '(ToTerritory = 0) or (z > highest)', '(z > highest)', []);
    if Original = Source.Text then raise Exception.Create('Missing selection correction');
    Context.CurrentPlayer := 4;
    Context.Conquest := False;
    Context.CardTradeByCombination := False;
    Context.Message := '';
    for P := 1 to MAXPLAYERS do begin
      Context.PlayerActive[P] := P <= 6;
      Context.PlayerName[P] := 'Player ' + IntToStr(P);
      Context.PlayerProgram[P] := 'raptorbot.trp';
      Context.PlayerNewArmies[P] := 0;
      for Card := Low(TCard) to High(TCard) do Context.PlayerCards[P,Card] := 0;
    end;
    Context.PlayerNewArmies[4] := 26;
    for T := 1 to MAXBUFFER do Context.Buffers[T] := 0;
    for T := 1 to MAXTERRITORIES do begin
      Context.TerritoryOwner[T] := Owners[T];
      Context.TerritoryArmies[T] := Armies[T];
    end;
    if Place(Original) <> 0 then raise Exception.Create('Saved failure not reproduced');
    Check;
    if Selected <> 29 then raise Exception.Create('Saved board did not select best front');
    for Owned := 1 to MAXTERRITORIES do
      for Strength := Low(Strengths) to High(Strengths) do begin
        for T := 1 to MAXTERRITORIES do begin
          Context.TerritoryOwner[T] := 2;
          Context.TerritoryArmies[T] := Strengths[Strength];
        end;
        Context.TerritoryOwner[Owned] := 4;
        Context.TerritoryArmies[Owned] := 1;
        for T := 1 to MAXBUFFER do Context.Buffers[T] := 0;
        if Strength = 0 then begin
          Previous := Place(Original);
          for T := 1 to MAXBUFFER do Context.Buffers[T] := 0;
          Check;
          if Selected <> Previous then raise Exception.Create('Ordinary selection changed');
        end else Check;
        Context.Buffers[1] := Owned;
        Check;
      end;
    WriteLn('PASS: Raptorbot saved failure and ',Cases,
      ' legal placements across all territories, extreme armies and cached destinations.');
  finally
    Source.Free;
  end;
end;

end.
