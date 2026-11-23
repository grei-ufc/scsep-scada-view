#!/usr/bin/env bash
# ======================================================================================================================
#  Laboratório Virtual de Subestações: parte COMUM dos instaladores (Ubuntu, Debian, Kali e Fedora).
#  Este arquivo não é para ser rodado sozinho: ele é carregado por instalar-lab-ubuntu.sh (e os irmãos).
#
#  O que o instalador faz, em 6 passos:
#    1. Confere o computador (sistema, internet, espaço em disco, memória, permissões).
#    2. Se você já usa o Docker: PARA todos os containers que estão rodando (nada é apagado) e guarda um
#       arquivo "voltar-containers.sh" para ligá-los de novo depois.
#    3. Instala o Docker e o Docker Compose, se faltarem. Se já existem, só continua.
#    4. Prepara o laboratório (libera nomes e escolhe uma porta livre).
#    5. Sobe o Scada-LTS e o vpn-local e PEDE O TOKEN DE ACESSO.
#    6. Confere se está tudo funcionando e mostra o resumo.
#
#  Tudo o que aparece na tela também é gravado em "instalacao-DATA.log", na pasta do pacote.
# ======================================================================================================================

# ----------------------------------------------------------------------------------------------------------------------
# Apresentação (cores só quando a saída é um terminal)
# ----------------------------------------------------------------------------------------------------------------------
lab_cores() {
  if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_T=$'\033[1;36m'; C_OK=$'\033[1;32m'; C_AV=$'\033[1;33m'; C_ER=$'\033[1;31m'; C_B=$'\033[1m'; C_0=$'\033[0m'
  else
    C_T=""; C_OK=""; C_AV=""; C_ER=""; C_B=""; C_0=""
  fi
}
lab_titulo() { echo; echo "${C_T}=== Passo $1 de $TOTAL: $2 ===${C_0}"; }
ok()    { echo "  ${C_OK}[ok]${C_0} $*"; }
aviso() { echo "  ${C_AV}[atenção]${C_0} $*"; }
info()  { echo "  $*"; }

# Erro com explicação: lab_fatal "o que aconteceu" "dica 1" "dica 2" ...
lab_fatal() {
  local msg="$1"; shift
  echo; echo "${C_ER}ERRO: $msg${C_0}"
  local d; for d in "$@"; do echo "  - $d"; done
  echo
  echo "Se não conseguir resolver, envie o arquivo abaixo ao professor (ele guarda tudo o que aconteceu):"
  echo "  $LOG"
  trap - ERR
  exit 1
}
lab_erro_inesperado() {
  trap - ERR
  echo; echo "${C_ER}ERRO inesperado na linha $1 do instalador:${C_0} $2"
  echo "Envie ao professor este texto e o arquivo: $LOG"
}

# Pergunta sim/não. Uso: lab_pergunta "Texto? [S/n]" S    (o segundo argumento é a resposta padrão: S ou N)
# Sem teclado disponível, e sem LAB_CONFIRMA, a resposta é "não" (por segurança).
lab_pergunta() {
  local texto="$1" padrao="${2:-S}" resp=""
  if [ -n "${LAB_CONFIRMA:-}" ]; then resp="$LAB_CONFIRMA"
  elif ( : < /dev/tty ) 2>/dev/null; then
    printf '%s ' "$texto" > /dev/tty
    read -r resp < /dev/tty || resp=""
    [ -n "$resp" ] || resp="$padrao"
  else
    echo "  (sem teclado disponível para perguntar; assumindo NÃO. Para aceitar sem perguntar: LAB_CONFIRMA=s)"
    resp="n"
  fi
  [[ "$resp" =~ ^[sSyY]$ ]]
}

