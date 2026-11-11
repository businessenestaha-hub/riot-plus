@echo off
rem Masaustune "LSM" kisayolu koyar (simgeli; Ctrl+Alt+L ile de acilir); eski "Riot Plus" kisayolunu kaldirir. Klasoru tasirsan yeniden calistir.
set "RP=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$k = $env:RP; $m = [Environment]::GetFolderPath('Desktop'); $w = New-Object -ComObject WScript.Shell; Remove-Item (Join-Path $m 'Riot Plus.lnk') -ErrorAction SilentlyContinue; $s = $w.CreateShortcut((Join-Path $m 'LSM.lnk')); $s.TargetPath = (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'); $s.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"' + (Join-Path $k 'lol-duzelt.ps1') + '\"'; $s.WorkingDirectory = $k; $s.IconLocation = (Join-Path $k 'riot-plus.ico'); $s.Description = 'LoL Skin Manager'; $s.Hotkey = 'CTRL+ALT+L'; $s.WindowStyle = 7; $s.Save(); 'Masaustune LSM kisayolu kondu. Ctrl+Alt+L ile de acilir.'"
pause
