unit ZotobAttackTests;

{$MODE Delphi}

interface

procedure RunZotobAttackTests;

implementation

uses Classes, SysUtils, Variants, Globals, Territ;

procedure RunZotobAttackTests;
const
  Guard = '  if ToTerritory = 0 then FromTerritory:=0;';
  Strengths: array[0..3] of Integer = (1, 1999, 2000, 2001);
var
  Source: TStringList;
  Original, Name, Diagnostics, ReturnValue: string;
  Context, BeforeGuard, AfterGuard: TTRCompContext;
  Params: array of Variant;
  Mode, Captured, Strength, SourceArmy, I, P, OldFrom, OldTo,
    NewFrom, NewTo, Cases, Cancelled, Attacks: Integer;
  Card: TCard;

  procedure Execute(const Script: string; var State: TTRCompContext;
    out FT, TT: Integer);
  begin
    SetLength(Params, 2);
    Params[0] := 0;
    Params[1] := 0;
    if not RunTRPRoutine(Name, Script, 'Attack', State, Params,
      ReturnValue, Diagnostics) then
      raise Exception.Create('Zotob attack comparison: ' + Diagnostics);
    FT := Params[0];
    TT := Params[1];
  end;

begin
  SetupTerritories;
  Cases := 0;
  Cancelled := 0;
  Attacks := 0;
  Name := 'players' + PathDelim + 'zotob.trp';
  Source := TStringList.Create;
  try
    Source.LoadFromFile(Name);
    if Pos(Guard, Source.Text) = 0 then
      raise Exception.Create('Zotob attack guard is missing');
    Original := StringReplace(Source.Text, Guard, '', []);
    for Mode := 0 to 1 do
      for Captured := 0 to 1 do
        for Strength := Low(Strengths) to High(Strengths) do
          for SourceArmy := 3 to 4 do begin
            Context.CurrentPlayer := 1;
            Context.Conquest := Captured = 1;
            Context.CardTradeByCombination := False;
            Context.Message := '';
            for I := 1 to MAXTERRITORIES do begin
              Context.TerritoryOwner[I] := 2;
              Context.TerritoryArmies[I] := Strengths[Strength];
            end;
            Context.TerritoryOwner[1] := 1;
            Context.TerritoryArmies[1] := SourceArmy;
            Context.TerritoryArmies[2] := 1;
            for P := 1 to MAXPLAYERS do begin
              Context.PlayerActive[P] := P <= 2;
              Context.PlayerName[P] := 'Player ' + IntToStr(P);
              Context.PlayerProgram[P] := 'zotob.trp';
              Context.PlayerNewArmies[P] := 0;
              for Card := Low(TCard) to High(TCard) do
                Context.PlayerCards[P, Card] := 0;
            end;
            for I := 1 to MAXBUFFER do Context.Buffers[I] := 0;
            Context.Buffers[48] := Mode;
            BeforeGuard := Context;
            AfterGuard := Context;
            Execute(Original, BeforeGuard, OldFrom, OldTo);
            Execute(Source.Text, AfterGuard, NewFrom, NewTo);
            Inc(Cases);
            if (OldFrom > 0) and (OldTo = 0) then begin
              Inc(Cancelled);
              if (NewFrom <> 0) or (NewTo <> 0) then
                raise Exception.Create('Zotob did not cancel a targetless attack');
            end
            else if (NewFrom <> OldFrom) or (NewTo <> OldTo) then
              raise Exception.Create('Zotob changed an existing attack decision');
            if (OldFrom > 0) and (OldTo > 0) then Inc(Attacks);
            for I := 1 to MAXBUFFER do
              if BeforeGuard.Buffers[I] <> AfterGuard.Buffers[I] then
                raise Exception.Create('Zotob guard changed a strategy buffer');
            if (Mode = 1) and (Captured = 0) and (SourceArmy = 4) then begin
              if Strengths[Strength] >= 2000 then begin
                if (OldFrom <> 1) or (OldTo <> 0) then
                  raise Exception.Create('Zotob reproduction no longer triggers');
              end
              else if (NewFrom <> 1) or (NewTo <> 2) then
                raise Exception.Create('Zotob positive-score attack changed');
            end;
          end;
    if (Cancelled = 0) or (Attacks = 0) then
      raise Exception.Create('Zotob comparison did not cover attacks and cancellations');
    WriteLn('PASS: Zotob ', Cases, ' paired attack cases; ', Cancelled,
      ' targetless attacks cancelled; ', Attacks,
      ' selected attacks unchanged; strategy buffers unchanged.');
  finally
    Source.Free;
  end;
end;

end.
