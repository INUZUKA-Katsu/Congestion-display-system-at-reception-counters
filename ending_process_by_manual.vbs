Option Explicit

Sub StopMadoLoop()
  Dim Locator,Service,Items,Item,Program
  Set Locator = WScript.CreateObject("WbemScripting.SWbemLocator")
  Set Service = Locator.ConnectServer
  Set Items   = Service.ExecQuery("Select * From Win32_Process Where CommandLine Like '%mado_Loop.rb%'")
  For Each Item In Items
    Item.terminate
    Program=Item.Caption
  Next
End Sub

Sub StartEndingProcess()
  Dim path,objWshShell
  Set objWshShell = WScript.CreateObject("WScript.Shell")
  path = Replace(WScript.ScriptFullName,WScript.ScriptName,"")
  objWshShell.CurrentDirectory = path
  WScript.CreateObject("WScript.Shell").Run ".\ruby-dist\ruby.exe .\mado_FTP.rb EndingProcess", 0
End Sub

Call StopMadoLoop()
Call StartEndingProcess()
