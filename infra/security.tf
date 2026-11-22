# Grupos de segurança conforme a matriz da seção 5.5 da Entrega 1 (R7),
# com HTTPS na web (S3) e saída restrita ao necessário (S2).
# O aws_security_group criado pelo Terraform remove a regra de saída padrão
# "tudo liberado": só existe a saída declarada abaixo.

resource "aws_security_group" "bastion" {
  name        = "${var.group}-sg-bastion"
  description = "Bastion: SSH de entrada apenas dos CIDRs autorizados"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "sg-bastion" }
}

resource "aws_security_group" "web" {
  name        = "${var.group}-sg-web"
  description = "VM web: HTTP/HTTPS publico, SSH apenas via bastion"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "sg-web" }
}

resource "aws_security_group" "app" {
  name        = "${var.group}-sg-app"
  description = "VM da aplicacao: API apenas para a web, SSH apenas via bastion"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "sg-app" }
}

# ---------------------------------------------------------------------------
# sg-bastion
# ---------------------------------------------------------------------------
resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  for_each = toset(var.ssh_allowed_cidrs)

  security_group_id = aws_security_group.bastion.id
  description       = "SSH dos integrantes (CIDR autorizado)"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "bastion_to_web_ssh" {
  security_group_id            = aws_security_group.bastion.id
  description                  = "Salto SSH para a VM web"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.web.id
}

resource "aws_vpc_security_group_egress_rule" "bastion_to_app_ssh" {
  security_group_id            = aws_security_group.bastion.id
  description                  = "Salto SSH para a VM da aplicacao"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.app.id
}

# ---------------------------------------------------------------------------
# sg-web
# ---------------------------------------------------------------------------
resource "aws_vpc_security_group_ingress_rule" "web_http" {
  security_group_id = aws_security_group.web.id
  description       = "HTTP publico (apenas redireciona para HTTPS)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "web_https" {
  security_group_id = aws_security_group.web.id
  description       = "HTTPS publico (usuarios finais)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "web_ssh_from_bastion" {
  security_group_id            = aws_security_group.web.id
  description                  = "SSH apenas a partir do bastion"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_egress_rule" "web_to_app_api" {
  security_group_id            = aws_security_group.web.id
  description                  = "Nginx repassa /api para o backend"
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_egress_rule" "web_https_out" {
  security_group_id = aws_security_group.web.id
  description       = "Pacotes e imagens Docker (HTTPS)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "web_http_out" {
  security_group_id = aws_security_group.web.id
  description       = "Repositorios apt do Ubuntu (HTTP)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------------------------------------------------------------------
# sg-app
# ---------------------------------------------------------------------------
resource "aws_vpc_security_group_ingress_rule" "app_api_from_web" {
  security_group_id            = aws_security_group.app.id
  description                  = "API aceita chamadas apenas do Nginx"
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.web.id
}

resource "aws_vpc_security_group_ingress_rule" "app_ssh_from_bastion" {
  security_group_id            = aws_security_group.app.id
  description                  = "SSH apenas a partir do bastion"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_egress_rule" "app_https_out" {
  security_group_id = aws_security_group.app.id
  description       = "Imagens Docker, SSM e S3 (HTTPS), via NAT ou endpoint"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "app_http_out" {
  security_group_id = aws_security_group.app.id
  description       = "Repositorios apt do Ubuntu (HTTP) via NAT"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------------------------------------------------------------------
# S4: segredos da aplicação no SSM Parameter Store (SecureString, nível
# Standard, sem custo). A vm-app lê com a própria role (S5); os valores não
# aparecem no user_data nem no código.
# ---------------------------------------------------------------------------
resource "aws_ssm_parameter" "db_password" {
  name        = "/${var.project}/db_password"
  description = "Senha do PostgreSQL da aplicacao"
  type        = "SecureString"
  value       = var.db_password
}

resource "aws_ssm_parameter" "admin_password" {
  name        = "/${var.project}/admin_password"
  description = "Senha do usuario admin da aplicacao"
  type        = "SecureString"
  value       = var.admin_password
}

# ---------------------------------------------------------------------------
# S5: identidade da vm-app com o mínimo necessário
#   - ler apenas os dois parâmetros acima
#   - gravar (PutObject) apenas no prefixo diario/ do bucket de backup
#   Sem permissão de leitura, listagem ou exclusão no bucket: quem invadir a
#   instância não consegue apagar nem baixar os backups.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${var.group}-vm-app-role"
  description        = "Identidade da vm-app: le os segredos da app e grava backups"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

data "aws_iam_policy_document" "app" {
  statement {
    sid       = "LerSegredosDaAplicacao"
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.db_password.arn, aws_ssm_parameter.admin_password.arn]
  }

  statement {
    sid       = "DecifrarComChaveDoSSM"
    actions   = ["kms:Decrypt"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.${var.region}.amazonaws.com"]
    }
  }

  statement {
    sid       = "GravarBackupDiario"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.backup.arn}/diario/*"]
  }
}

resource "aws_iam_role_policy" "app" {
  name   = "${var.group}-vm-app-policy"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app.json
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.group}-vm-app-profile"
  role = aws_iam_role.app.name
}
