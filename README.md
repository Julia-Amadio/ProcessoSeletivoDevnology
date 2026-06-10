# ProcessoSeletivoDevnology

[![Pipeline Status](https://gitlab.com/Julia-Amadio/ProcessoSeletivoDevnology/badges/main/pipeline.svg)](https://gitlab.com/Julia-Amadio/ProcessoSeletivoDevnology/-/pipelines)
[![Deploy](https://img.shields.io/badge/deploy-live-brightgreen)](http://100.25.46.122:5000/health)

Projeto elaborado como desafio técnico para o Processo Seletivo do Programa Trainee Cloud & IA da Devnology. Demonstra a automatização completa do ciclo de vida de uma aplicação web, desde o build até o deploy, por meio de um pipeline CI/CD estruturado no GitLab.

---

## Stack
- **Python + Flask:** aplicação backend com endpoints de health check
- **Docker:** containerização com multi-stage build
- **Docker Compose:** ambiente local isolado
- **GitLab CI/CD:** pipeline automatizado de integração e entrega contínua
- **flake8:** lint e conformidade com PEP 8
- **pytest:** testes unitários
- **bandit:** análise estática de segurança (SAST)
- **gunicorn:** servidor WSGI de produção
- **Terraform:** provisionamento da infraestrutura AWS como código
- **Amazon ECS Fargate:** orquestração e execução dos containers em produção
- **Amazon ECR:** registry de imagens Docker

---

## Pipeline CI/CD
O pipeline completo pode ser visualizado no repositório GitLab:
**https://gitlab.com/Julia-Amadio/ProcessoSeletivoDevnology**

| Stage | O que faz |
|---|---|
| `lint` | Verifica qualidade e estilo do código com flake8 (PEP 8) |
| `test` | Executa testes unitários com pytest |
| `sast` | Analisa vulnerabilidades de segurança em tempo estático com bandit |
| `build` | Constrói a imagem Docker e faz push para o GitLab Container Registry |
| `smoke-test` | Sobe o container da imagem buildada e valida o endpoint de health check |
| `deploy` | Simula o deploy no Amazon ECS (executa apenas na branch `main`) |

---

## Deploy

A aplicação está provisionada na AWS com infraestrutura definida via Terraform
e acessível publicamente:

| Endpoint | URL |
|---|---|
| Health check | http://100.25.46.122:5000/health |
| Raiz | http://100.25.46.122:5000 |

A infraestrutura (ECR, ECS Fargate, IAM, CloudWatch, Security Group) foi
provisionada com `terraform apply` a partir da pasta `/terraform`.

---

## Executando localmente

### Pré-requisitos

- [Python 3.12+](https://www.python.org/downloads/)
- [Docker Engine](https://docs.docker.com/engine/install/)
- [Git](https://git-scm.com/downloads)

Clone o repositório e navegue até a pasta:

```bash
git clone https://github.com/Julia-Amadio/ProcessoSeletivoDevnology.git
cd ProcessoSeletivoDevnology
```

### Com Docker (recomendado)

```bash
docker compose up --build
```

Em outro terminal, verifique os endpoints:

```bash
curl http://localhost:5000/
curl http://localhost:5000/health
```

### Sem Docker

1. Crie e ative o ambiente virtual:

    ```bash
    python -m venv .venv
    ```

    | Sistema | Shell | Comando de ativação do ambiente |
    |---|---|---|
    | Windows | cmd | `.venv\Scripts\activate` |
    | Windows | PowerShell | `.\.venv\Scripts\Activate.ps1` |
    | Linux/macOS | bash/zsh | `source .venv/bin/activate` |

2. Instale as dependências:

    ```bash
    pip install -r requirements-dev.txt
    ```

3. Execute a aplicação:

    ```bash
    python app.py
    ```

---

## Endpoints

| Método | Rota | Descrição |
|---|---|---|
| GET | `/` | Mensagem de boas-vindas |
| GET | `/health` | Health check com status, timestamp e versão |

```bash
# Rota raiz
curl http://localhost:5000/

# Health check
curl http://localhost:5000/health
```

Exemplo de resposta do `/health`:
```json
{
  "status": "healthy",
  "timestamp": "2026-05-21T02:12:42.662734",
  "version": "1.0.0"
}
```

---

## Ferramentas de qualidade
Essas ferramentas são executadas de forma automática no pipeline do GitLab toda vez que um push é feito. Localmente, elas podem ser utilizadas manualmente no terminal por meio da execução dos seguintes comandos:

### flake8
```bash
flake8 app.py test_app.py
```
**Resultado esperado:** nenhum output (ausência de erros é sucesso).

### pytest
```bash
pytest test_app.py -v
```
**Resultado esperado:** `test_health` e `test_index` marcados como `PASSED`.

### bandit
```bash
bandit app.py test_app.py -ll
```
**Resultado esperado:** `No issues identified.` Issues de severidade `LOW` são suprimidas pela flag `-ll`.

### healthcheck.sh

Com a aplicação rodando (via Docker ou diretamente), execute em outro terminal:

```bash
# verifica o endpoint /health (localhost:5000/health)
sh healthcheck.sh

# ou especifique a URL do endpoint da raiz
sh healthcheck.sh http://localhost:5000/
```
**Resultado esperado:** `[O] API healthy (http://localhost:5000/health)`. Se a API não responder, retorna `[X] API unhealthy - HTTP 000 (http://localhost:5000/health)`.

O script retorna `exit 0` em sucesso e `exit 1` em falha, o que permite que ele seja usado em automações e scripts que dependem do código de saída.

---

## Documentação adicional
- [Decisões de arquitetura](docs/ARCHITECTURE.md)
- [Como a IA foi utilizada neste projeto](docs/AI_USAGE.md)
