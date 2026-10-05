# ADR-003: Localização do banco de dados

No contexto de uma aplicação com poucos usuários (até 10) e menos de 1 GB de dados, cujo custo de nuvem é pago pelo próprio grupo,
diante da necessidade de o PostgreSQL não ficar exposto à internet e de manter o custo e o número de VMs baixos,
decidimos rodar o PostgreSQL 16 em contêiner Docker na mesma VM da API (`vm-app`, `t3.small`, sub-rede privada), escutando apenas em `localhost:5432`,
e descartamos o Amazon RDS for PostgreSQL e uma VM dedicada ao banco na sub-rede privada,
para não pagar uma instância a mais (uma VM `t3.micro` ou uma `db.t3.micro` no RDS) e manter a porta 5432 sem nenhuma regra de rede, já que ela nem sai da VM,
aceitando que a API e o banco disputam os mesmos 2 GiB de memória e créditos de CPU (um pico na API deixa o banco lento e vice-versa), que o backup e as atualizações do PostgreSQL são manuais e responsabilidade do grupo (não há backup automatizado nesta entrega), e que apagar ou perder a `vm-app`, inclusive em cada `terraform destroy`, apaga todos os dados.

## Contexto adicional

- **RDS:** traria backup automático, *point-in-time recovery* e opção Multi-AZ, mas custa mais e esconde a configuração de rede do banco, que é justamente o que esta disciplina avalia.
- **VM dedicada:** isolaria o banco com um `sg-db` (5432 aceita apenas o `sg-app`) e separaria os recursos, mas acrescenta ~US$ 8,23/mês (uma `t3.micro` com 8 GB, valor da calculadora) e mais uma VM para manter.
- Na Entrega 2, o plano de backup deve tratar o risco de perda de dados (por exemplo, `pg_dump` agendado para um bucket S3). Se a decisão mudar, será registrada numa errata que referencia este ADR.
