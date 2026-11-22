# Projeto Integrador — Infraestrutura em Nuvem

Uniamérica Descomplica · Prof. Gildomiro Bairros

## Grupo

| Integrante | GitHub |
|---|---|
| Gabriel Murbak | @BielMurbak |
| Rafael Scarabelot | @RafaelScarabelot |
| Gabriel Wegher | @weghergabriel |

## Aplicação

Sistema de gestão de oficina mecânica: cadastro de mecânicos e de serviços (ordens de serviço) com login.

- `app/frontend` — SPA React (Vite) servida por Nginx
- `app/backend` — API REST Spring Boot (Java 17) com Spring Security
- Banco de dados — PostgreSQL 16

**Funcionalidade verificável:** entrar com o usuário `admin` e cadastrar um mecânico, que aparece na listagem.

## Estrutura do repositório

```
├── README.md                     # Este arquivo: como criar, instalar, demonstrar e destruir
├── IA.md                         # Declaração de uso de IA
├── app/
│   ├── backend/                  # API Spring Boot (histórico importado de mecanica-backend)
│   └── frontend/                 # SPA React (histórico importado de mecanica-frontend)
├── docs/
│   ├── arquitetura.md            # Entrega 1: seções 5.1 a 5.7, 5.9 e 5.10
│   ├── seguranca.md              # Entrega 2: S1 a S8, achados e ameaças (Parte B)
│   ├── alta-disponibilidade.md   # Entrega 2: H1 a H7 e custo (Parte C)
│   ├── backup.md                 # Entrega 2: B1 a B7 (Parte D)
│   ├── errata.md                 # Divergências entre a Entrega 1 e o implantado
│   ├── adr/                      # ADRs 001 a 005
│   ├── diagramas/                # arquitetura (implantada) e arquitetura-ha (proposta), .drawio + .png
│   ├── custos/                   # Estimativas: Entrega 1, proposta de HA, backup GFS 12 meses
│   └── evidencias/               # Relatórios do Trivy e do Gitleaks, prints das demonstrações
└── infra/                        # Terraform (Entrega 2)
    ├── versions.tf               # Versão do Terraform e do provider (fixadas)
    ├── providers.tf              # Provider AWS e tags padrão (sem credenciais)
    ├── variables.tf              # Todas as variáveis, com type e description
    ├── network.tf                # VPC, sub-redes, IGW, NAT, rotas, endpoint S3, Flow Logs
    ├── security.tf               # Security groups, segredos no SSM, role da vm-app
    ├── compute.tf                # Instâncias, chave SSH, Elastic IPs
    ├── backup.tf                 # Bucket de backup (política mínima)
    ├── outputs.tf                # IPs, URL e comandos de conexão
    ├── templates/                # cloud-init das três VMs e endurecimento do SSH
    ├── terraform.tfvars.example  # Exemplo de variáveis (sem dados sensíveis)
    └── .terraform.lock.hcl       # Versões exatas do provider
```

## ⚠️ Aviso de custos

Este ambiente **gera custo enquanto existe**, pago pelo grupo. Com tudo ligado, custa cerca de **US$ 0,11 por hora** (US$ 77,27/mês em operação contínua, ver `docs/arquitetura.md` 5.9). O NAT Gateway e os IPv4 públicos cobram por hora **mesmo sem tráfego**.

- O alerta de orçamento (AWS Budgets, US$ 5/mês) foi criado **antes** do primeiro `apply`.
- **Ao fim de toda sessão de trabalho, rode `terraform destroy`.** Nunca deixe o ambiente ligado de um dia para o outro.
- Depois do `destroy`, confira no console (EC2 → Instâncias, Volumes, Elastic IPs; VPC → NAT Gateways; S3) que não sobrou nada.
- Não apague o arquivo `infra/terraform.tfstate`: sem ele o Terraform não encontra o que criou.

## Pré-requisitos

| Ferramenta | Versão usada | Instalação (Windows) |
|---|---|---|
| Terraform | 1.17 (`>= 1.9, < 2.0`) | `winget install Hashicorp.Terraform` |
| AWS CLI | v2 | `winget install Amazon.AWSCLI` |
| Cliente SSH | OpenSSH | já vem no Windows 10/11 e no Git Bash |
| Trivy / Gitleaks (só para a análise) | 0.76 / 8.30 | `winget install AquaSecurity.Trivy Gitleaks.Gitleaks` |

Na conta AWS (feito uma vez, manualmente, como o enunciado permite):

1. MFA no usuário root.
2. Alerta de orçamento no AWS Budgets.
3. Usuário IAM `terraform-grupo` com access key; `aws configure` com a key, região `us-east-1` e saída `json`. Teste: `aws sts get-caller-identity` deve terminar em `user/terraform-grupo`.
4. Chave SSH do grupo: `ssh-keygen -t ed25519 -f ~/.ssh/chave-grupo`. A chave **privada** é passada aos integrantes por um meio privado e **nunca** entra no repositório.

