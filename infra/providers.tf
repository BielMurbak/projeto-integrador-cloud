# Credenciais NÃO ficam aqui: vêm do perfil da AWS CLI (aws configure) ou das
# variáveis de ambiente AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY.
provider "aws" {
  region = var.region

  # R10: tags aplicadas a todos os recursos que suportam tags
  default_tags {
    tags = {
      Projeto       = var.project
      Grupo         = var.group
      Ambiente      = var.environment
      Responsavel   = var.owner
      GerenciadoPor = "terraform"
    }
  }
}
