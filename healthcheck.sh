#!/bin/bash
# healthcheck.sh - verifica se a API está respondendo corretamente

URL="${1:-http://localhost:5000/health}"

response=$(curl -s -o /dev/null -w "%{http_code}" "$URL")

if [ "$response" = "200" ]; then
  echo "[O] API healthy ($URL)"
  exit 0
else
  echo "[X] API unhealthy - HTTP $response ($URL)"
  exit 1
fi
