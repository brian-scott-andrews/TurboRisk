unit TRCompForm;

{$MODE Delphi}

interface

uses
  Classes, SysUtils, Variants, Forms, Controls, StdCtrls, ExtCtrls, Dialogs,
  ComCtrls, Menus, Grids, IniFiles, SynEdit, SynHighlighterPas, Globals;

type
  TfTRComp = class(TForm)
  private
    fCurrentFile: string;
    fLoading: Boolean;
    fModified: Boolean;
    fSource: TSynEdit;
    fDiagnostics: TMemo;
    fResultsPanel: TPanel;
    fLeftPanel: TPanel;
    fStatus: TLabel;
    fApiTree: TTreeView;
    fRoutineList: TListBox;
    fContext: TTRCompContext;
    fOpenDialog: TOpenDialog;
    fSaveDialog: TSaveDialog;
    fPascalHighlighter: TSynPasSyn;
    fRefreshingRoutines: Boolean;
    procedure AddButton(Parent: TWinControl; const sCaption: string;
      OnClick: TNotifyEvent);
    procedure AddApiCategory(const sCategory, sNames: string);
    procedure DoOpen(Sender: TObject);
    procedure DoSave(Sender: TObject);
    procedure DoSaveAs(Sender: TObject);
    procedure DoCompile(Sender: TObject);
    procedure DoRun(Sender: TObject);
    procedure DoAppExit(Sender: TObject);
    procedure DoUndo(Sender: TObject);
    procedure DoRedo(Sender: TObject);
    procedure DoCut(Sender: TObject);
    procedure DoCopy(Sender: TObject);
    procedure DoPaste(Sender: TObject);
    procedure DoApiHelp(Sender: TObject);
    procedure ApiDoubleClick(Sender: TObject);
    procedure RoutineDoubleClick(Sender: TObject);
    procedure DiagnosticDoubleClick(Sender: TObject);
    procedure SourceChanged(Sender: TObject);
    procedure RefreshRoutineList;
    function GetSelectedRoutine: string;
    procedure UpdateCaption;
    function ConfirmDiscardChanges: Boolean;
    function SaveCurrentFile: Boolean;
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  fTRComp: TfTRComp;

implementation

uses LCLType, LCLIntf, Math, Territ, TRCompContextForm;

type
  TTRoutineParameter = record
    Name: string;
    DataType: string;
    ByReference: Boolean;
  end;
  TTRoutineParameters = array of TTRoutineParameter;

procedure AddMenuCommand(Parent: TMenuItem; const sCaption: string;
  iKey: Word; OnClick: TNotifyEvent);
var
  Item: TMenuItem;
begin
  Item := TMenuItem.Create(Parent.Owner);
  Item.Caption := sCaption;
  Item.OnClick := OnClick;
  if iKey = VK_F1 then
    Item.ShortCut := Menus.ShortCut(iKey, [])
  else if iKey <> 0 then
    Item.ShortCut := Menus.ShortCut(iKey, [ssCtrl]);
  Parent.Add(Item);
end;

function IsPascalIdentifierChar(c: Char): Boolean;
begin
  Result := (c in ['A'..'Z']) or (c in ['a'..'z']) or
    (c in ['0'..'9']) or (c = '_');
end;

function GetRoutineDeclaration(const sSource, sRoutine: string;
  out sDeclaration: string; out Parameters: TTRoutineParameters;
  out sReturnType: string): Boolean;
var
  Lines, Names, Groups: TStringList;
  i, j, iKeyword, iNameStart, iNameEnd, iOpen, iClose, iColon,
  iGroup, iModifier, iParam: Integer;
  sLine, sHeader, sRoutineName, sGroup, sNames, sType, sModifier: string;
  bByReference: Boolean;
  Parameter: TTRoutineParameter;
  Modifiers: array [0 .. 2] of string;
