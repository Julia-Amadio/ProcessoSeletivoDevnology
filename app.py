# Importa o Flask e função para converter dicionários Python em JSON
from flask import Flask, jsonify
# Importa módulo de data/hora da bib padrão
from datetime import datetime

'''
Cria instância da aplicação
    __name__ é uma var que contém o nome do módulo atual.
    Flask usa isto para saber onde está o arquivo raiz do projeto.
'''
app = Flask(__name__)

'''
Quando alguém faz GET em /health, essa função é executada e retorna um JSON. 
O health check é onde o ECS (ou qualquer orquestrador) bate periodicamente 
para saber se o container está vivo e respondendo.
'''
@app.route('/health')
def health():
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "version": "1.0.0"
    })

# Rota raiz, só confirma que a API está no ar.
@app.route('/')
def index():
    return jsonify({"message": "Trainee DevOps API"})

'''
Só executa o servidor se o arquivo for chamado diretamente. 
0.0.0.0 faz com que escute em todas as interfaces de rede,
necessário dentro de um container para que requisições externas cheguem.
'''

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)