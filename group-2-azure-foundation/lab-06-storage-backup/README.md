# Lab 06 - Storage Account, Azure Backup e Azure File Sync

## Objetivo

Tres entregas relacionadas: criar armazenamento na Azure (Storage Account, File Share e Blob Container), proteger a VM do Lab 05 com Azure Backup, e conectar o File Server on-premises a nuvem via Azure File Sync. Cenario: a Contoso quer tirar os arquivos da FS01 do risco de falha de disco local, mantendo o acesso via SMB como sempre foi, so que com uma copia espelhada na nuvem. Em paralelo, a VM web ganha backup, como qualquer carga de producao deveria ter desde o primeiro dia.

## Estrutura criada

```
        FS01 (on-prem, Lab 03)              AZURE (Lab 06)

    +------------------------+      +------------------------------+
    |  C:\VendasLocal        | <--> |  Storage Account             |
    |  (Server Endpoint)     | sync |  stcontosoeus2xxxx           |
    +------------------------+      |                              |
                                    |   File Share "vendas"        |
                                    |   (Cloud Endpoint)           |
                                    |                              |
                                    |   Blob Container             |
                                    |   "documentos" (privado)     |
                                    +------------------------------+

    vm-web-prod-eus2 (Lab 05)           Recovery Services Vault
    +------------------------+      +------------------------------+
    |  VM em producao        | ---> |  rsv-contoso-eus2            |
    +------------------------+ bkp  |  DefaultPolicy               |
                                    +------------------------------+

    Storage Sync Service: sync-contoso-eus2
    Sync Group: sync-vendas
```

## Pre-requisitos

- Lab 05 concluido (VM `vm-web-prod-eus2` existente).
- Lab 03 concluido (FS01 de pe, ingressada no dominio).
- DC01 ligada, porque ela e o DNS de todo o ambiente.
- Instalador `StorageSyncAgent_WS2022.msi`, de 42,1 MB.

## Conceitos

**Storage Account** e a conta que guarda os diferentes tipos de armazenamento da Azure num unico namespace. O nome precisa ser unico no mundo todo, so letras minusculas e numeros, dai o sufixo aleatorio.

**Blob Container e File Share** guardam arquivos de formas diferentes. O Blob e armazenamento via API/HTTP, sem estrutura de pasta, bom para o que uma aplicacao le e escreve por codigo. O File Share fala o mesmo protocolo SMB de um File Server tradicional, entao pode ser mapeado como `Z:\` e usado como pasta normal do Windows. A escolha depende de quem vai consumir: aplicacao ou pessoa.

**Recovery Services Vault** e o cofre que guarda politicas e pontos de recuperacao. O **Azure Backup** e o servico que executa. O primeiro backup e sempre Full, os seguintes sao incrementais.

**Azure File Sync** tem quatro pecas: o Storage Sync Service (objeto guarda-chuva), o Sync Group (define um par de sincronizacao), o Cloud Endpoint (o lado nuvem) e o Server Endpoint (a pasta no servidor local).

**Cloud Tiering** mantem arquivos pouco acessados so na nuvem, deixando um placeholder local. Desabilitado neste lab por simplicidade.

**TLS 1.2 e o .NET Framework.** Mesmo com o sistema operacional suportando TLS 1.2, o .NET Framework pode usar TLS 1.0 por padrao em chamadas HTTP. Como a Azure exige TLS 1.2 no minimo, isso quebra autenticacao de forma silenciosa. Esse detalhe consumiu boa parte do tempo deste lab.

**IE Enhanced Security Configuration** vem ativado por padrao em todo Windows Server e bloqueia conteudo externo em componentes baseados no motor do Internet Explorer, incluindo telas de login de ferramentas modernas que usam esse motor por baixo dos panos.

## Como rodar

1. `01-storage-account.ps1` roda no host. Cria o Resource Group, a Storage Account com `MinimumTlsVersion TLS1_2`, o File Share `vendas` e o Blob Container `documentos`.

2. `02-azure-backup.ps1` roda no host. Cria o Vault num Resource Group separado (`rg-backup-prod-eus2`), habilita protecao na VM do Lab 05 e oferece disparar um backup sob demanda. A separacao por RG e governanca: backup e responsabilidade de outro time em ambiente real.

3. `04-fix-tls-permanente.ps1` roda dentro da FS01, antes de qualquer outra coisa. Aplica `SchUseStrongCrypto` no registro. Sem isso, os comandos do passo seguinte falham de forma intermitente.

4. `03-file-sync.ps1` roda parte no host (Storage Sync Service e Sync Group) e parte dentro da FS01 (registro do servidor). O agente precisa estar instalado na FS01 antes.

5. Criar Cloud Endpoint e Server Endpoint pelo portal, dentro do Sync Group.

> **Atencao ao passo 4.** O registro precisa rodar na mesma janela do PowerShell onde o TLS foi forcado. Detalhes em [Desafios encontrados](#desafios-encontrados).

## Validacao

```powershell
# Storage
Get-AzStorageShare -Context $ctx
Get-AzStorageContainer -Context $ctx

