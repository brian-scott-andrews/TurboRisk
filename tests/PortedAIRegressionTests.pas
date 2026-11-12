unit PortedAIRegressionTests;

{$MODE Delphi}

interface

procedure RunPortedAIRegressionTests;

implementation

uses Classes, SysUtils, Variants, Globals, Territ;

procedure RunPortedAIRegressionTests;
const
  Bots: array[0..8] of string =
    ('defender', 'constant', 'randy', 'slave', 'hunter', 'Walker2',
     'pitbull', 'piranha', 'digger');
var
  Source: TStringList;
  Context: TTRCompContext;
  Params: array of Variant;
  Name, Diagnostics, ReturnValue: string;
  Bot, I, Owned, Selected, Pattern: Integer;

  procedure Initialize;
  var
    I, P: Integer;
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
    for P := 1 to MAXPLAYERS do begin
      Context.PlayerActive[P] := P <= 3;
      Context.PlayerName[P] := 'Player ' + IntToStr(P);
      Context.PlayerProgram[P] := 'simple.trp';
      Context.PlayerNewArmies[P] := 0;
      for Card := Low(TCard) to High(TCard) do
        Context.PlayerCards[P, Card] := 0;
    end;
    for I := 1 to MAXBUFFER do Context.Buffers[I] := 0;
  end;

  procedure Place;
  begin
    SetLength(Params, 1);
    Params[0] := 0;
    if not RunTRPRoutine(Name, Source.Text, 'Placement', Context, Params,
      ReturnValue, Diagnostics) then
      raise Exception.Create(Name + ': ' + Diagnostics);
    Selected := Params[0];
    if (Selected < 1) or (Selected > MAXTERRITORIES) then
      raise Exception.Create(Name + ': invalid placement territory');
    if Context.TerritoryOwner[Selected] <> 1 then
      raise Exception.Create(Name + ': placement not owned');
  end;

begin
  SetupTerritories;
  Source := TStringList.Create;
  try
    for Bot := Low(Bots) to High(Bots) do begin
      Name := 'players' + PathDelim + Bots[Bot] + '.trp';
      Source.LoadFromFile(Name);
      if not ValidateTRPSource(Name, Source.Text, Diagnostics) then
        raise Exception.Create(Name + ': compile failure: ' + Diagnostics);
    end;
    Name := 'players' + PathDelim + 'randy.trp';
    Source.LoadFromFile(Name);
    for Owned := 1 to MAXTERRITORIES do
      for Pattern := 0 to 1 do begin
        Initialize;
        Context.TerritoryOwner[Owned] := 1;
        if Pattern = 1 then
          for I := 1 to MAXTERRITORIES do
            if I <> Owned then Context.TerritoryOwner[I] := 1;
        Place;
      end;
    Name := 'players' + PathDelim + 'slave.trp';
    Source.LoadFromFile(Name);
    Initialize;
    Context.TerritoryOwner[1] := 1;
    Context.TerritoryOwner[2] := 3;
    Context.Buffers[50] := 3;
    Place;
    if Context.Buffers[51] <> 0 then
      raise Exception.Create('Slave prematurely marked its master eliminated');
    Context.TerritoryOwner[2] := 2;
    Place;
    if Context.Buffers[51] <> 1 then
      raise Exception.Create('Slave did not recognize an eliminated master');
    for Bot := 3 to 4 do begin
      Name := 'players' + PathDelim + Bots[Bot] + '.trp';
      Source.LoadFromFile(Name);
      Initialize;
      for I := 1 to MAXTERRITORIES do
        Context.TerritoryOwner[I] := 0;
      // TRComp disables logging; enable it only for this announcement probe.
      I := Pos('PROCEDURE Placement', Source.Text);
      if I = 0 then
        raise Exception.Create('Announcement probe could not insert its wrapper');
      Source.Text := Copy(Source.Text, 1, I - 1) +
        'procedure LoggedAssignment(var T: integer);' + LineEnding +
        'begin ULogOn; Assignment(T); end;' + LineEnding +
        Copy(Source.Text, I, MaxInt);
      SetLength(Params, 1);
      Params[0] := 0;
      if not RunTRPRoutine(Name, Source.Text, 'LoggedAssignment', Context, Params,
        ReturnValue, Diagnostics) then
        raise Exception.Create(Name + ': ' + Diagnostics);
      if Bot = 3 then begin
        if (Context.Buffers[50] < 2) or (Context.Buffers[50] > 3) or
          (Pos('Chosen master: Player ', Diagnostics) = 0) then
          raise Exception.Create('Slave did not select and log its master');
      end
      else if (Context.Buffers[1] < 2) or (Context.Buffers[1] > 3) or
        (Pos('Chosen prey: Player ', Diagnostics) = 0) then
        raise Exception.Create('Hunter did not select and log its prey');
    end;
    WriteLn('PASS: all nine ported bots compile; Randy 84 legal placements;',
      ' Slave recognizes an active player with no remaining territories as eliminated;',
      ' Slave/Hunter select and log their targets.');
  finally
    Source.Free;
  end;
end;

end.
