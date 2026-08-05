# Lab 08 - VPN Site-to-Site (On-Premises e Azure)

## Objetivo

Estabelecer conectividade privada entre o ambiente on-premises (`192.168.10.0/24`, no Hyper-V) e a VNet do Azure (`10.10.0.0/16`), atraves de um tunel IPsec/IKEv2 Site-to-Site, usando RRAS como gateway VPN do lado local.

**Resultado:** tunel estabelecido e validado no plano de controle. A conectividade end-to-end nao fechou por uma limitacao de infraestrutura do ambiente domestico, o NAT duplo, documentada em detalhe abaixo. Esse resultado e legitimo e esta registrado como tal: a limitacao encontrada e um cenario que a Microsoft nao suporta oficialmente, e identifica-la exigiu eliminar sistematicamente todas as outras hipoteses.

## Estrutura criada

```
                     ON-PREMISES (Hyper-V)
    +--------------------------------------------------+
    |   contoso-dc01          contoso-fs01             |
    |   192.168.10.10         192.168.10.20            |
    |        |                     |                   |
    |        +----------+----------+                   |
    |                   |                              |
    |            vSwitch Lab-Internal                  |
    |              192.168.10.0/24                     |
    |                   |                              |
    |            contoso-gw01                          |
    |            192.168.10.1     (RRAS)               |
    |            172.20.129.160   (Default Switch)     |
    +-------------------+------------------------------+
                        |
                        | IPsec / IKEv2
                        | PSK + NAT-T (UDP 4500)
                        v
              +----------------------+
              |      INTERNET        |
              |  IP publico dinamico |
              +----------+-----------+
                         |
                         v
                       AZURE
    +--------------------------------------------------+
    |   pip-vng-eus2         Standard, Zones 1,2,3     |
    |            |                                     |
    |            v                                     |
    |   vng-contoso-eus2     VpnGw1AZ / RouteBased     |
    |            |                                     |
    |            |  GatewaySubnet 10.10.255.0/27       |
    |            v                                     |
    |   vnet-contoso-eus2 (10.10.0.0/16)               |
    |            |                                     |
    |            v                                     |
    |   subnet-web (10.10.1.0/24)                      |
    |   vm-web-prod-eus2 -> 10.10.1.4                  |
    |                                                  |
    |   lng-onprem-eus2      IP de casa + rede local   |
    |   cn-s2s-eus2          Connection IPsec/IKEv2    |
    +--------------------------------------------------+
```

## Pre-requisitos

- Lab 05 concluido (VNet e VM no Azure).
- Uma VM adicional no Hyper-V para o gateway (`contoso-gw01`), com dois adaptadores: Lab-Internal e Default Switch.
- IP publico conhecido, e a consciencia de que ele pode mudar durante o lab.

## Conceitos

**VPN Gateway** e o recurso que termina o tunel do lado da nuvem. Fica numa subnet dedicada (`GatewaySubnet`, com esse nome exato) e recebe um IP publico. Diferente da maioria dos recursos de rede, cobra por hora enquanto existir e demora de 30 a 45 minutos para provisionar. Isso muda a forma de trabalhar: nao da para criar e destruir casualmente.

**Local Network Gateway (LNG)** e a representacao, dentro do Azure, do que existe do outro lado do tunel. Guarda o IP publico do gateway on-premises e as faixas de rede que existem la. Sem o segundo, o Azure nao sabe para onde rotear, e isso falha em silencio.

**RouteBased e PolicyBased.** Gateway RouteBased usa tabela de rotas, e PolicyBased usa regras estaticas. RouteBased e o padrao moderno e o que este lab usa. Um detalhe que confunde: em gateway RouteBased, o Azure sempre negocia traffic selectors como `0.0.0.0/0`. Isso e normal e nao indica problema.

**NAT-T (NAT Traversal).** O protocolo ESP, que carrega os dados do tunel, nao tem portas, o que impede o NAT tradicional de rastrear sessoes. O NAT-T contorna encapsulando o ESP dentro de UDP 4500. Funciona bem com um nivel de NAT. Com dois, o mapeamento de retorno se perde.

