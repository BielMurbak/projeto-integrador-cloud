# Arquitetura (Entrega 1)

Projeto da arquitetura e das decisões de infraestrutura.
Provedor **AWS**, região **us-east-1 (N. Virginia)**, zona **us-east-1a**.

O que mudou na implantação (Entrega 2) está em [errata.md](errata.md).

## 5.1 A aplicação

**Problema:** oficinas pequenas controlam os serviços em papel ou planilha. Não sabem o que está pendente, quem é o mecânico responsável nem quanto cada serviço vai custar.

**Usuários:** funcionários administrativos da oficina e o administrador do sistema.

**Funcionalidades:**
- Login (HTTP Basic). O usuário admin é criado automaticamente no primeiro start.
- Cadastro de **mecânicos**: nome, especialidade, telefone, e-mail, ativo ou inativo.
- Cadastro de **serviços** (ordens de serviço): descrição, carro, mecânico, valor, duração e status (pendente, em andamento, concluído).

**Componentes:**
- **Frontend:** React servido por Nginx, que também repassa `/api` para o backend. É o único exposto à internet (porta 80).
- **Backend:** API Spring Boot 3.5 (Java 17) na porta 8080. Só recebe tráfego do Nginx.
- **Banco:** PostgreSQL 16. Só a API acessa, na mesma VM.

**Premissas:**
- Até 10 usuários ao mesmo tempo.
- Menos de 1 GB de dados no primeiro ano.
- Uso em horário comercial, sem SLA.
- **Sem alta disponibilidade:** uma zona e uma instância por camada (ver 5.10).
- Sem backup automático nesta entrega; o plano de backup vem na Entrega 2.

## 5.2 Diagrama

![Diagrama de arquitetura](diagramas/arquitetura.png)

Arquivo editável: [`diagramas/arquitetura.drawio`](diagramas/arquitetura.drawio). A imagem foi atualizada na Entrega 2 com o que foi de fato implantado; a versão original está na tag `entrega-1`.

**Fluxos:**
1. **Usuário:** navegador → Internet Gateway → `vm-web` (porta 80) → o Nginx entrega o React. As chamadas `/api/*` vão para a `vm-app:8080`, que consulta o PostgreSQL.
2. **Administrador:** IP do integrante → `vm-bastion:22` → do bastion, SSH para a `vm-web` ou a `vm-app` (`ssh -J`).
3. **Saída da VM privada:** `vm-app` → NAT Gateway → internet, para atualizar pacotes e baixar as imagens Docker. Ninguém de fora consegue entrar por esse caminho.

## 5.3 Endereços IP

**Rede:**
- VPC `vpc-mecanica`: `10.20.0.0/16`.
- Sub-rede pública `pub-a`: `10.20.1.0/24` (bastion, web e NAT).
- Sub-rede privada `priv-a`: `10.20.10.0/24` (API e banco).

**IPs fixos das instâncias** (fixados no Terraform, para o Nginx sempre achar a API):
- `vm-bastion`: 10.20.1.10, com IP público.
- `vm-web`: 10.20.1.20, com IP público.
- `vm-app`: 10.20.10.10, **sem IP público**.
- NAT Gateway: IP privado definido pela AWS, com Elastic IP.

**Por que esses tamanhos:**
- **VPC /16:** é o maior bloco que a AWS permite, não custa nada a mais e deixa espaço para crescer.
- **Sub-redes /24:** 256 endereços, dos quais a AWS reserva 5 (o `.0`, o `.1` roteador, o `.2` DNS, o `.3` reservado e o `.255`). Sobram 251, muito mais do que o necessário.
- **Numeração:** públicas em `10.20.1-9.x` e privadas em `10.20.10-19.x`. O terceiro número já diz o tipo.

## 5.4 Rotas

**`rt-publica`** (sub-rede `pub-a`):
- `10.20.0.0/16` → local (tráfego interno).
- `0.0.0.0/0` → Internet Gateway. É essa rota que torna a sub-rede pública.

**`rt-privada`** (sub-rede `priv-a`):
- `10.20.0.0/16` → local.
- `0.0.0.0/0` → NAT Gateway: só saída, de dentro para fora.

**Sem a rota para o NAT,** a `vm-app` continuaria acessível de dentro da VPC, mas sem internet. O `apt` e o download das imagens Docker falhariam, e a aplicação não subiria numa recriação do ambiente.

## 5.5 Regras de segurança

São três security groups, um por função. Entre componentes internos, as regras apontam para **outro security group**, não para um IP.

**`sg-bastion`:**
- Entrada: 22 só do IP `/32` de cada integrante. **Nunca `0.0.0.0/0`.**
- Saída: 22 para o `sg-web` e para o `sg-app`.

**`sg-web`:**
- Entrada: 80 de qualquer lugar (usuários) e 22 só do `sg-bastion`.
- Saída: 8080 para o `sg-app` (repassar o `/api`), e 80/443 para a internet (pacotes e imagens).

**`sg-app`:**
- Entrada: 8080 só do `sg-web` e 22 só do `sg-bastion`.
- Saída: 80/443 para a internet, pelo NAT.

**Observações:**
- O PostgreSQL (5432) não tem regra: ele só escuta dentro da VM.
- A regra padrão de saída "libera tudo" é removida.
- As Network ACLs ficam no padrão; o controle é feito nos security groups.
- Não há HTTPS nesta versão, por falta de domínio e certificado (ver 5.10). Foi adicionado na Entrega 2.

