Option Explicit

Dim Locator,Service,Items,Item,Res,Program

Res=False

Set Locator = WScript.CreateObject("WbemScripting.SWbemLocator")
Set Service = Locator.ConnectServer
Set Items   = Service.ExecQuery("Select * From Win32_Process Where CommandLine Like '%mado_Loop.rb%'")
For Each Item In Items
    Item.terminate
    Program=Item.Caption
    Msgbox "常駐Rubyプログラム「mado_Loop.rb」を停止しました。"
    Res=True    
Next

Set Locator = WScript.CreateObject("WbemScripting.SWbemLocator")
Set Service = Locator.ConnectServer
Set Items   = Service.ExecQuery("Select * From Win32_Process Where CommandLine Like '%monitorsys_Loop.rb%'")
For Each Item In Items
    Item.terminate
    Program=Item.Caption
    Msgbox "常駐Rubyプログラム「monitorsys_Loop.rb」を停止しました。"
    Res=True    
Next

If Res=False Then
    Msgbox "常駐しているRubyプログラムはありませんでした。"
End If