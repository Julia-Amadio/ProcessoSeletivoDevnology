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

## Exemplo 1: prompt abordando implementação inicial do Dockerfile
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

## Exemplo 2: prompt abordando entendimento inicial do provisionamento da ECS com Terraform
```
minha experiência anterior em usar o terraform como ferramenta de provisionamento 
foi para subir uma instância da EC2. já tenho AWS CLI e o terraform instalados na 
máquina de desenvolvimento, então isso facilita. sei usar AWS IAM e já tenho o 
aws configure feito com um usuário não-root, podendo tbm configurar outro profile.
entendo como a ferramenta é utilizada: nao dizemos como fazer, mas sim declaramos 
o estado final desejado (ex: "quero 1 EC2 rodando Ubuntu"). 

- terraform.tf define plugins necessários, definindo versões para o provider da aws 
e do terraform em si. interessante fazer o pinning.
- main.tf define a região da AWS onde isso vai ser provisionado e todas as outras 
propriedades do recurso de compute.

minha dúvida é o quão diferente é provisionar ECS e EC2. com EC2, no main.tf 
configuramos um acesso com SSH ou SSM (sendo o SSM o gold standard). temos um bloco
no main.tf pra query na API localizar o id da máquina, outros pra gestão de identidade 
e acesso (definir IAM role, policy attachment, etc), definir o security group com regras
de ingress e egress e, por fim, o ultimo bloco pra definir as caracteristicas do recurso
de compute.
porém SSM pra um contêiner me soa um pouco esquisito. então eu imagino que aqui o foco 
está em permitir a criação dele somente (posso estar errada!), pois o management já é 
feito pelo pipeline - falhou um stage, não sobe. como quem vai subir esse container na 
web é o pipeline, o pipeline precisa saber quais quais são as credenciais, e isso deve 
ser injetado pelas variáveis sem hardcoding.
```

## Exemplo 3: conversa abordando Docker Compose (*case* de "erro")
O prompt inicial foi fornecido com dois exemplos:
- Uma implementação de `docker-compose.yml` utilizada em outro projeto à parte, com 
explicação sobre as diferenças de contexto;
- Esqueleto construído a partir de conhecimento já existente sobre a ferramenta.
```
o que entendo de docker-compose foi totalmente construído por meio do desenvolvimento 
de outros projetos java.

services:
  db:
    image: postgres:15-alpine
    container_name: postgres-flashcards
    restart: unless-stopped
    environment:
      POSTGRES_DB: flashcards_db
      POSTGRES_USER: flashcards_admin
      POSTGRES_PASSWORD: password123
    ports:
      - "5434:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:

o acima foi feito pra subir uma instância local do postgresql pra que, durante o 
desenvolvimento, o dev pudesse rodar o banco da aplicação Spring Boot e fazer as 
queries localmente, sem que qualquer mudança refletisse no banco da nuvem (neon) 
que estava na .env. localhost:5434 era a porta onde o db ia abrir (5232 e 5233 ja 
estavam ocupadas c outros bancos).

como aqui em python nao temos db, acho q nosso docker-compose é pra definir a 
imagem usada, nome do container e volumes:
services:
  api:
    build: .
    container_name: devnology-api
    # Reinicia automaticamente se o container cair
    restart: unless-stopped
    ports:
      - "5000:5000"
    volumes:
      # Nao sei o que vem aqui!
```

A resposta do Claude foi que volumes também não eram necessários, já que a aplicação 
não persiste nada em disco — isso está correto. Entretanto, a correção fornecida pela 
IA foi a seguinte:
```
services:
  api:
    # Builda a imagem a partir do Dockerfile na pasta atual
    build: .
    container_name: devnology-api
    # Reinicia automaticamente se o container cair (útil em produção)
    restart: unless-stopped
    ports:
      - "5000:5000"
    # Variáveis de ambiente para configuração sem alterar o código
    environment:
      - FLASK_ENV=production
```

A variável de ambiente `FLASK_ENV=production` levantou algumas bandeiras vermelhas. 
Não tinha visto a mesma declarada antes em qualquer outra parte do código, nem entendi 
para quê servia. Ao pesquisar sobre a mesma pela busca padrão descobri que ela foi 
**descontinuada** na versão 2.3 do Flask — o projeto utiliza a 3.0.
O que ele controlava foi separado em duas variáveis menores:
- `FLASK_DEBUG=0`: desativa o modo debug (nunca deve estar ativo em produção pois 
expõe traceback completo para o usuário);
- `FLASK_ENV`: não faz mais nada na versão atual.

O compose atual não levou o bloco `environment` junto em nenhuma de suas versões. 
Como estamos usando gunicorn em vez do servidor embutido do Flask, e o `app.run()` só 
executa se chamado diretamente, na prática nenhuma dessas variáveis afeta o comportamento 
do container.
