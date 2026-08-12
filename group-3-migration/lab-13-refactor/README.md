# Lab 13 - Refactor: WEB01 para Azure App Service

Terceiro lab do Grupo 3. Aqui a mesma carga do Lab 11 muda de
estrategia: em vez de virar uma VM no Azure, vira um App Service.

---

## Objetivo

Provisionar a WEB01 como PaaS em vez de IaaS, e comparar as duas
abordagens lado a lado: quantidade de recursos, esforco operacional
e custo.

O Lab 11 respondeu "da para migrar?". Este responde "era esse o
melhor jeito?".

---

## Rehost x Refactor na pratica

```
LAB 11 - REHOST                    LAB 13 - REFACTOR

azurerm_windows_virtual_machine    azurerm_linux_web_app
azurerm_network_interface          azurerm_service_plan
azurerm_network_security_group     azurerm_resource_group
azurerm_public_ip
azurerm_nic_nsg_association
azurerm_resource_group
azurerm_dev_test_shutdown

7 recursos                          3 recursos

VOCE administra:                    AZURE administra:
  patch do Windows                    patch do SO
  instalacao do IIS                   runtime da aplicacao
  configuracao do servico             disponibilidade
  escala manual                       escala automatica
  janela de manutencao                atualizacao transparente

~USD 110/mes (D2s_v7)               ~USD 13/mes (B1)
                                    USD 0 (F1)
```

A diferenca nao e so preco. E o que voce deixa de ser responsavel.

---

## Quando cada um faz sentido

```
REHOST e melhor quando
  a aplicacao depende de coisas instaladas no SO
  ha software de terceiros que exige acesso ao servidor
  a migracao precisa ser rapida e sem alterar nada
  existe integracao com AD que o PaaS nao cobre

REFACTOR e melhor quando
  a aplicacao e web e nao depende do SO
  o time nao quer administrar servidor
  a carga varia e escala automatica ajuda
  o custo operacional importa mais que controle
```

A WEB01 da Contoso e caso claro de refactor: um site estatico
servido por IIS nao precisa de uma VM inteira.

---

## Status deste lab

O codigo Terraform esta escrito, validado e versionado. O
provisionamento real **nao foi concluido**: a subscription tem cota
zerada para App Service Plans.

```
Error: creating App Service Plan
  unexpected status 401 (401 Unauthorized)
  Operation cannot be completed without additional quota
  Current Limit (Total VMs): 0
  Current Usage: 0
  Amount required for this deployment (Total VMs): 1
```

O `terraform plan` roda limpo e monta os 3 recursos corretamente. O
`apply` esbarra na cota no momento de criar o Service Plan.

---

## Como o diagnostico foi feito

O erro cita "Total VMs", o que sugere problema com maquina virtual.
Mas nao ha VM nenhuma neste lab. O App Service Plan consome cota da
mesma categoria por baixo, mesmo sendo PaaS.

Tres variaveis foram testadas para isolar a causa:

| Variavel testada | Configuracao        | Resultado |
|------------------|---------------------|-----------|
| Tier             | B1 (Basic)          | mesmo erro |
| Tier             | F1 (Free)           | mesmo erro |
| Regiao           | eastus2             | mesmo erro |
| Regiao           | brazilsouth         | mesmo erro |
| Sistema operacional | Windows          | mesmo erro |
| Sistema operacional | Linux            | mesmo erro |

Seis combinacoes, um unico resultado. Quando trocar a variavel nao
muda o comportamento, a variavel nao e a causa.

A conclusao: a restricao esta em nivel de subscription, nao de
configuracao. Conta nova do Azure vem com cotas zeradas em varias
familias como medida antifraude, e App Service Plan e uma delas.

Vale registrar que `az appservice list-locations --sku F1` lista
East US 2 e Brazil South normalmente. A regiao **suporta** o
recurso. A conta e que nao pode cria-lo. Sao coisas diferentes, e a
mensagem de erro nao ajuda a separar.

---

## Precedente no proprio repositorio

Este e o terceiro bloqueio de cota da trilha, e o padrao ja e
reconhecivel:

```
LAB 05   familia B de VM zerada
         diagnostico inicial errado: achou que era falta de
         capacidade regional. Teste de controle (trocar familia
         mantendo a regiao) isolou a variavel.

LAB 11   Standard_A2_v2 e D2s_v3 indisponiveis em eastus2
         causa diferente: Capacity Restrictions, falta de
         capacidade real da regiao naquele momento.

LAB 13   App Service Plan bloqueado
         de volta para cota de conta, agora em outro servico.
```

Os Labs 05 e 13 sao cota. O Lab 11 e capacidade. Mesma familia de
mensagem de erro, causas distintas. O que separa os casos e testar
trocando uma variavel de cada vez.

---

## Por que nao foi pedido aumento de cota

