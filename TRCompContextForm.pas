unit TRCompContextForm;

{$MODE Delphi}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Grids, Dialogs,
  Globals;

type
  TfTRCompContext = class(TForm)
  private
    fPlayers: TStringGrid;
    fTerritories: TStringGrid;
    fBuffers: TStringGrid;
    fCurrentPlayer: TComboBox;
    fConquest: TCheckBox;
    fCardRule: TComboBox;
    fMessage: TMemo;
    procedure LoadContext(const Context: TTRCompContext);
    function SaveContext(var Context: TTRCompContext): Boolean;
  public
    constructor Create(AOwner: TComponent); override;
  end;

function EditTRCompContext(var Context: TTRCompContext): Boolean;

implementation

constructor TfTRCompContext.Create(AOwner: TComponent);
var
  Pages: TPageControl;
  Tab: TTabSheet;
  Buttons: TPanel;
  i: Integer;
begin
  inherited CreateNew(AOwner);
  Caption := 'TRComp - Execution Context';
  Width := 850;
  Height := 600;
  Position := poScreenCenter;

  Pages := TPageControl.Create(Self);
  Pages.Parent := Self;
  Pages.Align := alClient;

  Tab := TTabSheet.Create(Self);
  Tab.PageControl := Pages;
  Tab.Caption := 'Players';
  fPlayers := TStringGrid.Create(Self);
  fPlayers.Parent := Tab;
  fPlayers.Align := alClient;
  fPlayers.FixedRows := 1;
  fPlayers.FixedCols := 1;
  fPlayers.ColCount := 9;
  fPlayers.RowCount := MAXPLAYERS + 1;
  fPlayers.Options := fPlayers.Options + [goEditing, goAlwaysShowEditor];
  fPlayers.Cells[0, 0] := 'Player';
  fPlayers.Cells[1, 0] := 'Active (1/0)';
  fPlayers.Cells[2, 0] := 'Name';
  fPlayers.Cells[3, 0] := 'Program';
  fPlayers.Cells[4, 0] := 'New armies';
  fPlayers.Cells[5, 0] := 'Infantry';
  fPlayers.Cells[6, 0] := 'Artillery';
  fPlayers.Cells[7, 0] := 'Cavalry';
  fPlayers.Cells[8, 0] := 'Jokers';
  fPlayers.ColWidths[0] := 55;
  fPlayers.ColWidths[1] := 95;
  fPlayers.ColWidths[2] := 140;
  fPlayers.ColWidths[3] := 140;
  for i := 4 to 8 do
    fPlayers.ColWidths[i] := 80;
  for i := 1 to MAXPLAYERS do
    fPlayers.Cells[0, i] := IntToStr(i);

  Tab := TTabSheet.Create(Self);
  Tab.PageControl := Pages;
  Tab.Caption := 'Map';
  fTerritories := TStringGrid.Create(Self);
  fTerritories.Parent := Tab;
  fTerritories.Align := alClient;
  fTerritories.FixedRows := 1;
  fTerritories.FixedCols := 0;
  fTerritories.ColCount := 3;
  fTerritories.RowCount := MAXTERRITORIES + 1;
  fTerritories.Options := fTerritories.Options + [goEditing, goAlwaysShowEditor];
  fTerritories.Cells[0, 0] := 'Territory';
  fTerritories.Cells[1, 0] := 'Owner (0-10)';
  fTerritories.Cells[2, 0] := 'Armies';
  fTerritories.ColWidths[0] := 250;
  fTerritories.ColWidths[1] := 120;
  fTerritories.ColWidths[2] := 100;

  Tab := TTabSheet.Create(Self);
  Tab.PageControl := Pages;
  Tab.Caption := 'Buffers and message';
  fBuffers := TStringGrid.Create(Self);
  fBuffers.Parent := Tab;
  fBuffers.Align := alLeft;
  fBuffers.Width := 220;
  fBuffers.FixedRows := 1;
  fBuffers.FixedCols := 1;
  fBuffers.ColCount := 2;
  fBuffers.RowCount := MAXBUFFER + 1;
  fBuffers.Options := fBuffers.Options + [goEditing, goAlwaysShowEditor];
  fBuffers.Cells[0, 0] := 'Buffer';
  fBuffers.Cells[1, 0] := 'Value';
  fBuffers.ColWidths[0] := 90;
  fBuffers.ColWidths[1] := 110;
  for i := 1 to MAXBUFFER do
    fBuffers.Cells[0, i] := IntToStr(i);
  fMessage := TMemo.Create(Self);
  fMessage.Parent := Tab;
  fMessage.Align := alClient;
  fMessage.Lines.Add('Optional message for this execution context.');

  Buttons := TPanel.Create(Self);
  Buttons.Parent := Self;
  Buttons.Align := alBottom;
  Buttons.Height := 78;
  Buttons.BevelOuter := bvNone;
  fCurrentPlayer := TComboBox.Create(Self);
  fCurrentPlayer.Parent := Buttons;
  fCurrentPlayer.Left := 8;
  fCurrentPlayer.Top := 8;
  fCurrentPlayer.Width := 130;
  fCurrentPlayer.Style := csDropDownList;
  for i := 1 to MAXPLAYERS do
    fCurrentPlayer.Items.Add('Player ' + IntToStr(i));
  fConquest := TCheckBox.Create(Self);
  fConquest.Parent := Buttons;
  fConquest.Left := 150;
  fConquest.Top := 12;
  fConquest.Caption := 'Conquered this turn';
  fCardRule := TComboBox.Create(Self);
  fCardRule.Parent := Buttons;
  fCardRule.Left := 310;
  fCardRule.Top := 8;
  fCardRule.Width := 190;
  fCardRule.Style := csDropDownList;
  fCardRule.Items.Add('Progressive card trades');
  fCardRule.Items.Add('Combination card trades');
  with TButton.Create(Self) do begin
    Parent := Buttons;
    Caption := 'Cancel';
    ModalResult := mrCancel;
    SetBounds(650, 8, 82, 30);
  end;
  with TButton.Create(Self) do begin
    Parent := Buttons;
    Caption := 'Use Context';
    Default := True;
    ModalResult := mrOk;
    SetBounds(740, 8, 92, 30);
  end;
