unit CheckUpd;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient,
  IdFTP, StdCtrls, IdHTTP, Buttons, CheckLst, ComCtrls, ExtCtrls, OleCtrls,
  SHDocVw;

type
  TUpdNews = record
    sText: string;
    dDate: TDateTime;
  end;

  TUpdFile = record
    sType, sName, sSiteName, sPath, sSitePath, sRemark, sLocDate,
    sSiteDate: string;
  end;

  TfCheckUpd = class(TForm)
    IdHTTP: TIdHTTP;
    panNews: TPanel;
    Panel1: TPanel;
    wbrNews: TWebBrowser;
    Label2: TLabel;
    Label3: TLabel;
    txtLastDate: TDateTimePicker;
    Splitter1: TSplitter;
    panFiles: TPanel;
    lstUpdates: TListView;
    Label1: TLabel;
    cmdUpdate: TBitBtn;
    panStatus: TPanel;
    prbProgress: TProgressBar;
    prbDownload: TProgressBar;
    cmdCancel: TBitBtn;
    procedure FormShow(Sender: TObject);
    procedure cmdUpdateClick(Sender: TObject);
    procedure idHTTPWorkBegin(ASender: TObject; AWorkMode: TWorkMode;
      AWorkCountMax: Int64);
    procedure idHTTPWork(ASender: TObject; AWorkMode: TWorkMode;
      AWorkCount: Int64);
    procedure idHTTPWorkEnd(ASender: TObject; AWorkMode: TWorkMode);
    procedure txtLastDateChange(Sender: TObject);
  private
    sNewsHead, sNewsFoot: string; // news HTML header and footer
    arNews: array of TUpdNews;
    arFiles: array of TUpdFile;
  public
    function CheckUpdates(bSilent: boolean): boolean;
  end;

var
  fCheckUpd: TfCheckUpd;

implementation

{$R *.dfm}

uses ActiveX, DateUtils, StrUtils, IniFiles, StdPas, Globals;

procedure WBLoadHTML(WebBrowser: TWebBrowser; HTMLCode: string);
var
  sl: TStringList;
  ms: TMemoryStream;
begin
  WebBrowser.Navigate('about:blank');
  while WebBrowser.ReadyState < READYSTATE_INTERACTIVE do
    Application.ProcessMessages;

  if Assigned(WebBrowser.Document) then begin
    sl := TStringList.Create;
    try
      ms := TMemoryStream.Create;
      try
        sl.Text := HTMLCode;
        sl.SaveToStream(ms);
        ms.Seek(0, 0); (WebBrowser.Document as IPersistStreamInit)
        .Load(TStreamAdapter.Create(ms));
      finally
        ms.Free;
      end;
    finally
      sl.Free;
    end;
  end;
end;

function TfCheckUpd.CheckUpdates(bSilent: boolean): boolean;
const
  SEPARATOR = ';';
var
  sVersInfo, sNews, sTmp, sTmp2: string;
  lstFiles, lstNews: TStringList;
  rFileDesc: TSearchRec;
  i, j: integer;
  bIgnore, bNews, bHead: boolean;
