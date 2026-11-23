#!/usr/bin/env bash
# Sobe o Scada-LTS + vpn-local. Na primeira vez pergunta o token de ativação e grava no arquivo .env.
# Uso (no terminal do WSL, dentro desta pasta):  ./iniciar.sh
set -euo pipefail
cd "$(dirname "$0")"

# Docker Desktop / Docker moderno: "docker compose". Docker antigo do apt: "docker-compose".
if docker compose version >/dev/null 2>&1; then DC="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then DC="docker-compose"
else echo "ERRO: Docker não encontrado. Rode o instalador do seu sistema (install-lab-ubuntu.sh, -debian, -kali ou -fedora)."; exit 1; fi
docker info >/dev/null 2>&1 || { echo "ERRO: o Docker não está rodando (abra o Docker Desktop ou rode: sudo service docker start)."; exit 1; }

[ -f .env ] || cp .env.example .env
sed -i 's/\r$//' .env   # tira o fim de linha do Windows, se o arquivo foi editado no Bloco de Notas

valor() { grep -E "^$1=" .env | head -1 | cut -d= -f2- || true; }
grava() { if grep -qE "^$1=" .env; then sed -i "s|^$1=.*|$1=$2|" .env; else echo "$1=$2" >> .env; fi; }

# O vpn-local guarda a credencial num volume; se ele existe, o token não é mais necessário.
ja_ativada=0
docker volume inspect scada-lab_vpn-local_data >/dev/null 2>&1 && ja_ativada=1

# Lê uma linha do teclado de verdade (o terminal), mesmo que a saída esteja sendo gravada em um arquivo de registro
ler() { # ler "pergunta" variavel
  local _r=""
  if ( : < /dev/tty ) 2>/dev/null; then printf '%s' "$1" > /dev/tty; read -r _r < /dev/tty || _r=""
  else read -rp "$1" _r || _r=""; fi
  printf -v "$2" '%s' "$_r"
}

chave="$(valor CHAVE)"
if [ "$ja_ativada" = 0 ] && [ -z "$chave" ] && [ "${LAB_SEM_TOKEN:-0}" != 1 ]; then
  cat <<'TXT'

=========================== TOKEN DE ACESSO ===========================
O token liga o seu laboratório ao servidor (é como a "chave" do seu usuário).
  1. Abra o site do laboratório e entre com o seu usuário e senha.
  2. Vá em "Meu laboratório" e clique em "Copiar token". Ele começa com  ak_
  3. Volte aqui, cole o token (botão direito do mouse, ou Ctrl+Shift+V) e aperte Enter.

Ainda não tem o token? Aperte só Enter: o laboratório sobe do mesmo jeito e
você coloca o token depois com:   ./adicionar-token.sh
=======================================================================
TXT
  tentativas=0
  while :; do
    ler "Token (ou só Enter para deixar para depois): " chave
    chave="$(echo "$chave" | tr -d '[:space:]"'"'"'')"
    if [ -z "$chave" ]; then LAB_SEM_TOKEN=1; echo "Ok, o token fica para depois."; break; fi
    if [[ "$chave" =~ ^ak_[A-Za-z0-9_-]+$ ]]; then grava CHAVE "$chave"; echo "Token recebido."; break; fi
    tentativas=$((tentativas + 1))
    if [ "$tentativas" -ge 3 ]; then LAB_SEM_TOKEN=1; echo "Não deu certo 3 vezes. Vamos deixar o token para depois (./adicionar-token.sh)."; break; fi
    echo "Esse token não parece certo: ele começa com ak_ e não tem espaços. Copie de novo, inteiro, e cole."
  done
fi

echo "Subindo os contêineres (na primeira vez baixa as imagens; pode levar alguns minutos)..."
$DC up -d --build

sem_token=0
if [ "${LAB_SEM_TOKEN:-0}" = 1 ] && [ "$ja_ativada" = 0 ] && [ -z "$(valor CHAVE)" ]; then sem_token=1; fi
[ "$sem_token" = 1 ] && echo "Token pendente: o vpn-local subiu, mas só se conecta ao servidor depois que você adicionar o token."
[ "$sem_token" = 1 ] || echo "Aguardando o vpn-local falar com o servidor..."
for _ in $(seq 1 30); do
  [ "$sem_token" = 1 ] && break
  log="$(docker logs vpn-local 2>&1 | tail -20)"
  if echo "$log" | grep -q "ativada com sucesso\|credencial salva"; then echo "OK: vpn-local ativado e conectado."; break; fi
  if echo "$log" | grep -q "ERRO na ativa"; then echo "$log" | grep "ERRO na ativa" | tail -1; echo "Confira o token (site > Meu laboratório) e rode ./iniciar.sh de novo."; exit 1; fi
  sleep 2
done

porta="$(valor SCADA_PORT)"; porta="${porta:-8080}"
echo "Aguardando o Scada-LTS iniciar (na primeira vez leva de 1 a 5 minutos)..."
if command -v curl >/dev/null 2>&1; then
  for _ in $(seq 1 150); do
    cod="$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${porta}/Scada-LTS/" || true)"
    [ "$cod" = "200" ] || [ "$cod" = "302" ] && break
    sleep 2
  done
fi
# Aplica a configuração do Scada-LTS (Data Sources, pontos, controles liga/desliga e a tela "Painel de comando").
# Só na primeira vez: reimportar reinicia os controles. Para refazer: apague o arquivo .scada-config-aplicada e rode de novo.
if [ ! -f .scada-config-aplicada ]; then
  if command -v python3 >/dev/null 2>&1; then
    echo "Aplicando a configuração do Scada-LTS (pode levar até 1 minuto)..."
    if python3 scada-lts/importar.py scada-lts/scada-lts-import.json "http://localhost:${porta}/Scada-LTS"; then
      touch .scada-config-aplicada
    else
      echo "AVISO: não consegui importar sozinho. Rode: python3 scada-lts/importar.py (ou importe scada-lts/scada-lts-import.json em Import/Export)."
    fi
  else
    echo "AVISO: python3 não encontrado. Importe à mão o arquivo scada-lts/scada-lts-import.json em Import/Export."
  fi
fi

echo
[ "$sem_token" = 1 ] && echo "FALTA SÓ O TOKEN. Quando tiver (site > Meu laboratório > Copiar token), rode:  cd $PWD && ./adicionar-token.sh"
echo "Pronto. Abra no navegador do Windows:  http://localhost:${porta}/Scada-LTS/   (admin / admin)"
