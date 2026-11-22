# Segurança (Parte B)

Controles S1 a S8, achados das ferramentas de análise e principais ameaças.
Tudo foi verificado nos testes de 21/11 e 22/11/2026: [teste 21/11](evidencias/teste-final-2026-11-21.txt), [teste 22/11](evidencias/teste-final-2026-11-22.txt).

## 1. Controles

### S1: SSH endurecido
- Sem login por senha e sem login como root, em todas as VMs (`MaxAuthTries 3`).
- Arquivo `00-hardening.conf`, gravado pelo cloud-init (`infra/templates/sshd-hardening.conf`).
- **Como mostrar:** `ssh -o PubkeyAuthentication=no ubuntu@<IP_BASTION>` responde `Permission denied (publickey)`.

### S2: saída restrita
- A regra padrão "libera tudo" foi removida. Cada security group só libera as saídas necessárias:
  - **bastion:** só SSH para a web e para a app. Não tem saída para a internet.
  - **web:** 8080 para a app e 80/443 para baixar pacotes.
  - **app:** 80/443 pelo NAT ou pelo endpoint do S3.
- O PostgreSQL não publica nenhuma porta.
- Código em `infra/security.tf`.

### S3: HTTPS
- O Nginx da `vm-web` atende na 443 com TLS 1.2/1.3 e certificado autoassinado, com o IP da web no certificado.
- A porta 80 só redireciona para o HTTPS (`301`).
- **Como mostrar:** `curl -I http://<IP_WEB>` responde `301`; o navegador abre `https://<IP_WEB>`.

### S4: segredos fora do código
- As senhas do banco e do admin entram por variável de ambiente (`TF_VAR_...`, no arquivo `infra/.env`, que não vai para o Git).
- O Terraform guarda as duas no **SSM Parameter Store** como `SecureString`.
- A `vm-app` lê as senhas no boot com a própria role e grava um `.env` que só o root lê (permissão 600).
- As senhas não aparecem no código, no `user_data` nem no `terraform output`.

### S5: menor privilégio
- Só a `vm-app` tem role (`mecanica-vm-app-role`). Ela pode apenas:
  - ler os 2 parâmetros de senha;
  - gravar backup em `diario/`.
- Ela **não pode** listar, ler nem apagar backups.
- Nenhuma chave de acesso fica gravada nas VMs. IMDSv2 é obrigatório nas três.
- **Como mostrar:** na `vm-app`, `aws s3 ls s3://<bucket>/` responde `AccessDenied`.

### S6: criptografia
- Discos das 3 VMs criptografados (`encrypted = true`).
- Bucket de backup com criptografia AES256 declarada no código, e cada cópia também é enviada com `--sse AES256`.
- O bucket recusa qualquer acesso sem TLS.
- **Como mostrar:** `aws ec2 describe-volumes` mostra `Encrypted: true`.

### S7: análise automatizada
- **Trivy** analisa o código Terraform; **Gitleaks** procura segredos em todo o histórico do Git.
- Relatórios em `docs/evidencias/`. O tratamento dos achados está na seção 2.

### S8: proteção da conta
- MFA ativo no usuário root: [print](evidencias/mfa-conta.png), com o número da conta coberto.
- Alerta de orçamento de US$ 5/mês (AWS Budgets).
- O Terraform usa um usuário próprio (`terraform-grupo`), nunca o root.

### Outros controles
- O security group padrão da VPC fica sem nenhuma regra.
- As sub-redes não dão IP público automático: só têm IP público o bastion, a web e o NAT.
- O bucket de backup é privado e versionado.
- VPC Flow Logs gravam o tráfego da rede no bucket.
- O backup vai para o S3 pelo endpoint de gateway, sem passar pela internet.

## 2. Achados do Trivy e do Gitleaks

**Gitleaks:** nenhum segredo encontrado no histórico ([relatório](evidencias/gitleaks.txt)).

