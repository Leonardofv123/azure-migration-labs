# Lab 10 - Azure Migrate: Discovery e Assessment

Primeiro lab do Grupo 3. Aqui a Contoso do Brasil sai do papel e comeca
a olhar de verdade para o Azure: quanto vai custar, quais VMs estao
prontas para migrar e qual tamanho de maquina faz sentido para cada uma.

---

## Objetivo

Usar o Azure Migrate para inventariar as 4 VMs do ambiente Hyper-V
on-premises, gerar um assessment com sizing e custo estimado, e deixar
o terreno preparado para o rehost (que fica para o Lab 11).

---

## Conceitos

**Azure Migrate** e o servico guarda-chuva da Microsoft para migracao.
Ele nao migra nada sozinho: e um hub que reune discovery, assessment,
planejamento e execucao em um lugar so.

O fluxo padrao tem tres fases:

```
DISCOVERY          ASSESSMENT              REHOST
inventariar    ->  calcular sizing    ->   migrar de fato
o que existe       e custo estimado        (Lab 11)
```

Existem duas formas de fazer o discovery:

```
APPLIANCE                          IMPORT CSV
VM fornecida pela Microsoft        arquivo com os dados das VMs
que varre o Hyper-V sozinha        preenchido manualmente
                                   
+ dados de performance reais       + nao depende de rede
+ mapa de dependencias             + funciona em qualquer ambiente
- exige conectividade estavel      - sem dados de performance
- 12 GB de download                - sem mapa de dependencias
```

Este lab tentou o caminho do Appliance primeiro e terminou pelo import
CSV. O motivo esta documentado na secao de desafios.

---

## Arquitetura

```
ON-PREMISES (Hyper-V)                     AZURE
                                          
contoso-dc01   192.168.10.10              rg-migrate-prod-eus2
contoso-fs01   192.168.10.20                      |
contoso-web01  192.168.10.30                      v
contoso-gw01   192.168.10.1               migrate-contoso-eus2
       |                                  (Brazil South)
       |                                          |
       v                                          v
   inventario CSV  ------------------->    Discovery (4 servidores)
                                                  |
                                                  v
                                          assessment-contoso-iaas
                                          4/4 Ready, USD 440,45/mes
```

---

## Pre-requisitos

- Ambiente Hyper-V do Grupo 1 funcionando (4 VMs)
- Ambiente Azure do Grupo 2 montado
- Azure CLI autenticado na subscription correta
- Conta com papel Owner ou Contributor na subscription
- Security Defaults do tenant desabilitadas (ver desafios)

---

## Passo a passo

### 1. Resource group

```powershell
az group create `
  --name rg-migrate-prod-eus2 `
  --location eastus2
```

### 2. Projeto Azure Migrate

O comando `az migrate project create` nao existe na CLI, nem com a
extensao `migrate` instalada. O projeto precisa ser criado pelo portal.

```
Portal > Azure Migrate > Create project
  Subscription:    Azure subscription 1
  Resource group:  rg-migrate-prod-eus2
  Project name:    migrate-contoso-eus2
  Geography:       Brazil
```

A escolha de Geography define onde fica o endpoint de discovery. Vale
escolher a regiao mais proxima.

### 3. Estrutura de pastas no repositorio

```powershell
New-Item -ItemType Directory -Path "D:\azure-migration-labs\group-3-migration\lab-10-azure-migrate\scripts"
New-Item -ItemType Directory -Path "D:\azure-migration-labs\group-3-migration\lab-10-azure-migrate\screenshots"
```

### 4. Appliance (tentativa)

O portal gera uma project key e disponibiliza o download do Appliance
em VHD (12 GB) ou script PowerShell (500 MB).

```
Portal > migrate-contoso-eus2 > Start discovery
  > Using appliance > For Azure > Yes, with Hyper-V
```

Importacao no Hyper-V:

```powershell
Expand-Archive -Path "D:\AzureMigrateAppliance.zip" `
  -DestinationPath "D:\VMs\appl-contoso" `
  -Force
```

