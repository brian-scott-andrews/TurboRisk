unit Computer;

{$MODE Delphi}

interface

// Execute the computer player's turn.
procedure ExecuteComputerTurn;
function strTran(ctext, cfor, cwith: string): string;


implementation

uses LCLIntf, LCLType, LMessages, Forms, Controls, SysUtils, Dialogs,
  uPSRuntime, uPSUtils, {StdPas,}
  Main, Globals, Territ, Stats, Log, TRPError, Sim, SimRun;

var

  // Varibles used to pass parameters to the script executer
  tParamToTerritory, tParamFromTerritory, tParamArmies: PPSVariant;
  tParamList: TPSList; // The parameter list

  iStartTime, iEndTime: QWord; // CPU timing for TRSim

{ Character by Character String Replacement }
function StrTran(ctext, cfor, cwith: string): string;
  var
     ntemp  : word  ;
     nreplen: word  ;
  begin
     cfor    := upperCase(cfor)   ;
     nreplen := length(cfor)      ;
     for ntemp := 1 to length(ctext) do begin
        if (upperCase(copy(ctext, ntemp, nreplen)) = cfor) then
        begin
           delete(ctext, ntemp, nreplen);
           insert(cwith, ctext, ntemp);
        end;
     end;
     result := ctext;
end;

