# LSM (LoL Skin Manager) kurulum ve guncelleme betigi.
# Kullanim (PowerShell'e yapistir):
#     irm https://raw.githubusercontent.com/businessenestaha-hub/riot-plus/main/kur.ps1 | iex
# Ilk seferde kurar (C:\Users\<ad>\LSM), masaustune kisayol koyar ve acar. Tekrar calistirilinca gunceller; ayarlar korunur.
# Uygulama baska bir klasordeyse (masaustundeki LSM kisayolu oraya bakiyorsa) orayi gunceller.
# Ayarlari sifirlamak icin once:  $env:LSMSIFIRLA='1'
# Not: bu dosyada bilerek yalniz ASCII karakter var (irm ile okunurken Turkce harfler bozulabiliyor) ve komut kisa tutuldu:
# uzun komutlar Discord gibi yerlerde yapistirilirken alt cizgiler yutuluyor (14 Kas 2026: Win32_Process -> Win32Process).
& {
    $ErrorActionPreference = 'Stop'
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        # Acik LSM varsa kapat (dosyalari degistirebilmek icin)
        Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -like '*lol-duzelt*' } |
            ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Milliseconds 800

        $masaustu = [Environment]::GetFolderPath('Desktop')
        $kisayol = Join-Path $masaustu 'LSM.lnk'
        $kabuk = New-Object -ComObject WScript.Shell
        $hedef = $null
        if (Test-Path -LiteralPath $kisayol) {
            $eski = $kabuk.CreateShortcut($kisayol).WorkingDirectory
            if ($eski -and (Test-Path -LiteralPath (Join-Path $eski 'lol-duzelt.ps1'))) { $hedef = $eski }
        }
        if (-not $hedef) { $hedef = Join-Path $env:USERPROFILE 'LSM' }

        $zip = Join-Path $env:TEMP 'lsm.zip'
        $ac = Join-Path $env:TEMP 'lsm-ac'
        Write-Host 'LSM indiriliyor...'
        Invoke-WebRequest 'https://github.com/businessenestaha-hub/riot-plus/archive/refs/heads/main.zip' -OutFile $zip -UseBasicParsing
        if (Test-Path -LiteralPath $ac) { Remove-Item -LiteralPath $ac -Recurse -Force }
        Expand-Archive -LiteralPath $zip -DestinationPath $ac -Force
        $kaynak = Get-ChildItem -LiteralPath $ac -Directory | Select-Object -First 1
        if (-not $kaynak -or -not (Test-Path -LiteralPath (Join-Path $kaynak.FullName 'lol-duzelt.ps1'))) { throw 'indirilen pakette uygulama yok' }

        New-Item -ItemType Directory -Force $hedef | Out-Null
        Copy-Item (Join-Path $kaynak.FullName '*') $hedef -Recurse -Force
        if (-not (Test-Path -LiteralPath (Join-Path $hedef 'lol-duzelt.ps1'))) { throw 'dosyalar kopyalanamadi' }
        if ($env:LSMSIFIRLA -eq '1') {
            Remove-Item -LiteralPath (Join-Path $hedef 'ayarlar.json') -Force -ErrorAction SilentlyContinue
            $env:LSMSIFIRLA = $null
            Write-Host 'Ayarlar sifirlandi.'
        }

        # Kisayol ancak dosyalar yerindeyse kurulur
        $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $arg = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + (Join-Path $hedef 'lol-duzelt.ps1') + '"'
        $s = $kabuk.CreateShortcut($kisayol)
        $s.TargetPath = $ps
        $s.Arguments = $arg
        $s.WorkingDirectory = $hedef
        $s.IconLocation = (Join-Path $hedef 'riot-plus.ico')
        $s.Description = 'LoL Skin Manager'
        $s.Hotkey = 'CTRL+ALT+L'
        $s.WindowStyle = 7
        $s.Save()
        if (Test-Path -LiteralPath $kisayol) { Remove-Item -LiteralPath (Join-Path $masaustu 'Riot Plus.lnk') -Force -ErrorAction SilentlyContinue }

        Start-Process -FilePath $ps -ArgumentList $arg
        Write-Host ('LSM hazir: ' + $hedef) -ForegroundColor Green
    } catch {
        Write-Host ('HATA: ' + $_.Exception.Message) -ForegroundColor Red
        Write-Host 'Bu satiri oldugu gibi ilet.'
    }
}
