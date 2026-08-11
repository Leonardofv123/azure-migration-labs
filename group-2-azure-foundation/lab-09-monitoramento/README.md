# Lab 09 - Monitoramento Hibrido (Azure Monitor, Log Analytics e Azure Arc)

## Objetivo

Centralizar o monitoramento de toda a infraestrutura da Contoso, servidores on-premises e recursos Azure, num unico Log Analytics Workspace, usando Azure Arc para estender o plano de controle do Azure ate as maquinas Hyper-V. Ao final, as quatro maquinas do ambiente reportam metricas de performance e event logs para o mesmo workspace, consultaveis pelas mesmas queries KQL, independente de onde estejam rodando.

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
    |  + AMA (extensao nativa)         |         |  - Security (4624, 4625,  |
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

## Pre-requisitos

- Labs 01 a 04 concluidos (DC01, FS01 e WEB01 de pe).
- Lab 05 concluido (VM `vm-web-prod-eus2`).
- Resource providers do Arc registrados na subscription (o script 04 faz isso).

## Conceitos

**Azure Arc** estende o plano de controle do Azure para maquinas que nao estao nele: servidores on-premises, outras nuvens, qualquer lugar. Instala um agente (`azcmagent`) que registra a maquina como um recurso do Azure, com Resource ID proprio. A partir dai ela aceita as mesmas ferramentas de uma VM nativa: extensoes, Azure Policy, RBAC.

**Azure Monitor Agent (AMA)** e quem coleta os dados dentro da maquina. Detalhe importante: nesta versao ele roda como processo monitorado (`AMAExtHealthMonitor.exe`), nao como servico Windows tradicional. Procurar por `Get-Service AzureMonitorAgent` nao encontra nada, e isso gerou um diagnostico errado neste lab.

**Data Collection Rule (DCR)** define o que coletar e para onde mandar. E um recurso independente, reutilizavel entre varias maquinas.

**Como as pecas se encaixam.** Tres componentes precisam existir e estar ligados entre si:

```
   AGENTE (AMA)              DCR                    WORKSPACE
"quem coleta"          "o que coletar"          "onde guardar"
       |                      |                        |
       +----------------------+------------------------+
                              |
                    ASSOCIACAO (DCRA)
              "esta maquina usa esta regra"
```

A associacao e um recurso separado e explicito. Instalar o agente e criar a DCR nao e suficiente: sem a associacao, o agente roda saudavel mas sem instrucao nenhuma, e nada chega ao workspace. A ausencia de qualquer uma das tres pecas produz silencio, sem erro e sem aviso.

## Como rodar

Todos os comandos rodam no host, via Azure CLI ou `Invoke-Command`.

1. `01-criar-workspace.ps1` cria `rg-monitor-prod-eus2` e o workspace `law-contoso-eus2`. Ao final imprime o Workspace ID, que e usado em todas as queries.

2. `02-criar-dcr.ps1` cria a DCR a partir de `dcr-windows.json`. O script substitui o placeholder `<SUB_ID>` pelo ID da subscription atual automaticamente.

3. `03-associar-dcr-vm.ps1` instala o AMA na VM Azure e associa a DCR, nos dois passos que precisam andar juntos.

4. `04-criar-service-principal.ps1` registra os resource providers do Arc, espera o registro completar, e cria o Service Principal com o role e o escopo corretos.

5. `05-instalar-arc.ps1` conecta uma VM on-premises ao Arc. Ajusta a MTU para 1400 antes do download, de proposito. Rodar uma VM por vez:

   ```powershell
   .\05-instalar-arc.ps1 -VM contoso-dc01 -Dominio
   .\05-instalar-arc.ps1 -VM contoso-fs01 -Dominio
   .\05-instalar-arc.ps1 -VM contoso-web01 -Dominio
   ```

6. `06-instalar-ama-arc.ps1` instala o AMA e associa a DCR numa maquina Arc:

   ```powershell
   .\06-instalar-ama-arc.ps1 -Maquina DC01
   .\06-instalar-ama-arc.ps1 -Maquina FS01
   .\06-instalar-ama-arc.ps1 -Maquina WEB01
   ```

7. `07-validar-heartbeat.ps1` confirma que todas as maquinas estao reportando.

## Validacao

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

## Queries uteis

```kql
// Ultima vez que cada maquina reportou
Heartbeat
| summarize UltimoSinal = max(TimeGenerated) by Computer
| order by Computer asc

// Maquinas que sumiram nos ultimos 10 minutos
Heartbeat
| summarize UltimoSinal = max(TimeGenerated) by Computer
| where UltimoSinal < ago(10m)

// CPU media por maquina, ultima hora
Perf
| where CounterName == "% Processor Time"
| where TimeGenerated > ago(1h)
| summarize CPUMedia = avg(CounterValue) by Computer
| order by CPUMedia desc

// Horario de boot das maquinas
Event
| where Source == "EventLog" and EventID == 6005
| project TimeGenerated, Computer
| order by TimeGenerated desc

// Falhas de logon por maquina
Event
| where EventID == 4625
| summarize Tentativas = count() by Computer, bin(TimeGenerated, 1h)
| order by Tentativas desc
```

## Desafios encontrados

Dois destes envolveram diagnosticos incorretos que custaram tempo. Estao registrados como foram, porque o erro de metodo e a parte mais util de lembrar.

### 1. MTU, o problema mais dificil de enxergar

Na FS01, o script de onboarding travava indefinidamente. Sem mensagem de erro, sem timeout, apenas silencio.

**O que confundia:** todos os testes de rede passavam.

```powershell
Test-NetConnection -ComputerName "gbl.his.arc.azure.com" -Port 443
# TcpTestSucceeded : True
```

DNS resolvia. Handshake TCP completava. Firewall foi desabilitado e nao mudou nada.

**Onde a pista apareceu.** Forcando um timeout explicito, o comando finalmente falou:

```powershell
Invoke-WebRequest -Uri "https://aka.ms/azcmagent-windows" `
    -OutFile "$env:TEMP\install.ps1" -TimeoutSec 20
# ERRO: The operation has timed out.
```

Isso separou dois cenarios que pareciam iguais: conexao recusada (rede bloqueada) e conexao aberta que nao transfere dados. O segundo aponta para fragmentacao.

**A causa.** Comparando as interfaces das duas maquinas:

```
FS01: NlMtu 1500   <- padrao
DC01: NlMtu 1400   <- ajustado anteriormente
```

A DC01 ja tinha MTU 1400, herdada do troubleshooting do Lab 08. Por isso ela funcionou de primeira e a FS01 nao.

Com MTU 1500 nessa rede virtual, pacotes maiores precisam ser fragmentados, e essa fragmentacao estava sendo descartada. O handshake TCP usa pacotes pequenos e passa. A transferencia de dados usa pacotes cheios e morre.

```powershell
Set-NetIPInterface -InterfaceAlias "Ethernet" -AddressFamily IPv4 -NlMtuBytes 1400
```

Download imediato apos o ajuste: `Length: 44069`.

> **O que ficou:** na WEB01, a MTU foi ajustada antes de qualquer tentativa de onboarding. O processo rodou do inicio ao fim sem interrupcao. Aplicar o aprendizado de forma preventiva economizou a repeticao inteira do ciclo de diagnostico. Por isso o script `05-instalar-arc.ps1` ja faz o ajuste automaticamente.

### 2. Metodo de verificacao errado

Depois de instalar o AMA na VM Azure, a query de Heartbeat retornava vazio. A verificacao parecia confirmar o problema:

```powershell
Get-Service AzureMonitorAgent
# Cannot find any service with service name 'AzureMonitorAgent'
```

**O erro.** Conclui que a instalacao havia falhado silenciosamente. Isso levou a um ciclo longo e desnecessario: desinstalar a extensao, limpar residuos em disco, reinstalar via CLI, tentar pelo portal, investigar espaco em disco.

**O que revelou o engano.** O log da extensao mostrou o processo real em execucao:

```
[StartProcess] INFO: Starting the command: AMAExtHealthMonitor.exe ...
[HandleEnableCommand] INFO: Completed Extension Enable
[Main] ErrorCode:0 ERROR: Operation Complete.
```

```powershell
Get-Process | Where-Object { $_.ProcessName -like '*AMA*' }
# AMAExtHealthMonitor  4272  8/4/2026 2:16:48 PM
```

O horario de inicio, 14:16, era anterior a toda a intervencao. O agente nunca esteve quebrado. A verificacao e que estava olhando para o lugar errado.

> **O que ficou:** quando uma ferramenta reporta sucesso e a verificacao diz o contrario, a verificacao tambem e hipotese. Confirmar que o metodo de checagem corresponde ao que a ferramenta realmente faz, antes de concluir que a ferramenta falhou.

**Efeito colateral:** a tentativa pelo portal criou uma DCR adicional, sete metric alerts e um action group. Estao documentados e mantidos, porque nao atrapalham e ilustram o comportamento padrao do wizard.

### 3. Resource provider nao registrado

```
The client '<appId>' does not have authorization to perform action
'Microsoft.HybridCompute/register/action' over scope '/subscriptions/<SUB_ID>'
Code: AuthorizationFailed httpStatusCode:403
```

A mensagem fala em autorizacao, entao a resposta natural e mexer em RBAC. Foram adicionados dois roles diferentes, em dois escopos diferentes, e o erro continuou identico. As permissoes estavam corretas.

**A causa real:**

```powershell
az provider show --namespace Microsoft.HybridCompute --query "registrationState" --output tsv
# NotRegistered
```

Sem o provider habilitado, a subscription nao aceita registros de maquinas Arc, independente de quantos roles o principal tenha. O Azure devolve 403 porque a acao nao esta disponivel, e a mensagem nao diferencia isso de falta de permissao.

> **O que ficou:** 403 em Azure nao significa necessariamente RBAC. Antes de sair atribuindo roles, verificar se o resource provider esta registrado. E rapido e elimina uma classe inteira de falsos positivos.

### 4. Associacao de DCR esquecida

DC01 conectada ao Arc, AMA instalado, processo rodando, e nenhum Heartbeat. A associacao nunca foi criada:

```powershell
az monitor data-collection rule association list --resource ".../machines/DC01" --output table
# (vazio)
```

O agente estava saudavel, mas sem instrucao. Sem erro, apenas silencio.

> **O que ficou:** instalar a extensao e criar a associacao viraram um par indivisivel. Nas maquinas seguintes, os dois comandos foram executados juntos, e o Heartbeat apareceu sem intervencao adicional. Por isso os scripts 03 e 06 fazem os dois passos.

### 5. Escopo do Service Principal

O role `Azure Connected Machine Onboarding` nao cobre a acao `register/action`, e o escopo de resource group nao e suficiente. A configuracao que funciona usa `Azure Connected Machine Resource Administrator` com escopo de subscription.

Apos o onboarding, o Service Principal pode ser removido, porque so e necessario durante o registro.

## Aprendizados

**Diagnostico**

- Handshake TCP bem-sucedido nao garante transferencia de dados. Quando `Test-NetConnection` passa mas o download trava, suspeitar de MTU e fragmentacao.
- Timeout explicito (`-TimeoutSec`) transforma travamento silencioso em mensagem de erro utilizavel.
- Comparar uma maquina que funciona com uma que nao funciona, atributo por atributo, isola a variavel mais rapido.
- Quando a ferramenta diz "sucesso" e a verificacao diz "falhou", ambas sao hipoteses.
- `Get-Service` e `Get-Process` respondem perguntas diferentes. Nem todo agente roda como servico Windows.

**Azure**

- HTTP 403 pode indicar resource provider nao registrado, nao apenas falta de permissao.
- `--output table` nao renderiza arrays. Validar com `--query` em JSON.
- A associacao de DCR e um recurso independente. Agente e DCR sem associacao nao produzem dado algum.
- Wizards do portal criam recursos adicionais por padrao. Revisar o que foi criado.

**Operacao**

- Aplicar correcoes conhecidas de forma preventiva economiza ciclos inteiros de diagnostico.
- Log Analytics nao cobra por recurso provisionado, apenas por volume ingerido. Diferente do Lab 08, nao ha pressa em destruir.
- Maquinas Arc permanecem registradas mesmo desligadas.

## Custos

| Componente | Custo |
|---|---|
| Log Analytics Workspace | 5 GB por mes gratis, retencao de 31 dias inclusa |
| Azure Arc | Gratuito |
| Azure Monitor Agent | Gratuito |
| Data Collection Rules | Gratuito |
| Metric Alerts | Primeiras 10 regras gratuitas |

O volume das quatro maquinas com esta DCR fica confortavelmente dentro do tier gratuito.

## Limpeza

Nada aqui cobra por hora provisionada, entao o ambiente pode permanecer ativo entre sessoes.

```powershell
# Desconectar uma maquina do Arc
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
│   ├── 06-instalar-ama-arc.ps1
│   ├── 07-validar-heartbeat.ps1
│   └── dcr-windows.json
└── screenshots/
```

**Proximo:** Grupo 3, Azure Migrate: Discovery, Assessment e Rehost.
