#!/usr/bin/env bash
# Para quem JÁ TEM o Docker e o Scada-LTS rodando e quer MANTER o dele: sobe só o vpn-local, ligado ao SEU Scada-LTS,
# e aplica nele a configuração do laboratório (Data Sources, pontos, controles liga/desliga e a tela "Painel de comando").
# Nada do que você já tem no Scada-LTS é apagado ou parado.
#
#   ./so-vpn-local.sh                       (procura sozinho o container do Scada-LTS)
#   ./so-vpn-local.sh NOME_DO_CONTAINER     (nome mostrado por: docker ps)
#   ./so-vpn-local.sh --host                (Scada-LTS instalado direto no Linux/WSL, fora do Docker)
#   LAB_SO_CONFIG=1 ./so-vpn-local.sh ...   (só aplica a configuração, sem mexer no vpn-local)
#
# O vpn-local passa a usar a MESMA rede do seu Scada-LTS. Assim, no Scada-LTS, os dispositivos Modbus ficam em
# 127.0.0.11 a 127.0.0.14, porta 5020 (os mesmos endereços do pacote completo).
set -euo pipefail
cd "$(dirname "$0")"

command -v docker >/dev/null 2>&1 || { echo "ERRO: Docker não encontrado. Rode ./instalar.sh."; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERRO: o Docker não está rodando (abra o Docker Desktop ou rode: sudo service docker start)."; exit 1; }

# Nomes do container, da imagem e do volume do vpn-local (mude por variável de ambiente só se precisar)
NOME_CONTAINER="${VPN_LOCAL_CONTAINER:-vpn-local}"
IMAGEM="${VPN_LOCAL_IMAGEM:-lab/vpn-local:latest}"
VOLUME="${VPN_LOCAL_VOLUME:-vpn-local_data}"

ALVO="${1:-${LAB_ALVO:-}}"
if [ -z "$ALVO" ]; then
  mapfile -t achados < <(docker ps --format '{{.Names}}\t{{.Image}}' | grep -i scada | grep -v -F "$NOME_CONTAINER" | cut -f1)
  if [ "${#achados[@]}" = 1 ]; then
    ALVO="${achados[0]}"; echo "Container do Scada-LTS encontrado: $ALVO"
  else
    echo "Não achei um único container do Scada-LTS. Containers rodando:"; docker ps --format '  {{.Names}}  ({{.Image}})'
    read -rp "Digite o nome do container do Scada-LTS (ou --host): " ALVO
  fi
fi
if [ "$ALVO" = "--host" ]; then
  REDE="host"
else
  docker inspect -f '{{.State.Running}}' "$ALVO" 2>/dev/null | grep -q true || { echo "ERRO: o container '$ALVO' não está rodando."; exit 1; }
  REDE="container:$ALVO"
fi

[ -f .env ] || cp .env.example .env
sed -i 's/\r$//' .env
valor() { grep -E "^$1=" .env | head -1 | cut -d= -f2- || true; }
grava() { if grep -qE "^$1=" .env; then sed -i "s|^$1=.*|$1=$2|" .env; else echo "$1=$2" >> .env; fi; }

# ---------------------------------------------------------------------------------------------------------------
# Etapa 1: vpn-local
# ---------------------------------------------------------------------------------------------------------------
if [ "${LAB_SO_CONFIG:-0}" != 1 ]; then
  chave="$(valor CHAVE)"
  if ! docker volume inspect "$VOLUME" >/dev/null 2>&1 && [ -z "$chave" ]; then
    echo "Cole o seu token de ativação (site do laboratório > Meu laboratório > Copiar token)."
    read -rp "Token (começa com ak_): " chave
    chave="$(echo "$chave" | tr -d '[:space:]"'"'"'')"
    if ! [[ "$chave" =~ ^ak_[A-Za-z0-9_-]+$ ]]; then echo "ERRO: token inválido. Copie de novo, inteiro, sem espaços."; exit 1; fi
    grava CHAVE "$chave"
  fi
  servidor="$(valor SERVIDOR)"; servidor="${servidor:-https://scsep.joaopedromagalhaes.com.br}"
  nome="$(valor NOME)"; nome="${nome:-Scada-LTS (Docker)}"

  echo "Preparando o vpn-local..."
  docker build -q -t "$IMAGEM" ./vpn-local >/dev/null

  # Se já existe um container com esse nome que NÃO foi criado por este script (por exemplo, o do pacote completo),
  # pergunta antes de substituir.
  if docker inspect "$NOME_CONTAINER" >/dev/null 2>&1; then
    if [ "$(docker inspect -f '{{index .Config.Labels "lab.so-vpn-local"}}' "$NOME_CONTAINER")" != "1" ]; then
      read -rp "Já existe um container '$NOME_CONTAINER' que não foi criado por este script (talvez do pacote completo). Remover e substituir? [s/N] " resp
      [[ "$resp" =~ ^[sS]$ ]] || { echo "Cancelado. Nada foi alterado."; exit 1; }
    fi
    docker rm -f "$NOME_CONTAINER" >/dev/null
  fi

  docker run -d --name "$NOME_CONTAINER" --label lab.so-vpn-local=1 --restart unless-stopped --network "$REDE" \
    -e SERVIDOR="$servidor" -e CHAVE="$(valor CHAVE)" -e NOME="$nome" -v "$VOLUME":/data "$IMAGEM" >/dev/null

  echo "Aguardando o vpn-local falar com o servidor..."
  ok=0
  for _ in $(seq 1 30); do
    log="$(docker logs "$NOME_CONTAINER" 2>&1 | tail -20)"
    if echo "$log" | grep -q "ativada com sucesso\|credencial salva"; then echo "OK: vpn-local ativado e conectado."; ok=1; break; fi
    if echo "$log" | grep -q "ERRO na ativa"; then
      echo "$log" | grep "ERRO na ativa" | tail -1
      echo "Confira o token (site > Meu laboratório) e rode de novo."; exit 1
    fi
    sleep 2
  done
  [ "$ok" = 1 ] || echo "AVISO: ainda não confirmou. Veja: docker logs $NOME_CONTAINER"
fi

# ---------------------------------------------------------------------------------------------------------------
# Etapa 2: configuração do Scada-LTS (Data Sources, pontos, controles e tela). Só ADICIONA; nada é apagado.
# ---------------------------------------------------------------------------------------------------------------
echo
echo "Agora posso aplicar no SEU Scada-LTS a configuração do laboratório: 4 Data Sources, 34 pontos, 18 links"
echo "(controles liga/desliga) e a tela gráfica \"Painel de comando\". O que você já tem lá NÃO é apagado nem alterado."
if [ -n "${LAB_CONFIRMA:-}" ]; then resp="$LAB_CONFIRMA"; elif [ -r /dev/tty ]; then read -rp "Aplicar agora? [S/n] " resp < /dev/tty || resp="n"; else resp="n"; fi
if [[ "$resp" =~ ^[nN]$ ]]; then
  echo "Ok, não apliquei. Para aplicar depois: LAB_SO_CONFIG=1 ./so-vpn-local.sh $ALVO"
else
  # endereço do Scada-LTS: porta publicada do container (8080 por dentro) ou o IP do container
  URL="${SCADA_URL:-}"
  if [ -z "$URL" ] && [ "$REDE" != "host" ]; then
    porta="$(docker port "$ALVO" 8080/tcp 2>/dev/null | head -1 | awk -F: '{print $NF}')"
    if [ -n "$porta" ]; then URL="http://localhost:$porta/Scada-LTS"
    else
      ip="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' "$ALVO" | awk '{print $1}')"
      [ -n "$ip" ] && URL="http://$ip:8080/Scada-LTS"
    fi
  fi
  if [ -z "$URL" ]; then
    read -rp "Endereço do seu Scada-LTS [http://localhost:8080/Scada-LTS]: " URL < /dev/tty || true
    URL="${URL:-http://localhost:8080/Scada-LTS}"
  fi
  echo "Aplicando em $URL (pode levar até 1 minuto)..."
  saida="$(mktemp)"
  if ! python3 scada-lts/importar.py scada-lts/scada-lts-import.json "$URL" 2>&1 | tee "$saida"; then :; fi
  if grep -q "login recusado" "$saida" && [ -r /dev/tty ]; then
    echo "O admin do seu Scada-LTS não é admin/admin. Digite o usuário e a senha dele."
    read -rp "Usuário [admin]: " SCADA_USER < /dev/tty || true; export SCADA_USER="${SCADA_USER:-admin}"
    read -rsp "Senha: " SCADA_SENHA < /dev/tty || true; echo; export SCADA_SENHA
    python3 scada-lts/importar.py scada-lts/scada-lts-import.json "$URL" || echo "AVISO: não consegui aplicar. Veja a mensagem acima."
  fi
  rm -f "$saida"
fi

cat <<TXT

Pronto. No seu Scada-LTS, os dispositivos Modbus estão em (porta 5020):
  127.0.0.11  IED de proteção (disjuntor geral)
  127.0.0.12  CLP de geração (disjuntores do motor e do inversor)
  127.0.0.14  CLP do painel e motor (LEDs)
A tela "Painel de comando" fica no menu Graphic views.

Atenção: se você recriar o container do Scada-LTS, rode este script de novo (o vpn-local usa a rede dele).
TXT
