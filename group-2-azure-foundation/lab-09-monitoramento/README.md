# Lab 09 - Monitoramento Híbrido (Azure Monitor + Log Analytics + Azure Arc)

## Objetivo

Centralizar o monitoramento de toda a infraestrutura da Contoso — servidores on-premises e recursos Azure — num único Log Analytics Workspace, usando Azure Arc para estender o plano de controle do Azure até as máquinas Hyper-V. Ao final, as quatro máquinas do ambiente reportam métricas de performance e event logs para o mesmo workspace, consultáveis pelas mesmas queries KQL, independente de onde estejam rodando.

## Estrutura criada

```
              ON-PREMISES (Hyper-V)                          AZURE

    +----------------------------------+
    |  contoso-dc01   AD DS + DNS      |--+
    |  + azcmagent (Arc) + AMA         |  |
    |                                  |  |
    |  contoso-fs01   File Server      |--+
    |  + azcmagent (Arc) + AMA         |  |      HTTPS / 443
    |                                  |  +----------------------+
    |  contoso-web01  IIS              |--+                      |
    |  + azcmagent (Arc) + AMA         |                         v
    +----------------------------------+         +---------------------------+
                                                 |  dcr-windows-contoso      |
    +----------------------------------+         |  (Data Collection Rule)   |
    |  vm-web-prod-eus2                |-------->|  - 7 perf counters @ 60s  |
    |  10.10.1.4                       |         |  - System / Application   |
    |  + AMA (extensão nativa)         |         |  - Security (4624, 4625,  |
    +----------------------------------+         |    4720, 4726)            |
                                                 +-------------+-------------+
                                                               |
                                                               v
                                                 +---------------------------+
                                                 |  law-contoso-eus2         |
                                                 |  Log Analytics Workspace  |
                                                 |  PerGB2018 / 31 dias      |
                                                 +-------------+-------------+
                                                               |
                                    +--------------------------+-------------+
                                    v                          v             v
                              Queries KQL                  Alertas      Workbooks
```

## Pré-requisitos

- Labs 01-04 concluídos (DC01, FS01 e WEB01 de pé).
- Lab 05 concluído (VM `vm-web-prod-eus2`).
- Resource providers do Arc registrados na subscription (ver passo 5).

## Conceitos

**Azure Arc** estende o plano de controle do Azure para máquinas que não estão nele — servidores on-premises, outras nuvens, qualquer lugar. Instala um agente (`azcmagent`) que registra a máquina como um recurso do Azure, com Resource ID próprio. A partir daí ela aceita as mesmas ferramentas de uma VM nativa: extensões, Azure Policy, RBAC.

**Azure Monitor Agent (AMA)** é quem coleta os dados dentro da máquina. Detalhe importante: nesta versão ele roda como **processo monitorado** (`AMAExtHealthMonitor.exe`), não como serviço Windows tradicional. Procurar por `Get-Service AzureMonitorAgent` não encontra nada — e isso gerou um diagnóstico errado neste lab.

**Data Collection Rule (DCR)** define o que coletar e para onde mandar. É um recurso independente, reutilizável entre várias máquinas.

**Como as peças se encaixam.** Três componentes precisam existir **e estar ligados entre si**:

```
   AGENTE (AMA)              DCR                    WORKSPACE
"quem coleta"          "o que coletar"          "onde guardar"
       |                      |                        |
       +----------------------+------------------------+
                              |
                    ASSOCIAÇÃO (DCRA)
              "esta máquina usa esta regra"
```

A **associação** é um recurso separado e explícito. Instalar o agente e criar a DCR não é suficiente — sem a associação, o agente roda saudável mas sem instrução nenhuma, e nada chega ao workspace. A ausência de qualquer uma das três peças produz silêncio: sem erro, sem aviso.

## Como rodar

Todos os comandos rodam **no host**, via Azure CLI ou `Invoke-Command`.