begin
  Result := false;
  try
    Screen.Cursor := crHourGlass;
    Application.ProcessMessages;
    SetLength(arNews, 0);
    SetLength(arFiles, 0);
    // load news and version info file from website
    try
      sVersInfo := IdHTTP.Get(
        'http://www.marioferrari.org/freeware/turborisk/version_info.csv');
      sNews := IdHTTP.Get(
        'http://www.marioferrari.org/freeware/turborisk/news.htm');
    except
      on e: Exception do begin
        if not bSilent then begin
          MessageDlg('Could not connect to TurboRisk website: ' + e.Message,
            mtError, [mbOk], 0);
        end;
        exit;
      end;
    end;
    // create temporary lists
    lstFiles := TStringList.Create;
    lstNews := TStringList.Create;
    try
      // copy news and version info into lists
      lstFiles.Text := sVersInfo;
      lstNews.Text := sNews;
      // news: populate array
      sNewsHead := '';
      sNewsFoot := '';
      bHead := true;
      bNews := false;
      bIgnore := false;
      j := -1;
      SetLength(arNews, 0);
      for i := 0 to lstNews.Count - 1 do begin
        sTmp := lstNews[i];
        // begin:ignore
        if not bIgnore and SameText(copy(sTmp, 1, 17), '<!-- begin:ignore')
        then begin
          bIgnore := true;
        end
        // end:ignore
        else if bIgnore and SameText(copy(sTmp, 1, 15), '<!-- end:ignore') then
        begin
          bIgnore := false;
        end
        // ignore
        else if bIgnore then begin
          // do nothing
        end
        // begin:news
        else if not bNews and SameText(copy(sTmp, 1, 15), '<!-- begin:news')
        then begin
          sTmp2 := trim(copy(sTmp, 16, 255));
          inc(j);
          SetLength(arNews, j + 1);
          arNews[j].dDate := EncodeDate(StrToInt(copy(sTmp2, 1, 4)),
            StrToInt(copy(sTmp2, 5, 2)), StrToInt(copy(sTmp2, 7, 2)));
          arNews[j].sText := '';
          bNews := true;
          bHead := false;
        end
        // end:news
        else if bNews and SameText(copy(sTmp, 1, 13), '<!-- end:news') then
        begin
          bNews := false;
        end
        // news
        else if bNews then begin
          arNews[j].sText := arNews[j].sText + #13#10 + sTmp;
        end
        // header
        else if bHead then begin
          sNewsHead := sNewsHead + #13#10 + sTmp;
        end
        // footer
        else begin
          sNewsFoot := sNewsFoot + #13#10 + sTmp;
        end;
      end;
      // version info: populate array
      SetLength(arFiles, lstFiles.Count);
      for i := 0 to lstFiles.Count - 1 do begin
        sTmp := lstFiles[i];
        arFiles[i].sType := splitstr(sTmp, SEPARATOR);
        arFiles[i].sName := splitstr(sTmp, SEPARATOR);
        arFiles[i].sSiteName := splitstr(sTmp, SEPARATOR);
        arFiles[i].sSiteDate := splitstr(sTmp, SEPARATOR);
        arFiles[i].sRemark := sTmp;
        arFiles[i].sLocDate := '';
        if CompareText(arFiles[i].sType, 'app') = 0 then begin
          arFiles[i].sPath := '';
          arFiles[i].sSitePath := '';
        end
        else if CompareText(arFiles[i].sType, 'map') = 0 then begin
          arFiles[i].sPath := 'maps\';
          arFiles[i].sSitePath := 'maps/';
        end
        else if CompareText(arFiles[i].sType, 'trp') = 0 then begin
          arFiles[i].sPath := 'players\';
          arFiles[i].sSitePath := 'players/';
        end;
      end;
      // check local version of files
      for i := 0 to lstFiles.Count - 1 do begin
        if FindFirst(sG_AppPath + arFiles[i].sPath + arFiles[i].sName,
          faAnyFile, rFileDesc) = 0 then begin
          arFiles[i].sLocDate := FormatDateTime('yyyymmdd',
            FileDateToDateTime(rFileDesc.Time));
        end;
      end;
      FindClose(rFileDesc);
      // check if there are newer news
      for i := 0 to high(arNews) do begin
        if arNews[i].dDate > sG_LastNews then begin
          Result := true;
        end;
      end;
      // check if there are newer versions
      for i := 0 to high(arFiles) do begin
        with arFiles[i] do begin
          if sLocDate = '' then begin
            if (CompareText(sName, 'TRMap.exe') <> 0) and (CompareText(sName,
                'TRComp.exe') <> 0) then begin
              Result := true;
            end;
          end
          else if sSiteDate > sLocDate then begin
            Result := true;
          end;
        end;
      end;
    finally
      lstNews.Free;
      lstFiles.Free;
    end;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TfCheckUpd.FormShow(Sender: TObject);
var
  sRmk: string;
  i: integer;
  bError: boolean;
begin
  // load version info file from website
  CheckUpdates(false);
  // populate News
  txtLastDate.Date := IncDay(sG_LastNews, 1);
  txtLastDateChange(Sender);
  // populate Update list
  lstUpdates.Clear;
  for i := 0 to high(arFiles) do begin
    with arFiles[i] do begin
      with lstUpdates.Items.Add do begin
        sRmk := '';
        Caption := sType;
        SubItems.Add(sName);
        if sLocDate = '' then begin
          SubItems.Add('New file');
          if (CompareText(sName, 'TRMap.exe') = 0) or (CompareText(sName,
              'TRComp.exe') = 0) or (CompareText(sName, 'TRSim.exe') = 0) then
          begin
            Checked := false;
            sRmk := '(Not installed) ';
          end
          else begin
            Checked := true;
          end;
        end
        else if sSiteDate > sLocDate then begin
          SubItems.Add('Newer version');
          Checked := true;
        end
        else begin
          SubItems.Add('Up-to-date');
          Checked := false;
        end;
        SubItems.Add(sRmk + sRemark);
      end;
    end;
  end;
end;

procedure TfCheckUpd.cmdUpdateClick(Sender: TObject);
var
  tData, tData2: TMemoryStream;
  sBak: string;
  i, iCount: integer;
  bMap, bExe, bTurboRisk: boolean;
