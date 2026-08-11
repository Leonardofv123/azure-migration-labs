# Lab 11 - Rehost: migracao da WEB01 para o Azure

Segundo lab do Grupo 3. Aqui a WEB01 finalmente atravessa: sai do
Hyper-V e passa a rodar no Azure.

---

## Objetivo

Levar a carga de trabalho da contoso-web01 (Windows Server + IIS
servindo uma pagina) para uma VM no Azure, usando o sizing que o
assessment do Lab 10 recomendou, e validar que o site responde
publicamente.

---

## Uma decisao antes de comecar

O caminho oficial do rehost no Azure Migrate depende do Appliance
replicando o disco continuamente. Como o Appliance nao completou o
registro no Lab 10 (limitacao de rede documentada la), esse caminho
estava fechado.

Duas opcoes na mesa:

```
INSISTIR NO APPLIANCE
  A replicacao de disco e muito mais pesada que o registro que ja
  falhou. Se o POST de registro nao passa, a replicacao continua
  tambem nao passaria. Alta chance de repetir o mesmo diagnostico
  e nao sair do lugar.

REHOST ASSISTIDO POR IaC          <- adotado
  Provisionar a VM de destino com Terraform, usando o SKU que o
  assessment recomendou, e recriar a configuracao da aplicacao.
  A carga de trabalho migra de verdade, so que a infraestrutura
  nasce de codigo em vez de vir de uma copia de disco.
```

Vale ser explicito sobre o que muda com essa escolha:

```
O QUE O REHOST VIA ASR TRARIA        O QUE ESTE LAB FAZ
copia bit a bit do disco             VM nova provisionada do zero
tudo que estava instalado            IIS instalado e configurado
arquivos e configuracoes intactos    conteudo recriado
                                     
zero trabalho manual                 configuracao manual da aplicacao
depende de replicacao continua       depende so de codigo e acesso RDP
```

Para uma VM simples como a WEB01 (Windows Server + IIS servindo
paginas estaticas), recriar sai mais rapido do que replicar. Em
migracoes reais essa decisao aparece com frequencia: nem toda VM
vale o custo e a complexidade de uma replicacao completa.

---

## Arquitetura

```
ANTES                              DEPOIS

contoso-web01                      vm-web01-migrated
Hyper-V local                      Azure, East US 2
192.168.10.30                      10.10.1.5 (privado)
Lab-Internal                       20.114.161.35 (publico)
Windows Server 2022 + IIS          Windows Server 2022 + IIS
                                   
       |                                    ^
       |                                    |
       +---- rehost via Terraform ----------+
```

A VM nova entra na `vnet-contoso-eus2` e na `subnet-web` que ja
existiam desde o Lab 05. Isso e proposital: em uma migracao real a
carga que chega no Azure convive com o que ja esta la, nao ganha
uma rede propria isolada.

---

## Recursos criados

```
rg-migrated-prod-eus2
  pip-web01-migrated-eus2      IP publico Standard, estatico
  nsg-web01-migrated           libera 80, 443 e 3389
  nic-web01-migrated-eus2      conectada na subnet-web existente
  vm-web01-migrated            Windows Server 2022 Gen2
  auto-shutdown                22h, horario de Brasilia
```

---

## Pre-requisitos

- Ambiente Azure do Grupo 2 no ar (VNet e subnet existentes)
- Assessment do Lab 10 concluido (e dele que vem o sizing)
- Terraform instalado
- Azure CLI autenticado na subscription correta

---

## Passo a passo

### 1. Estrutura de pastas

```powershell
New-Item -ItemType Directory -Path "D:\azure-migration-labs\group-3-migration\lab-11-rehost\scripts"
New-Item -ItemType Directory -Path "D:\azure-migration-labs\group-3-migration\lab-11-rehost\terraform"
New-Item -ItemType Directory -Path "D:\azure-migration-labs\group-3-migration\lab-11-rehost\screenshots"
```

### 2. Resource group de destino

```powershell
az group create `
  --name rg-migrated-prod-eus2 `
  --location eastus2
```

Detalhe que cobra o preco depois: criar o RG por fora e depois
declarar ele no Terraform gera conflito. Ou cria so pelo Terraform,
ou importa para o state (ver desafios).

### 3. Terraform

Tres arquivos em `terraform/`:

```
main.tf         data sources da rede existente + recursos novos
variables.tf    subscription_id, vm_size, credenciais
outputs.tf      IPs e resource ID da VM criada
```

A senha nunca fica no codigo. Ela e declarada como variavel
`sensitive` e o Terraform pergunta na hora de rodar.

```powershell
terraform init
terraform plan
terraform apply
```

### 4. Instalacao do IIS

Acesso via RDP no IP publico:

```powershell
mstsc /v:20.114.161.35
```

Dentro da VM:

```powershell
Install-WindowsFeature -Name Web-Server -IncludeManagementTools
```

### 5. Publicacao do site

Pagina criada em `C:\inetpub\wwwroot\index.html`, identificando a
origem da migracao. A pagina padrao do IIS foi removida para a nova
assumir a raiz.

### 6. Validacao

Local, dentro da VM:

```powershell
Invoke-WebRequest -Uri "http://localhost" -UseBasicParsing | Select-Object StatusCode
```

Externa, do navegador do host:

```
http://20.114.161.35
```

Ambos retornaram 200.

---

## Desafios encontrados

### O nome da subnet no codigo nao era o nome real

O `main.tf` referenciava `snet-web`, seguindo a convencao de
nomenclatura do repositorio. So que a subnet criada la no Lab 05 se
chama `subnet-web`. O Terraform reclamou de forma clara:

