# Lab 05 - Rede e VM no Azure (VNet, NSG, Terraform e Bicep)

## Objetivo

Provisionar a primeira infraestrutura real da Contoso na Azure: uma rede segmentada em três camadas (web, aplicação e dados) e uma VM web rodando na camada web. O lab foi feito em duas passadas — primeiro tudo manual via PowerShell e Azure CLI, para entender o que cada recurso é; depois a mesma rede declarada em Terraform e em Bicep, para comparar as duas abordagens de Infrastructure as Code lado a lado. Cenário: até aqui a Contoso vivia inteira no Hyper-V; este é o lab que coloca a empresa na nuvem.

## Estrutura criada

```
                          Internet
                              |
                              v
                +-------------------------+
                |   NSG: nsg-web          |
                |   libera só 80 e 443    |
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
     |  reservada para a camada de aplicação     |
     +-------------------------------------------+
     |  snet-data  10.10.3.0/24                  |
     |  reservada para banco e file server       |
     +-------------------------------------------+

     VNet: vnet-contoso-eus2 (10.10.0.0/16)
     Resource Group: rg-network-prod-eus2
     Região: East US 2
```

A rede foi planejada originalmente em `brazilsouth`, mas precisou ser recriada em `eastus2` depois de uma sequência de erros de SKU. A história completa está em [Desafios encontrados](#desafios-encontrados).

## Pré-requisitos

- Conta Azure ativa com subscription válida.
- Azure PowerShell (módulo `Az`) e Azure CLI instalados.
- Terraform e Bicep CLI, para as seções de Infrastructure as Code.
- Labs 01-04 concluídos (ambiente on-premises servindo de referência).

## Conceitos

**VNet (Virtual Network)** é a rede privada dentro da Azure — o equivalente em nuvem ao vSwitch usado no Hyper-V nos labs anteriores.

**Sub-rede** é uma divisão lógica dentro da VNet, cada uma com sua faixa de IP. Separar em web/app/dados não é organização estética: permite aplicar regras de segurança diferentes por camada. Se a camada web for comprometida, ela não tem acesso direto e irrestrito à camada de dados.

**NSG (Network Security Group)** é o firewall da Azure. Por padrão tudo que vem de fora é bloqueado — o NSG só libera o que for explicitamente permitido.

**SKU de VM** define quantos vCPUs e quanta RAM a máquina tem. A família B (Burstable) entra no tier gratuito; a família D (uso geral) é paga desde a primeira hora. Essa diferença acabou sendo central no troubleshooting deste lab.

**Cota de vCPUs** é o limite de quantos vCPUs de cada família a subscription pode usar. O detalhe que pega desprevenido: contas novas frequentemente vêm com cota **zerada** para as famílias burstable, como medida antifraude contra mineração de criptomoeda. A região pode ter capacidade física de sobra e mesmo assim a criação falha.

**Terraform e o arquivo de state.** O Terraform decide o que criar comparando o código `.tf` (o que você quer) com o `.tfstate` (o que ele acha que já existe). Na primeira execução o state está vazio, então tudo aparece como "a ser criado" — mesmo que recursos parecidos já existam na Azure, criados por fora.

**Bicep** é a linguagem de IaC nativa da Microsoft, só para Azure. Não tem motor próprio: compila para ARM Template (JSON) e quem executa é o Azure Resource Manager. Por isso não existe arquivo de state.

## Como rodar

Os scripts rodam **no host**, não dentro de VM.

1. `01-criar-rede.ps1` — cria o Resource Group, a VNet com as três sub-redes e o NSG com a regra `Allow-Web`. Rodar `Get-AzContext` antes, para confirmar que a subscription selecionada é a certa.

2. `02-criar-vm.ps1` — cria a `vm-web-prod-eus2` na `snet-web`. Dois parâmetros merecem atenção, ambos vindos de erro: `--computer-name` separado de `--name` (limite de 15 caracteres do NetBIOS) e ausência de `--os-disk-size-gb` (a imagem exige no mínimo 127 GB).

3. `03-auto-shutdown.ps1` — agenda o desligamento automático às 22h. Crítico nesta VM, que está fora do tier gratuito.

4. `terraform/` — `terraform init`, `plan` e `apply`. Aplicado num Resource Group isolado (`rg-network-prod-eus2-tf`) para não conflitar com o ambiente manual. Destruído com `terraform destroy` ao final da comparação.

5. `bicep/` — `az bicep build --file main.bicep`. Validado localmente, sem deployment, para comparar sintaxe sem duplicar recursos e custo.

## Validação

```powershell
# Contexto correto antes de criar qualquer coisa
Get-AzContext

# Rede criada
Get-AzVirtualNetwork -Name 'vnet-contoso-eus2' -ResourceGroupName 'rg-network-prod-eus2'

# VM em execução
az vm show --resource-group rg-network-prod-eus2 --name vm-web-prod-eus2 `
    --show-details --query "{Nome:name, Estado:powerState, IP:publicIps}" --output table
```

O portal deve mostrar o Resource Group com a VNet (três sub-redes), o NSG com a regra `Allow-Web` e a VM com status **VM running**.

## Terraform vs Bicep

| | Terraform | Bicep |
|---|---|---|
| Escopo | Multi-cloud | Só Azure |
| Motor | Próprio | Azure Resource Manager |
| Estado | Arquivo `.tfstate` | Nenhum (o Azure sabe) |
| Strings | Aspas duplas | Aspas simples |
| Compilação | Não compila | Compila para ARM JSON |

A diferença mais prática é o state. O Terraform precisa guardar e proteger esse arquivo — em equipe, num backend remoto. O Bicep não tem essa preocupação porque consulta o próprio Azure. Em compensação, o Terraform enxerga outros provedores além da Azure.

## Desafios encontrados

A criação da VM, que deveria ser um comando único, virou uma sequência de erros encadeados. Vale ler na ordem, porque um levou ao outro.

### 1. SkuNotAvailable em brazilsouth

```
Standard_B2ats_v2 is currently not available in location 'brazilsouth'
```

A leitura óbvia é falta de capacidade física na região. Tentativa com um segundo SKU do mesmo tier gratuito deu o mesmo erro. Hipótese: região sem capacidade. Ação: recriar tudo em `eastus2`.

### 2. SkuNotAvailable de novo, agora em eastus2

O mesmo erro, agora numa das maiores regiões do mundo, para **três** SKUs diferentes da família B. A chance de estar sem capacidade para três SKUs simultaneamente é praticamente nula — a hipótese de capacidade regional caiu.

**Teste de controle:** criar uma VM de família diferente, na mesma região.

```
Standard_D2s_v3 (não-burstable)  ->  criou de primeira
```

Isso isolou a variável. Não era região, não era capacidade: era a família B especificamente.

**Causa real:** cota **zerada** para toda a família B na subscription nova. Medida antifraude padrão da Microsoft. A mensagem de erro fala "not available", sugerindo indisponibilidade física, mas a causa é administrativa — são coisas diferentes que produzem o mesmo texto.

**Solução:** seguir com `Standard_D2s_v3`, consumindo o crédito de US$ 200 em vez das 750h mensais do tier gratuito.

> **O que ficou:** quando um erro se repete em condições que deveriam ser diferentes, a variável que você está mudando não é a certa. Trocar de região três vezes não resolveria — o teste que resolveu foi mudar a família da VM, mantendo tudo o resto igual.

### 3. Tamanho de disco menor que a imagem

```
The specified disk size 64 GB is smaller than the size of the corresponding
disk in the VM image: 127 GB
```

O parâmetro `--os-disk-size-gb 64` fazia sentido para o SKU original, onde o disco de 64 GiB era exigência do tier gratuito. Ao trocar para `Standard_D2s_v3` essa restrição sumiu — e a imagem do Windows Server 2022 exige no mínimo 127 GB.

> **O que ficou:** parâmetros herdados de uma configuração anterior viram erro quando o contexto muda. Ao trocar de SKU, revisar o comando inteiro, não só o campo `--size`.

### 4. Nome de computador acima do limite

```
Windows computer name cannot be more than 15 characters long
```

Por padrão o `az vm create` usa o valor de `--name` também como nome de computador dentro do Windows. E `vm-web-prod-eus2` tem 16 caracteres — um a mais que o limite do NetBIOS, que é de 1987 e continua valendo.

```
--name           vm-web-prod-eus2   (recurso Azure, sem limite)
--computer-name  vmwebprodeus2      (Windows, 13 caracteres)
```

> **O que ficou:** o nome do recurso na Azure e o hostname dentro do sistema operacional são independentes. Convenções com hífen e sufixo de região estouram o limite do NetBIOS com facilidade.

### 5. Recursos órfãos depois de deletar a VM de teste

A VM criada no teste de controle foi deletada com `az vm delete`. Mas o comando remove **apenas a VM** — NIC, IP público e disco ficam soltos, cobrando.

```powershell
az resource list --resource-group <rg> --output table
```

Cada um precisou ser deletado individualmente.

> **O que ficou:** deletar uma VM na Azure não cascateia. Depois de qualquer teste descartável, listar os recursos do RG e conferir o que sobrou — senão o custo continua correndo em silêncio.

### 6. Erro de sintaxe no Bicep

Várias linhas de `BCP103` e `BCP007`. O arquivo foi escrito com aspas duplas; o Bicep exige aspas simples — diferente do Terraform (HCL) e do JSON, que aceitam duplas.

### 7. Pasta criada dentro do System32

O terminal estava aberto em `C:\Windows\System32` no momento de criar a pasta do projeto. A estrutura inteira, incluindo o `.terraform` já inicializado, foi parar lá dentro.

Resolvido com `Move-Item`, mas foi necessário rodar `terraform init` novamente — o state está amarrado ao caminho.

## Aprendizados

**Azure**

- `SkuNotAvailable` pode significar cota zerada, não falta de capacidade física. A mensagem não distingue as duas coisas.
- Subscriptions novas vêm com cota zero para famílias burstable. Verificar antes de montar um lab inteiro em cima do tier gratuito.
- Deletar VM não deleta NIC, IP público nem disco.
- Nome de recurso Azure e hostname Windows são independentes.

**Infrastructure as Code**

- O Terraform só enxerga o que está no state dele. Recursos criados por fora são invisíveis para o `plan`.
- Bicep usa aspas simples; Terraform e JSON usam duplas.
- Aplicar Terraform num Resource Group isolado evita conflito com o ambiente em uso.

**Diagnóstico**

- Quando o mesmo erro se repete depois de mudar uma variável, a variável mudada não é a causa.
- Um teste de controle bem escolhido vale mais que três tentativas repetindo o mesmo padrão.

## Custos

| Recurso | Custo |
|---|---|
| VNet, sub-redes, NSG | Gratuitos |
| IP público Standard | Cobrado por hora |
| `vm-web-prod-eus2` | `Standard_D2s_v3`, fora do tier gratuito |
| Disco Premium LRS 127 GB | Cobrado por GB provisionado |

O auto-shutdown às 22h é o que segura o custo desta VM.

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

---

**Próximo:** [Lab 06 - Storage, Backup e File Sync](../lab-06-storage-backup/) — primeiro lab que depende diretamente da rede e da VM criadas aqui.