**Plano de controle e plano de dados.** Distincao central para entender o resultado deste lab. O plano de controle e a negociacao do tunel (IKE), e e o que reporta "Connected". O plano de dados e o trafego real passando dentro do tunel (ESP). Os dois podem estar em estados diferentes: um tunel pode reportar "Connected" com total honestidade e ainda assim nao transportar um unico pacote.

## Como rodar

Os scripts do lado Azure rodam no host. Os de configuracao do RRAS rodam dentro da GW01, ou via `Invoke-Command` a partir do host.

1. `01-gateway-subnet.ps1` cria a `GatewaySubnet` com esse nome exato. O Azure identifica a subnet do gateway pelo nome, nao por configuracao.

2. `02-public-ip.ps1` cria o Public IP Standard com as tres zonas, obrigatorio para o SKU `VpnGw1AZ`.

3. `03-vpn-gateway.ps1` provisiona o gateway, com confirmacao antes de comecar. Leva de 30 a 45 minutos.

4. `04-local-network-gateway.ps1` cria o LNG. Detecta o IP publico automaticamente e ja inclui o prefixo `192.168.10.0/24`, que e obrigatorio.

5. `05-connection.ps1` amarra gateway e LNG. A PSK e pedida em runtime, nunca versionada.

6. `06-configurar-rras.ps1` roda na GW01: instala RRAS, habilita NAT-T, ajusta a MTU, desabilita firewall (ambiente de lab) e cria a interface S2S `To-Azure`.

7. Configurar rotas nas duas pontas: `10.10.0.0/16` na DC01, `192.168.10.0/24` na VM Azure.

8. `07-diagnostico.ps1` valida tudo na mesma execucao. Ver o item 5 dos desafios para entender por que isso importa.

9. `08-limpeza.ps1` remove os recursos. Rodar assim que terminar, depois de tirar os prints.

> **Custo.** Este e o lab mais caro da trilha por unidade de tempo.

## Validacao

```powershell
# Status da Connection
az network vpn-connection show `
    --resource-group rg-network-prod-eus2 --name cn-s2s-eus2 `
    --query "{Status:connectionStatus, In:ingressBytesTransferred, Out:egressBytesTransferred}" `
    --output table

# Parametros IKE negociados
az network vpn-connection list-ike-sas `
    --resource-group rg-network-prod-eus2 --name cn-s2s-eus2
```

Para o teste completo, usar `07-diagnostico.ps1`, que coleta estado do tunel, rota e ping na mesma execucao.

## Resultado

| Item | Status | Evidencia |
|---|---|---|
| VPN Gateway provisionado | OK | `provisioningState: Succeeded` |
| Connection criada | OK | `cn-s2s-eus2` |
| Tunel estabelecido (Azure) | OK | `connectionStatus: Connected` |
| Tunel estabelecido (RRAS) | OK | `ConnectionState: Connected` |
| Fase 1 IKEv2 negociada | OK | AES256 / SHA1 / DHGroup2 |
| Fase 2 (Quick Mode) | OK | SPIs inbound e outbound presentes |
| Trafego IKE | OK | 35,22 KiB in / 240 B out |
| Rotas nas duas pontas | OK | `10.10.0.0/16` para `To-Azure` |
| NSG e firewall liberados | OK | `test-ip-flow`: Allow |
| Ping end-to-end | FALHOU | 100% loss |

A presenca dos SPIs de Quick Mode confirma que a fase 2 fechou. O tunel esta completo do ponto de vista de negociacao.

## Desafios encontrados

O lab mais dificil da trilha ate aqui, por tres motivos somados: o gateway custa por hora, o resultado depende de infraestrutura fora do seu controle (roteador, ISP, NAT do Hyper-V), e a falha e silenciosa, porque tudo reporta sucesso e nada funciona.

### 1. SKU descontinuado

```
The value 'VpnGw1' is not supported
```

SKUs nao-AZ foram descontinuados na regiao. Trocar para `VpnGw1AZ`.

### 2. Public IP sem zonas

O SKU `VpnGw1AZ` e zone-redundant e exige Public IP Standard com as tres zonas declaradas: `--zone 1 2 3`.

### 3. IP publico residencial mudou no meio do lab

