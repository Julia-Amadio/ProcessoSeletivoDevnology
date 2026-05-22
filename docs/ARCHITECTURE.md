# ARCHITECTURE.md
Este documento descreve as decisões técnicas tomadas ao longo do desenvolvimento
do projeto: escolha de ferramentas, organização dos arquivos e trade-offs considerados.

---

## Estrutura do projeto

```
ProcessoSeletivoDevnology/
├── docs/
│   ├── ARCHITECTURE.md   # este arquivo
│   └── AI_USAGE.md       # documentação do uso de IA
├── .dockerignore         # arquivos ignorados pelo Docker no build da imagem
├── .gitignore            # arquivos ignorados pelo Git
├── .gitlab-ci.yml        # pipeline de CI/CD do GitLab
├── app.py                # aplicação Flask com endpoints / e /health
├── docker-compose.yml    # ambiente local isolado via Docker
├── Dockerfile            # build da imagem de produção (multi-stage)
├── healthcheck.sh        # script para verificar se a API está respondendo
├── requirements.txt      # dependências de produção
├── requirements-dev.txt  # dependências de desenvolvimento (inclui produção)
└── test_app.py           # testes unitários com pytest
```

Os arquivos `app.py`, `test_app.py` e `requirements.txt` foram fornecidos pelos
avaliadores. Os scripts Python não tiveram o funcionamento alterado em relação ao
original — apenas ajustes de estilo para conformidade com PEP 8, adição de
comentários e uma supressão de falso positivo do Bandit, detalhadas a seguir.

---

## Ambiente virtual Python (`.venv`)

O Ubuntu 24.04 bloqueia instalações de pacotes Python system-wide por padrão,
protegendo as dependências do sistema operacional de conflitos com pacotes de
projetos. A solução correta — e boa prática independente do sistema — é isolar
as dependências em um ambiente virtual por projeto.

Com `.venv`, cada projeto tem sua própria versão de cada pacote sem interferir
em outros projetos ou no Python do sistema. O diretório `.venv/` está no
`.gitignore` e as dependências são reproduzidas a partir dos arquivos
`requirements*.txt`.

---

## Divisão de dependências

O `requirements.txt` original incluía o `pytest`, o que resultava em uma imagem
Docker de produção com uma dependência de testes inutilizada, aumentando
desnecessariamente a superfície de ataque.

As listas foram divididas em duas responsabilidades distintas:

- **`requirements.txt`:** dependências de produção exclusivamente (`flask`, `gunicorn`). 
É o arquivo usado pelo Dockerfile.
- **`requirements-dev.txt`:** herda `requirements.txt` via `-r requirements.txt` e adiciona 
as ferramentas de desenvolvimento (`pytest`, `flake8`, `bandit`). 
É o arquivo usado localmente por quem desenvolve.

O pipeline do GitLab instala cada ferramenta individualmente no job que a utiliza,
sem depender de nenhum dos dois arquivos e garantindo que cada job tenha apenas
o que precisa.

---

## Dockerfile com multi-stage build

O objetivo do multi-stage foi separar o ambiente de instalação de dependências
do ambiente de execução final.

Um `pip install flask`, por exemplo, pode precisar de `gcc`, headers e
ferramentas de build para compilar dependências nativas. Essas ferramentas 
podem pesar dezenas de MB e não têm utilidade na imagem final, 
sendo necessárias apenas durante a instalação.

- **Stage `builder`:** possui pip e ferramentas de build. Instala as dependências
em `/install` e gera os pacotes prontos.
- **Stage final:** parte de uma imagem limpa e mínima (`python:3.12-slim`). Copia apenas
a pasta de pacotes do stage anterior, sem nenhuma ferramenta de build.

O resultado é uma imagem menor e com menos superfície de ataque. Menos
ferramentas instaladas significa menos vetores de exploração.

### Cache de layers

O `COPY requirements.txt .` é feito antes do `COPY app.py .` intencionalmente.
O Docker cacheia cada instrução como uma layer. Separando a cópia do
`requirements.txt` da cópia do código, o `pip install` só é reexecutado quando
as dependências mudam — não a cada alteração no código da aplicação.

### Health check no Dockerfile

