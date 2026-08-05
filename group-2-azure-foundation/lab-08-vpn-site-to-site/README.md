# Lab 08 - VPN Site-to-Site (On-Premises ↔ Azure)

## Objetivo

Estabelecer conectividade privada entre o ambiente on-premises (`192.168.10.0/24`, no Hyper-V) e a VNet do Azure (`10.10.0.0/16`), através de um túnel IPsec/IKEv2 Site-to-Site, usando RRAS como gateway VPN do lado local.

**Resultado:** túnel estabelecido e validado no plano de controle. A conectividade end-to-end não fechou por uma limitação de infraestrutura do ambiente doméstico — NAT duplo — documentada em detalhe abaixo. Esse resultado é legítimo e está registrado como tal: a limitação encontrada é um cenário que a Microsoft não suporta oficialmente, e identificá-la exigiu eliminar sistematicamente todas as outras hipóteses.

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
              |  IP público dinâmico |
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

## Pré-requisitos

- Lab 05 concluído (VNet e VM no Azure).
- Uma VM adicional no Hyper-V para o gateway (`contoso-gw01`), com dois adaptadores: Lab-Internal e Default Switch.
- IP público conhecido — e a consciência de que ele pode mudar durante o lab.

## Conceitos

**VPN Gateway** é o recurso que termina o túnel do lado da nuvem. Fica numa subnet dedicada (`GatewaySubnet`, com esse nome exato) e recebe um IP público. Diferente da maioria dos recursos de rede, **cobra por hora enquanto existir** e demora de 30 a 45 minutos para provisionar. Isso muda a forma de trabalhar: não dá para criar e destruir casualmente.

**Local Network Gateway (LNG)** é a representação, dentro do Azure, do que existe do outro lado do túnel. Guarda o IP público do gateway on-premises e as faixas de rede que existem lá. Sem o segundo, o Azure não sabe para onde rotear — e isso falha em silêncio.

**RouteBased vs PolicyBased.** Gateway RouteBased usa tabela de rotas; PolicyBased usa regras estáticas. RouteBased é o padrão moderno e o que este lab usa. Um detalhe que confunde: em gateway RouteBased, o Azure sempre negocia traffic selectors como `0.0.0.0/0`. Isso é normal e **não** indica problema.

**NAT-T (NAT Traversal).** O protocolo ESP, que carrega os dados do túnel, não tem portas — o que impede o NAT tradicional de rastrear sessões. O NAT-T contorna encapsulando o ESP dentro de UDP 4500. Funciona bem com **um** nível de NAT. Com dois, o mapeamento de retorno se perde.

**Plano de controle vs plano de dados.** Distinção central para entender o resultado deste lab. O **plano de controle** é a negociação do túnel (IKE) — é o que reporta "Connected". O **plano de dados** é o tráfego real passando dentro do túnel (ESP). Os dois podem estar em estados diferentes: um túnel pode reportar "Connected" com total honestidade e ainda assim não transportar um único pacote.

## Como rodar

Os scripts do lado Azure rodam **no host**. Os de configuração do RRAS rodam **dentro da GW01**, ou via `Invoke-Command` a partir do host.

1. `01-gateway-subnet.ps1` — cria a `GatewaySubnet` com esse nome exato. O Azure identifica a subnet do gateway pelo nome, não por configuração.

2. `02-public-ip.ps1` — Public IP Standard com as três zonas. Obrigatório para o SKU `VpnGw1AZ`.

3. `03-vpn-gateway.ps1` — provisiona o gateway. **De 30 a 45 minutos.** O `--no-wait` devolve o terminal enquanto isso.

4. `04-local-network-gateway.ps1` — cria o LNG com o IP público de casa **e** o prefixo `192.168.10.0/24`. O prefixo é obrigatório; sem ele o túnel conecta mas nada roteia.

5. `05-connection.ps1` — amarra gateway e LNG com a PSK.

6. `06-configurar-rras.ps1` — roda na GW01: instala RRAS, habilita NAT-T no registro, desabilita firewall (ambiente de lab) e cria a interface S2S `To-Azure`.

7. Configurar rotas nas duas pontas — `10.10.0.0/16` na DC01, `192.168.10.0/24` na VM Azure.

8. Liberar ICMP no NSG e no firewall da VM Azure.

> **Custo.** Este é o lab mais caro da trilha por unidade de tempo. Tirar os prints e rodar `08-limpeza.ps1` assim que o objetivo for atingido.

## Validação

```powershell
# Status da Connection
az network vpn-connection show `
    --resource-group rg-network-prod-eus2 --name cn-s2s-eus2 `
    --query "{Status:connectionStatus, In:ingressBytesTransferred, Out:egressBytesTransferred}" `
    --output table

