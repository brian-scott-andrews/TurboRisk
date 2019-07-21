unit Programs;

{$MODE Delphi}

interface

uses
  LCLIntf, LCLType, LMessages, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, CheckLst, Buttons;

type
  TfPrograms = class(TForm)
    Label1: TLabel;
    txtPrgDesc: TMemo;
    Label2: TLabel;
    lstPrgFile: TCheckListBox;
    cmdOK: TBitBtn;
    cmdAnnulla: TBitBtn;
    function strTran(ctext, cfor, cwith: string): string;
    procedure FormShow(Sender: TObject);
    procedure lstPrgFileClickCheck(Sender: TObject);
    procedure lstPrgFileClick(Sender: TObject);
    procedure cmdOKClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  fPrograms: TfPrograms;

implementation

{$R *.lfm}

uses {StdPas,} Players, Globals;

{ Character by Character String Replacement }
function TfPrograms.strTran(ctext, cfor, cwith: string): string;
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



procedure TfPrograms.FormShow(Sender: TObject);
var
  rFileDesc: TSearchRec;
  i: integer;
begin
  // load program list
  lstPrgFile.Items.Clear;
  if FindFirst(sG_AppPath+'players/*.trp', faAnyFile, rFileDesc) = 0 then begin
    repeat
      lstPrgFile.Items.Add(rFileDesc.Name);
    until FindNext(rFileDesc) <> 0;
    FindClose(rFileDesc);
  end;
  // select current program, if any
  {i := lstPrgFile.Items.IndexOf(fPlayers.cboPrgFile.Text);        }
  if i>=0 then begin
    lstPrgFile.ItemIndex:=i;
    lstPrgFile.Checked[i] := true;
    lstPrgFileClick(Sender);
  end;
end;

procedure TfPrograms.lstPrgFileClickCheck(Sender: TObject);
var
  i, j: integer;
begin
  // uncheck all other items
  j := lstPrgFile.ItemIndex;
  if lstPrgFile.Checked[j] then begin
    for i:=0 to lstPrgFile.Items.Count-1 do begin
      if i<>j then lstPrgFile.Checked[i] := false;
    end;
  end;
end;

procedure TfPrograms.lstPrgFileClick(Sender: TObject);
var
  fTRP: textfile;
  sLine: string;
  bComment: boolean;
  i: integer;
begin
  if lstPrgFile.ItemIndex<0 then exit;
  txtPrgDesc.Clear;
  AssignFile(fTRP,sG_AppPath+'players\'+lstPrgFile.Items[lstPrgFile.ItemIndex]);
  Reset(fTRP);
  try
    // read initial comment delimited by { and }
    bComment := false;
    while not Eof(fTRP) do begin
      Readln(fTRP,sLine);
      // search for begin of comment
      if not bComment then begin
        i := pos('{',sLine);
        if i>0 then begin
          sLine := StrTran(sLine,'{','');
          bComment := true;
          if trim(sLine)='' then continue;
        end;
      end;
      // copy comment into control
      if bComment then begin
        i := pos('}',sLine);
        if i>0 then sLine := StrTran(sLine,'}','');
        txtPrgDesc.Lines.Add(sLine);
        if i>0 then break;
      end;  
    end;
  finally
    CloseFile(fTRP);
  end;
end;

procedure TfPrograms.cmdOKClick(Sender: TObject);
var
  i: integer;
begin
  for i:=0 to lstPrgFile.Items.Count-1 do begin
    if lstPrgFile.Checked[i] then begin
      fPlayers.cboPrgFile.Text := lstPrgFile.Items[i];
      break;
    end;
  end;
  ModalResult := mrOK;
end;

end.