## Configuração das variáveis

Dentro de `infra/`:

1. Copie o exemplo e preencha:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

   | Variável | O que colocar |
   |---|---|
   | `owner` | Nome de quem roda o `apply` (vai para a tag `Responsavel`) |
   | `ssh_allowed_cidrs` | IP público `/32` de cada integrante (descubra com `curl https://checkip.amazonaws.com`). `0.0.0.0/0` é recusado pela validação |
   | `ssh_public_key` | Conteúdo de `~/.ssh/chave-grupo.pub` |

   **Se o IP de um integrante mudar** (IP residencial dinâmico, risco 7 da Entrega 1), troque o valor em `ssh_allowed_cidrs` e rode `terraform apply`: o plano mostra só a troca da regra (`1 to add, 1 to destroy`). Aconteceu nos testes de 21/11 e 22/11, quando o SSH deu `Connection timed out` até a regra ser atualizada.

   As demais variáveis (região, zona, CIDRs, tipos de instância, IPs privados, imagens, retenção do backup) já têm o valor da Entrega 1 como padrão; ver `variables.tf`.

2. As **senhas** não ficam em arquivo versionado. Crie `infra/.env` (ignorado pelo Git):

   ```bash
   export TF_VAR_db_password='<senha do banco, 12+ caracteres>'
   export TF_VAR_admin_password='<senha do admin, 8+ caracteres>'
   ```

   e carregue antes de qualquer `plan`, `apply` ou `destroy`:

   ```bash
   source .env
   ```

   No PowerShell, o equivalente é `$env:TF_VAR_db_password = '...'` e `$env:TF_VAR_admin_password = '...'`.

## Criar o ambiente (apply)

```bash
cd infra
source .env
terraform init
terraform plan
terraform apply
```

O `apply` cria 49 recursos em ~2 a 3 minutos (o NAT Gateway leva ~1,5 min). Ao final, mostra:

| Output | Uso |
|---|---|
| `app_url` | URL da aplicação (`https://<IP da web>`) |
| `bastion_public_ip` / `ssh_bastion` | Entrar no bastion |
| `ssh_app_via_bastion` / `ssh_web_via_bastion` | Entrar nas outras VMs passando pelo bastion |
| `nat_public_ip` | IP de saída da `vm-app` (deve bater com `curl ifconfig.me` nela) |
| `private_ips` | IPs privados das três VMs |
| `backup_bucket` | Bucket das cópias do banco |

## Instalação da aplicação

A instalação é **automática**: cada VM executa o seu cloud-init (`infra/templates/`) no primeiro boot. **Espere de 5 a 8 minutos** depois do `apply`. Para acompanhar:

```bash
eval "$(ssh-agent -s)" && ssh-add ~/.ssh/chave-grupo
ssh -J ubuntu@<IP_BASTION> ubuntu@10.20.10.10 'cloud-init status --wait'
ssh -J ubuntu@<IP_BASTION> ubuntu@10.20.1.20 'cloud-init status --wait'
```

`status: done` significa que terminou. Se aparecer `status: error`, veja `sudo tail -50 /var/log/cloud-init-output.log` na VM.

Se o erro for `Failed to fetch ... archive.ubuntu.com` (o espelho do Ubuntu falhou durante o boot), recrie só aquela VM: `terraform apply -replace=aws_instance.app` (ou `aws_instance.web`). O cloud-init já configura o apt para tentar 10 vezes (`/etc/apt/apt.conf.d/80-retries`), então isso deve ser raro.

O que o cloud-init faz, na ordem (para repetir à mão, execute os mesmos comandos na VM via SSH):

**`vm-app` (10.20.10.10)** — `infra/templates/cloud-init-app.yaml`

1. Grava `/etc/ssh/sshd_config.d/00-hardening.conf` (sem senha, sem root) e reinicia o SSH, e `/etc/apt/apt.conf.d/80-retries` (apt tenta 10 vezes, só IPv4).
2. `apt-get update && apt-get install -y docker.io docker-compose-v2 cron`
3. `snap install aws-cli --classic`
4. `systemctl enable --now docker`
5. Grava `/opt/mecanica/docker-compose.yml` (PostgreSQL 16 sem porta publicada + API na 8080).
6. Executa `/opt/mecanica/start.sh`: lê as senhas no SSM Parameter Store com a role da instância, grava `/opt/mecanica/.env` (permissão 600) e roda `docker compose -f /opt/mecanica/docker-compose.yml up -d`.
7. Grava `/usr/local/bin/backup-db.sh` e o cron `/etc/cron.d/backup-db` (diário às 06h UTC e 10 min após o boot).

**`vm-web` (10.20.1.20)** — `infra/templates/cloud-init-web.yaml`