# Parâmetros IKE negociados
az network vpn-connection list-ike-sas `
    --resource-group rg-network-prod-eus2 --name cn-s2s-eus2

# Estado do túnel + rota + teste, TUDO na mesma execução
Invoke-Command -VMName "contoso-gw01" -Credential $cred -ScriptBlock {
    Get-VpnS2SInterface -Name "To-Azure" | Select-Object Name, ConnectionState
    Get-NetRoute -AddressFamily IPv4 |
        Where-Object { $_.DestinationPrefix -eq "10.10.0.0/16" } |
        Select-Object DestinationPrefix, InterfaceAlias, InterfaceIndex
    ping 10.10.1.4 -n 4
}
```

> A validação **na mesma execução** não é detalhe estilístico — é o que evita o erro de método descrito no item 5 dos desafios.

## Resultado

| Item | Status | Evidência |
|---|---|---|
| VPN Gateway provisionado | ✅ | `provisioningState: Succeeded` |
| Connection criada | ✅ | `cn-s2s-eus2` |
| Túnel estabelecido (Azure) | ✅ | `connectionStatus: Connected` |
| Túnel estabelecido (RRAS) | ✅ | `ConnectionState: Connected` |
| Fase 1 IKEv2 negociada | ✅ | AES256 / SHA1 / DHGroup2 |
| Fase 2 (Quick Mode) | ✅ | SPIs inbound e outbound presentes |
| Tráfego IKE | ✅ | 35,22 KiB in / 240 B out |
| Rotas nas duas pontas | ✅ | `10.10.0.0/16` → `To-Azure` |
| NSG e firewall liberados | ✅ | `test-ip-flow`: Allow |
| **Ping end-to-end** | ❌ | 100% loss |

A presença dos SPIs de Quick Mode confirma que a fase 2 fechou. O túnel está completo do ponto de vista de negociação.

## Desafios encontrados

O lab mais difícil da trilha até aqui, por três motivos somados: o gateway custa por hora, o resultado depende de infraestrutura fora do seu controle (roteador, ISP, NAT do Hyper-V), e a falha é silenciosa — tudo reporta sucesso e nada funciona.

### 1. SKU descontinuado

```
The value 'VpnGw1' is not supported
```

SKUs não-AZ foram descontinuados na região. Trocar para `VpnGw1AZ`.

### 2. Public IP sem zonas

O SKU `VpnGw1AZ` é zone-redundant e exige Public IP Standard com as três zonas declaradas: `--zone 1 2 3`.

### 3. IP público residencial mudou no meio do lab

Depois de horas com tudo funcionando, o túnel parou:

```
Connect-VpnS2SInterface: The network connection between your computer and
the VPN server could not be established because the remote server is not
responding.
```

O IP público de casa mudou, e o LNG continuava apontando para o antigo — o Azure estava tentando falar com um endereço que não era mais o nosso.

```powershell
(Invoke-WebRequest -Uri "https://api.ipify.org").Content
```

> **O que ficou:** IP residencial é dinâmico. Para VPN S2S estável, seria necessário DNS dinâmico ou IP fixo contratado. Num lab, basta conferir o IP quando algo parar de funcionar sem motivo aparente.

### 4. LNG sem prefixo de endereço — a falha mais silenciosa

Túnel conectando normalmente, status Connected dos dois lados, e nenhum tráfego roteando. Não havia erro em lugar nenhum.

Pior: o comando de verificação mostrava o campo vazio **mesmo quando estava preenchido**, porque `--output table` não renderiza arrays. Isso levou a diagnóstico errado numa primeira passada.

```powershell
# Errado — esconde o array
az network local-gateway show ... --output table

# Certo
az network local-gateway show ... --query "localNetworkAddressSpace"
```

> **O que ficou:** dois aprendizados. O prefixo do LNG é obrigatório e sua ausência não gera erro nenhum. E `--output table` do Azure CLI esconde arrays — sempre validar com `--query` em JSON.

### 5. Rota migrando para o Loopback

```
PING: transmit failed. General failure.
```

Isso **não** é timeout. Timeout significa que o pacote saiu e não voltou. "Transmit failed" significa que o Windows não conseguiu nem transmitir.

Quando o túnel cai, o RRAS remove a interface e a rota `10.10.0.0/16` escorrega para o Loopback:

```
DestinationPrefix : 10.10.0.0/16
InterfaceAlias    : Loopback Pseudo-Interface 1   <- rota órfã
InterfaceIndex    : 1
```

O pacote era entregue ao loopback e morria ali.

