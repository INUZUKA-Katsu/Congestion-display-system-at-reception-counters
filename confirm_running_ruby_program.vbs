Option Explicit

Dim Locator,Service,Items,Item,Res

  Res=False
  Set Locator = WScript.CreateObject("WbemScripting.SWbemLocator")
  Set Service = Locator.ConnectServer
  Set Items   = Service.ExecQuery("Select * From Win32_Process Where CommandLine Like '%.rb%'")
  For Each Item In Items
    msgbox Item.CommandLine,0,"実行中Rubyプログラム"
    Res=True
  Next

If Res=False Then
    msgbox "実行中Rubyプログラムはありません。"
End If
