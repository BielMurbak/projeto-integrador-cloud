# R11: IP público do recurso de acesso, IP público do NAT, IPs privados e URL da aplicação

output "bastion_public_ip" {
  description = "IP público (Elastic IP) do bastion."
  value       = aws_eip.bastion.public_ip
}

output "web_public_ip" {
  description = "IP público (Elastic IP) da VM web, que expõe a aplicação."
  value       = aws_eip.web.public_ip
}

output "nat_public_ip" {
  description = "IP público do NAT Gateway. Deve ser igual ao 'curl ifconfig.me' feito na vm-app."
  value       = aws_eip.nat.public_ip
}

output "private_ips" {
  description = "IPs privados das instâncias."
  value = {
    bastion = aws_instance.bastion.private_ip
    web     = aws_instance.web.private_ip
    app     = aws_instance.app.private_ip
  }
}

output "app_url" {
  description = "URL da aplicação (HTTPS com certificado autoassinado)."
  value       = "https://${aws_eip.web.public_ip}"
}

output "ssh_bastion" {
  description = "Comando para entrar no bastion."
  value       = "ssh ${var.ssh_user}@${aws_eip.bastion.public_ip}"
}

output "ssh_app_via_bastion" {
  description = "Comando para entrar na vm-app passando pelo bastion (ProxyJump)."
  value       = "ssh -J ${var.ssh_user}@${aws_eip.bastion.public_ip} ${var.ssh_user}@${aws_instance.app.private_ip}"
}

output "ssh_web_via_bastion" {
  description = "Comando para entrar na vm-web passando pelo bastion (ProxyJump)."
  value       = "ssh -J ${var.ssh_user}@${aws_eip.bastion.public_ip} ${var.ssh_user}@${aws_instance.web.private_ip}"
}

output "backup_bucket" {
  description = "Bucket S3 das cópias diárias do banco (prefixo diario/)."
  value       = aws_s3_bucket.backup.bucket
}
