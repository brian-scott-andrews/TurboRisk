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
    out FT, TT: Integer); forward;

  procedure CompareStaleTargetFix;
  var
    OldState, NewState, Board: TTRCompContext;
    Trial, T, Player, Target, VariantIndex, OldFT, OldTT, NewFT, NewTT,
      Total, Same, LegalChanges, StopChanges, InvalidChanges, BufferChanges,
      OldAttacks, OldStops: Integer;
    SavedSeed: LongInt;
    PlacementParams: array[0..0] of Variant;

    function LegalAttack(const State: TTRCompContext; FT, TT: Integer): Boolean;
    begin
      Result := False;
      if (FT < 1) or (FT > MAXTERRITORIES) or
        (TT < 1) or (TT > MAXTERRITORIES) then Exit;
      Result := (State.TerritoryOwner[FT] = State.CurrentPlayer) and
        (State.TerritoryOwner[TT] <> State.CurrentPlayer) and
        (State.TerritoryArmies[FT] > 1) and Confinante(FT, TT);
    end;

    procedure Compare;
    var
      B: Integer;
    begin
      OldState := Board;
      NewState := Board;
      RandSeed := 12345;
      Execute(Original, OldState, OldFT, OldTT);
      RandSeed := 12345;
      Execute(Source.Text, NewState, NewFT, NewTT);
      Inc(Total);
      if LegalAttack(Board, OldFT, OldTT) then Inc(OldAttacks);
      if OldFT = 0 then Inc(OldStops);
      if (OldFT = NewFT) and (OldTT = NewTT) then Inc(Same)
      else begin
        if OldFT = 0 then Inc(StopChanges)
        else if LegalAttack(Board, OldFT, OldTT) then Inc(LegalChanges)
        else Inc(InvalidChanges);
        if (OldFT = 0) or LegalAttack(Board, OldFT, OldTT) then
          WriteLn('Zotob differential case ', Total, ': old ', OldFT, ' -> ',
            OldTT, '; new ', NewFT, ' -> ', NewTT);
        if (NewFT <> 0) and not LegalAttack(Board, NewFT, NewTT) then
          raise Exception.Create('Zotob correction introduced an invalid attack');
      end;
      for B := 1 to MAXBUFFER do
        if OldState.Buffers[B] <> NewState.Buffers[B] then begin
          Inc(BufferChanges);
          Break;
        end;
    end;

  begin
    Total := 0;
    Same := 0;
    LegalChanges := 0;
    StopChanges := 0;
    InvalidChanges := 0;
    BufferChanges := 0;
    OldAttacks := 0;
    OldStops := 0;
    SavedSeed := RandSeed;
    try
      Board := Context;
      for Player := 1 to MAXPLAYERS do
        Board.PlayerProgram[Player] := 'opponent-' + IntToStr(Player);
      Board.PlayerProgram[1] := 'zotob.trp';
      // Placement supplies realistic strategy buffers on reproducible boards.
      for Trial := 1 to 128 do begin
        RandSeed := Trial * 7919;
        Board.Conquest := Odd(Trial);
        Board.CardTradeByCombination := (Trial mod 3) = 0;
        for Player := 1 to MAXPLAYERS do begin
          Board.PlayerActive[Player] := Player <= 2 + Trial mod 9;
          Board.PlayerNewArmies[Player] := 5;
        end;
        for T := 1 to MAXTERRITORIES do begin
          Board.TerritoryOwner[T] := 1 + Random(2 + Trial mod 9);
          Board.TerritoryArmies[T] := 1 + Random(40);
          if (Trial mod 4 = 0) and (Random(8) = 0) then
            Board.TerritoryArmies[T] := 1000 + Random(1500);
        end;
        Board.TerritoryOwner[1] := 1;
        Board.TerritoryOwner[2] := 2;
        for T := 1 to MAXBUFFER do Board.Buffers[T] := 0;
        Board.Buffers[48] := Trial mod 2;
        PlacementParams[0] := 0;
        if not RunTRPRoutine(Name, Original, 'Placement', Board,
          PlacementParams, ReturnValue, Diagnostics) then
          raise Exception.Create('Zotob differential placement: ' + Diagnostics);
        Compare;
      end;
      // Stress stale targets and the D=1000 sentinel for every enemy location.
      for Target := 1 to MAXTERRITORIES do
        for VariantIndex := 0 to 7 do begin
          for T := 1 to MAXTERRITORIES do begin
            Board.TerritoryOwner[T] := 1;
            Board.TerritoryArmies[T] := 1;
          end;
          Board.TerritoryOwner[Target] := 2;
          Board.TerritoryArmies[Target] := 100;
          Board.TerritoryArmies[41] := 2000;
          Board.Conquest := (VariantIndex and 1) <> 0;
          for T := 1 to MAXBUFFER do Board.Buffers[T] := 0;
          Board.Buffers[48] := 1;
          if (VariantIndex and 2) <> 0 then Board.Buffers[49] := 2;
          if (VariantIndex and 4) <> 0 then
            Board.Buffers[Target] := 1000;
          Compare;
        end;
      WriteLn('Zotob stale-target differential: ', Total, ' paired boards; ',
        Same, ' identical; ', LegalChanges, ' changed legal attacks; ',
        StopChanges, ' changed stops; ', InvalidChanges,
        ' changed invalid attacks; ', BufferChanges, ' changed buffer sets; ',
        OldAttacks, ' old legal attacks; ', OldStops, ' old stops.');
      if BufferChanges <> 0 then
        raise Exception.Create('Zotob stale-target fix changed strategy buffers');
      if (LegalChanges <> 0) or (StopChanges <> 0) then
        raise Exception.Create('Zotob stale-target fix changed a legal decision');
      if (OldAttacks = 0) or (OldStops = 0) or (InvalidChanges = 0) then
        raise Exception.Create('Zotob differential comparison lacks coverage');
    finally
      RandSeed := SavedSeed;
    end;
  end;

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
    for I := 1 to MAXTERRITORIES do begin
      Context.TerritoryOwner[I] := 1;
      Context.TerritoryArmies[I] := 1;
    end;
    Context.TerritoryOwner[36] := 2;
    Context.TerritoryArmies[36] := 100;
    Context.TerritoryArmies[41] := 2000;
    Context.Conquest := True;
    for I := 1 to MAXBUFFER do Context.Buffers[I] := 0;
    Context.Buffers[48] := 1;
    Original := StringReplace(Source.Text, '      TA:=0;', '', []);
    Original := StringReplace(Original, ' and (TA>0)', '', [rfReplaceAll]);
    BeforeGuard := Context;
    AfterGuard := Context;
    Execute(Original, BeforeGuard, OldFrom, OldTo);
    if (OldFrom <> 41) or (OldTo <> 36) then
      raise Exception.Create('Zotob stale-target reproduction did not trigger');
    Execute(Source.Text, AfterGuard, NewFrom, NewTo);
    if NewFrom <> 0 then
      raise Exception.Create('Zotob selected an interior source with a stale target');
    WriteLn('PASS: Zotob stale 41 -> 36 target reproduced without fix and rejected with fix.');
    CompareStaleTargetFix;
    WriteLn('PASS: Zotob ', Cases, ' paired attack cases; ', Cancelled,
      ' targetless attacks cancelled; ', Attacks,
      ' selected attacks unchanged; strategy buffers unchanged.');
  finally
    Source.Free;
  end;
end;

end.