1. Endurecimento do SSH e configuração do apt (iguais).
2. `apt-get update && apt-get install -y nginx docker.io openssl`
3. Gera o certificado autoassinado com o Elastic IP no SAN: `openssl req -x509 -newkey rsa:2048 -nodes -days 30 -keyout /etc/nginx/tls/mecanica.key -out /etc/nginx/tls/mecanica.crt -subj "/CN=<IP_WEB>" -addext "subjectAltName=IP:<IP_WEB>"`
4. Grava `/etc/nginx/sites-available/mecanica` (80 → 301 para HTTPS; 443 com TLS; `/api/` → `10.20.10.10:8080`; `/` → frontend), remove o site `default` e ativa o novo.
5. `docker run -d --name frontend --restart unless-stopped -p 127.0.0.1:8081:80 ghcr.io/bielmurbak/mecanica-frontend:latest`
6. `nginx -t && systemctl reload nginx`

**`vm-bastion`** — só o endurecimento do SSH (não tem saída para a internet).

**Usar a aplicação:** abra o `app_url`, aceite o aviso do certificado autoassinado e entre com `admin` e a senha de `TF_VAR_admin_password`.

## Destruir o ambiente (destroy)

```bash
cd infra
source .env
terraform destroy
terraform state list   # deve voltar vazio
```

O bucket de backup tem `force_destroy`, então é apagado mesmo com cópias dentro. Se o `destroy` falhar no meio (por exemplo, esperando o NAT), rode de novo.

## Demonstrações (apresentação de 23/11)

| Demo | Conteúdo | Quem conduz |
|---|---|---|
| D1 | Estado consistente: `terraform plan` sem alterações e `terraform output` | Gabriel Murbak |
| D2 | Aplicação por HTTPS: abrir o `app_url`, login, cadastrar um mecânico; `curl -I http://<IP_WEB>` mostra o 301 | Gabriel Murbak |
| D3 | Acesso administrativo: SSH no bastion, `ssh -J` até a `vm-app`, recusa de senha (S1) | Rafael Scarabelot |
| D4 | NAT e isolamento: `curl ifconfig.me` na `vm-app` = `nat_public_ip`; `vm-app` sem IP público; SSH só do CIDR autorizado | Rafael Scarabelot |
| D5 | Segurança: senhas fora do código (S4), relatório do Trivy com um achado corrigido e um aceito (S7) | Gabriel Wegher |
| D6 | Backup: bucket, regra de 1 dia, criptografia e cópia existente; custo anual da GFS | Gabriel Wegher |
| D7 | Alta disponibilidade: diagrama `arquitetura-ha.png` e análise de custo | Gabriel Wegher |

Comandos de apoio (com os valores do `terraform output`):

```bash
# D1
terraform plan -detailed-exitcode     # código 0 = nada a alterar
terraform output

# D2
curl -I http://<IP_WEB>               # 301 para https://
curl -vk https://<IP_WEB>/health      # TLS 1.3 e "ok"

# D3
eval "$(ssh-agent -s)" && ssh-add ~/.ssh/chave-grupo
ssh ubuntu@<IP_BASTION>
ssh -J ubuntu@<IP_BASTION> ubuntu@10.20.10.10
ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password ubuntu@<IP_BASTION>   # Permission denied (publickey)

# D4 (dentro da vm-app)
curl -s https://ifconfig.me            # igual ao nat_public_ip
ip -4 -br addr                         # só 10.20.10.10, sem IP público

# D5
grep -rn "password" infra/*.tf         # só variáveis sensitive, nenhum valor
trivy config infra/                    # AWS-0178 corrigido; AWS-0104/0132 aceitos (docs/seguranca.md)

# D6
aws s3 ls s3://<BUCKET>/diario/
aws s3api get-bucket-lifecycle-configuration --bucket <BUCKET>
aws s3api head-object --bucket <BUCKET> --key diario/<ARQUIVO>   # ServerSideEncryption: AES256
# dentro da vm-app: a role não consegue apagar
aws s3 rm s3://<BUCKET>/diario/<ARQUIVO>   # AccessDenied
```

## Documentação

- Evidências: [`docs/evidencias/`](docs/evidencias/) — relatórios do Trivy e do Gitleaks e a saída completa dos testes finais (D1 a D6) de 21/11 e 22/11/2026

- Entrega 1: [`docs/arquitetura.md`](docs/arquitetura.md), [ADRs 001 a 003](docs/adr/)
- Entrega 2: [`docs/seguranca.md`](docs/seguranca.md), [`docs/alta-disponibilidade.md`](docs/alta-disponibilidade.md), [`docs/backup.md`](docs/backup.md), [`docs/errata.md`](docs/errata.md), [ADR-004](docs/adr/004-estrategia-de-alta-disponibilidade.md), [ADR-005](docs/adr/005-estrategia-de-backup.md)
- Uso de IA: [`IA.md`](IA.md)
