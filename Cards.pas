unit Cards;

{$MODE Delphi}

interface

uses
  LCLIntf, LCLType, LMessages, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ExtCtrls, StdCtrls, Buttons, checklst;

type
  TfCards = class(TForm)
    lstCards: TCheckListBox;
    cmdTrade: TBitBtn;
    cmdHold: TBitBtn;
    panArmies: TPanel;
    procedure FormShow(Sender: TObject);
    procedure lstCardsClickCheck(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure cmdTradeClick(Sender: TObject);
    procedure cmdCancel(Sender: TObject);
  private
    { Private declarations }
    bReady: boolean;
    iPBenefit,
    iPInf, iPCav, iPArt, iPJok: integer;
    function PreparaForm: boolean;
  public
    { Public declarations }
  end;

var
  fCards: TfCards;

// Assegna una nuova carta al giocatore di turno
procedure PescaCarta;

// Verifica la validità e il valore di una combinazione di carte
function TestCombinazione(iInf, iCav, iArt, iJok: integer): integer;

// Valuta la migliore combinazione per il giocatore di turno
function CercaCombinazioneMigliore(var iInf, iCav, iArt, iJok: integer): boolean;

implementation

{$R *.lfm}

uses Globals, Stats;

procedure TfCards.FormShow(Sender: TObject);
begin
  PreparaForm;
  UpdateGridPos;
end;

procedure TfCards.lstCardsClickCheck(Sender: TObject);
var
  i: integer;
begin
  if not bReady then exit;
  iPInf:=0; iPCav:=0; iPArt:=0; iPJok:=0;
  with arPlayer[iTurn], lstCards do begin
    for i:=0 to Items.Count-1 do begin
      if Checked[i] then begin
        if Items[i]='Infantry' then inc(iPInf)
        else if Items[i]='Cavalry' then inc(iPCav)
        else if Items[i]='Artillery' then inc(iPArt)
        else if Items[i]='Joker' then inc(iPJok);
      end;
    end;
    iPBenefit := TestCombinazione(iPInf, iPCav, iPArt, iPJok);
    if iPBenefit<=0 then begin
      cmdTrade.Enabled := false;
      panArmies.Caption := '';
    end else begin
      cmdTrade.Enabled := true;
      panArmies.Caption := IntToStr(iPBenefit)+' armies';
    end;
  end;
end;

procedure TfCards.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := cmdHold.Enabled or (ModalResult = mrOK);
end;

procedure TfCards.cmdTradeClick(Sender: TObject);
begin
  with arPlayer[iTurn] do begin
    if iPBenefit > 0 then begin
      inc(NewArmy,iPBenefit);
      dec(Cards[caInf],iPInf); dec(Cards[caCav],iPCav);
      dec(Cards[caArt],iPArt); dec(Cards[caJok],iPJok);
      inc(NScambi);
      UpdateStats;
    end;
    // se non ci sono altre combinazioni e sono in gestione semiautom.-> esco
    if not PreparaForm and (CardsHandling=chSmart) then
      ModalResult := mrOK;
  end;
end;

function TfCards.PreparaForm: boolean;
var
  i,
  iInf, iCav, iArt, iJok: integer;
begin
  bReady := false;
  with arPlayer[iTurn], lstCards do begin
    // ricerca combinazione da proporre di default
    Result := CercaCombinazioneMigliore(iInf, iCav, iArt, iJok);
    // caricamento lista carte
    Items.Clear;
    for i:=1 to Cards[caInf] do begin
      Items.Add('Infantry');
      if iInf>0 then begin
        Checked[Items.Count-1] := true;
        dec(iInf);
      end;
    end;
    for i:=1 to Cards[caCav] do begin
      Items.Add('Cavalry');
      if iCav>0 then begin
        Checked[Items.Count-1] := true;
        dec(iCav);
      end;
    end;
    for i:=1 to Cards[caArt] do begin
      Items.Add('Artillery');
      if iArt>0 then begin
        Checked[Items.Count-1] := true;
        dec(iArt);
      end;
    end;
    for i:=1 to Cards[caJok] do begin
      Items.Add('Joker');
      if iJok>0 then begin
        Checked[Items.Count-1] := true;
        dec(iJok);
      end;
    end;
    cmdHold.Enabled := (Items.Count<=RMaxHeldCards);
    bReady := true;
    lstCardsClickCheck(self);
  end;
end;

// Assegna una nuova carta al giocatore di turno
procedure PescaCarta;
begin
  with arPlayer[iTurn] do begin
    case Random(44)+1 of
      1..14:  inc(Cards[caInf]);
      15..28: inc(Cards[caArt]);
      29..42: inc(Cards[caCav]);
      43..44: inc(Cards[caJok]);
    end;
  end;
end;

// Verifica la validità e il valore di una combinazione di carte
function TestCombinazione(iInf, iCav, iArt, iJok: integer): integer;
begin
  Result := -1;  // combinazione non possibile
  if iInf+iCav+iArt+iJok<>3 then exit;

  with arPlayer[iTurn] do begin
    // test se combinazione possibile
    if (iInf>Cards[caInf]) or (iCav>Cards[caCav])
    or (iArt>Cards[caArt]) or (iJok>Cards[caJok]) then exit;
    // valore combinazione
    if ((iInf=1) and (iCav=1) and (iArt=1))
    or ((iInf=1) and (iCav=1) and (iJok=1))
    or ((iInf=1) and (iJok=1) and (iArt=1))
    or ((iJok=1) and (iCav=1) and (iArt=1))
    or ((iInf=1) and (iJok=2))
    or ((iCav=1) and (iJok=2))
    or ((iArt=1) and (iJok=2))
    or (iJok=3) then begin
      Result := RSetValue[csDif];
    end else
    if (iInf=3)
    or ((iInf=2) and (iJok=1)) then begin
      Result := RSetValue[csInf];
    end else
    if (iCav=3)
    or ((iCav=2) and (iJok=1)) then begin
      Result := RSetValue[csCav];
    end else
    if (iArt=3)
    or ((iArt=2) and (iJok=1)) then begin
      Result := RSetValue[csArt];
    end else begin
      Result := 0;
    end;
    if (Result > 0) and (RCardsValueType = cvProgressive) then begin
      if NScambi<8 then
        Result := RTradeValue[NScambi+1]
      else
        Result := RTradeValue[8] + (NScambi-7) * RValueInc;
    end;
  end;
end;

// Valuta la migliore combinazione per il giocatore di turno
function CercaCombinazioneMigliore(var iInf, iCav, iArt, iJok: integer): boolean;
var
  iMaxBenefit: integer;
  procedure Valuta(iInf2, iCav2, iArt2, iJok2: integer);
  var
    iBenefit: integer;
  begin
    iBenefit := TestCombinazione(iInf2, iCav2, iArt2, iJok2);
    if iBenefit>iMaxBenefit then begin
      iInf := iInf2; iCav := iCav2;
      iArt := iArt2; iJok := iJok2;
      iMaxBenefit := iBenefit;
    end;
  end;
begin
  iInf:=0; iCav:=0; iArt:=0; iJok:=0;
  iMaxBenefit := 0;
  Valuta(1,1,1,0);
  Valuta(1,1,0,1);
  Valuta(1,0,1,1);
  Valuta(0,1,1,1);
  Valuta(1,0,0,2);
  Valuta(0,1,0,2);
  Valuta(0,0,1,2);
  Valuta(0,0,0,3);
  Valuta(3,0,0,0);
  Valuta(0,3,0,0);
  Valuta(0,0,3,0);
  Valuta(2,0,0,1);
  Valuta(0,2,0,1);
  Valuta(0,0,2,1);
  Result := (iMaxBenefit>0);
end;


procedure TfCards.cmdCancel(Sender: TObject);
begin
  ModalResult := mrCancel
end;

end.
