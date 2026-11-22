# ---------------------------------------------------------------------------
# Identificação e tags (R10)
# ---------------------------------------------------------------------------
variable "project" {
  type        = string
  description = "Nome do projeto. Usado como prefixo dos recursos e na tag Projeto."
  default     = "projeto-integrador-cloud"
}

variable "group" {
  type        = string
  description = "Identificação do grupo (tag Grupo)."
  default     = "mecanica"
}

variable "environment" {
  type        = string
  description = "Nome do ambiente (tag Ambiente)."
  default     = "entrega2"
}

variable "owner" {
  type        = string
  description = "Integrante que executou o apply (tag Responsavel)."
}

# ---------------------------------------------------------------------------
# Região e rede (R1 a R4)
# ---------------------------------------------------------------------------
variable "region" {
  type        = string
  description = "Região da AWS onde a infraestrutura é criada."
  default     = "us-east-1"
}

variable "availability_zone" {
  type        = string
  description = "Zona de disponibilidade das sub-redes (arquitetura implantada usa uma única zona)."
  default     = "us-east-1a"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR da VPC, conforme o plano de endereçamento da Entrega 1 (seção 5.3)."
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr precisa ser um bloco CIDR IPv4 válido."
  }
}

variable "public_subnet_cidr" {
  type        = string
  description = "CIDR da sub-rede pública pub-a (bastion, web e NAT Gateway)."
  default     = "10.20.1.0/24"
}

variable "private_subnet_cidr" {
  type        = string
  description = "CIDR da sub-rede privada priv-a (API + PostgreSQL)."
  default     = "10.20.10.0/24"
}

# ---------------------------------------------------------------------------
# Acesso administrativo (R7, R8)
# ---------------------------------------------------------------------------
variable "ssh_allowed_cidrs" {
  type        = list(string)
  description = "CIDRs autorizados a acessar o bastion por SSH (IP /32 de cada integrante)."

  validation {
    condition     = length(var.ssh_allowed_cidrs) > 0 && alltrue([for c in var.ssh_allowed_cidrs : can(cidrhost(c, 0)) && c != "0.0.0.0/0"])
    error_message = "Informe ao menos um CIDR válido. 0.0.0.0/0 não é aceito para SSH."
  }
}

variable "ssh_public_key" {
  type        = string
  description = "Conteúdo da chave pública SSH do grupo (ssh-ed25519 ...). A chave privada nunca entra no repositório."
}

variable "ssh_user" {
  type        = string
  description = "Usuário padrão da imagem (Ubuntu). Usado só nos outputs de conexão."
  default     = "ubuntu"
}

# ---------------------------------------------------------------------------
# Instâncias (R9) e IPs privados fixos (seção 5.3 da Entrega 1)
# ---------------------------------------------------------------------------
variable "bastion_instance_type" {
  type        = string
  description = "Tipo da instância bastion (família T3)."
  default     = "t3.micro"
}

variable "web_instance_type" {
  type        = string
  description = "Tipo da instância web (Nginx + frontend)."
  default     = "t3.micro"
}

variable "app_instance_type" {
  type        = string
  description = "Tipo da instância da aplicação (API + PostgreSQL)."
  default     = "t3.small"
}

variable "bastion_disk_gb" {
  type        = number
  description = "Tamanho do disco gp3 do bastion, em GiB."
  default     = 8
}

variable "web_disk_gb" {
  type        = number
  description = "Tamanho do disco gp3 da VM web, em GiB."
  default     = 8
}

variable "app_disk_gb" {
  type        = number
  description = "Tamanho do disco gp3 da VM da aplicação, em GiB (imagens Docker + dados do banco)."
  default     = 20
}

variable "bastion_private_ip" {
  type        = string
  description = "IP privado fixo do bastion na sub-rede pública."
  default     = "10.20.1.10"
}

variable "web_private_ip" {
  type        = string
  description = "IP privado fixo da VM web na sub-rede pública."
  default     = "10.20.1.20"
}

variable "app_private_ip" {
  type        = string
  description = "IP privado fixo da VM da aplicação na sub-rede privada. O Nginx aponta para ele."
  default     = "10.20.10.10"
}

# ---------------------------------------------------------------------------
# Aplicação (R12) e segredos (S4)
# ---------------------------------------------------------------------------
variable "backend_image" {
  type        = string
  description = "Imagem Docker da API Spring Boot."
  default     = "ghcr.io/bielmurbak/mecanica-backend:latest"
}

variable "frontend_image" {
  type        = string
  description = "Imagem Docker do frontend React (arquivos estáticos servidos por Nginx)."
  default     = "ghcr.io/bielmurbak/mecanica-frontend:latest"
}

variable "db_password" {
  type        = string
  description = "Senha do PostgreSQL. Informar por TF_VAR_db_password; vai para o SSM Parameter Store como SecureString."
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 12
    error_message = "A senha do banco precisa ter pelo menos 12 caracteres."
  }
}

variable "admin_password" {
  type        = string
  description = "Senha do usuário admin da aplicação. Informar por TF_VAR_admin_password; vai para o SSM Parameter Store."
  sensitive   = true

  validation {
    condition     = length(var.admin_password) >= 8
    error_message = "A senha do admin precisa ter pelo menos 8 caracteres."
  }
}

# ---------------------------------------------------------------------------
# Backup (Parte D, política mínima)
# ---------------------------------------------------------------------------
variable "backup_retention_days" {
  type        = number
  description = "Dias até a expiração das cópias diárias no bucket (política mínima: no máximo 2)."
  default     = 1

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 2
    error_message = "A política mínima exige retenção de 1 ou 2 dias."
  }
}

variable "backup_cron" {
  type        = string
  description = "Agenda (formato cron, horário UTC) do pg_dump diário na VM da aplicação."
  default     = "0 6 * * *"
}
