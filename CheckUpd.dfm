object fCheckUpd: TfCheckUpd
  Left = 534
  Top = 275
  HelpContext = 510
  Caption = 'Update manager'
  ClientHeight = 638
  ClientWidth = 617
  Color = clBtnFace
  Constraints.MinHeight = 500
  Constraints.MinWidth = 400
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object Splitter1: TSplitter
    Left = 0
    Top = 209
    Width = 617
    Height = 5
    Cursor = crVSplit
    Align = alTop
  end
  object panNews: TPanel
    Left = 0
    Top = 0
    Width = 617
    Height = 209
    Align = alTop
    BevelOuter = bvLowered
    TabOrder = 0
    ExplicitLeft = 8
    ExplicitTop = 8
    ExplicitWidth = 516
    DesignSize = (
      617
      209)
    object Label2: TLabel
      Left = 8
      Top = 17
      Width = 32
      Height = 13
      Caption = 'News'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object Label3: TLabel
      Left = 412
      Top = 17
      Width = 83
      Height = 13
      Anchors = [akTop, akRight]
      Caption = 'Show news since'
      ExplicitLeft = 395
    end
    object Panel1: TPanel
      Left = 8
      Top = 36
      Width = 601
      Height = 165
      Anchors = [akLeft, akTop, akRight, akBottom]
      BevelOuter = bvLowered
      Ctl3D = True
      ParentCtl3D = False
      TabOrder = 0
      object wbrNews: TWebBrowser
        Left = 1
        Top = 1
        Width = 599
        Height = 163
        Align = alClient
        TabOrder = 0
        ExplicitWidth = 300
        ExplicitHeight = 64
        ControlData = {
          4C000000E93D0000D91000000000000000000000000000000000000000000000
          000000004C000000000000000000000001000000E0D057007335CF11AE690800
          2B2E126208000000000000004C0000000114020000000000C000000000000046
          8000000000000000000000000000000000000000000000000000000000000000
          00000000000000000100000000000000000000000000000000000000}
      end
    end
    object txtLastDate: TDateTimePicker
      Left = 507
      Top = 9
      Width = 101
      Height = 21
      Anchors = [akTop, akRight]
      Date = 40428.500000000000000000
      Time = 40428.500000000000000000
      TabOrder = 1
      OnChange = txtLastDateChange
      ExplicitLeft = 490
    end
  end
  object panFiles: TPanel
    Left = 0
    Top = 214
    Width = 617
    Height = 424
    Align = alClient
    BevelOuter = bvLowered
    TabOrder = 1
    ExplicitLeft = 97
    ExplicitTop = 226
    ExplicitWidth = 503
    ExplicitHeight = 258
    DesignSize = (
      617
      424)
    object Label1: TLabel
      Left = 8
      Top = 6
      Width = 27
      Height = 13
      Caption = 'Files'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lstUpdates: TListView
      Left = 9
      Top = 25
      Width = 599
      Height = 337
      Anchors = [akLeft, akTop, akRight, akBottom]
      Checkboxes = True
      Columns = <
        item
          Caption = 'Type'
        end
        item
          Caption = 'File name'
          Width = 150
        end
        item
          Caption = 'Status'
          Width = 100
        end
        item
          Caption = 'Comments'
          Width = 220
        end>
      TabOrder = 0
      ViewStyle = vsReport
      ExplicitHeight = 293
    end
    object panStatus: TPanel
      Left = 9
      Top = 393
      Width = 436
      Height = 27
      Alignment = taLeftJustify
      Anchors = [akLeft, akRight, akBottom]
      BevelOuter = bvLowered
      BorderWidth = 5
      TabOrder = 2
      Visible = False
      ExplicitTop = 390
    end
    object prbProgress: TProgressBar
      Left = 8
      Top = 368
      Width = 600
      Height = 26
      Anchors = [akLeft, akRight, akBottom]
      TabOrder = 3
      Visible = False
      ExplicitTop = 365
    end
    object prbDownload: TProgressBar
      Left = 451
      Top = 393
      Width = 157
      Height = 26
      Anchors = [akRight, akBottom]
      TabOrder = 4
      Visible = False
      ExplicitTop = 390
    end
    object cmdCancel: TBitBtn
      Left = 513
      Top = 375
      Width = 96
      Height = 36
      Anchors = [akRight, akBottom]
      Cancel = True
      Caption = 'Close'
      DoubleBuffered = True
      ModalResult = 2
      ParentDoubleBuffered = False
      TabOrder = 5
      ExplicitTop = 355
    end
    object cmdUpdate: TBitBtn
      Left = 8
      Top = 375
      Width = 156
      Height = 36
      Anchors = [akLeft, akBottom]
      Caption = 'Install/Update selected files'
      DoubleBuffered = True
      ParentDoubleBuffered = False
      TabOrder = 1
      OnClick = cmdUpdateClick
      ExplicitTop = 372
    end
  end
  object idHTTP: TIdHTTP
    OnWork = idHTTPWork
    OnWorkBegin = idHTTPWorkBegin
    OnWorkEnd = idHTTPWorkEnd
    AllowCookies = True
    ProxyParams.BasicAuthentication = False
    ProxyParams.ProxyPort = 0
    Request.ContentLength = -1
    Request.ContentType = 'text/html'
    Request.Accept = 'text/html, */*'
    Request.BasicAuthentication = False
    Request.UserAgent = 'Mozilla/5.0 (Windows; U; Windows NT 6.0; it;'
    HTTPOptions = [hoForceEncodeParams]
    Left = 49
    Top = 438
  end
end
