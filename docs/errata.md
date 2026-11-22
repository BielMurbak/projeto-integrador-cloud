# Errata: o que mudou da Entrega 1 para a implantação

Diferenças entre o projeto da Entrega 1 ([arquitetura.md](arquitetura.md) e ADRs 001 a 003) e o que o código de `infra/` cria.

Nenhuma **decisão** dos ADRs 001, 002 e 003 mudou. As diferenças são detalhes de implementação ou exigências da Entrega 2, por isso nenhum ADR foi marcado como "substituída". As decisões novas estão no [ADR-004](adr/004-estrategia-de-alta-disponibilidade.md) (alta disponibilidade, só proposta) e no [ADR-005](adr/005-estrategia-de-backup.md) (backup).

## Mudanças

**1. HTTPS na porta 443**
- Antes: só HTTP na porta 80.
- Agora: o Nginx atende HTTPS na 443 e a 80 só redireciona.
- Motivo: controle S3 da Entrega 2.

**2. Elastic IP no bastion e na web**
- Antes: IP público comum, que muda a cada boot.
- Agora: Elastic IP fixo.
- Motivo: o R6 pede IP estático, e o IP da web precisa ir no certificado HTTPS. O custo é o mesmo.

**3. Nginx da `vm-web`**
- Antes: o contêiner do frontend fazia tudo.
- Agora: o Nginx do sistema cuida do HTTPS e do `/api`; o contêiner só entrega a página (em `127.0.0.1:8081`).
- Motivo: gerar o certificado no boot sem mudar a imagem do frontend.

**4. PostgreSQL sem porta** (ADR-003, sem mudança de decisão)
- Antes: escutando em `localhost:5432`.
- Agora: nenhuma porta publicada; só a API alcança o banco, pela rede interna do Docker.
- Motivo: mais restrito que o previsto.

**5. Senhas no SSM Parameter Store**
- Antes: não detalhado.
- Agora: as senhas ficam no SSM como `SecureString`.
- Motivo: controle S4.

**6. Role na `vm-app`** (ADR-001, sem mudança de decisão)
- Antes: nenhuma VM tinha role.
- Agora: a `vm-app` tem uma role que só lê as 2 senhas e só grava backup.
- Motivo: S4, S5 e o backup. O acesso de administrador continua sendo SSH pelo bastion.

**7. Recursos novos**
- Bucket S3 de backup, endpoint do S3, VPC Flow Logs e o security group padrão sem regras.
- Motivo: backup (Parte D), achado do Trivy e economia de NAT.

**8. Docker do repositório do Ubuntu**
- Antes: repositório oficial do Docker.
- Agora: pacotes `docker.io` e `docker-compose-v2` do Ubuntu.
- Motivo: instalação mais simples no boot.

**9. AWS CLI na `vm-app`**
- Instalada por `snap`. Ela é necessária para ler as senhas e gravar o backup, e o Ubuntu 24.04 não tem mais o pacote no apt.

**10. Nome dos security groups**
- Antes: `sg-bastion`, `sg-web`, `sg-app`.
- Agora: `mecanica-sg-...`, porque a AWS não aceita nomes começando com `sg-`.

**11. Sub-rede pública sem IP automático**
- Só têm IP público os recursos que declaram um, o que evita IP público por acidente.

**12. IMDSv2 obrigatório nas 3 VMs**
- Protege a role da `vm-app` (ameaça 3 de [seguranca.md](seguranca.md)).

**13. Tag a mais**
- `GerenciadoPor = terraform`, para identificar no console o que o código criou.

**14. Nginx com `listen 443 ssl http2`**
- O primeiro teste falhou porque o Nginx do Ubuntu 24.04 não aceita `http2 on;`. Corrigido no template.

**15. Bastion sem instalar pacotes**
- O bastion não tem saída para a internet (matriz da Entrega 1), então não recebe atualizações no boot. Aceito porque ele é recriado a cada apresentação com a imagem mais nova do Ubuntu.

**16. apt com novas tentativas**
- No teste de 22/11 o servidor de pacotes do Ubuntu falhou por alguns segundos e a `vm-app` subiu sem Docker.
- Agora o apt tenta 10 vezes, só por IPv4. Testado de novo com sucesso ([evidência](evidencias/teste-final-2026-11-22.txt)).

**17. Diagrama atualizado**
- `docs/diagramas/arquitetura.png` agora mostra o que foi implantado: HTTPS, Elastic IPs, S3, endpoint, SSM, Flow Logs e o fluxo de backup. A versão original fica na tag `entrega-1`.

**18. `arquitetura.md` reescrito**
- O texto da Entrega 1 foi reorganizado sem tabelas e encurtado, para ficar mais fácil de ler. As decisões e a numeração das seções continuam as mesmas. O original fica na tag `entrega-1`.

## Issues do professor

Não há issues abertas no repositório. O convite enviado ao professor em 29/09/2026 expirou antes de ser aceito, então ele não conseguiu abrir issues. O repositório agora é público.

## Custos

- Previsão da Entrega 1 (cenário B): cerca de US$ 4,23 no período, com 40 h ligado.
- O custo real será registrado em `docs/custos/` depois da apresentação.