# ----------------------------------------------------------------------------------------------------------------------
# Sistema
# ----------------------------------------------------------------------------------------------------------------------
lab_os_val() { grep -E "^$1=" /etc/os-release 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"' || true; }

lab_nome_distro() {
  case "$LAB_DISTRO" in
    ubuntu) echo "Ubuntu" ;; debian) echo "Debian" ;; kali) echo "Kali Linux" ;; fedora) echo "Fedora" ;; *) echo "$LAB_DISTRO" ;;
  esac
}

# Mantém o apt calmo e espera se outro programa (atualização automática) estiver usando o apt
APT_OPTS=(-o DPkg::Lock::Timeout=180)
lab_apt_atualizar() {
  if $SUDO apt-get "${APT_OPTS[@]}" update; then return 0; fi
  if [ "$LAB_DISTRO" = kali ]; then
    info "O apt reclamou das chaves do Kali. Atualizando a chave do repositório..."
    $SUDO curl -fsSL -o /usr/share/keyrings/kali-archive-keyring.gpg https://archive.kali.org/archive-keyring.gpg || true
    $SUDO apt-get "${APT_OPTS[@]}" update && return 0
  fi
  aviso "não consegui atualizar a lista de pacotes (apt update). Vou tentar instalar mesmo assim."
  aviso "Se falhar: confira a internet e a data/hora do computador (data errada quebra o apt)."
  return 0
}
lab_apt_instalar() { $SUDO env DEBIAN_FRONTEND=noninteractive apt-get "${APT_OPTS[@]}" install -y "$@"; }
lab_dnf_instalar() { $SUDO dnf install -y "$@"; }
lab_instalar_pacote() { # instala um pacote simples (python3, curl...) na família certa
  case "$LAB_DISTRO" in
    fedora) lab_dnf_instalar "$@" ;;
    *) if [ "$APT_FEITO" = 0 ]; then lab_apt_atualizar; APT_FEITO=1; fi; lab_apt_instalar "$@" ;;
  esac
}

lab_acessa() { # lab_acessa URL -> 0 se o endereço responde (qualquer código HTTP)
  local cod; cod="$(curl -s -m 15 -o /dev/null -w '%{http_code}' "$1" 2>/dev/null || true)"
  [ -n "$cod" ] && [ "$cod" != "000" ]
}

# ----------------------------------------------------------------------------------------------------------------------
# Docker: perguntas simples
# ----------------------------------------------------------------------------------------------------------------------
lab_tem_docker() { command -v docker >/dev/null 2>&1 && ! docker --version 2>&1 | grep -qi podman; }
lab_tem_compose() {
  docker compose version >/dev/null 2>&1 || { [ -n "$SUDO" ] && $SUDO docker compose version >/dev/null 2>&1; } || command -v docker-compose >/dev/null 2>&1
}
lab_compose_v2() { docker compose version >/dev/null 2>&1 || { [ -n "$SUDO" ] && $SUDO docker compose version >/dev/null 2>&1; }; }
lab_docker_ativo() { docker info >/dev/null 2>&1 || { [ -n "$SUDO" ] && $SUDO docker info >/dev/null 2>&1; }; }
lab_definir_dk() { DK="docker"; docker info >/dev/null 2>&1 || DK="$SUDO docker"; }

lab_ligar_docker() {
  lab_docker_ativo && return 0
  info "Ligando o serviço do Docker..."
  if [ -d /run/systemd/system ]; then
    $SUDO systemctl enable --now docker >/dev/null 2>&1 || $SUDO systemctl start docker || true
  else
    $SUDO service docker start || true      # WSL sem systemd
  fi
  local i; for i in $(seq 1 20); do lab_docker_ativo && break; sleep 2; done
  lab_docker_ativo && { ok "Serviço do Docker ligado."; return 0; }
  lab_fatal "o serviço do Docker não ligou." \
    "Veja o motivo com:  $SUDO systemctl status docker   (ou:  $SUDO journalctl -u docker -n 30)" \
    "No WSL sem systemd, tente:  sudo service docker start" \
    "Se você usa o Docker Desktop (Windows), abra o programa, espere ele ficar verde e rode de novo." \
    "Se o seu WSL é a versão 1, o Docker não funciona nele. No PowerShell do Windows:  wsl --set-version Ubuntu 2"
}

