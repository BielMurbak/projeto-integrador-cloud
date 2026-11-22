# Plano de backup (Parte D)

São duas políticas:
- **Conservadora (GFS):** o que recomendaríamos para a oficina de verdade. Só no papel, com custo para 12 meses.
- **Mínima:** criada pelo Terraform e mostrada na apresentação, com custo perto de zero.

Decisão registrada no [ADR-005](adr/005-estrategia-de-backup.md).

## B1. O que precisa de backup

**Precisa:**
- **Banco PostgreSQL** (mecânicos, serviços, usuários). É o único dado que não se recria, e ele some a cada `terraform destroy`.
- **State do Terraform** e **chave SSH do grupo.** Ficam fora deste plano: cada integrante guarda a própria cópia.

**Não precisa:**
- **Infraestrutura e configuração das VMs:** são recriadas pelo código em `infra/`, que está no Git.
- **Imagens da aplicação:** ficam no `ghcr.io`, geradas a partir de `app/`.
- **Senhas:** são criadas de novo em cada ambiente.
- **Arquivos enviados por usuários:** a aplicação não tem upload; tudo fica no banco.

## B2. RPO e RTO

- **RPO de 24 horas** (quanto dado podemos perder). A oficina tem até 10 usuários e poucos cadastros por dia. Perder um dia dá trabalho, mas dá para recadastrar a partir das anotações.
- **RTO de 4 horas** (em quanto tempo o sistema volta). O `terraform apply` leva ~10 minutos e restaurar o banco, poucos minutos. O resto do tempo é para diagnosticar e conferir. Enquanto isso, a oficina atende no papel.

## B3. Política conservadora (GFS)

**Mecanismo por ativo:**
- **Banco:** `pg_dump` compactado, gravado no S3. O dump sai consistente mesmo com o sistema em uso.
- **Cópias no bucket:** versionamento do S3, para que uma cópia sobrescrita não se perca.
- **Código e configuração:** o próprio Git.
- **State do Terraform:** cópia guardada pelo integrante que roda o `apply`.

**Son (filho), diário**
- Todo dia às 03h, fora do expediente.
- Guarda 7 dias, em `diario/`, na classe S3 Standard.
- Permite voltar a qualquer dia da última semana.

**Father (pai), semanal**
- A cópia de **domingo** é copiada para `semanal/`.
- Guarda 5 semanas, na classe S3 Standard-IA (mais barata).
- Permite voltar a qualquer semana do último mês.

**Grandfather (avô), mensal**
- A cópia do **último dia do mês** é copiada para `mensal/`.
- Guarda 12 meses, na classe S3 Glacier Instant Retrieval (a mais barata, e devolve o arquivo na hora).
- Permite voltar a qualquer mês do último ano.

Cada pasta tem sua regra de expiração. As retenções ficam acima do tempo mínimo de cobrança de cada classe, então não há multa por apagar antes.

## B4. Onde as cópias ficam

- **Fora da VM:** vão direto para o S3, nada fica no disco da `vm-app`.
- **Em outra região:** na política conservadora, o bucket é replicado para Ohio (`us-east-2`).
- **Criptografadas:** AES256, e o bucket só aceita acesso por TLS (S6).
- **Com acesso restrito:** a `vm-app` só consegue **gravar** em `diario/`; não lista, não lê e não apaga (S5).
- **Sem passar pelo NAT:** o envio usa o endpoint do S3, que é gratuito.

## B5. Quem é responsável pelo quê

**Banco PostgreSQL (na `vm-app`)**
- AWS: só o disco (replicado dentro da zona). Isso **não protege** contra um `DROP TABLE`.
- Grupo: tudo o resto, ou seja, fazer o dump, guardar, restaurar e atualizar o PostgreSQL.

**Cópias no S3**
- AWS: durabilidade de 99,999999999%, criptografia quando ligada, execução das regras de expiração e da replicação.
- Grupo: gerar as cópias, escolher retenção e classe, configurar criptografia e acesso, testar a restauração.

**Disco da `vm-app`**
- AWS: replicação dentro da zona e criptografia.
- Grupo: saber que o disco é apagado no `destroy` (não usamos snapshots).

**State do Terraform**
- AWS: nada, porque ele fica no notebook de quem roda o `apply`.
- Grupo: guardar e proteger o arquivo.

**Infraestrutura**
- AWS: criar o que o código descreve.
- Grupo: manter o código no Git, reproduzível.

## B6. Política mínima (configurada e testada)

Opção A do enunciado: dump do banco gravado no S3, só a geração diária, com retenção curta. Escolhemos o dump, e não o snapshot do disco, porque o dump sai consistente do ponto de vista do banco; um snapshot com o banco rodando seria só *crash-consistent*. Tudo vem do Terraform: [`infra/backup.tf`](../infra/backup.tf) e o cloud-init da `vm-app`.

- **Agenda:** um backup **10 minutos depois do boot** e depois **um por dia** às 03h de Brasília. Também dá para rodar à mão: `sudo /usr/local/bin/backup-db.sh`.
- **Onde fica:** `s3://mecanica-backup-<conta>/diario/mecanica-<data-hora>.sql.gz`.
- **Retenção:** cada cópia expira em **1 dia** (regra `son-diario`). Segundo a documentação da AWS (*Amazon S3 Lifecycle, Expiring objects*), a expiração é arredondada para a meia-noite UTC seguinte e executada de forma assíncrona. Por isso a cópia some entre 24 e 48 horas depois de criada, dentro do limite de 2 dias. No teste, a cópia de 19/11 00h27 recebeu expiração em 21/11 00h00.
- **Criptografia:** AES256, confirmada com `aws s3api head-object`.
- **Permissão:** a `vm-app` grava com a própria role, sem chave de acesso na máquina.

