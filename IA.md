# Declaração de uso de IA

O grupo usou ferramentas de IA neste trabalho, conforme permitido pelo enunciado. Esta declaração lista quais ferramentas foram usadas, em quais partes e o que o grupo verificou ou corrigiu no que foi gerado.

## Ferramentas utilizadas

**Claude (Anthropic):** assistente de escrita técnica, de análise de alternativas e de organização do repositório.

## Uso por parte do trabalho

### Decisões de arquitetura

**O que a IA fez:** apresentou alternativas com prós, contras e custo para provedor, região, número de VMs, banco, acesso administrativo e instalação.

**O que o grupo fez:** escolheu cada opção. A proposta inicial tinha 4 VMs. O grupo questionou se era possível usar uma VM só, verificou que isso não atendia aos fluxos exigidos (sem instância privada nem bastion) e escolheu 3 VMs, com API e banco na mesma VM, para reduzir custo e complexidade. O grupo também questionou o que continua sendo cobrado com as VMs desligadas, o que levou à estratégia de destruir e recriar o ambiente com Terraform.

### `docs/arquitetura.md` (5.1 a 5.7, 5.9 e 5.10)

**O que a IA fez:** redigiu as seções a partir das decisões do grupo e do código da aplicação (versões lidas do `pom.xml`, `package.json`, Dockerfiles e `docker-compose`).

**O que o grupo fez:** leu todas as seções e conferiu as premissas (até 10 usuários, ~40 h de uso até a Entrega 2), os CIDRs, as rotas e a matriz de segurança (nenhuma regra de SSH para `0.0.0.0/0`). A seção 5.9 foi atualizada com os valores oficiais da calculadora preenchida pelo grupo.

### ADRs 001, 002 e 003

**O que a IA fez:** auxiliou na escrita e revisão dos três ADRs, organizando as decisões já tomadas pelo grupo no formato Y-statement e ajudando a deixar o texto mais claro e estruturado.

**O que o grupo fez:** conferiu que cada um nomeia as alternativas descartadas e tem uma consequência negativa específica. No ADR 002, o grupo corrigiu a afirmação de que o NAT custava "mais que as três VMs juntas": comparando com a calculadora, ele custa mais que as horas das três instâncias (US$ 30,37), mas não mais que as VMs com os discos (US$ 33,24).

### Diagrama (`docs/diagramas/`)

**O que a IA fez:** ajudou com o planejamento do diagrama.

**O que o grupo fez:** o integrante responsável conferiu os elementos obrigatórios com o checklist do enunciado (região, zona, CIDRs, gateways, instâncias, grupos de segurança e os três fluxos), fez o diagrama no draw.io e exportou o PNG.

### Estimativa de custos

**O que a IA fez:** orientou o preenchimento da AWS Pricing Calculator e fez uma conta prévia com os preços públicos, usada só para conferência.

## Responsabilidade

Todo o conteúdo entregue foi revisado pelo grupo, e os três integrantes são capazes de explicar qualquer parte do projeto. As decisões de arquitetura são do grupo. A IA foi usada para apresentar alternativas, redigir e organizar.