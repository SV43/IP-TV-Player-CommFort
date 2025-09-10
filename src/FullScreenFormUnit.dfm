object FullScreenForm: TFullScreenForm
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'FullScreen'
  ClientHeight = 930
  ClientWidth = 1340
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -19
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  OldCreateOrder = False
  Touch.GestureManager = GestureManager1
  Touch.InteractiveGestureOptions = [igoPanSingleFingerHorizontal, igoPanInertia, igoParentPassthrough]
  WindowState = wsMaximized
  OnKeyPress = FormKeyPress
  PixelsPerInch = 96
  TextHeight = 25
  object ActionList1: TActionList
    Left = 120
    Top = 32
    object Action1: TAction
      Caption = 'Action1'
    end
  end
  object GestureManager1: TGestureManager
    Left = 48
    Top = 32
    GestureData = <
      item
        Control = Owner
        Collection = <
          item
            Action = Action1
            GestureID = sgiUp
          end>
      end>
  end
end