lab_grupo_docker() {
  [ "$(id -u)" = 0 ] && return 0
  if ! id -nG "$ME" | grep -qw docker; then
    if $SUDO usermod -aG docker "$ME"; then GRUPO_NOVO=1
    else aviso "não consegui colocar você no grupo docker (precisará de sudo para usar o Docker)."; fi
  fi
}

# ----------------------------------------------------------------------------------------------------------------------
# Passo 1: conferir o computador
# ----------------------------------------------------------------------------------------------------------------------
lab_passo1_verificar() {
  lab_titulo 1 "Conferindo o seu computador"
  ok "Sistema: $(lab_os_val PRETTY_NAME)  (instalador para $(lab_nome_distro))"

  # permissão de administrador
  if [ "$(id -u)" = 0 ]; then
    SUDO=""; ok "Você está como administrador (root)."
  elif command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
    info "O sistema vai pedir a sua SENHA (ao digitar ela não aparece na tela; digite e aperte Enter)."
    if ! sudo -v; then
      lab_fatal "não consegui a permissão de administrador (sudo)." \
        "Confira a senha. No WSL é a senha que você criou ao instalar o Ubuntu." \
        "Seu usuário precisa poder usar sudo."
    fi
    ok "Permissão de administrador (sudo) ok."
  else
    lab_fatal "o comando 'sudo' não existe neste computador." \
      "Entre como administrador com:  su -    (digite a senha do root)" \
      "Depois rode de novo o mesmo comando de instalação."
  fi

  [ "${LAB_PULAR_VERIFICACAO:-0}" = 1 ] && { info "(verificação de internet/disco/memória pulada)"; return 0; }

  # WSL
  if grep -qi microsoft /proc/version 2>/dev/null; then
    if uname -r | grep -qi 'wsl2'; then ok "Windows com WSL 2 detectado."
    else
      lab_fatal "o seu WSL parece ser a versão 1, onde o Docker não funciona." \
        "No PowerShell do Windows rode:  wsl --set-version Ubuntu 2   (troque 'Ubuntu' pelo nome mostrado em: wsl -l -v)" \
        "Depois abra o Ubuntu e rode o instalador de novo."
    fi
  fi

  # arquitetura
  case "$(uname -m)" in
    x86_64|amd64) ok "Processador: 64 bits (x86_64)." ;;
    *) aviso "processador $(uname -m): a imagem do Scada-LTS foi feita para PC comum (x86_64) e pode não funcionar aqui." ;;
  esac

  # espaço em disco (as imagens do Docker ocupam uns 3 GB)
  local dir="/"; [ -d /var/lib/docker ] && dir="/var/lib/docker"
  local livre_kb; livre_kb="$(df -Pk "$dir" 2>/dev/null | awk 'NR==2 {print $4}')"
  if [ -n "$livre_kb" ]; then
    if [ "$livre_kb" -lt 6000000 ]; then
      lab_fatal "pouco espaço em disco: só $((livre_kb / 1024)) MB livres (preciso de uns 6 GB)." \
        "Libere espaço (apague arquivos grandes) e rode de novo." \
        "Se tem containers antigos que não usa mais:  docker system prune"
    fi
    ok "Espaço em disco: $((livre_kb / 1024 / 1024)) GB livres."
  fi

  # memória
  local ram_kb; ram_kb="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || true)"
  if [ -n "$ram_kb" ]; then
    if [ "$ram_kb" -lt 3000000 ]; then aviso "pouca memória ($((ram_kb / 1024)) MB). O Scada-LTS pode ficar lento ou travar; o ideal é 4 GB ou mais."
    else ok "Memória: $((ram_kb / 1024)) MB."; fi
  fi

  # internet
  command -v curl >/dev/null 2>&1 || lab_instalar_pacote curl
  if lab_acessa https://github.com; then ok "Internet: GitHub acessível."
  else lab_fatal "sem acesso à internet (GitHub)." "Confira a conexão, o Wi-Fi e se há VPN/proxy bloqueando." "No WSL, teste:  ping -c1 8.8.8.8"; fi
  if lab_acessa https://registry-1.docker.io/v2/; then ok "Internet: Docker Hub acessível."
  else aviso "não consegui falar com o Docker Hub (hub.docker.com). O download das imagens pode falhar; confira a internet."; fi
  if lab_acessa "$SERVIDOR_LAB/api/health"; then ok "Servidor do laboratório acessível."
  else aviso "não consegui falar com o servidor do laboratório ($SERVIDOR_LAB). O vpn-local só conecta quando ele estiver acessível."; fi
}