begin
  Result := False;
  sDeclaration := '';
  sReturnType := '';
  SetLength(Parameters, 0);
  Lines := TStringList.Create;
  Names := TStringList.Create;
  Groups := TStringList.Create;
  Modifiers[0] := 'var ';
  Modifiers[1] := 'out ';
  Modifiers[2] := 'const ';
  try
    Lines.Text := sSource;
    for i := 0 to Lines.Count - 1 do begin
      sLine := TrimLeft(Lines[i]);
      if CompareText(Copy(sLine, 1, 10), 'procedure ') = 0 then
        iKeyword := 11
      else if CompareText(Copy(sLine, 1, 9), 'function ') = 0 then
        iKeyword := 10
      else
        Continue;
      iNameStart := iKeyword;
      iNameEnd := iNameStart;
      while (iNameEnd <= Length(sLine)) and
        IsPascalIdentifierChar(sLine[iNameEnd]) do
        Inc(iNameEnd);
      sRoutineName := Copy(sLine, iNameStart, iNameEnd - iNameStart);
      if CompareText(sRoutineName, sRoutine) <> 0 then
        Continue;
      sHeader := sLine;
      j := i + 1;
      while (Pos(';', sHeader) = 0) and (j < Lines.Count) do begin
        sHeader := sHeader + ' ' + Trim(Lines[j]);
        Inc(j);
      end;
      sDeclaration := sHeader;
      iOpen := Pos('(', sHeader);
      iClose := LastDelimiter(')', sHeader);
      if (iOpen > 0) and (iClose > iOpen) then begin
        Groups.StrictDelimiter := True;
        Groups.Delimiter := ';';
        Groups.DelimitedText := Copy(sHeader, iOpen + 1, iClose - iOpen - 1);
        for iGroup := 0 to Groups.Count - 1 do begin
          sGroup := Trim(Groups[iGroup]);
          bByReference := False;
          for iModifier := Low(Modifiers) to High(Modifiers) do begin
            sModifier := Modifiers[iModifier];
            if CompareText(Copy(sGroup, 1, Length(sModifier)), sModifier) = 0 then begin
              bByReference := CompareText(sModifier, 'var ') = 0;
              Delete(sGroup, 1, Length(sModifier));
              Break;
            end;
          end;
          iColon := Pos(':', sGroup);
          if iColon = 0 then
            Continue;
          sNames := Trim(Copy(sGroup, 1, iColon - 1));
          sType := Trim(Copy(sGroup, iColon + 1, MaxInt));
          Names.StrictDelimiter := True;
          Names.Delimiter := ',';
          Names.DelimitedText := sNames;
          for iParam := 0 to Names.Count - 1 do begin
            Parameter.Name := Trim(Names[iParam]);
            Parameter.DataType := sType;
            Parameter.ByReference := bByReference;
            SetLength(Parameters, Length(Parameters) + 1);
            Parameters[High(Parameters)] := Parameter;
          end;
        end;
      end;
      iColon := LastDelimiter(':', sHeader);
      if ((iClose = 0) and (iColon > iNameEnd - iNameStart)) or
         (iColon > iClose) then
        sReturnType := Trim(Copy(sHeader, iColon + 1,
          Pos(';', sHeader) - iColon - 1));
      Result := True;
      Exit;
    end;
  finally
    Groups.Free;
    Names.Free;
    Lines.Free;
  end;
end;

function ParameterDefault(const DataType: string): string;
begin
  if CompareText(DataType, 'boolean') = 0 then
    Result := 'False'
  else if (CompareText(DataType, 'string') = 0) or
    (CompareText(DataType, 'ansistring') = 0) then
    Result := ''
  else if (CompareText(DataType, 'double') = 0) or
    (CompareText(DataType, 'single') = 0) or
    (CompareText(DataType, 'real') = 0) then
    Result := '0'
  else
    Result := '0';
end;

constructor TfTRComp.Create(AOwner: TComponent);
var
  Toolbar, ResultsPanel, LeftPanel, ApiPanel, RoutinePanel: TPanel;
  ResultsSplitter, ApiSplitter, MainSplitter: TSplitter;
  MainMenu: TMainMenu;
  MenuItem: TMenuItem;
  Heading: TLabel;
  IniFile: TIniFile;
  iFontSize, iTabWidth: Integer;
  bLineNumbers: Boolean;
  iPlayer, iTerritory: Integer;
