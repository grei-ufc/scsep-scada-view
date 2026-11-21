#!/usr/bin/env bash
# Instalação do Laboratório Virtual: UM comando só, para quem tem só o WSL/Ubuntu, para quem já tem o Docker
# e também para quem já tem um Scada-LTS rodando (o dele é PARADO, sem apagar nada, e você pode voltar a ele).
#   Cole no terminal do Ubuntu:
#     sudo apt update && sudo apt install -y curl && curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/instalar.sh | bash
#   Com o pacote já baixado, dentro da pasta:  ./instalar.sh
set -euo pipefail

REPO="https://github.com/grei-ufc/scsep-scada-view.git"
DESTINO="$HOME/scsep-scada-view"
NOMES="${LAB_NOMES:-rede mysql vpn-local scadalts}"   # nomes de containers que o pacote usa
PORTA="${LAB_PORTA:-8080}"                              # porta do Scada-LTS do pacote

APT_ATUALIZADO=0
eh_kali() { [ "${LAB_KALI:-0}" = 1 ] || grep -qi '^ID=kali' /etc/os-release 2>/dev/null; }
apt_atualizar() {
  sudo apt-get update && return 0
  if eh_kali; then
    echo "O apt reclamou das chaves do Kali. Atualizando a chave do repositório..."
    sudo curl -fsSL -o /usr/share/keyrings/kali-archive-keyring.gpg https://archive.kali.org/archive-keyring.gpg || true
    sudo apt-get update && return 0
  fi
  return 1
}
apt_instalar() {
  if [ "$APT_ATUALIZADO" = 0 ]; then apt_atualizar; APT_ATUALIZADO=1; fi
  sudo apt-get install -y "$@"
}

echo "== Laboratório Virtual: instalação =="
eh_kali && echo "(Kali Linux detectado: usando os pacotes do Debian/Kali)"
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
  # quando o script vem por "curl | bash", o teclado precisa vir do terminal (para as perguntas e o token)
  if [ -r /dev/tty ] && ! [ -t 0 ]; then exec bash ./instalar.sh < /dev/tty; else exec bash ./instalar.sh; fi
fi
cd "$AQUI"

# 1) Docker e Docker Compose, numa rodada só do apt. O nome do pacote do Compose muda conforme a distribuição:
#    Ubuntu: docker-compose-v2 | Debian/Kali: docker-compose (v2) | outros: docker-compose-plugin
tem_docker() { command -v docker >/dev/null 2>&1; }
tem_candidato() { local c; c="$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print $2}')"; [ -n "$c" ] && [ "$c" != "(none)" ]; }
tem_compose() { sudo docker compose version >/dev/null 2>&1 || command -v docker-compose >/dev/null 2>&1; }
if ! tem_docker || ! tem_compose; then
  echo "Instalando o Docker e o Docker Compose (pode levar alguns minutos)..."
  if [ "$APT_ATUALIZADO" = 0 ]; then apt_atualizar || true; APT_ATUALIZADO=1; fi
  pacotes=()
  tem_docker || pacotes+=(docker.io)
  if ! tem_compose; then
    for p in docker-compose-v2 docker-compose-plugin docker-compose; do
      if tem_candidato "$p"; then pacotes+=("$p"); break; fi
    done
  fi
  [ "${#pacotes[@]}" -gt 0 ] && { apt_instalar "${pacotes[@]}" || true; }
  # confere o resultado; se faltar algo, usa o instalador oficial do Docker
  if ! tem_docker || ! tem_compose; then
    if eh_kali; then
      echo "ERRO: não consegui instalar o Docker pelo apt do Kali (veja as mensagens acima). Tente: sudo apt update && sudo apt install -y docker.io docker-compose"
      exit 1
    fi
    echo "Usando o instalador oficial do Docker..."
    command -v curl >/dev/null 2>&1 || apt_instalar curl
    curl -fsSL https://get.docker.com | sudo sh
  fi
fi

# 2) (o Compose já foi instalado acima)

# 3) python3 (usado para aplicar a configuração do Scada-LTS)
command -v python3 >/dev/null 2>&1 || apt_instalar python3

[ "${INSTALAR_SO_PACOTES:-0}" = 1 ] && { echo "(modo teste: pacotes instalados)"; exit 0; }