# ----------------------------------------------------------------------------------------------------------------------
# Passo 2: se já usa o Docker, parar o que está rodando
# ----------------------------------------------------------------------------------------------------------------------
lab_passo2_containers() {
  lab_titulo 2 "Verificando se você já usa o Docker"
  if ! lab_tem_docker; then
    ok "O Docker ainda não está instalado: não há nada para parar."
    return 0
  fi
  ok "Docker encontrado: $(docker --version 2>/dev/null || echo instalado)"
  lab_ligar_docker
  lab_definir_dk

  local ids=() descr=() id nome img proj
  while IFS='|' read -r id nome img proj; do
    [ -n "$id" ] || continue
    [ "$proj" = "$PROJETO" ] && continue            # os containers do próprio laboratório ficam
    ids+=("$id"); descr+=("$nome  (imagem: $img)")
  done < <($DK ps --format '{{.ID}}|{{.Names}}|{{.Image}}|{{.Label "com.docker.compose.project"}}' 2>/dev/null || true)

  if [ "${#ids[@]}" = 0 ]; then ok "Nenhum outro container em execução."; return 0; fi

  echo
  echo "  Estes containers estão rodando agora:"
  local d; for d in "${descr[@]}"; do echo "    - $d"; done
  echo
  echo "  Para o laboratório funcionar sem conflito (portas e nomes), vou PARAR todos eles."
  echo "  Nada será apagado: seus dados e imagens continuam. Para ligá-los de novo depois, use o arquivo"
  echo "  voltar-containers.sh que vou criar na pasta $PASTA"
  echo "  (Containers configurados com 'restart: always' voltam sozinhos quando o computador é reiniciado;"
  echo "   se isso atrapalhar o laboratório, pare-os de novo com:  docker stop NOME)"
  if ! lab_pergunta "Posso parar esses ${#ids[@]} containers? [S/n]" S; then
    echo; echo "Cancelado. Nada foi alterado."; exit 1
  fi
  $DK stop -t 10 "${ids[@]}" >/dev/null || aviso "alguns containers demoraram ou não pararam; confira com: docker ps"
  VOLTA_START+=("${ids[@]}")
  ok "${#ids[@]} container(s) parados."
}

# ----------------------------------------------------------------------------------------------------------------------
# Passo 3: instalar o Docker (se faltar)
# ----------------------------------------------------------------------------------------------------------------------
lab_tem_candidato() { local c; c="$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print $2}')"; [ -n "$c" ] && [ "$c" != "(none)" ]; }

