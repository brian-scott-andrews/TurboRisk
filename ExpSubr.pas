unit ExpSubr;

// Routines rese disponibili all'interprete

interface

function TName(T: integer): string;
function TOwner(T: integer): integer;
function TArmies(T: integer): integer;
function TContinent(T: integer): integer;
function TBordersCount(T: integer): integer;
function TBorder(T, B: integer): integer;
function TIsBordering(T1, T2: integer): boolean;
function TIsFront(T: integer): boolean;
function TIsMine(T: integer): boolean;
function TIsEntry(T: integer): boolean;
function TFrontsCount(T: integer): integer;
function TFront(T, F: integer): integer;
function TStrongestFront(T: integer; var ET, EA: integer): boolean;
function TWeakestFront(T: integer; var ET, EA: integer): boolean;
function TPressure(T: integer): integer;
function TDistance(ST, DT: integer): integer;
function TShortestPath(ST, DT: integer; var TT, PL: integer): boolean;
function TWeakestPath(ST, DT: integer; var TT, PL, EA: integer): boolean;
function TPathToFront(T: integer): integer;
function PMe: integer;
function PName(P: integer): string;
function PProgram(P: integer): string;
function PActive(P: integer): boolean;
function PAlive(P: integer): boolean;
function PHuman(P: integer): boolean;
function PArmiesCount(P: integer): integer;
function PNewArmies(P: integer): integer;
function PTerritoriesCount(P: integer): integer;
function PCardCount(P: integer): integer;
function PCardTurnInValue(P: integer): integer;
function COwner(C: integer): integer;
function CBonus(C: integer): integer;
function CTerritoriesCount(C: integer): integer;
function CTerritory(C, T: integer): integer;
function CBordersCount(C: integer): integer;
function CBorder(C, B: integer): integer;
function CEntriesCount(C: integer): integer;
function CEntry(C, B: integer): integer;
function CAnalysis(C: integer; var PT, PA, ET, EA: integer): boolean;
function CLeader(C: integer; var P, T, A: integer): boolean;
function SConquest: boolean;
function SPlayersCount: integer;
function SAlivePlayersCount: integer;
function SCardsBasedOnCombo: boolean;
procedure UMessage(M: string);
procedure ULog(M: string);
procedure UBufferSet(B: integer; V: double);
function UBufferGet(B: integer): double;
function URandom(R: integer): double;
procedure UTakeSnapshot(M: string);
function UDialog(M, B: string): integer;
procedure UAbortGame;
procedure ULogOff;
procedure ULogOn;
procedure UMessageOff;
procedure UMessageOn;
procedure UDialogOff;
procedure UDialogOn;
procedure USnapShotOff;
procedure USnapShotOn;

implementation

uses Clipbrd, SysUtils, Classes, Dialogs, Globals, Territ, Log, Stats, UDialog;

type
  TPrioCont = array [0 .. 5] of record // Lista priorità conquista continenti
  Cont: TContId;
Valore :
double;
end;

// ************************
// * ROUTINES "TERRITORY" *
// ************************

function TName(T: integer): string;
// returns the name of territory T, '?' if T is out of range
begin
  if (T > 0) and (T <= MAXTERRITORIES) then
    result := arTerritory[T].Name
  else
    result := '?';
end;

function TOwner(T: integer): integer;
// returns the owner of territory T, 0 if T is unassigned, -1 if T is out of range
begin
  if (T > 0) and (T <= MAXTERRITORIES) then
    result := arTerritory[T].Owner
  else
    result := -1;
end;

function TArmies(T: integer): integer;
// returns the number of armies on territory T, 0 if T is unassigned, -1 if T is out of range
begin
  if (T > 0) and (T <= MAXTERRITORIES) then
    result := arTerritory[T].Army
  else
    result := -1;
end;

function TContinent(T: integer): integer;
// returns the ID of the continent which territory T belongs to, -1 if T is out of range
begin
  if (T > 0) and (T <= MAXTERRITORIES) then
    result := ord(arTerritory[T].Contin) + 1
  else
    result := -1;
end;

function TBordersCount(T: integer): integer;
// returns the number of borders of territory T (max 6), -1 if T is out of range
begin
  if (T > 0) and (T <= MAXTERRITORIES) then
    result := arTerritory[T].NBord
  else
    result := -1;
