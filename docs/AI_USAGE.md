# AI_USAGE.md

Este documento descreve como a Inteligência Artificial foi utilizada
no projeto, escrito de forma pessoal e direta.
O modelo utilizado foi o Claude Sonnet 4.6.

O objetivo foi usar a IA como par de programação, não como oráculo —
nenhum código foi incorporado sem que eu entendesse o contexto e a
necessidade de cada decisão.

## Como estruturei os prompts

O fluxo de trabalho com a IA seguiu um padrão consistente ao longo do projeto:

**1. Contextualização antes de qualquer código**

Ao lidar com uma tecnologia desconhecida, o primeiro passo foi fornecer contexto
à IA: para que a ferramenta seria usada e, quando possível, uma analogia com
algo que eu já conhecia em outra linguagem ou contexto. Isso orientou as
explicações para o nível certo, sem partir do zero absoluto.

**2. Pesquisa independente em paralelo**

Com a explicação inicial em mãos, recorri à documentação oficial e a exemplos
disponíveis online para validar o que foi explicado e construir minha própria
compreensão da ferramenta.

**3. Construção de rascunhos próprios**

Com base na documentação e em experiências anteriores, construí rascunhos do
código para compreender a lógica e a estrutura semântica dos arquivos antes de
qualquer refinamento. Quando uma decisão de arquitetura parecia relevante mas eu
não sabia como implementá-la, registrava isso diretamente no rascunho como
comentário e esse comentário virava parte do prompt.

**4. Refinamento assistido**

Somente após entender a lógica envolvida, o rascunho era submetido à IA para
correções e adições. O papel da IA nessa etapa era o de revisor, não de autor.

**5. Interpretação independente de erros**

Diante de outputs de erro, o objetivo foi interpretar os logs de forma autônoma.
A IA era consultada apenas quando eu ficava genuinamente travada e, mesmo
nesses casos, o foco era entender a causa do erro, não apenas receber o fix.

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
