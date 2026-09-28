<#-------------------------------------------------------------------
Apprentissage PowerShell - Script n° 2
 Auteur BD – 17/12/2013
 ---------------------------------------------------------------------#>
 $dossier = $args[0]
 Write-Host "calcul en cours sur $dossier"
 Get-ChildItem -Path $dossier -Recurse -Force | `
    where-object {$_PsisContainer -ne 0} | `
    Where-object {$_.Length -gt 1MB} | `
        Measure-Object -property Length -Sum | `
            ForEach-Object {
                $total = $_.sum / 1MB
            write-host -foregroundColor yellow ("le dossier "+$dossier+" contient {0:#,##0.0} MB" -f $total)
 }