end;

function TBorder(T, B: integer): integer;
// returns bordering territory #B of territory T, -1 if T or B are out of range
begin
  if (T > 0) and (T <= MAXTERRITORIES) and (B > 0) and
  (B <= arTerritory[T].NBord) then
    result := arTerritory[T].Bord[B]
  else
    result := -1;
end;

function TIsBordering(T1, T2: integer): boolean;
// returns true if territory T1 is bordering on territory T2, false if not or T or B are out of range
begin
  if (T1 > 0) and (T1 <= MAXTERRITORIES) and (T2 > 0) and
  (T2 <= MAXTERRITORIES) then
    result := Confinante(T1, T2)
  else
    result := false;
end;

function TIsFront(T: integer): boolean;
// returns true if territory T is owned by current player and has at least one bordering
// territory occupied by opponents, false if not or T is out of range
begin
  if (T > 0) and (T <= MAXTERRITORIES) then
    result := Confine(T)
  else
    result := false;
end;

function TIsMine(T: integer): boolean;
// returns true if territory T is owned by current player,
// false if not or T is out of range
begin
  if (T > 0) and (T <= MAXTERRITORIES) then
    result := (arTerritory[T].Owner = iTurn)
  else
    result := false;
end;

function TIsEntry(T: integer): boolean;
// returns true if territory T is an Entry Territory
// Entry territories are territories which are part of a continent but
// may be accessed from another continent
begin
  if T in [1, 3, 9, 10, 12, 14, 15, 16, 20, 22, 25 .. 29, 31, 37, 39] then
    result := true
  else
    result := false;
end;

function TFrontsCount(T: integer): integer;
// returns the number of territories bordering on territory T which are occupied
// by opponents, -1 if T is out of range
var
  C, F: integer;
begin
  if (T > 0) and (T <= MAXTERRITORIES) then begin
    F := 0;
    for C := 1 to arTerritory[T].NBord do begin
      if arTerritory[arTerritory[T].Bord[C]].Owner <> iTurn then begin
        inc(F);
      end;
    end;
    result := F;
  end
  else
    result := -1;
end;

function TFront(T, F: integer): integer;
// returns bordering enemy territory #F of territory T, -1 if T or F are out of range
var
  C, F2: integer;
begin
  if (T > 0) and (T <= MAXTERRITORIES) then begin
    F2 := 0;
    for C := 1 to arTerritory[T].NBord do begin
      if arTerritory[arTerritory[T].Bord[C]].Owner <> iTurn then begin
        inc(F2);
        if F2 = F then begin
          result := arTerritory[T].Bord[C];
          exit;
        end;
      end;
    end;
    result := -1;
  end
  else
    result := -1;
end;

function TStrongestFront(T: integer; var ET, EA: integer): boolean;
// returns false if T is out of range, otherwise true
// the "var" variables will contain information on territory T:
// ET: number of the strongest enemy's territory bordering on T, 0 if T has not fronts
// EA: enemy's armies on territory ET
// (unassigned territories are not counted)
var
  C: integer;
begin
  if (T > 0) and (T <= MAXTERRITORIES) then begin
    ET := 0;
    EA := 0;
    for C := 1 to arTerritory[T].NBord do begin
      if arTerritory[arTerritory[T].Bord[C]].Owner <> iTurn then begin
        if arTerritory[arTerritory[T].Bord[C]].Army > EA then begin
          ET := arTerritory[T].Bord[C];
          EA := arTerritory[ET].Army;
        end;
      end;
    end;
    result := true;
  end
  else
    result := false;
end;

function TWeakestFront(T: integer; var ET, EA: integer): boolean;
// returns false if T is out of range, otherwise true
// the "var" variables will contain information on territory T:
// ET: number of the weakest enemy's territory bordering on T, 0 if T has not fronts
// EA: enemy's armies on territory ET
// (unassigned territories are not counted)
var
  C: integer;
begin
  if (T > 0) and (T <= MAXTERRITORIES) then begin
    ET := 0;
    EA := MaxInt;
    for C := 1 to arTerritory[T].NBord do begin
      if arTerritory[arTerritory[T].Bord[C]].Owner <> iTurn then begin
        if arTerritory[arTerritory[T].Bord[C]].Army < EA then begin
          ET := arTerritory[T].Bord[C];
          EA := arTerritory[ET].Army;
        end;
      end;
    end;
    if ET = 0 then
      EA := 0;
    result := true;
  end
  else
    result := false;
