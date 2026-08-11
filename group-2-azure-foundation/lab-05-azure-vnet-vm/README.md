# Lab 05 - Rede e VM no Azure (VNet, NSG, Terraform e Bicep)

## Objetivo

Provisionar a primeira infraestrutura real da Contoso na Azure: uma rede segmentada em tres camadas (web, aplicacao e dados) e uma VM web rodando na camada web. O lab foi feito em duas passadas. Primeiro tudo manual via PowerShell e Azure CLI, para entender o que cada recurso e. Depois a mesma rede declarada em Terraform e em Bicep, para comparar as duas abordagens de Infrastructure as Code lado a lado. Cenario: ate aqui a Contoso vivia inteira no Hyper-V, e este e o lab que coloca a empresa na nuvem.

## Estrutura criada

```
                          Internet
                              |
                              v
                +-------------------------+
                |   NSG: nsg-web          |
                |   libera so 80 e 443    |
                +-----------+-------------+
                            |
                            v
     +-------------------------------------------+
     |  snet-web   10.10.1.0/24                  |
     |                                           |
     |  vm-web-prod-eus2                         |
     |  Windows Server 2022 / Standard_D2s_v3    |
     +-------------------------------------------+
     |  snet-app   10.10.2.0/24                  |
     |  reservada para a camada de aplicacao     |
     +-------------------------------------------+
     |  snet-data  10.10.3.0/24                  |
     |  reservada para banco e file server       |
     +-------------------------------------------+

     VNet: vnet-contoso-eus2 (10.10.0.0/16)
     Resource Group: rg-network-prod-eus2
     Regiao: East US 2
```

