# Lab 06 - Storage Account, Azure Backup e Azure File Sync

## Objetivo

Três entregas relacionadas: criar armazenamento na Azure (Storage Account, File Share e Blob Container), proteger a VM do Lab 05 com Azure Backup, e conectar o File Server on-premises à nuvem via Azure File Sync. Cenário: a Contoso quer tirar os arquivos da FS01 do risco de falha de disco local, mantendo o acesso via SMB como sempre foi, só que com uma cópia espelhada na nuvem. Em paralelo, a VM web ganha backup — como qualquer carga de produção deveria ter desde o primeiro dia.

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
    |  VM em produção        | ---> |  rsv-contoso-eus2            |
    +------------------------+ bkp  |  DefaultPolicy               |
                                    +------------------------------+

    Storage Sync Service: sync-contoso-eus2
    Sync Group: sync-vendas
```

## Pré-requisitos

- Lab 05 concluído (VM `vm-web-prod-eus2` existente).
- Lab 03 concluído (FS01 de pé, ingressada no domínio).
- DC01 ligada — ela é o DNS de todo o ambiente.
- Instalador `StorageSyncAgent_WS2022.msi` (42,1 MB).

## Conceitos

**Storage Account** é a conta que guarda os diferentes tipos de armazenamento da Azure num único namespace. O nome precisa ser único no mundo todo, só letras minúsculas e números — daí o sufixo aleatório.

**Blob Container vs File Share.** Os dois guardam arquivos, mas de formas diferentes. O **Blob** é armazenamento via API/HTTP, sem estrutura de pasta — bom para o que uma aplicação lê e escreve por código. O **File Share** fala o mesmo protocolo SMB de um File Server tradicional, então pode ser mapeado como `Z:\` e usado como pasta normal do Windows. A escolha depende de quem vai consumir: aplicação ou pessoa.

**Recovery Services Vault** é o cofre que guarda políticas e pontos de recuperação. O **Azure Backup** é o serviço que executa — o primeiro backup é sempre Full, os seguintes são incrementais.

**Azure File Sync** tem quatro peças: o **Storage Sync Service** (objeto guarda-chuva), o **Sync Group** (define um par de sincronização), o **Cloud Endpoint** (o lado nuvem) e o **Server Endpoint** (a pasta no servidor local).

**Cloud Tiering** mantém arquivos pouco acessados só na nuvem, deixando um placeholder local. Desabilitado neste lab por simplicidade.

**TLS 1.2 e o .NET Framework.** Mesmo com o sistema operacional suportando TLS 1.2, o .NET Framework pode usar TLS 1.0 por padrão em chamadas HTTP. Como a Azure exige TLS 1.2 no mínimo, isso quebra autenticação de forma silenciosa. Esse detalhe consumiu boa parte do tempo deste lab.

**IE Enhanced Security Configuration** vem ativado por padrão em todo Windows Server e bloqueia conteúdo externo em componentes baseados no motor do Internet Explorer — incluindo telas de login de ferramentas modernas que usam esse motor por baixo dos panos.

## Como rodar

1. `01-storage-account.ps1` — roda **no host**. Cria o Resource Group, a Storage Account com `MinimumTlsVersion TLS1_2`, o File Share `vendas` e o Blob Container `documentos`.

2. `02-azure-backup.ps1` — roda **no host**. Cria o Vault num Resource Group separado (`rg-backup-prod-eus2`), habilita proteção na VM do Lab 05 e dispara um backup sob demanda. A separação por RG é governança: backup é responsabilidade de outro time em ambiente real.

3. `04-fix-tls-permanente.ps1` — roda **dentro da FS01**, antes de qualquer outra coisa. Aplica `SchUseStrongCrypto` no registro. Sem isso, os comandos do passo seguinte falham de forma intermitente.

4. `03-file-sync.ps1` — parte no host (Storage Sync Service e Sync Group), parte dentro da FS01 (registro do servidor). O agente precisa estar instalado na FS01 antes.

5. Criar Cloud Endpoint e Server Endpoint pelo portal, dentro do Sync Group.

> **Atenção ao passo 4.** O registro precisa rodar na **mesma janela do PowerShell** onde o TLS foi forçado. Detalhes em [Desafios encontrados](#desafios-encontrados).

## Validação

```powershell
# Storage
Get-AzStorageShare -Context $ctx
Get-AzStorageContainer -Context $ctx