Depois de horas com tudo funcionando, o tunel parou:

```
Connect-VpnS2SInterface: The network connection between your computer and
the VPN server could not be established because the remote server is not
responding.
```

O IP publico de casa mudou, e o LNG continuava apontando para o antigo. O Azure estava tentando falar com um endereco que nao era mais o nosso.

```powershell
(Invoke-WebRequest -Uri "https://api.ipify.org").Content
```

> **O que ficou:** IP residencial e dinamico. Para VPN S2S estavel, seria necessario DNS dinamico ou IP fixo contratado. Num lab, basta conferir o IP quando algo parar de funcionar sem motivo aparente.

### 4. LNG sem prefixo de endereco, a falha mais silenciosa

Tunel conectando normalmente, status Connected dos dois lados, e nenhum trafego roteando. Nao havia erro em lugar nenhum.

Pior: o comando de verificacao mostrava o campo vazio mesmo quando estava preenchido, porque `--output table` nao renderiza arrays. Isso levou a diagnostico errado numa primeira passada.

```powershell
# Errado, esconde o array
az network local-gateway show ... --output table

# Certo
az network local-gateway show ... --query "localNetworkAddressSpace"
```

> **O que ficou:** dois aprendizados. O prefixo do LNG e obrigatorio e sua ausencia nao gera erro nenhum. E `--output table` do Azure CLI esconde arrays, entao sempre validar com `--query` em JSON.

### 5. Rota migrando para o Loopback

```
PING: transmit failed. General failure.
```

Isso nao e timeout. Timeout significa que o pacote saiu e nao voltou. "Transmit failed" significa que o Windows nao conseguiu nem transmitir.

Quando o tunel cai, o RRAS remove a interface e a rota `10.10.0.0/16` escorrega para o Loopback:

```
DestinationPrefix : 10.10.0.0/16
InterfaceAlias    : Loopback Pseudo-Interface 1   <- rota orfa
InterfaceIndex    : 1
```

O pacote era entregue ao loopback e morria ali.

> **O que ficou, o erro de metodo mais custoso do lab:** durante varias tentativas, o estado do tunel e o estado da rota foram verificados em momentos diferentes. Como o tunel caia e voltava, cada verificacao pegava um retrato diferente, e as conclusoes nao batiam. A correcao foi validar tudo na mesma execucao, e foi isso que produziu a evidencia conclusiva. O script `07-diagnostico.ps1` existe por causa disso.

### 6. Outros

- **Servico RRAS parado:** `Start-Service RemoteAccess`
- **Rota nao persistida na VM Azure:** `route add -p` via RDP pode nao persistir, entao validar via `run-command`
- **Comando de reset removido:** `az network vpn-connection reset` nao existe mais, usar `Disconnect` e `Connect-VpnS2SInterface`

## Limitacao encontrada, NAT duplo

### A evidencia

Capturado numa unica execucao, garantindo que os tres estados coexistem no mesmo instante:

```
=== ESTADO DO TUNEL RRAS ===
Name     ConnectionState  Destination
----     ---------------  -----------
To-Azure Connected        {<IP do Gateway>}

=== ROTA PARA AZURE ===
DestinationPrefix InterfaceAlias InterfaceIndex NextHop
----------------- -------------- -------------- -------
10.10.0.0/16      To-Azure       34             0.0.0.0

=== TESTE DE CONECTIVIDADE ===
Pinging 10.10.1.4 with 32 bytes of data:
Request timed out. (x4)
    Packets: Sent = 4, Received = 0, Lost = 4 (100% loss)
```

Tunel up, rota correta, interface correta, e o pacote nao passa.

### O que foi eliminado

O lado Azure foi validado com o Network Watcher:

```
az network watcher test-ip-flow ... -> Access: Allow
                                      Rule: AllowVnetInBound
```

Isso descarta de uma vez NSG, route table, propagacao de rotas do gateway e firewall da VM. O caminho no Azure esta limpo. Somado a rota correta do lado on-premises e ao tunel negociado nas duas fases, sobra apenas a camada de encapsulamento ESP.

### A causa provavel

