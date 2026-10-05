# ADR-001: Estratégia de acesso administrativo

No contexto de uma aplicação cujas VMs de backend ficam numa sub-rede privada sem IP público,
diante da necessidade de os três integrantes administrarem todas as VMs por SSH (exigido na Entrega 2) sem expor a porta 22 dessas VMs à internet,
decidimos usar uma VM bastion (`vm-bastion`, `t3.micro`) na sub-rede pública, com SSH liberado apenas para o IP /32 de cada integrante, e acessar as demais VMs a partir dela com `ssh -J` (ProxyJump), que só aceitam SSH vindo do `sg-bastion`,
e descartamos o IP público com SSH direto em cada VM e o AWS Systems Manager Session Manager,
para que exista um único ponto de entrada administrativo, auditável e fácil de fechar, e a `vm-app` continue sem nenhuma porta exposta à internet,
aceitando que pagamos uma VM e um IPv4 público a mais (~US$ 0,015/h, ~US$ 11,88/mês no cenário contínuo: US$ 8,23 da VM com disco + US$ 3,65 do IPv4), que o bastion vira um ponto único de falha do acesso administrativo (se ele cair, ninguém entra nas VMs até recriá-lo), e que a regra por IP /32 precisa ser atualizada toda vez que o IP residencial de um integrante mudar, o que bloqueia o acesso dele até lá.

## Contexto adicional

- **IP público direto:** eliminaria o bastion, mas exigiria IP público e porta 22 aberta na `vm-app`, contradizendo a sub-rede privada do projeto.
- **Session Manager:** não abre porta 22 nem exige bastion, mas depende de agente e de papel IAM nas VMs e não demonstra SSH, que a Entrega 2 exige.
- As chaves privadas SSH ficam só nas máquinas dos integrantes. Nenhuma chave privada é copiada para o bastion (o ProxyJump repassa a conexão sem precisar dela).