O Dockerfile define um `HEALTHCHECK` que bate no endpoint `/health` a cada 30
segundos. Se o container falhar em todos os checks, o orquestrador (ECS ou outro)
o marca como `unhealthy` e pode substituí-lo automaticamente.

### Usuário não-root

O container roda como `appuser`, um usuário sem senha e sem privilégios de
administrador. Se a aplicação for comprometida, o atacante não terá acesso root
ao container.

---

## Escolha do gunicorn como servidor

O servidor embutido do Flask (`app.run()`) é single-thread e não possui tratamento 
robusto de erros HTTP, não sendo adequado para produção. O `gunicorn` é um servidor 
WSGI de produção que resolve ambos os problemas.

Flask é uma aplicação WSGI (síncrona). Dois workers foram configurados (`--workers 2`) 
para atender requisições simultâneas, adequado para o escopo do projeto.

---

## Docker Compose para desenvolvimento local

O `docker-compose.yml` serve três propósitos no desenvolvimento local:

1. Build automático da imagem a partir do Dockerfile, sem precisar rodar
`docker build` manualmente;
2. Mapeamento de porta declarativo, sem precisar lembrar o `-p 5000:5000` do
`docker run`;
3. Um único comando (`docker compose up --build`) que reproduz o ambiente de
forma consistente em qualquer máquina.

---

## Escolha do flake8 para lint

O flake8 verifica três camadas de qualidade do código Python:

- **Estilo:** indentação, espaços, comprimento de linha (PEP 8);
- **Qualidade:** imports não utilizados, variáveis declaradas mas nunca usadas;
- **Erros potenciais:** uso incorreto de operadores, funções sem retorno esperado.

O job de lint falha o pipeline se qualquer problema for encontrado, impedindo
que código com erros de estilo ou qualidade avance para os stages seguintes.

---

## Escolha do Bandit para SAST

O Bandit é a ferramenta padrão da indústria para SAST em Python, sendo inclusive o
que o GitLab usa em seu template oficial de CI para Python. Seu output é legível:
aponta exatamente o arquivo, a linha, a severidade e a descrição da
vulnerabilidade encontrada.

A flag `-ll` suprime alertas de severidade `LOW`, evitando ruído e focando o job
em problemas reais.

### Falso positivo suprimido

O Bandit levanta um alerta `B104` para o `host="0.0.0.0"` no `app.py`. O alerta
é tecnicamente correto — binding em todas as interfaces expõe o serviço para
tráfego externo — mas é intencional e necessário para que o container responda a
requisições vindas de fora.

O comentário `# nosec B104` na linha em questão suprime o alerta de forma
cirúrgica e documentada. É a forma oficial do Bandit para indicar que a linha foi
revisada conscientemente — diferente de ignorar o problema.

---

## Decisões do pipeline `.gitlab-ci.yml`

### Cache do pip entre pipelines

O pip por padrão salva cache em `/root/.cache`, fora do diretório do projeto. O
GitLab só consegue persistir cache de caminhos dentro de `$CI_PROJECT_DIR`, então
`PIP_CACHE_DIR` é redirecionado para `.cache/pip`. Na prática, os pacotes não são
baixados do zero a cada pipeline.

A chave de cache usa `$CI_COMMIT_REF_SLUG` (nome da branch sanitizado) para que
branches diferentes não compartilhem cache incompatível entre si.

### Job template `.docker-base`

Os stages `build` e `smoke-test` compartilham a mesma configuração base: imagem
`docker:24`, serviço `dind` e login no registry. Repetir esse bloco nos dois jobs
seria redundante e difícil de manter.

O template `.docker-base` centraliza essa configuração. O ponto no início do nome
instrui o GitLab a não executá-lo diretamente — ele só existe para ser herdado
via `extends`. O `before_script` do template (login no registry) é executado
automaticamente antes do `script` de cada job filho.

### Stage smoke-test

O stage `test` valida o código-fonte com pytest. O `smoke-test` vai além: sobe
o container da imagem que acabou de ser buildada e valida que ela funciona de
fato como artefato, não apenas que o código passa nos testes unitários.

Isso detecta problemas que só aparecem na imagem real: dependências faltando no
`requirements.txt`, erro de configuração do gunicorn, porta não exposta
corretamente.
