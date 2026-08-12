# Lab 14 - Framework de Decisao dos 5 Rs

Ultimo lab da trilha. Aqui nao se provisiona nada: se decide.

Os treze labs anteriores construiram o ambiente e migraram uma carga.
Este pega cada servidor da Contoso do Brasil e responde uma pergunta
so: qual estrategia de migracao faz sentido para ele, e por que.

---

## Os 5 Rs

Framework de estrategias de migracao para nuvem. A versao da
Microsoft no Cloud Adoption Framework usa estes cinco, embora
outros autores incluam Retire e Retain, chegando a seis ou sete.

```
REHOST         move como esta, sem alterar a aplicacao
               VM vira VM. Rapido, sem ganho de plataforma.

REFACTOR       ajustes minimos para rodar em PaaS
               a aplicacao e a mesma, muda onde ela roda.

REARCHITECT    redesenha a aplicacao
               monolito vira microsservicos, por exemplo.

REBUILD        reescreve do zero como cloud-native
               a aplicacao antiga e descartada.

REPLACE        troca por um SaaS pronto
               nao migra nada, contrata outra coisa.
```

Dois adicionais que aparecem na pratica e que a trilha usa:

```
RETIRE         desliga e nao substitui
               a carga nao era mais necessaria.

RETAIN         fica onde esta, por enquanto
               migrar agora nao compensa ou nao e possivel.
```

---

## Por que esse framework existe

Sem um criterio, toda migracao vira rehost. E o caminho de menor
resistencia: copia a VM, sobe no Azure, pronto. Funciona, e as vezes
e a escolha certa.

O problema e quando vira a unica escolha. Ai a empresa sai de um
datacenter proprio e chega na nuvem com os mesmos servidores, os
mesmos patches para aplicar, o mesmo trabalho operacional, so que
pagando por hora em vez de ter comprado o hardware.

Os 5 Rs forcam a pergunta antes da execucao: essa carga precisa
mesmo ser uma VM do outro lado?

---

## O ambiente da Contoso do Brasil

```
contoso-dc01   192.168.10.10   AD DS + DNS, dominio contoso.local
                               + Entra Connect (Lab 07)
                               + Azure Arc + AMA (Lab 09)

contoso-fs01   192.168.10.20   File Server
                               + Azure File Sync (Lab 06)
                               + Azure Arc + AMA (Lab 09)

contoso-web01  192.168.10.30   IIS servindo intranet
                               + Azure Arc + AMA (Lab 09)

contoso-gw01   192.168.10.1    RRAS, gateway e NAT
                               + VPN Site-to-Site (Lab 08)
```

Quatro servidores, quatro decisoes diferentes.

---

## Decisao por carga

### contoso-web01 - IIS

```
ESTRATEGIA   Refactor
ALTERNATIVA  Rehost (executado no Lab 11)
```

**Por que refactor.** O site e servido por IIS e nao depende de nada
instalado no SO alem do proprio servidor web. Nao ha software de
terceiros, nao ha integracao com o dominio, nao ha job agendado. E
o caso de livro do App Service.

**O que os labs mostraram.** O Lab 11 fez o rehost e funcionou: VM
no Azure, IIS instalado, site respondendo publicamente. O Lab 13
escreveu o refactor e comparou:

```
                    REHOST (Lab 11)      REFACTOR (Lab 13)
recursos            7                     3
patch do SO         responsabilidade sua  Azure
escala              manual                automatica
custo mensal        ~USD 110 (D2s_v7)     ~USD 13 (B1)
```

Reducao de aproximadamente 88 por cento no custo, e o time deixa de
administrar um servidor.

**O que quebraria.** Se a intranet usasse autenticacao integrada com
o AD, ou se houvesse aplicacao ASP.NET legada dependendo de
componentes registrados no Windows, o refactor exigiria trabalho
antes. Nao e o caso aqui.

**Situacao real.** O rehost foi executado. O refactor teve o codigo
validado mas nao provisionado, por cota da subscription (documentado
no Lab 13).

---

### contoso-fs01 - File Server

```
ESTRATEGIA   Replace
ALTERNATIVA  Rehost
```