lab_instalar_docker_apt() {
  lab_apt_atualizar; APT_FEITO=1
  local pacotes=() p
  lab_tem_docker || pacotes+=(docker.io)
  if ! lab_tem_compose; then
    # o nome do pacote do Compose muda conforme a versão da distribuição
    for p in docker-compose-v2 docker-compose-plugin docker-compose; do
      if lab_tem_candidato "$p"; then pacotes+=("$p"); break; fi
    done
  fi
  if [ "${#pacotes[@]}" -gt 0 ]; then
    info "Instalando: ${pacotes[*]}"
    lab_apt_instalar "${pacotes[@]}" || aviso "o apt não conseguiu instalar tudo (veja as mensagens acima)."
  fi
  if lab_tem_docker && lab_tem_compose; then return 0; fi
  if [ "$LAB_DISTRO" = kali ]; then
    lab_fatal "não consegui instalar o Docker pelo apt do Kali." \
      "Tente à mão:  sudo apt update && sudo apt install -y docker.io docker-compose" \
      "Se o apt reclamar de chaves, atualize o sistema:  sudo apt update --allow-releaseinfo-change"
  fi
  info "Tentando o instalador oficial do Docker (get.docker.com)..."
  command -v curl >/dev/null 2>&1 || lab_apt_instalar curl
  curl -fsSL https://get.docker.com | $SUDO sh || true
}

lab_instalar_docker_dnf() {
  # Fedora com o "podman-docker" (um falso comando docker) conflita com o Docker de verdade
  local extra=()
  if command -v docker >/dev/null 2>&1 && docker --version 2>&1 | grep -qi podman; then
    info "O comando 'docker' atual é do Podman. Vou trocá-lo pelo Docker de verdade (o Podman em si continua instalado)."
    extra=(--allowerasing)
  fi
  local pacotes=()
  lab_tem_docker || pacotes+=(moby-engine)
  lab_tem_compose || pacotes+=(docker-compose)
  if [ "${#pacotes[@]}" -gt 0 ]; then
    info "Instalando: ${pacotes[*]}"
    $SUDO dnf install -y "${extra[@]}" "${pacotes[@]}" || aviso "o dnf não conseguiu instalar tudo (veja as mensagens acima)."
  fi
  if lab_tem_docker && lab_tem_compose; then return 0; fi
  info "Tentando o repositório oficial do Docker para Fedora..."
  $SUDO dnf install -y dnf-plugins-core || true
  $SUDO dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo 2>/dev/null \
    || $SUDO dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo || true
  $SUDO dnf install -y "${extra[@]}" docker-ce docker-ce-cli containerd.io docker-compose-plugin || true
}

# Se só existe o Compose antigo (v1, em Python), instala o plugin v2: o antigo falha ao recriar containers em Docker novo
lab_garantir_compose_v2() {
  lab_compose_v2 && return 0
  info "Instalando o Docker Compose v2 (o Compose antigo tem problemas com Docker novo)..."
  local arq; case "$(uname -m)" in x86_64|amd64) arq=x86_64 ;; aarch64|arm64) arq=aarch64 ;; *) return 0 ;; esac
  local dest=/usr/local/lib/docker/cli-plugins
  $SUDO mkdir -p "$dest"
  if $SUDO curl -fsSL -o "$dest/docker-compose" "https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-$arq"; then
    $SUDO chmod +x "$dest/docker-compose"
    if lab_compose_v2; then ok "Docker Compose v2 instalado."; else aviso "não consegui ativar o Compose v2; vou usar o que existe."; fi
  else
    aviso "não consegui baixar o Compose v2; vou usar o que existe (docker-compose)."
    $SUDO rm -f "$dest/docker-compose"
  fi
}

lab_passo3_docker() {
  lab_titulo 3 "Instalando o que falta (Docker e Docker Compose)"
  if lab_tem_docker && lab_tem_compose; then
    ok "Docker e Docker Compose já estão instalados: nada a instalar."
  else
    echo "  Vou instalar o Docker. Pode levar alguns minutos; não feche o terminal."
    case "$LAB_DISTRO" in
      ubuntu|debian|kali) lab_instalar_docker_apt ;;
      fedora)             lab_instalar_docker_dnf ;;
    esac
    lab_tem_docker  || lab_fatal "o Docker não foi instalado." "Veja as mensagens acima e confira a internet." "Rode o instalador de novo: ele continua de onde parou."
    lab_tem_compose || lab_fatal "o Docker Compose não foi instalado." "Veja as mensagens acima." "Rode o instalador de novo: ele continua de onde parou."
    ok "Docker instalado."
  fi
  lab_garantir_compose_v2
  if ! command -v python3 >/dev/null 2>&1; then info "Instalando o python3 (aplica a configuração no Scada-LTS)..."; lab_instalar_pacote python3; fi
  if [ "${LAB_PARAR_APOS:-}" = pacotes ]; then echo "(modo teste: pacotes instalados)"; exit 0; fi
  lab_ligar_docker
  lab_definir_dk
  lab_grupo_docker
}

