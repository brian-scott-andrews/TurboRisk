unit Attack;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, Buttons, ExtCtrls;

type
  TfAttack = class(TForm)
    panFromTerr: TPanel;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    panFromArmies: TPanel;
    panFromPlayer: TPanel;
    panFromColor: TPanel;
    panToTerr: TPanel;
    panToArmies: TPanel;
    panToPlayer: TPanel;
    panToColor: TPanel;
    cmdAttack: TBitBtn;
    cmdRetreat: TBitBtn;
    cmdDoOrDie: TBitBtn;
    chkAutoMoveAll: TCheckBox;
    cmdAttackUntil1: TBitBtn;
    cboUntil1: TComboBox;
    lblUntil1: TLabel;
    cmdAttackUntil2: TBitBtn;
    lblUntil2: TLabel;
    cboUntil2: TComboBox;
    procedure FormShow(Sender: TObject);
    procedure cmdAttackClick(Sender: TObject);
    procedure cmdDoOrDieClick(Sender: TObject);
    procedure cmdAttackUntil1Click(Sender: TObject);
    procedure cmdAttackUntil2Click(Sender: TObject);
    procedure cboUntilKeyPress(Sender: TObject; var Key: Char);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
  private
    procedure UpdateDisplay;
  public
    iTf, iTt: integer; // Territori Da e A attacco
  end;

var
  fAttack: TfAttack;

implementation

{$R *.DFM}

uses Globals, Main, Territ, Stats;

procedure TfAttack.FormShow(Sender: TObject);
begin
  // size and controls depend on preferences
  if bPrefExpertAttack then begin
    cmdAttackUntil1.Visible := true;
    cmdAttackUntil2.Visible := true;
    lblUntil1.Visible := true;
    lblUntil2.Visible := true;
    cboUntil1.Visible := true;
    cboUntil2.Visible := true;
    Height := 254;
  end
  else begin
    cmdAttackUntil1.Visible := false;
    cmdAttackUntil2.Visible := false;
    lblUntil1.Visible := false;
    lblUntil2.Visible := false;
    cboUntil1.Visible := false;
    cboUntil2.Visible := false;
    Height := 186;
  end;
  // dynamic window position
  if arTerritory[iTf].Coord.X > fMain.Width div 2 then
    Left := fMain.Left + 18
  else
    Left := fMain.Left + 338;
  if arTerritory[iTf].Coord.Y > fMain.Height div 2 then
    Top := fMain.Top + 70
  else
    Top := fMain.Top + 290;
  // inizializzazione controlli
  panFromTerr.Caption := arTerritory[iTf].Name;
  panFromPlayer.Caption := arPlayer[iTurn].Name;
  panFromColor.Color := arPlayer[iTurn].Color;
  panToTerr.Caption := arTerritory[iTt].Name;
  panToPlayer.Caption := arPlayer[arTerritory[iTt].Owner].Name;
  panToColor.Color := arPlayer[arTerritory[iTt].Owner].Color;
  UpdateDisplay;
end;

procedure TfAttack.FormKeyPress(Sender: TObject; var Key: Char);
begin
  case Key of
    'A','a':
      cmdAttackClick(Sender);
    'D','d':
      cmdDoOrDieClick(Sender);
    'R','r':
      ModalResult := mrCancel;
    'M','m':
      cmdAttackUntil1Click(Sender);
    'E','e':
      cmdAttackUntil2Click(Sender);
  end;
end;

procedure TfAttack.UpdateDisplay;
begin
  panFromArmies.Caption := IntToStr(arTerritory[iTf].Army);
  panToArmies.Caption := IntToStr(arTerritory[iTt].Army);
  cmdAttack.Enabled := (arTerritory[iTf].Army > 1);
  cmdDoOrDie.Enabled := cmdAttack.Enabled;
end;

procedure TfAttack.cboUntilKeyPress(Sender: TObject; var Key: Char);
begin
  if not(Key in ['0' .. '9', #08]) then
    Key := #0;
end;

procedure TfAttack.cmdAttackClick(Sender: TObject);
begin
  if PerformAttack(iTf, iTt) then begin
    if chkAutoMoveAll.Checked then begin
      inc(arTerritory[iTt].Army, arTerritory[iTf].Army - 1);
      arTerritory[iTf].Army := 1;
      DisplayTerritory(iTf);
      DisplayTerritory(iTt);
      UpdateStats;
    end;
    ModalResult := mrOK;
  end
  else begin
    UpdateDisplay;
  end;
end;

procedure TfAttack.cmdDoOrDieClick(Sender: TObject);
var
  bConquista: boolean;
begin
  repeat
    bConquista := PerformAttack(iTf, iTt);
    UpdateDisplay;
    Application.ProcessMessages;
  until bConquista or (arTerritory[iTf].Army < 2);
  if bConquista then begin
    if chkAutoMoveAll.Checked then begin
      inc(arTerritory[iTt].Army, arTerritory[iTf].Army - 1);
      arTerritory[iTf].Army := 1;
      DisplayTerritory(iTf);
      DisplayTerritory(iTt);
      UpdateStats;
    end;
    ModalResult := mrOK;
  end
  else begin
    ModalResult := mrCancel;
  end;
end;

procedure TfAttack.cmdAttackUntil1Click(Sender: TObject);
var
  bConquista: boolean;
  iTarget: integer;
begin
  bConquista := false;
  iTarget := StrToIntDef(cboUntil1.Text, 0);
  while not bConquista and (arTerritory[iTf].Army >= 2) and
  (arTerritory[iTf].Army > iTarget) do begin
    bConquista := PerformAttack(iTf, iTt);
    UpdateDisplay;
    Application.ProcessMessages;
  end;
  if bConquista then begin
    if chkAutoMoveAll.Checked then begin
      inc(arTerritory[iTt].Army, arTerritory[iTf].Army - 1);
      arTerritory[iTf].Army := 1;
      DisplayTerritory(iTf);
      DisplayTerritory(iTt);
      UpdateStats;
    end;
    ModalResult := mrOK;
  end
  else begin
    ModalResult := mrCancel;
  end;
end;

procedure TfAttack.cmdAttackUntil2Click(Sender: TObject);
var
  bConquista: boolean;
  iTarget: integer;
begin
  bConquista := false;
  iTarget := StrToIntDef(cboUntil2.Text, 0);
  while not bConquista and (arTerritory[iTf].Army >= 2) and
  (arTerritory[iTt].Army > iTarget) do begin
    bConquista := PerformAttack(iTf, iTt);
    UpdateDisplay;
    Application.ProcessMessages;
  end;
  if bConquista then begin
    if chkAutoMoveAll.Checked then begin
      inc(arTerritory[iTt].Army, arTerritory[iTf].Army - 1);
      arTerritory[iTf].Army := 1;
      DisplayTerritory(iTf);
      DisplayTerritory(iTt);
      UpdateStats;
    end;
    ModalResult := mrOK;
  end
  else begin
    ModalResult := mrCancel;
  end;
end;

end.
