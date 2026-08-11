# Lab 12 - Validacao pos-migracao e cutover

Ultimo lab do Grupo 3 e da trilha. Aqui nao se cria nada novo: se
decide se o que foi migrado esta bom o suficiente para virar a
producao, e o que fazer se nao estiver.

---

## Por que este lab e diferente

Os labs anteriores foram execucao. Este e decisao.

O cutover e o momento em que a migracao deixa de ser reversivel na
pratica. Enquanto a origem continua ligada e recebendo trafego, o
destino e so uma copia rodando em paralelo. Depois que o trafego
muda de lado, voltar atras custa caro e as vezes nao da mais.

Por isso existe um checklist. Nao e burocracia: e a diferenca entre
migrar com confianca e migrar torcendo.

---

## Nota sobre este lab especifico

A `vm-web01-migrated` criada no Lab 11 foi validada (site
respondendo publicamente, HTTP 200) e destruida em seguida, por
decisao consciente de custo documentada la.

Isso significa que este lab e **procedimental**: descreve o processo
de validacao e cutover que seria executado, com os criterios reais
de decisao, sem repetir um teste ja comprovado apenas para gerar
mais uma captura de tela.

O que vale mais aqui nao e provar de novo que o IIS sobe. E deixar
registrado como se decide que uma migracao esta pronta.

---

## Test failover x cutover

Confusao comum, e vale separar antes de continuar.

```
TEST FAILOVER
  Sobe uma copia da VM em uma rede isolada.
  A producao continua rodando normalmente, sem saber.
  Serve para responder: "a VM liga? a aplicacao sobe?"
  Pode ser feito quantas vezes quiser.
  Nao tem impacto se der errado.

CUTOVER
  Move o trafego real da origem para o destino.
  A producao passa a ser a VM nova.
  Serve para responder: nada. E execucao, nao teste.
  Acontece uma vez.
  Se der errado, tem impacto em usuario real.
```

O test failover e onde se descobre problema. O cutover e onde se
paga o preco de nao ter descoberto.

---

## Checklist de validacao pre-cutover

Dividido pelo que a resposta significa, nao por ordem de execucao.

### Infraestrutura

```
[ ] VM de destino liga e completa o boot sem erro
[ ] Sistema operacional atualizado e licenciado
[ ] Disco com espaco livre compativel com a origem
[ ] IP privado dentro da faixa esperada da subnet
[ ] IP publico atribuido, se a carga precisa ser publica
[ ] NSG liberando exatamente as portas necessarias, nao mais
[ ] DNS resolvendo (interno e externo)
```

Este ultimo item derruba mais migracao do que parece. A VM sobe,
responde por IP, e ninguem testa por nome ate o cutover.

### Aplicacao

```
[ ] Servico principal iniciado e configurado para iniciar sozinho
[ ] Aplicacao responde localmente (localhost)
[ ] Aplicacao responde externamente (IP publico ou rede interna)
[ ] Conteudo servido e o mesmo da origem
[ ] Certificados instalados e validos, se aplicavel
[ ] Logs sendo gerados no lugar esperado
```

No Lab 11 os dois primeiros testes de resposta foram feitos:

```powershell
Invoke-WebRequest -Uri "http://localhost" -UseBasicParsing | Select-Object StatusCode
```

```
http://20.114.161.35
```

Ambos retornaram 200.

### Dependencias

```
[ ] Todos os sistemas que consomem esta carga foram mapeados
[ ] Todos os sistemas que esta carga consome foram mapeados
[ ] Cada dependencia alcanca o destino (nao so a origem)
[ ] Integracao com AD funciona, se a carga depende de dominio
[ ] Compartilhamentos de rede acessiveis, se aplicavel
```

Este bloco e o que o mapa de dependencias do Azure Migrate
Appliance geraria automaticamente. Sem ele (limitacao documentada
no Lab 10), o mapeamento precisa ser manual - e manual significa
que alguem pode esquecer.

Na Contoso do Brasil a WEB01 era a candidata mais segura
justamente por ter poucas dependencias: o IIS sobe sem domain
join. DC01 e FS01 nao teriam essa facilidade.

### Operacao

```
[ ] Backup configurado no destino antes do cutover
[ ] Monitoramento coletando (Azure Monitor / AMA / DCR associada)
[ ] Alertas apontando para o destino, nao so para a origem
[ ] Auto-shutdown desabilitado se a carga e realmente producao
[ ] Acesso administrativo testado por mais de uma pessoa
```

O item do auto-shutdown merece atencao. No Lab 11 ele foi
configurado para 22h porque era lab. Em producao, uma VM que
desliga sozinha as 22h e um incidente esperando acontecer.