end;

function TPressure(T: integer): integer;
// returns the total number of enemy armies bordering on territory T, -1 if T is out of range
var
  C: integer;
begin
  if (T > 0) and (T <= MAXTERRITORIES) then begin
    result := 0;
    for C := 1 to arTerritory[T].NBord do begin
      if arTerritory[arTerritory[T].Bord[C]].Owner <> iTurn then begin
        result := result + arTerritory[arTerritory[T].Bord[C]].Army;
      end;
    end;
  end
  else
    result := -1;
end;

function TPath(const iFrom, iTo: integer; const bAvoidOwned, bUseOwned,
  bArmies: boolean; var iLength, iCost: integer; var aPath: array of integer)
: boolean;
{
  TPath: Finds best path using Dijkstra's algorithm. Not released to TRPs, just for inner use
  iFrom:       initial territory
  iTo:         destination territory
  bAvoidOwned: set this to true to make path avoid territories owned by current player
  bUseOwned:   set this to true to make path move only along territories owned by current player
  bArmies:     if true, TPath will use armies as "distance", otherwise 1 for each territory
  iLength:     returns the length of the Path, -1 if the path does not exists
  iCost:       returns the cost of the path (if bArmies = total armies to defeat,
  else the length of the path);
  aPath:       returns the path: a 1-based array of territory numbers,
  from iFrom (excluded) to iTo (included)
  returns true if the path exists, false if not
}
var
  i, iNode, iChild, iCostFromStart: integer;
  bFound, bIsOpen, bIsClosed: boolean;
  lstOpen: TList; // OPEN list (FIFO)
  aNode: array [1 .. MAXTERRITORIES] of record bClosed: boolean;
  // node is in the CLOSED list
  iParent: integer; // previous node in the optimal path
  iCostFromStart: integer; // cost to arrive to this node
end;

begin
  // initialize
  lstOpen := TList.Create;
  for i := 1 to MAXTERRITORIES do
    aNode[i].bClosed := false;
  // start node
  aNode[iFrom].iParent := 0;
  aNode[iFrom].iCostFromStart := 0;
  lstOpen.Add(Pointer(iFrom));
  // begin A* search
  bFound := false;
  while lstOpen.Count > 0 do begin
    // get first node from OPEN list
    iNode := integer(lstOpen.Items[0]);
    lstOpen.Delete(0);
    // test if it is the target
    if iNode = iTo then begin
      bFound := true;
      // break;
    end;
    // examine connected nodes
    if iNode <> iTo then begin
      for i := 1 to arTerritory[iNode].NBord do begin
        iChild := arTerritory[iNode].Bord[i];
        // skip owned territories if required
        if bAvoidOwned and (arTerritory[iChild].Owner = iTurn) then
          continue
        else if bUseOwned and (arTerritory[iChild].Owner <> iTurn) then
          continue;
        // check if child territory is in OPEN and CLOSED lists
        bIsOpen := lstOpen.IndexOf(Pointer(iChild)) >= 0;
        bIsClosed := aNode[iChild].bClosed;
        // compute cost from node to child
        if bArmies then begin
          // cost = armies + 1
          iCostFromStart := aNode[iNode].iCostFromStart + arTerritory[iChild]
          .Army + 1;
        end
        else begin
          // cost = distance (1000) + territory number
          iCostFromStart := aNode[iNode].iCostFromStart + 1000 + iChild;
        end;
        // assign cost to child if node has not yet been already reached
        // or if reached with higher cost
        if (not bIsOpen and not bIsClosed) or
        (iCostFromStart < aNode[iChild].iCostFromStart) then begin
          aNode[iChild].iParent := iNode;
          aNode[iChild].iCostFromStart := iCostFromStart;
          if bIsClosed then
            aNode[iChild].bClosed := false; // remove child from CLOSED list
          if not bIsOpen then
            lstOpen.Add(Pointer(iChild));
        end;
      end;
    end; //
    aNode[iNode].bClosed := true; // node has been examined, add to CLOSED list
  end;
  if not bFound then begin
    // return with empty path and error if target was not reached
    result := false;
    iLength := -1;
    iCost := MaxInt;
  end
  else begin
    // compute length and cost of path
    iLength := 0;
    iCost := aNode[iTo].iCostFromStart;
    iNode := iTo;
    while aNode[iNode].iParent > 0 do begin
      inc(iLength);
      iNode := aNode[iNode].iParent;
    end;
    // build path array
    if length(aPath) >= iLength then begin // check that array is large enough
      i := iLength - 1; // dinamic array receceived as par is always 0-based
      iNode := iTo;
      while aNode[iNode].iParent > 0 do begin
        aPath[i] := iNode;
        dec(i);
        iNode := aNode[iNode].iParent;
      end;
      result := true;
    end
    else begin // array is not large enough, return error
      result := false;
      iLength := -1;
      iCost := MaxInt;
    end;
  end;
  // free resources
  lstOpen.Free;
