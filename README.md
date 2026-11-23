# Laboratório Virtual de Subestações: vpn-local + Scada-LTS em Docker

Pacote Docker que sobe, no computador do aluno, o **Scada-LTS** (com MySQL) e o **vpn-local**, a peça que liga o Scada-LTS à simulação 3D do laboratório. Não é preciso instalar nenhum programa no Windows além do WSL e do Docker.

```
Sala 3D (site) ──► Servidor do laboratório ◄── HTTPS (só saída) ── vpn-local ◄── Modbus TCP ── Scada-LTS
                                                                  └──────── mesma rede Docker ────────┘
```

| Contêiner | Para quê |
|---|---|
| `vpn-local` | Expõe o seu laboratório como dispositivos Modbus TCP (`127.0.0.11` a `.14`, porta `5020`) e leva os comandos do Scada-LTS ao servidor |
| `scadalts` | [Scada-LTS](https://github.com/SCADA-LTS/Scada-LTS), o supervisório (mestre Modbus) |
| `mysql` | Banco do Scada-LTS |
| `rede` | Contêiner mínimo dono da rede compartilhada |

## Instalação: copie e cole UMA linha

Abra o terminal do seu Linux (no Windows: o **Ubuntu do WSL**) e cole **a linha do seu sistema**. O sistema vai pedir a sua **senha** (ao digitar ela não aparece: digite e aperte Enter).

```bash
# Ubuntu (e o Ubuntu do WSL)
sudo apt update && sudo apt install -y curl git && curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/instalar-lab-ubuntu.sh | bash

# Debian
sudo apt update && sudo apt install -y curl git && curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/instalar-lab-debian.sh | bash

# Kali Linux
sudo apt update && sudo apt install -y curl git && curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/instalar-lab-kali.sh | bash

# Fedora
sudo dnf install -y curl git && curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/instalar-lab-fedora.sh | bash
```

Se o instalador não for o do seu sistema, ele avisa e mostra a linha certa. No **Debian** sem `sudo` ("sudo: command not found"): rode `su -`, depois `apt update && apt install -y curl git sudo` e cole a linha de novo.

### O que o instalador faz (6 passos, com mensagens em português)

1. **Confere o computador**: sistema, internet, espaço em disco (uns 6 GB), memória e permissões.
2. **Se você já usa o Docker, PARA todos os containers que estão rodando** (nada é apagado) e cria o arquivo `voltar-containers.sh` para ligá-los de novo. Ele **mostra a lista e pergunta antes**.
3. **Instala o Docker e o Docker Compose** se faltarem. Se já existem, só continua.
4. **Prepara**: se já existir um container com o nome `mysql`, `scadalts` etc., renomeia (com `-anterior`); se a porta 8080 estiver ocupada, usa outra livre (8088...).
5. **Sobe o Scada-LTS e o vpn-local e pede o seu TOKEN DE ACESSO** (site > *Meu laboratório* > *Copiar token*). Sem o token agora, aperte só **Enter**: ele sobe do mesmo jeito.
6. **Confere** se está tudo rodando e mostra o endereço, o login e os comandos do dia a dia.

Tudo o que aparece na tela fica gravado em `instalacao-DATA.log`, na pasta `~/scsep-scada-view`: se algo der errado, **envie esse arquivo ao professor**.

**Token para depois:** coloque `LAB_SEM_TOKEN=1` antes do `bash` no fim da linha (`... | LAB_SEM_TOKEN=1 bash`) e, quando tiver o token: `cd ~/scsep-scada-view && ./adicionar-token.sh`.

**Rodar de novo:** pode repetir o mesmo comando quando quiser; ele continua de onde parou e não duplica nada.

**Sem teclado para perguntar** (automação): `LAB_CONFIRMA=s` antes do `bash` responde "sim" às perguntas.

### Problemas comuns

| O que aparece | O que fazer |
|---|---|
| `sudo: command not found` (Debian) | Rode `su -`, depois `apt update && apt install -y curl git sudo` e cole a linha de novo |
| `permission denied ... docker.sock` | Feche e abra o terminal (o grupo `docker` só vale depois disso) ou use `sudo docker ...` |
| O Docker não liga no WSL | `sudo service docker start`. Se o WSL for versão 1: no PowerShell, `wsl --set-version Ubuntu 2` |
| Reiniciei o computador e nada subiu | Abra o terminal e rode `sudo systemctl start docker` (no WSL: `sudo service docker start`) e `cd ~/scsep-scada-view && docker compose up -d` |
| A página do Scada-LTS não abre | Na primeira vez demora de 3 a 5 minutos. Veja: `docker logs scadalts` |
| O vpn-local não conecta | Falta o token (`./adicionar-token.sh`) ou ele foi copiado incompleto. Veja: `docker logs vpn-local` |
| "Pouco espaço em disco" | Libere uns 6 GB. Containers antigos: `docker system prune` |
| "Could not get lock" / apt travado | Outra atualização está rodando: espere uns minutos (o instalador já espera até 3) e rode de novo |
| Quero meus containers antigos de volta | `cd ~/scsep-scada-view && ./voltar-containers.sh` |
| A porta 8080 está ocupada | O instalador escolhe outra sozinho e mostra o endereço certo no final |

### Baixar o pacote sem a linha de comando

```bash
cd ~ && git clone https://github.com/grei-ufc/scsep-scada-view.git && cd scsep-scada-view
./instalar-lab-ubuntu.sh        # ou -debian, -kali, -fedora
```

Pelo navegador: **Code > Download ZIP**, extraia e copie a pasta para o Linux (`cp -r /mnt/c/Users/SEU_USUARIO/Downloads/scsep-scada-view-main ~/scsep-scada-view`). Se aparecer "Permission denied" ao rodar um `.sh`, use `bash instalar-lab-ubuntu.sh`.

Pré-requisito no Windows: **WSL com Ubuntu** (PowerShell como administrador: `wsl --install -d Ubuntu`, reinicie e crie usuário e senha). O Docker **não** precisa estar instalado.

Depois da instalação, abra **http://localhost:8080/Scada-LTS/** (`admin` / `admin`; troque a senha). O instalador aplica sozinho (só na primeira vez) a configuração do Scada-LTS: Data Sources, pontos, controles liga/desliga e a tela **Painel de comando** (menu **Graphic views**), onde você **clica** nos botões e LEDs para comandar a simulação. Se aparecer "AVISO: não consegui importar sozinho", rode `python3 scada-lts/importar.py` (senha do admin trocada: `SCADA_SENHA=suasenha python3 scada-lts/importar.py`) ou importe `scada-lts/scada-lts-import.json` em **Import/Export**. Para atualizar: `git pull && ./iniciar.sh`.

## Onde fica o token

No arquivo `.env`, na linha `CHAVE=`. Sem o script: `cp .env.example .env`, edite e rode `docker compose up -d --build`.

| Variável | Significado | Padrão |
|---|---|---|
| `SERVIDOR` | Endereço do site do laboratório | `https://scsep.joaopedromagalhaes.com.br` |
| `CHAVE` | **Token de ativação** (`ak_…`) de "Meu laboratório" | vazio |
| `NOME` | Nome desta instalação | `Scada-LTS (Docker)` |
| `SCADA_PORT` | Porta do Scada-LTS no seu computador | `8080` |

O token só é lido na primeira ativação; depois o vpn-local guarda a credencial no volume `scada-lab_vpn-local_data`. Para trocar de token: `docker compose down`, `docker volume rm scada-lab_vpn-local_data`, ajuste `CHAVE` e `docker compose up -d`.

## Já tenho Scada-LTS e quero MANTER o meu

Se você já tem um Scada-LTS rodando e **não quer pará-lo**, use este comando: ele instala só o **vpn-local**, liga-o ao **seu** Scada-LTS e **aplica nele a configuração do laboratório** (4 Data Sources, 34 pontos, os controles liga/desliga e a tela **Painel de comando**). Nada que você já tem é parado, apagado ou alterado: a configuração só é **adicionada** (ele pergunta antes). Serve no Ubuntu e no Kali:

```bash
sudo apt update && sudo apt install -y curl && curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/instalar-no-meu-scada.sh | bash
```

- Ele acha sozinho o container do Scada-LTS; se houver mais de um, pergunta o nome (`docker ps`). Para informar direto: `LAB_ALVO=NOME_DO_CONTAINER` antes do comando, ou `./so-vpn-local.sh NOME_DO_CONTAINER` com o pacote baixado.
- Se o admin do seu Scada-LTS **não** for `admin`/`admin`, ele pede o usuário e a senha.
- Se você **recriar** o container do Scada-LTS, rode o comando de novo (o vpn-local usa a rede dele).
- Para **parar o seu** e usar o do laboratório, use o instalador do seu sistema (início desta página).

## Já tenho Docker e um Scada-LTS rodando

Use o instalador do seu sistema (início desta página). No **passo 2** ele lista os containers que estão rodando (inclusive o seu Scada-LTS), **pergunta** e os **PARA, sem apagar nada**. Para ligá-los de novo depois: `cd ~/scsep-scada-view && ./voltar-containers.sh`.

## Já tenho Docker e Scada-LTS: como ligar o vpn-local

Se você **já tem o Docker e um Scada-LTS rodando** (em outro container), não precisa do pacote completo: suba só o **vpn-local** e ligue-o ao **seu** Scada-LTS. Dentro da pasta do pacote:

```bash
./so-vpn-local.sh                    # procura sozinho o container do Scada-LTS
./so-vpn-local.sh NOME_DO_CONTAINER  # ou informe o nome (veja com: docker ps)
./so-vpn-local.sh --host             # Scada-LTS instalado direto no Linux/WSL, fora do Docker
```

O script pergunta o token, sobe o vpn-local **na mesma rede do seu Scada-LTS** e avisa quando estiver conectado. Com isso, no seu Scada-LTS os dispositivos Modbus ficam em `127.0.0.11`, `127.0.0.12` e `127.0.0.14` (porta `5020`), os mesmos endereços do pacote completo. Para criar os Data Sources, os pontos, os controles e a tela **Painel de comando** sem fazer à mão:

```bash
python3 scada-lts/importar.py scada-lts/scada-lts-import.json http://localhost:PORTA/Scada-LTS
```

Troque `PORTA` pela porta do seu Scada-LTS. Se a senha do admin não for `admin`: `SCADA_SENHA=suasenha python3 scada-lts/importar.py ...`.

- Se você **recriar** o container do Scada-LTS, rode `./so-vpn-local.sh` de novo: o vpn-local usa a rede dele.
- Se já existir um container chamado `vpn-local` (por exemplo, do pacote completo), o script **pergunta antes de substituir**.
- Se o seu Scada-LTS roda no **Windows** (fora do WSL), esse caminho não serve: use o pacote completo (instalador do seu sistema).

## Comandos do dia a dia

| Quero… | Comando |
|---|---|
| Ver o que o vpn-local faz | `docker logs -f vpn-local` |
| Reiniciar o vpn-local / o Scada-LTS | `docker restart vpn-local` / `docker restart scadalts` |
| Parar tudo (guarda os dados) | `docker compose down` |
| Apagar tudo, inclusive banco e credencial | `docker compose down -v` |
| Atualizar o pacote e a configuração do Scada-LTS | `git pull && ./iniciar.sh` |

## Conteúdo

```
instalar-lab-ubuntu.sh   # instalador Ubuntu (e Ubuntu do WSL)
instalar-lab-debian.sh   # instalador Debian
instalar-lab-kali.sh     # instalador Kali Linux
instalar-lab-fedora.sh   # instalador Fedora
lib/lab-comum.sh         # os passos e as mensagens, comuns aos quatro instaladores
iniciar.sh               # pergunta o token, grava o .env e sobe tudo
adicionar-token.sh       # adiciona (ou troca) o token do vpn-local depois da instalação
voltar-containers.sh     # (criado pelo instalador) liga de novo os containers que ele parou
instalar-no-meu-scada.sh # para quem já tem Scada-LTS e quer MANTER o dele: instala o vpn-local e aplica a configuração
so-vpn-local.sh          # o mesmo, com mais opções (nome do container, --host)
docker-compose.yml       # rede, mysql, vpn-local, scadalts
.env.example             # modelo de configuração (copie para .env)
vpn-local/               # Dockerfile e vpn-local-service.cjs (o vpn-local como serviço, gerado)
scada-lts/               # importar.py (aplica a configuração sozinho) e scada-lts-import.json: 4 Data Sources, 34 pontos, 18 point links e a tela gráfica "Painel de comando"
# Instaladores antigos (ainda funcionam): instalar.sh, instalar-kali.sh, instalar-fedora.sh, instalar-sem-token.sh, trocar-scada.sh
```

## Segurança

O `.env` e a credencial do vpn-local (guardada em texto no volume Docker) são pessoais: não compartilhe nem faça commit do `.env` (já está no `.gitignore`). O banco usa `root`/`root` e só é acessível dentro do Docker.
