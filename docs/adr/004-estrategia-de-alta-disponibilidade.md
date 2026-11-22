# ADR-004: Estratégia de alta disponibilidade (proposta)

**Status:** aceita como proposta, não implantada. Se implantada, substitui o [ADR-003](003-localizacao-banco.md) (banco na mesma VM da API).

No contexto da evolução da arquitetura da Entrega 1, que tem oito pontos únicos de falha (seção 5.10) e roda tudo em `us-east-1a`,
diante da necessidade de a aplicação continuar no ar se uma instância, um componente de rede ou uma zona de disponibilidade inteira falhar,
decidimos distribuir a arquitetura em duas zonas (`us-east-1a` e `us-east-1b`), com um Application Load Balancer na frente de dois Auto Scaling Groups (web e API, mínimo de 2 instâncias cada, uma por zona, em sub-redes privadas), banco Amazon RDS for PostgreSQL em implantação Multi-AZ, um NAT Gateway por zona e o bastion em um Auto Scaling Group 1/1 que cobre as duas zonas,
e descartamos o NAT Gateway compartilhado entre as zonas, o PostgreSQL replicado em VMs próprias (streaming replication com failover manual ou Patroni) e a réplica de leitura do RDS no lugar do Multi-AZ,
para que a falha de uma zona seja absorvida sem intervenção (o ALB deixa de enviar tráfego para a zona perdida, o ASG recria instâncias na zona que sobrou e o RDS promove o standby em ~60 a 120 s), sem perda de dados confirmados (replicação síncrona) e com instâncias descartáveis, já que a aplicação não guarda sessão nem arquivos no servidor,
aceitando que o custo mensal em operação contínua sobe de US$ 77,27 para US$ 191,25 (+147%), com o segundo NAT (+US$ 32,85), o RDS Multi-AZ (+US$ 27,96) e o ALB (+US$ 22,27) como maiores aumentos; que o failover do RDS ainda derruba as requisições por até 2 minutos; que o bastion continua sendo um ponto único do acesso administrativo durante os ~5 minutos de recriação pelo ASG; que a região `us-east-1` continua sendo um ponto único de falha; e que, para o perfil de uso atual (10 usuários, horário comercial, sem SLA), o grupo **não recomenda** implantar a proposta, preferindo a arquitetura de uma zona com o plano de backup ([ADR-005](005-estrategia-de-backup.md)) e RTO de 4 horas.

## Contexto adicional

- **NAT compartilhado:** economizaria US$ 32,85/mês, mas na falha da zona do NAT as instâncias novas criadas pelo ASG na outra zona não conseguiriam baixar pacotes e imagens no boot. A alta disponibilidade falharia justamente no cenário que ela existe para cobrir.
- **PostgreSQL em VMs próprias:** a instância custaria menos, mas o failover automático exigiria Patroni e um consenso (etcd), mais componentes para manter e proteger. O failover manual não atende a meta de recuperação sem intervenção.
- **Réplica de leitura:** é assíncrona (pode perder as últimas transações) e a promoção é manual.
- **Ajuste na aplicação:** o health check do `tg-api` usa `/actuator/health`, o que exige acrescentar `spring-boot-starter-actuator` ao `pom.xml`. A rota já está liberada em `SecurityConfig`.
- Detalhes, plano de endereçamento e cálculo de custo: [`docs/alta-disponibilidade.md`](../alta-disponibilidade.md).
