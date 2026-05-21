# Importa a instância Flask
from app import app


# O Flask tem um cliente de teste embutido que simula requisições HTTP
# sem precisar subir um servidor de verdade. Esse teste verifica:
#   1. Que a rota retorna status 200 OK
#   2. Que o campo status no JSON é "healthy"
def test_health():
    client = app.test_client()
    response = client.get('/health')
    assert response.status_code == 200
    assert response.json["status"] == "healthy"


# Só verifica que a rota raiz responde, não valida conteúdo do JSON
def test_index():
    client = app.test_client()
    response = client.get('/')
    assert response.status_code == 200
