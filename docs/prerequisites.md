# Pre-requisitos

## Hardware

- Host com 16 GB de RAM (rodar no maximo 2 VMs de 4 GB simultaneas).
- SSD obrigatorio (HD mecanico deixa as VMs lentas demais).
- Espaco livre: ~50 GB para os primeiros labs, 150 a 200 GB para o capstone.

## Software no host

- Windows com Hyper-V habilitado.
- PowerShell 7 (lado a lado com o Windows PowerShell 5.1).
- Git, VS Code, Azure CLI (para os labs de nuvem).

## Imagens

- ISO do Windows Server 2022 x64, versao Evaluation.
- Atencao a arquitetura: usar x64, nunca ARM64.

## Rede do laboratorio

- Faixa: 192.168.10.0/24.
- Gateway (host): 192.168.10.1.
- Isolamento via vSwitch interno + NAT (nao usa a rede fisica de casa).
