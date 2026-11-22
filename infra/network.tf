# R1: VPC com o CIDR da Entrega 1
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "vpc-mecanica" }
}

# Fecha o security group padrão da VPC (nenhuma regra): nada deve usá-lo
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "sg-default-fechado" }
}

# R2: sub-rede pública e sub-rede privada
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false # IPs públicos só via Elastic IP, de forma explícita

  tags = { Name = "pub-a", Tipo = "publica" }
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = { Name = "priv-a", Tipo = "privada" }
}

# R3: saída para a internet da sub-rede pública
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "igw-mecanica" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "rt-publica" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# R4: NAT gerenciado com IP público, rota padrão da privada apontando para ele
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = { Name = "eip-nat" }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = { Name = "nat-mecanica" }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = { Name = "rt-privada" }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Registro do tráfego da VPC (achado AWS-0178 do Trivy, corrigido). Grava no
# bucket de backup, prefixo flow-logs/, e expira em 1 dia: custo de centavos.
resource "aws_flow_log" "vpc" {
  vpc_id                   = aws_vpc.main.id
  traffic_type             = "ALL"
  log_destination_type     = "s3"
  log_destination          = "${aws_s3_bucket.backup.arn}/flow-logs/"
  max_aggregation_interval = 600

  tags = { Name = "flowlog-vpc-mecanica" }

  depends_on = [aws_s3_bucket_policy.backup]
}

# Endpoint de gateway do S3 (gratuito): o backup da vm-app vai direto ao bucket
# pela rede da AWS, sem passar pelo NAT (que cobra por GB processado)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = { Name = "vpce-s3" }
}
