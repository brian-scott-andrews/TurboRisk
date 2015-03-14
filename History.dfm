object fHistory: TfHistory
  Left = 242
  Top = 107
  HelpContext = 330
  Caption = 'History'
  ClientHeight = 430
  ClientWidth = 582
  Color = clBtnFace
  Constraints.MinHeight = 335
  Constraints.MinWidth = 430
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poDesigned
  OnCreate = FormCreate
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object pagHistory: TPageControl
    Left = 0
    Top = 0
    Width = 582
    Height = 430
    ActivePage = tbsHistory
    Align = alClient
    TabOrder = 0
    object tbsHistory: TTabSheet
      Caption = 'History'
      object lstHistory: TListView
        Left = 0
        Top = 0
        Width = 574
        Height = 402
        Align = alClient
        Columns = <>
        ReadOnly = True
        RowSelect = True
        TabOrder = 0
        ViewStyle = vsReport
        OnColumnClick = lstHistoryColumnClick
        OnCompare = lstHistoryCompare
      end
    end
    object tbsRanking: TTabSheet
      Caption = 'Ranking'
      ImageIndex = 1
      object grdRanking: TJvStringGrid
        Left = 0
        Top = 0
        Width = 574
        Height = 402
        Align = alClient
        ColCount = 4
        DefaultColWidth = 100
        DefaultRowHeight = 17
        DefaultDrawing = False
        FixedCols = 0
        FixedRows = 0
        Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine]
        ScrollBars = ssVertical
        TabOrder = 0
        OnDrawCell = grdRankingDrawCell
        Alignment = taCenter
        FixedFont.Charset = DEFAULT_CHARSET
        FixedFont.Color = clWindowText
        FixedFont.Height = -11
        FixedFont.Name = 'MS Sans Serif'
        FixedFont.Style = []
        OnCaptionClick = grdRankingCaptionClick
      end
    end
    object tbsCompare: TTabSheet
      Caption = 'Compare'
      ImageIndex = 2
      object Label1: TLabel
        Left = 5
        Top = 10
        Width = 38
        Height = 13
        Caption = 'Player 1'
      end
      object Label2: TLabel
        Left = 260
        Top = 10
        Width = 38
        Height = 13
        Caption = 'Player 2'
      end
      object Label3: TLabel
        Left = 190
        Top = 20
        Width = 32
        Height = 13
        Caption = 'Versus'
      end
      object Bevel1: TBevel
        Left = 5
        Top = 65
        Width = 146
        Height = 6
        Shape = bsBottomLine
      end
      object Bevel2: TBevel
        Left = 260
        Top = 65
        Width = 146
        Height = 6
        Shape = bsBottomLine
      end
      object cboPlayer1: TComboBox
        Left = 5
        Top = 25
        Width = 145
        Height = 21
        Style = csDropDownList
        Sorted = True
        TabOrder = 0
      end
      object cboPlayer2: TComboBox
        Left = 260
        Top = 25
        Width = 145
        Height = 21
        Style = csDropDownList
        Sorted = True
        TabOrder = 1
      end
      object cmdAnalyze: TBitBtn
        Left = 170
        Top = 55
        Width = 75
        Height = 25
        Caption = 'Analyze'
        DoubleBuffered = True
        ParentDoubleBuffered = False
        TabOrder = 2
        OnClick = cmdAnalyzeClick
      end
      object panAnalyze: TPanel
        Left = 0
        Top = 85
        Width = 411
        Height = 196
        BevelOuter = bvNone
        TabOrder = 3
        object lblAnalyze: TLabel
          Left = 45
          Top = 25
          Width = 321
          Height = 13
          Alignment = taCenter
          AutoSize = False
          Caption = 'Results of direct fights between P1 and P2'
        end
        object lblPlayer1: TLabel
          Left = 45
          Top = 75
          Width = 321
          Height = 13
          AutoSize = False
          Caption = 'P1 won X times (x%)'
        end
        object lblPlayer2: TLabel
          Left = 45
          Top = 95
          Width = 321
          Height = 13
          Alignment = taRightJustify
          AutoSize = False
          Caption = 'P2 won X times (x%)'
        end
        object prbPlayer2: TProgressBar
          Left = 370
          Top = 10
          Width = 36
          Height = 176
          Orientation = pbVertical
          Position = 50
          Smooth = True
          TabOrder = 0
        end
        object prbPlayer1: TProgressBar
          Left = 5
          Top = 10
          Width = 36
          Height = 176
          Orientation = pbVertical
          Position = 50
          Smooth = True
          TabOrder = 1
        end
      end
    end
  end
end
