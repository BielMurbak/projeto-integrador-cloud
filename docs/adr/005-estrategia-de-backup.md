# ADR-005: Estratégia de backup

**Status:** aceita. Política mínima implantada (Terraform); política conservadora GFS planejada.

No contexto de um banco PostgreSQL que roda em contêiner na `vm-app` ([ADR-003](003-localizacao-banco.md)) e é apagado a cada `terraform destroy`, com menos de 1 GB de dados no primeiro ano e uso em horário comercial por até 10 pessoas,
diante da necessidade de recuperar os dados após exclusão acidental, corrupção, ataque ou erro de operação, com RPO de 24 horas e RTO de 4 horas, e de manter o custo do trabalho acadêmico próximo de zero,
decidimos fazer dump lógico diário (`pg_dump` comprimido) gravado pela própria `vm-app` em um bucket S3 criptografado (SSE-S3), por meio de uma role que só tem permissão de gravar no prefixo `diario/`, organizando a política conservadora em esquema GFS (diária às 03h com 7 dias em S3 Standard; a cópia de domingo promovida a semanal com 5 semanas em Standard-IA; a do último dia do mês promovida a mensal com 12 meses em Glacier Instant Retrieval; replicação para `us-east-2`) e configurando no trabalho apenas a geração diária com expiração de 1 dia,
e descartamos o snapshot agendado do disco EBS da `vm-app` pelo Data Lifecycle Manager e o AWS Backup,
para ter cópias consistentes do ponto de vista do banco (o `pg_dump` usa um snapshot transacional, enquanto o snapshot de disco seria apenas *crash-consistent*), pequenas (só os dados, não o sistema operacional e as imagens Docker), fora da instância e que nem um invasor com controle da `vm-app` consegue listar, ler ou apagar,
aceitando que a restauração é manual (criar o ambiente, baixar o dump com o usuário do grupo e rodar `psql`), que o RPO de 24 horas significa perder até um dia de cadastros, que a política mínima configurada (1 dia, sem semanal, mensal nem réplica) não desfaz um erro descoberto depois de 2 dias, que o bucket do trabalho tem `force_destroy` e some no `terraform destroy`, e que a promoção entre gerações na política conservadora exige uma identidade separada com permissão de leitura e cópia no bucket.

## Contexto adicional

- **Snapshot do disco (DLM):** captura o disco inteiro de 20 GB (sistema, imagens e banco) e é apenas *crash-consistent*: transações em andamento podem se perder. Em produção, mitigaria-se com `pg_backup_start`/`pg_backup_stop` ou parando o banco antes do snapshot.
- **AWS Backup:** mesmo mecanismo de snapshot, com cobrança adicional e sem ganho para um único volume.
- **Custo:** política mínima ≈ US$ 0,00 no período do trabalho; política GFS US$ 1,22 em 12 meses. O parâmetro de maior impacto é a retenção da geração diária (30 dias em vez de 7: +126%). Detalhes em [`docs/backup.md`](../backup.md).
- Este ADR complementa o [ADR-003](003-localizacao-banco.md), que registrava o backup como manual e pendente para a Entrega 2. A decisão de manter o banco na VM não muda.