end;

function TDistance(ST, DT: integer): integer;
// returns the distance (number of borders to cross) between territories ST and DT,
// -1 if ST or DT are out of range
var
  iLength, iCost: integer;
  aPath: array [1 .. 42] of integer;
begin
  if (ST < 1) or (ST > MAXTERRITORIES) or (DT < 1) or (DT > MAXTERRITORIES)
  then begin
    result := -1;
    exit
  end;
  if TPath(ST, DT, false, false, false, iLength, iCost, aPath) then begin
    result := iLength;
  end
  else begin
    result := -1; // this should never happen
  end;
end;

function TShortestPath(ST, DT: integer; var TT, PL: integer): boolean;
// finds the shortest path to go from the start territory ST to the destination territory DT
// returns false if ST or DT are out of range, otherwise true
// the "var" variables will contain information on the path from ST to DT:
// TT: first territory in the path
// PL: path length (number of borders to cross)
var
  iLength, iCost: integer;
  aPath: array [1 .. 42] of integer;
begin
  TT := 0;
  PL := 0;
  if (ST < 1) or (ST > MAXTERRITORIES) or (DT < 1) or (DT > MAXTERRITORIES)
  then begin
    result := false;
    exit
  end;
  result := TPath(ST, DT, false, false, false, iLength, iCost, aPath);
  if iLength > 0 then
    TT := aPath[1]
  else
    TT := ST;
  PL := iLength;
end;

function TWeakestPath(ST, DT: integer; var TT, PL, EA: integer): boolean;
// finds the weakest path to go from the start territory ST to the destination territory DT
// the "weakest path" is the path that contains the minimum number of enemy armies
// and that doesn't cross territories already owned by the current player
// returns false if ST or DT are out of range or if the path doesn't exist
// the "var" variables will contain information on the path from ST to DT:
// TT: first territory in the path
// PL: path length (number of territories to conquer)
// EA: total number of enemy armies along the path
var
  iLength, iCost: integer;
  aPath: array [1 .. 42] of integer;
begin
  TT := 0;
  PL := 0;
  EA := 0;
  if (ST < 1) or (ST > MAXTERRITORIES) or (DT < 1) or (DT > MAXTERRITORIES) or
  (ST = DT) then begin
    result := false;
    exit
  end;
  result := TPath(ST, DT, true, false, true, iLength, iCost, aPath);
  if iLength > 0 then
    TT := aPath[1]
  else
    TT := ST;
  PL := iLength;
  EA := iCost - PL;
end;

function TPathToFront(T: integer): integer;
// finds the path to go from territory T to the closest front territory
// returns the number of the first territory in the path
// returns 0 if T is itself a front, -1 if T is out of range
var
  iDest, iLength, iCost, iMinLength: integer;
  aPath: array [1 .. 42] of integer;
begin
  if (T < 1) or (T > MAXTERRITORIES) then begin
    result := -1;
    exit;
  end;
  if TIsFront(T) then begin
    result := 0;
    exit;
  end;
  // search for the closest front
  iMinLength := MaxInt;
  result := 0;
  for iDest := 1 to MAXTERRITORIES do begin
    if TIsFront(iDest) then begin
      if TPath(T, iDest, false, true, false, iLength, iCost, aPath) then begin
        if (iLength > 0) and (iLength < iMinLength) then begin
          result := aPath[1];
          iMinLength := iLength;
        end;
      end;
    end;
  end;
end;

