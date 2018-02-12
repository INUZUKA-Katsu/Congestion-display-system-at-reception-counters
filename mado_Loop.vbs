Option Explicit

Dim path,objWshShell

path = Replace(WScript.ScriptFullName,WScript.ScriptName,"")
Set objWshShell = WScript.CreateObject("WScript.Shell")
objWshShell.CurrentDirectory = path

WScript.CreateObject("WScript.Shell").Run ".\ruby-dist\ruby.exe .\mado_Loop.rb", 0