**Testado em 19/11, 21/11 e 22/11/2026.** O backup automático apareceu no bucket criptografado e com data de expiração, e a `vm-app` levou `AccessDenied` ao tentar listar, ler e apagar. Saídas completas: [teste 21/11](evidencias/teste-final-2026-11-21.txt), [teste 22/11](evidencias/teste-final-2026-11-22.txt) (seção D6).

## B7. Custos

### Política mínima no período do trabalho: ≈ US$ 0,00
- Armazenamento: arquivos de poucos KB, vivos por até 2 dias, abaixo de US$ 0,001.
- Requisições: ~25 envios no período, abaixo de US$ 0,001.
- Transferência: US$ 0,00, porque o envio vai pelo endpoint do S3, que é gratuito.

### Política GFS em 12 meses: US$ 1,22 no ano

**Premissas:**
- O banco começa com 100 MB e cresce 70 MB por mês, até ~870 MB no fim do ano (menos de 1 GB, como na seção 5.1 da Entrega 1).
- Cada cópia ocupa 25% do banco, já compactada com gzip.
- Ficam guardadas 7 cópias diárias, 5 semanais e até 12 mensais.
- Tudo em 2 regiões: `us-east-1` e a réplica em `us-east-2`.
- Todo mês: 30 cópias diárias novas, 4 promoções semanais e 1 mensal.

**Preços unitários** (preços públicos de `us-east-1`, os mesmos da calculadora, consultados em 21/11/2026):
- S3 Standard: US$ 0,023 por GB/mês.
- S3 Standard-IA: US$ 0,0125 por GB/mês, cobrança mínima de 30 dias e leitura a US$ 0,01 por GB.
- S3 Glacier Instant Retrieval: US$ 0,004 por GB/mês, cobrança mínima de 90 dias e leitura a US$ 0,03 por GB.
- Envio e cópia (PUT/COPY): US$ 0,005 por 1.000.
- Mudança de classe: US$ 0,01 por 1.000 para IA e US$ 0,02 por 1.000 para Glacier IR.
- Replicação para a outra região: US$ 0,01 por GB.

As retenções (35 dias no Standard-IA e 365 no Glacier IR) passam da cobrança mínima de cada classe, então não há multa por apagar antes. A leitura só é paga quando se restaura uma cópia antiga, o que é raro.

**Mês a mês** (banco → cópias guardadas → volume em backup nas 2 regiões → custo):
- Mês 1: 0,10 GB → 12 cópias → 0,60 GB → US$ 0,02
- Mês 2: 0,17 GB → 14 cópias → 1,16 GB → US$ 0,03
- Mês 3: 0,24 GB → 15 cópias → 1,70 GB → US$ 0,05
- Mês 4: 0,31 GB → 16 cópias → 2,27 GB → US$ 0,06
- Mês 5: 0,38 GB → 17 cópias → 2,88 GB → US$ 0,08
- Mês 6: 0,45 GB → 18 cópias → 3,53 GB → US$ 0,09
- Mês 7: 0,52 GB → 19 cópias → 4,21 GB → US$ 0,11
- Mês 8: 0,59 GB → 20 cópias → 4,92 GB → US$ 0,12
- Mês 9: 0,66 GB → 21 cópias → 5,67 GB → US$ 0,14
- Mês 10: 0,73 GB → 22 cópias → 6,46 GB → US$ 0,15
- Mês 11: 0,80 GB → 23 cópias → 7,28 GB → US$ 0,17
- Mês 12: 0,87 GB → 24 cópias → 8,13 GB → US$ 0,19
- **Total no ano: US$ 1,22**

O custo cresce porque o banco cresce e porque as cópias mensais se acumulam até a 12ª. Os valores incluem armazenamento, requisições, mudanças de classe e replicação. Planilha com o cálculo: [`custos/backup-gfs-12-meses.csv`](custos/backup-gfs-12-meses.csv).

**Qual parâmetro mais pesa no custo:**
- **Retenção diária (Son):** é o parâmetro da GFS que mais pesa. Com 30 dias em vez de 7, o custo vai a US$ 2,76 (+126%). Reduzir para 3 dias economizaria, mas um erro percebido no 4º dia só voltaria pela cópia semanal, perdendo até 6 dias de trabalho em vez de 1.
- **Cópia em outra região:** sem ela, o custo cai 71%, para US$ 0,36. Não compensa, porque uma falha da região levaria a aplicação e o backup juntos.
- **Os outros** mudam menos de 25%: Glacier IR trocado por Standard (+22%), 10 semanas em vez de 5 (+15%), diário em Standard-IA (−18%).

O valor é baixo porque o banco é pequeno. Perder um ano de ordens de serviço custaria muito mais.

## O que a política mínima não cobre

- **Erro percebido depois de 2 dias:** a cópia já expirou. Exemplo: um mecânico apagado na segunda e percebido na quarta não volta.
- **Corrupção silenciosa:** se o banco corromper, o dump do dia copia o problema e não existe cópia anterior.
- **Falha da região:** a cópia fica na mesma região da aplicação.
- **`terraform destroy`:** apaga o bucket junto com as cópias. Na política conservadora, o bucket ficaria fora do ciclo de `apply` e `destroy`.
