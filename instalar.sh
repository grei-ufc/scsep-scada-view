#!/usr/bin/env bash
# Instalação simples do Laboratório Virtual. Serve para quem só tem o WSL com Ubuntu:
# baixa o pacote (instala o git se faltar), instala Docker, Compose e python3 se faltarem, e sobe tudo.
#
#   Sem ter baixado nada (cole no Ubuntu):
#     sudo apt update && sudo apt install -y curl && curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/instalar.sh | bash
#   Com o pacote já baixado, dentro da pasta:
#     ./instalar.sh
set -euo pipefail

REPO="https://github.com/grei-ufc/scsep-scada-view.git"
DESTINO="$HOME/scsep-scada-view"

APT_ATUALIZADO=0
apt_instalar() {
  if [ "$APT_ATUALIZADO" = 0 ]; then sudo apt-get update; APT_ATUALIZADO=1; fi
  sudo apt-get install -y "$@"
}

echo "== Laboratório Virtual: instalação =="
echo "Se o Ubuntu pedir a sua senha, digite-a (ela não aparece na tela) e aperte Enter."

# 0) Pacote: se este script não está dentro da pasta do pacote, baixa o pacote primeiro e continua de lá
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -z "$AQUI" ] || [ ! -f "$AQUI/docker-compose.yml" ]; then
  echo "Baixando o pacote do laboratório para $DESTINO ..."
  command -v git >/dev/null 2>&1 || apt_instalar git
  if [ -d "$DESTINO/.git" ]; then
    git -C "$DESTINO" pull --ff-only || echo "(não consegui atualizar; usando a versão que já está aí)"
  else
    git clone "$REPO" "$DESTINO"
  fi
  if [ "${INSTALAR_SO_BAIXAR:-0}" = 1 ]; then echo "Pacote baixado em $DESTINO"; exit 0; fi
  cd "$DESTINO"
  # quando o script vem por "curl | bash", o teclado precisa vir do terminal (para perguntar o token)
  if [ -r /dev/tty ] && ! [ -t 0 ]; then exec bash ./instalar.sh < /dev/tty; else exec bash ./instalar.sh; fi
fi
cd "$AQUI"

# 1) Docker
if ! command -v docker >/dev/null 2>&1; then
  echo "Instalando o Docker (pode levar alguns minutos)..."
  apt_instalar docker.io || true
fi

# 2) Docker Compose (o comando "docker compose")
if ! sudo docker compose version >/dev/null 2>&1; then
  echo "Instalando o Docker Compose..."
  apt_instalar docker-compose-v2 || {
    echo "Usando o instalador oficial do Docker..."
    command -v curl >/dev/null 2>&1 || apt_instalar curl
    curl -fsSL https://get.docker.com | sudo sh
  }
fi

# 3) python3 (usado para aplicar a configuração do Scada-LTS)
command -v python3 >/dev/null 2>&1 || apt_instalar python3

# 4) Serviço do Docker ligado
if ! sudo docker info >/dev/null 2>&1; then
  sudo systemctl enable --now docker >/dev/null 2>&1 || sudo service docker start
  sleep 3
fi

# 5) Seu usuário usa o Docker sem sudo (vale a partir da próxima vez que abrir o Ubuntu)
if ! id -nG "$USER" | grep -qw docker; then
  sudo usermod -aG docker "$USER"
fi

# 6) Pergunta o token e sobe o laboratório (já com o grupo docker, sem precisar reabrir o Ubuntu)
if docker info >/dev/null 2>&1; then
  exec ./iniciar.sh
else
  exec sg docker -c "./iniciar.sh"
fi
