# Laboratório Virtual de Subestações: Scada-LTS + vpn-local em Docker

Este repositório instala, no computador do aluno, o **Scada-LTS** (supervisório) e o **vpn-local** (a conexão que liga o Scada-LTS à sala 3D do laboratório). Um único comando, por sistema (**Ubuntu, Debian, Kali Linux e Fedora**), faz tudo: confere o computador, para os containers que já existirem, instala o Docker se faltar, sobe o Scada-LTS e o vpn-local, pede o token de acesso e aplica a configuração.

```
Sala 3D (site) ──► Servidor do laboratório ◄── HTTPS (só saída) ── vpn-local ◄── Modbus TCP ── Scada-LTS
                                                                   └───────── mesma rede Docker ────────┘
```

| Container | Para quê |
|---|---|
| `rede` | Container mínimo que **é dono da rede** compartilhada (e publica a porta do Scada-LTS) |
| `mysql` | Banco do Scada-LTS |
| `vpn-local` | Expõe o laboratório como dispositivos **Modbus TCP** em `127.0.0.11` a `127.0.0.14`, porta `5020`, e leva os comandos do Scada-LTS ao servidor |
| `scadalts` | O [Scada-LTS](https://github.com/SCADA-LTS/Scada-LTS), mestre Modbus. Abre em `http://localhost:8080/Scada-LTS/` (`admin` / `admin`) |

---

## 1. Instalação: copie e cole UMA linha

Abra o terminal do Linux (no Windows: o **Ubuntu do WSL**) e cole **a linha do seu sistema**. O sistema pede a sua **senha** (ao digitar, ela não aparece: digite e aperte Enter).

```bash
# Ubuntu (e Ubuntu do WSL)
sudo apt update && sudo apt install -y curl git && curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/install-lab-ubuntu.sh | bash

# Debian
sudo apt update && sudo apt install -y curl git && curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/install-lab-debian.sh | bash

# Kali Linux
sudo apt update && sudo apt install -y curl git && curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/install-lab-kali.sh | bash

# Fedora
sudo dnf install -y curl git && curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/install-lab-fedora.sh | bash
```

- Usou o instalador do sistema errado? Ele avisa e mostra a linha certa, sem instalar nada.
- **Token para depois:** coloque `LAB_SEM_TOKEN=1` antes do `bash` (`... | LAB_SEM_TOKEN=1 bash`) ou aperte só Enter quando ele pedir o token. Depois: `cd ~/scsep-scada-view && ./adicionar-token.sh`.
- Pode repetir o mesmo comando quando quiser: ele continua de onde parou e não duplica nada.
- Tudo o que aparece na tela fica gravado em `~/scsep-scada-view/instalacao-DATA.log`. Se algo der errado, envie esse arquivo ao professor.

Ao terminar, abra **http://localhost:8080/Scada-LTS/** (ou a porta mostrada no quadro PRONTO) com `admin` / `admin`. Em **Graphic views > Painel de comando** os botões e LEDs são clicáveis e comandam a sala 3D.

---

## 2. Guia passo a passo (para pessoas e para agentes de IA)

Esta seção descreve **exatamente** o que fazer e o que esperar, para que uma pessoa ou uma IA execute a instalação sozinha, sem adivinhar.

### 2.1 O que você precisa antes de começar

| Item | Detalhe | Como conferir |
|---|---|---|
| Sistema | Ubuntu (e derivados, como Mint e o Ubuntu do WSL 2), Debian, Kali ou Fedora, 64 bits | `. /etc/os-release; echo "$ID, $ID_LIKE, $PRETTY_NAME"` |
| Permissão de administrador | `root`, ou usuário com `sudo` | `id -u` (0 = root) ou `sudo -v` |
| Internet | GitHub, Docker Hub e o servidor do laboratório | `curl -sI https://github.com \| head -1` |
| Disco e memória | 6 GB livres (as imagens ocupam uns 3 GB); 4 GB de RAM recomendados (mínimo 3 GB) | `df -h /` e `free -m` |
| **Token de acesso** | Começa com `ak_`. Quem tem conta no site copia em *Meu laboratório > Copiar token*. Pode ficar para depois | Fornecido pelo usuário |
| WSL (só no Windows) | Precisa ser **WSL 2**. Em WSL 1 o Docker não funciona | PowerShell: `wsl -l -v` (coluna VERSION = 2) |

### 2.2 Qual instalador usar

Descubra o sistema com `. /etc/os-release; echo "$ID $ID_LIKE"` e escolha:

| `ID` / `ID_LIKE` contém | Instalador | Pré-instalação |
|---|---|---|
| `kali` | `install-lab-kali.sh` | `sudo apt update && sudo apt install -y curl git` |
| `ubuntu` (inclui Mint, Pop!_OS) | `install-lab-ubuntu.sh` | `sudo apt update && sudo apt install -y curl git` |
| `debian` (e não é Kali/Ubuntu) | `install-lab-debian.sh` | `sudo apt update && sudo apt install -y curl git` (Debian sem `sudo`: entre com `su -` e instale também o pacote `sudo`) |
| `fedora` | `install-lab-fedora.sh` | `sudo dnf install -y curl git` |
| qualquer outro (Arch, RHEL, Alpine...) | **não suportado** | Pare e avise o usuário |

A URL de cada instalador é `https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/<instalador>`.

### 2.3 Regras para um agente de IA

1. **Peça consentimento antes de parar containers.** O passo 2 do instalador **PARA todos os containers em execução** (não apaga nada). Mostre ao usuário o que está rodando (`docker ps`) e só use `LAB_CONFIRMA=s` depois que ele concordar.
2. **Nunca** rode `docker rm`, `docker rmi`, `docker system prune`, `docker volume rm` ou `docker compose down -v` por conta própria: apagam dados do usuário. Só com pedido explícito.
3. **O token é segredo.** Não o exiba em mensagens, não o grave em logs ou commits. O instalador não o grava no log; ele fica só no arquivo `.env` (que está no `.gitignore`).
4. **`sudo` pede senha e precisa de terminal.** Sem terminal (agente sem TTY), o instalador só funciona como `root` ou com `sudo` sem senha (`NOPASSWD`). Se não for o caso, peça ao usuário para rodar o comando no terminal dele.
5. Não edite `docker-compose.yml` nem os scripts. A única configuração do dia a dia está no `.env` (variável `SCADA_PORT`, escolhida pelo instalador) e nas variáveis `LAB_*` abaixo.
6. Se algo falhar, leia as últimas linhas de `~/scsep-scada-view/instalacao-*.log`, procure o sintoma na seção 2.7, corrija e **rode o instalador de novo** (é seguro repetir).

### 2.4 Rodar o instalador

**Interativo** (pessoa no terminal): use a linha da seção 1.

**Não interativo** (agente), com o consentimento do usuário já obtido e o token deixado para depois:

```bash
# Ubuntu como exemplo; troque pelo instalador do sistema (seção 2.2)
sudo apt update && sudo apt install -y curl git
curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/install-lab-ubuntu.sh | LAB_CONFIRMA=s LAB_SEM_TOKEN=1 bash
```

Depois, com o token em mãos (o `sg docker` é necessário se o usuário acabou de entrar no grupo `docker`):

```bash
cd ~/scsep-scada-view
./adicionar-token.sh ak_SEU_TOKEN            # se "docker info" funciona sem sudo
sg docker -c "./adicionar-token.sh ak_SEU_TOKEN"   # caso contrário
```

Códigos de saída do instalador: `0` = concluído; `1` = erro (a mensagem diz o motivo e o que fazer) ou cancelado pelo usuário ("Cancelado. Nada foi alterado.").

**Variáveis de ambiente** (coloque antes de `bash`, como em `... | LAB_SEM_TOKEN=1 bash`):

| Variável | Efeito | Padrão |
|---|---|---|
| `LAB_SEM_TOKEN=1` | Não pergunta o token; o vpn-local sobe sem conexão e o token é adicionado depois | pergunta |
| `LAB_CONFIRMA=s` | Responde **sim** a todas as perguntas (ex.: parar containers). Use só com consentimento | pergunta; sem teclado, assume **não** |
| `LAB_PORTAS="8080 8088"` | Portas candidatas para o Scada-LTS, na ordem | `8080 8088 8090 8100` |
| `LAB_DESTINO=/caminho` | Pasta onde o pacote é baixado | `~/scsep-scada-view` |
| `LAB_SERVIDOR=https://...` | Endereço do servidor usado só na verificação de internet | servidor do laboratório |
| `LAB_NOMES="rede mysql ..."` | Nomes de containers que o laboratório usa e que serão renomeados se forem de outro programa | `rede mysql vpn-local scadalts` |
| `LAB_PULAR_VERIFICACAO=1` | Pula a checagem de internet, disco e memória | confere |
| `LAB_PARAR_APOS=pacotes` ou `preparar` | Só para testes: encerra depois dessa etapa | roda tudo |

### 2.5 O que o instalador faz, passo a passo

O instalador é o arquivo `install-lab-<sistema>.sh` (confere o sistema e baixa o pacote para `~/scsep-scada-view`) mais a biblioteca `lib/lab-comum.sh` (os 6 passos). A saída traz **"Passo N de 6"**; cada linha começa com `[ok]` (deu certo) ou `[atenção]` (aviso que não impede a instalação).

**Antes dos passos.** Confere se o sistema é o do instalador (senão mostra o comando certo e sai). Instala o `git` se faltar, clona `https://github.com/grei-ufc/scsep-scada-view.git` em `~/scsep-scada-view` (ou atualiza com `git pull`; se o histórico foi reescrito, alinha com `git fetch` + `git reset --hard origin/main`; o `.env` não é afetado) e continua a partir da pasta do pacote, devolvendo o teclado ao terminal (`/dev/tty`).

**Passo 1: conferir o computador.**
- Permissão: `root`, ou `sudo -v` (pede a senha). Sem `sudo`: erro com a dica `su -`.
- WSL: precisa ser WSL 2 (`uname -r` contém `wsl2`); WSL 1 gera erro.
- Processador `x86_64` (outros: aviso). Disco: mínimo 6 GB livres em `/` (ou em `/var/lib/docker`); menos que isso gera erro. Memória: menos de 3 GB gera aviso.
- Internet: `https://github.com` (obrigatório), `https://registry-1.docker.io/v2/` e o servidor do laboratório (apenas avisos).

**Passo 2: se já usa o Docker, parar o que está rodando.**
- Se o `docker` não existe, não há o que parar. Se existe, liga o serviço (se estiver parado) e lista os containers em execução que **não** são do projeto `scada-lab`.
- Mostra a lista, **pergunta** `[S/n]` e executa `docker stop -t 10 <ids>`. **Nada é apagado.** Resposta "não" cancela tudo (código 1).
- Os containers parados entram no arquivo `voltar-containers.sh`.
- Containers com `restart: always` voltam sozinhos ao reiniciar o computador; se atrapalharem, pare-os de novo.

**Passo 3: instalar o que falta (Docker e Compose).** Só instala se faltar; se tudo existe, escreve "nada a instalar".

| Sistema | Pacotes (nessa ordem) |
|---|---|
| Ubuntu / Debian / Kali | `apt-get update`; `docker.io`; o Compose pelo primeiro pacote com candidato entre `docker-compose-v2`, `docker-compose-plugin`, `docker-compose`. O `apt` espera até 3 min se outro programa o estiver usando. Kali com erro de chave: baixa `kali-archive-keyring.gpg` e repete |
| Ubuntu / Debian (se o `apt` não bastar) | Instalador oficial `https://get.docker.com` |
| Kali (se o `apt` não bastar) | Sem alternativa: erro com o comando manual `sudo apt install -y docker.io docker-compose` |
| Fedora | `dnf install -y moby-engine docker-compose`. Se o `docker` atual for o do Podman (`podman-docker`), usa `--allowerasing` para trocá-lo. Se não bastar: repositório oficial `download.docker.com/linux/fedora` + `docker-ce docker-ce-cli containerd.io docker-compose-plugin` |

Em seguida: se só existir o Compose antigo (`docker-compose` v1, em Python), baixa o plugin **v2.29.7** para `/usr/local/lib/docker/cli-plugins/` (o v1 falha ao recriar containers em Docker novo); instala o `python3` se faltar (usado para aplicar a configuração do Scada-LTS); liga o serviço (`systemctl enable --now docker`, ou `service docker start` no WSL sem systemd; espera até 40 s); e, se você não for root, adiciona seu usuário ao grupo `docker` (`usermod -aG docker`; vale a partir do próximo login: o instalador usa `sg docker` e não precisa que você reabra o terminal).

**Passo 4: preparar.**
- **Nomes:** container com o nome `rede`, `mysql`, `vpn-local` ou `scadalts` que **não é do projeto `scada-lab`** é parado e renomeado para `NOME-anterior-DATA` (não é apagado; `voltar-containers.sh` desfaz).
- **Porta:** escolhe a primeira livre entre `8080 8088 8090 8100` (testa a conexão em `127.0.0.1`), ou mantém a porta do `rede` se o laboratório já existir. Grava `SCADA_PORT=<porta>` no `.env`.
- Escreve `voltar-containers-DATA.sh` (e uma cópia `voltar-containers.sh`): para o laboratório, desfaz os renomeios e liga de novo o que foi parado.

**Passo 5: subir e pedir o token** (roda `iniciar.sh`).
1. Cria o `.env` a partir de `.env.example` se não existir.
2. Se o volume `scada-lab_vpn-local_data` ainda **não** existe e `CHAVE` está vazia, e não há `LAB_SEM_TOKEN=1`: mostra o quadro **TOKEN DE ACESSO** e pergunta. Aceita `ak_` seguido de letras, números, `_` ou `-` (espaços e aspas são removidos). Até **3 tentativas**; **só Enter** (ou 3 erros) deixa o token para depois.
3. `docker compose up -d --build` (na primeira vez baixa as imagens: 5 a 20 minutos).
4. Espera o vpn-local falar com o servidor (até 1 min) e o Scada-LTS responder (200 ou 302; até 5 min).
5. Na primeira vez, roda `python3 scada-lts/importar.py`, que faz login como `admin/admin` e importa `scada-lts/scada-lts-import.json`: **4 Data Sources, 35 pontos, 21 point links e a tela "Painel de comando"**. Cria o arquivo `.scada-config-aplicada` para não repetir. Se o admin já trocou a senha: `SCADA_USER=... SCADA_SENHA=... python3 scada-lts/importar.py`.

**Passo 6: conferir e resumir.** Lista o estado dos 4 containers, testa a página do Scada-LTS e o vpn-local e mostra o quadro **PRONTO** (endereço, login, comandos do dia a dia, caminho do `voltar-containers.sh` e do log).

### 2.6 Como conferir que deu certo

Rode dentro de `~/scsep-scada-view`. Troque `PORTA` pelo valor de `SCADA_PORT` no `.env` (padrão 8080).

| Verificação | Comando | Resultado esperado |
|---|---|---|
| 4 containers rodando | `docker ps --filter label=com.docker.compose.project=scada-lab --format '{{.Names}}: {{.Status}}'` | `rede`, `mysql`, `vpn-local`, `scadalts`, todos `Up` (`mysql` e `vpn-local` com `(healthy)`) |
| Scada-LTS no ar | `curl -s -o /dev/null -w '%{http_code}' http://localhost:PORTA/Scada-LTS/` | `200` ou `302` (nos primeiros minutos pode dar `000`/`404`: espere e repita) |
| vpn-local conectado | `docker logs --tail 30 vpn-local` | contém `ativada com sucesso`, `credencial salva` ou `estado: connected` |
| Modbus ativo | `docker inspect -f '{{.State.Health.Status}}' vpn-local` | `healthy` |
| Configuração aplicada | `ls .scada-config-aplicada` | o arquivo existe |
| Servidor acessível | `curl -s -o /dev/null -w '%{http_code}' https://scsep.joaopedromagalhaes.com.br/api/health` | `200` |

Se o token ficou para depois, "vpn-local conectado" só passa depois do `./adicionar-token.sh`. Os outros itens já devem passar.

### 2.7 Problemas comuns

| Sintoma | Causa provável | O que fazer |
|---|---|---|
| `ESTE INSTALADOR É PARA <sistema>` | Instalador do sistema errado | Use o comando que ele mostrou (seção 2.2) |
| `sudo: command not found` (Debian) | Debian mínimo sem `sudo` | `su -` e `apt update && apt install -y curl git sudo`; rode o comando de novo |
| `não consegui a permissão de administrador (sudo)` | Senha errada, ou sem TTY | Confira a senha; sem TTY use `root` ou `sudo` sem senha |
| `pouco espaço em disco` | Menos de 6 GB livres | Libere espaço. Containers e imagens sem uso: `docker system prune` (**apaga dados: só com autorização do usuário**) |
| `o seu WSL parece ser a versão 1` | WSL 1 não roda o Docker | PowerShell: `wsl --set-version Ubuntu 2` |
| `o serviço do Docker não ligou` | Serviço parado ou sem systemd | `sudo systemctl status docker`; no WSL: `sudo service docker start`; com Docker Desktop, abra-o e espere |
| `permission denied ... docker.sock` | Usuário acabou de entrar no grupo `docker` | Feche e abra o terminal, ou use `sg docker -c "..."` |
| `Could not get lock` / `apt` travado | Atualização automática rodando | Espere alguns minutos e rode de novo |
| `Cancelado. Nada foi alterado.` | Resposta "não" à pergunta de parar containers, ou sem teclado | Responda `S`, ou use `LAB_CONFIRMA=s` com o consentimento do usuário |
| `não consegui baixar o pacote` | GitHub inacessível ou data/hora errada | Confira a internet e o relógio |
| Download das imagens falha | Rede instável, limite do Docker Hub | Rode o instalador de novo: continua de onde parou |
| Página do Scada-LTS não abre | Primeira inicialização (3 a 5 min) | Espere; veja `docker logs scadalts` |
| `AVISO: não consegui importar sozinho` | Scada-LTS ainda iniciando, ou senha do admin trocada | `python3 scada-lts/importar.py` (com `SCADA_SENHA=...` se necessário); ou importe `scada-lts/scada-lts-import.json` em Import/Export |
| `vpn-local` sem conexão | Falta o token ou foi copiado incompleto | `./adicionar-token.sh ak_...`; veja `docker logs vpn-local` |
| `ERRO na ativação` | Token inválido, revogado ou expirado | Copie o token de novo em *Meu laboratório* |
| Reiniciei o computador e nada subiu | O Docker não liga sozinho (WSL) | `sudo systemctl start docker` (WSL: `sudo service docker start`) e `cd ~/scsep-scada-view && docker compose up -d` |
| Porta 8080 ocupada | Outro programa usa a porta | O instalador escolhe outra (8088...) e mostra a certa no quadro PRONTO |

### 2.8 Uso no dia a dia, atualização e reversão

Dentro de `~/scsep-scada-view`:

| Quero... | Comando |
|---|---|
| Ver o estado | `docker compose ps` |
| Desligar (guarda os dados) | `docker compose stop` |
| Ligar (também depois de reiniciar o computador) | `docker compose up -d` |
| Ver a conexão com o servidor | `docker logs -f vpn-local` |
| Reiniciar uma peça | `docker restart vpn-local` ou `docker restart scadalts` |
| Adicionar ou trocar o token | `./adicionar-token.sh` (pergunta) ou `./adicionar-token.sh ak_...` |
| Ligar de novo os containers que o instalador parou | `./voltar-containers.sh` |
| Atualizar o pacote e a configuração | `git pull && ./iniciar.sh` |
| Reaplicar a configuração do Scada-LTS | apague `.scada-config-aplicada` e rode `./iniciar.sh` |
| Desligar e **apagar tudo** (banco e credencial) | `docker compose down -v` (**destrutivo**) |

`./adicionar-token.sh` recria o vpn-local com o novo token (apaga só o volume da credencial anterior); o Scada-LTS continua rodando. O mesmo token pode ser usado em até 10 instalações.

---

## 3. Configuração (`.env`)

O instalador cria o `.env` a partir de `.env.example`. Os valores só são lidos na primeira ativação do vpn-local; depois a credencial fica no volume `scada-lab_vpn-local_data`.

| Variável | Significado | Padrão |
|---|---|---|
| `SERVIDOR` | Endereço do site do laboratório | `https://scsep.joaopedromagalhaes.com.br` |
| `CHAVE` | **Token de ativação** (`ak_...`) de *Meu laboratório* | vazio |
| `NOME` | Nome desta instalação (aparece em *Meu laboratório > Instalações*) | `Scada-LTS (Docker)` |
| `SCADA_PORT` | Porta do Scada-LTS no computador | `8080` (o instalador ajusta se estiver ocupada) |

## 4. Conteúdo do repositório

```
install-lab-ubuntu.sh    # instalador Ubuntu (e Ubuntu do WSL)
install-lab-debian.sh    # instalador Debian
install-lab-kali.sh      # instalador Kali Linux
install-lab-fedora.sh    # instalador Fedora
lib/lab-comum.sh         # os 6 passos e as mensagens, comuns aos quatro instaladores
iniciar.sh               # token, docker compose up, espera e importação da configuração
adicionar-token.sh       # adiciona ou troca o token do vpn-local depois da instalação
docker-compose.yml       # rede, mysql, vpn-local, scadalts
.env.example             # modelo de configuração
vpn-local/               # Dockerfile e vpn-local-service.cjs (o vpn-local como serviço)
scada-lts/               # importar.py e scada-lts-import.json (Data Sources, pontos, controles e tela)
# Criados na instalação (fora do GitHub): .env, voltar-containers.sh, instalacao-DATA.log, .scada-config-aplicada
```

## 5. Segurança

O `.env` e a credencial do vpn-local (guardada em texto no volume Docker) são pessoais: não compartilhe nem faça commit do `.env` (já está no `.gitignore`). O banco usa `root`/`root` e só é acessível dentro do Docker. O instalador não grava senha nem token no log.