begin
  inherited CreateNew(AOwner);
  Caption := 'TRComp - TRP Editor and Compiler';
  Width := 1000;
  Height := 720;
  Position := poScreenCenter;
  OnCloseQuery := FormCloseQuery;

  MainMenu := TMainMenu.Create(Self);
  MenuItem := TMenuItem.Create(MainMenu);
  MenuItem.Caption := '&File';
  MainMenu.Items.Add(MenuItem);
  AddMenuCommand(MenuItem, '&Open...', VK_O, DoOpen);
  AddMenuCommand(MenuItem, '&Save', VK_S, DoSave);
  AddMenuCommand(MenuItem, 'Save &As...', 0, DoSaveAs);
  AddMenuCommand(MenuItem, '-', 0, nil);
  AddMenuCommand(MenuItem, 'E&xit', 0, DoAppExit);
  MenuItem := TMenuItem.Create(MainMenu);
  MenuItem.Caption := '&Edit';
  MainMenu.Items.Add(MenuItem);
  AddMenuCommand(MenuItem, '&Undo', VK_Z, DoUndo);
  AddMenuCommand(MenuItem, '&Redo', VK_Y, DoRedo);
  AddMenuCommand(MenuItem, 'Cu&t', VK_X, DoCut);
  AddMenuCommand(MenuItem, '&Copy', VK_C, DoCopy);
  AddMenuCommand(MenuItem, '&Paste', VK_V, DoPaste);
  MenuItem := TMenuItem.Create(MainMenu);
  MenuItem.Caption := '&TRP';
  MainMenu.Items.Add(MenuItem);
  AddMenuCommand(MenuItem, '&Compile', 0, DoCompile);
  AddMenuCommand(MenuItem, '&Run selected routine...', 0, DoRun);
  MenuItem := TMenuItem.Create(MainMenu);
  MenuItem.Caption := '&Help';
  MainMenu.Items.Add(MenuItem);
  AddMenuCommand(MenuItem, 'TRP API reference', VK_F1, DoApiHelp);
  Menu := MainMenu;

  Toolbar := TPanel.Create(Self);
  Toolbar.Parent := Self;
  Toolbar.Align := alTop;
  Toolbar.Height := 42;
  Toolbar.BevelOuter := bvNone;

  AddButton(Toolbar, 'Open', DoOpen);
  AddButton(Toolbar, 'Save', DoSave);
  AddButton(Toolbar, 'Save As', DoSaveAs);
  AddButton(Toolbar, 'Compile', DoCompile);
  AddButton(Toolbar, 'Run', DoRun);

  fStatus := TLabel.Create(Self);
  fStatus.Parent := Toolbar;
  fStatus.Align := alRight;
  fStatus.Alignment := taRightJustify;
  fStatus.Caption := 'Ready';
  fStatus.BorderSpacing.Right := 12;

  ResultsPanel := TPanel.Create(Self);
  ResultsPanel.Parent := Self;
  ResultsPanel.Align := alBottom;
  ResultsPanel.Height := 190;
  ResultsPanel.Caption := '';
  ResultsPanel.BevelOuter := bvNone;
  fResultsPanel := ResultsPanel;

  Heading := TLabel.Create(Self);
  Heading.Parent := ResultsPanel;
  Heading.Align := alTop;
  Heading.Caption := 'Messages';
  fDiagnostics := TMemo.Create(Self);
  fDiagnostics.Parent := ResultsPanel;
  fDiagnostics.Align := alClient;
  fDiagnostics.ReadOnly := True;
  fDiagnostics.ScrollBars := ssBoth;
  fDiagnostics.WordWrap := False;
  fDiagnostics.Font.Name := 'Consolas';
  fDiagnostics.Lines.Add('Compiler messages and routine results will appear here.');
  fDiagnostics.OnDblClick := DiagnosticDoubleClick;

  ResultsSplitter := TSplitter.Create(Self);
  ResultsSplitter.Parent := Self;
  ResultsSplitter.Align := alBottom;
  ResultsSplitter.Height := 6;
  ResultsSplitter.MinSize := 120;

  LeftPanel := TPanel.Create(Self);
  LeftPanel.Parent := Self;
  LeftPanel.Align := alLeft;
  LeftPanel.Width := 260;
  LeftPanel.BevelOuter := bvNone;
  LeftPanel.Caption := '';
  fLeftPanel := LeftPanel;

  ApiPanel := TPanel.Create(Self);
  ApiPanel.Parent := LeftPanel;
  ApiPanel.Align := alClient;
  ApiPanel.BevelOuter := bvNone;
  ApiPanel.BorderSpacing.Around := 2;
  Heading := TLabel.Create(Self);
  Heading.Parent := ApiPanel;
  Heading.Align := alTop;
  Heading.Caption := 'TurboRisk API';
  fApiTree := TTreeView.Create(Self);
  fApiTree.Parent := ApiPanel;
  fApiTree.Align := alClient;
  fApiTree.OnDblClick := ApiDoubleClick;
  AddApiCategory('Territories',
    'TName TOwner TArmies TContinent TBordersCount TBorder TIsBordering TIsFront TIsMine TIsEntry TFrontsCount TFront TStrongestFront TWeakestFront TPressure TDistance TShortestPath TWeakestPath TPathToFront');
  AddApiCategory('Continents',
    'COwner CBonus CTerritoriesCount CTerritory CBordersCount CBorder CEntriesCount CEntry CAnalysis CLeader');
  AddApiCategory('Players',
    'PMe PName PProgram PActive PAlive PHuman PArmiesCount PNewArmies PTerritoriesCount PCardCount PCardTurnInValue');
  AddApiCategory('Status',
    'SConquest SPlayersCount SAlivePlayersCount SCardsBasedOnCombo');
  AddApiCategory('Utilities',
    'UMessage ULog UBufferSet UBufferGet URandom UTakeSnapshot UDialog UAbortGame ULogOff ULogOn UMessageOff UMessageOn UDialogOff UDialogOn USnapShotOff USnapShotOn');
  fApiTree.FullExpand;

  ApiSplitter := TSplitter.Create(Self);
  ApiSplitter.Parent := LeftPanel;
  ApiSplitter.Align := alBottom;
  ApiSplitter.Height := 5;

  RoutinePanel := TPanel.Create(Self);
  RoutinePanel.Parent := LeftPanel;
  RoutinePanel.Align := alBottom;
  RoutinePanel.Height := 180;
  RoutinePanel.BevelOuter := bvNone;
  RoutinePanel.BorderSpacing.Around := 2;
  Heading := TLabel.Create(Self);
  Heading.Parent := RoutinePanel;
  Heading.Align := alTop;
  Heading.Caption := 'Procedures and functions';
  fRoutineList := TListBox.Create(Self);
  fRoutineList.Parent := RoutinePanel;
  fRoutineList.Align := alClient;
  fRoutineList.OnDblClick := RoutineDoubleClick;

  MainSplitter := TSplitter.Create(Self);
  MainSplitter.Parent := Self;
  MainSplitter.Align := alLeft;
  MainSplitter.Width := 6;
  MainSplitter.MinSize := 180;

  fSource := TSynEdit.Create(Self);
  fSource.Parent := Self;
  fSource.Align := alClient;
  fSource.ScrollBars := ssBoth;
  fSource.Font.Name := 'Consolas';
  fPascalHighlighter := TSynPasSyn.Create(Self);
  fPascalHighlighter.CompilerMode := pcmDelphi;
  fSource.Highlighter := fPascalHighlighter;
  fSource.OnChange := SourceChanged;

  fContext.CurrentPlayer := 1;
  fContext.CardTradeByCombination := False;
  SetupTerritories;
  for iPlayer := 1 to MAXPLAYERS do begin
    fContext.PlayerActive[iPlayer] := iPlayer <= 2;
    fContext.PlayerName[iPlayer] := 'Player ' + IntToStr(iPlayer);
    fContext.PlayerProgram[iPlayer] := '';
    fContext.PlayerNewArmies[iPlayer] := 3;
  end;
  for iTerritory := 1 to MAXTERRITORIES do begin
    fContext.TerritoryOwner[iTerritory] := ((iTerritory - 1) mod 2) + 1;
    fContext.TerritoryArmies[iTerritory] := 2;
  end;

  fOpenDialog := TOpenDialog.Create(Self);
  fOpenDialog.Filter := 'TRP player scripts (*.trp)|*.trp|All files (*.*)|*.*';
  fOpenDialog.DefaultExt := 'trp';
  fOpenDialog.Options := fOpenDialog.Options + [ofFileMustExist, ofPathMustExist];

  fSaveDialog := TSaveDialog.Create(Self);
  fSaveDialog.Filter := fOpenDialog.Filter;
  fSaveDialog.DefaultExt := 'trp';
  fSaveDialog.Options := fSaveDialog.Options + [ofPathMustExist, ofOverwritePrompt];

  IniFile := TIniFile.Create(ChangeFileExt(Application.ExeName, '.ini'));
  try
    iFontSize := IniFile.ReadInteger('Edit', 'FontSize', 10);
    iTabWidth := IniFile.ReadInteger('Edit', 'TabWidth', 2);
    bLineNumbers := IniFile.ReadInteger('Edit', 'LineNumbers', 1) <> 0;
    Width := IniFile.ReadInteger('Windows', 'MainWidth', Width);
    Height := IniFile.ReadInteger('Windows', 'MainHeight', Height);
    LeftPanel.Width := IniFile.ReadInteger('Windows', 'APIWidth',
      IniFile.ReadInteger('Windows', 'SidebarWidth',
      IniFile.ReadInteger('Edit', 'APIWidth', LeftPanel.Width)));
    ResultsPanel.Height := IniFile.ReadInteger('Windows', 'MsgHeight',
      IniFile.ReadInteger('Windows', 'MessageHeight',
      IniFile.ReadInteger('Edit', 'MsgHeight', ResultsPanel.Height)));
  finally
    IniFile.Free;
  end;
  if (iFontSize < 6) or (iFontSize > 48) then
    iFontSize := 10;
  if (iTabWidth < 1) or (iTabWidth > 16) then
    iTabWidth := 2;
  fSource.Font.Size := iFontSize;
  fSource.TabWidth := iTabWidth;
  fSource.Gutter.LineNumberPart(0).Visible := bLineNumbers;
  RefreshRoutineList;

  fCurrentFile := '';
  fModified := False;
  fLoading := False;
  UpdateCaption;