## 5.6 Tecnologias

- **Ubuntu Server 24.04 LTS:** suporte até 2029, imagem oficial gratuita, funciona com cloud-init.
- **Docker + Docker Compose:** a aplicação já tem imagens prontas no `ghcr.io`.
- **Backend:** Java 17 + Spring Boot 3.5, que é a stack da aplicação.
- **Frontend:** React + Vite. O Node.js só é usado para gerar os arquivos.
- **Nginx:** entrega o React e repassa o `/api`, para não expor a porta 8080.
- **PostgreSQL 16:** é o banco que a aplicação já usa.
- **Terraform ≥ 1.9 com o provider `hashicorp/aws ~> 6.0`:** exigido pela disciplina, permite criar e destruir tudo de novo.
- **cloud-init:** cada VM se instala sozinha no primeiro boot.

**Por que `us-east-1`:**
- **Custo:** é a região mais barata. Em São Paulo, o mesmo ambiente custa de 50% a 60% mais. Esse foi o motivo decisivo.
- **Latência:** ~120 ms, contra ~20 ms em São Paulo. É aceitável para um sistema administrativo com poucos usuários.
- **Serviços:** tem tudo o que precisamos e 6 zonas, o que permite propor alta disponibilidade.
- **Experiência:** o grupo já usou a AWS antes.

## 5.7 Tamanho das instâncias

- **`vm-bastion`:** `t3.micro` (2 vCPU, 1 GiB), disco gp3 de 8 GiB. Só repassa SSH.
- **`vm-web`:** `t3.micro` (2 vCPU, 1 GiB), disco gp3 de 8 GiB. O Nginx usa menos de 50 MB.
- **`vm-app`:** `t3.small` (2 vCPU, 2 GiB), disco gp3 de 20 GiB. Spring + PostgreSQL + Docker chegam a ~1,2 GB no pico, e o disco maior guarda as imagens e o banco.

**Por que T3:** o uso é baixo, com picos curtos. As instâncias T3 acumulam créditos de CPU enquanto estão paradas e custam bem menos que as de uso geral.

**Por que não menor:**
- A `t3.nano` (0,5 GiB) não roda Ubuntu com Docker com folga.
- Com uma `t3.micro`, a `vm-app` ficaria sem memória e a API cairia.

**Quando os créditos acabam:** usamos o modo `standard`, em que a CPU fica limitada ao mínimo e a aplicação fica lenta, mas não sai do ar. O modo `unlimited` cobraria o excesso à parte.

## 5.9 Custos

Estimativa da calculadora da AWS (01/10/2026, `us-east-1`, sem nível gratuito):
- Link: <https://calculator.aws/#/estimate?id=9e7fbfad8f04a4509955794e7fb70ace1189658c>
- PDF: [`custos/estimativa.pdf`](custos/estimativa.pdf)

**Por mês, tudo ligado 24 h:**
- `vm-bastion`: US$ 8,23.
- `vm-web`: US$ 8,23.
- `vm-app`: US$ 16,78.
- VPC: US$ 44,03, que é o NAT (US$ 32,85) mais os dados do NAT (US$ 0,23) mais 3 IPs públicos (US$ 10,95).
- **Total: US$ 77,27 por mês** (cenário A).

**Cenário B (o trabalho):** cerca de 40 horas ligado até 23/11, destruindo tudo entre as sessões: **≈ US$ 4,23** (US$ 0,1059 por hora × 40 h).

**O mais caro é o NAT Gateway** (~43% do total): custa quase o mesmo que as três VMs juntas e cobra por hora mesmo sem uso.
- **Daria para trocar** por uma instância NAT de ~US$ 3 por mês, mas ela vira mais um servidor para manter e um ponto único de falha.
- **Não trocamos** porque o NAT gerenciado é obrigatório na Entrega 2 ([ADR-002](adr/002-saida-internet-subrede-privada.md)).

**Controle de custos:**
- `terraform destroy` ao fim de **toda** sessão.
- Alerta de orçamento no AWS Budgets por e-mail.
- Tags em todos os recursos, para filtrar o custo.
- Conferir no console, depois de cada sessão, se não sobrou nada.

**Decisão:** destruir e recriar a cada sessão, com instalação automática pelo cloud-init. Assim só pagamos as horas usadas. O preço é que os dados do banco se perdem a cada `destroy`, o que é aceitável porque são dados de teste.

## 5.10 Riscos e limitações

1. **Uma só zona:** se a zona cair, a aplicação inteira cai.
2. **API e banco na mesma VM:** se a VM falhar, a aplicação para e os dados se perdem. A API e o banco também disputam CPU e memória.
3. **Uma só VM web, sem balanceador:** qualquer falha ou reinício derruba o site.
4. **Um só NAT:** se ele cair, a `vm-app` fica sem internet e a recriação do ambiente falha.
5. **Um só bastion:** se ele cair, o grupo perde o acesso administrativo até recriá-lo.
6. **Sem HTTPS:** a senha do login trafega sem criptografia.
7. **IP residencial que muda:** quando o IP de um integrante muda, ele perde o SSH até a regra ser atualizada.
8. **CPU com créditos:** uso alto e contínuo esgota os créditos e deixa a aplicação lenta.

Esta lista é o ponto de partida da alta disponibilidade e do backup da Entrega 2.
