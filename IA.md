# Declaração de uso de IA

O grupo usou ferramentas de IA neste trabalho, conforme permitido pelo enunciado. Esta declaração apresenta quais ferramentas foram utilizadas, em quais partes do trabalho e como o grupo verificou, revisou e validou as informações e sugestões fornecidas.

## Ferramentas utilizadas

**Claude (Anthropic):** utilizado como ferramenta de apoio à escrita técnica, análise de alternativas, organização do repositório e auxílio em atividades de implementação e validação.

## Uso por parte do trabalho

### Decisões de arquitetura

**Como a IA auxiliou:** apresentou alternativas, com seus respectivos prós, contras e custos, para provedor, região, número de VMs, banco de dados, acesso administrativo e instalação.

**O que o grupo fez:** avaliou as alternativas e tomou todas as decisões. A proposta inicial tinha 4 VMs. O grupo questionou se seria possível utilizar apenas uma VM, verificou que essa configuração não atenderia aos fluxos exigidos (sem instância privada nem bastion) e optou por 3 VMs, com API e banco na mesma VM, visando reduzir custos e complexidade. O grupo também questionou quais recursos continuariam gerando custos mesmo com as VMs desligadas, o que levou à adoção da estratégia de destruir e recriar o ambiente com Terraform.

### `docs/arquitetura.md` (5.1 a 5.7, 5.9 e 5.10)

**Como a IA auxiliou:** apoiou a elaboração das seções com base nas decisões tomadas pelo grupo e nas informações do código da aplicação, incluindo versões consultadas no `pom.xml`, `package.json`, Dockerfiles e `docker-compose`.

**O que o grupo fez:** revisou todas as seções e conferiu as premissas (até 10 usuários, aproximadamente 40 horas de uso até a Entrega 2), os CIDRs, as rotas e a matriz de segurança (nenhuma regra de SSH para `0.0.0.0/0`). A seção 5.9 foi atualizada com os valores oficiais da calculadora preenchida pelo grupo.

### ADRs 001, 002 e 003

**Como a IA auxiliou:** apoiou a elaboração e revisão dos três ADRs, sugerindo formas de organizar as decisões já tomadas pelo grupo no formato Y-statement e contribuindo para melhorar a clareza e a estrutura dos textos.

**O que o grupo fez:** revisou o conteúdo e conferiu se cada ADR apresentava as alternativas descartadas e uma consequência negativa específica. No ADR 002, o grupo corrigiu a afirmação de que o NAT custava "mais que as três VMs juntas": comparando com a calculadora, ele custa mais que as horas das três instâncias (US$ 30,37), mas não mais que as VMs com os discos (US$ 33,24).

### Diagrama (`docs/diagramas/`)

**Como a IA auxiliou:** contribuiu com sugestões e orientações para o planejamento do diagrama.

**O que o grupo fez:** o integrante responsável conferiu os elementos obrigatórios com o checklist do enunciado (região, zona, CIDRs, gateways, instâncias, grupos de segurança e os três fluxos), elaborou o diagrama no draw.io e exportou o PNG.

### Estimativa de custos

**Como a IA auxiliou:** forneceu orientações para o preenchimento da AWS Pricing Calculator e realizou uma estimativa prévia com base nos preços públicos, utilizada apenas como referência para conferência.

**O que o grupo fez:** preencheu a calculadora oficial e utilizou seus valores como referência para a estimativa final de custos.

## Entrega 2

### Código Terraform (`infra/`) e cloud-init (`infra/templates/`)

**Como a IA auxiliou:** forneceu apoio técnico na elaboração do código, considerando as definições do projeto da Entrega 1 (CIDRs, IPs fixos, matriz de segurança, tipos de instância e tags) e os controles S1 a S8. Também auxiliou na execução e interpretação dos resultados de `terraform fmt`, `validate` e `plan`, no primeiro teste de `apply`, nos testes de conexão (HTTPS, SSH, recusa de senha, IP do NAT e backup) e no processo de `destroy`.

**O que o grupo fez:** autorizou cada `apply` e `destroy` (que geram custos), criou o alerta de orçamento antes do primeiro `apply`, gerou a access key do usuário `terraform-grupo` e configurou a AWS CLI (a IA não teve acesso nem manipulou as credenciais). O grupo também revisou o código e conferiu no console que nenhum recurso permaneceu ligado. O primeiro teste apresentou uma falha na `vm-web` (`unknown directive "http2"`, Nginx 1.24 do Ubuntu); a correção foi validada por meio da recriação apenas da VM afetada (errata, item 14).

### Limpeza da conta AWS

**Como a IA auxiliou:** ajudou a identificar, região por região, recursos que poderiam gerar custos na conta, provenientes de trabalhos anteriores (um volume EBS em São Paulo, dois segredos e três buckets), e orientou o processo de limpeza.

**O que o grupo fez:** autorizou a exclusão dos recursos identificados e conferiu a limpeza da conta.

### Segurança, backup e alta disponibilidade (`docs/seguranca.md`, `docs/backup.md`, `docs/alta-disponibilidade.md`, ADRs 004 e 005, errata)

**Como a IA auxiliou:** apoiou a análise dos resultados do Trivy e do Gitleaks, a elaboração das justificativas dos achados, o levantamento de ameaças, a organização do plano de backup, a estruturação da proposta de alta disponibilidade, dos ADRs e da errata. Também auxiliou na consulta dos preços oficiais na AWS Price List API e nos cálculos das tabelas de custo (planilha GFS de 12 meses e custo da proposta de HA), além de contribuir com a elaboração do diagrama `arquitetura-ha.drawio` e sua exportação para PNG.

**O que o grupo fez:** escolheu a correção dos Flow Logs como achado "corrigido" da demonstração, revisou as justificativas dos achados aceitos, conferiu as premissas de custo (volume do banco, crescimento e tamanho do dump) e avaliou a conclusão de que a proposta de HA não se justifica para o perfil da oficina.