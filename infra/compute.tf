# Ubuntu Server 24.04 LTS oficial da Canonical
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# R8: a chave pública é informada por variável; a privada fica só com os integrantes
resource "aws_key_pair" "grupo" {
  key_name   = "${var.group}-chave-grupo"
  public_key = var.ssh_public_key
}

# R6: IPs públicos estáticos (Elastic IP) para o bastion e para a web.
# Criados antes das instâncias para que o IP entre no certificado HTTPS.
resource "aws_eip" "bastion" {
  domain = "vpc"
  tags   = { Name = "eip-bastion" }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_eip" "web" {
  domain = "vpc"
  tags   = { Name = "eip-web" }

  depends_on = [aws_internet_gateway.main]
}

locals {
  # Endurecimento do SSH (S1), comum às três instâncias
  ssh_hardening = file("${path.module}/templates/sshd-hardening.conf")
}

# ---------------------------------------------------------------------------
# vm-bastion (pub-a)
# ---------------------------------------------------------------------------
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.bastion_instance_type
  subnet_id              = aws_subnet.public.id
  private_ip             = var.bastion_private_ip
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name               = aws_key_pair.grupo.key_name

  user_data = templatefile("${path.module}/templates/cloud-init-bastion.yaml", {
    ssh_hardening = local.ssh_hardening
  })
  user_data_replace_on_change = true

  credit_specification {
    cpu_credits = "standard"
  }

  # IMDSv2 obrigatório
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  # S6: disco criptografado
  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.bastion_disk_gb
    encrypted             = true
    delete_on_termination = true
    tags                  = { Name = "disk-bastion" }
  }

  tags = { Name = "vm-bastion", Funcao = "bastion" }
}

resource "aws_eip_association" "bastion" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion.id
}

# ---------------------------------------------------------------------------
# vm-app (priv-a, sem IP público): API Spring Boot + PostgreSQL
# ---------------------------------------------------------------------------
resource "aws_instance" "app" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.app_instance_type
  subnet_id                   = aws_subnet.private.id
  private_ip                  = var.app_private_ip
  associate_public_ip_address = false # R5
  vpc_security_group_ids      = [aws_security_group.app.id]
  key_name                    = aws_key_pair.grupo.key_name
  iam_instance_profile        = aws_iam_instance_profile.app.name

  user_data = templatefile("${path.module}/templates/cloud-init-app.yaml", {
    ssh_hardening        = local.ssh_hardening
    region               = var.region
    backend_image        = var.backend_image
    db_password_param    = aws_ssm_parameter.db_password.name
    admin_password_param = aws_ssm_parameter.admin_password.name
    backup_bucket        = aws_s3_bucket.backup.bucket
    backup_cron          = var.backup_cron
    cors_origin          = "https://${aws_eip.web.public_ip}"
  })
  user_data_replace_on_change = true

  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.app_disk_gb
    encrypted             = true
    delete_on_termination = true
    tags                  = { Name = "disk-app" }
  }

  tags = { Name = "vm-app", Funcao = "aplicacao" }

  # A vm-app precisa da rota pelo NAT para instalar pacotes no primeiro boot
  depends_on = [aws_route_table_association.private, aws_nat_gateway.main]
}

# ---------------------------------------------------------------------------
# vm-web (pub-a): Nginx com HTTPS na frente do frontend e do /api
# ---------------------------------------------------------------------------
resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.web_instance_type
  subnet_id              = aws_subnet.public.id
  private_ip             = var.web_private_ip
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.grupo.key_name

  user_data = templatefile("${path.module}/templates/cloud-init-web.yaml", {
    ssh_hardening  = local.ssh_hardening
    frontend_image = var.frontend_image
    app_private_ip = var.app_private_ip
    public_ip      = aws_eip.web.public_ip
  })
  user_data_replace_on_change = true

  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.web_disk_gb
    encrypted             = true
    delete_on_termination = true
    tags                  = { Name = "disk-web" }
  }

  tags = { Name = "vm-web", Funcao = "web" }
}

resource "aws_eip_association" "web" {
  instance_id   = aws_instance.web.id
  allocation_id = aws_eip.web.id
}
