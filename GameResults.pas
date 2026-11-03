unit GameResults;

{$MODE Delphi}

interface

uses Classes, SysUtils;

const
  RESULT_COMPLETE = 1;
  RESULT_MAX_PLAYERS = 10;

type
  TResultPlayer = record
    Name: string;
    LastTurn, Army, Territ: integer;
  end;

  TGameResult = record
    GameDate: TDateTime;
    Status, Duration, Turns, PlayerCount: integer;
    HasDetails: boolean;
    Players: array[0..RESULT_MAX_PLAYERS - 1] of TResultPlayer;
  end;

  TGameResults = array of TGameResult;

function ParseGameResult(const Line: string): TGameResult;
function ReadGameResults(const FileName: string): TGameResults;
function HistoryResultLine(const Game: TGameResult): string;
function CompletedHistoryLines(const Games: TGameResults;
  out Skipped: integer): TStringList;

implementation

function ParseGameResult(const Line: string): TGameResult;
var
  Fields: TStringList;
  I, Offset: integer;
  DatePart, TimePart: string;

  function Number(Index: integer): integer;
  begin
    if not TryStrToInt(Fields[Index], Result) or (Result < 0) then
      raise EConvertError.CreateFmt('Invalid non-negative integer in column %d.', [Index + 1]);
  end;

  function Digits(const Value: string; Count: integer): boolean;
  var
    J: integer;
  begin
    Result := Length(Value) = Count;
    for J := 1 to Length(Value) do
      if not (Value[J] in ['0'..'9']) then Result := false;
  end;

begin
  Result := Default(TGameResult);
  Fields := TStringList.Create;
  try
    Fields.StrictDelimiter := true;
    Fields.Delimiter := ',';
    Fields.QuoteChar := #0;
    Fields.DelimitedText := Line;
    if Fields.Count < 4 then
      raise EConvertError.Create('Too few columns for a game result.');
    DatePart := Fields[0];
    if not Digits(DatePart, 8) then
      raise EConvertError.Create('Expected a date in YYYYMMDD format.');
    Result.GameDate := EncodeDate(StrToInt(Copy(DatePart, 1, 4)),
      StrToInt(Copy(DatePart, 5, 2)), StrToInt(Copy(DatePart, 7, 2)));
    Result.HasDetails := Length(Fields[1]) = 6;
    if Result.HasDetails then begin
      if Fields.Count < 6 then
        raise EConvertError.Create('Incomplete simulator result header.');
      TimePart := Fields[1];
      if not Digits(TimePart, 6) then
        raise EConvertError.Create('Expected a time in HHMMSS format.');
      Result.GameDate := Result.GameDate + EncodeTime(StrToInt(Copy(TimePart, 1, 2)),
        StrToInt(Copy(TimePart, 3, 2)), StrToInt(Copy(TimePart, 5, 2)), 0);
      Result.Status := Number(2);
      if Result.Status > 5 then
        raise EConvertError.Create('Unknown simulator ending status.');
      Result.Duration := Number(3);
      Result.Turns := Number(4);
      Result.PlayerCount := Number(5);
      Offset := 6;
      if Fields.Count <> Offset + 4 * Result.PlayerCount then
        raise EConvertError.Create('Simulator player count does not match the columns.');
    end else begin
      Result.Status := RESULT_COMPLETE;
      Result.Duration := -1;
      Result.Turns := -1;
      Result.PlayerCount := Number(1);
      Offset := 2;
      if Fields.Count <> Offset + Result.PlayerCount then
        raise EConvertError.Create('History player count does not match the columns.');
    end;
    if (Result.PlayerCount < 2) or (Result.PlayerCount > RESULT_MAX_PLAYERS) then
      raise EConvertError.Create('Player count must be between 2 and 10.');
    for I := 0 to Result.PlayerCount - 1 do begin
      Result.Players[I].Name := Fields[Offset];
      if Trim(Result.Players[I].Name) = '' then
        raise EConvertError.Create('Player name must not be empty.');
      if Result.HasDetails then begin
        Result.Players[I].LastTurn := Number(Offset + 1);
        Result.Players[I].Army := Number(Offset + 2);
        Result.Players[I].Territ := Number(Offset + 3);
        Inc(Offset, 4);
      end else begin
        Result.Players[I].LastTurn := -1;
        Result.Players[I].Army := -1;
        Result.Players[I].Territ := -1;
        Inc(Offset);
      end;
    end;
  finally
    Fields.Free;
  end;
end;

function ReadGameResults(const FileName: string): TGameResults;
var
  Lines: TStringList;
  I, Count: integer;
begin
  Result := nil;
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FileName);
    SetLength(Result, Lines.Count);
    Count := 0;
    for I := 0 to Lines.Count - 1 do begin
      if Trim(Lines[I]) = '' then Continue;
      try
        Result[Count] := ParseGameResult(Lines[I]);
      except
        on E: EConvertError do
          raise EConvertError.CreateFmt('%s, line %d: %s', [FileName, I + 1, E.Message]);
      end;
      Inc(Count);
    end;
    SetLength(Result, Count);
  finally
    Lines.Free;
  end;
end;

function HistoryResultLine(const Game: TGameResult): string;
var
  I: integer;
begin
  if Game.Status <> RESULT_COMPLETE then
    raise EConvertError.Create('Only completed games have a history finishing order.');
  Result := FormatDateTime('yyyymmdd', Game.GameDate) + ',' + IntToStr(Game.PlayerCount);
  for I := 0 to Game.PlayerCount - 1 do
    Result := Result + ',' + Game.Players[I].Name;
end;

function CompletedHistoryLines(const Games: TGameResults;
  out Skipped: integer): TStringList;
var
  I: integer;
begin
  Result := TStringList.Create;
  Skipped := 0;
  try
    for I := 0 to High(Games) do
      if Games[I].Status = RESULT_COMPLETE then
        Result.Add(HistoryResultLine(Games[I]))
      else
        Inc(Skipped);
  except
    Result.Free;
    raise;
  end;
end;

end.
