# Flytter GIF-ene inn i repoet, så siden ikke trenger storage.kemta.net.
# Krever PowerShell 7 (pwsh). Kjør fra mappa: ./hent-gifs.ps1
# Laster ned alle GIF-er i CSV-ene til img/ og skriver om CSV-ene til relative stier.
# GIF-er som ikke kan lastes ned, beholder den gamle adressen og gir en advarsel.
#
# -HentAlle: går i tillegg gjennom mappelistingen under -KildeUrl (standard /junk/) og
# laster ned alle bildefiler som ikke allerede ligger i img/. Mapper i -HoppOver sjekkes ikke.
# Den venter -PauseMs mellom hvert kall, så serveren ikke tror det er et angrep.
# -ProveKjoring viser hva som ville blitt lastet ned, uten å laste ned noe.
# Eksempel: ./hent-gifs.ps1 -HentAlle -ProveKjoring
param(
    [string[]]$Lists = @('gifs', 'dax'),
    [switch]$HentAlle,
    [string]$KildeUrl = 'http://storage.kemta.net/junk/',
    [string[]]$HoppOver = @('/junk/nes/'),
    [string[]]$Filtyper = @('.gif', '.png', '.jpg', '.jpeg'),
    [int]$PauseMs = 2000,
    [switch]$ProveKjoring
)

$ErrorActionPreference = 'Stop'
$imgDir = Join-Path $PSScriptRoot 'img'
New-Item -ItemType Directory -Force -Path $imgDir | Out-Null

function Invoke-Rolig {
    param([string]$Uri, [string]$OutFile)
    for ($forsok = 1; $forsok -le 4; $forsok++) {
        Start-Sleep -Milliseconds $PauseMs
        try {
            $p = @{ Uri = $Uri; TimeoutSec = 60; UserAgent = 'litgifs-hent-gifs/1.0' }
            if ($OutFile) { Invoke-WebRequest @p -OutFile $OutFile; return }
            return Invoke-WebRequest @p
        } catch {
            if ($forsok -eq 4) { throw }
            $vent = 10 * $forsok
            $retryAfter = $_.Exception.Response.Headers.RetryAfter.Delta
            if ($retryAfter) { $vent = [int]$retryAfter.TotalSeconds }
            Write-Warning "Feil mot $Uri ($($_.Exception.Message)). Prøver igjen om $vent s."
            Start-Sleep -Seconds $vent
        }
    }
}

function Get-Bildefiler {
    param([uri]$Mappe, [hashtable]$Besokt)
    if ($Besokt.ContainsKey($Mappe.AbsoluteUri)) { return }
    $Besokt[$Mappe.AbsoluteUri] = $true
    Write-Host "Leser $($Mappe.AbsolutePath)"
    $html = (Invoke-Rolig -Uri $Mappe.AbsoluteUri).Content
    foreach ($m in [regex]::Matches($html, '(?i)href\s*=\s*["'']([^"''#?]+)["'']')) {
        $url = [uri]::new($Mappe, $m.Groups[1].Value)
        # Bare lenker som ligger under mappa vi leser (ikke ../ eller andre nettsteder)
        if ($url.Host -ne $Mappe.Host -or -not $url.AbsolutePath.StartsWith($Mappe.AbsolutePath) -or
            $url.AbsolutePath -eq $Mappe.AbsolutePath) { continue }
        $sti = [uri]::UnescapeDataString($url.AbsolutePath)
        if ($HoppOver | Where-Object { $sti.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) }) { continue }
        if ($sti.EndsWith('/')) {
            Get-Bildefiler -Mappe $url -Besokt $Besokt
        } elseif ([IO.Path]::GetExtension($sti).ToLowerInvariant() -in $Filtyper) {
            $url
        }
    }
}

