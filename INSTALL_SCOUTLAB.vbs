Option Explicit
Dim shell, fso, root, batchPath
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
root = fso.GetParentFolderName(WScript.ScriptFullName)
batchPath = fso.BuildPath(root, "INSTALL_SCOUTLAB.bat")
If Not fso.FileExists(batchPath) Then
  MsgBox "INSTALL_SCOUTLAB.bat wurde nicht gefunden. Bitte die ZIP vollstaendig entpacken und diese BAT-Datei starten.", vbExclamation, "ScoutLab Sports"
  WScript.Quit 2
End If
shell.Run Chr(34) & batchPath & Chr(34), 1, False