> **O que ficou — o erro de método mais custoso do lab:** durante várias tentativas, o estado do túnel e o estado da rota foram verificados em **momentos diferentes**. Como o túnel caía e voltava, cada verificação pegava um retrato diferente, e as conclusões não batiam. A correção foi validar tudo na mesma execução — foi isso que produziu a evidência conclusiva.

### 6. Outros

- **Serviço RRAS parado:** `Start-Service RemoteAccess`
- **Rota não persistida na VM Azure:** `route add -p` via RDP pode não persistir; validar via `run-command`
- **Comando de reset removido:** `az network vpn-connection reset` não existe mais; usar `Disconnect`/`Connect-VpnS2SInterface`

## Limitação encontrada — NAT duplo

### A evidência

Capturado numa **única execução**, garantindo que os três estados coexistem no mesmo instante:

```
=== ESTADO DO TÚNEL RRAS ===
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

Túnel up, rota correta, interface correta — e o pacote não passa.

### O que foi eliminado

O lado Azure foi validado com o Network Watcher:

```
az network watcher test-ip-flow ... -> Access: Allow
                                      Rule: AllowVnetInBound
```

Isso descarta de uma vez NSG, route table, propagação de rotas do gateway e firewall da VM. O caminho no Azure está limpo. Somado à rota correta do lado on-premises e ao túnel negociado nas duas fases, sobra apenas a camada de encapsulamento ESP.

### A causa provável

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

O ESP não tem portas, o que impede o NAT tradicional de rastrear sessões. O NAT-T contorna encapsulando em UDP 4500 — e funciona com **um** nível de NAT. Com dois, o mapeamento de retorno se perde: o Azure responde, o roteador entrega ao host Hyper-V, e o NAT do Hyper-V não consegue determinar qual VM interna é o destino.

A assinatura de tráfego é consistente com isso:

```
Data in  : 35,22 KiB   <- Azure recebe normalmente
Data out : 240 B       <- respostas não completam o caminho de volta
```

O "Connected" reportado pelos dois lados é honesto: refere-se ao plano de controle, que atravessa NAT sem problema. O plano de dados é que não fecha.

A Microsoft **não suporta oficialmente** gateway VPN atrás de múltiplos níveis de NAT. É limitação de infraestrutura, não erro de configuração.

### Como resolver em ambiente real

| Abordagem | Aplicabilidade |
|---|---|
| External vSwitch no Hyper-V | Remove o NAT #1 — cenário suportado |
| Port forwarding UDP 500/4500 | Depende de suporte do roteador |
| IP público dedicado | Solução de produção |
| Azure VPN Client (P2S) | Alternativa quando S2S não é viável |
| ExpressRoute | Produção enterprise, sem internet |

## Aprendizados

**Diagnóstico**

- "Connected" num túnel VPN indica apenas que o plano de controle funcionou. Não garante tráfego de dados.
- A proporção entre ingress e egress é sinal forte: muito in e pouco out aponta para problema no caminho de retorno.
- Estados coletados em momentos diferentes produzem diagnósticos falsos. Túnel, rota e teste devem sair da mesma execução.
- `transmit failed. General failure.` não é a mesma coisa que `Request timed out.` O primeiro é problema local de rota; o segundo é o pacote saindo e não voltando.
- `test-ip-flow` do Network Watcher elimina toda a camada Azure de uma vez. Vale usar cedo, não como último recurso.

**Azure**

- `--output table` não renderiza arrays. Validar com `--query` em JSON.
- O prefixo do LNG é obrigatório e sua ausência não gera erro — apenas silêncio.
- Em gateway RouteBased, traffic selectors `0.0.0.0/0` são normais.

**Operação**

- VPN Gateway custa por hora. Deletar imediatamente ao fim do lab.
- Tirar os prints **antes** de qualquer destruição. O custo de printar é zero; o de perder a evidência é refazer o lab.
- NAT duplo é cenário não suportado. Identificar a topologia de rede **antes** de provisionar recursos que cobram por hora teria economizado horas de gateway rodando.

## Limpeza

Na ordem — a Connection precisa sair antes do Gateway:

```powershell
az network vpn-connection delete --resource-group rg-network-prod-eus2 --name cn-s2s-eus2
az network vnet-gateway delete --resource-group rg-network-prod-eus2 --name vng-contoso-eus2 --no-wait
az network local-gateway delete --resource-group rg-network-prod-eus2 --name lng-onprem-eus2
```

A exclusão leva de 15 a 20 minutos. Confirmar com `az network vnet-gateway list`. O Public IP pode ser mantido para reuso.

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

O PSK não é versionado — os scripts usam `Read-Host`, seguindo a convenção do repositório.

---

**Próximo:** [Lab 09 - Monitoramento híbrido](../lab-09-monitoramento/) — não depende do túnel; os agentes se comunicam por HTTPS/443.