```powershell
$report = Compare-VM -Path "D:\VMs\appl-contoso\AzureMigrateAppliance_v25.25.09.11\Virtual Machines\716DCB86-74A6-4E5B-9BF3-6ED838DDE299.vmcx" `
  -Copy `
  -GenerateNewId `
  -VhdDestinationPath "D:\VMs\appl-contoso\disk2" `
  -VirtualMachinePath "D:\VMs\appl-contoso\vm2"
```

```powershell
$report.Incompatibilities[0].Source | Connect-VMNetworkAdapter -SwitchName "Lab-Internal"
```

```powershell
Import-VM -CompatibilityReport $report
```

Configuracao de recursos:

```powershell
Set-VMMemory -VMName "AzureMigrateAppliance_v25.25.09.11" -StartupBytes 4GB
Set-VMProcessor -VMName "AzureMigrateAppliance_v25.25.09.11" -Count 2
Start-VM -VMName "AzureMigrateAppliance_v25.25.09.11"
```

Rede dentro do Appliance:

```powershell
New-NetIPAddress -InterfaceAlias "Ethernet" `
  -IPAddress 192.168.10.50 `
  -PrefixLength 24 `
  -DefaultGateway 192.168.10.1
```

```powershell
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 192.168.10.10
```

O Configuration Manager fica em `https://192.168.10.50:44368`.

### 5. Discovery via import CSV

Caminho alternativo adotado apos o bloqueio no registro do Appliance.

```
Portal > migrate-contoso-eus2 > Discover > Using import
```

Geracao do inventario:

```powershell
$csv = @"
*Server name,IP addresses,*Cores,*Memory (In MB),*OS name,OS version,OS architecture,Server type,Hypervisor,CPU utilization percentage,Memory utilization percentage,Storage in use (In MB),*Storage allocated (In MB)
contoso-dc01,192.168.10.10,2,2048,Windows Server 2022,10.0.20348,x64,Virtual,Hyper-V,10,20,40960,81920
contoso-fs01,192.168.10.20,2,2048,Windows Server 2022,10.0.20348,x64,Virtual,Hyper-V,5,15,81920,163840
contoso-web01,192.168.10.30,2,2048,Windows Server 2022,10.0.20348,x64,Virtual,Hyper-V,15,25,40960,81920
contoso-gw01,192.168.10.1,2,2048,Windows Server 2022,10.0.20348,x64,Virtual,Hyper-V,5,10,20480,40960
"@

$csv | Out-File -FilePath "$env:USERPROFILE\Downloads\contoso-vms.csv" -Encoding UTF8 -Force
```

Resultado: 4 rows processed, 4 warnings (campos opcionais em branco).

### 6. Assessment

```
Portal > All inventory > selecionar as 4 VMs > Create assessment

  Assessment name:         assessment-contoso-iaas
  Default target location: Brazil South
  Program/offer:           Pay-As-You-Go
  Default savings option:  None
  Sizing criteria:         As on-premises
  Azure hybrid benefit:    habilitado
```

O sizing criteria foi definido como `As on-premises` porque o import CSV
nao carrega historico de performance. Com `Performance-based` o Azure
usaria percentis de utilizacao que nao existem, e o resultado seria
chute com cara de precisao.

---

## Resultado

```
VM              Readiness   SKU               Custo/mes (USD)
contoso-dc01    Ready       Standard_A2_v2    110,11
contoso-fs01    Ready       Standard_A2_v2    110,11
contoso-gw01    Ready       Standard_A2_v2    110,11
contoso-web01   Ready       Standard_A2_v2    110,11
                                              -------
                                              440,45

Compute:   380,93
Storage:     0,00
Security:   59,52

Migration blockers: nenhum
Emissoes estimadas: 4,75 KgCO2e/mes
```

---

## Desafios encontrados

### O comando az migrate project create nao existe

Instalar a extensao `migrate` da CLI resolve parte dos comandos, mas nao
o `project create`. A mensagem de erro (`'project' is misspelled or not
recognized`) sugere erro de digitacao, o que atrapalha o diagnostico. O
subcomando simplesmente nao esta implementado. Projeto criado pelo portal.

### Nome do appliance limitado a 14 caracteres

O portal aceita ate 14 caracteres e valida so depois de digitar. Nomes
descritivos como `appliance-contoso-hyper-v` sao rejeitados sem explicar
o limite antecipadamente.