Pedir aumento de cota e o procedimento correto em ambiente real. O
caminho e portal > Subscriptions > Usage + quotas > New Support
Request.

Aqui a decisao foi outra, e ela e explicita: o prazo de aprovacao
nao esta sob controle e pode levar dias. Travar o cronograma da
trilha esperando aprovacao para um lab que ja provou seu ponto no
codigo nao compensa.

O que este lab precisava demonstrar era a **diferenca entre rehost e
refactor**, e essa diferenca esta no Terraform: 3 recursos contra 7,
sem NIC, sem NSG, sem IP publico, sem instalacao de servico.

---

## Terraform

```
terraform/
├── main.tf         resource group, service plan, linux web app
├── variables.tf    subscription_id, sku, nome do app
└── outputs.tf      URL publica, nome, sku do plano
```

Validacao executada:

```powershell
terraform init
terraform plan
```

```
Plan: 3 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + app_service_name     = "contoso-web01-refactor"
  + app_service_plan_sku = "F1"
  + app_service_url      = (known after apply)
```

O plan confirma que o codigo esta correto. Rodar `terraform apply`
em uma subscription com cota liberada provisiona os tres recursos.

---

## Desafios encontrados

### O erro fala de VM em um lab sem nenhuma VM

`Current Limit (Total VMs): 0` em um deploy de App Service confunde.
A tentacao e procurar VM no codigo, e nao tem nenhuma. App Service
Plan consome cota de compute por baixo do PaaS, e a mensagem expoe
essa camada interna sem explicar.

### F1 nao aceita always_on

O plano Free nao suporta `always_on = true`. O Terraform so reclama
no apply, nao no plan:

```hcl
site_config {
  always_on = true    # remover no tier F1
}
```

### Sintaxe de application_stack muda entre Windows e Linux

Windows:

```hcl
application_stack {
  current_stack  = "dotnet"
  dotnet_version = "v6.0"
}
```

Linux:

```hcl
application_stack {
  dotnet_version = "8.0"
}
```

O `current_stack` nao existe no Linux, e o formato da versao perde o
prefixo `v`. Trocar `azurerm_windows_web_app` por
`azurerm_linux_web_app` sem ajustar esse bloco quebra o plan.

### outputs.tf tambem referencia o tipo do recurso

Ao trocar o tipo do web app, o `outputs.tf` continua apontando para
o antigo:

```
Error: Reference to undeclared resource
A managed resource "azurerm_windows_web_app" "web01" has not been
declared in the root module.
```

Renomear recurso no Terraform exige varrer todos os arquivos que o
referenciam, nao so o `main.tf`.

### PowerShell e regex multi-linha

Varias substituicoes com `-replace` e `\r?\n` falharam
silenciosamente: o comando roda, nao da erro, e o arquivo continua
igual. Para remover linha inteira, `Where-Object` funciona melhor:

```powershell
(Get-Content $arquivo) | Where-Object { $_ -notmatch "always_on" } | Set-Content $arquivo
```

Sempre conferir com `Select-String` depois. Comando que roda sem
erro nao e o mesmo que comando que fez o que voce queria.

---

## Aprendizados

**Erro de cota e erro de capacidade parecem iguais e nao sao.**
Cota e limite da sua conta e se resolve com pedido de aumento.
Capacidade e falta de recurso na regiao e se resolve trocando de
regiao ou esperando. Confundir os dois leva a tentar a solucao
errada por horas.

**Trocar variavel sem mudar resultado e informacao, nao fracasso.**
Seis combinacoes testadas com o mesmo erro provaram onde o problema
nao estava. Isso e o que permitiu concluir com confianca que a causa
era a subscription.

**PaaS tambem consome cota de compute.** A abstracao esconde a VM
ate o momento em que ela aparece na mensagem de erro.

**Codigo validado tem valor mesmo sem deploy.** O `terraform plan`
prova que a configuracao esta correta. O que faltou foi permissao da
conta, nao logica.

**Saber quando parar de contornar.** Havia caminho para insistir
(pedir cota, tentar outra subscription). A decisao de documentar e
seguir e tao tecnica quanto a de continuar tentando, e depende do
que o lab precisa provar.

---

## Custos

```
Nenhum recurso provisionado.
Resource group criado e deletado durante os testes.
```

Se a cota for liberada e o lab for executado:

```
App Service Plan F1 (Free)     USD 0
App Service Plan B1 (Basic)    ~USD 13/mes
```

Comparado ao Lab 11 (rehost com VM D2s_v7, ~USD 110/mes), o refactor
para B1 representa reducao de aproximadamente 88 por cento no custo
mensal para a mesma carga.

---

## Proximo lab

Lab 14 - Framework de Decisao dos 5 Rs: consolida as estrategias
aplicadas na trilha e justifica a escolha para cada carga da
Contoso.