procedure ShowError(sMsg: string);
begin
  if not bG_TRSim then begin // TurboRisk
    fTRPError.txtMsg.Text := sMsg;
    case fTRPError.ShowModal of
      mrYes: begin
          // dump memory if required
          sMsg := StrTran(sMsg, #13#10, '\n');
          if not SysUtils.DirectoryExists(sG_AppPath + PathDelim + 'Dump') then begin
            if not CreateDir(sG_AppPath + PathDelim + 'Dump') then
              raise Exception.Create('Cannot create ' + sG_AppPath + PathDelim + 'Dump');
          end;
          SaveGame(sG_AppPath + 'Dump' + PathDelim + 'trdump_' + FormatDateTime
            ('yyyymmdd_hhmmss', Now) + '.trd', sMsg);
        end;
      mrAbort: begin
          bStopASAP := true;
          bCloseASAP := true;
        end;
    end;
  end
  else begin // TRSim
    fSimRun.SimLog('TRP error: ' + sMsg);
    if fSim.chkErrorDump.Checked then begin
      // dump memory if required
      sMsg := StrTran(sMsg, #13#10, '\n');
      if not SysUtils.DirectoryExists(sG_AppPath + PathDelim +'Dump') then begin
        if not CreateDir(sG_AppPath + PathDelim + 'Dump') then
          raise Exception.Create('Cannot create ' + sG_AppPath + PathDelim + 'Dump');
      end;
      SaveGame(sG_AppPath + 'Dump'+PathDelim+'trdump_' + FormatDateTime('yyyymmdd_hhmmss',
          Now) + '.trd', sMsg);
    end;
    if fSim.chkErrorAbort.Checked then begin
      uSimStatus := ssError;
      bStopASAP := true;
    end;
  end;
end;

procedure CPU_Phase(uRoutine: TRoutine);
begin
  inc(arPlayer[iTurn].aCPU[uRoutine].iPhases);
end;

procedure CPU_Call(uRoutine: TRoutine; iTicks: QWord);
begin
  arPlayer[iTurn].aCPU[uRoutine].iTime := arPlayer[iTurn].aCPU[uRoutine]
  .iTime + iTicks;
  inc(arPlayer[iTurn].aCPU[uRoutine].iCalls);
end;

procedure LogTRPDecision(const sMessage: string);
begin
  if bTRSimCLI and bSimVerbose then
    fSimRun.SimLog(Format('[verbose] turn %d player %s: %s',
      [iTurnCounter, arPlayer[iTurn].Name, sMessage]));
end;

// ************************************************************
// * INITIAL TERRITORY ASSIGNMENT ROUTINES *
// ************************************************************

// Choose a territory for initial assignment
procedure CmpAssegnazione;
var
  iTo: integer;
  sMsg: string;

begin

  // prepare parameters to pass to the script executer
  VSetInt(tParamToTerritory, 0);
  tParamList.Clear;
  tParamList.Add(tParamToTerritory);

  // run the script
  try
    CPU_Phase(rtAssignment);
    iStartTime := SysUtils.GetTickCount64();
//    QueryPerformanceCounter(iStartTime); // get initial time
    ScriptExec.RunProc(tParamList, ScriptExec.GetProc('ASSIGNMENT'));
    iEndTime := gettickcount64;
//    QueryPerformanceCounter(iEndTime); // get final time
    CPU_Call(rtAssignment, iEndTime - iStartTime);
    // get back value of var parameters
    iTo := VGetInt(tParamToTerritory);
  except
    on e: Exception do begin
      sMsg := 'Player: ' + arPlayer[iTurn].Name + #13#10 +
      'Routine: Assignment' + #13#10 + 'Error: ' +
      e.message;
      ShowError(sMsg);
      exit;
    end;
  end;

  // Prepare the error message
  sMsg := 'Player: ' + arPlayer[iTurn].Name + #13#10 + 'Routine: Assignment' +
  #13#10 + 'To territory: ' + IntToStr(iTo) + #13#10 + 'Error: ';
  // Validate the request
  if (iTo < 1) or (iTo > MAXTERRITORIES) or (arTerritory[iTo].Owner <> 0) then
  begin
    sMsg := sMsg + 'Invalid "To" territory';
    ShowError(sMsg);
    iTo := 0;
  end;
  if iTo > 0 then begin
    LogTRPDecision('Assignment: ' + arTerritory[iTo].Name);
    // Assign the territory
    AssegnaTerritorio(iTo, iTurn);
    inc(arTerritory[iTo].Army);
    dec(arPlayer[iTurn].NewArmy);
    // Log
    if arPlayer[iTurn].KeepLog then
      ScriviLog(arTerritory[iTo].Name + ' assigned.');
    // Update the display and statistics
    DisplayTerritory(iTo);
    UpdateStats;
    if not bTRSimCLI then
      Application.ProcessMessages;
  end;
end;

// ***********************************************
// * ARMY PLACEMENT ROUTINES *
// ***********************************************

// Choose a territory for placing a new army
procedure CmpCollocaArmate(iDaCollocare: integer);
var
  iTo: integer;
  sMsg: string;

begin
  CPU_Phase(rtPlacement);
  // repeat placement procedure
  while iDaCollocare > 0 do begin
    iTo := 0;
    try
      // prepare parameters to pass to the script executer
      VSetInt(tParamToTerritory, iTo);
      tParamList.Clear;
      tParamList.Add(tParamToTerritory);
      // run the script
      iStartTime := SysUtils.GetTickCount64();
//      QueryPerformanceCounter(iStartTime); // get initial time
      ScriptExec.RunProc(tParamList, ScriptExec.GetProc('PLACEMENT'));
      iEndTime := SysUtils.GetTickCount64();
//      QueryPerformanceCounter(iEndTime); // get final time
      CPU_Call(rtPlacement, iEndTime - iStartTime);
      // get back value of var parameters
      iTo := VGetInt(tParamToTerritory);
    except
      on e: Exception do begin
        sMsg := 'Player: ' + arPlayer[iTurn].Name + #13#10 +
        'Routine: Placement' + #13#10 + 'Error: ' + e.message;
        ShowError(sMsg);
        exit;
      end;
    end;

    // Prepare the error message
    sMsg := 'Player: ' + arPlayer[iTurn].Name + #13#10 + 'Routine: Placement' +
    #13#10 + 'To territory: ' + IntToStr(iTo) + #13#10 + 'Error: ';
    // Validate the request
    if (iTo < 1) or (iTo > MAXTERRITORIES) or (arTerritory[iTo].Owner <> iTurn)
    then begin
      sMsg := sMsg + 'Invalid "To" territory';
      ShowError(sMsg);
      iTo := 0;
    end;
    if iTo > 0 then begin
      LogTRPDecision(Format('Placement: add 1 army to %s (%d -> %d)',
        [arTerritory[iTo].Name, arTerritory[iTo].Army,
         arTerritory[iTo].Army + 1]));
      // Log
      if arPlayer[iTurn].KeepLog then
        ScriviLog('Army placement in ' + arTerritory[iTo].Name);
      // Place the army
      CollocaArmata(iTo, iTurn, 1);
    end
    else begin
      arPlayer[iTurn].NewArmy := 0; // force 0 new army to place
      break; // Stop the loop after an error
    end;

    dec(iDaCollocare);
  end;

end;

// ***************************************************************
// * CONQUERED TERRITORY OCCUPATION ROUTINES *
// ***************************************************************

procedure CmpOccupa(iFrom, iTo: integer);
var
  iArmies: integer;
  sMsg: string;
begin

  // prepare parameters to pass to the script executer
  VSetInt(tParamFromTerritory, iFrom);
  VSetInt(tParamToTerritory, iTo);
  VSetInt(tParamArmies, 0);
  tParamList.Clear;
  tParamList.Add(tParamArmies);
  tParamList.Add(tParamToTerritory);
  tParamList.Add(tParamFromTerritory);

  try
    // run script
    CPU_Phase(rtOccupation);
    iStartTime := SysUtils.GetTickCount64();
//    QueryPerformanceCounter(iStartTime); // get initial time
    ScriptExec.RunProc(tParamList, ScriptExec.GetProc('OCCUPATION'));
    iEndTime := SysUtils.GetTickCount64();
//    QueryPerformanceCounter(iEndTime); // get final time
    CPU_Call(rtOccupation, iEndTime - iStartTime);
    // get back value of var parameters
    iArmies := VGetInt(tParamArmies);
  except
    on e: Exception do begin
      sMsg := 'Player: ' + arPlayer[iTurn].Name + #13#10 +
      'Routine: Occupation' + #13#10 + 'Error: ' +
      e.message;
      ShowError(sMsg);
      exit;
    end;
  end;

  // If a troop movement was requested...
  if iArmies > 0 then begin
  LogTRPDecision(Format('Occupation: move %d armies from %s to %s',
    [iArmies, arTerritory[iFrom].Name, arTerritory[iTo].Name]));
  // Prepare the error message
    sMsg := 'Player: ' + arPlayer[iTurn].Name + #13#10 +
    'Routine: Occupation' + #13#10 + 'From territory: ' + arTerritory[iFrom]
    .Name + #13#10 + 'To territory: ' + arTerritory[iTo].Name + #13#10 +
    'Armies: ' + IntToStr(iArmies) + #13#10 + 'Error: ';
    // Validate the request
    if iArmies > arTerritory[iFrom].Army - 1 then begin
      sMsg := sMsg + 'Invalid number of armies';
      ShowError(sMsg);
      exit;
    end;
    // Log
    if arPlayer[iTurn].KeepLog then
      ScriviLog('Occupation: troops move (' + IntToStr(iArmies)
        + ') from ' + arTerritory[iFrom].Name + ' to ' + arTerritory[iTo]
        .Name);
    // Move the troops
    inc(arTerritory[iTo].Army, iArmies);
    dec(arTerritory[iFrom].Army, iArmies);
    // Update the display
    DisplayTerritory(iFrom);
    DisplayTerritory(iTo);
    UpdateStats;
    if not bTRSimCLI then
      Application.ProcessMessages;
  end
  else
    LogTRPDecision('Occupation: leave armies in place');
end;

// ********************************
// * ATTACK ROUTINES *
// ********************************

procedure CmpAttacco;
var
  iFrom, iTo: integer;
  sMsg: string;
  bEsito: boolean;

begin

  CPU_Phase(rtAttack);
  // repeat attack procedure
  repeat
    iFrom := 0;
    iTo := 0;
    try
      // prepare parameters to pass to the script executer
      VSetInt(tParamFromTerritory, iFrom);
      VSetInt(tParamToTerritory, iTo);
      tParamList.Clear;
      tParamList.Add(tParamToTerritory);
      tParamList.Add(tParamFromTerritory);
      // run the script
      iStartTime := SysUtils.GetTickCount64();
//      QueryPerformanceCounter(iStartTime); // get initial time
      ScriptExec.RunProc(tParamList, ScriptExec.GetProc('ATTACK'));
      iEndTime := SysUtils.GetTickCount64();
//      QueryPerformanceCounter(iEndTime); // get final time
      CPU_Call(rtAttack, iEndTime - iStartTime);
      // get back value of var parameters
      iFrom := VGetInt(tParamFromTerritory);
      iTo := VGetInt(tParamToTerritory);
    except
      on e: Exception do begin
        sMsg := 'Player: ' + arPlayer[iTurn].Name + #13#10 +
        'Routine: Attack' + #13#10 + 'Error: ' + e.message;
        ShowError(sMsg);
        if not bTRSimCLI then
          MessageDlg(sMsg, mtError, [mbOk], 0);
        exit;
      end;
    end;

    // If an attack was requested...
    if iFrom > 0 then begin
      // Prepare the error message
      sMsg := 'Player: ' + arPlayer[iTurn].Name + #13#10 + 'Routine: Attack' +
      #13#10 + 'From territory: ' + IntToStr(iFrom)
      + #13#10 + 'To territory: ' + IntToStr(iTo)
      + #13#10 + 'Error: ';
      // Validate the request
      if (iFrom > MAXTERRITORIES) or (arTerritory[iFrom].Owner <> iTurn) then
      begin
        sMsg := sMsg + 'Invalid "From" territory';
        ShowError(sMsg);
        exit;
      end;
      if (iTo < 1) or (iTo > MAXTERRITORIES) or
      (arTerritory[iTo].Owner = iTurn) then begin
        sMsg := sMsg + 'Invalid "To" territory';
        ShowError(sMsg);
        exit;
      end;
      if not Confinante(iFrom, iTo) then begin
        sMsg := sMsg + 'Invalid "From->To"';
        ShowError(sMsg);
        exit;
      end;
      if arTerritory[iFrom].Army < 2 then begin
        sMsg := sMsg + 'From territory has not enough armies';
        ShowError(sMsg);
        exit;
      end;
      // Attack
      LogTRPDecision(Format('Attack: %s (%d armies) -> %s (%d defenders)',
        [arTerritory[iFrom].Name, arTerritory[iFrom].Army,
         arTerritory[iTo].Name, arTerritory[iTo].Army]));
      bEsito := PerformAttack(iFrom, iTo);
      if bEsito then
        LogTRPDecision('Attack result: captured ' + arTerritory[iTo].Name)
      else
        LogTRPDecision('Attack result: repelled at ' + arTerritory[iTo].Name);
      // Update the display
      UpdateStats;
      if not bTRSimCLI then
        Application.ProcessMessages;
      // Handle the consequences of a successful attack
      if bEsito then begin
        // Exit immediately if this attack wins the game
        if iNPlayers < 2 then
          exit;
        // Move troops into the conquered territory
        if arTerritory[iFrom].Army > 1 then begin
          CmpOccupa(iFrom, iTo);
        end;
        // Place any armies gained from eliminating a player
        if bEliminatedPlayer then begin
          if RImmediateTrade then
            AssignNewArmies(true);
          if arPlayer[iTurn].NewArmy > 0 then begin
            CmpCollocaArmate(arPlayer[iTurn].NewArmy);
          end;
        end;
      end
      else
        LogTRPDecision('Attack: no target selected');
    end;

  until iFrom = 0;
end;

// *********************************************
// * FORTIFICATION ROUTINES *
// *********************************************

procedure CmpTrasferimento;
var
  iFrom, iTo, iArmies: integer;
  sMsg: string;
begin
  // Prevent multiple fortification moves
  if arPlayer[iTurn].FlMove then
    exit;

  // prepare parameters to pass to the script executer
  VSetInt(tParamFromTerritory, 0);
  VSetInt(tParamToTerritory, 0);
  VSetInt(tParamArmies, 0);
  tParamList.Clear;
  tParamList.Add(tParamArmies);
  tParamList.Add(tParamToTerritory);
  tParamList.Add(tParamFromTerritory);

  try
    // run the script
    CPU_Phase(rtFortification);
    iStartTime := SysUtils.GetTickCount64();
//    QueryPerformanceCounter(iStartTime); // get initial time
    ScriptExec.RunProc(tParamList, ScriptExec.GetProc('FORTIFICATION'));
    iEndTime := SysUtils.GetTickCount64();
//    QueryPerformanceCounter(iEndTime); // get final time
    CPU_Call(rtFortification, iEndTime - iStartTime);
    // get back value of var parameters
    iFrom := VGetInt(tParamFromTerritory);
    iTo := VGetInt(tParamToTerritory);
    iArmies := VGetInt(tParamArmies);
  except
    on e: Exception do begin
      sMsg := 'Player: ' + arPlayer[iTurn].Name + #13#10 +
      'Routine: Fortification' + #13#10 + 'Error: ' + e.message;
      ShowError(sMsg);
      exit;
    end;
  end;

  // If a troop movement was requested...
  if iFrom > 0 then begin
    LogTRPDecision(Format('Fortification: move %d armies from %s to %s',
      [iArmies, arTerritory[iFrom].Name, arTerritory[iTo].Name]));
    // Prepare the error message
    sMsg := 'Player: ' + arPlayer[iTurn].Name + #13#10 +
    'Routine: Fortification' + #13#10 + 'From territory: ' + IntToStr(iFrom)
    + #13#10 + 'To territory: ' + IntToStr(iTo)
    + #13#10 + 'Armies: ' + IntToStr(iArmies) + #13#10 + 'Error: ';
    // Validate the request
    if (iFrom > MAXTERRITORIES) or (arTerritory[iFrom].Owner <> iTurn) then
    begin
      sMsg := sMsg + 'Invalid "From" territory';
      ShowError(sMsg);
      exit;
    end;
    if (iTo < 1) or (iTo > MAXTERRITORIES) or (arTerritory[iTo].Owner <> iTurn)
    then begin
      sMsg := sMsg + 'Invalid "To" territory';
      ShowError(sMsg);
      exit;
    end;
    if not Confinante(iFrom, iTo) then begin
      sMsg := sMsg + 'Invalid "From->To"';
      ShowError(sMsg);
      exit;
    end;
    if (iArmies <= 0) or (iArmies > arTerritory[iFrom].Army - 1) then begin
      sMsg := sMsg + 'Invalid number of armies';
      ShowError(sMsg);
      exit;
    end;
    // Log
    if arPlayer[iTurn].KeepLog then
      ScriviLog('Fortification: troops move (' + IntToStr(iArmies)
        + ') from ' + arTerritory[iFrom].Name + ' to ' + arTerritory[iTo]
        .Name);
    // Move the troops
    inc(arTerritory[iTo].Army, iArmies);
    dec(arTerritory[iFrom].Army, iArmies);
    arPlayer[iTurn].FlMove := true;
    // Update the display
    DisplayTerritory(iFrom);
    DisplayTerritory(iTo);
    UpdateStats;
    if not bTRSimCLI then
      Application.ProcessMessages;
  end
  else
    LogTRPDecision('Fortification: no move selected');

end;

// ******************************
// * COMPUTER GAME TURN SUPERVISOR *
// ******************************

// Execute the computer player's turn.
procedure ExecuteComputerTurn;
begin
  // update LastTurn for TRSim statistics
  arPlayer[iTurn].LastTurn := iTurnCounter;

  // load the script
  if not ScriptExec.LoadData(arPlayer[iTurn].Code) then begin
    if bTRSimCLI then begin
      fSimRun.SimLog('Player: ' + arPlayer[iTurn].Name + #13#10 +
        'Error: script loading failed');
      uSimStatus := ssError;
      bStopASAP := true;
    end
    else
      MessageDlg('Player: ' + arPlayer[iTurn].Name + #13#10 +
        'Error: script loading failed', mtError, [mbOk], 0);
    exit;
  end;

  // Create variables to pass parameters to the script executer
  tParamList := TIfList.Create; // Create the parameter list
  tParamToTerritory := CreateHeapVariant(ScriptExec.FindType2(btS32));
  tParamFromTerritory := CreateHeapVariant(ScriptExec.FindType2(btS32));
  tParamArmies := CreateHeapVariant(ScriptExec.FindType2(btS32));
  if (tParamToTerritory = nil) or (tParamFromTerritory = nil) or
  (tParamArmies = nil) then begin
    if bTRSimCLI then begin
      fSimRun.SimLog('Could not create script parameters.');
      uSimStatus := ssError;
      bStopASAP := true;
    end
    else
      MessageDlg('Could not create script parameters.', mtError, [mbOk], 0);
    exit;
  end;

  // Play a move according to state of the game
  case GameState of
    gsAssigning:
      CmpAssegnazione;
    gsDistributing:
      if arPlayer[iTurn].NewArmy > 0 then
        CmpCollocaArmate(1);
    gsPlaying: begin
        if arPlayer[iTurn].NewArmy > 0 then
          CmpCollocaArmate(arPlayer[iTurn].NewArmy);
        CmpAttacco;
        if iNPlayers > 1 then
          CmpTrasferimento;
      end;
  end;

  // Free parameter passing variables
  tParamList.Clear;
  tParamList.Add(tParamArmies);
  tParamList.Add(tParamToTerritory);
  tParamList.Add(tParamFromTerritory);
  FreePIFVariantList(tParamList);

end;

end.
