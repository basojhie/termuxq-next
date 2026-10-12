param(
    [string]$TargetDirectory = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Port = 8765
$AgentUrl = 'https://raw.githubusercontent.com/basojhie/termuxq-next/main/termuxq_agent.py'
$TempFile = $null
$AgentFile = $null
$BackupDirectory = Join-Path $env:LOCALAPPDATA 'TermuxQ\agent-backups'

try {
    # Normalize common copy/paste mistakes: surrounding quotes, or a filename
    # passed where a folder was expected.
    if ([string]::IsNullOrWhiteSpace($TargetDirectory)) {
        $TargetDirectory = $PSScriptRoot
    }
    # Strip quote characters independently: Windows command-line parsing can
    # leave only the trailing quote when the argument ends in a backslash.
    $TargetDirectory = $TargetDirectory.Trim().Trim([char[]]@(34, 39)).Trim()

    if ([string]::IsNullOrWhiteSpace($TargetDirectory)) {
        throw 'Folder tujuan kosong. Masukkan folder tempat termuxq_agent.py berada.'
    }

    # If a file path was pasted, use its parent folder when it is a known file.
    if (Test-Path -LiteralPath $TargetDirectory -PathType Leaf) {
        $leafName = [System.IO.Path]::GetFileName($TargetDirectory)
        if ($leafName -match '^(?i:termuxq_agent\.py|update_and_start_termuxq_agent\.ps1)$') {
            $TargetDirectory = Split-Path -Parent $TargetDirectory
        } else {
            throw 'Kamu memasukkan path file, bukan folder. Pilih folder yang berisi termuxq_agent.py.'
        }
    }

    try {
        $TargetDirectory = [System.IO.Path]::GetFullPath($TargetDirectory)
    } catch {
        throw ('Path folder tidak valid. Hapus tanda kutip tambahan dan masukkan path folder saja. Detail: ' + $_.Exception.Message)
    }

    if (-not (Test-Path -LiteralPath $TargetDirectory -PathType Container)) {
        throw ('Folder tujuan tidak ditemukan: ' + $TargetDirectory)
    }

    $AgentFile = Join-Path $TargetDirectory 'termuxq_agent.py'
    $TempFile = Join-Path $TargetDirectory 'termuxq_agent.download.tmp'

    Write-Host ''
    Write-Host '=== TermuxQ Agent Auto Update ===' -ForegroundColor Cyan
    Write-Host ('Folder agent: ' + $TargetDirectory)
    Write-Host 'Mengunduh Agent terbaru dari repository resmi...'

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
        throw 'Python belum ditemukan. Instal Python 3, aktifkan Add Python to PATH, lalu jalankan file ini kembali.'
    }

    New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
    if (Test-Path -LiteralPath $AgentFile -PathType Leaf) {
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $backupFile = Join-Path $BackupDirectory ('termuxq_agent_' + $stamp + '.py')
        Copy-Item -LiteralPath $AgentFile -Destination $backupFile
        Write-Host ('Cadangan Agent lama: ' + $backupFile) -ForegroundColor DarkGray
    }

    # Stop only a listener whose process is clearly the TermuxQ Python Agent.
    $listeners = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty OwningProcess -Unique)
    foreach ($listenerProcessId in $listeners) {
        if (-not $listenerProcessId -or $listenerProcessId -le 0) { continue }
        $processInfo = Get-CimInstance Win32_Process -Filter ('ProcessId = ' + [int]$listenerProcessId) -ErrorAction SilentlyContinue
        if (-not $processInfo) { continue }
        $isPython = $processInfo.Name -match '(?i)^(python|pythonw|py|python3(?:\.\d+)?)\.exe$'
        $isTermuxQ = $processInfo.CommandLine -match '(?i)termuxq_agent\.py'
        if ($isPython -and $isTermuxQ) {
            Stop-Process -Id ([int]$listenerProcessId) -Force
            Start-Sleep -Milliseconds 800
            Write-Host ('Agent lama dihentikan (PID ' + $listenerProcessId + ').') -ForegroundColor DarkGray
        } else {
            throw ('Port ' + $Port + ' sedang dipakai proses lain (PID ' + $listenerProcessId + ', ' + $processInfo.Name + '). Tidak dihentikan demi keamanan.')
        }
    }

    Move-Item -LiteralPath $TempFile -Destination $AgentFile -Force
    $pythonArgumentList = @($pythonPrefix) + @('"' + $AgentFile + '"')
    Start-Process -FilePath $python.Source -ArgumentList $pythonArgumentList -WorkingDirectory $TargetDirectory
    Write-Host 'Agent baru berjalan; memverifikasi dukungan LAN ping...'

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
            # Give the Agent time to start.
        }
    }

    if (-not $verified) {
        throw 'Agent belum berhasil diverifikasi. Pastikan Python berjalan dan port 8765 tidak diblokir. Cek proses Agent untuk pesan error.'
    }

    Write-Host ''
    Write-Host ('BERHASIL: TermuxQ Agent ' + $stats.agent_version + ' aktif.') -ForegroundColor Green
    Write-Host ('Perangkat: ' + $stats.host)
    Write-Host 'Fitur LAN ping: tersedia.'
    Write-Host 'Segarkan browser dengan Ctrl+F5, buka LAN Device Monitor, lalu coba ping kembali.'
} catch {
    # Preserve the original error; cleanup must never replace it with another path error.
    $originalMessage = $_.Exception.Message
    Write-Host ''
    Write-Host ('GAGAL: ' + $originalMessage) -ForegroundColor Red
    if (-not [string]::IsNullOrWhiteSpace($TempFile)) {
        try {
            Remove-Item -LiteralPath $TempFile -Force -ErrorAction Stop
        } catch {
            Write-Host ('Peringatan: file sementara tidak berhasil dihapus: ' + $_.Exception.Message) -ForegroundColor DarkYellow
        }
    }
    exit 1
} finally {
    Write-Host ''
}
Read-Host 'Tekan Enter untuk menutup'
