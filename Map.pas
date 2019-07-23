unit Map;

{$MODE Delphi}

interface

uses
  LCLIntf, LCLType, LMessages, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,   ImgList,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, Buttons{, JvExExtCtrls, JvImage,
  JvBaseThumbnail, JvThumbImage};

type
  TfMap = class(TForm)
    lstMap: TListView;
    Label1: TLabel;
    panMapPreview: TPanel;
    imgMapPreview: TImage;
    txtMapSize: TEdit;
    Label2: TLabel;
    Label3: TLabel;
    cmdOK: TBitBtn;
    cmdAnnulla: TBitBtn;
    txtMapAuthor: TEdit;
    Label4: TLabel;
    txtMapRevision: TEdit;
    Label5: TLabel;
    procedure FormShow(Sender: TObject);
    procedure cmdOKClick(Sender: TObject);
    procedure lstMapChange(Sender: TObject; Item: TListItem;
      Change: TItemChange);
    procedure lstMapSelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure cmdCancel(Sender: TObject);
  private
    bLoading: boolean;
  public
    { Public declarations }
  end;

var
  fMap: TfMap;

implementation

{$R *.lfm}

uses Globals, IniFiles, Territ;

procedure TfMap.FormShow(Sender: TObject);
var
  SearchRec: TSearchRec;
  IniFile: TIniFile;
begin
  bLoading := true;
  // load list of map
  lstMap.Clear;
  if FindFirst(sG_AppPath+'maps/*.trm', 0, SearchRec) = 0 then begin
    repeat
      with lstMap.Items.Add do begin
        Caption := SearchRec.Name;
        if SameText(SearchRec.Name,sMapFile) then begin
          Checked := true;
          lstMap.ItemIndex := lstMap.Items.Count-1;
        end;
        IniFile := TIniFile.Create(sG_AppPath+'maps/'+SearchRec.Name);
        try
          SubItems.Add(IniFile.ReadString('Map','Desc',''));
          SubItems.Add(IniFile.ReadString('Map','Author',''));
          SubItems.Add(IniFile.ReadString('Map','Revision',''));
        finally
          IniFile.Free;
        end;
      end;
    until FindNext(SearchRec)<>0;
  end;
  FindClose(SearchRec);
  bLoading := false;
  if lstMap.ItemIndex>0 then begin
    lstMap.ItemFocused := lstMap.Items[lstMap.ItemIndex];
    lstMapSelectItem(Sender,lstMap.ItemFocused,true);
  end;
end;

procedure TfMap.cmdOKClick(Sender: TObject);
var
  i, iT: integer;
begin
  for i:=0 to lstMap.Items.Count-1 do begin
    if lstMap.Items[i].Checked then begin
      sMapFile := lstMap.Items[i].Caption;
      LoadMap;
      if GameState<>gsStopped then begin
        for it:=1 to MAXTERRITORIES do DisplayTerritory(iT);
      end;
      break;
    end;
  end;
  ModalResult := mrOK;    
end;

procedure TfMap.lstMapChange(Sender: TObject; Item: TListItem;
  Change: TItemChange);
var
  i: integer;
begin
  if bLoading then exit;
  // uncheck all other items
  if Item.Checked then begin
    for i:=0 to lstMap.Items.Count-1 do begin
      if lstMap.Items[i]<>Item then lstMap.Items[i].Checked:=false;
    end;
  end;
end;

procedure TfMap.lstMapSelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
var
  sBmpFile: string;
  bmp: TBitmap;
begin
  if bLoading then exit;
  if lstMap.ItemIndex<0 then exit;
  sBmpFile := ChangeFileExt(sG_AppPath+'maps/'+Item.Caption,'.bmp');
  if FileExists(sBmpFile) then begin
    bmp := TBitmap.Create;
    try
      // load bitmap and compute ratio
      bmp.LoadFromFile(sBmpFile);
      // stretch it into preview
      SetStretchBltMode(imgMapPreview.Canvas.Handle, HALFTONE);  // improve strech quality
      StretchBlt(imgMapPreview.Canvas.Handle, 0, 0, imgMapPreview.Width, imgMapPreview.Height, bmp.Canvas.Handle, 0, 0, bmp.Width, bmp.Height, SrcCopy);
      imgMapPreview.Refresh;
      // update controls
      imgMapPreview.Visible := true;
      panMapPreview.Caption := '';
      txtMapSize.Text := IntToStr(bmp.Width)+' x '
                       + IntToStr(bmp.Height);
      txtMapAuthor.Text := lstMap.ItemFocused.SubItems[1];
      txtMapRevision.Text := lstMap.ItemFocused.SubItems[2];
    finally
      bmp.Free;
    end;
  end else begin
    imgMapPreview.Visible := false;
    txtMapSize.Text := '';
    panMapPreview.Caption := 'Cannot find bitmap file';
  end;
end;

procedure TfMap.cmdCancel(Sender: TObject);
begin
  ModalResult := mrCancel;    //Added this line
end;

end.