### Import-VM falha apontando para a pasta

`Import-VM -Path` com `-Copy` precisa do arquivo `.vmcx` diretamente, nao
da pasta `Virtual Machines`. Apontar para a pasta retorna "A operacao
recebeu um parametro que nao era valido", que nao ajuda em nada.

Depois de corrigir o caminho, a importacao ainda falha porque o VHD vem
configurado com um switch chamado `New Virtual Switch` que nao existe no
host. O `Compare-VM` revela isso:

```
Could not find Ethernet switch 'New Virtual Switch'. (MessageId 33012)
```

A correcao precisa acontecer no objeto de report, e o `Import-VM` tem que
usar esse mesmo objeto. Fazer o `Compare-VM`, corrigir e rodar `Import-VM`
em momentos separados invalida o report e retorna um erro que aponta para
o servico de gerenciamento do Hyper-V, mandando investigar o lugar errado.

### O Appliance nasce sem rota para a internet

Com IP estatico na Lab-Internal e gateway apontando para 192.168.10.1, o
Appliance so alcanca a internet se o GW01 estiver ligado, porque e ele que
roda o RRAS com NAT. Com o GW01 desligado, o `Test-NetConnection` trava
sem erro em vez de falhar rapido.

Um detalhe do lab que so aparece aqui: o DHCP roda no FS01. Ligar o FS01
para o Appliance pegar IP funciona, mas gasta RAM que faz falta. IP
estatico e mais barato em memoria e mais previsivel.

### Erro 530035 no login: nao era permissao

O login do Appliance falhava com "You don't have access to this" mesmo
com a conta tendo Owner na subscription. A tentacao e continuar mexendo
em RBAC, e foi o que aconteceu: duas contas receberam Contributor e Owner
sem que nada mudasse.

O detalhe que resolve esta no painel de troubleshooting, nao na mensagem
principal:

```
Error Code:    530035
App name:      Microsoft Azure PowerShell
Device state:  Unregistered
```

`Device state: Unregistered` e a pista. O bloqueio vinha das Security
Defaults do tenant, que exigem dispositivo registrado no Entra ID. Nao
aparece em Conditional Access porque o tenant nao tem licenca P1 para
isso, o que reforca a impressao errada de que nao ha politica nenhuma.

```
Portal > Microsoft Entra ID > Properties > Manage security defaults
  > Disabled > My organization is using Conditional Access
```

Login funcionou na tentativa seguinte.

### Registro do Appliance: TCP passa, HTTPS passa, registro nao

Depois do login resolvido, o registro falhava com tres erros diferentes
que se alternavam:

```
connected host has failed to respond
Error 12030  WINHTTP_CALLBACK_STATUS_REQUEST_ERROR  connection terminated abnormally
Error 12002  WINHTTP_CALLBACK_STATUS_REQUEST_ERROR  operation timed out
```

Hipoteses testadas e eliminadas:

| Hipotese                | Teste                                   | Resultado |
|-------------------------|-----------------------------------------|-----------|
| Autenticacao            | login no Configuration Manager          | funciona  |
| RBAC                    | Owner na subscription                   | nao muda  |
| Security Defaults       | desabilitadas                           | nao muda  |
| MTU                     | 1400 e depois 1350                      | nao muda  |
| NAT duplo               | segunda NIC no switch Internet, sem GW01| nao muda  |
| TLS                     | SchUseStrongCrypto + TLS 1.2 forcado    | nao muda  |
| Latencia do endpoint    | projeto recriado em Brazil South        | nao muda  |
| Conectividade HTTPS     | Invoke-WebRequest no endpoint           | HTTP 404  |

O 404 e o dado mais util da tabela. Ele prova que TCP, TLS e HTTP
completo funcionam ate o servidor responder. O que falha e especificamente
o POST de registro, com payload maior.

Esse padrao ja tinha aparecido no Lab 07, no `estimateAccess` do Entra
Connect: teste generico passa, POST com payload maior morre. La a solucao
foi trocar a rede para dados moveis. Aqui o mesmo sintoma reapareceu, e o
registro do Appliance nao tem o mesmo escape.