**Por que replace.** Um file server e infraestrutura, nao aplicacao.
Ele existe para guardar arquivos e controlar quem acessa o que. O
Azure Files faz exatamente isso sem VM nenhuma.

**O caminho ja esta meio andado.** O Lab 06 configurou Azure File
Sync entre o FS01 e um File Share no Azure. Os arquivos ja estao
sincronizados na nuvem. O que falta e cortar o lado local.

```
HOJE (Lab 06)                    DEPOIS DO REPLACE

FS01 (VM)                        Azure Files
  C:\VendasLocal                   share "vendas"
      |                                ^
      +-- File Sync -----------------> |
                                       |
  usuarios acessam via                usuarios acessam
  \\FS01\Vendas                       direto pelo share
```

**O que quebraria.** Permissoes NTFS herdadas de grupos do AD
precisam ser recriadas ou mapeadas via Entra ID. Se houver
aplicacao com caminho UNC hardcoded apontando para `\\FS01\`, ela
precisa ser ajustada. Em ambiente real isso e o que da trabalho, nao
a migracao dos arquivos em si.

**Custo.** Elimina a VM e o disco. Fica so o custo por GB armazenado
e transacoes, que para o volume da Contoso e marginal.

---

### contoso-dc01 - Active Directory Domain Services

```
ESTRATEGIA   Retain (por enquanto)
DEPOIS       Replace parcial por Entra ID
```

**Por que retain.** Esta e a decisao menos obvia da lista, e a mais
importante de justificar.

O DC01 nao e so um servidor: e a raiz de identidade do ambiente
inteiro. Todo servidor ingressado no dominio, toda permissao de
arquivo, toda politica de grupo depende dele. Migrar ou substituir
um domain controller nao e uma migracao, e uma mudanca de
arquitetura de identidade.

**O que ja existe.** O Lab 07 configurou o Entra Connect com Password
Hash Sync. Os oito usuarios do AD ja existem no Entra ID, e a senha
funciona nos dois lados. A ponte de identidade esta construida.

```
HOJE

contoso.local (AD DS)  --- Entra Connect ---> Entra ID
  8 usuarios                                    8 usuarios
  5 OUs                                         mesmas senhas
  4 grupos globais
```

**Por que nao substituir agora.** Enquanto houver servidor
ingressado no dominio ou aplicacao usando autenticacao integrada, o
AD DS precisa existir. No estado atual da Contoso, o FS01 depende
dele para permissoes.

A ordem correta e: primeiro migrar ou substituir o que depende do
dominio, depois avaliar o DC. Fazer o contrario quebra tudo de uma
vez.

**Quando revisitar.** Depois que FS01 virar Azure Files e WEB01 virar
App Service, sobra pouca coisa dependendo do dominio local. Ai a
conversa muda: ou o DC vai para uma VM no Azure (rehost, mantendo
AD DS), ou o ambiente vira cloud-only com Entra ID, ou usa Microsoft
Entra Domain Services como meio termo.

**A alternativa que nao foi escolhida.** Rehost do DC01 para uma VM
no Azure e tecnicamente possivel e comum. Mas mantem o custo
operacional de administrar um domain controller sem ganho de
plataforma - o mesmo trabalho, so que na nuvem.

---

### contoso-gw01 - RRAS

```
ESTRATEGIA   Retire
```

**Por que retire.** O GW01 existe para uma funcao so: rotear a rede
`192.168.10.0/24` para fora e terminar o tunel VPN do lado
on-premises.

Quando as outras cargas sairem do Hyper-V, nao sobra rede local para
rotear. E o VPN Gateway do Azure ja faz o lado de la do tunel de
forma nativa e gerenciada.

```
HOJE                              DEPOIS

GW01 (VM com RRAS)                nada
  gateway de 192.168.10.0/24        (a rede local deixa de existir)
  termina o tunel S2S               Azure VPN Gateway continua
  NAT para internet                 (se ainda houver ponta local)
