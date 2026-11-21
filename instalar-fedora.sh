#!/usr/bin/env bash
# Instalador para FEDORA: LIMPA o Docker e instala o laboratório (Scada-LTS + vpn-local).
#
#   ATENÇÃO: este script PARA e EXCLUI TODOS os containers (rodando e parados) e TODAS as imagens do Docker deste
#   computador, e só continua depois que você digitar  APAGAR TUDO.  Volumes (dados de bancos) e redes NÃO são apagados,
#   a não ser que você rode com LAB_APAGAR_VOLUMES=1.
#
#   Cole no terminal do Fedora:
#     sudo dnf install -y curl git && curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/instalar-fedora.sh | bash
#   Para deixar o token para depois (e adicionar com ./adicionar-token.sh):  LAB_SEM_TOKEN=1 antes do comando.
set -euo pipefail

REPO="https://github.com/grei-ufc/scsep-scada-view.git"
DESTINO="$HOME/scsep-scada-view"

echo "== Laboratório Virtual: instalação no Fedora =="

# 0) Só Fedora
os_val() { grep -E "^$1=" /etc/os-release 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"' || true; }
if [ "$(os_val ID)" != "fedora" ]; then
  echo "ERRO: este instalador é só para Fedora (você está em: $(os_val PRETTY_NAME))."
  echo "Para Debian, Ubuntu e Kali use o instalar.sh (veja o README)."
  exit 1
fi
echo "Distribuição detectada: Fedora ($(os_val PRETTY_NAME))"

# 1) Pacote: se este script não está dentro da pasta do pacote, baixa o pacote primeiro e continua de lá
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -z "$AQUI" ] || [ ! -f "$AQUI/docker-compose.yml" ]; then
  echo "Baixando o pacote do laboratório para $DESTINO ..."
  command -v git >/dev/null 2>&1 || sudo dnf install -y git
  if [ -d "$DESTINO/.git" ]; then git -C "$DESTINO" pull --ff-only || echo "(usando a versão que já está aí)"; else git clone "$REPO" "$DESTINO"; fi
  cd "$DESTINO"
  # quando o script vem por "curl | bash", o teclado precisa vir do terminal (para a confirmação e o token)
  if [ -r /dev/tty ] && ! [ -t 0 ]; then exec bash ./instalar-fedora.sh < /dev/tty; else exec bash ./instalar-fedora.sh; fi
fi
cd "$AQUI"

# 2) Docker e Docker Compose. Primeiro os pacotes do próprio Fedora (moby-engine + docker-compose);
#    se não der, o repositório oficial do Docker para Fedora.
tem_docker() { command -v docker >/dev/null 2>&1; }
tem_compose() { sudo docker compose version >/dev/null 2>&1 || command -v docker-compose >/dev/null 2>&1; }
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
if ! sudo docker info >/dev/null 2>&1; then sudo systemctl enable --now docker; sleep 3; fi
if ! id -nG "$USER" | grep -qw docker; then sudo usermod -aG docker "$USER"; fi

# 4) LIMPEZA: para e exclui TODOS os containers e TODAS as imagens (pede confirmação digitada)
DK="docker"; docker info >/dev/null 2>&1 || DK="sudo docker"
n_cont="$($DK ps -aq | wc -l)"; n_rod="$($DK ps -q | wc -l)"; n_img="$($DK images -aq | sort -u | wc -l)"
if [ "$n_cont" -gt 0 ] || [ "$n_img" -gt 0 ]; then
  echo
  echo "=============================== ATENÇÃO ==============================="
  echo "Vou PARAR e EXCLUIR TODOS os containers ($n_cont no total, $n_rod rodando) e TODAS as imagens ($n_img) do Docker."
  echo "Containers:"; $DK ps -a --format '  {{.Names}}  ({{.Image}}, {{.Status}})' | head -30
  if [ "${LAB_APAGAR_VOLUMES:-0}" = 1 ]; then echo "E TODOS OS VOLUMES (dados de bancos) também, porque você pediu LAB_APAGAR_VOLUMES=1."
  else echo "Volumes (dados de bancos) e redes NÃO serão apagados."; fi
  echo "Isso NÃO pode ser desfeito. As imagens serão baixadas de novo quando precisar."
  echo "======================================================================="
  if [ -n "${LAB_CONFIRMA:-}" ]; then resp="$LAB_CONFIRMA"
  elif [ -r /dev/tty ]; then read -rp 'Para continuar, digite exatamente  APAGAR TUDO  e aperte Enter: ' resp < /dev/tty || resp=""
  else resp=""; fi
  [ "$resp" = "APAGAR TUDO" ] || { echo "Cancelado. Nada foi alterado."; exit 1; }

  ids="$($DK ps -q)";  [ -z "$ids" ] || $DK stop $ids >/dev/null
  ids="$($DK ps -aq)"; [ -z "$ids" ] || $DK rm -f $ids >/dev/null
  ids="$($DK images -aq)"; [ -z "$ids" ] || $DK rmi -f $ids >/dev/null 2>&1 || true
  if [ "${LAB_APAGAR_VOLUMES:-0}" = 1 ]; then ids="$($DK volume ls -q)"; [ -z "$ids" ] || $DK volume rm -f $ids >/dev/null 2>&1 || true; fi
  echo "Docker limpo: $($DK ps -aq | wc -l) containers e $($DK images -aq | wc -l) imagens restantes."
  echo
fi

# 5) Sobe o laboratório (Scada-LTS + vpn-local). Se LAB_SEM_TOKEN=1, o token fica para depois (./adicionar-token.sh)
if docker info >/dev/null 2>&1; then
  exec ./iniciar.sh
else
  exec sg docker -c "LAB_SEM_TOKEN=${LAB_SEM_TOKEN:-0} ./iniciar.sh"
fi
