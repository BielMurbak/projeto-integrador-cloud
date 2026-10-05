# ADR-002: Saída para a internet da sub-rede privada

No contexto da `vm-app`, que fica na sub-rede privada sem IP público,
diante da necessidade de ela baixar atualizações do Ubuntu e as imagens Docker da aplicação (`ghcr.io`) a cada recriação do ambiente, sem aceitar conexões iniciadas pela internet,
decidimos usar um NAT Gateway gerenciado da AWS na sub-rede pública, com rota `0.0.0.0/0 → NAT` na tabela da sub-rede privada,
e descartamos uma instância NAT própria (EC2 `t4g.nano` com *source/dest check* desativado) e a ausência de saída para a internet (VM com imagem pré-montada),
para ter uma saída que a AWS mantém, atualiza e escala sozinha, sem mais um servidor para administrar, e que funciona igual a cada `terraform apply`,
aceitando que o NAT Gateway é o item mais caro da arquitetura (US$ 0,045/h + US$ 0,045/GB, ~US$ 33/mês, ~43% dos US$ 77,27 do custo contínuo, mais que as horas das três instâncias EC2 somadas, que dão US$ 30,37), que ele cobra por hora mesmo sem tráfego e não pode ser desligado, só apagado (o que nos obriga a destruir o ambiente entre as sessões), e que ele existe em uma única zona, então uma falha nessa zona corta a saída da `vm-app`.

## Contexto adicional

- **Instância NAT:** custaria ~US$ 3/mês (cerca de 10 vezes menos), mas seria mais uma VM para atualizar e proteger, com banda limitada ao tipo da instância e sem recuperação automática em caso de falha.
- **Sem saída:** seria o mais seguro e barato, mas exigiria gerar uma imagem (AMI) com tudo pré-instalado a cada mudança e impediria as atualizações de segurança. Isso inviabiliza o fluxo de recriação com cloud-init.
- O NAT gerenciado é obrigatório na Entrega 2. A análise acima registra o que ele custa em relação às alternativas.