end;

procedure TfTRCompContext.LoadContext(const Context: TTRCompContext);
var
  i, iTerritory: Integer;
begin
  fCurrentPlayer.ItemIndex := Context.CurrentPlayer - 1;
  fConquest.Checked := Context.Conquest;
  if Context.CardTradeByCombination then
    fCardRule.ItemIndex := 1
  else
    fCardRule.ItemIndex := 0;
  for i := 1 to MAXPLAYERS do begin
    fPlayers.Cells[1, i] := IntToStr(Ord(Context.PlayerActive[i]));
    fPlayers.Cells[2, i] := Context.PlayerName[i];
    fPlayers.Cells[3, i] := Context.PlayerProgram[i];
    fPlayers.Cells[4, i] := IntToStr(Context.PlayerNewArmies[i]);
    fPlayers.Cells[5, i] := IntToStr(Context.PlayerCards[i, caInf]);
    fPlayers.Cells[6, i] := IntToStr(Context.PlayerCards[i, caArt]);
    fPlayers.Cells[7, i] := IntToStr(Context.PlayerCards[i, caCav]);
    fPlayers.Cells[8, i] := IntToStr(Context.PlayerCards[i, caJok]);
  end;
  for iTerritory := 1 to MAXTERRITORIES do begin
    fTerritories.Cells[0, iTerritory] := arTerritory[iTerritory].Name;
    fTerritories.Cells[1, iTerritory] :=
      IntToStr(Context.TerritoryOwner[iTerritory]);
    fTerritories.Cells[2, iTerritory] :=
      IntToStr(Context.TerritoryArmies[iTerritory]);
  end;
  for i := 1 to MAXBUFFER do
    fBuffers.Cells[1, i] := FloatToStr(Context.Buffers[i]);
  fMessage.Lines.Text := Context.Message;