1. `01-criar-workspace.ps1` — cria `rg-monitor-prod-eus2` e o workspace `law-contoso-eus2`. Guardar o `customerId` retornado; é o Workspace ID usado nas queries.

2. `02-criar-dcr.ps1` — cria a DCR a partir de `dcr-windows.json`. Na primeira execução, o CLI instala a extensão `monitor-control-service` automaticamente.

3. `03-associar-dcr-vm.ps1` — associa a DCR à VM Azure.

4. `04-criar-service-principal.ps1` — cria o SP de onboarding com papel **Azure Connected Machine Resource Administrator**, escopo de **subscription** (não de resource group).

5. **Registrar os providers do Arc.** Obrigatório antes de qualquer onboarding:

   ```powershell
   az provider register --namespace Microsoft.HybridCompute
   az provider register --namespace Microsoft.GuestConfiguration
   az provider register --namespace Microsoft.HybridConnectivity
   ```

   Aguardar `Registered` (2 a 5 minutos) antes de seguir.

6. **Ajustar a MTU** das VMs on-premises para 1400, antes do onboarding. Ver item 1 dos desafios.

7. `05-instalar-arc.ps1` — copia e executa o script de onboarding dentro de cada VM. Saída esperada: `level=info msg="Conectou o computador ao Azure"`.

8. **Instalar o AMA e associar a DCR** — dois comandos, sempre em par:

   ```powershell
   az connectedmachine extension create --machine-name DC01 --name AzureMonitorWindowsAgent ...
   az monitor data-collection rule association create --name dcra-dc01 ...
   ```

   Repetir para FS01 e WEB01.

## Validação

```powershell
az monitor log-analytics query `
    --workspace <WORKSPACE_ID> `
    --analytics-query "Heartbeat | summarize UltimoSinal = max(TimeGenerated) by Computer | order by Computer asc" `
    --output table
```

Resultado obtido:

```
Computer             UltimoSinal
-------------------  ----------------------------
DC01.contoso.local   2026-08-05T01:10:31.1153645Z
FS01.contoso.local   2026-08-05T01:10:48.6569380Z
WEB01.contoso.local  2026-08-05T01:10:02.0473512Z
vm-web-eus2          2026-08-05T01:10:00.1793009Z
```

E os sete performance counters coletando normalmente:

```
Contagem  CounterName
--------  --------------------------
     388  Bytes Total/sec
     195  Available MBytes
     195  % Free Space
     195  % Committed Bytes In Use
     195  Processor Queue Length
     194  % Processor Time
     194  Disk Transfers/sec
```

## Queries úteis

```kql
// Última vez que cada máquina reportou
Heartbeat
| summarize UltimoSinal = max(TimeGenerated) by Computer
| order by Computer asc

// Máquinas que sumiram nos últimos 10 minutos
Heartbeat
| summarize UltimoSinal = max(TimeGenerated) by Computer
| where UltimoSinal < ago(10m)

// CPU média por máquina, última hora
Perf
| where CounterName == "% Processor Time"
| where TimeGenerated > ago(1h)
| summarize CPUMedia = avg(CounterValue) by Computer
| order by CPUMedia desc

// Horário de boot das máquinas
Event
| where Source == "EventLog" and EventID == 6005
| project TimeGenerated, Computer
| order by TimeGenerated desc

// Falhas de logon por máquina
Event
| where EventID == 4625
| summarize Tentativas = count() by Computer, bin(TimeGenerated, 1h)
| order by Tentativas desc
```

## Desafios encontrados

Dois destes envolveram diagnósticos incorretos que custaram tempo. Estão registrados como foram, porque o erro de método é a parte mais útil de lembrar.

### 1. MTU — o problema mais difícil de enxergar

Na FS01, o script de onboarding travava indefinidamente. Sem mensagem de erro, sem timeout — apenas silêncio.

**O que confundia:** todos os testes de rede passavam.

```powershell
Test-NetConnection -ComputerName "gbl.his.arc.azure.com" -Port 443
# TcpTestSucceeded : True
```

DNS resolvia. Handshake TCP completava. Firewall foi desabilitado e não mudou nada.

**Onde a pista apareceu.** Forçando um timeout explícito, o comando finalmente falou:

```powershell
Invoke-WebRequest -Uri "https://aka.ms/azcmagent-windows" `
    -OutFile "$env:TEMP\install.ps1" -TimeoutSec 20
# ERRO: The operation has timed out.
```