// *********************
// * ROUTINES "PLAYER" *
// *********************

function PMe: integer;
// returns the ID of the player in turn
begin
  result := iTurn;
end;

function PName(P: integer): string;
// returns player's P name, '?' if P is out of range
begin
  if (P > 0) and (P <= MAXPLAYERS) then
    result := arPlayer[P].Name
  else
    result := '?';
end;

function PProgram(P: integer): string;
// returns player's program file name (lowercase), 'human' if human,
// '?' if P is out of range
begin
  if (P > 0) and (P <= MAXPLAYERS) then begin
    if arPlayer[P].Computer then
      result := lowercase(arPlayer[P].PrgFile)
    else
      result := 'human';
  end
  else begin
    result := '?';
  end;
end;

function PActive(P: integer): boolean;
// returns true if player P was active at the beginning of the game, false if not or P is out of range
begin
  if (P > 0) and (P <= MAXPLAYERS) then
    result := arPlayer[P].Active
  else
    result := false;
end;

function PAlive(P: integer): boolean;
// returns true if player P is alive, false if not or P is out of range
begin
  if (P > 0) and (P <= MAXPLAYERS) then begin
    if GameState = gsAssigning then
      result := arPlayer[P].Active
    else
      result := arPlayer[P].Active and (arPlayer[P].Territ > 0);
  end
  else begin
    result := false;
  end;
end;

function PHuman(P: integer): boolean;
// returns true if P is a human player, false if P is computer player or P is out of range
begin
  if (P > 0) and (P <= MAXPLAYERS) then
    result := not arPlayer[P].Computer
  else
    result := false;
end;

function PArmiesCount(P: integer): integer;
// returns the number of armies totally controlled by player P on all
// of its territories, -1 if P is out of range
var
  T, A: integer;
begin
  if (P > 0) and (P <= MAXPLAYERS) then begin
    A := 0;
    for T := 1 to MAXTERRITORIES do
      if arTerritory[T].Owner = P then
        inc(A, arTerritory[T].Army);
    result := A;
  end
  else
    result := -1;
end;

function PNewArmies(P: integer): integer;
// returns the number of armies which player P still has to place on his territories,
// -1 if P is out of range
begin
  if (P > 0) and (P <= MAXPLAYERS) then
    result := arPlayer[P].NewArmy
  else
    result := -1;
end;

function PTerritoriesCount(P: integer): integer;
// returns the number of territories controlled by player P, -1 if P is out of range
var
  T, O: integer;
begin
  if (P > 0) and (P <= MAXPLAYERS) then begin
    O := 0;
    for T := 1 to MAXTERRITORIES do
      if arTerritory[T].Owner = P then
        inc(O);
    result := O;
  end
  else
    result := -1;
end;

function PCardCount(P: integer): integer;
// returns the number of cards Player P has, -1 if P is out of range
begin
  if (P > 0) and (P <= MAXPLAYERS) then begin
    with arPlayer[P] do begin
      result := Cards[caInf] + Cards[caArt] + Cards[caCav] + Cards[caJok];
    end;
  end
  else
    result := -1;
end;

function PCardTurnInValue(P: integer): integer;
// if the trade in value is based on progression, returns the value of Player P's
// next card turn in
// returns 0 if the trade in value is based on combination, -1 if P is out of range
begin
  if (P <= 0) or (P > MAXPLAYERS) then begin
    result := -1;
    exit;
  end;
  if RCardsValueType = cvConstant then begin
    result := 0;
    exit;
  end;
  with arPlayer[P] do begin
    if NScambi < 8 then
      result := RTradeValue[NScambi + 1]
    else
      result := RTradeValue[8] + (NScambi - 7) * RValueInc;
  end;
end;

// ************************
// * ROUTINES "CONTINENT" *
// ************************

function COwner(C: integer): integer;
// returns the owner of continent C, 0 if C has more then one occupant, -1 if C is out of range
begin
  if (C > 0) and (C <= 6) then
    result := arContinent[TContId(C - 1)].Owner
  else
    result := -1;
end;

function CBonus(C: integer): integer;
// returns the number of armies (per turn) which the control of continent C entitles to, -1 if C is out of range
begin
  if (C > 0) and (C <= 6) then
    result := arContinent[TContId(C - 1)].Bonus
  else
    result := -1;
