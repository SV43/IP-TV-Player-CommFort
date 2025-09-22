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
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnPaint = FormPaint
  OnShow = FormShow
  TextHeight = 13
  object Splitter: TSplitter
    Left = 775
    Top = 0
    Height = 455
    Align = alRight
    ExplicitLeft = 549
    ExplicitTop = 16
    ExplicitHeight = 416
  end
  object PanelButton: TPanel
    Left = 0
    Top = 455
    Width = 1108
    Height = 53
    Align = alBottom
    TabOrder = 0
    object sbBack: TSpeedButton
      AlignWithMargins = True
      Left = 4
      Top = 4
      Width = 45
      Height = 45
      Align = alLeft
      ImageIndex = 4
      HotImageIndex = 0
      Flat = True
      OnClick = sbBackClick
    end
    object sbPlay: TSpeedButton
      AlignWithMargins = True
      Left = 55
      Top = 4
      Width = 45
      Height = 45
      Align = alLeft
      Flat = True
      OnClick = sbPlayClick
    end
    object sbNext: TSpeedButton
      AlignWithMargins = True
      Left = 106
      Top = 4
      Width = 45
      Height = 45
      Align = alLeft
      Flat = True
      OnClick = sbNextClick
    end
    object sbFullScreen: TSpeedButton
      AlignWithMargins = True
      Left = 1059
      Top = 4
      Width = 45
      Height = 45
      Align = alRight
      Flat = True
      OnClick = sbFullScreenClick
      ExplicitLeft = 1060
    end
    object sbOpen: TSpeedButton
      AlignWithMargins = True
      Left = 157
      Top = 4
      Width = 45
      Height = 45
      Align = alLeft
      Flat = True
      OnClick = sbOpenClick
    end
    object lbStatus: TLabel
      AlignWithMargins = True
      Left = 220
      Top = 4
      Width = 7
      Height = 45
      Margins.Left = 15
      Align = alLeft
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -19
      Font.Name = 'MS Sans Serif'
      Font.Style = [fsBold]
      ParentFont = False
      Layout = tlCenter
      ExplicitHeight = 24
    end
    object sbVolume: TSpeedButton
      AlignWithMargins = True
      Left = 1008
      Top = 4
      Width = 45
      Height = 45
      Align = alRight
      Flat = True
      OnClick = sbVolumeClick
      ExplicitLeft = 1010
    end
    object lbEPGStatus: TLabel
      Left = 230
      Top = 1
      Width = 5
      Height = 51
      Align = alLeft
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'MS Sans Serif'
      Font.Style = [fsBold]
      ParentFont = False
      ExplicitHeight = 16
    end
    object tvVolume: TImageTrackBar
      Left = 805
      Top = 1
      Width = 200
      Height = 51
      Align = alRight
      Max = 200
      Position = 100
      OnChange = ImageTrackBar1Change
    end
  end
  object pnPlayer: TPanel
    Left = 0
    Top = 0
    Width = 775
    Height = 455
    Align = alClient
    TabOrder = 1
    object VLC_Player: TPasLibVlcPlayer
      Left = 1
      Top = 1
      Width = 773
      Height = 453
      Align = alClient
      PopupMenu = pmMenu
      OnDblClick = VLC_PlayerDblClick
      SnapShotFmt = 'png'
      OnMediaPlayerPlaying = VLC_PlayerMediaPlayerPlaying
      MouseEventsHandler = mehComponent
    end
  end
  object lbChannels: TListBox
    Left = 778
    Top = 0
    Width = 330
    Height = 455
    Style = lbOwnerDrawVariable
    Align = alRight
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'MS Sans Serif'
    Font.Style = [fsBold]
    ItemHeight = 54
    ParentFont = False
    PopupMenu = pmMenu
    TabOrder = 2
    OnDblClick = lbChannelsDblClick
    OnDrawItem = lbChannelsDrawItem
  end
  object pmMenu: TPopupMenu
    Left = 248
    Top = 256
    object C1: TMenuItem
      AutoCheck = True
      Caption = #1057#1087#1080#1089#1086#1082' '#1082#1072#1085#1072#1083#1086#1074
      Checked = True
      OnClick = C1Click
    end
    object N1: TMenuItem
      Caption = #1053#1072#1089#1090#1088#1086#1081#1082#1080
      OnClick = N1Click
    end
  end
  object ilLogos: TImageList
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
    Interval = 3000
    OnTimer = tStatusTimer
    Left = 433
    Top = 257
  end
end