```
Subnet (... Subnet Name: "snet-web") was not found
```

Convencao documentada e o que voce pretendia fazer. O que esta no
Azure e o que voce fez. Nem sempre batem, e o codigo tem que seguir
a realidade:

```powershell
az network vnet subnet list `
  --resource-group rg-network-prod-eus2 `
  --vnet-name vnet-contoso-eus2 `
  --query "[].name" `
  --output table
```

### Resource group criado por fora vira conflito no apply

O RG tinha sido criado com `az group create` antes de escrever o
Terraform. Na hora do apply:

```
A resource with the ID "..." already exists - to be managed via
Terraform this resource needs to be imported into the State.
```

Nao e erro, e o Terraform se recusando a assumir controle de algo
que ele nao criou. A saida e importar:

```powershell
terraform import azurerm_resource_group.migrated "/subscriptions/<sub-id>/resourceGroups/rg-migrated-prod-eus2"
```

Licao pratica: ou tudo nasce do Terraform, ou o que veio antes
precisa entrar no state antes do primeiro apply.

### Limite de 15 caracteres no nome de computador (de novo)

`vm-web01-migrated` tem 17 caracteres. O nome do recurso no Azure
aceita, o nome NetBIOS do Windows nao:

```
"computer_name" can be at most 15 characters, got 17
```

Mesmo limite que apareceu no Lab 05. A diferenca e que la o
parametro era `--computer-name` na CLI, aqui e o argumento
`computer_name` no bloco da VM:

```hcl
name          = "vm-web01-migrated"
computer_name = "web01-mig"
```

### SkuNotAvailable duas vezes, e nao era cota

Primeiro com o `Standard_A2_v2`, o SKU que o assessment recomendou:

```
Following SKUs have failed for Capacity Restrictions:
Standard_A2_v2 is currently not available in location 'eastus2'
```

Depois com o `Standard_D2s_v3`, que funciona nas outras VMs deste
lab. Mesma mensagem.

No Lab 05 um `SkuNotAvailable` parecido era cota zerada para a
familia B. Aqui e outra coisa: `Capacity Restrictions` e falta de
capacidade da regiao naquele momento, nao limite da conta. O jeito
de separar os dois casos e listar o que esta disponivel agora:

```powershell
az vm list-skus --location eastus2 --size Standard_D2 --output table
```

A coluna `Restrictions` conta a historia. `Standard_D2s_v7` estava
com `None`, e foi o escolhido.

Vale registrar que isso significa que a VM nao subiu com o SKU que o
assessment recomendou. Em ambiente real isso e uma decisao de
migracao: quando o SKU alvo nao esta disponivel, escolhe-se o
equivalente mais proximo e documenta-se o desvio.

### SKU novo nao boota imagem Geracao 1

Trocado o SKU, veio outro erro:

```
The selected VM size 'Standard_D2s_v7' cannot boot Hypervisor
Generation '1'
```

A imagem `2022-datacenter` e Gen1. Os SKUs das familias mais novas
so aceitam Gen2. A correcao e no `sku` da imagem, nao no tamanho da
VM:

```hcl
sku = "2022-datacenter-g2"
```

Detalhe que nao aparece na documentacao basica: o sufixo `-g2` no
nome da imagem e o que define a geracao.

---

## Aprendizados

**Erro em cadeia nao e o mesmo erro repetido.** Foram cinco falhas
seguidas no `terraform apply`, cada uma com causa diferente: nome de
subnet, RG fora do state, limite NetBIOS, capacidade regional e
geracao de hipervisor. A tentacao e achar que "o Terraform nao esta
funcionando". Cada mensagem apontava exatamente o que corrigir.

**SkuNotAvailable tem mais de uma causa.** No Lab 05 era cota da
conta. Aqui era capacidade da regiao. Mesma mensagem, diagnostico e
solucao diferentes. O `az vm list-skus` com a coluna `Restrictions`
e o que separa os dois casos.

**O que o assessment recomenda nem sempre e o que voce consegue
provisionar.** O plano dizia `Standard_A2_v2`. A realidade da regiao
naquele momento disse outra coisa. Migracao tem esses desvios, e
documentar o desvio vale mais do que fingir que ele nao aconteceu.

**Terraform assume o que ele criou, nao o que ja existia.** O import
resolve, mas o mais limpo e decidir desde o inicio quem e o dono de
cada recurso.

**Rehost nao precisa ser replicacao de disco para ser rehost.** A
carga de trabalho saiu do Hyper-V e chegou no Azure fazendo a mesma
coisa. O caminho foi outro, e a documentacao diz qual foi.

---

## Screenshots

| Arquivo | Descricao |
|---------|-----------|
| vm-migrada-criada.png | Recursos no resource group apos o apply |
| rdp-conectado-vm-migrada.png | Acesso RDP na VM de destino |
| site-migrado-acessivel-internet.png | Site respondendo no IP publico |

---

## Custos

```
vm-web01-migrated (Standard_D2s_v7)   fora do tier gratuito
pip-web01-migrated-eus2 (Standard)    cobra por hora alocado
Disco Standard_LRS                    cobra por GB
```

Auto-shutdown as 22h ja esta configurado no Terraform, mas ele so
desliga o compute. IP publico e disco continuam contando.

Para derrubar tudo quando o lab estiver validado:

```powershell
terraform destroy
```

Antes de rodar isso, tirar os prints. Depois do destroy nao tem
como voltar.

---

## O que fica pendente

A WEB01 original continua ligada no Hyper-V. O cutover de verdade
(desligar a origem e apontar o trafego para o destino) fica para o
Lab 12, junto com a validacao pos-migracao.