end;

function CTerritoriesCount(C: integer): integer;
// returns the number of territories belonging to continent C, -1 if C is out of range
begin
  if (C > 0) and (C <= 6) then
    case TContId(C - 1) of
      coNA:
        result := 9;
      coSA:
        result := 4;
      coAF:
        result := 6;
      coEU:
        result := 7;
      coAS:
        result := 12;
      coAU:
        result := 4;
    else
      result := -1
    end
  else
    result := -1;
end;

function CTerritory(C, T: integer): integer;
// returns the ID of territory #T belonging to continent C, -1 if T or C are out of range
begin
  if (C > 0) and (C <= 6) and (T > 0) then
    case TContId(C - 1) of
      coNA:
        if T > 9 then
          result := -1
        else
          result := T;
      coSA:
        if T > 4 then
          result := -1
        else
          result := T + 9;
      coAF:
        if T > 6 then
          result := -1
        else
          result := T + 13;
      coEU:
        if T > 7 then
          result := -1
        else
          result := T + 19;
      coAS:
        if T > 12 then
          result := -1
        else
          result := T + 26;
      coAU:
        if T > 4 then
          result := -1
        else
          result := T + 38;
    else
      result := -1
    end
  else
    result := -1;
end;

function CBordersCount(C: integer): integer;
// returns the number of border territories on continent C (max 6), -1 if C is out of range
// Border territories are territories which are outside the continent but
// may be accessed from it
begin
  if (C > 0) and (C <= 6) then
    case TContId(C - 1) of
      coNA:
        result := 3;
      coSA:
        result := 2;
      coAF:
        result := 4;
      coEU:
        result := 6;
      coAS:
        result := 6;
      coAU:
        result := 1;
    else
      result := -1
    end
  else
    result := -1;
end;

function CBorder(C, B: integer): integer;
// returns border territory #B of continent C, -1 if C or B are out of range
// Border territories are territories which are outside the continent but
// may be accessed from it
begin
  if (C > 0) and (C <= 6) and (B > 0) then
    case TContId(C - 1) of
      coNA:
        case B of
          1:
            result := 20;
          2:
            result := 10;
          3:
            result := 37;
        else
          result := -1;
        end;
      coSA:
        case B of
          1:
            result := 9;
          2:
            result := 14;
        else
          result := -1;
        end;
      coAF:
        case B of
          1:
            result := 12;
          2:
            result := 25;
          3:
            result := 26;
          4:
            result := 27;
        else
          result := -1;
        end;
      coEU:
        case B of
          1:
            result := 3;
          2:
            result := 15;
          3:
            result := 14;
          4:
            result := 27;
          5:
            result := 28;
          6:
            result := 29;
        else
          result := -1;
        end;
      coAS:
        case B of
          1:
            result := 1;
          2:
            result := 15;
          3:
            result := 16;
          4:
            result := 22;
          5:
            result := 26;
          6:
            result := 39;
        else
          result := -1;
        end;
      coAU:
        case B of
          1:
            result := 31;
        else
          result := -1;
        end;
    else
      result := -1
    end
  else
    result := -1;
end;

function CAnalysis(C: integer; var PT, PA, ET, EA: integer): boolean;
// returns false if C is out of range, otherwise true
// the "var" variables will contain information on continent C:
// PT: player in turn's number of territories on continent C
// PA: player in turn's armies on continent C
// ET: enemy's number of territories on continent C
// EA: enemy's armies on continent C
// (unassigned territories are not counted)
var
  T: integer;
  tCont: TContId;
begin
  if (C < 1) or (C > 6) then begin
    result := false;
    exit;
  end;
  tCont := TContId(C - 1);
  PT := 0;
  PA := 0;
  ET := 0;
  EA := 0;
  // analisi
  for T := 1 to MAXTERRITORIES do begin
    if arTerritory[T].Contin = tCont then begin
      if arTerritory[T].Owner = iTurn then begin
        inc(PT);
        inc(PA, arTerritory[T].Army);
      end
      else if arTerritory[T].Owner <> 0 then begin
        inc(ET);
        inc(EA, arTerritory[T].Army);
      end;
    end;
  end;
  result := true;
end;

