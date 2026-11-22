# Parte D: política mínima configurada (geração Son do GFS, opção A do enunciado).
# A vm-app faz pg_dump diário e grava em s3://<bucket>/diario/. As cópias
# expiram em var.backup_retention_days dias.

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "backup" {
  bucket = "${var.group}-backup-${data.aws_caller_identity.current.account_id}"

  # Permite que o terraform destroy apague o bucket mesmo com cópias dentro
  # (seção 11 do enunciado: não podem restar buckets após a apresentação)
  force_destroy = true

  tags = { Name = "backup-mecanica" }
}

resource "aws_s3_bucket_public_access_block" "backup" {
  bucket                  = aws_s3_bucket.backup.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "backup" {
  bucket = aws_s3_bucket.backup.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# S6: criptografia em repouso declarada explicitamente (SSE-S3, AES-256)
resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Versionamento: se alguém sobrescrever uma cópia, a anterior continua
# disponível como versão não corrente até expirar
resource "aws_s3_bucket_versioning" "backup" {
  bucket = aws_s3_bucket.backup.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Retenção curta: cópias de diario/ expiram em backup_retention_days dias e
# versões antigas em 1 dia. Nada fica mais de 2 dias.
resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    id     = "son-diario"
    status = "Enabled"

    filter {
      prefix = "diario/"
    }

    expiration {
      days = var.backup_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  rule {
    id     = "flow-logs"
    status = "Enabled"

    filter {
      prefix = "flow-logs/"
    }

    expiration {
      days = 1
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }

  rule {
    id     = "limpa-marcadores-de-exclusao"
    status = "Enabled"

    filter {}

    expiration {
      expired_object_delete_marker = true
    }
  }

  depends_on = [aws_s3_bucket_versioning.backup]
}

# Só aceita conexões HTTPS. Libera também a entrega dos Flow Logs da VPC
# (serviço delivery.logs), restrita ao prefixo flow-logs/ e a esta conta.
data "aws_iam_policy_document" "backup_bucket" {
  statement {
    sid       = "EntregaFlowLogs"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.backup.arn}/flow-logs/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid       = "VerificaAclFlowLogs"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.backup.arn]
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid     = "NegaTransporteSemTLS"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.backup.arn,
      "${aws_s3_bucket.backup.arn}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "backup" {
  bucket = aws_s3_bucket.backup.id
  policy = data.aws_iam_policy_document.backup_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.backup]
}
