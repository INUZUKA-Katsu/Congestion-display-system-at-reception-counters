Option Explicit

Dim Locator,Service,Items,Item,Res,Program

Res=False

Set Locator = WScript.CreateObject("WbemScripting.SWbemLocator")
Set Service = Locator.ConnectServer
Set Items   = Service.ExecQuery("Select * From Win32_Process Where CommandLine Like '%mado_Loop.rb%'")
For Each Item In Items
    Item.terminate
    Program=Item.Caption
    Msgbox "�풓Ruby�v���O�����umado_Loop.rb�v���~���܂����B"
    Res=True    
Next

Set Locator = WScript.CreateObject("WbemScripting.SWbemLocator")
Set Service = Locator.ConnectServer
Set Items   = Service.ExecQuery("Select * From Win32_Process Where CommandLine Like '%monitorsys_Loop.rb%'")
For Each Item In Items
    Item.terminate
    Program=Item.Caption
    Msgbox "�풓Ruby�v���O�����umonitorsys_Loop.rb�v���~���܂����B"
    Res=True    
Next

If Res=False Then
    Msgbox "�풓���Ă���Ruby�v���O�����͂���܂���ł����B"
End If