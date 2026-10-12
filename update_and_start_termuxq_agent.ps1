param(
    [string]$TargetDirectory = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Port = 8765
$AgentFile = Join-Path $TargetDirectory 'termuxq_agent.py'
$AgentUrl = 'https://raw.githubusercontent.com/basojhie/termuxq-next/main/termuxq_agent.py'
$TempFile = Join-Path $TargetDirectory 'termuxq_agent.download.tmp'
$BackupDirectory = Join-Path $env:LOCALAPPDATA 'TermuxQ\agent-backups'

try {
    if (-not (Test-Path -LiteralPath $TargetDirectory -PathType Container)) {
        throw ('Folder tujuan tidak ditemukan: ' + $TargetDirectory)
    }

    Write-Host ''
    Write-Host '=== TermuxQ Agent Auto Update ===' -ForegroundColor Cyan
    Write-Host ('Folder agent: ' + $TargetDirectory)
    Write-Host 'Mengunduh agent terbaru dari repository TermuxQ...'

    Invoke-WebRequest -UseBasicParsing -Uri $AgentUrl -OutFile $TempFile
    $candidate = Get-Content -LiteralPath $TempFile -Raw
    if ($candidate -notmatch 'private_lan_ping' -or $candidate -notmatch 'def ping_host' -or $candidate -notmatch 'agent_version') {
        throw 'File unduhan tidak memiliki penanda versi dan fitur LAN ping yang diharapkan. File lama tidak diubah.'
    }

    $python = Get-Command python -ErrorAction SilentlyContinue
    $pythonPrefix = @()
    if (-not $python) {
        $python = Get-Command py -ErrorAction SilentlyContinue
        if ($python) { $pythonPrefix = @('-3') }
    }
    if (-not $python) {
        throw 'Python belum ditemukan. Instal Python 3 dari python.org, aktifkan Add Python to PATH, lalu jalankan file ini kembali.'
    }

    if (-not (Test-Path -LiteralPath $BackupDirectory)) {
        New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
    }
    if (Test-Path -LiteralPath $AgentFile -PathType Leaf) {
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $backupFile = Join-Path $BackupDirectory ('termuxq_agent_' + $stamp + '.py')
        Copy-Item -LiteralPath $AgentFile -Destination $backupFile
        Write-Host ('Cadangan agent lama: ' + $backupFile) -ForegroundColor DarkGray
    }

    # Stop only the process listening on port 8765 when its command line identifies
    # the TermuxQ agent. Refuse to stop another application occupying the port.
    $listeners = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty OwningProcess -Unique)
    foreach ($listenerPid in $listeners) {
        if (-not $listenerPid -or $listenerPid -le 0) { continue }
        $processInfo = Get-CimInstance Win32_Process -Filter ('ProcessId = ' + [int]$listenerPid) -ErrorAction SilentlyContinue
        if (-not $processInfo) { continue }
        $isPython = $processInfo.Name -match '(?i)^(python|pythonw|py|python3(?:\.\d+)?)\.exe$'
        $isTermuxQ = $processInfo.CommandLine -match '(?i)termuxq_agent\.py'
        if ($isPython -and $isTermuxQ) {
            Stop-Process -Id ([int]$listenerPid) -Force
            Start-Sleep -Milliseconds 700
            Write-Host ('Agent lama dihentikan (PID ' + $listenerPid + ').') -ForegroundColor DarkGray
        } else {
            throw ('Port ' + $Port + ' sedang dipakai proses lain (PID ' + $listenerPid + ', ' + $processInfo.Name + '). Tidak dihentikan demi keamanan.')
        }
    }

    Move-Item -LiteralPath $TempFile -Destination $AgentFile -Force
    $pythonArgumentList = @($pythonPrefix) + @(('"' + $AgentFile + '"'))
    Start-Process -FilePath $python.Source -ArgumentList $pythonArgumentList -WorkingDirectory $TargetDirectory
    Write-Host 'Agent baru sedang dinyalakan. Memverifikasi dukungan LAN ping...'

    $verified = $false
    $stats = $null
    for ($attempt = 1; $attempt -le 15; $attempt++) {
        Start-Sleep -Seconds 1
        try {
            $stats = Invoke-RestMethod -Uri ('http://127.0.0.1:' + $Port + '/stats') -TimeoutSec 2
            if ($stats.agent_version -eq '2.1.0' -and $stats.features -contains 'private_lan_ping') {
                $verified = $true
                break
            }
        } catch {
            # The new process may need another second to start.
        }
    }

    if (-not $verified) {
        throw 'Agent belum berhasil diverifikasi. Pastikan Python berjalan dan port 8765 tidak diblokir. File agent baru tetap tersimpan; cek jendela agent untuk pesan error.'
    }

    Write-Host ''
    Write-Host ('BERHASIL: TermuxQ Agent ' + $stats.agent_version + ' aktif.') -ForegroundColor Green
    Write-Host ('Perangkat: ' + $stats.host)
    Write-Host 'Fitur LAN ping: tersedia.'
    Write-Host 'Sekarang segarkan browser dengan Ctrl+F5, buka LAN Device Monitor, lalu ulangi ping.'
} catch {
    Write-Host ''
    Write-Host ('GAGAL: ' + $_.Exception.Message) -ForegroundColor Red
    if (Test-Path -LiteralPath $TempFile) {
        Remove-Item -LiteralPath $TempFile -Force -ErrorAction SilentlyContinue
    }
    exit 1
} finally {
    Write-Host ''
}
Read-Host 'Tekan Enter untuk menutup'
