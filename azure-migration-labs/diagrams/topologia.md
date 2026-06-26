# Diagramas (ASCII)

Os diagramas deste repositorio sao mantidos em ASCII, dentro de blocos de
codigo, para serem leves e versionaveis.

## Topologia on-premises (Labs 01 a 04)

```
                    Rede do laboratorio: 192.168.10.0/24
                              (isolada via NAT)

   [ DC01 ]           [ FS01 ]            [ WEB01 ]
   .10                .20                 .30
   AD DS + DNS        File Server +       IIS
                      DHCP
      |                  |                   |
      +------------------+-------------------+
                         |
              [ vSwitch "Lab-Internal" ]
                         |
              [ Host = 192.168.10.1 = GATEWAY ]
                         |
              [ NAT "Lab-NAT" ]
                         |
                     Internet
```

## Floresta Active Directory (Lab 02)

```
Floresta: contoso.local
     |
Dominio: contoso.local (CONTOSO)
     |
OUs: TI | Vendas | Financeiro | Diretoria | ServiceAccounts
     |
Grupos: GG_TI | GG_Vendas | GG_Financeiro | GG_Diretoria
```
