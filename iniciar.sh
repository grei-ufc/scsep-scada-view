#!/usr/bin/env bash
# Sobe o Scada-LTS + Ponte. Na primeira vez pergunta o token de ativação e grava no arquivo .env.
# Uso (no terminal do WSL, dentro desta pasta):  ./iniciar.sh
set -euo pipefail
cd "$(dirname "$0")"

# Docker Desktop / Docker moderno: "docker compose". Docker antigo do apt: "docker-compose".
if docker compose version >/dev/null 2>&1; then DC="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then DC="docker-compose"
else echo "ERRO: Docker não encontrado. Veja o passo 1 do tutorial."; exit 1; fi
docker info >/dev/null 2>&1 || { echo "ERRO: o Docker não está rodando (abra o Docker Desktop ou rode: sudo service docker start)."; exit 1; }

[ -f .env ] || cp .env.example .env
sed -i 's/\r$//' .env   # tira o fim de linha do Windows, se o arquivo foi editado no Bloco de Notas

valor() { grep -E "^$1=" .env | head -1 | cut -d= -f2- || true; }
grava() { if grep -qE "^$1=" .env; then sed -i "s|^$1=.*|$1=$2|" .env; else echo "$1=$2" >> .env; fi; }

# A Ponte guarda a credencial num volume; se ele existe, o token não é mais necessário.
ja_ativada=0
docker volume inspect scada-lab_ponte_data >/dev/null 2>&1 && ja_ativada=1

chave="$(valor CHAVE)"
if [ "$ja_ativada" = 0 ] && [ -z "$chave" ]; then
  echo "Cole o seu token de ativação (site do laboratório > Meu laboratório > Copiar token)."
  read -rp "Token (começa com ak_): " chave
  chave="$(echo "$chave" | tr -d '[:space:]"'"'"'')"
  if ! [[ "$chave" =~ ^ak_[A-Za-z0-9_-]+$ ]]; then echo "ERRO: token inválido. Copie de novo, inteiro, sem espaços."; exit 1; fi
  grava CHAVE "$chave"
fi

echo "Subindo os contêineres (na primeira vez baixa as imagens; pode levar alguns minutos)..."
$DC up -d --build

echo "Aguardando a Ponte falar com o servidor..."
for _ in $(seq 1 30); do
  log="$(docker logs ponte 2>&1 | tail -20)"
  if echo "$log" | grep -q "ativada com sucesso\|credencial salva"; then echo "OK: Ponte ativada e conectada."; break; fi
  if echo "$log" | grep -q "ERRO na ativa"; then echo "$log" | grep "ERRO na ativa" | tail -1; echo "Veja a seção \"Se algo der errado\" do tutorial."; exit 1; fi
  sleep 2
done

porta="$(valor SCADA_PORT)"; porta="${porta:-8080}"
echo "Aguardando o Scada-LTS iniciar (1 a 3 minutos)..."
if command -v curl >/dev/null 2>&1; then
  for _ in $(seq 1 90); do
    cod="$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${porta}/Scada-LTS/" || true)"
    [ "$cod" = "200" ] || [ "$cod" = "302" ] && break
    sleep 2
  done
fi
echo
echo "Pronto. Abra no navegador do Windows:  http://localhost:${porta}/Scada-LTS/   (admin / admin)"
