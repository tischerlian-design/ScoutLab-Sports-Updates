Option Explicit
Dim shell, fso, root, batchPath
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
root = fso.GetParentFolderName(WScript.ScriptFullName)
batchPath = fso.BuildPath(root, "START_SCOUTLAB.bat")
If Not fso.FileExists(batchPath) Then
  MsgBox "START_SCOUTLAB.bat fehlt. Bitte ScoutLab zuerst vollstaendig entpacken und installieren.", vbExclamation, "ScoutLab Sports"
  WScript.Quit 2
End If
shell.Run Chr(34) & batchPath & Chr(34), 0, False
