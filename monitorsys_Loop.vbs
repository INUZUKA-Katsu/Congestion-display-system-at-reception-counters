Option Explicit

Dim path,objWshShell

Set objWshShell = WScript.CreateObject("WScript.Shell")

path = Replace(WScript.ScriptFullName,WScript.ScriptName,"")

objWshShell.CurrentDirectory = path

WScript.CreateObject("WScript.Shell").Run ".\ruby-dist\ruby.exe .\monitorsys_Loop.rb", 0