end;

procedure TfTRComp.AddButton(Parent: TWinControl; const sCaption: string;
  OnClick: TNotifyEvent);
var
  Button: TButton;
begin
  Button := TButton.Create(Self);
  Button.Parent := Parent;
  Button.Align := alLeft;
  Button.Caption := sCaption;
  Button.Width := 90;
  Button.OnClick := OnClick;
end;

procedure TfTRComp.AddApiCategory(const sCategory, sNames: string);
var
  Root: TTreeNode;
  Names: TStringList;
  i: Integer;
begin
  Root := fApiTree.Items.Add(nil, sCategory);
  Names := TStringList.Create;
  try
    Names.Delimiter := ' ';
    Names.StrictDelimiter := True;
    Names.DelimitedText := sNames;
    for i := 0 to Names.Count - 1 do
      fApiTree.Items.AddChild(Root, Names[i]);
  finally
    Names.Free;
  end;
end;

procedure TfTRComp.RefreshRoutineList;
var
  Lines, Names: TStringList;
  i, iKeyword, iNameEnd: Integer;
  sLine, sName: string;
begin
  if fRefreshingRoutines then
    Exit;
  fRefreshingRoutines := True;
  Lines := TStringList.Create;
  Names := TStringList.Create;
  try
    Names.Sorted := True;
    Names.Duplicates := dupIgnore;
    Lines.Text := fSource.Text;
    for i := 0 to Lines.Count - 1 do begin
      sLine := TrimLeft(Lines[i]);
      if CompareText(Copy(sLine, 1, 10), 'procedure ') = 0 then
        iKeyword := 11
      else if CompareText(Copy(sLine, 1, 9), 'function ') = 0 then
        iKeyword := 10
      else
        Continue;
      iNameEnd := iKeyword;
      while (iNameEnd <= Length(sLine)) and
        IsPascalIdentifierChar(sLine[iNameEnd]) do
        Inc(iNameEnd);
      sName := Copy(sLine, iKeyword, iNameEnd - iKeyword);
      if sName <> '' then
        Names.AddObject(sName, TObject(PtrInt(i + 1)));
    end;
    fRoutineList.Items.Assign(Names);
  finally
    Names.Free;
    Lines.Free;
    fRefreshingRoutines := False;
  end;
