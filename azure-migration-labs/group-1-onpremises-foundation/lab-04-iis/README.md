# Lab 04 - IIS Web Server

## Objetivo

Publicar um portal interno (`intranet.contoso.local`) com HTTPS, num app
pool isolado, numa terceira VM (`WEB01`). Este site e candidato a
migracao/refatoracao para Azure App Service em fase futura da trilha
(comparacao IaaS vs PaaS).

## Topologia

```
                    Rede do laboratorio: 192.168.10.0/24

   [ DC01 ]            [ FS01 ]             [ WEB01 ]
   192.168.10.10       192.168.10.20        192.168.10.30
   AD DS + DNS         DHCP + File Server   IIS (IntranetContoso)
                                              porta 80 (HTTP)
                                              porta 443 (HTTPS)
      |                     |                    |
      +---------------------+--------------------+
                       |
            [ vSwitch "Lab-Internal" ]
                       |
            [ Host = 192.168.10.1 = GATEWAY ]
                       |
            [ NAT "Lab-NAT" ]
                       |
                   Internet

   DNS na DC01: intranet.contoso.local -> A -> 192.168.10.30
```

## Pre-requisitos

- Labs 01 a 03 concluidos.
- Host com RAM suficiente para DC01 + WEB01 ligadas (recomendado desligar a
  FS01, que nao e usada neste lab, se o host tiver 16 GB de RAM total).

## Como rodar

1. `00-criar-vm-web01.ps1` (no HOST): cria a VM (4 GB RAM, 2 vCPU, 1 disco).
2. Instalar o Windows Server pela interface grafica (mesma rotina anterior).
3. `01a-rename-ip.ps1` (DENTRO da WEB01): renomeia, IP fixo 192.168.10.30,
   DNS apontando para o DC01. Reiniciar ao final.
4. `01b-ingressar-dominio.ps1` (DENTRO da WEB01, apos reboot): ingressa no
   dominio. A VM reinicia de novo.
5. `02-instalar-iis.ps1` (DENTRO da WEB01): instala o papel IIS.
6. `03-publicar-site.ps1` (DENTRO da WEB01): cria a pasta, o app pool e o
   site (HTTP, porta 80).
7. `04-https-dns.ps1` (DENTRO da WEB01): cria o certificado self-signed,
   o binding HTTPS (porta 443) e o registro DNS remoto na DC01.

## Validacao

```powershell
Get-Website | Format-Table -AutoSize
Get-WebBinding -Name 'IntranetContoso'
Resolve-DnsName -Name 'intranet.contoso.local'
```

Teste final: abrir `https://intranet.contoso.local` no navegador, dentro de
qualquer VM do dominio. O navegador exibe aviso de certificado nao
confiavel (`NET::ERR_CERT_AUTHORITY_INVALID`) - clicar em "Avancado" e
prosseguir para visualizar a pagina.

## Observacoes e boas praticas

- O nome de exibicao de um Windows Feature pode nao bater com o nome
  interno usado pelo PowerShell (ex.: "ASP.NET 4.8" e instalado via
  `Web-Asp-Net45`). Em caso de erro `is not valid`, usar
  `Get-WindowsFeature *termo*` para descobrir o nome correto.
- O aviso de certificado nao confiavel e esperado com certificados
  self-signed; nao indica falha de configuracao.
- `Invoke-Command -ComputerName <servidor>` executa codigo remotamente em
  outro servidor do dominio, sem precisar abrir sessao manual nele - base
  da administracao em escala.

## Conceitos cobertos

IIS, Site, Application Pool, Binding, Host Header, certificado
self-signed, Invoke-Command, IaaS vs PaaS.
