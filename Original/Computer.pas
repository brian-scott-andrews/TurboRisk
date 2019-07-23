unit Computer;

{$MODE Delphi}

interface

// Esecuzione mossa computer
procedure EseguiTurnoComputer;

implementation

uses LCLIntf, LCLType, LMessages, Forms, Controls, SysUtils, Dialogs,
  uPSRuntime, uPSUtils, {StdPas,}
  Main, Globals, Territ, Stats, Log, TRPError, Sim;

var

  // Varibles used to pass parameters to the script executer
  tParamToTerritory, tParamFromTerritory, tParamArmies: PPSVariant;
  tParamList: TPSList; // The parameter list

  iStartTime, iEndTime: Int64; // CPU timing for TRSim

procedure ShowError(sMsg: string);
begin
  if not bG_TRSim then begin // TurboRisk
    fTRPError.txtMsg.Text := sMsg;
    case fTRPError.ShowModal of
      mrYes: begin
          // dump memory if required
          sMsg := StrTran(sMsg, #13#10, '\n');
          if not SysUtils.DirectoryExists(sG_AppPath + '\Dump') then begin
            if not CreateDir(sG_AppPath + '\Dump') then
              raise Exception.Create('Cannot create ' + sG_AppPath + '\Dump');
          end;
          SaveGame(sG_AppPath + 'Dump\trdump_' + FormatDateTime
            ('yyyymmdd_hhmmss', Now) + '.trd', sMsg);
        end;
      mrAbort: begin
          bStopASAP := true;
          bCloseASAP := true;
        end;
    end;
  end
  else begin // TRSim
    if fSim.chkErrorDump.Checked then begin
      // dump memory if required
      sMsg := StrTran(sMsg, #13#10, '\n');
      if not SysUtils.DirectoryExists(sG_AppPath + '\Dump') then begin
        if not CreateDir(sG_AppPath + '\Dump') then
          raise Exception.Create('Cannot create ' + sG_AppPath + '\Dump');
      end;
      SaveGame(sG_AppPath + 'Dump\trdump_' + FormatDateTime('yyyymmdd_hhmmss',
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

procedure CPU_Call(uRoutine: TRoutine; iTicks: Int64);
begin
  arPlayer[iTurn].aCPU[uRoutine].iTime := arPlayer[iTurn].aCPU[uRoutine]
  .iTime + iTicks;
  inc(arPlayer[iTurn].aCPU[uRoutine].iCalls);
end;

// ************************************************************
// * ROUTINES DI ASSEGNAZIONE INIZIALE TERRITORI - ASSIGNMENT *
// ************************************************************

// Scelta territorio per assegnazione iniziale
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
    QueryPerformanceCounter(iStartTime); // get initial time
    ScriptExec.RunProc(tParamList, ScriptExec.GetProc('ASSIGNMENT'));
    QueryPerformanceCounter(iEndTime); // get final time
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

  // Preparazione messaggio di errore
  sMsg := 'Player: ' + arPlayer[iTurn].Name + #13#10 + 'Routine: Assignment' +
  #13#10 + 'To territory: ' + IntToStr(iTo) + #13#10 + 'Error: ';
  // Verifica validità richiesta
  if (iTo < 1) or (iTo > MAXTERRITORIES) or (arTerritory[iTo].Owner <> 0) then
  begin
    sMsg := sMsg + 'Invalid "To" territory';
    ShowError(sMsg);
    iTo := 0;
  end;
  if iTo > 0 then begin
    // Assegnazione
    AssegnaTerritorio(iTo, iTurn);
    inc(arTerritory[iTo].Army);
    dec(arPlayer[iTurn].NewArmy);
    // Log
    if arPlayer[iTurn].KeepLog then
      ScriviLog(arTerritory[iTo].Name + ' assigned.');
    // Aggiornamento display e statistiche
    DisplayTerritory(iTo);
    UpdateStats;
    Application.ProcessMessages;
  end;
end;

// ***********************************************
// * ROUTINES DI COLLOCAZIONE ARMATE - PLACEMENT *
// ***********************************************

// Scelta collocazione nuova armata sui propri territori
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
      QueryPerformanceCounter(iStartTime); // get initial time
      ScriptExec.RunProc(tParamList, ScriptExec.GetProc('PLACEMENT'));
      QueryPerformanceCounter(iEndTime); // get final time
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

    // Preparazione messaggio di errore
    sMsg := 'Player: ' + arPlayer[iTurn].Name + #13#10 + 'Routine: Placement' +
    #13#10 + 'To territory: ' + IntToStr(iTo) + #13#10 + 'Error: ';
    // Verifica validità richiesta
    if (iTo < 1) or (iTo > MAXTERRITORIES) or (arTerritory[iTo].Owner <> iTurn)
    then begin
      sMsg := sMsg + 'Invalid "To" territory';
      ShowError(sMsg);
      iTo := 0;
    end;
    if iTo > 0 then begin
      // Log
      if arPlayer[iTurn].KeepLog then
        ScriviLog('Army placement in ' + arTerritory[iTo].Name);
      // Collocazione
      CollocaArmata(iTo, iTurn, 1);
    end
    else begin
      arPlayer[iTurn].NewArmy := 0; // force 0 new army to place
      break; // interruzione ciclo per errori
    end;

    dec(iDaCollocare);
  end;

end;

// ***************************************************************
// * ROUTINES DI OCCUPAZIONE TERRITORIO CONQUISTATO - OCCUPATION *
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
    QueryPerformanceCounter(iStartTime); // get initial time
    ScriptExec.RunProc(tParamList, ScriptExec.GetProc('OCCUPATION'));
    QueryPerformanceCounter(iEndTime); // get final time
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

  // Se richiesto spostamento...
  if iArmies > 0 then begin
    // Preparazione messaggio di errore
    sMsg := 'Player: ' + arPlayer[iTurn].Name + #13#10 +
    'Routine: Occupation' + #13#10 + 'From territory: ' + arTerritory[iFrom]
    .Name + #13#10 + 'To territory: ' + arTerritory[iTo].Name + #13#10 +
    'Armies: ' + IntToStr(iArmies) + #13#10 + 'Error: ';
    // Verifica validità richiesta
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
    // Spostamento
    inc(arTerritory[iTo].Army, iArmies);
    dec(arTerritory[iFrom].Army, iArmies);
    // Aggiornamento video
    DisplayTerritory(iFrom);
    DisplayTerritory(iTo);
    UpdateStats;
    Application.ProcessMessages;
  end;
end;

// ********************************
// * ROUTINES DI ATTACCO - ATTACK *
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
      QueryPerformanceCounter(iStartTime); // get initial time
      ScriptExec.RunProc(tParamList, ScriptExec.GetProc('ATTACK'));
      QueryPerformanceCounter(iEndTime); // get final time
      CPU_Call(rtAttack, iEndTime - iStartTime);
      // get back value of var parameters
      iFrom := VGetInt(tParamFromTerritory);
      iTo := VGetInt(tParamToTerritory);
    except
      on e: Exception do begin
        sMsg := 'Player: ' + arPlayer[iTurn].Name + #13#10 +
        'Routine: Attack' + #13#10 + 'Error: ' + e.message;
        ShowError(sMsg);
        MessageDlg(sMsg, mtError, [mbOk], 0);
        exit;
      end;
    end;

    // Se richiesto attacco...
    if iFrom > 0 then begin
      // Preparazione messaggio di errore
      sMsg := 'Player: ' + arPlayer[iTurn].Name + #13#10 + 'Routine: Attack' +
      #13#10 + 'From territory: ' + IntToStr(iFrom)
      + #13#10 + 'To territory: ' + IntToStr(iTo)
      + #13#10 + 'Error: ';
      // Verifica validità richiesta
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
      // Attacco
      bEsito := PerformAttack(iFrom, iTo);
      // Aggiornamento display
      UpdateStats;
      Application.ProcessMessages;
      // Conseguenze dellattacco riuscito
      if bEsito then begin
        // uscita immediata se vittoria
        if iNPlayers < 2 then
          exit;
        // territorio conquistato, spostamento conseguente
        if arTerritory[iFrom].Army > 1 then begin
          CmpOccupa(iFrom, iTo);
        end;
        // collocazione eventuali armate conquistate
        if bEliminatedPlayer then begin
          if RImmediateTrade then
            AssignNewArmies(true);
          if arPlayer[iTurn].NewArmy > 0 then begin
            CmpCollocaArmate(arPlayer[iTurn].NewArmy);
          end;
        end;
      end;
    end;

  until iFrom = 0;
end;

// *********************************************
// * ROUTINES DI TRASFERIMENTO - FORTIFICATION *
// *********************************************

procedure CmpTrasferimento;
var
  iFrom, iTo, iArmies: integer;
  sMsg: string;
begin
  // protezione contro trasferimenti multipli
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
    QueryPerformanceCounter(iStartTime); // get initial time
    ScriptExec.RunProc(tParamList, ScriptExec.GetProc('FORTIFICATION'));
    QueryPerformanceCounter(iEndTime); // get final time
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

  // Se richiesto spostamento...
  if iFrom > 0 then begin
    // Preparazione messaggio di errore
    sMsg := 'Player: ' + arPlayer[iTurn].Name + #13#10 +
    'Routine: Fortification' + #13#10 + 'From territory: ' + IntToStr(iFrom)
    + #13#10 + 'To territory: ' + IntToStr(iTo)
    + #13#10 + 'Armies: ' + IntToStr(iArmies) + #13#10 + 'Error: ';
    // Verifica validità richiesta
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
    // Spostamento
    inc(arTerritory[iTo].Army, iArmies);
    dec(arTerritory[iFrom].Army, iArmies);
    arPlayer[iTurn].FlMove := true;
    // Aggiornamento video
    DisplayTerritory(iFrom);
    DisplayTerritory(iTo);
    UpdateStats;
    Application.ProcessMessages;
  end;

end;

// ******************************
// * SUPERVISORE GIOCO COMPUTER *
// ******************************

// Esecuzione mossa computer
procedure EseguiTurnoComputer;
begin
  // update LastTurn for TRSim statistics
  arPlayer[iTurn].LastTurn := iTurnCounter;

  // load the script
  if not ScriptExec.LoadData(arPlayer[iTurn].Code) then begin
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
