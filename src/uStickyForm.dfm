object frmStickyForm: TfrmStickyForm
  Left = 457
  Top = 248
  BorderIcons = []
  BorderStyle = bsNone
  Caption = 'Sticky Form'
  ClientHeight = 508
  ClientWidth = 1108
  Color = clWhite
  DoubleBuffered = True
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OnShow = FormShow
  TextHeight = 13
  object Splitter1: TSplitter
    Left = 775
    Top = 0
    Height = 458
    Align = alRight
    ExplicitLeft = 549
    ExplicitTop = 16
    ExplicitHeight = 416
  end
  object PanelButton: TPanel
    Left = 0
    Top = 458
    Width = 1108
    Height = 50
    Align = alBottom
    TabOrder = 0
    object sbBack: TSpeedButton
      Left = 1
      Top = 1
      Width = 56
      Height = 48
      Align = alLeft
      ImageIndex = 4
      HotImageIndex = 0
      Flat = True
      OnClick = sbBackClick
      ExplicitLeft = -5
      ExplicitTop = 5
    end
    object sbPlay: TSpeedButton
      Left = 57
      Top = 1
      Width = 56
      Height = 48
      Align = alLeft
      Flat = True
      ExplicitLeft = 88
      ExplicitTop = 8
      ExplicitHeight = 22
    end
    object sbStop: TSpeedButton
      Left = 113
      Top = 1
      Width = 56
      Height = 48
      Align = alLeft
      Flat = True
      OnClick = sbStopClick
      ExplicitHeight = 54
    end
    object sbNext: TSpeedButton
      Left = 169
      Top = 1
      Width = 56
      Height = 48
      Align = alLeft
      Flat = True
      OnClick = sbNextClick
      ExplicitLeft = 175
      ExplicitTop = 5
    end
    object sbFullScreen: TSpeedButton
      Left = 1051
      Top = 1
      Width = 56
      Height = 48
      Align = alRight
      Flat = True
      OnClick = sbFullScreenClick
      ExplicitLeft = 762
      ExplicitHeight = 54
    end
    object sbOpen: TSpeedButton
      Left = 225
      Top = 1
      Width = 56
      Height = 48
      Align = alLeft
      Flat = True
      OnClick = sbOpenClick
      ExplicitLeft = 281
      ExplicitTop = 5
    end
    object lbStatus: TLabel
      AlignWithMargins = True
      Left = 296
      Top = 4
      Width = 5
      Height = 42
      Margins.Left = 15
      Align = alLeft
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = [fsBold]
      ParentFont = False
      Layout = tlCenter
      ExplicitHeight = 13
    end
    object sbVolume: TSpeedButton
      Left = 995
      Top = 1
      Width = 56
      Height = 48
      Align = alRight
      Flat = True
      OnClick = sbVolumeClick
      ExplicitLeft = 762
      ExplicitHeight = 54
    end
    object tvVolume: TTrackBar
      AlignWithMargins = True
      Left = 813
      Top = 14
      Width = 179
      Height = 32
      Margins.Top = 13
      Align = alRight
      Max = 200
      Position = 100
      TabOrder = 0
      TickStyle = tsNone
      OnChange = tvVolumeChange
    end
  end
  object pnPlayer: TPanel
    Left = 0
    Top = 0
    Width = 775
    Height = 458
    Align = alClient
    TabOrder = 1
    object VLC_Player: TPasLibVlcPlayer
      Left = 1
      Top = 1
      Width = 773
      Height = 456
      ParentCustomHint = False
      Align = alClient
      ParentShowHint = False
      PopupMenu = pmMenu
      ShowHint = False
      SpuShow = False
      OsdShow = False
      AudioOutput = aoWaveOut
      SnapShotFmt = 'png'
      DeinterlaceMode = dmBLEND
      UseEvents = False
      MouseEventsHandler = mehComponent
    end
  end
  object lbIPTVlist: TListBox
    Left = 778
    Top = 0
    Width = 330
    Height = 458
    Style = lbOwnerDrawFixed
    Align = alRight
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'MS Sans Serif'
    Font.Style = [fsBold]
    ItemHeight = 50
    ParentFont = False
    PopupMenu = pmMenu
    TabOrder = 2
    OnDblClick = lbIPTVlistDblClick
    OnDrawItem = lbIPTVlistDrawItem
  end
  object pmMenu: TPopupMenu
    Left = 248
    Top = 256
    object C1: TMenuItem
      AutoCheck = True
      Caption = #1057#1087#1080#1089#1086#1082' '#1082#1072#1085#1072#1083#1086#1074
      Checked = True
    end
    object N1: TMenuItem
      Caption = #1053#1072#1089#1090#1088#1086#1081#1082#1080
      OnClick = N1Click
    end
    object N1231: TMenuItem
      Caption = '123'
    end
  end
  object ilChanel: TImageList
    Height = 50
    Width = 50
    Left = 129
    Top = 225
  end
  object odFile: TOpenDialog
    Left = 329
    Top = 217
  end
  object tStatus: TTimer
    OnTimer = tStatusTimer
    Left = 433
    Top = 257
  end
end
