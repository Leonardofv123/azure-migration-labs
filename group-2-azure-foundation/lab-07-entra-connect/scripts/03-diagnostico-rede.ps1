<#
.SYNOPSIS
    Lab 07 - Bateria de diagnostico de rede na DC01.
.DESCRIPTION
    Roda os testes que foram usados para eliminar hipoteses durante o
    troubleshooting do erro HttpRequestException no endpoint estimateAccess.

    ATENCAO A UMA LICAO DESTE LAB: todos estes testes podem passar e o
    wizard ainda falhar. Teste de conectividade generica (TCP, GET) nao
    cobre POST com payload maior. Se tudo aqui passar e o wizard continuar
    quebrando, a variavel a trocar e a propria rede de saida.
.NOTES
    Rodar no HOST. Acessa a DC01 via Invoke-Command.
#>

$cred = Get-Credential -Message "Credencial do dominio (contoso\administrator)"

Invoke-Command -VMName 'contoso-dc01' -Credential $cred -ScriptBlock {

    Write-Host "=== TLS 1.2 no .NET Framework ===" -ForegroundColor Cyan
    Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' `
        -Name SchUseStrongCrypto -ErrorAction SilentlyContinue |
        Select-Object SchUseStrongCrypto

    Write-Host "=== Forwarders DNS ===" -ForegroundColor Cyan
    Get-DnsServerForwarder -ErrorAction SilentlyContinue

    Write-Host "=== Proxy WinHTTP ===" -ForegroundColor Cyan
    netsh winhttp show proxy

    Write-Host "=== Conectividade TCP 443 ===" -ForegroundColor Cyan
    'login.microsoftonline.com', 'graph.microsoft.com' | ForEach-Object {
        $r = Test-NetConnection -ComputerName $_ -Port 443 -WarningAction SilentlyContinue
        [PSCustomObject]@{
            Endpoint = $_
            TCP443   = $r.TcpTestSucceeded
            IP       = $r.RemoteAddress
        }
    }

    Write-Host "=== Chamada HTTPS real (nao so TCP) ===" -ForegroundColor Cyan
    try {
        $resp = Invoke-WebRequest -Uri 'https://login.microsoftonline.com' `
            -UseBasicParsing -TimeoutSec 15
        Write-Host "Status: $($resp.StatusCode), tamanho: $($resp.RawContentLength) bytes" -ForegroundColor Green
    } catch {
        Write-Host "ERRO: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.InnerException) {
            Write-Host "Inner: $($_.Exception.InnerException.Message)" -ForegroundColor Red
        }
    }

    Write-Host "=== Memoria disponivel ===" -ForegroundColor Cyan
    Get-CimInstance Win32_OperatingSystem |
        Select-Object @{N='LivreGB';E={[math]::Round($_.FreePhysicalMemory/1MB,2)}}

    Write-Host "=== MTU das interfaces ===" -ForegroundColor Cyan
    Get-NetIPInterface -AddressFamily IPv4 |
        Select-Object InterfaceAlias, NlMtu
}