function CLeader(C: integer; var P, T, A: integer): boolean;
// returns false if C is out of range, otherwise true
// the "var" variables will contain information on continent C:
// P: leader = player who controls greatest number of territories
// T: leader's number of territories on continent C
// A: leader's armies on continent C
// if two or more players own the same number of territories, the leader is the
// one which has more armies. If continent is empty (all territories unissegned)
// P returns 0.
// (unassigned territories are not counted)
var
  iT, iG, iMax, iVal: integer;
  arP: array [1 .. MAXPLAYERS] of record T, A: integer end;
  tCont: TContId;
begin
  if (C < 1) or (C > 6) then begin
    result := false;
    exit;
  end;
  tCont := TContId(C - 1);
  P := 0;
  T := 0;
  A := 0;
  // reset vettore
  for iG := 1 to MAXPLAYERS do begin
    arP[iG].T := 0;
    arP[iG].A := 0;
  end;
  // analisi
  for iT := 1 to MAXTERRITORIES do begin
    with arTerritory[iT] do begin
      if Contin = tCont then begin
        if Owner <> 0 then begin
          inc(arP[Owner].T);
          inc(arP[Owner].A, Army);
        end;
      end;
    end;
  end;
  // trova leader
  iMax := 0;
  for iG := 1 to MAXPLAYERS do begin
    iVal := arP[iG].T * 1000 + arP[iG].A;
    if iVal > iMax then begin
      iMax := iVal;
      P := iG;
      T := arP[iG].T;
      A := arP[iG].A;
    end;
  end;
  result := true;
end;

function CEntriesCount(C: integer): integer;
// returns the number of entry territories on continent C (max 6), -1 if C is out of range
// Entry territories are territories which are part of the continent but
// may be accessed from another continent
begin
  if (C > 0) and (C <= 6) then
    case TContId(C - 1) of
      coNA:
        result := 3;
      coSA:
        result := 2;
      coAF:
        result := 3;
      coEU:
        result := 4;
      coAS:
        result := 5;
      coAU:
        result := 1;
    else
      result := -1
    end
  else
    result := -1;
end;

function CEntry(C, B: integer): integer;
// returns entry territory #B of continent C, -1 if C or B are out of range
// Entry territories are territories which are part of the continent but
// may be accessed from another continent
begin
  if (C > 0) and (C <= 6) and (B > 0) then
    case TContId(C - 1) of
      coNA:
        case B of
          1:
            result := 1;
          2:
            result := 3;
          3:
            result := 9;
        else
          result := -1;
        end;
      coSA:
        case B of
          1:
            result := 10;
          2:
            result := 12;
        else
          result := -1;
        end;
      coAF:
        case B of
          1:
            result := 14;
          2:
            result := 15;
          3:
            result := 16;
        else
          result := -1;
        end;
      coEU:
        case B of
          1:
            result := 20;
          2:
            result := 22;
          3:
            result := 25;
          4:
            result := 26;
        else
          result := -1;
        end;
      coAS:
        case B of
          1:
            result := 27;
          2:
            result := 28;
          3:
            result := 29;
          4:
            result := 31;
          5:
            result := 37;
        else
          result := -1;
        end;
      coAU:
        case B of
          1:
            result := 39;
        else
          result := -1;
        end;
    else
      result := -1
    end
  else
    result := -1;
end;


// *********************
// * ROUTINES "STATUS" *
// *********************

function SConquest: boolean;
// returns true if current player has conquered at least one territory on current turn,
// otherwise false
begin
  result := arPlayer[iTurn].FlConq;
end;

function SPlayersCount: integer;
// returns the number of active players
var
  G: integer;
begin
  result := 0;
  for G := 1 to MAXPLAYERS do
    if arPlayer[G].Active then
      result := result + 1;
end;

function SAlivePlayersCount: integer;
// returns the number of players who are currently alive
var
  G: integer;
begin
  result := 0;
  for G := 1 to MAXPLAYERS do
    if arPlayer[G].Active and ((arPlayer[G].Territ > 0) or
      (GameState = gsAssigning)) then
      result := result + 1;
end;

function SCardsBasedOnCombo: boolean;
// returns true if the card rules are set for the trade in value to based on combination,
// false if the trade in value is based on progression
begin
  result := (RCardsValueType = cvConstant);
end;

// ************************
// * ROUTINES "UTILITIES" *
// ************************