# Backup
Get-AzRecoveryServicesBackupItem -BackupManagementType AzureVM -WorkloadType AzureVM
# ProtectionStatus deve estar Healthy

# Sincronizacao, criar arquivo na FS01
"Teste de sincronizacao - Lab 06" |
    Out-File -FilePath 'C:\VendasLocal\teste-sync.txt' -Encoding utf8
```

O arquivo deve aparecer em poucos minutos no portal, em **Storage Account > File shares > vendas > Browse**.

## Desafios encontrados

Este lab teve o troubleshooting mais longo ate aqui, e o mais instrutivo, porque os problemas apareceram em camadas completamente diferentes, uma depois da outra. Um erro escondia o proximo.

### 1. A VM nao liga, memoria do host

```
Not enough memory in the system to start the virtual machine contoso-dc01
```

A FS01 estava rodando tranquila, usando cerca de 2,3 GB de um host de 16 GB. Parecia sobrar memoria. Mas a RAM esgotada era do host fisico, nao das VMs. O consumo vinha de programas e abas abertas no proprio computador.

> **O que ficou:** ao dimensionar um lab de virtualizacao, contar a memoria que o host consome com o uso normal. O total disponivel para VMs e sempre menor que a RAM instalada.

### 2. DNS morto na FS01

Timeout completo em qualquer resolucao de nome, inclusive local. A causa: a DC01 estava desligada, e ela e o controlador de dominio e o servidor DNS do ambiente.

> **O que ficou:** num ambiente com DC unica, ela e ponto unico de falha para tudo. Antes de diagnosticar problema de rede nas outras maquinas, confirmar que a DC esta de pe.

### 3. DNS local funciona, externo nao

Depois da DC01 ligar, nomes internos resolviam. Externos continuavam com timeout. A DC01 nunca teve forwarder DNS configurado: sabia resolver `*.contoso.local`, mas nao tinha para onde encaminhar o resto.

```powershell
Add-DnsServerForwarder -IPAddress "8.8.8.8" -PassThru
```

### 4. Link de download caindo numa busca do Bing

O link `https://aka.ms/AFSAgent` abria uma pagina de busca. Causa: cache de DNS antigo no navegador, guardado durante o periodo em que a resolucao externa estava quebrada.

```powershell
ipconfig /flushdns
```

**Armadilha no caminho:** buscando o instalador manualmente, um dos resultados levava a `UpdateDetails.xml` de 3,3 KB. Isso e apenas um manifesto. O arquivo correto e `StorageSyncAgent_WS2022.msi`, com 42,1 MB.

> **O que ficou:** depois de corrigir DNS, limpar o cache local. E conferir o tamanho do arquivo baixado contra o esperado.

### 5. Assistente grafico bloqueado pelo IE ESC

O `ServerRegistration.exe` abria, mas a tela de login era bloqueada, barrando o dominio `aadcdn.msauth.net`. Configuracao padrao de todo Windows Server, que restringe conteudo externo em qualquer componente baseado no motor do IE. E o assistente usa esse motor por baixo, mesmo parecendo moderno.

Resolvido em **Server Manager > Local Server > IE Enhanced Security Configuration > Off**.

### 6. Assistente diz que nao ha subscription acessivel

```
For the provided username and password, no Azure subscription is accessible
```

A conta estava correta, e o acesso aquela subscription estava confirmado no mesmo dia, pelo Az CLI e pelo PowerShell, na mesma maquina.

**Causa:** o componente de login do assistente usa um controle de navegador legado que nao lida bem com fluxos de autenticacao modernos. Ele falha e reporta uma mensagem que nao corresponde a realidade.

**Solucao:** abandonar a interface grafica e registrar via PowerShell.

> **O que ficou:** quando a mensagem de erro contradiz algo que voce acabou de verificar por outro caminho, desconfie da ferramenta que deu o erro, nao do fato verificado.

