# Projeto Integrador — Infraestrutura em Nuvem

Uniamérica Descomplica · Prof. Gildomiro Bairros

## Grupo

| Integrante | GitHub |
|---|---|
| Gabriel Murbak | @BielMurbak |
| Rafael Scarabelot | @RafaelScarabelot |
| _(a preencher)_ | |

## Aplicação

Sistema de gestão de oficina mecânica: cadastro de mecânicos e de serviços (ordens de serviço) com login.

- `app/frontend` — SPA React (Vite) servida por Nginx, que faz proxy de `/api` para o backend
- `app/backend` — API REST Spring Boot (Java 17) com Spring Security
- Banco de dados — PostgreSQL

## Estrutura do repositório

```
├── README.md              # Identificação do grupo e visão geral
├── IA.md                  # Declaração de uso de IA
├── app/
│   ├── backend/           # API Spring Boot (histórico importado de mecanica-backend)
│   └── frontend/          # SPA React (histórico importado de mecanica-frontend)
├── docs/
│   ├── arquitetura.md     # Seções 5.1 a 5.7, 5.9 e 5.10
│   ├── adr/               # Registros de decisão arquitetural
│   ├── diagramas/         # Fonte editável (.drawio) e imagem exportada
│   └── custos/            # Estimativa da calculadora oficial
└── infra/                 # Terraform/OpenTofu (Entrega 2)
```
