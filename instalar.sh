#!/usr/bin/env bash
# Instalação simples do Laboratório Virtual: instala o Docker (se faltar) e sobe tudo.
# Uso, dentro da pasta do pacote:  ./instalar.sh
set -euo pipefail
cd "$(dirname "$0")"

echo "== Laboratório Virtual: instalação =="
echo "Se o Ubuntu pedir a sua senha, digite-a (ela não aparece na tela) e aperte Enter."

# 1) Docker
if ! command -v docker >/dev/null 2>&1; then
  echo "Instalando o Docker (pode levar alguns minutos)..."
  sudo apt-get update
  sudo apt-get install -y docker.io || true
fi

# 2) Docker Compose (o comando "docker compose")
if ! sudo docker compose version >/dev/null 2>&1; then
  echo "Instalando o Docker Compose..."
  sudo apt-get install -y docker-compose-v2 || { echo "Usando o instalador oficial do Docker..."; curl -fsSL https://get.docker.com | sudo sh; }
fi

# 3) Serviço do Docker ligado
if ! sudo docker info >/dev/null 2>&1; then
  sudo systemctl enable --now docker >/dev/null 2>&1 || sudo service docker start
  sleep 3
fi

# 4) Seu usuário usa o Docker sem sudo (vale a partir da próxima vez que abrir o Ubuntu)
if ! id -nG "$USER" | grep -qw docker; then
  sudo usermod -aG docker "$USER"
fi

# 5) Pergunta o token e sobe o laboratório (já com o grupo docker, sem precisar reabrir o Ubuntu)
if docker info >/dev/null 2>&1; then
  exec ./iniciar.sh
else
  exec sg docker -c "./iniciar.sh"
fi
