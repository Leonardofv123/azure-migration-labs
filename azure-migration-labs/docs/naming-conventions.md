# Convencoes de Nomenclatura

## VMs

| Nome      | Papel                          | IP            |
|-----------|--------------------------------|---------------|
| DC01      | Domain Controller + DNS        | 192.168.10.10 |
| FS01      | File Server + DHCP             | 192.168.10.20 |
| WEB01     | IIS Web Server                 | 192.168.10.30 |

## Dominio

- Dominio AD: contoso.local
- NetBIOS: CONTOSO

## OUs

- Uma por setor: TI, Vendas, Financeiro, Diretoria, ServiceAccounts.

## Grupos

- Prefixo GG_ para grupos globais por departamento (ex.: GG_TI, GG_Vendas).

## Rede

- vSwitch: Lab-Internal
- NAT: Lab-NAT
- Faixa: 192.168.10.0/24

## Recursos Azure (labs de nuvem)

- Prefixo de regiao: brazilsouth.
- Padrao sugerido: rg-contoso-<area>, vnet-contoso-<area>, etc.