begin
  Screen.Cursor := crHourGlass;
  bTurboRisk := false;
  // count files to update
  iCount := 0;
  for i := 0 to lstUpdates.Items.Count - 1 do begin
    if lstUpdates.Items[i].Checked then
      inc(iCount);
  end;
  // prepare controls
  tData := TMemoryStream.Create;
  tData2 := TMemoryStream.Create;
  cmdUpdate.Visible := false;
  cmdCancel.Visible := false;
  panStatus.Visible := true;
  prbDownload.Visible := true;
  prbDownload.Position := 0;
  prbProgress.Visible := true;
  prbProgress.Position := 0;
  prbProgress.Max := iCount;
  Application.ProcessMessages;
  try
    // update cycle
    for i := 0 to lstUpdates.Items.Count - 1 do begin
      // skip files not to download
      if not lstUpdates.Items[i].Checked then
        continue;
      // select row in list
      panStatus.Caption := 'Downloading "' + arFiles[i].sName + '"...';
      lstUpdates.Selected := lstUpdates.Items[i];
      Application.ProcessMessages;
      // choose proper path
      bMap := (CompareText(arFiles[i].sType, 'map') = 0);
      // download file from server into stream
      tData.Clear;
      tData2.Clear;
      try
        IdHTTP.Get('http://www.marioferrari.org/freeware/turborisk/' + arFiles
          [i].sSitePath + arFiles[i].sSiteName, tData);
      except
        on e: Exception do begin
          MessageDlg('Could not connect to TurboRisk website: ' + e.Message,
            mtError, [mbOk], 0);
          exit;
        end;
      end;
      // if file is a map, download bmp as well
      if bMap then begin
        try
          IdHTTP.Get('http://www.marioferrari.org/freeware/turborisk/' + arFiles
            [i].sSitePath + ChangeFileExt(arFiles[i].sSiteName, '.bmp'),
            tData2);
        except
          on e: Exception do begin
            MessageDlg('Could not connect to TurboRisk website: ' + e.Message,
              mtError, [mbOk], 0);
            exit;
          end;
        end;
      end;
      // check if file is exe and if is TurboRisk itself
      bExe := false;
      if (CompareText(arFiles[i].sName, 'TurboRisk.exe') = 0) then begin
        bExe := true;
        bTurboRisk := true;
      end;
      if (CompareText(arFiles[i].sName, 'TRMap.exe') = 0) or
      (CompareText(arFiles[i].sName, 'TRComp.exe') = 0) or
      (CompareText(arFiles[i].sName, 'TRSim.exe') = 0) then begin
        bExe := true;
      end;
      // if file is exe, save previous version to ".bak"
      if bExe then begin
        sBak := ChangeFileExt(arFiles[i].sName, '.bak');
        if FileExists(arFiles[i].sPath + sBak) then
          DeleteFile(arFiles[i].sPath + sBak); // delete previous ".bak"
        RenameFile(arFiles[i].sPath + arFiles[i].sName,
          arFiles[i].sPath + sBak);
      end;
      // save stream to file
      tData.SaveToFile(sG_AppPath + arFiles[i].sPath + arFiles[i].sName);
      if bMap then
        tData2.SaveToFile(sG_AppPath + arFiles[i].sPath + ChangeFileExt
          (arFiles[i].sName, '.bmp'));
      // refresh list and progress bar
      lstUpdates.Items[i].Checked := false;
      lstUpdates.Items[i].SubItems[1] := 'Up-to-date';
      panStatus.Caption := panStatus.Caption + ' done.';
      prbProgress.Position := prbProgress.Position + 1;
      Application.ProcessMessages;
    end;
  finally
    tData.Free;
    tData2.Free;
    panStatus.Visible := false;
    prbProgress.Visible := false;
    prbDownload.Visible := false;
    cmdUpdate.Visible := true;
    cmdCancel.Visible := true;
    Screen.Cursor := crDefault;
    if bTurboRisk then begin
      MessageDlg(
        'TurboRisk application updated, you need to close and restart it to apply the changes.', mtInformation, [mbOk], 0);
    end;
  end;
end;

procedure TfCheckUpd.idHTTPWorkBegin(ASender: TObject; AWorkMode: TWorkMode;
  AWorkCountMax: Int64);
begin
  prbDownload.Max := AWorkCountMax;
  prbDownload.Position := 0;
end;

procedure TfCheckUpd.idHTTPWork(ASender: TObject; AWorkMode: TWorkMode;
  AWorkCount: Int64);
begin
  prbDownload.Position := AWorkCount;
end;

procedure TfCheckUpd.idHTTPWorkEnd(ASender: TObject; AWorkMode: TWorkMode);
begin
  prbDownload.Position := prbDownload.Max;
end;

procedure TfCheckUpd.txtLastDateChange(Sender: TObject);
var
  i: integer;
  sHTML: string;
begin
  // header
  sHTML := sNewsHead + #13#10;
  // news according to date
  for i := 0 to high(arNews) do begin
    // show news more recent than specified date
    if CompareDate(arNews[i].dDate, txtLastDate.Date) >= 0 then begin
      sHTML := sHTML + arNews[i].sText + #13#10;
    end;
    // update last date
    if CompareDate(arNews[i].dDate, sG_LastNews) > 0 then begin
      sG_LastNews := arNews[i].dDate;
    end;
  end;
  // footer
  sHTML := sHTML + sNewsFoot;
  // load into browser
  WBLoadHTML(wbrNews, sHTML);
end;

end.
