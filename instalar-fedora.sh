#!/usr/bin/env bash
# Instala o Scada-LTS e o vpn-local no FEDORA. Só isso: não apaga nada do seu Docker.
#
#   Cole no terminal do Fedora:
#     sudo dnf install -y curl git && curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/instalar-fedora.sh | bash
#
#   O que faz: baixa o pacote, instala o Docker (se faltar), liga o Docker e sobe o Scada-LTS + vpn-local,
#   pedindo o token. Com LAB_SEM_TOKEN=1 o token fica para depois (./adicionar-token.sh).
#   (Opcional, desligado por padrão: LAB_LIMPAR_DOCKER=1 APAGA todos os containers e imagens antes de instalar.)
set -euo pipefail
trap 'echo; echo "ERRO na linha $LINENO: $BASH_COMMAND"; echo "Copie esta mensagem e envie para o professor."' ERR

REPO="https://github.com/grei-ufc/scsep-scada-view.git"
DESTINO="$HOME/scsep-scada-view"

echo "== Laboratório Virtual: Scada-LTS + vpn-local no Fedora =="

# 0) Só Fedora
os_val() { grep -E "^$1=" /etc/os-release 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"' || true; }
if [ "$(os_val ID)" != "fedora" ]; then
  echo "ERRO: este instalador é só para Fedora (você está em: $(os_val PRETTY_NAME))."
  echo "Para Debian, Ubuntu e Kali use o instalar.sh (veja o README)."
  exit 1
fi
echo "Distribuição detectada: Fedora ($(os_val PRETTY_NAME))"

# 1) Pacote: se este script não está dentro da pasta do pacote, baixa o pacote primeiro e continua de lá.
#    Uma pasta só é "o pacote" se tiver os arquivos dele (não basta ter um docker-compose.yml de outro projeto).
eh_pacote() { [ -f "$1/docker-compose.yml" ] && [ -f "$1/iniciar.sh" ] && [ -d "$1/vpn-local" ]; }
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -z "$AQUI" ] || ! eh_pacote "$AQUI"; then
  echo "Baixando o pacote do laboratório para $DESTINO ..."
  command -v git >/dev/null 2>&1 || sudo dnf install -y git
  if [ -d "$DESTINO/.git" ]; then git -C "$DESTINO" pull -q --ff-only || echo "(usando a versão que já está aí)"; else git clone -q "$REPO" "$DESTINO"; fi
  cd "$DESTINO"
  # quando o script vem por "curl | bash", o teclado precisa vir do terminal (para o token)
  if [ -r /dev/tty ] && ! [ -t 0 ]; then exec bash ./instalar-fedora.sh < /dev/tty; else exec bash ./instalar-fedora.sh; fi
fi
cd "$AQUI"

# 2) Docker e Docker Compose. Primeiro os pacotes do próprio Fedora (moby-engine + docker-compose);
#    se não der, o repositório oficial do Docker para Fedora.
tem_docker() { command -v docker >/dev/null 2>&1; }
tem_compose() { docker compose version >/dev/null 2>&1 || sudo docker compose version >/dev/null 2>&1 || command -v docker-compose >/dev/null 2>&1; }
if ! tem_docker || ! tem_compose; then
  echo "Instalando o Docker e o Docker Compose (pode levar alguns minutos)..."
  pacotes=()
  tem_docker || pacotes+=(moby-engine)
  tem_compose || pacotes+=(docker-compose)
  sudo dnf install -y "${pacotes[@]}" || true
  if ! tem_docker || ! tem_compose; then
    echo "Usando o repositório oficial do Docker para Fedora..."
    sudo dnf install -y dnf-plugins-core
    sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo 2>/dev/null \
      || sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  fi
fi
command -v python3 >/dev/null 2>&1 || sudo dnf install -y python3
[ "${INSTALAR_SO_PACOTES:-0}" = 1 ] && { echo "(modo teste: pacotes instalados)"; exit 0; }

# 3) Serviço do Docker ligado e usuário no grupo docker
if ! sudo docker info >/dev/null 2>&1; then
  echo "Ligando o serviço do Docker..."
  sudo systemctl enable --now docker
  for _ in 1 2 3 4 5 6 7 8 9 10; do sudo docker info >/dev/null 2>&1 && break; sleep 2; done
  sudo docker info >/dev/null 2>&1 || { echo "ERRO: o Docker não iniciou. Veja: sudo systemctl status docker"; exit 1; }
fi
if ! id -nG "$USER" | grep -qw docker; then sudo usermod -aG docker "$USER"; fi
DK="docker"; docker info >/dev/null 2>&1 || DK="sudo docker"

# 4) OPCIONAL (só com LAB_LIMPAR_DOCKER=1): apaga TODOS os containers e imagens, depois de você digitar APAGAR TUDO
if [ "${LAB_LIMPAR_DOCKER:-0}" = 1 ]; then
  n_cont="$($DK ps -aq | wc -l)"; n_img="$($DK images -aq | sort -u | wc -l)"
  if [ "$n_cont" -gt 0 ] || [ "$n_img" -gt 0 ]; then
    echo "ATENÇÃO: vou PARAR e EXCLUIR TODOS os containers ($n_cont) e TODAS as imagens ($n_img). Volumes não serão apagados."
    $DK ps -a --format '  {{.Names}}  ({{.Image}}, {{.Status}})' | head -30
    if [ -n "${LAB_CONFIRMA:-}" ]; then resp="$LAB_CONFIRMA"
    elif [ -r /dev/tty ]; then read -rp 'Digite exatamente  APAGAR TUDO  para continuar: ' resp < /dev/tty || resp=""
    else resp=""; fi
    [ "$resp" = "APAGAR TUDO" ] || { echo "Cancelado. Nada foi alterado."; exit 1; }
    ids="$($DK ps -q)";      [ -z "$ids" ] || $DK stop $ids >/dev/null
    ids="$($DK ps -aq)";     [ -z "$ids" ] || $DK rm -f $ids >/dev/null
    ids="$($DK images -aq)"; [ -z "$ids" ] || $DK rmi -f $ids >/dev/null 2>&1 || true
    echo "Docker limpo."
  fi
fi

# 5) Porta: se a 8080 estiver ocupada por outro programa, o laboratório usa a 8088
if command -v ss >/dev/null 2>&1 && ss -ltn 2>/dev/null | grep -q ":8080 "; then
  if ! $DK ps --filter "publish=8080" --format '{{.Names}}' | grep -q '^rede$'; then
    echo "A porta 8080 está ocupada por outro programa: o laboratório vai usar a 8088."
    [ -f .env ] || cp .env.example .env
    if grep -qE '^SCADA_PORT=' .env; then sed -i 's|^SCADA_PORT=.*|SCADA_PORT=8088|' .env; else echo "SCADA_PORT=8088" >> .env; fi
  fi
fi

# 6) Sobe o Scada-LTS + vpn-local (pergunta o token; com LAB_SEM_TOKEN=1 ele fica para depois)
echo "Subindo o laboratório..."
trap - ERR
if docker info >/dev/null 2>&1; then
  exec bash ./iniciar.sh
else
  exec sg docker -c "LAB_SEM_TOKEN=${LAB_SEM_TOKEN:-0} bash ./iniciar.sh"
fi
