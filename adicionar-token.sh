#!/usr/bin/env bash
# Adiciona (ou troca) o token de ativação do vpn-local, depois que o laboratório já foi instalado.
#   ./adicionar-token.sh                 (pergunta o token)
#   ./adicionar-token.sh ak_xxxxxxxxx    (já com o token)
# Onde pegar o token: site do laboratório > Meu laboratório > Token de ativação > Copiar token.
set -euo pipefail
cd "$(dirname "$0")"

if docker compose version >/dev/null 2>&1; then DC="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then DC="docker-compose"
else echo "ERRO: Docker Compose não encontrado. Rode ./instalar.sh."; exit 1; fi
docker info >/dev/null 2>&1 || { echo "ERRO: o Docker não está rodando ou você não tem acesso (feche e abra o Ubuntu; ou: sudo service docker start)."; exit 1; }

[ -f .env ] || cp .env.example .env
sed -i 's/\r$//' .env
grava() { if grep -qE "^$1=" .env; then sed -i "s|^$1=.*|$1=$2|" .env; else echo "$1=$2" >> .env; fi; }

chave="${1:-}"
if [ -z "$chave" ]; then
  echo "Cole o seu token de ativação (site do laboratório > Meu laboratório > Copiar token)."
  read -rp "Token (começa com ak_): " chave
fi
chave="$(echo "$chave" | tr -d '[:space:]"'"'"'')"
if ! [[ "$chave" =~ ^ak_[A-Za-z0-9_-]+$ ]]; then echo "ERRO: token inválido. Copie de novo, inteiro, sem espaços."; exit 1; fi
grava CHAVE "$chave"

echo "Aplicando o token no vpn-local..."
$DC rm -sf vpn-local >/dev/null 2>&1 || true            # para o vpn-local (o Scada-LTS continua rodando)
docker volume rm scada-lab_vpn-local_data >/dev/null 2>&1 || true   # esquece uma credencial anterior, se houver
$DC up -d vpn-local >/dev/null

ok=0
for _ in $(seq 1 30); do
  log="$(docker logs vpn-local 2>&1 | tail -20)"
  if echo "$log" | grep -q "ativada com sucesso\|credencial salva"; then echo "OK: vpn-local ativado e conectado ao seu laboratório."; ok=1; break; fi
  if echo "$log" | grep -q "ERRO na ativa"; then
    echo "$log" | grep "ERRO na ativa" | tail -1
    echo "Confira o token (site > Meu laboratório) e rode ./adicionar-token.sh de novo."; exit 1
  fi
  sleep 2
done
[ "$ok" = 1 ] || echo "AVISO: ainda não confirmou. Veja: docker logs vpn-local"
