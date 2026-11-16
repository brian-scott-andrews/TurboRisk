const
  CounterReference =
    'function Gain(E: integer): double;' + LineEnding +
    'var C,T,Missing,P,EnemyMissing: integer;' + LineEnding +
    'begin' + LineEnding +
    '  P:=TOwner(E); C:=TContinent(E); Missing:=0; EnemyMissing:=0;' + LineEnding +
    '  for T:=1 to CTerritoriesCount(C) do begin' + LineEnding +
    '    if not Owned[CTerritory(C,T)] then Missing:=Missing+1;' + LineEnding +
    '    if (TOwner(CTerritory(C,T))<>P) or Owned[CTerritory(C,T)] then EnemyMissing:=EnemyMissing+1;' + LineEnding +
    '  end;' + LineEnding +
    '  Result:=1.8+4*(Income(Counts[PMe]+1)-Income(Counts[PMe]));' + LineEnding +
    '  if P>0 then Result:=Result+4*(Income(Counts[P])-Income(Counts[P]-1));' + LineEnding +
    '  Result:=Result+CBonus(C)*3.0/(Missing+1);' + LineEnding +
    '  if Missing=1 then Result:=Result+CBonus(C)*5;' + LineEnding +
    '  if EnemyMissing=0 then Result:=Result+CBonus(C)*6;' + LineEnding +
    '  if (P>0) and (Counts[P]=1) then Result:=Result+500;' + LineEnding +
    'end;' + LineEnding +
    '' + LineEnding +
    'procedure Explore(Cur,Armies,Depth,First: integer; Score,Chance: double);' + LineEnding +
    'var F,E,P,D,Remaining,NextFirst: integer; Q,Cost,V: double;' + LineEnding +
    'begin' + LineEnding +
    '  if Depth=0 then exit;' + LineEnding +
    '  for F:=1 to TBordersCount(Cur) do begin' + LineEnding +
    '    E:=TBorder(Cur,F); P:=TOwner(E);' + LineEnding +
    '    if not Owned[E] and (P>0) and (Armies>0) then begin' + LineEnding +
    '      D:=TArmies(E); if D<1 then D:=1;' + LineEnding +
    '      Q:=Odds(Armies,D);' + LineEnding +
    '      if Q>=0.55 then begin' + LineEnding +
    '        Cost:=Casualties(Armies,D);' + LineEnding +
    '        V:=Score+Chance*(Q*Gain(E)-Cost-0.65-(1-Q)*Armies*0.35);' + LineEnding +
    '        NextFirst:=First; if NextFirst=0 then NextFirst:=E;' + LineEnding +
    '        if V>BestScore then begin BestScore:=V; FirstTarget:=NextFirst end;' + LineEnding +
    '        Remaining:=Armies-round(Cost)-1;' + LineEnding +
    '        if Remaining>1 then begin' + LineEnding +
    '          Owned[E]:=True; Counts[PMe]:=Counts[PMe]+1; Counts[P]:=Counts[P]-1;' + LineEnding +
    '          Explore(E,Remaining,Depth-1,NextFirst,V,Chance*Q);' + LineEnding +
    '          Owned[E]:=False; Counts[PMe]:=Counts[PMe]-1; Counts[P]:=Counts[P]+1;' + LineEnding +
    '        end;' + LineEnding +
    '      end;' + LineEnding +
    '    end;' + LineEnding +
    '  end;' + LineEnding +
    'end;' + LineEnding +
    '' + LineEnding +
    'function Campaign(Extra: integer; var Source,Target: integer): double;' + LineEnding +
    'var T,P,I,J: integer; Tops: array[1..4] of integer; Overall: double;' + LineEnding +
    'begin' + LineEnding +
    '  if not Ready then PrepareOdds;' + LineEnding +
    '  for T:=1 to 42 do Owned[T]:=TIsMine(T);' + LineEnding +
    '  for P:=1 to 10 do Counts[P]:=PTerritoriesCount(P);' + LineEnding +
    '  for I:=1 to 4 do Tops[I]:=0;' + LineEnding +
    '  for T:=1 to 42 do if TIsFront(T) then' + LineEnding +
    '    for I:=1 to 4 do if (Tops[I]=0) or (TArmies(T)>TArmies(Tops[I])) then begin' + LineEnding +
    '      for J:=4 downto I+1 do Tops[J]:=Tops[J-1];' + LineEnding +
    '      Tops[I]:=T; break;' + LineEnding +
    '    end;' + LineEnding +
    '  Source:=0; Target:=0; Overall:=0;' + LineEnding +
    '  for I:=1 to 4 do if Tops[I]>0 then begin' + LineEnding +
    '    SearchSource:=Tops[I]; BestScore:=0; FirstTarget:=0;' + LineEnding +
    '    Explore(SearchSource,TArmies(SearchSource)-1+Extra,3,0,0,1);' + LineEnding +
    '    if BestScore>Overall then begin' + LineEnding +
    '      Overall:=BestScore; Source:=SearchSource; Target:=FirstTarget;' + LineEnding +
    '    end;' + LineEnding +
    '  end;' + LineEnding +
    '  Result:=Overall;' + LineEnding +
    'end;' + LineEnding +
    '' + LineEnding +
    '' + LineEnding;
  ChallengerRouteReference =
    'function EliminationRoute(Start, P, Budget: integer;' + LineEnding +
    '  var First, Cost: integer): boolean;' + LineEnding +
    'var' + LineEnding +
    '  Used, Closed: array [1..42] of boolean;' + LineEnding +
    '  Distance, Previous: array [1..42] of integer;' + LineEnding +
    '  T, E, F, Current, Next, Remaining, N, Cheapest, StepCost, Factor, Limit: integer;' + LineEnding +
    'begin' + LineEnding +
    '  result:=false; First:=0; Cost:=0;' + LineEnding +
    '  if (Start<1) or (Start>42) or (P<1) or (P>10) then exit;' + LineEnding +
    '  if not TIsMine(Start) or (P=PMe) or not PActive(P) then exit;' + LineEnding +
    '  Remaining:=PTerritoriesCount(P);' + LineEnding +
    '  Limit:=6;' + LineEnding +
    '  if (SAlivePlayersCount<=4) and (SPlayersCount<=4) then Limit:=10;' + LineEnding +
    '  if (Remaining<1) or (Remaining>Limit) then exit;' + LineEnding +
    '  Factor:=2;' + LineEnding +
    '  if SCardsBasedOnCombo then Factor:=3;' + LineEnding +
    '  if Factor*PArmiesCount(P)+Remaining+4>Budget then exit;' + LineEnding +
    '  for T:=1 to 42 do Used[T]:=false;' + LineEnding +
    '  Used[Start]:=true; Current:=Start;' + LineEnding +
    '' + LineEnding +
    '  while Remaining>0 do begin' + LineEnding +
    '    for T:=1 to 42 do begin' + LineEnding +
    '      Distance[T]:=100000; Previous[T]:=0; Closed[T]:=false;' + LineEnding +
    '    end;' + LineEnding +
    '    Distance[Current]:=0; Next:=0;' + LineEnding +
    '    for N:=1 to 42 do begin' + LineEnding +
    '      E:=0; Cheapest:=100000;' + LineEnding +
    '      for T:=1 to 42 do' + LineEnding +
    '        if not Closed[T] and (Distance[T]<Cheapest) then begin' + LineEnding +
    '          E:=T; Cheapest:=Distance[T];' + LineEnding +
    '        end;' + LineEnding +
    '      if E=0 then break;' + LineEnding +
    '      Closed[E]:=true;' + LineEnding +
    '      if (E<>Current) and (TOwner(E)=P) then begin Next:=E; break end;' + LineEnding +
    '      for F:=1 to TBordersCount(E) do begin' + LineEnding +
    '        T:=TBorder(E,F);' + LineEnding +
    '        if not TIsMine(T) and not Used[T] and not Closed[T] then begin' + LineEnding +
    '          StepCost:=Distance[E]+Factor*Defense(T)+1;' + LineEnding +
    '          if StepCost<Distance[T] then begin' + LineEnding +
    '            Distance[T]:=StepCost; Previous[T]:=E;' + LineEnding +
    '          end;' + LineEnding +
    '        end;' + LineEnding +
    '      end;' + LineEnding +
    '    end;' + LineEnding +
    '    if Next=0 then exit;' + LineEnding +
    '    Cost:=Cost+Distance[Next];' + LineEnding +
    '    if Cost+4>Budget then exit;' + LineEnding +
    '    T:=Next;' + LineEnding +
    '    // The moving stack cannot cross its own trail by attacking.' + LineEnding +
    '    while T<>Current do begin' + LineEnding +
    '      if TOwner(T)=P then Remaining:=Remaining-1;' + LineEnding +
    '      Used[T]:=true;' + LineEnding +
    '      E:=Previous[T];' + LineEnding +
    '      if E=0 then exit;' + LineEnding +
    '      if (Current=Start) and (E=Start) then First:=T;' + LineEnding +
    '      T:=E;' + LineEnding +
    '    end;' + LineEnding +
    '    Current:=Next;' + LineEnding +
    '  end;' + LineEnding +
    '  result:=First>0;' + LineEnding +
    'end;' + LineEnding +
    '' + LineEnding +
    '' + LineEnding;
  ChallengerAttackReference =
    'procedure Attack(var FromTerritory, ToTerritory: integer);' + LineEnding +
    'var T, F, E, P, Next, Cost, Target, Reward, BestReward, Stack,' + LineEnding +
    '  Available, Score, Best, H, Neighbor, Onward, Cheapest, Force: integer;' + LineEnding +
    '  Need: double;' + LineEnding +
    '  Small, Duel, Allowed, Breaks: boolean;' + LineEnding +
    '  TC: integer;' + LineEnding +
    'begin' + LineEnding +
    '  FromTerritory:=0; ToTerritory:=0;' + LineEnding +
    '  Stack:=StrongestFront;' + LineEnding +
    '  if Stack=0 then exit;' + LineEnding +
    '  P:=trunc(UBufferGet(1));' + LineEnding +
    '  T:=trunc(UBufferGet(2));' + LineEnding +
    '  if (P>=1) and (P<=10) and (T>=1) and (T<=42) then' + LineEnding +
    '    if EliminationRoute(T,P,TArmies(T)-1,Next,Cost) then begin' + LineEnding +
    '      FromTerritory:=T; ToTerritory:=Next; exit;' + LineEnding +
    '    end;' + LineEnding +
    '  UBufferSet(1,0); UBufferSet(2,0); BestReward:=0;' + LineEnding +
    '  for T:=1 to 42 do if TIsMine(T) and TIsFront(T) and (TArmies(T)>1) then begin' + LineEnding +
    '    Reward:=ChooseElimination(T,TArmies(T)-1,Target,Next);' + LineEnding +
    '    if Reward>BestReward then begin' + LineEnding +
    '      BestReward:=Reward; FromTerritory:=T; ToTerritory:=Next;' + LineEnding +
    '      UBufferSet(1,Target); UBufferSet(2,T);' + LineEnding +
    '    end;' + LineEnding +
    '  end;' + LineEnding +
    '  if ToTerritory>0 then exit;' + LineEnding +
    '' + LineEnding +
    '  Best:=-100000; Force:=EnemyArmies;' + LineEnding +
    '  // Large games keep the original big-game behaviour throughout.' + LineEnding +
    '  Duel:=(SAlivePlayersCount=2) and (SPlayersCount<=4);' + LineEnding +
    '  Small:=(SAlivePlayersCount<=4) and (SPlayersCount<=4);' + LineEnding +
    '  TC:=0;' + LineEnding +
    '  if SmallMode then TC:=TargetContinent;' + LineEnding +
    '  for T:=1 to 42 do if TIsMine(T) and (TArmies(T)>1) then' + LineEnding +
    '    for F:=1 to TFrontsCount(T) do begin' + LineEnding +
    '      E:=TFront(T,F); Available:=TArmies(T)-1;' + LineEnding +
    '      Breaks:=COwner(TContinent(E))=TOwner(E);' + LineEnding +
    '      Need:=3.0;' + LineEnding +
    '      if SCardsBasedOnCombo then Need:=4.0;' + LineEnding +
    '      if CompletesContinent(E) then Need:=2.5;' + LineEnding +
    '      Allowed:=not SConquest or CompletesContinent(E);' + LineEnding +
    '      if (Available>Force*2+42) or (SAlivePlayersCount=2) then begin Need:=1.8; Allowed:=true end;' + LineEnding +
    '      if Small and not Duel then begin' + LineEnding +
    '        // Few opponents: continents and bonus denial matter more than in big games.' + LineEnding +
    '        if CompletesContinent(E) then begin Need:=1.5; Allowed:=true end' + LineEnding +
    '        else if (TC>0) and (TContinent(E)=TC) then begin Need:=1.3; Allowed:=true end' + LineEnding +
    '        else if Breaks then begin Need:=2.0; Allowed:=true end;' + LineEnding +
    '        if (T=Stack) and (Available>Force) then begin Need:=1.5; Allowed:=true end;' + LineEnding +
    '      end;' + LineEnding +
    '      if Duel then begin' + LineEnding +
    '        // One opponent: keep the main stack rolling; other armies only take a card.' + LineEnding +
    '        if T=Stack then begin Need:=1.0; Allowed:=true end' + LineEnding +
    '        else Allowed:=not SConquest;' + LineEnding +
    '      end;' + LineEnding +
    '      if Allowed and (Available>=Need*Defense(E)) then begin' + LineEnding +
    '        Onward:=0; Cheapest:=100000;' + LineEnding +
    '        for H:=1 to TBordersCount(E) do begin' + LineEnding +
    '          Neighbor:=TBorder(E,H);' + LineEnding +
    '          if not TIsMine(Neighbor) then begin' + LineEnding +
    '            Onward:=Onward+1;' + LineEnding +
    '            if Defense(Neighbor)<Cheapest then Cheapest:=Defense(Neighbor);' + LineEnding +
    '          end;' + LineEnding +
    '        end;' + LineEnding +
    '        Score:=Available-Defense(E)*8+Onward*2;' + LineEnding +
    '        if Duel then Score:=Available-Defense(E)*3+Onward*4;' + LineEnding +
    '        if Cheapest<100000 then Score:=Score-Cheapest;' + LineEnding +
    '        if CompletesContinent(E) then Score:=Score+CBonus(TContinent(E))*12;' + LineEnding +
    '        if (TC>0) and (TContinent(E)=TC) then Score:=Score+40;' + LineEnding +
    '        if COwner(TContinent(E))=TOwner(E) then' + LineEnding +
    '          Score:=Score+CBonus(TContinent(E))*4;' + LineEnding +
    '        if Score>Best then begin Best:=Score; FromTerritory:=T; ToTerritory:=E end;' + LineEnding +
    '      end;' + LineEnding +
    '    end;' + LineEnding +
    'end;' + LineEnding +
    '' + LineEnding +
    '' + LineEnding;
