#!/usr/bin/env bash
# ======================================================================================================================
#  Laboratório Virtual de Subestações: instalador para Kali Linux
#
#  Instala o Scada-LTS e o vpn-local (conexão com o laboratório). Em resumo:
#    - se você já usa o Docker, PARA os containers que estiverem rodando (nada é apagado);
#    - instala o Docker, se não tiver;
#    - sobe o Scada-LTS e o vpn-local e pede o seu TOKEN de acesso.
#
#  COMO USAR: copie a linha abaixo, cole no terminal e aperte Enter (o sistema pede a sua senha):
#
#    sudo apt update && sudo apt install -y curl git && curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/instalar-lab-kali.sh | bash
#
#  Para deixar o token para depois (você adiciona com ./adicionar-token.sh):
#
#    sudo apt update && sudo apt install -y curl git && curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/instalar-lab-kali.sh | LAB_SEM_TOKEN=1 bash
#
#  Com o pacote já baixado, dentro da pasta dele:  ./instalar-lab-kali.sh
# ======================================================================================================================
set -euo pipefail

LAB_DISTRO="kali"
LAB_ARQUIVO="instalar-lab-kali.sh"
LAB_REPO="https://github.com/grei-ufc/scsep-scada-view.git"
LAB_DESTINO="${LAB_DESTINO:-$HOME/scsep-scada-view}"
LAB_RAW="https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main"

# Qual é o sistema deste computador? (ubuntu, debian, kali, fedora ou outro)
lab_familia() {
  local id like
  id="$(grep -E '^ID=' /etc/os-release 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"' || true)"
  like="$(grep -E '^ID_LIKE=' /etc/os-release 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"' || true)"
  case " $id $like " in
    *" kali "*)   echo kali ;;
    *" ubuntu "*) echo ubuntu ;;
    *" fedora "*) echo fedora ;;
    *" debian "*) echo debian ;;
    *) echo outro ;;
  esac
}

FAMILIA="$(lab_familia)"
if [ "$FAMILIA" != "$LAB_DISTRO" ]; then
  nome="$(grep -E '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"' || true)"
  echo
  echo "ESTE INSTALADOR É PARA Kali Linux, mas o seu sistema parece ser: ${nome:-desconhecido}."
  case "$FAMILIA" in
    ubuntu|debian|kali|fedora)
      echo "Use o instalador do seu sistema (copie e cole):"
      echo
      if [ "$FAMILIA" = fedora ]; then echo "  sudo dnf install -y curl git && curl -fsSL $LAB_RAW/instalar-lab-$FAMILIA.sh | bash"
      else echo "  sudo apt update && sudo apt install -y curl git && curl -fsSL $LAB_RAW/instalar-lab-$FAMILIA.sh | bash"; fi ;;
    *) echo "Este laboratório tem instalador para Ubuntu, Debian, Kali Linux e Fedora." ;;
  esac
  echo
  exit 1
fi

# Pacote do laboratório: se este script não está dentro da pasta dele, baixa o pacote e continua de lá.
# (Uma pasta só é "o pacote" se tiver os arquivos dele.)
lab_eh_pacote() { [ -f "$1/docker-compose.yml" ] && [ -f "$1/iniciar.sh" ] && [ -f "$1/lib/lab-comum.sh" ]; }
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"

if [ -z "$AQUI" ] || ! lab_eh_pacote "$AQUI"; then
  echo "== Laboratório Virtual: baixando o pacote para $LAB_DESTINO =="
  if ! command -v git >/dev/null 2>&1; then
    echo "Instalando o git..."
    if [ "$(id -u)" = 0 ]; then LAB_SU=""; else LAB_SU="sudo"; fi
    $LAB_SU apt-get update -qq && $LAB_SU apt-get install -y git
  fi
  if [ -d "$LAB_DESTINO/.git" ]; then
    git -C "$LAB_DESTINO" pull -q --ff-only || echo "(não consegui atualizar o pacote; usando a versão que já está aí)"
  else
    if [ -e "$LAB_DESTINO" ]; then
      mv "$LAB_DESTINO" "$LAB_DESTINO.antigo-$(date +%Y%m%d%H%M%S)"
      echo "(a pasta $LAB_DESTINO já existia e não era o pacote; foi guardada com o sufixo .antigo)"
    fi
    git clone -q "$LAB_REPO" "$LAB_DESTINO" || {
      echo
      echo "ERRO: não consegui baixar o pacote de $LAB_REPO."
      echo "  - Confira a internet:  curl -I https://github.com"
      echo "  - Se aparecer erro de certificado, confira a data e a hora do computador."
      exit 1
    }
  fi
  lab_eh_pacote "$LAB_DESTINO" || { echo "ERRO: o pacote baixado está incompleto em $LAB_DESTINO. Apague a pasta e rode de novo."; exit 1; }
  cd "$LAB_DESTINO"
  # com "curl | bash" o teclado não é o do script: devolve o terminal, senão não dá para digitar a senha e o token
  if ( : < /dev/tty ) 2>/dev/null && ! [ -t 0 ]; then exec bash "./$LAB_ARQUIVO" < /dev/tty; else exec bash "./$LAB_ARQUIVO"; fi
fi

cd "$AQUI"
# shellcheck source=lib/lab-comum.sh
source "$AQUI/lib/lab-comum.sh"
lab_principal