end;

function TfTRCompContext.SaveContext(var Context: TTRCompContext): Boolean;
var
  i, iTerritory: Integer;
  iValue, iOwner: Integer;
  dValue: Double;
begin
  Result := False;
  if fCurrentPlayer.ItemIndex < 0 then begin
    MessageDlg('Select the current player.', mtError, [mbOk], 0);
    Exit;
  end;
  Context.CurrentPlayer := fCurrentPlayer.ItemIndex + 1;
  if fCardRule.ItemIndex < 0 then begin
    MessageDlg('Select a card trade rule.', mtError, [mbOk], 0);
    Exit;
  end;
  Context.CardTradeByCombination := fCardRule.ItemIndex = 1;
  Context.Conquest := fConquest.Checked;
  for i := 1 to MAXPLAYERS do begin
    if not TryStrToInt(fPlayers.Cells[1, i], iValue) or
       not (iValue in [0, 1]) then begin
      MessageDlg('Player ' + IntToStr(i) +
        ' Active must be 0 or 1.', mtError, [mbOk], 0);
      Exit;
    end;
    Context.PlayerActive[i] := iValue = 1;
    Context.PlayerName[i] := fPlayers.Cells[2, i];
    Context.PlayerProgram[i] := fPlayers.Cells[3, i];
    if not TryStrToInt(fPlayers.Cells[4, i], Context.PlayerNewArmies[i]) then begin
      MessageDlg('Player ' + IntToStr(i) +
        ' has an invalid new-armies value.', mtError, [mbOk], 0);
      Exit;
    end;
    for iValue := Ord(Low(TCard)) to Ord(High(TCard)) do begin
      if not TryStrToInt(fPlayers.Cells[5 + iValue, i], iOwner) or
         (iOwner < 0) then begin
        MessageDlg('Player ' + IntToStr(i) +
          ' has an invalid card count.', mtError, [mbOk], 0);
        Exit;
      end;
      Context.PlayerCards[i, TCard(iValue)] := iOwner;
    end;
  end;
  if not Context.PlayerActive[Context.CurrentPlayer] then begin
    MessageDlg('The current player must be active.', mtError, [mbOk], 0);
    Exit;
  end;
  for iTerritory := 1 to MAXTERRITORIES do begin
    if not TryStrToInt(fTerritories.Cells[1, iTerritory], iOwner) or
       (iOwner < 0) or (iOwner > MAXPLAYERS) then begin
      MessageDlg('Territory ' + fTerritories.Cells[0, iTerritory] +
        ' must have an owner from 0 to ' + IntToStr(MAXPLAYERS) + '.',
        mtError, [mbOk], 0);
      Exit;
    end;
    if not TryStrToInt(fTerritories.Cells[2, iTerritory], iValue) or
       (iValue < 0) then begin
      MessageDlg('Territory ' + fTerritories.Cells[0, iTerritory] +
        ' has an invalid army count.', mtError, [mbOk], 0);
      Exit;
    end;
    Context.TerritoryOwner[iTerritory] := iOwner;
    Context.TerritoryArmies[iTerritory] := iValue;
  end;
  for i := 1 to MAXBUFFER do begin
    if not TryStrToFloat(fBuffers.Cells[1, i], dValue) then begin
      MessageDlg('Buffer ' + IntToStr(i) +
        ' has an invalid value.', mtError, [mbOk], 0);
      Exit;
    end;
    Context.Buffers[i] := dValue;
  end;
  Context.Message := fMessage.Lines.Text;
  Result := True;
end;

function EditTRCompContext(var Context: TTRCompContext): Boolean;
var
  Form: TfTRCompContext;
begin
  Form := TfTRCompContext.Create(nil);
  try
    Form.LoadContext(Context);
    Result := Form.ShowModal = mrOk;
    if Result then
      Result := Form.SaveContext(Context);
  finally
    Form.Free;
  end;
end;

end.
