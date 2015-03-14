unit SimCPULog;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, Globals;

type

  TCPUdata = record
    Phases, // number of phases played
    Calls, // number of calls
    Time: integer; // total time (milliseconds)
  end;

  TPlayerStats = record
    Name: string; // name
    CPUdata: array [TRoutine] of TCPUdata;
  end;

  TfSimCPULog = class(TForm)
    Panel1: TPanel;
    lstDetail: TListView;
    lstSummary: TListView;

    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure lstSummarySelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
  private
    aPStats: array of TPlayerStats;
    procedure LoadLogFile;
    function DecodeRoutine(uRoutine: TRoutine): string;
  public
    sLogFileName: string;
  end;

var
  fSimCPULog: TfSimCPULog;

implementation

{$R *.dfm}

uses IniFiles, StrUtils, StdPas;

procedure TfSimCPULog.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
end;

procedure TfSimCPULog.FormDestroy(Sender: TObject);
begin
  fSimCPULog := nil;
end;

procedure TfSimCPULog.FormShow(Sender: TObject);
begin
  Caption := 'CPU usage analysis: ' + sLogFileName;
  LoadLogFile;
end;

procedure TfSimCPULog.LoadLogFile;
var
  LogFile: TIniFile;
  TRPs: TStringList;
  i: integer;
  uRoutine: TRoutine;
  sRoutine: string;

begin
  if not FileExists(sG_AppPath + sLogFileName) then begin
    MsgErr('Log file "' + sLogFileName + '" not found.');
    exit;
  end;
  // open log file
  LogFile := TIniFile.Create(sG_AppPath + sLogFileName);
  TRPs := TStringList.Create;
  try
    with LogFile do begin
      ReadSections(TRPs); // read TRP names in log file
      TRPs.Sorted := true; // sort them by name
      lstSummary.Clear; // clear analysis
      SetLength(aPStats, TRPs.Count);
      // analysis
      for i := 0 to TRPs.Count - 1 do begin
        with lstSummary.Items.Add do begin
          aPStats[i].Name := TRPs[i];
          Caption := TRPs[i];
          for uRoutine := rtAssignment to rtFortification do begin
            sRoutine := IntToStr(ord(uRoutine));
            aPStats[i].CPUdata[uRoutine].Phases := ReadInteger(TRPs[i],
              'Phases' + sRoutine, 0);
            aPStats[i].CPUdata[uRoutine].Calls := ReadInteger(TRPs[i],
              'Calls' + sRoutine, 0);
            aPStats[i].CPUdata[uRoutine].Time := ReadInteger(TRPs[i],
              'Time' + sRoutine, 0);
            if aPStats[i].CPUdata[uRoutine].Phases > 0 then
              SubItems.Add(FormatFloat('0.0',
                  aPStats[i].CPUdata[uRoutine].Time / aPStats[i].CPUdata
                  [uRoutine].Phases))
            else
              SubItems.Add('-');
          end;
        end;
      end;
      // legenda
      (* txtCPULog.Lines.Add('');
        txtCPULog.Lines.Add(
        'Phases = number of times the TRP has entered a phase (attack, occupation...)');
        txtCPULog.Lines.Add(
        'Calls = number of times the TRP code has been called during the phase');
        txtCPULog.Lines.Add('T/Ph = average time per phase (milliseconds)');
        txtCPULog.Lines.Add('C/Ph = average number of calls per phase');
        txtCPULog.Lines.Add('T/C = average time per call (milliseconds)');
        *)
    end;
  finally
    LogFile.Free;
    TRPs.Free;
  end;
end;

procedure TfSimCPULog.lstSummarySelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
var
  iP: integer;
  uRoutine: TRoutine;
begin
  lstDetail.Clear;
  if lstSummary.ItemIndex < 0 then begin
    lstDetail.Columns[0].Caption := '';
    exit;
  end;
  // populate player's list
  iP := lstSummary.ItemIndex;
  lstDetail.Columns[0].Caption := aPStats[iP].Name;
  with lstDetail.Items.Add do begin
    Caption := 'Phases';
    for uRoutine := rtAssignment to rtFortification do begin
      with aPStats[iP].CPUdata[uRoutine] do begin
        SubItems.Add(FormatFloat(',0', Phases));
      end;
    end;
  end;
  with lstDetail.Items.Add do begin
    Caption := 'Calls';
    for uRoutine := rtAssignment to rtFortification do begin
      with aPStats[iP].CPUdata[uRoutine] do begin
        SubItems.Add(FormatFloat(',0', Calls));
      end;
    end;
  end;
  with lstDetail.Items.Add do begin
    Caption := 'Time (ms)';
    for uRoutine := rtAssignment to rtFortification do begin
      with aPStats[iP].CPUdata[uRoutine] do begin
        SubItems.Add(FormatFloat(',0', Time));
      end;
    end;
  end;
  with lstDetail.Items.Add do begin
    Caption := 'Time/Phase (ms)';
    for uRoutine := rtAssignment to rtFortification do begin
      with aPStats[iP].CPUdata[uRoutine] do begin
        if Phases > 0 then
          SubItems.Add(FormatFloat('0.0', Time / Phases))
        else
          SubItems.Add('-');
      end;
    end;
  end;
  with lstDetail.Items.Add do begin
    Caption := 'Time/Call (ms)';
    for uRoutine := rtAssignment to rtFortification do begin
      with aPStats[iP].CPUdata[uRoutine] do begin
        if Calls > 0 then
          SubItems.Add(FormatFloat('0.0', Time / Calls))
        else
          SubItems.Add('-');
      end;
    end;
  end;
  with lstDetail.Items.Add do begin
    Caption := 'Calls/Phase';
    for uRoutine := rtAssignment to rtFortification do begin
      with aPStats[iP].CPUdata[uRoutine] do begin
        if Phases > 0 then
          SubItems.Add(FormatFloat('0.0', Calls / Phases))
        else
          SubItems.Add('-');
      end;
    end;
  end;
end;

function TfSimCPULog.DecodeRoutine(uRoutine: TRoutine): string;
begin
  case uRoutine of
    rtAssignment:
      result := 'Assignment';
    rtPlacement:
      result := 'Placement';
    rtAttack:
      result := 'Attack';
    rtOccupation:
      result := 'Occupation';
    rtFortification:
      result := 'Fortification';
  end;
end;

end.