**Trivy** ([antes da correção](evidencias/trivy-infra-antes.txt) e [versão entregue](evidencias/trivy-infra.txt)):

- **AWS-0178: VPC sem Flow Logs (média). Corrigido.**
  Recurso: `aws_vpc.main`.
  Criamos o Flow Logs gravando no bucket, com expiração de 1 dia. O achado some do relatório final.

- **AWS-0104: saída liberada para qualquer IP (crítica, 4 regras). Aceito.**
  Recursos: `web_http_out`, `web_https_out`, `app_http_out`, `app_https_out` (em `infra/security.tf`).
  As VMs precisam baixar pacotes do Ubuntu e imagens do GitHub, e esses serviços mudam de IP o tempo todo. Por isso a saída fica limitada só às portas 80 e 443, não a IPs. A `vm-app` só sai pelo NAT, que não aceita conexões de fora.

- **AWS-0132: bucket sem chave própria no KMS (alta). Aceito.**
  Recurso: `aws_s3_bucket_server_side_encryption_configuration.backup`.
  O bucket já é criptografado (AES256). Uma chave própria custaria US$ 1/mês e só controlaria quem pode decifrar, o que a política do bucket e a role já garantem.

- **AWS-0089: bucket sem log de acesso (baixa). Aceito.**
  Recurso: `aws_s3_bucket.backup`.
  Exigiria um segundo bucket só para os logs. O ambiente vive poucas horas, e as ações de gerenciamento já ficam no CloudTrail.

Nenhum achado foi escondido com `#trivy:ignore`: todos continuam no relatório.

## 3. Ameaças

**1. Ataque de força bruta no SSH do bastion**
- Ativo: `vm-bastion` e, a partir dele, as outras VMs.
- Proteção: só chave, sem root, porta 22 aberta só para o IP do integrante (a variável recusa `0.0.0.0/0`).
- Risco que sobra: a chave SSH é uma só para os três integrantes. Se o notebook de um for invadido, a chave precisa ser trocada para todos.

**2. Invasão da `vm-web` (exposta à internet) para chegar à app e ao banco**
- Ativo: `vm-web`, `vm-app` e os dados do PostgreSQL.
- Proteção: a web só fala com a app na porta 8080, sem SSH. O banco não tem porta publicada. A web não tem role.
- Risco que sobra: o invasor consegue chamar a API como se fosse o Nginx.

**3. Invasão da `vm-app` para roubar as credenciais da AWS**
- Ativo: senhas da aplicação, backups e a conta AWS.
- Proteção: IMDSv2 obrigatório; a role só lê as 2 senhas e só grava em `diario/`.
- Risco que sobra: o invasor lê as senhas da aplicação, mas **não consegue apagar nem ler os backups**.

**4. Perda dos dados (erro, `DROP TABLE`, ransomware)**
- Ativo: banco PostgreSQL da `vm-app`.
- Proteção: `pg_dump` diário para o S3, fora da VM, e a VM não pode apagar as cópias.
- Risco que sobra: na política mínima a cópia dura só 1 dia. Um erro descoberto depois disso não tem volta; o plano GFS ([backup.md](backup.md)) resolve.

**5. Vazamento de credenciais (repositório público ou notebook de um integrante)**
- Ativo: senhas da aplicação, chave SSH do grupo e a chave da AWS do `terraform-grupo`.
- Proteção: `.gitignore` cobre state, tfvars, `.env` e chaves. O Gitleaks não achou nada. O root tem MFA.
- Risco que sobra: o `terraform.tfstate` guarda as senhas em texto puro no notebook de quem roda o `apply`. A chave do `terraform-grupo` dá acesso de administrador sem MFA. Ela será desativada ao fim do trabalho.

## 4. Responsabilidade compartilhada

- **AWS:** hardware, rede física, durabilidade do S3 e a criptografia em si.
- **Grupo:** ligar a criptografia no código, configurar o SSH e o sistema operacional, regras de rede, roles mínimas, MFA, backup e retenção.