end;

function TfTRComp.GetSelectedRoutine: string;
begin
  if fRoutineList.ItemIndex < 0 then
    Result := ''
  else
    Result := fRoutineList.Items[fRoutineList.ItemIndex];
end;

procedure TfTRComp.ApiDoubleClick(Sender: TObject);
var
  Node: TTreeNode;
begin
  Node := fApiTree.Selected;
  if (Node = nil) or (Node.Count > 0) then
    Exit;
  fSource.SelText := Node.Text;
  fSource.SetFocus;
end;

procedure TfTRComp.RoutineDoubleClick(Sender: TObject);
var
  iLine: Integer;
begin
  if fRoutineList.ItemIndex < 0 then
    Exit;
  iLine := PtrInt(fRoutineList.Items.Objects[fRoutineList.ItemIndex]);
  if (iLine < 1) or (iLine > fSource.Lines.Count) then
    Exit;
  fSource.CaretXY := Point(1, iLine);
  fSource.SetFocus;
end;

procedure TfTRComp.DiagnosticDoubleClick(Sender: TObject);
var
  sLine: string;
  iOpen, iComma, iClose, iLine: Integer;
begin
  if fDiagnostics.CaretPos.Y >= fDiagnostics.Lines.Count then
    Exit;
  sLine := fDiagnostics.Lines[fDiagnostics.CaretPos.Y];
  iOpen := Pos('(', sLine);
  iComma := Pos(',', sLine);
  iClose := Pos(')', sLine);
  if (iOpen > 0) and (iComma > iOpen) then
    iLine := StrToIntDef(Copy(sLine, iOpen + 1, iComma - iOpen - 1), 0)
  else if (iOpen > 0) and (iClose > iOpen) then
    iLine := StrToIntDef(Copy(sLine, iOpen + 1, iClose - iOpen - 1), 0)
  else
    iLine := 0;
  if (iLine > 0) and (iLine <= fSource.Lines.Count) then begin
    fSource.CaretXY := Point(1, iLine);
    fSource.SetFocus;
  end;