procedure UMessage(M: string);
// display a modal window with message M
begin
  if arPlayer[iTurn].UMessageEnabled then begin
    if fStats.Visible then
      fStats.BringToFront;
    if fLog.Visible then
      fLog.BringToFront;
    // copy log to clipboard
    Clipboard.SetTextBuf(PChar(fLog.txtLog.Text));
    // show dialog
    fUDialog.Caption := arPlayer[iTurn].Name;
    fUDialog.sMsg := M;
    fUDialog.sButtons := ';;Ok';
    fUDialog.ShowModal;
  end;
end;

procedure ULog(M: string);
// write message M on the log
begin
  if arPlayer[iTurn].ULogEnabled then
    ScriviLog(M);
end;

procedure UBufferSet(B: integer; V: double);
// set B element of Player's buffer to value V
begin
  if (B > 0) and (B <= MAXBUFFER) then
    arPlayer[iTurn].Buffer[B] := V;
end;

function UBufferGet(B: integer): double;
// returns Bth element of Player's buffer, -1 if B is out of range
begin
  if (B > 0) and (B <= MAXBUFFER) then
    result := arPlayer[iTurn].Buffer[B]
  else
    result := -1.0;
end;

function URandom(R: integer): double;
// if R is greater than 0, returns am integer random number X in the range
// 0 <= X < R, otherwise a real-type random number X in the range 0 <= X < 1
begin
  if R > 0 then
    result := Random(R)
  else
    result := Random;
end;

procedure UTakeSnapshot(M: string);
// save a snapshot of the game
// a snapshot is a copy of the global status of the game saved to a file
// with name 'trdump_YYYYMMDD_HHMMSS.trd'
// message M is included in the snapshot
begin
  if arPlayer[iTurn].USnapShotEnabled then begin
    // create dump folder, if not existing
    if not SysUtils.DirectoryExists(sG_AppPath + '\Dump') then begin
      if not CreateDir(sG_AppPath + '\Dump') then
        raise Exception.Create('Cannot create ' + sG_AppPath + '\Dump');
    end;
    if bG_TRSim then begin
      SaveGame(sG_AppPath + 'Dump\trdump_' + FormatDateTime('yyyymmdd_hhmmss',
          Now) + '_simgame_' + FormatFloat('000', iSimCurr) + '.trd', M);
    end
    else begin
      SaveGame(sG_AppPath + 'Dump\trdump_' + FormatDateTime('yyyymmdd_hhmmss',
          Now) + '.trd', M)
    end;
  end;
end;

function UDialog(M, B: string): integer;
// display a modal window with message M and B buttons
// B is a comma-separated string (like 'Continue;Dump;Stop') max 5 buttons
// returns a number corresponding to the button pressed by
// the user, 0 if the user closed the window
begin
  result := 0;
  if arPlayer[iTurn].UDialogEnabled then begin
    if fStats.Visible then
      fStats.BringToFront;
    if fLog.Visible then
      fLog.BringToFront;
    // copy log to clipboard
    Clipboard.SetTextBuf(PChar(fLog.txtLog.Text));
    // show dialog
    fUDialog.Caption := arPlayer[iTurn].Name;
    fUDialog.sMsg := M;
    fUDialog.sButtons := B;
    fUDialog.ShowModal;
    result := fUDialog.iDlgResult;
  end;
end;

procedure UAbortGame;
// asks TurboRisk to stop ASAP
begin
  bStopASAP := true;
end;

procedure ULogOff;
begin
  arPlayer[iTurn].ULogEnabled := false;
end;

procedure ULogOn;
begin
  arPlayer[iTurn].ULogEnabled := true;
end;

procedure UMessageOff;
begin
  arPlayer[iTurn].UMessageEnabled := false;
end;

procedure UMessageOn;
begin
  arPlayer[iTurn].UMessageEnabled := true;
end;

procedure UDialogOff;
begin
  arPlayer[iTurn].UDialogEnabled := false;
end;

procedure UDialogOn;
begin
  arPlayer[iTurn].UDialogEnabled := true;
end;

procedure USnapShotOff;
begin
  arPlayer[iTurn].USnapShotEnabled := false;
end;

procedure USnapShotOn;
begin
  arPlayer[iTurn].USnapShotEnabled := true;
end;

end.