# Backup
Get-AzRecoveryServicesBackupItem -BackupManagementType AzureVM -WorkloadType AzureVM
# ProtectionStatus deve estar Healthy

# Sincronização — criar arquivo na FS01
"Teste de sincronização - Lab 06" |
    Out-File -FilePath 'C:\VendasLocal\teste-sync.txt' -Encoding utf8
```

O arquivo deve aparecer em poucos minutos no portal, em **Storage Account → File shares → vendas → Browse**.

## Desafios encontrados

Este lab teve o troubleshooting mais longo até aqui, e o mais instrutivo — porque os problemas apareceram em camadas completamente diferentes, uma depois da outra. Um erro escondia o próximo.

### 1. A VM não liga — memória do host

```
Not enough memory in the system to start the virtual machine contoso-dc01
```

A FS01 estava rodando tranquila, usando ~2,3 GB de um host de 16 GB. Parecia sobrar memória. Mas a RAM esgotada era do **host físico**, não das VMs — o consumo vinha de programas e abas abertas no próprio computador.

> **O que ficou:** ao dimensionar um lab de virtualização, contar a memória que o host consome com o uso normal. O total disponível para VMs é sempre menor que a RAM instalada.

### 2. DNS morto na FS01

Timeout completo em qualquer resolução de nome, inclusive local. A causa: a DC01 estava desligada, e ela é o controlador de domínio **e** o servidor DNS do ambiente.

> **O que ficou:** num ambiente com DC única, ela é ponto único de falha para tudo. Antes de diagnosticar problema de rede nas outras máquinas, confirmar que a DC está de pé.

### 3. DNS local funciona, externo não

Depois da DC01 ligar, nomes internos resolviam. Externos continuavam com timeout. A DC01 nunca teve forwarder DNS configurado — sabia resolver `*.contoso.local`, mas não tinha para onde encaminhar o resto.

```powershell
Add-DnsServerForwarder -IPAddress "8.8.8.8" -PassThru
```

### 4. Link de download caindo numa busca do Bing

O link `https://aka.ms/AFSAgent` abria uma página de busca. Causa: cache de DNS antigo no navegador, guardado durante o período em que a resolução externa estava quebrada.

```powershell
ipconfig /flushdns
```

**Armadilha no caminho:** buscando o instalador manualmente, um dos resultados levava a `UpdateDetails.xml` de 3,3 KB. Isso é apenas um manifesto. O arquivo correto é `StorageSyncAgent_WS2022.msi`, com 42,1 MB.

> **O que ficou:** depois de corrigir DNS, limpar o cache local. E conferir o tamanho do arquivo baixado contra o esperado.

### 5. Assistente gráfico bloqueado pelo IE ESC

O `ServerRegistration.exe` abria, mas a tela de login era bloqueada, barrando o domínio `aadcdn.msauth.net`. Configuração padrão de todo Windows Server, que restringe conteúdo externo em qualquer componente baseado no motor do IE — e o assistente usa esse motor por baixo, mesmo parecendo moderno.

Resolvido em **Server Manager → Local Server → IE Enhanced Security Configuration → Off**.

### 6. Assistente diz que não há subscription acessível

```
For the provided username and password, no Azure subscription is accessible
```

A conta estava correta, e o acesso àquela subscription estava confirmado no mesmo dia, pelo Az CLI e pelo PowerShell, na mesma máquina.

**Causa:** o componente de login do assistente usa um controle de navegador legado que não lida bem com fluxos de autenticação modernos. Ele falha e reporta uma mensagem que não corresponde à realidade.

**Solução:** abandonar a interface gráfica e registrar via PowerShell.

> **O que ficou:** quando a mensagem de erro contradiz algo que você acabou de verificar por outro caminho, desconfie da ferramenta que deu o erro — não do fato verificado.

