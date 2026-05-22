# AI_USAGE.md

Este documento descreve como a Inteligência Artificial foi utilizada
no projeto, escrito de forma pessoal e direta.
O modelo utilizado foi o Claude Sonnet 4.6.

O objetivo foi usar a IA como par de programação, não como oráculo —
nenhum código foi incorporado sem que eu entendesse o contexto e a
necessidade de cada decisão.

## Como estruturei os prompts

- Para tecnologias com as quais nunca tive contato, o primeiro passo
foi pedir uma descrição superficial do funcionamento — o suficiente
para conseguir navegar pela documentação oficial e exemplos online.

- Com esse contexto, construí protótipos do código à mão, baseando-me
na documentação e em experiências passadas com ferramentas similares.
Quando uma decisão de arquitetura era importante mas eu não sabia
implementar, o protótipo vinha com comentários explicitando isso.

- Somente depois, a IA era consultada para refinamento do protótipo.

- Em casos de erro, o objetivo era interpretar os logs de forma
independente, recorrendo à IA apenas quando ficava realmente presa.

## Exemplo: prompt abordando implementação inicial do Dockerfile
```
Eu entendo o conceito de multi-stage. Em uma aplicação em C ou golang, por exemplo, 
precisaríamos de um stage de build (compilar a aplicação em um binário executável), 
porém isso não existe aqui com o Python. Do que percebo, precisaremos de um primeiro
stage para a instalar as dependências e gerar os pacotes, e outro que parte da
imagem limpa para copiar os pacotes e expor a porta com o comando de execução.

# --- Stage 1 ---
# Imagem base
FROM python:3.12-slim
 
#Define um diretório de trabalho limpo
WORKDIR /app

# Copia o requirements.txt primeiro
COPY requirements.txt .
#Instala todas as dependências
RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt

# --- Stage 2 ---
FROM python:3.12-slim

WORKDIR /app

# Copia o código da aplicação
COPY app.py .

# Expõe porta
EXPOSE 5000

# Comando de execução
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]

Indique correções e adições necessárias para este protótipo que construí.
Acho que dois stages são suficientes. 
```
