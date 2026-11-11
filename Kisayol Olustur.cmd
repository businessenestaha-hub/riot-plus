@echo off
rem Masaustune "Riot Plus" kisayolu koyar (simgeli; Ctrl+Alt+L ile de acilir). Klasoru tasirsan yeniden calistir.
set "RP=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$k = $env:RP; $w = New-Object -ComObject WScript.Shell; $s = $w.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'Riot Plus.lnk')); $s.TargetPath = (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'); $s.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"' + (Join-Path $k 'lol-duzelt.ps1') + '\"'; $s.WorkingDirectory = $k; $s.IconLocation = (Join-Path $k 'riot-plus.ico'); $s.Hotkey = 'CTRL+ALT+L'; $s.WindowStyle = 7; $s.Save(); 'Masaustune Riot Plus kisayolu kondu. Ctrl+Alt+L ile de acilir.'"
pause