A rede foi planejada originalmente em `brazilsouth`, mas precisou ser recriada em `eastus2` depois de uma sequencia de erros de SKU. A historia completa esta em [Desafios encontrados](#desafios-encontrados).

## Pre-requisitos

- Conta Azure ativa com subscription valida.
- Azure PowerShell (modulo `Az`) e Azure CLI instalados.
- Terraform e Bicep CLI, para as secoes de Infrastructure as Code.
- Labs 01 a 04 concluidos (ambiente on-premises servindo de referencia).

## Conceitos

**VNet (Virtual Network)** e a rede privada dentro da Azure, o equivalente em nuvem ao vSwitch usado no Hyper-V nos labs anteriores.

**Sub-rede** e uma divisao logica dentro da VNet, cada uma com sua faixa de IP. Separar em web, app e dados nao e organizacao estetica: permite aplicar regras de seguranca diferentes por camada. Se a camada web for comprometida, ela nao tem acesso direto e irrestrito a camada de dados.

**NSG (Network Security Group)** e o firewall da Azure. Por padrao tudo que vem de fora e bloqueado, e o NSG so libera o que for explicitamente permitido.

**SKU de VM** define quantos vCPUs e quanta RAM a maquina tem. A familia B (Burstable) entra no tier gratuito, e a familia D (uso geral) e paga desde a primeira hora. Essa diferenca acabou sendo central no troubleshooting deste lab.

**Cota de vCPUs** e o limite de quantos vCPUs de cada familia a subscription pode usar. O detalhe que pega desprevenido: contas novas frequentemente vem com cota zerada para as familias burstable, como medida antifraude contra mineracao de criptomoeda. A regiao pode ter capacidade fisica de sobra e mesmo assim a criacao falha.

**Terraform e o arquivo de state.** O Terraform decide o que criar comparando o codigo `.tf` (o que voce quer) com o `.tfstate` (o que ele acha que ja existe). Na primeira execucao o state esta vazio, entao tudo aparece como "a ser criado", mesmo que recursos parecidos ja existam na Azure, criados por fora.

**Bicep** e a linguagem de IaC nativa da Microsoft, so para Azure. Nao tem motor proprio: compila para ARM Template (JSON) e quem executa e o Azure Resource Manager. Por isso nao existe arquivo de state.

## Como rodar

Os scripts rodam no host, nao dentro de VM.

1. `01-criar-rede.ps1` cria o Resource Group, a VNet com as tres sub-redes e o NSG com a regra `Allow-Web`. O script pede confirmacao da subscription antes de criar qualquer coisa.

2. `02-criar-vm.ps1` cria a `vm-web-prod-eus2` na `snet-web`. Dois parametros merecem atencao, ambos vindos de erro: `--computer-name` separado de `--name` (limite de 15 caracteres do NetBIOS) e ausencia de `--os-disk-size-gb` (a imagem exige no minimo 127 GB).

3. `03-auto-shutdown.ps1` agenda o desligamento automatico as 22h. Critico nesta VM, que esta fora do tier gratuito.

4. `terraform/` roda com `terraform init`, `plan` e `apply`. Aplicado num Resource Group isolado (`rg-network-prod-eus2-tf`) para nao conflitar com o ambiente manual. Destruido com `terraform destroy` ao final da comparacao.

5. `bicep/` roda com `az bicep build --file main.bicep`. Validado localmente, sem deployment, para comparar sintaxe sem duplicar recursos e custo.

## Validacao

```powershell
# Contexto correto antes de criar qualquer coisa
Get-AzContext

# Rede criada
Get-AzVirtualNetwork -Name 'vnet-contoso-eus2' -ResourceGroupName 'rg-network-prod-eus2'

# VM em execucao
az vm show --resource-group rg-network-prod-eus2 --name vm-web-prod-eus2 `
    --show-details --query "{Nome:name, Estado:powerState, IP:publicIps}" --output table
```

O portal deve mostrar o Resource Group com a VNet (tres sub-redes), o NSG com a regra `Allow-Web` e a VM com status **VM running**.

## Terraform vs Bicep

| | Terraform | Bicep |
|---|---|---|
| Escopo | Multi-cloud | So Azure |
| Motor | Proprio | Azure Resource Manager |
| Estado | Arquivo `.tfstate` | Nenhum (o Azure sabe) |
| Strings | Aspas duplas | Aspas simples |
| Compilacao | Nao compila | Compila para ARM JSON |

A diferenca mais pratica e o state. O Terraform precisa guardar e proteger esse arquivo, em equipe num backend remoto. O Bicep nao tem essa preocupacao porque consulta o proprio Azure. Em compensacao, o Terraform enxerga outros provedores alem da Azure.

## Desafios encontrados

A criacao da VM, que deveria ser um comando unico, virou uma sequencia de erros encadeados. Vale ler na ordem, porque um levou ao outro.

### 1. SkuNotAvailable em brazilsouth

```
Standard_B2ats_v2 is currently not available in location 'brazilsouth'
```

A leitura obvia e falta de capacidade fisica na regiao. Tentativa com um segundo SKU do mesmo tier gratuito deu o mesmo erro. Hipotese: regiao sem capacidade. Acao: recriar tudo em `eastus2`.

### 2. SkuNotAvailable de novo, agora em eastus2

O mesmo erro, agora numa das maiores regioes do mundo, para tres SKUs diferentes da familia B. A chance de estar sem capacidade para tres SKUs simultaneamente e praticamente nula, entao a hipotese de capacidade regional caiu.

**Teste de controle:** criar uma VM de familia diferente, na mesma regiao.

```
Standard_D2s_v3 (nao-burstable)  ->  criou de primeira
```

Isso isolou a variavel. Nao era regiao, nao era capacidade: era a familia B especificamente.

**Causa real:** cota zerada para toda a familia B na subscription nova. Medida antifraude padrao da Microsoft. A mensagem de erro fala "not available", sugerindo indisponibilidade fisica, mas a causa e administrativa. Sao coisas diferentes que produzem o mesmo texto.

**Solucao:** seguir com `Standard_D2s_v3`, consumindo o credito de US$ 200 em vez das 750h mensais do tier gratuito.

> **O que ficou:** quando um erro se repete em condicoes que deveriam ser diferentes, a variavel que voce esta mudando nao e a certa. Trocar de regiao tres vezes nao resolveria. O teste que resolveu foi mudar a familia da VM, mantendo tudo o resto igual.

### 3. Tamanho de disco menor que a imagem

```
The specified disk size 64 GB is smaller than the size of the corresponding
disk in the VM image: 127 GB
```

O parametro `--os-disk-size-gb 64` fazia sentido para o SKU original, onde o disco de 64 GiB era exigencia do tier gratuito. Ao trocar para `Standard_D2s_v3` essa restricao sumiu, e a imagem do Windows Server 2022 exige no minimo 127 GB.

> **O que ficou:** parametros herdados de uma configuracao anterior viram erro quando o contexto muda. Ao trocar de SKU, revisar o comando inteiro, nao so o campo `--size`.

### 4. Nome de computador acima do limite

```
Windows computer name cannot be more than 15 characters long
```

Por padrao o `az vm create` usa o valor de `--name` tambem como nome de computador dentro do Windows. E `vm-web-prod-eus2` tem 16 caracteres, um a mais que o limite do NetBIOS, que e de 1987 e continua valendo.

```
--name           vm-web-prod-eus2   (recurso Azure, sem limite)
--computer-name  vmwebprodeus2      (Windows, 13 caracteres)
```

> **O que ficou:** o nome do recurso na Azure e o hostname dentro do sistema operacional sao independentes. Convencoes com hifen e sufixo de regiao estouram o limite do NetBIOS com facilidade.

### 5. Recursos orfaos depois de deletar a VM de teste

A VM criada no teste de controle foi deletada com `az vm delete`. Mas o comando remove apenas a VM. NIC, IP publico e disco ficam soltos, cobrando.

```powershell
az resource list --resource-group <rg> --output table
```

Cada um precisou ser deletado individualmente.

> **O que ficou:** deletar uma VM na Azure nao cascateia. Depois de qualquer teste descartavel, listar os recursos do RG e conferir o que sobrou, senao o custo continua correndo em silencio.

### 6. Erro de sintaxe no Bicep

Varias linhas de `BCP103` e `BCP007`. O arquivo foi escrito com aspas duplas, e o Bicep exige aspas simples, diferente do Terraform (HCL) e do JSON, que aceitam duplas.

### 7. Pasta criada dentro do System32

O terminal estava aberto em `C:\Windows\System32` no momento de criar a pasta do projeto. A estrutura inteira, incluindo o `.terraform` ja inicializado, foi parar la dentro.

Resolvido com `Move-Item`, mas foi necessario rodar `terraform init` novamente, porque o state esta amarrado ao caminho.

## Aprendizados

**Azure**

- `SkuNotAvailable` pode significar cota zerada, nao falta de capacidade fisica. A mensagem nao distingue as duas coisas.
- Subscriptions novas vem com cota zero para familias burstable. Verificar antes de montar um lab inteiro em cima do tier gratuito.
- Deletar VM nao deleta NIC, IP publico nem disco.
- Nome de recurso Azure e hostname Windows sao independentes.

**Infrastructure as Code**

- O Terraform so enxerga o que esta no state dele. Recursos criados por fora sao invisiveis para o `plan`.
- Bicep usa aspas simples, Terraform e JSON usam duplas.
- Aplicar Terraform num Resource Group isolado evita conflito com o ambiente em uso.

**Diagnostico**

- Quando o mesmo erro se repete depois de mudar uma variavel, a variavel mudada nao e a causa.
- Um teste de controle bem escolhido vale mais que tres tentativas repetindo o mesmo padrao.

## Custos

| Recurso | Custo |
|---|---|
| VNet, sub-redes, NSG | Gratuitos |
| IP publico Standard | Cobrado por hora |
| `vm-web-prod-eus2` | `Standard_D2s_v3`, fora do tier gratuito |
| Disco Premium LRS 127 GB | Cobrado por GB provisionado |

O auto-shutdown as 22h e o que segura o custo desta VM.

## Estrutura de arquivos

```
lab-05-azure-vnet-vm/
├── README.md
├── scripts/
│   ├── 01-criar-rede.ps1
│   ├── 02-criar-vm.ps1
│   └── 03-auto-shutdown.ps1
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── bicep/
│   └── main.bicep
└── screenshots/
```

No `.gitignore`: `.tfstate`, pasta `.terraform/` e `main.json` (artefato de build do Bicep).

**Proximo:** [Lab 06 - Storage, Backup e File Sync](../lab-06-storage-backup/), primeiro lab que depende diretamente da rede e da VM criadas aqui.