Conclusao: limitacao de rede residencial em conexoes HTTPS longas com
payload grande, ja documentada duas vezes neste repositorio. Discovery
seguiu pelo import CSV.

### Recriar o projeto deixa recursos orfaos

Deletar o projeto Azure Migrate pelo portal nao deleta os recursos que ele
criou junto. Sobraram dez, incluindo Key Vault, MasterSite, HyperVSite e
sites de descoberta de MySQL, PostgreSQL, MongoDB e Storage.

Como esses recursos ficam presos na regiao antiga, o projeto novo em outra
regiao nao consegue criar recursos com os mesmos nomes:

```
The resource 'migrate-contos0722mastersite' already exists in location
'centralus' in resource group 'rg-migrate-prod-eus2'. A resource with the
same name cannot be created in location 'brazilsouth'.
```

O erro so aparece na hora de gerar a project key, e menciona um recurso
por vez. Vale listar tudo antes:

```powershell
az resource list --resource-group rg-migrate-prod-eus2 --query "[].{nome:name, tipo:type}" --output table
```

Depois deletar um por um passando o `--resource-type` de cada.

### CSV rejeita o campo OS version com texto

O template do Azure Migrate aceita "Windows Server 2022" em `OS name`, mas
`OS version` so aceita numeros e ponto:

```
The OS version can contain only numbers (0-9) or a period (.). Example: '7.6.8'
```

O valor correto para Windows Server 2022 e `10.0.20348`. O erro so aparece
depois do import falhar e do download do CSV de erros, entao vale conferir
antes de subir.

---

## Aprendizados

**Uma mensagem de erro principal pode apontar para o lugar errado.** O
"You don't have access to this" custou duas atribuicoes de role inuteis. A
resposta estava em `Device state: Unregistered`, no painel de detalhes.

**Teste generico de conectividade nao cobre POST com payload grande.** O
`Test-NetConnection` retorna sucesso, o `Invoke-WebRequest` retorna 404 (que
tambem e sucesso, do ponto de vista de rede), e mesmo assim o registro
falha. Segunda vez que esse padrao aparece no repositorio.

**Deletar recurso no portal nem sempre deleta o que ele criou.** Os
recursos orfaos so aparecem quando bloqueiam a proxima acao, em outro
contexto, com uma mensagem que nao menciona a delecao anterior.

**Sizing criteria precisa combinar com a origem dos dados.** Escolher
`Performance-based` com dados vindos de CSV produz numero bonito e sem
fundamento. `As on-premises` e honesto sobre o que se sabe.

**Ter um caminho alternativo vale mais que insistir no principal.** O
Appliance da mais dado, mas o import CSV entrega assessment valido. O
resultado do lab foi preservado.

---

## Screenshots

| Arquivo | Descricao |
|---------|-----------|
| appliance-importada-hyperv.png | VM do Appliance importada no Hyper-V |
| appliance-conectividade-internet.png | Teste de conectividade a partir do Appliance |
| appliance-configuration-manager.png | Configuration Manager acessivel |
| appliance-login-sucesso.png | Login apos desabilitar Security Defaults |
| nova-project-key-brazilsouth.png | Project key com endpoint Brazil South |
| import-csv-concluido.png | Import CSV com 4 rows processed |
| inventory-4-vms-descobertas.png | As 4 VMs no inventario do projeto |
| assessment-criado.png | Notificacao de assessment em computacao |
| assessment-ready.png | Assessment com status Ready |
| assessment-resultado-overview.png | Readiness, custo e emissoes |
| assessment-servers-lift-shift.png | Mapeamento para Azure VM |
| assessment-detalhamento-vms.png | SKU e custo por VM |

---

## Custos

```
Azure Migrate (projeto e assessment)   gratuito
Appliance                              gratuito (roda no Hyper-V local)
Recursos criados pelo projeto          gratuitos em repouso
```

O valor de USD 440,45 do assessment e estimativa do que custaria rodar as
4 VMs no Azure. Nada disso foi provisionado neste lab.

Atencao para o Lab 11: a replicacao do rehost cria storage e recursos que
cobram por hora. Vale deletar assim que a validacao terminar.

---

## Proximo lab

Lab 11 - Rehost: replicacao e migracao da WEB01 para o Azure.