Isso separou dois cenários que pareciam iguais: *conexão recusada* (rede bloqueada) versus *conexão aberta que não transfere dados*. O segundo aponta para fragmentação.

**A causa.** Comparando as interfaces das duas máquinas:

```
FS01: NlMtu 1500   <- padrão
DC01: NlMtu 1400   <- ajustado anteriormente
```

A DC01 já tinha MTU 1400, herdada do troubleshooting do Lab 08. Por isso ela funcionou de primeira e a FS01 não.

Com MTU 1500 nessa rede virtual, pacotes maiores precisam ser fragmentados — e essa fragmentação estava sendo descartada. O handshake TCP usa pacotes pequenos e passa. A transferência de dados usa pacotes cheios e morre.

```powershell
Set-NetIPInterface -InterfaceAlias "Ethernet" -AddressFamily IPv4 -NlMtuBytes 1400
```

Download imediato após o ajuste: `Length: 44069`.

> **O que ficou:** na WEB01, a MTU foi ajustada **antes** de qualquer tentativa de onboarding. O processo rodou do início ao fim sem interrupção. Aplicar o aprendizado de forma preventiva economizou a repetição inteira do ciclo de diagnóstico.

### 2. Método de verificação errado

Depois de instalar o AMA na VM Azure, a query de Heartbeat retornava vazio. A verificação parecia confirmar o problema:

```powershell
Get-Service AzureMonitorAgent
# Cannot find any service with service name 'AzureMonitorAgent'
```

**O erro.** Concluí que a instalação havia falhado silenciosamente. Isso levou a um ciclo longo e desnecessário: desinstalar a extensão, limpar resíduos em disco, reinstalar via CLI, tentar pelo portal, investigar espaço em disco.

**O que revelou o engano.** O log da extensão mostrou o processo real em execução:

```
[StartProcess] INFO: Starting the command: AMAExtHealthMonitor.exe ...
[HandleEnableCommand] INFO: Completed Extension Enable
[Main] ErrorCode:0 ERROR: Operation Complete.
```

```powershell
Get-Process | Where-Object { $_.ProcessName -like '*AMA*' }
# AMAExtHealthMonitor  4272  8/4/2026 2:16:48 PM
```

O horário de início — 14:16 — era **anterior a toda a intervenção**. O agente nunca esteve quebrado. A verificação é que estava olhando para o lugar errado.

> **O que ficou:** quando uma ferramenta reporta sucesso e a verificação diz o contrário, **a verificação também é hipótese**. Confirmar que o método de checagem corresponde ao que a ferramenta realmente faz, antes de concluir que a ferramenta falhou.

**Efeito colateral:** a tentativa pelo portal criou uma DCR adicional, sete metric alerts e um action group. Estão documentados e mantidos — não atrapalham e ilustram o comportamento padrão do wizard.

### 3. Resource provider não registrado

```
The client '<appId>' does not have authorization to perform action
'Microsoft.HybridCompute/register/action' over scope '/subscriptions/<SUB_ID>'
Code: AuthorizationFailed httpStatusCode:403
```

A mensagem fala em autorização, então a resposta natural é mexer em RBAC. Foram adicionados dois roles diferentes, em dois escopos diferentes — e o erro continuou idêntico. As permissões estavam corretas.

**A causa real:**

```powershell
az provider show --namespace Microsoft.HybridCompute --query "registrationState" --output tsv
# NotRegistered
```