# 4) Serviço do Docker ligado
if ! sudo docker info >/dev/null 2>&1; then
  sudo systemctl enable --now docker >/dev/null 2>&1 || sudo service docker start
  sleep 3
fi

# 5) Seu usuário usa o Docker sem sudo (vale a partir da próxima vez que abrir o Ubuntu)
if ! id -nG "$USER" | grep -qw docker; then
  sudo usermod -aG docker "$USER"
fi

# 6) Se você JÁ TEM um Scada-LTS rodando, o dele é PARADO (nada é apagado) para não conflitar com o do laboratório.
DK="docker"; docker info >/dev/null 2>&1 || DK="sudo docker"
do_pacote() { [ "$($DK inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$1" 2>/dev/null)" = "scada-lab" ]; }
lista=()
for n in $NOMES; do $DK inspect "$n" >/dev/null 2>&1 && ! do_pacote "$n" && lista+=("$n"); done
while read -r n; do
  [ -n "$n" ] || continue
  do_pacote "$n" && continue
  [[ " ${lista[*]:-} " == *" $n "* ]] || lista+=("$n")
done < <($DK ps --filter "publish=$PORTA" --format '{{.Names}}')

if [ "${#lista[@]}" -gt 0 ]; then
  echo
  echo "Achei um Scada-LTS (ou containers com os mesmos nomes do laboratório / usando a porta $PORTA):"
  for n in "${lista[@]}"; do $DK ps -a --filter "name=^/$n\$" --format '  {{.Names}}  ({{.Image}}, {{.Status}})'; done
  echo "Vou PARAR esses containers (nada será apagado) e, quando o nome for igual ao do laboratório, renomear com o sufixo -anterior."
  if [ -n "${LAB_CONFIRMA:-}" ]; then resp="$LAB_CONFIRMA"; elif [ -r /dev/tty ]; then read -rp "Continuar? [s/N] " resp < /dev/tty; else resp="n"; fi
  [[ "$resp" =~ ^[sS]$ ]] || { echo "Cancelado. Nada foi alterado."; exit 1; }

  carimbo="$(date +%Y%m%d%H%M)"
  volta=("#!/usr/bin/env bash" "# Volta ao Scada-LTS que você tinha antes (gerado por instalar.sh em $carimbo)." "set -e" 'cd "$(dirname "$0")"'
         'echo "Parando o laboratório..."; docker compose down >/dev/null 2>&1 || true')
  iniciar_de_novo=()
  for n in "${lista[@]}"; do
    rodando="$($DK inspect -f '{{.State.Running}}' "$n")"
    [ "$rodando" = true ] && $DK stop "$n" >/dev/null
    novo="$n"
    for p in $NOMES; do
      if [ "$p" = "$n" ]; then novo="$n-anterior-$carimbo"; $DK rename "$n" "$novo"; volta+=("docker rename $novo $n"); fi
    done
    [ "$rodando" = true ] && iniciar_de_novo+=("$n")
    echo "  parado: $n -> $novo"
  done
  volta+=("docker start ${iniciar_de_novo[*]:-} >/dev/null 2>&1 || true" 'echo "Pronto: o seu Scada-LTS anterior voltou."')
  printf '%s\n' "${volta[@]}" > voltar-ao-scada-anterior.sh; chmod +x voltar-ao-scada-anterior.sh
  echo "Para voltar ao seu Scada-LTS depois: cd $PWD && ./voltar-ao-scada-anterior.sh"
  echo
fi

# 6b) Se a porta ainda estiver ocupada (por um programa fora do Docker), o laboratório usa a 8088
if command -v ss >/dev/null 2>&1 && ss -ltn 2>/dev/null | grep -q ":$PORTA "; then
  echo "A porta $PORTA continua ocupada por outro programa: o laboratório vai usar a 8088."
  [ -f .env ] || cp .env.example .env
  if grep -qE '^SCADA_PORT=' .env; then sed -i 's|^SCADA_PORT=.*|SCADA_PORT=8088|' .env; else echo "SCADA_PORT=8088" >> .env; fi
fi

[ "${INSTALAR_SO_PREPARAR:-0}" = 1 ] && { echo "(modo teste: parou aqui)"; exit 0; }

# 7) Pergunta o token e sobe o laboratório (já com o grupo docker, sem precisar reabrir o Ubuntu)
if docker info >/dev/null 2>&1; then
  exec ./iniciar.sh
else
  exec sg docker -c "./iniciar.sh"
fi