# ----------------------------------------------------------------------------------------------------------------------
# Passo 4: preparar (nomes e porta)
# ----------------------------------------------------------------------------------------------------------------------
lab_do_pacote() { [ "$($DK inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$1" 2>/dev/null || true)" = "$PROJETO" ]; }

lab_porta_ocupada() { ( exec 3<>"/dev/tcp/127.0.0.1/$1" ) 2>/dev/null; }

lab_passo4_preparar() {
  lab_titulo 4 "Preparando o laboratório"
  # 4a) containers antigos com os MESMOS nomes do laboratório (rede, mysql, vpn-local, scadalts): renomeia para não conflitar
  local n novo carimbo="$CARIMBO" renomeou=0
  for n in $NOMES; do
    $DK inspect "$n" >/dev/null 2>&1 || continue
    lab_do_pacote "$n" && continue
    novo="$n-anterior-$carimbo"
    local id; id="$($DK inspect -f '{{.Id}}' "$n" | cut -c1-12)"
    local rodando; rodando="$($DK inspect -f '{{.State.Running}}' "$n")"
    [ "$rodando" = true ] && { $DK stop -t 10 "$n" >/dev/null; VOLTA_START+=("$id"); }
    $DK rename "$n" "$novo"
    VOLTA_RENOMEAR+=("$id|$n")
    info "container antigo '$n' renomeado para '$novo' (não foi apagado)"
    renomeou=1
  done
  [ "$renomeou" = 1 ] || ok "Nenhum conflito de nomes."

  # 4b) porta do Scada-LTS: usa a 8080; se estiver ocupada por outro programa, procura uma livre
  [ -f .env ] || cp .env.example .env
  sed -i 's/\r$//' .env
  local porta_rede=""
  if $DK inspect rede >/dev/null 2>&1 && lab_do_pacote rede; then
    porta_rede="$($DK port rede 8080/tcp 2>/dev/null | head -1 | awk -F: '{print $NF}')"
  fi
  local p escolhida=""
  if [ -n "$porta_rede" ]; then escolhida="$porta_rede"          # reinstalação: mantém a porta que já usa
  else
    for p in $PORTAS; do
      if ! lab_porta_ocupada "$p"; then escolhida="$p"; break; fi
    done
  fi
  [ -n "$escolhida" ] || lab_fatal "todas as portas (${PORTAS}) estão ocupadas." "Feche programas que usam essas portas ou defina outra:  LAB_PORTAS=\"9000 9001\" ./instalar-lab-$LAB_DISTRO.sh"
  if grep -qE '^SCADA_PORT=' .env; then sed -i "s|^SCADA_PORT=.*|SCADA_PORT=$escolhida|" .env; else echo "SCADA_PORT=$escolhida" >> .env; fi
  if [ "$escolhida" = 8080 ]; then ok "Porta do Scada-LTS: 8080."
  else aviso "a porta 8080 está ocupada por outro programa; o laboratório vai usar a $escolhida."; fi
  PORTA_ESCOLHIDA="$escolhida"

  lab_escrever_volta
  if [ "${LAB_PARAR_APOS:-}" = preparar ]; then echo "(modo teste: parou aqui)"; exit 0; fi
}

# Cria o script que liga de novo os containers que foram parados
lab_escrever_volta() {
  if [ "${#VOLTA_START[@]}" = 0 ] && [ "${#VOLTA_RENOMEAR[@]}" = 0 ]; then return 0; fi
  local f="$PASTA/voltar-containers-$CARIMBO.sh" l
  {
    echo '#!/usr/bin/env bash'
    echo "# Volta os containers que o instalador parou em $CARIMBO. Gerado automaticamente."
    echo 'cd "$(dirname "$0")"'
    echo 'D="docker"; docker info >/dev/null 2>&1 || D="sudo docker"'
    echo 'echo "Parando o laboratório (para liberar as portas)..."'
    echo '$D compose stop >/dev/null 2>&1 || docker-compose stop >/dev/null 2>&1 || true'
    for l in "${VOLTA_RENOMEAR[@]}"; do echo "\$D rename ${l%%|*} ${l##*|} || true"; done
    if [ "${#VOLTA_START[@]}" -gt 0 ]; then echo "\$D start ${VOLTA_START[*]} && echo \"Pronto: seus containers voltaram.\""; fi
  } > "$f"
  chmod +x "$f"
  cp "$f" "$PASTA/voltar-containers.sh"
  info "Para ligar de novo os seus containers antigos, depois:  cd $PASTA && ./voltar-containers.sh"
}

# ----------------------------------------------------------------------------------------------------------------------
# Passo 5: subir o laboratório e pedir o token
# ----------------------------------------------------------------------------------------------------------------------
lab_passo5_subir() {
  lab_titulo 5 "Subindo o Scada-LTS e o vpn-local"
  echo "  Na primeira vez o Docker baixa as imagens (uns 3 GB): pode levar de 5 a 20 minutos."
  echo "  Em seguida vou pedir o TOKEN DE ACESSO do seu laboratório."
  echo
  local rc=0
  if docker info >/dev/null 2>&1; then
    LAB_SEM_TOKEN="${LAB_SEM_TOKEN:-0}" bash ./iniciar.sh || rc=$?
  elif sg docker -c true </dev/null >/dev/null 2>&1; then
    sg docker -c "LAB_SEM_TOKEN=${LAB_SEM_TOKEN:-0} bash ./iniciar.sh" || rc=$?
  else
    $SUDO env LAB_SEM_TOKEN="${LAB_SEM_TOKEN:-0}" bash ./iniciar.sh || rc=$?
    $SUDO chown -R "$ME" "$PASTA" 2>/dev/null || true
  fi
  if [ "$rc" != 0 ]; then
    lab_fatal "a subida do laboratório terminou com erro (código $rc)." \
      "Se a mensagem acima fala de TOKEN: copie de novo em 'Meu laboratório' (inteiro, sem espaços) e rode:  cd $PASTA && ./adicionar-token.sh" \
      "Se fala de download/rede: confira a internet e rode:  cd $PASTA && ./iniciar.sh" \
      "Para ver o que cada container disse:  docker logs scadalts   e   docker logs vpn-local"
  fi
}

# ----------------------------------------------------------------------------------------------------------------------
# Passo 6: conferir e mostrar o resumo
# ----------------------------------------------------------------------------------------------------------------------
lab_passo6_resumo() {
  lab_titulo 6 "Conferindo se está tudo certo"
  lab_definir_dk
  local n estado faltando=0
  for n in rede mysql vpn-local scadalts; do
    estado="$($DK inspect -f '{{.State.Status}}' "$n" 2>/dev/null || echo ausente)"
    if [ "$estado" = running ]; then ok "$n: rodando"; else aviso "$n: $estado"; faltando=1; fi
  done
  local porta cod=000
  porta="$(grep -E '^SCADA_PORT=' .env 2>/dev/null | head -1 | cut -d= -f2-)"; porta="${porta:-8080}"
  cod="$(curl -s -m 10 -o /dev/null -w '%{http_code}' "http://localhost:$porta/Scada-LTS/" 2>/dev/null || true)"
  if [ "$cod" = 200 ] || [ "$cod" = 302 ]; then ok "Scada-LTS respondendo na porta $porta."
  else aviso "o Scada-LTS ainda está iniciando (é normal na primeira vez). Espere uns 2 minutos e abra o endereço abaixo."; fi
  local vpn; vpn="$($DK logs --tail 30 vpn-local 2>&1 || true)"
  if echo "$vpn" | grep -q "ativada com sucesso\|credencial salva\|estado: connected"; then ok "vpn-local conectado ao servidor do laboratório."
  else aviso "vpn-local ainda sem conexão com o servidor (faltou o token?). Veja o quadro abaixo."; fi

  echo
  echo "${C_B}===================== PRONTO =====================${C_0}"
  echo "  Abra no navegador:   http://localhost:$porta/Scada-LTS/"
  echo "  Usuário e senha:     admin / admin"
  echo
  echo "  Se ainda falta o TOKEN (site do laboratório > Meu laboratório > Copiar token):"
  echo "      cd $PASTA && ./adicionar-token.sh"
  echo
  echo "  Comandos do dia a dia (dentro de $PASTA):"
  echo "      docker compose ps        mostra se está tudo rodando"
  echo "      docker compose stop      desliga o laboratório"
  echo "      docker compose up -d     liga de novo (ou depois de reiniciar o computador)"
  echo "      docker logs vpn-local    mostra a conexão com o servidor"
  if [ "${#VOLTA_START[@]}" -gt 0 ] || [ "${#VOLTA_RENOMEAR[@]}" -gt 0 ]; then
    echo
    echo "  Para voltar aos seus containers antigos:  cd $PASTA && ./voltar-containers.sh"
  fi
  if [ "$GRUPO_NOVO" = 1 ]; then
    echo
    echo "  Dica: feche e abra o terminal para usar o 'docker' sem digitar sudo."
  fi
  echo
  echo "  Registro completo desta instalação (envie ao professor se algo der errado):"
  echo "      $LOG"
  echo "${C_B}==================================================${C_0}"
  return 0
}

# ----------------------------------------------------------------------------------------------------------------------
# Fluxo principal (chamado pelos instalar-lab-*.sh)
# ----------------------------------------------------------------------------------------------------------------------
lab_principal() {
  set -Eeuo pipefail
  lab_cores                                         # antes do tee: depois dele a saída deixa de ser um terminal
  PASTA="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  cd "$PASTA"
  CARIMBO="$(date +%Y%m%d-%H%M%S)"
  LOG="$PASTA/instalacao-$CARIMBO.log"
  exec > >(tee -a "$LOG") 2>&1
  trap 'lab_erro_inesperado "$LINENO" "$BASH_COMMAND"' ERR

  PROJETO="scada-lab"
  NOMES="${LAB_NOMES:-rede mysql vpn-local scadalts}"
  PORTAS="${LAB_PORTAS:-8080 8088 8090 8100}"
  SERVIDOR_LAB="${LAB_SERVIDOR:-https://scsep.joaopedromagalhaes.com.br}"
  ME="$(id -un)"; SUDO=""; DK="docker"; APT_FEITO=0; GRUPO_NOVO=0; PORTA_ESCOLHIDA=8080
  VOLTA_START=(); VOLTA_RENOMEAR=(); TOTAL=6

  echo "${C_B}== Laboratório Virtual de Subestações: instalação no $(lab_nome_distro) ==${C_0}"
  echo "Este instalador vai: conferir o computador, parar containers que você já tenha rodando (sem apagar nada),"
  echo "instalar o Docker se faltar, e subir o Scada-LTS e o vpn-local, pedindo o seu token de acesso."
  echo "Dura de 5 a 25 minutos, quase todo no download. Se aparecer um erro, ele explica o que fazer."

  lab_passo1_verificar
  lab_passo2_containers
  lab_passo3_docker
  lab_passo4_preparar
  lab_passo5_subir
  lab_passo6_resumo
}
