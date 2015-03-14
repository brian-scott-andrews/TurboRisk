unit Move;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Buttons, StdCtrls, ExtCtrls;

type
  TfMove = class(TForm)
    panFromTerr: TPanel;
    Label1: TLabel;
    Label2: TLabel;
    panFromArmies: TPanel;
    panToTerr: TPanel;
    panToArmies: TPanel;
    cmdOk: TBitBtn;
    cmdCancel: TBitBtn;
    SpeedButton1: TSpeedButton;
    SpeedButton2: TSpeedButton;
    SpeedButton3: TSpeedButton;
    SpeedButton4: TSpeedButton;
    SpeedButton6: TSpeedButton;
    SpeedButton7: TSpeedButton;
    SpeedButton8: TSpeedButton;
    SpeedButton9: TSpeedButton;
    cmdAll: TBitBtn;
    cmdBalance: TBitBtn;
    procedure FormShow(Sender: TObject);
    procedure MoveArmiesClick(Sender: TObject);
    procedure cmdOkClick(Sender: TObject);
    procedure cmdAllClick(Sender: TObject);
    procedure cmdBalanceClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure cmdCancelClick(Sender: TObject);
  private
    procedure UpdateDisplay;
  public
    iProv, iDest, iMinDest,
    iTf, iTt: integer;        // Territori Da e A attacco
  end;

var
  fMove: TfMove;

implementation

{$R *.DFM}

uses Globals, Main, Territ, Log;

procedure TfMove.FormShow(Sender: TObject);
begin
  // posizionamento dinamico finestra
  if arTerritory[iTf].Coord.X > fMain.Width div 2 then
    Left := fMain.Left + 18
  else
    Left := fMain.Left + 338;
  if arTerritory[iTf].Coord.Y > fMain.Height div 2 then
    Top := fMain.Top + 70
  else
    Top := fMain.Top + 290;
  // inizializzazione controlli
  iProv := arTerritory[iTf].Army;
  iDest := arTerritory[iTt].Army;
  iMinDest := iDest;
  panFromTerr.Caption := arTerritory[iTf].Name;
  panToTerr.Caption   := arTerritory[iTt].Name;
  UpdateDisplay;
end;

procedure TfMove.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if (ModalResult<>mrCancel) and arPlayer[iTurn].KeepLog then
    ScriviLog('Troops move (' + IntToStr(arTerritory[iTt].Army-iMinDest)
              + ') from ' + arTerritory[iTf].Name + ' to ' + arTerritory[iTt].Name);
end;

procedure TfMove.UpdateDisplay;
begin
  panFromArmies.Caption := IntToStr(iProv);
  panToArmies.Caption   := IntToStr(iDest);
end;

procedure TfMove.MoveArmiesClick(Sender: TObject);
var
  iMove: integer;
begin
 iMove := (Sender as TControl).Tag;
 if iProv-iMove<1 then iMove := iProv - 1;
 if iDest+iMove<iMinDest then iMove := iMinDest - iDest;
 dec(iProv,iMove);
 inc(idest,iMove);
 UpdateDisplay;
end;

procedure TfMove.cmdOkClick(Sender: TObject);
begin
  arTerritory[iTf].Army := iProv;
  arTerritory[iTt].Army := iDest;
  DisplayTerritory(iTf);
  DisplayTerritory(iTt);
  if arTerritory[iTt].Army=iMinDest then  // Se la situazione è quella iniziale
    ModalResult := mrCancel;              // non considero lo spostamento avvenuto
end;

procedure TfMove.cmdAllClick(Sender: TObject);
begin
  arTerritory[iTf].Army := 1;
  arTerritory[iTt].Army := iDest + iProv - 1;
  DisplayTerritory(iTf);
  DisplayTerritory(iTt);
  if arTerritory[iTt].Army=iMinDest then  // Se la situazione è quella iniziale
    ModalResult := mrCancel;              // non considero lo spostamento avvenuto
end;

procedure TfMove.cmdBalanceClick(Sender: TObject);
var
  iBal, iResto: integer;
begin
  iBal := (iProv + iDest) div 2;
  iResto := (iProv + iDest) mod 2;
  iProv := iBal;
  iDest := iBal + iResto;
  while iDest<iMinDest do begin
    inc(iDest);
    dec(iProv);
  end;
  arTerritory[iTf].Army := iProv;
  arTerritory[iTt].Army := iDest;
  DisplayTerritory(iTf);
  DisplayTerritory(iTt);
  if arTerritory[iTt].Army=iMinDest then  // Se la situazione è quella iniziale
    ModalResult := mrCancel;              // non considero lo spostamento avvenuto
end;

procedure TfMove.cmdCancelClick(Sender: TObject);
begin
  //
end;

end.
