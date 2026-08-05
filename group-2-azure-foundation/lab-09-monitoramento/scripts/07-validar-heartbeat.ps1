<#
.SYNOPSIS
    Lab 09 - Valida que todas as maquinas estao reportando.
.DESCRIPTION
    O Heartbeat e a tabela mais rapida a popular: o agente manda sinal
    de vida a cada minuto. Se a maquina aparece aqui, a pipeline inteira
    esta funcionando (agente, DCR, associacao, workspace).
.NOTES
    Rodar no HOST.
#>

$ws = az monitor log-analytics workspace show `
    --resource-group rg-monitor-prod-eus2 `
    --workspace-name law-contoso-eus2 `
    --query customerId --output tsv

Write-Host "Ultimo sinal de cada maquina:" -ForegroundColor Cyan

az monitor log-analytics query `
    --workspace $ws `
    --analytics-query "Heartbeat | summarize UltimoSinal = max(TimeGenerated) by Computer | order by Computer asc" `
    --output table

Write-Host ""
Write-Host "Performance counters coletados:" -ForegroundColor Cyan

az monitor log-analytics query `
    --workspace $ws `
    --analytics-query "Perf | summarize Amostras=count() by Computer, CounterName | order by Computer asc, Amostras desc" `
    --output table

Write-Host ""
Write-Host "Se alguma maquina nao aparecer, verifique nesta ordem:" -ForegroundColor Yellow
Write-Host "  1. A associacao da DCR existe?"
Write-Host "     az monitor data-collection rule association list --resource <id> -o table"
Write-Host "  2. O processo AMAExtHealthMonitor esta rodando na maquina?"
Write-Host "     (Get-Process, nao Get-Service)"
Write-Host "  3. Passaram pelo menos 10 minutos desde a associacao?"