```
GW01 (192.168.10.1 / 172.20.129.160)
   |
   v  NAT #1 - Default Switch do Hyper-V
   |
   v  NAT #2 - roteador residencial
   |
   v
Azure VPN Gateway
```

O ESP nao tem portas, o que impede o NAT tradicional de rastrear sessoes. O NAT-T contorna encapsulando em UDP 4500, e funciona com um nivel de NAT. Com dois, o mapeamento de retorno se perde: o Azure responde, o roteador entrega ao host Hyper-V, e o NAT do Hyper-V nao consegue determinar qual VM interna e o destino.

A assinatura de trafego e consistente com isso:

```
Data in  : 35,22 KiB   <- Azure recebe normalmente
Data out : 240 B       <- respostas nao completam o caminho de volta
```

O "Connected" reportado pelos dois lados e honesto: refere-se ao plano de controle, que atravessa NAT sem problema. O plano de dados e que nao fecha.

A Microsoft nao suporta oficialmente gateway VPN atras de multiplos niveis de NAT. E limitacao de infraestrutura, nao erro de configuracao.

### Como resolver em ambiente real

| Abordagem | Aplicabilidade |
|---|---|
| External vSwitch no Hyper-V | Remove o NAT #1, cenario suportado |
| Port forwarding UDP 500/4500 | Depende de suporte do roteador |
| IP publico dedicado | Solucao de producao |
| Azure VPN Client (P2S) | Alternativa quando S2S nao e viavel |
| ExpressRoute | Producao enterprise, sem internet |

## Aprendizados

**Diagnostico**

- "Connected" num tunel VPN indica apenas que o plano de controle funcionou. Nao garante trafego de dados.
- A proporcao entre ingress e egress e sinal forte: muito in e pouco out aponta para problema no caminho de retorno.
- Estados coletados em momentos diferentes produzem diagnosticos falsos. Tunel, rota e teste devem sair da mesma execucao.
- `transmit failed. General failure.` nao e a mesma coisa que `Request timed out.` O primeiro e problema local de rota, o segundo e o pacote saindo e nao voltando.
- `test-ip-flow` do Network Watcher elimina toda a camada Azure de uma vez. Vale usar cedo, nao como ultimo recurso.

**Azure**

- `--output table` nao renderiza arrays. Validar com `--query` em JSON.
- O prefixo do LNG e obrigatorio e sua ausencia nao gera erro, apenas silencio.
- Em gateway RouteBased, traffic selectors `0.0.0.0/0` sao normais.

**Operacao**

- VPN Gateway custa por hora. Deletar imediatamente ao fim do lab.
- Tirar os prints antes de qualquer destruicao. O custo de printar e zero, o de perder a evidencia e refazer o lab.
- NAT duplo e cenario nao suportado. Identificar a topologia de rede antes de provisionar recursos que cobram por hora teria economizado horas de gateway rodando.

## Limpeza

Na ordem, porque a Connection precisa sair antes do Gateway:

```powershell
az network vpn-connection delete --resource-group rg-network-prod-eus2 --name cn-s2s-eus2
az network vnet-gateway delete --resource-group rg-network-prod-eus2 --name vng-contoso-eus2 --no-wait
az network local-gateway delete --resource-group rg-network-prod-eus2 --name lng-onprem-eus2
```

A exclusao leva de 15 a 20 minutos. Confirmar com `az network vnet-gateway list`. O Public IP pode ser mantido para reuso.

## Estrutura de arquivos

```
lab-08-vpn-site-to-site/
├── README.md
├── scripts/
│   ├── 01-gateway-subnet.ps1
│   ├── 02-public-ip.ps1
│   ├── 03-vpn-gateway.ps1
│   ├── 04-local-network-gateway.ps1
│   ├── 05-connection.ps1
│   ├── 06-configurar-rras.ps1
│   ├── 07-diagnostico.ps1
│   └── 08-limpeza.ps1
└── screenshots/
```

O PSK nao e versionado. Os scripts usam `Read-Host`, seguindo a convencao do repositorio.

**Proximo:** [Lab 09 - Monitoramento hibrido](../lab-09-monitoramento/), que nao depende do tunel porque os agentes se comunicam por HTTPS/443.