if ($HentAlle) {
    $kilde = [uri]($KildeUrl.TrimEnd('/') + '/')
    $filer = @(Get-Bildefiler -Mappe $kilde -Besokt @{} | Sort-Object AbsoluteUri -Unique)
    Write-Host "Fant $($filer.Count) bildefiler under $($kilde.AbsolutePath)"
    $kildeSti = [uri]::UnescapeDataString($kilde.AbsolutePath)
    $iCsv = @{}
    foreach ($list in $Lists) {
        Import-Csv (Join-Path $PSScriptRoot "$list.csv") -Delimiter ';' -Encoding utf8 |
            Where-Object { $_.Gif -match '^https?://' } | ForEach-Object { $iCsv[([uri]$_.Gif).AbsoluteUri] = $true }
    }
    # Ved like filnavn får én fil img/<navn>: først den CSV-ene peker på, så den i gifs/, så den høyest
    # oppe i mappetreet. De andre legges i img/<mappe under /junk/>/<navn>, så ingen bilder blir borte.
    $rangert = $filer | Sort-Object @{ E = { -not $iCsv.ContainsKey($_.AbsoluteUri) } },
        @{ E = { -not [uri]::UnescapeDataString($_.AbsolutePath).StartsWith("$($kildeSti)gifs/") } },
        @{ E = { $_.Segments.Count } }, AbsoluteUri
    $ugyldig = '[' + [regex]::Escape(-join [IO.Path]::GetInvalidFileNameChars()) + ']'
    $brukt = @{}
    $nye = 0
    foreach ($url in $rangert) {
        $deler = @([uri]::UnescapeDataString($url.AbsolutePath).Substring($kildeSti.Length).Split('/') |
            ForEach-Object { $_ -replace $ugyldig, '_' })
        $name = $deler[-1]
        $rel = $name
        if ($brukt.ContainsKey($rel)) {
            $mappe = if ($deler.Count -gt 1) { $deler[0..($deler.Count - 2)] -join '/' } else { 'junk' }
            $rel = "$mappe/$name"
            $n = 2
            while ($brukt.ContainsKey($rel)) {
                $rel = "$mappe/$([IO.Path]::GetFileNameWithoutExtension($name))-$n$([IO.Path]::GetExtension($name))"; $n++
            }
            Write-Host "Samme filnavn finnes fra før ($($brukt[$name])), legger $($url.AbsoluteUri) i img/$rel" -ForegroundColor Yellow
        }
        $brukt[$rel] = $url.AbsoluteUri
        $target = Join-Path $imgDir $rel
        if (Test-Path -LiteralPath $target) { continue }
        if ($ProveKjoring) { Write-Host "Ville hentet $($url.AbsoluteUri) -> img/$rel"; $nye++; continue }
        try {
            New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
            Invoke-Rolig -Uri $url.AbsoluteUri -OutFile $target
            Write-Host "Hentet img/$rel"
            $nye++
        } catch {
            Remove-Item -LiteralPath $target -ErrorAction SilentlyContinue
            Write-Warning "Klarte ikke å hente $($url.AbsoluteUri): $($_.Exception.Message)"
        }
    }
    Write-Host "$nye nye bildefiler$(if ($ProveKjoring) { ' (prøvekjøring)' })" -ForegroundColor Green
    if ($ProveKjoring) { return }
}

foreach ($list in $Lists) {
    $csvPath = Join-Path $PSScriptRoot "$list.csv"
    $rows = Import-Csv $csvPath -Delimiter ';' -Encoding utf8
    foreach ($row in $rows) {
        if ($row.Gif -notmatch '^https?://') { continue }   # allerede lokal
        $name = [IO.Path]::GetFileName(([uri]$row.Gif).AbsolutePath)
        $target = Join-Path $imgDir $name
        if (-not (Test-Path $target)) {
            try {
                Invoke-Rolig -Uri $row.Gif -OutFile $target
                Write-Host "Hentet $name"
            } catch {
                Write-Warning "Klarte ikke å hente $($row.Gif): $($_.Exception.Message)"
                continue
            }
        }
        $row.Gif = "img/$name"
    }
    $rows | Export-Csv $csvPath -Delimiter ';' -Encoding utf8NoBOM -NoTypeInformation -UseQuotes AsNeeded
    Write-Host "Oppdaterte $list.csv" -ForegroundColor Green
}