end;

procedure TfTRComp.DoRun(Sender: TObject);
var
  Parameters: TTRoutineParameters;
  aParams: array of Variant;
  sRoutine, sDeclaration, sReturnType, sSource, sName, sReturnValue,
  sDiagnostics, sTypeName, sValue: string;
  Dialog: TForm;
  Grid: TStringGrid;
  Button: TButton;
  i, iRow: Integer;
  iInteger: Int64;
  dNumber: Double;
  bBoolean: Boolean;
begin
  sRoutine := GetSelectedRoutine;
  if sRoutine = '' then begin
    MessageDlg('Select a procedure or function in the list first.',
      mtInformation, [mbOk], 0);
    Exit;
  end;
  sSource := fSource.Text;
  if not GetRoutineDeclaration(sSource, sRoutine, sDeclaration, Parameters,
    sReturnType) then begin
    MessageDlg('Could not read the declaration for ' + sRoutine + '.',
      mtError, [mbOk], 0);
    Exit;
  end;
  if not EditTRCompContext(fContext) then
    Exit;

  SetLength(aParams, Length(Parameters));
  if Length(Parameters) > 0 then begin
    Dialog := TForm.Create(Self);
    try
      Dialog.Caption := 'Parameters - ' + sRoutine;
      Dialog.Width := 520;
      Dialog.Height := Min(150 + Length(Parameters) * 34, 600);
      Dialog.Position := poScreenCenter;
      Grid := TStringGrid.Create(Dialog);
      Grid.Parent := Dialog;
      Grid.Align := alClient;
      Grid.FixedRows := 1;
      Grid.FixedCols := 0;
      Grid.ColCount := 3;
      Grid.RowCount := Length(Parameters) + 1;
      Grid.Options := Grid.Options + [goEditing, goAlwaysShowEditor];
      Grid.Cells[0, 0] := 'Parameter';
      Grid.Cells[1, 0] := 'Type';
      Grid.Cells[2, 0] := 'Value';
      Grid.ColWidths[0] := 160;
      Grid.ColWidths[1] := 120;
      Grid.ColWidths[2] := 180;
      for i := 0 to High(Parameters) do begin
        Grid.Cells[0, i + 1] := Parameters[i].Name;
        Grid.Cells[1, i + 1] := Parameters[i].DataType;
        Grid.Cells[2, i + 1] := ParameterDefault(Parameters[i].DataType);
      end;
      Button := TButton.Create(Dialog);
      Button.Parent := Dialog;
      Button.Align := alBottom;
      Button.Height := 36;
      Button.Caption := 'Run routine';
      Button.Default := True;
      Button.ModalResult := mrOk;
      if Dialog.ShowModal <> mrOk then
        Exit;
      for i := 0 to High(Parameters) do begin
        iRow := i + 1;
        sTypeName := LowerCase(Parameters[i].DataType);
        sValue := Trim(Grid.Cells[2, iRow]);
        if (sTypeName = 'string') or (sTypeName = 'ansistring') or
           (sTypeName = 'widestring') then
          aParams[i] := Grid.Cells[2, iRow]
        else if (sTypeName = 'boolean') then begin
          if not TryStrToBool(sValue, bBoolean) then begin
            MessageDlg('Enter True or False for parameter ' +
              Parameters[i].Name + '.', mtError, [mbOk], 0);
            Exit;
          end;
          aParams[i] := bBoolean;
        end
        else if (sTypeName = 'double') or (sTypeName = 'single') or
          (sTypeName = 'real') or (sTypeName = 'extended') or
          (sTypeName = 'currency') then begin
          if not TryStrToFloat(sValue, dNumber) then begin
            MessageDlg('Enter a number for parameter ' + Parameters[i].Name +
              '.', mtError, [mbOk], 0);
            Exit;
          end;
          aParams[i] := dNumber;
        end
        else begin
          if not TryStrToInt64(sValue, iInteger) then begin
            MessageDlg('Enter an integer value for parameter ' +
              Parameters[i].Name + '.', mtError, [mbOk], 0);
            Exit;
          end;
          aParams[i] := iInteger;
        end;
      end;
    finally
      Dialog.Free;
    end;
  end;

  if fCurrentFile = '' then
    sName := IncludeTrailingPathDelimiter(GetCurrentDir) + 'Untitled.trp'
  else
    sName := fCurrentFile;
  try
    if RunTRPRoutine(sName, sSource, sRoutine, fContext, aParams,
      sReturnValue, sDiagnostics) then begin
      sDiagnostics := 'Routine: ' + sRoutine + LineEnding +
        'Declaration: ' + sDeclaration + LineEnding +
        'Context message: ' + Trim(fContext.Message) + LineEnding +
        'Return value: ' + sReturnValue + LineEnding +
        sDiagnostics;
      for i := 0 to High(Parameters) do
        sDiagnostics := sDiagnostics + Parameters[i].Name + ' = ' +
          VarToStr(aParams[i]) + LineEnding;
      fStatus.Caption := 'Routine completed';
    end
    else
      fStatus.Caption := 'Routine failed';
    fDiagnostics.Lines.Text := sDiagnostics;
  except
    on E: Exception do begin
      fDiagnostics.Lines.Text := E.ClassName + ': ' + E.Message;
      fStatus.Caption := 'Routine failed';
    end;
  end;
