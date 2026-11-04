# Flytter GIF-ene inn i repoet, så siden ikke trenger storage.kemta.net.
# Krever PowerShell 7 (pwsh). Kjør fra mappa: ./hent-gifs.ps1
# Laster ned alle GIF-er i CSV-ene til img/ og skriver om CSV-ene til relative stier.
# GIF-er som ikke kan lastes ned, beholder den gamle adressen og gir en advarsel.
param([string[]]$Lists = @('gifs', 'dax'))

$ErrorActionPreference = 'Stop'
$imgDir = Join-Path $PSScriptRoot 'img'
New-Item -ItemType Directory -Force -Path $imgDir | Out-Null

foreach ($list in $Lists) {
    $csvPath = Join-Path $PSScriptRoot "$list.csv"
    $rows = Import-Csv $csvPath -Delimiter ';' -Encoding utf8
    foreach ($row in $rows) {
        if ($row.Gif -notmatch '^https?://') { continue }   # allerede lokal
        $name = [IO.Path]::GetFileName(([uri]$row.Gif).AbsolutePath)
        $target = Join-Path $imgDir $name
        if (-not (Test-Path $target)) {
            try {
                Invoke-WebRequest -Uri $row.Gif -OutFile $target
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