```

**O que quebraria.** Nada, desde que ele seja o ultimo a sair.
Enquanto DC01 ou FS01 estiverem ligados no Hyper-V, eles dependem do
GW01 para alcancar a internet e o Azure. Desligar antes da hora
isola o que sobrou.

**Ordem importa.** GW01 e a ultima peca a ser desligada, nao a
primeira.

---

## Resumo

| Carga | Estrategia | Destino | Status |
|-------|-----------|---------|--------|
| contoso-web01 | Refactor | Azure App Service | rehost executado (Lab 11), refactor codificado (Lab 13) |
| contoso-fs01 | Replace | Azure Files | File Sync configurado (Lab 06) |
| contoso-dc01 | Retain | AD DS local + Entra ID | Entra Connect ativo (Lab 07) |
| contoso-gw01 | Retire | nenhum | pendente, ultimo a sair |

---

## Ordem de execucao

A estrategia diz **o que** fazer com cada carga. A ordem diz
**quando**, e ela e ditada pelas dependencias.

```
1. WEB01     nao depende de nada, entao vai primeiro
             (executado no Lab 11)

2. FS01      depende do DC01 para permissoes
             precisa resolver identidade antes de cortar

3. DC01      so depois que ninguem mais depender dele

4. GW01      ultimo, quando nao houver rede local para rotear
```

Migrar na ordem errada nao e so ineficiente: quebra o ambiente no
meio do caminho, com metade das cargas de cada lado e nenhuma rota
entre elas.

---

## Custo comparado

Estimativa baseada no assessment do Lab 10 (4 servidores, USD 440,45
por mes em rehost puro) contra a estrategia mista deste lab:

```
REHOST DE TUDO                    ESTRATEGIA MISTA

web01   VM      ~USD 110          web01   App Service   ~USD 13
fs01    VM      ~USD 110          fs01    Azure Files   ~USD 5
dc01    VM      ~USD 110          dc01    retain        USD 0 no Azure
gw01    VM      ~USD 110          gw01    retire        USD 0
                --------                                --------
                ~USD 440                                ~USD 18
```

Os valores de Azure Files sao estimativa por volume; o assessment do
Lab 10 calculou apenas o cenario de rehost.

A diferenca nao vem de negociar preco. Vem de nao migrar o que nao
precisava ser migrado.

---

## Aprendizados

**Rehost e o default, nao a resposta.** E o caminho mais rapido e por
isso vira o unico caminho quando ninguem pergunta se ha alternativa.
O framework existe para forcar a pergunta.

**A melhor migracao as vezes e nao migrar.** Retire e Retain nao sao
fracasso do processo, sao resultado legitimo. O GW01 nao precisa de
destino no Azure. O DC01 nao precisa ir agora.

**Dependencia define ordem, nao preferencia.** Dava para comecar pelo
DC01, que e o servidor mais importante. Seria o pior comeco
possivel, porque todo o resto depende dele.

**Decisao de arquitetura precisa de dado.** O que sustentou cada
escolha aqui nao foi opiniao: foi o custo do assessment do Lab 10, o
File Sync ja configurado no Lab 06, o Entra Connect funcionando
desde o Lab 07, e a comparacao real entre os Labs 11 e 13.

**Documentar a alternativa recusada vale tanto quanto a escolhida.**
"Rehost do DC01 e possivel mas mantem o custo operacional sem ganho"
diz mais sobre o raciocinio do que so escrever "Retain".

---

## Custos

Este lab nao provisiona nada. Nao ha custo associado.

---

## Fim da trilha

```
GRUPO 1 - Fundacao on-premises
  Lab 01  Hyper-V + primeira VM
  Lab 02  Active Directory + DNS
  Lab 03  DHCP + File Server
  Lab 04  IIS

GRUPO 2 - Fundacao Azure
  Lab 05  Rede e VM (Terraform, Bicep)
  Lab 06  Storage, Backup e File Sync
  Lab 07  Entra Connect (identidade hibrida)
  Lab 08  VPN Site-to-Site
  Lab 09  Azure Monitor + Arc

GRUPO 3 - Migracao
  Lab 10  Discovery e Assessment
  Lab 11  Rehost da WEB01
  Lab 12  Validacao e cutover
  Lab 13  Refactor para App Service
  Lab 14  Framework de decisao dos 5 Rs
```

A Contoso do Brasil saiu de um Hyper-V isolado, construiu identidade
hibrida, conectividade e monitoramento, avaliou custo antes de
migrar, executou uma migracao e definiu o que fazer com o que
sobrou.