### 7. HttpRequestException no PowerShell

```
HttpRequestException: An error occurred while sending the request
```

O .NET Framework usava TLS 1.0 por padrão. A Azure exige TLS 1.2 no mínimo — a chamada quebrava antes mesmo de tentar autenticar.

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```

### 8. Registro travando por 20 minutos sem erro

`Register-AzStorageSyncServer` ficava pendurado indefinidamente. `Debug-StorageSyncServer -Diagnose` reportou 0 issues. `Test-NetConnection` confirmou porta 443 aberta para os três endpoints de controle. Isso eliminou rede, firewall e DNS.

Foi feita uma atualização do repositório de certificados raiz (`certutil -generateSSTFromWU`). Honestamente: não há certeza de que isso resolveu alguma coisa — a causa real apareceu no item seguinte.

### 9. A causa real — escopo do fix de TLS

Numa nova tentativa, o problema reapareceu em **formato diferente**: erro rápido de `HttpRequestException`, em vez do travamento longo. Essa mudança de sintoma foi a pista. O ambiente era o mesmo, o comando era o mesmo — a única diferença era a janela do PowerShell.

**Causa:** o fix de TLS do item 7 vale **apenas para a sessão** em que foi executado. Uma janela nova volta ao comportamento padrão do .NET Framework. O fix funcionava, mas evaporava a cada janela nova — e como o trabalho estava sendo feito em várias janelas ao longo das tentativas, o comportamento parecia aleatório.

**Solução:** reaplicar na mesma janela onde o registro seria executado, e aplicar o fix permanente via registro do Windows:

```powershell
[Microsoft.Win32.Registry]::SetValue(
    'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\.NETFramework\v4.0.30319',
    'SchUseStrongCrypto', 1, 'DWord')

[Microsoft.Win32.Registry]::SetValue(
    'HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319',
    'SchUseStrongCrypto', 1, 'DWord')
```

> **O que ficou — aprendizado central do lab:** ajuste via `[Net.ServicePointManager]` vale por **processo**, não por máquina. Cada janela nova do PowerShell reinicia com o padrão do .NET. Só o ajuste via registro persiste entre sessões.
>
> E o meta-aprendizado: quando o mesmo problema aparece com sintomas diferentes em tentativas diferentes, procurar o que mudou entre elas — inclusive coisas que parecem irrelevantes, como ter aberto um terminal novo.

## Aprendizados

**Diagnóstico em camadas**

- Os problemas apareceram em camadas distintas: memória física, DNS, segurança do Windows Server, protocolo TLS. Cada um escondia o próximo. Resolver um por vez, de baixo pra cima, é mais rápido que adivinhar.
- Quando o sintoma muda entre tentativas idênticas, a diferença está no contexto — não no comando.
- Ferramenta reportando erro que contradiz uma verificação independente: desconfiar da ferramenta.

**Windows Server**

- IE ESC vem ligado por padrão e bloqueia telas de login de ferramentas modernas.
- Assistentes gráficos de registro costumam ser menos confiáveis que o equivalente em PowerShell.
- `[Net.ServicePointManager]` vale por sessão. `SchUseStrongCrypto` no registro vale para sempre.

**Ambiente de laboratório**

- DC única é ponto único de falha para DNS de todo o ambiente.
- DNS interno precisa de forwarder para resolver nomes externos.
- Depois de corrigir DNS, limpar o cache do cliente.
- RAM do host inclui o que você usa no dia a dia, não só as VMs.

## Custos

| Recurso | Custo |
|---|---|
| Storage Account Standard_LRS | Por GB armazenado |
| File Share | Por GB provisionado |
| Blob Container | Por GB + transações |
| Recovery Services Vault | Por instância protegida + storage |
| Azure File Sync | Por servidor sincronizado |

Volume baixo neste lab, mas o custo é contínuo e proporcional ao uso — diferente do VPN Gateway do Lab 08, que cobra por hora existindo.

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

---

**Próximo:** [Lab 07 - Entra Connect](../lab-07-entra-connect/) — identidade híbrida entre o AD do Lab 02 e o Microsoft Entra ID.
