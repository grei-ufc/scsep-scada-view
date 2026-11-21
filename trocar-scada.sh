#!/usr/bin/env bash
# Para quem JÁ TEM o Docker e um Scada-LTS rodando: PARA o seu Scada-LTS (sem apagar nada), baixa e roda o do
# laboratório, que já vem com o vpn-local. Cole no terminal do Ubuntu:
#   curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/trocar-scada.sh | bash
# Para voltar ao seu Scada-LTS depois: ./voltar-ao-scada-anterior.sh (criado por este script, na pasta do pacote).
set -euo pipefail

REPO="https://github.com/grei-ufc/scsep-scada-view.git"
DESTINO="$HOME/scsep-scada-view"
NOMES="${LAB_NOMES:-rede mysql vpn-local scadalts}"   # nomes de containers que o pacote usa
PORTA="${LAB_PORTA:-8080}"                              # porta do Scada-LTS do pacote

command -v docker >/dev/null 2>&1 || { echo "ERRO: Docker não encontrado. Use o instalador completo (instalar.sh do README)."; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERRO: o Docker não está rodando ou você não tem acesso. Tente: sudo service docker start"; exit 1; }

# 0) Pacote: se não está na pasta dele, baixa e continua de lá
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -z "$AQUI" ] || [ ! -f "$AQUI/docker-compose.yml" ]; then
  echo "Baixando o pacote do laboratório para $DESTINO ..."
  command -v git >/dev/null 2>&1 || { sudo apt-get update && sudo apt-get install -y git; }
  if [ -d "$DESTINO/.git" ]; then git -C "$DESTINO" pull --ff-only || echo "(usando a versão que já está aí)"; else git clone "$REPO" "$DESTINO"; fi
  cd "$DESTINO"
  if [ -r /dev/tty ] && ! [ -t 0 ]; then exec bash ./trocar-scada.sh < /dev/tty; else exec bash ./trocar-scada.sh; fi
fi
cd "$AQUI"

# 1) O que atrapalha: containers com os nomes do pacote (que não sejam do próprio pacote) ou usando a porta
do_pacote() { [ "$(docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$1" 2>/dev/null)" = "scada-lab" ]; }
lista=()
for n in $NOMES; do docker inspect "$n" >/dev/null 2>&1 && ! do_pacote "$n" && lista+=("$n"); done
while read -r n; do
  [ -n "$n" ] || continue
  do_pacote "$n" && continue
  [[ " ${lista[*]:-} " == *" $n "* ]] || lista+=("$n")
done < <(docker ps --filter "publish=$PORTA" --format '{{.Names}}')

if [ "${#lista[@]}" = 0 ]; then
  echo "Não achei nenhum Scada-LTS seu para parar."
else
  echo "Estes containers atrapalham (nomes iguais aos do laboratório ou usam a porta $PORTA):"
  for n in "${lista[@]}"; do docker ps -a --filter "name=^/$n\$" --format '  {{.Names}}  ({{.Image}}, {{.Status}})'; done
  echo "Vou PARAR (nada será apagado) e, quando o nome for igual ao do laboratório, renomear com o sufixo -anterior."
  if [ -n "${LAB_CONFIRMA:-}" ]; then resp="$LAB_CONFIRMA"; elif [ -r /dev/tty ]; then read -rp "Continuar? [s/N] " resp < /dev/tty; else resp="n"; fi
  [[ "$resp" =~ ^[sS]$ ]] || { echo "Cancelado. Nada foi alterado."; exit 1; }

  carimbo="$(date +%Y%m%d%H%M)"
  volta=("#!/usr/bin/env bash" "# Volta ao Scada-LTS que você tinha antes (gerado por trocar-scada.sh em $carimbo)." "set -e" 'cd "$(dirname "$0")"'
         'echo "Parando o laboratório..."; docker compose down >/dev/null 2>&1 || true')
  iniciar=()
  for n in "${lista[@]}"; do
    rodando="$(docker inspect -f '{{.State.Running}}' "$n")"
    [ "$rodando" = true ] && docker stop "$n" >/dev/null
    novo="$n"
    for p in $NOMES; do
      if [ "$p" = "$n" ]; then novo="$n-anterior-$carimbo"; docker rename "$n" "$novo"; volta+=("docker rename $novo $n"); fi
    done
    [ "$rodando" = true ] && iniciar+=("$n")
    echo "  parado: $n${novo:+ -> $novo}"
  done
  volta+=("docker start ${iniciar[*]:-} >/dev/null 2>&1 || true" 'echo "Pronto: o seu Scada-LTS anterior voltou."')
  printf '%s\n' "${volta[@]}" > voltar-ao-scada-anterior.sh; chmod +x voltar-ao-scada-anterior.sh
  echo "Para voltar ao seu Scada-LTS depois: ./voltar-ao-scada-anterior.sh (na pasta $PWD)"
fi

# 2) Se a porta ainda estiver ocupada (por um programa fora do Docker), usa a 8088
if command -v ss >/dev/null 2>&1 && ss -ltn 2>/dev/null | grep -q ":$PORTA "; then
  echo "A porta $PORTA continua ocupada por outro programa: o laboratório vai usar a 8088."
  [ -f .env ] || cp .env.example .env
  if grep -qE '^SCADA_PORT=' .env; then sed -i 's|^SCADA_PORT=.*|SCADA_PORT=8088|' .env; else echo "SCADA_PORT=8088" >> .env; fi
fi

[ "${TROCAR_SO_PREPARAR:-0}" = 1 ] && { echo "(modo teste: parou aqui)"; exit 0; }
exec bash ./instalar.sh
