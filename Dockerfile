# =============================================================================
# STAGE 1: builder. Instala dependências em um ambiente completo.
# Tudo que for ferramenta de build fica aqui e não vai para a imagem final.
# =============================================================================
FROM python:3.12-slim AS builder

WORKDIR /app

# Copia só o requirements.txt primeiro.
# O Docker cacheia cada instrução como uma "layer". Se copiarmos
# só o requirements.txt aqui, o pip só roda novamente quando esse arquivo
# mudar e não a cada alteração no código da aplicação.
COPY requirements.txt .

# Instala as dependências em uma pasta isolada (/install).
# --no-cache-dir: não salva cache do pip, reduz tamanho da imagem.
# --prefix: instala em pasta separada para facilitar a cópia no stage final.
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# =============================================================================
# STAGE 2: final. Imagem limpa de execução. 
# Não contém pip, gcc nem ferramentas de build.
# =============================================================================
FROM python:3.12-slim

WORKDIR /app

# Cria usuário não-root antes de copiar qualquer coisa.
# Rodar como root dentro de um container é um risco de segurança:
# se a aplicação for comprometida, o atacante teria privilégios de root.
RUN adduser --disabled-password --gecos "" appuser
# 1. --disabled-password: o usuário não tem senha, ou seja, ninguém consegue fazer 
#    login interativo como ele. Para um container isso é o correto, nenhum 
#    humano vai "logar" nele.
# 2. --gecos "": GECOS é um campo antigo do Unix que armazena informações pessoais 
#    do usuário (nome completo, telefone, etc). A flag vazia pula essas perguntas 
#    interativas que o adduser normalmente faria.
# 3. appuser: o nome do usuário criado.
# O objetivo aqui é ter um usuário com o mínimo de privilégios possível.

# Copia os pacotes instalados no stage builder para o path padrão do Python.
COPY --from=builder /install /usr/local

# Copia o código da aplicação.
COPY app.py .

# Transfere a propriedade dos arquivos para o usuário não-root.
RUN chown -R appuser:appuser /app

# Troca para o usuário não-root. Tudo daqui em diante roda como appuser.
USER appuser

# Documenta que o container escuta na porta 5000.
# Não abre a porta sozinho, quem faz o mapeamento real é o docker run ou compose.
EXPOSE 5000

# Verifica se o container está saudável a cada 30 segundos, enquanto ativo.
# Se /health demora mais que 5 segundos para responder, resulta em timeout. 
# Realiza três tentativas.
# Caso ocorram três falhas consecutivas, o container é marcado como 'unhealthy',
# e o orquestrador pode reiniciá-lo ou tirar ele do load balancer.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" || exit 1

# Comando de execução.
# Usamos gunicorn em vez de "python app.py" porque o servidor embutido do Flask
# não é adequado para produção, sendo single-thread e sem tratamento de erros HTTP.
# workers 2: duas threads para atender requisições simultâneas (adequado para free tier).
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