end;

procedure TfTRComp.DoApiHelp(Sender: TObject);
var
  sHelpFile: string;
begin
  sHelpFile := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) +
    'Doc' + PathDelim + 'TurboRisk.chm';
  if not FileExists(sHelpFile) then begin
    MessageDlg('Doc\TurboRisk.chm was not found beside TRComp.',
      mtError, [mbOk], 0);
    Exit;
  end;
  if not OpenDocument(sHelpFile) then
    MessageDlg('Could not open the TurboRisk help file.', mtError, [mbOk], 0);
end;

procedure TfTRComp.DoAppExit(Sender: TObject);
begin
  Close;
end;

procedure TfTRComp.DoUndo(Sender: TObject);
begin
  fSource.Undo;
end;

procedure TfTRComp.DoRedo(Sender: TObject);
begin
  fSource.Redo;
end;

procedure TfTRComp.DoCut(Sender: TObject);
begin
  fSource.CutToClipboard;
end;

procedure TfTRComp.DoCopy(Sender: TObject);
begin
  fSource.CopyToClipboard;
end;

procedure TfTRComp.DoPaste(Sender: TObject);
begin
  fSource.PasteFromClipboard;
end;

procedure TfTRComp.UpdateCaption;
var
  sFileName: string;
begin
  if fCurrentFile = '' then
    sFileName := 'Untitled.trp'
  else
    sFileName := ExtractFileName(fCurrentFile);
  if fModified then
    sFileName := sFileName + '*';
  Caption := sFileName + ' - TRComp';
end;

procedure TfTRComp.SourceChanged(Sender: TObject);
begin
  RefreshRoutineList;
  if not fLoading then begin
    fModified := True;
    UpdateCaption;
    fStatus.Caption := 'Modified';
  end;
end;

function TfTRComp.ConfirmDiscardChanges: Boolean;
var
  Choice: Integer;
begin
  Result := True;
  if fModified then begin
    Choice := MessageDlg('Save changes to this TRP file before closing?',
      mtConfirmation, [mbYes, mbNo, mbCancel], 0);
    Result := Choice <> mrCancel;
    if Result and (Choice = mrYes) then
      Result := SaveCurrentFile;
  end;
end;

function TfTRComp.SaveCurrentFile: Boolean;
var
  Lines: TStringList;