### 7. HttpRequestException no PowerShell

```
HttpRequestException: An error occurred while sending the request
```

O .NET Framework usava TLS 1.0 por padrao. A Azure exige TLS 1.2 no minimo, entao a chamada quebrava antes mesmo de tentar autenticar.

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```

### 8. Registro travando por 20 minutos sem erro

`Register-AzStorageSyncServer` ficava pendurado indefinidamente. `Debug-StorageSyncServer -Diagnose` reportou 0 issues. `Test-NetConnection` confirmou porta 443 aberta para os tres endpoints de controle. Isso eliminou rede, firewall e DNS.

Foi feita uma atualizacao do repositorio de certificados raiz com `certutil -generateSSTFromWU`. Honestamente: nao ha certeza de que isso resolveu alguma coisa, porque a causa real apareceu no item seguinte.

### 9. A causa real, escopo do fix de TLS

Numa nova tentativa, o problema reapareceu em formato diferente: erro rapido de `HttpRequestException`, em vez do travamento longo. Essa mudanca de sintoma foi a pista. O ambiente era o mesmo, o comando era o mesmo, e a unica diferenca era a janela do PowerShell.

**Causa:** o fix de TLS do item 7 vale apenas para a sessao em que foi executado. Uma janela nova volta ao comportamento padrao do .NET Framework. O fix funcionava, mas evaporava a cada janela nova. E como o trabalho estava sendo feito em varias janelas ao longo das tentativas, o comportamento parecia aleatorio.

**Solucao:** reaplicar na mesma janela onde o registro seria executado, e aplicar o fix permanente via registro do Windows:

```powershell
[Microsoft.Win32.Registry]::SetValue(
    'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\.NETFramework\v4.0.30319',
    'SchUseStrongCrypto', 1, 'DWord')

[Microsoft.Win32.Registry]::SetValue(
    'HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319',
    'SchUseStrongCrypto', 1, 'DWord')
```

> **O que ficou, aprendizado central do lab:** ajuste via `[Net.ServicePointManager]` vale por processo, nao por maquina. Cada janela nova do PowerShell reinicia com o padrao do .NET. So o ajuste via registro persiste entre sessoes.
>
> E o meta-aprendizado: quando o mesmo problema aparece com sintomas diferentes em tentativas diferentes, procurar o que mudou entre elas, inclusive coisas que parecem irrelevantes, como ter aberto um terminal novo.

## Aprendizados

**Diagnostico em camadas**

- Os problemas apareceram em camadas distintas: memoria fisica, DNS, seguranca do Windows Server, protocolo TLS. Cada um escondia o proximo. Resolver um por vez, de baixo pra cima, e mais rapido que adivinhar.
- Quando o sintoma muda entre tentativas identicas, a diferenca esta no contexto, nao no comando.
- Ferramenta reportando erro que contradiz uma verificacao independente: desconfiar da ferramenta.

**Windows Server**

- IE ESC vem ligado por padrao e bloqueia telas de login de ferramentas modernas.
- Assistentes graficos de registro costumam ser menos confiaveis que o equivalente em PowerShell.
- `[Net.ServicePointManager]` vale por sessao. `SchUseStrongCrypto` no registro vale para sempre.

**Ambiente de laboratorio**

- DC unica e ponto unico de falha para DNS de todo o ambiente.
- DNS interno precisa de forwarder para resolver nomes externos.
- Depois de corrigir DNS, limpar o cache do cliente.
- RAM do host inclui o que voce usa no dia a dia, nao so as VMs.

## Custos

| Recurso | Custo |
|---|---|
| Storage Account Standard_LRS | Por GB armazenado |
| File Share | Por GB provisionado |
| Blob Container | Por GB e transacoes |
| Recovery Services Vault | Por instancia protegida e storage |
| Azure File Sync | Por servidor sincronizado |

Volume baixo neste lab, mas o custo e continuo e proporcional ao uso, diferente do VPN Gateway do Lab 08, que cobra por hora existindo.

## Estrutura de arquivos

```
lab-06-storage-backup/
├── README.md
├── scripts/
│   ├── 01-storage-account.ps1
│   ├── 02-azure-backup.ps1
│   ├── 03-file-sync.ps1
│   └── 04-fix-tls-permanente.ps1
└── screenshots/
```

**Proximo:** [Lab 07 - Entra Connect](../lab-07-entra-connect/), identidade hibrida entre o AD do Lab 02 e o Microsoft Entra ID.