---

## Criterios go / no-go

Nem todo item do checklist tem o mesmo peso.

```
BLOQUEIA O CUTOVER (no-go absoluto)
  Aplicacao nao responde no destino
  Alguma dependencia critica nao alcanca o destino
  Backup nao configurado
  Sem acesso administrativo confirmado
  Sem plano de rollback testado

ADIA MAS NAO BLOQUEIA (avaliar caso a caso)
  Monitoramento parcial
  Performance abaixo da origem mas dentro do aceitavel
  Certificado com validade curta
  Documentacao incompleta

NAO BLOQUEIA
  Diferenca de SKU em relacao ao recomendado pelo assessment
  Nome de recurso fora do padrao
  Tag faltando
```

O terceiro grupo tem um exemplo concreto deste lab: o assessment do
Lab 10 recomendou `Standard_A2_v2`, e a VM subiu com
`Standard_D2s_v7` por indisponibilidade regional. Isso e um desvio
documentado, nao um impedimento.

---

## Procedimento de cutover

Ordem importa. Cada passo assume que o anterior foi confirmado.

```
1. Congelar mudancas na origem
   Ninguem escreve mais nada na WEB01 a partir daqui.

2. Sincronizar o delta final
   Qualquer conteudo alterado desde a ultima copia.

3. Validar o destino uma ultima vez
   Checklist rapido: servico no ar, conteudo igual.

4. Mudar o apontamento
   DNS, load balancer, ou o que direciona o trafego.
   Este e o ponto de nao retorno pratico.

5. Monitorar a janela critica
   Primeiras horas com atencao redobrada.
   E aqui que aparece o que os testes nao pegaram.

6. Desligar a origem (sem deletar)
   Desliga, mas mantem por um periodo de seguranca.

7. Deletar a origem
   So depois de dias ou semanas de destino estavel.
```

O passo 6 e 7 sao separados de proposito. Desligar e reversivel em
minutos. Deletar nao e reversivel de jeito nenhum.

---

## Rollback

Todo cutover precisa de um caminho de volta definido **antes** de
comecar. Se o plano de rollback so for pensado no momento em que
algo der errado, ja e tarde.

```
GATILHOS DE ROLLBACK
  Aplicacao inacessivel por mais que o tempo tolerado
  Perda de dado detectada
  Dependencia critica quebrada sem correcao rapida
  Performance inviabilizando o uso

PROCEDIMENTO
  1. Reverter o apontamento de trafego para a origem
  2. Religar a origem, se ja tiver sido desligada
  3. Confirmar que a origem voltou a responder
  4. Registrar o que falhou antes de tentar de novo
```

O passo 4 e o que transforma um rollback em aprendizado em vez de
so um susto.

O periodo em que a origem fica desligada mas nao deletada existe
exatamente para viabilizar isso. Deletar cedo demais e trocar
economia de custo por risco.

---

## Estado final da trilha

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
```

A Contoso do Brasil saiu de um ambiente Hyper-V isolado e chegou
com uma carga rodando no Azure, passando por identidade hibrida,
conectividade, monitoramento e avaliacao de custo no caminho.

---

## Aprendizados

**Cutover e decisao, nao tarefa.** A parte tecnica de mudar um
apontamento leva minutos. O que leva tempo e ter certeza de que
esta na hora.

**Checklist existe porque memoria falha sob pressao.** No dia do
cutover ninguem lembra de checar DNS por nome se isso nao estiver
escrito.

**Desligar e deletar sao momentos diferentes.** Juntar os dois em
um passo so elimina a rede de seguranca inteira.

**Mapa de dependencias manual e ponto fraco conhecido.** Sem o
Appliance, esse mapeamento virou responsabilidade humana - e isso
precisa estar explicito, nao escondido.

**Nem todo desvio e problema.** SKU diferente do recomendado, nome
fora do padrao: documenta e segue. Aplicacao fora do ar: para tudo.
Saber separar os dois e o que evita tanto o cutover imprudente
quanto o adiamento eterno.

---

## Custos

Este lab nao cria recursos. Os recursos do Lab 11 ja foram
destruidos apos validacao.

Ainda ativo na subscription (do Grupo 2):

```
vm-web-prod-eus2         fora do tier gratuito, auto-shutdown 22h
law-contoso-eus2         gratuito no volume atual
rsv-contoso-eus2         cobra por instancia protegida
stcontosoeus2lab         cobra por GB
```

Vale revisar periodicamente com:

```powershell
az resource list --query "[].{nome:name, tipo:type, rg:resourceGroup}" --output table
```