begin
  Result := False;
  if fCurrentFile = '' then begin
    fSaveDialog.FileName := 'Untitled.trp';
    if not fSaveDialog.Execute then
      Exit;
    fCurrentFile := fSaveDialog.FileName;
  end;
  Lines := TStringList.Create;
  try
    try
      Lines.Text := fSource.Text;
      Lines.SaveToFile(fCurrentFile);
      fModified := False;
      UpdateCaption;
      fStatus.Caption := 'Saved';
      Result := True;
    except
      on E: Exception do
        MessageDlg('Could not save ' + fCurrentFile + ':' + LineEnding +
          E.Message, mtError, [mbOk], 0);
    end;
  finally
    Lines.Free;
  end;
end;

procedure TfTRComp.DoOpen(Sender: TObject);
var
  Lines: TStringList;
  Choice: Integer;
begin
  if fModified then begin
    Choice := MessageDlg('Save changes to this TRP file first?', mtConfirmation,
      [mbYes, mbNo, mbCancel], 0);
    if Choice = mrCancel then
      Exit;
    if (Choice = mrYes) and not SaveCurrentFile then
      Exit;
  end;
  if not fOpenDialog.Execute then
    Exit;
  Lines := TStringList.Create;
  try
    try
      Lines.LoadFromFile(fOpenDialog.FileName);
      fLoading := True;
      try
        fSource.Lines.Assign(Lines);
      finally
        fLoading := False;
      end;
      fCurrentFile := ExpandFileName(fOpenDialog.FileName);
      fModified := False;
      fDiagnostics.Clear;
      fStatus.Caption := 'Opened';
      UpdateCaption;
    except
      on E: Exception do
        MessageDlg('Could not open ' + fOpenDialog.FileName + ':' + LineEnding +
          E.Message, mtError, [mbOk], 0);
    end;
  finally
    Lines.Free;
  end;
end;

procedure TfTRComp.DoSave(Sender: TObject);
begin
  SaveCurrentFile;
end;

procedure TfTRComp.DoSaveAs(Sender: TObject);
var
  PreviousFile: string;
begin
  PreviousFile := fCurrentFile;
  if PreviousFile <> '' then
    fSaveDialog.FileName := PreviousFile
  else
    fSaveDialog.FileName := 'Untitled.trp';
  if fSaveDialog.Execute then begin
    fCurrentFile := fSaveDialog.FileName;
    if not SaveCurrentFile then
      fCurrentFile := PreviousFile;
    UpdateCaption;
  end;
end;

procedure TfTRComp.DoCompile(Sender: TObject);
var
  sName, sDiagnostics: string;
  bCompiled: Boolean;
begin
  if fCurrentFile = '' then
    sName := IncludeTrailingPathDelimiter(GetCurrentDir) + 'Untitled.trp'
  else
    sName := fCurrentFile;
  try
    bCompiled := ValidateTRPSource(sName, fSource.Text, sDiagnostics);
    fDiagnostics.Lines.Text := sDiagnostics;
    if bCompiled then
      fStatus.Caption := 'Compile succeeded'
    else
      fStatus.Caption := 'Compile failed';
  except
    on E: Exception do begin
      fDiagnostics.Lines.Text := E.ClassName + ': ' + E.Message;
      fStatus.Caption := 'Compile failed';
    end;
  end;
end;

procedure TfTRComp.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  IniFile: TIniFile;
begin
  CanClose := ConfirmDiscardChanges;
  if CanClose then begin
    try
      IniFile := TIniFile.Create(ChangeFileExt(Application.ExeName, '.ini'));
      try
        IniFile.WriteInteger('Windows', 'MainWidth', Width);
        IniFile.WriteInteger('Windows', 'MainHeight', Height);
        IniFile.WriteInteger('Windows', 'APIWidth', fLeftPanel.Width);
        IniFile.WriteInteger('Windows', 'MsgHeight', fResultsPanel.Height);
        IniFile.WriteInteger('Edit', 'FontSize', fSource.Font.Size);
        IniFile.WriteInteger('Edit', 'TabWidth', fSource.TabWidth);
        if fSource.Gutter.LineNumberPart(0).Visible then
          IniFile.WriteInteger('Edit', 'LineNumbers', 1)
        else
          IniFile.WriteInteger('Edit', 'LineNumbers', 0);
      finally
        IniFile.Free;
      end;
    except
      on E: Exception do
        MessageDlg('Could not save TRComp settings:' + LineEnding + E.Message,
          mtError, [mbOk], 0);
    end;
  end;
end;

end.