Sem o provider habilitado, a subscription não aceita registros de máquinas Arc — independente de quantos roles o principal tenha. O Azure devolve 403 porque a ação não está disponível, e a mensagem não diferencia isso de falta de permissão.

> **O que ficou:** 403 em Azure não significa necessariamente RBAC. Antes de sair atribuindo roles, verificar se o resource provider está registrado — é rápido e elimina uma classe inteira de falsos positivos.

### 4. Associação de DCR esquecida

DC01 conectada ao Arc, AMA instalado, processo rodando — e nenhum Heartbeat. A associação nunca foi criada:

```powershell
az monitor data-collection rule association list --resource ".../machines/DC01" --output table
# (vazio)
```

O agente estava saudável, mas sem instrução. Sem erro — apenas silêncio.

> **O que ficou:** instalar a extensão e criar a associação viraram um par indivisível. Nas máquinas seguintes, os dois comandos foram executados juntos, e o Heartbeat apareceu sem intervenção adicional.

### 5. Escopo do Service Principal

O role `Azure Connected Machine Onboarding` não cobre a ação `register/action`, e o escopo de resource group não é suficiente. A configuração que funciona usa `Azure Connected Machine Resource Administrator` com escopo de **subscription**.

Após o onboarding, o Service Principal pode ser removido — ele só é necessário durante o registro.

## Aprendizados

**Diagnóstico**

- Handshake TCP bem-sucedido não garante transferência de dados. Quando `Test-NetConnection` passa mas o download trava, suspeitar de MTU e fragmentação.
- Timeout explícito (`-TimeoutSec`) transforma travamento silencioso em mensagem de erro utilizável.
- Comparar uma máquina que funciona com uma que não funciona, atributo por atributo, isola a variável mais rápido.
- Quando a ferramenta diz "sucesso" e a verificação diz "falhou", ambas são hipóteses.
- `Get-Service` e `Get-Process` respondem perguntas diferentes. Nem todo agente roda como serviço Windows.

**Azure**

- HTTP 403 pode indicar resource provider não registrado, não apenas falta de permissão.
- `--output table` não renderiza arrays. Validar com `--query` em JSON.
- A associação de DCR é um recurso independente. Agente + DCR sem associação não produz dado algum.
- Wizards do portal criam recursos adicionais por padrão. Revisar o que foi criado.

**Operação**

- Aplicar correções conhecidas de forma preventiva economiza ciclos inteiros de diagnóstico.
- Log Analytics não cobra por recurso provisionado, apenas por volume ingerido. Diferente do Lab 08, não há pressa em destruir.
- Máquinas Arc permanecem registradas mesmo desligadas.

## Custos

| Componente | Custo |
|---|---|
| Log Analytics Workspace | 5 GB/mês grátis, retenção de 31 dias inclusa |
| Azure Arc | Gratuito |
| Azure Monitor Agent | Gratuito |
| Data Collection Rules | Gratuito |
| Metric Alerts | Primeiras 10 regras gratuitas |

O volume das quatro máquinas com esta DCR fica confortavelmente dentro do tier gratuito.

## Limpeza

Nada aqui cobra por hora provisionada, então o ambiente pode permanecer ativo entre sessões.

```powershell
# Desconectar uma máquina do Arc
& "$env:PROGRAMFILES\AzureConnectedMachineAgent\azcmagent.exe" disconnect

# Remover o Service Principal
az ad sp delete --id "<appId>"

# Remover todo o ambiente
az group delete --name rg-monitor-prod-eus2 --yes --no-wait
```

## Estrutura de arquivos

```
lab-09-monitoramento/
├── README.md
├── scripts/
│   ├── 01-criar-workspace.ps1
│   ├── 02-criar-dcr.ps1
│   ├── 03-associar-dcr-vm.ps1
│   ├── 04-criar-service-principal.ps1
│   ├── 05-instalar-arc.ps1
│   └── dcr-windows.json
└── screenshots/
```

---

**Próximo:** Grupo 3 — Azure Migrate: Discovery, Assessment e Rehost.
