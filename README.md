# KTH Biblioteket Webhook Apps

En Node.js-baserad webhook-mottagare för automatiserade deploymenter via GitHub Webhooks. Applikationen körs i en Docker-container med tillgång till hostens Docker-miljö, vilket möjliggör automatisk byggning och deployment av andra containrar.

## Översikt

Webhook-servern lyssnar på inkommande GitHub-webhooks, validerar deras signaturer och kör deployment-skript baserat på payloaden. Systemet är designat för att hantera deploymenter av Docker-baserade applikationer via ett externt deploy-script.

## Arkitektur

```
GitHub Webhook → Traefik (HTTPS) → webhook-apps-container → deploy.sh → Docker Compose
```

## Förutsättningar

- Docker och Docker Compose v2 på host-maskinen
- Traefik som reverse proxy (konfigurerat med Let's Encrypt)
- Externt Docker-nätverk `apps-net`
- GitHub-webhook konfigurerad med hemlighet (secret)

## Miljövariabler

Skapa en `.env`-fil med följande variabler:

| Variabel | Beskrivning | Exempel |
|----------|-------------|---------|
| `WEBHOOK_PORT` | Port som servern lyssnar på internt | `80` |
| `WEBHOOK_SECRET` | Hemlighet för webhook-signaturvalidering | `din-hemliga-nyckel` |
| `GITHUB_WEBHOOK_HASHALG` | Hash-algoritm för HMAC-validering | `sha256` |
| `GITHUB_WEBHOOK_SIGNATURE_HEADER` | HTTP-header för signaturen | `x-hub-signature-256` |
| `GITHUB_WEBHOOK_DEPLOY_SCRIPT` | Sökväg till deploy-scriptet | `/app/deploy.sh` |
| `WEBHOOK_DOCKER_PATH` | Sökväg till Docker Compose-filer på hosten | `/docker` |
| `HOST` | Hostname för Traefik-routing | `api-ref.lib.kth.se` |
| `PATHPREFIX` | URL-prefix för webhook-endpointen | `/webhook` |

## Installation på servern

Applikationen installeras på servern under sökvägen `/local/docker/webhook-apps`. På servern finns **inget repository** – endast Docker-bilden (från GHCR) och konfigurationsfilerna körs som en container.

Mappen `/local/docker` monteras in i webhook-containern som read-only (`:ro`), vilket gör att `deploy.sh` kan läsa och köra Docker Compose-filer för andra appar som ligger på servern.

### 1. Skapa mapp och konfigurationsfiler

```bash
sudo mkdir -p /local/docker/webhook-apps
```

### 2. Lägg `docker-compose.yml` på plats

Skapa filen `/local/docker/webhook-apps/docker-compose.yml`:

```yaml
services:
  webhook-apps:
    container_name: webhook-apps
    image: ghcr.io/kth-biblioteket/webhook-apps:main
    restart: always
    env_file:
      - .env
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.webhook-apps.rule=Host(`${HOST}`) && PathPrefix(`${PATHPREFIX}`)"
      - "traefik.http.routers.webhook-apps.middlewares=webhook-apps-stripprefix"
      - "traefik.http.middlewares.webhook-apps-stripprefix.stripprefix.prefixes=${PATHPREFIX}"
      - "traefik.http.routers.webhook-apps.entrypoints=websecure"
      - "traefik.http.routers.webhook-apps.tls=true"
      - "traefik.http.routers.webhook-apps.tls.certresolver=myresolver"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /local/docker:/docker:ro
    networks:
      - apps-net
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:${WEBHOOK_PORT}/hook"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

networks:
  apps-net:
    external: true
```

### 3. Skapa `.env`-fil

```bash
sudo nano /local/docker/webhook-apps/.env
```

Exempel:
```env
WEBHOOK_PORT=80
WEBHOOK_SECRET=super-hemlig-nyckel-fran-github
GITHUB_WEBHOOK_HASHALG=sha256
GITHUB_WEBHOOK_SIGNATURE_HEADER=x-hub-signature-256
GITHUB_WEBHOOK_DEPLOY_SCRIPT=/app/deploy.sh
WEBHOOK_DOCKER_PATH=/docker
HOST=api-ref.lib.kth.se
PATHPREFIX=/webhook
```

### 4. Skapa det externa nätverket

```bash
sudo docker network create apps-net
```

> **Observera:** `apps-net` måste vara samma nätverk som Traefik och andra appar använder.

### 5. Starta tjänsten

```bash
cd /local/docker/webhook-apps
sudo docker compose up -d
```

Bilden dras automatiskt från `ghcr.io/kth-biblioteket/webhook-apps:main`.

> **Observera:** Vid första körningen finns bilden inte lokalt, så `docker compose up -d` **pullar automatiskt** från GHCR. Vid efterföljande uppdateringar krävs `docker compose pull` för att hämta en nyare version.

### 6. Verifiera installationen

```bash
# Kontrollera att containern körs
sudo docker ps | grep webhook-apps

# Testa healthcheck
curl https://api-ref.lib.kth.se/webhook/hook
```

Förväntat svar:
```
KTH Biblioteket Webhooks för Apps
```

### 7. Konfigurera app-repon (GitHub Actions)

I varje app-repo som ska deployas via webhooken lägger du till en GitHub Actions-workflow. Workflowen bygger och pushar Docker-bilden till GHCR, och anropar sedan webhook-servern för att trigga deployment.

#### Exempel: `.github/workflows/build-and-deploy.yml`

```yaml
name: Create, publish Docker image and Deploy using webhook

on:
  push:
    branches: ['ref']

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build-and-push-image:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Log in to the Container registry
        uses: docker/login-action@v2
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.DEPLOY_TOKEN }}

      - name: Extract metadata (tags, labels) for Docker
        id: meta
        uses: docker/metadata-action@v4
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}

      - name: Build and push Docker image
        uses: docker/build-push-action@v3
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}

  deploy:
    needs: build-and-push-image
    runs-on: ubuntu-latest
    steps:
      - name: Deploy docker container webhook
        uses: distributhor/workflow-webhook@v2
        env:
          webhook_url: https://api-ref.lib.kth.se/webhooks/hook
          webhook_secret: ${{ secrets.WEBHOOK_SECRET }}
          data: '{ "action": "deploy" }'
```

#### Förutsättningar per app-repo som ska använde denna webhook

1. **DEPLOY_TOKEN** – Repository secret med `write:packages`-behörighet för GHCR.
2. **WEBHOOK_SECRET** – Repository secret med samma värde som `WEBHOOK_SECRET` i webhook-serverns `.env`. Används för att signera och validera webhook-anropet.

#### Så fungerar flödet

```
1. Push till branch (t.ex. 'ref')
        ↓
2. Actions bygger och pushar Docker-bild till GHCR
        ↓
3. Deploy-jobb anropar webhook-servern via distributhor/workflow-webhook@v2
        ↓
4. Webhook-servern validerar signaturen med WEBHOOK_SECRET
        ↓
5. deploy.sh körs med event, repo, commit och action
        ↓
6. Docker Compose bygger/startar om app-containern
```

> **Observera:** `distributhor/workflow-webhook@v2` skickar automatiskt med metadata om repositoryt, eventet och commit:en i payloaden. Webhook-servern (`index.js`) extraherar dessa fält för att bygga kommandot till `deploy.sh`.

#### Payload som skickas till webhooken

`workflow-webhook` skickar en payload som innehåller:
- `event` – Typ av GitHub-event (t.ex. `push`)
- `repository` – Fullt repo-namn (`owner/repo-name`)
- `commit` – Commit-hash
- `data.action` – Action som ska utföras (`deploy`)

Webhook-servern validerar signaturen och kör `deploy.sh` med dessa parametrar.

### Filstruktur på servern

```
/local/docker/
├── webhook-apps/
│   ├── docker-compose.yml      # Endast denna och .env behövs
│   └── .env
│
├── <andra-app-1>/
│   └── docker-compose.yml
│
└── <andra-app-2>/
    └── docker-compose.yml
```

> **Viktigt:** Källkoden (`index.js`, `Dockerfile`, etc.) finns **inte** på servern. All kod är inbäddad i Docker-bilden som byggs via GitHub Actions.

### Uppdatera på servern

När en ny version pushas till `main` byggs bilden automatiskt via GitHub Actions. För att uppdatera på servern:

```bash
cd /local/docker/webhook-apps
sudo docker compose pull
sudo docker compose up -d
```

> **Viktigt:** `docker compose up -d` gör **inte** automatiskt en `pull` om det redan finns en lokal bild. Den använder den lokala bilden även om en nyare version finns i registret. Därför krävs `docker compose pull` först.
>
> Alternativt kan du köra `sudo docker compose up -d --pull always` för att alltid hämta den senaste bilden.

---

## API Endpoints

### GET /hook

Healthcheck-endpoint. Returnerar en enkel textbekräftelse.

**Svar:**
- `200 OK` - Servern är igång

### POST /hook

Huvudendpoint för webhook-anrop. Validerar signaturen och bearbetar payloaden.

**Headers:**
- `x-hub-signature-256` - HMAC-SHA256-signatur av payloaden

**Payload (JSON):**
```json
{
  "event": "push",
  "repository": "owner/repo-name",
  "commit": "abc123...",
  "data": {
    "action": "deploy"
  }
}
```

**Svar:**
- `200 OK` - Deployment lyckades
- `401 Unauthorized` - Ogiltig signatur
- `500 Internal Server Error` - Deployment misslyckades
- `204 No Content` - Ingen handler för angiven action

## Säkerhet

### Signaturvalidering

Alla inkommande webhooks valideras med HMAC-SHA256. Signaturen skickas i headern `x-hub-signature-256` och har formatet:
```
sha256=<hex-hash>
```

Servern beräknar hash av payloaden (JSON-strängifierad) med den konfigurerade hemligheten och jämför med den mottagna signaturen.

### Container-säkerhet

- Docker-socket monteras read-write (krävs för Docker-kommandon)
- Docker Compose-filer monteras read-only (`:ro`)
- Traefik hanterar TLS/SSL via Let's Encrypt
- Endast verifierade webhooks accepteras

## Deploy-script

Deploy-scriptet (`deploy.sh`) anropas med följande argument:

```bash
deploy.sh <event> <repository> <commit> <action> <docker-path>
```

**Argument:**
1. `event` - Typ av GitHub-event (t.ex. `push`)
2. `repository` - Repositoriets namn (utan owner)
3. `commit` - Commit-hash
4. `action` - Action från payload (t.ex. `deploy`)
5. `docker-path` - Sökväg till Docker-konfiguration

**Timeout:**
- Standard: 5 minuter
- Deployment: 10 minuter
- Max buffer: 50 MB

## Docker-konfiguration

### Dockerfile

Baseras på `node:16-alpine` och inkluderar:
- Git, Bash, wget, ca-certificates
- Docker CLI
- Docker Compose v2
- Docker Buildx v0.20.0

### Docker Compose

Tjänsten konfigureras med:
- Automatisk omstart (`restart: always`)
- Healthcheck var 30:e sekund
- Traefik-labels för routing och TLS
- Volym-monteringar för Docker-socket och compose-filer

## Loggning

Servern loggar detaljerad information:
- Signaturvalidering
- Mottagen payload
- Deployment-status
- Fel och stack traces

Loggar visas i realtid från deploy-scriptet via stdout/stderr.

## Underhåll

### Uppdatera bilden

```bash
docker compose pull
docker compose up -d
```

### Visa loggar

```bash
docker logs -f webhook-apps
```

### Hälsokontroll

```bash
docker inspect --format='{{.State.Health.Status}}' webhook-apps
```

## Utveckling

### Lokalt

```bash
npm install
npm start
```

### Bygg Docker-bild

```bash
docker build -t webhook-apps .
```

## Felhantering

- **Ogiltig signatur**: Returnerar 401 med tidsstämpel
- **Saknat deploy-script**: Returnerar 500 med felmeddelande
- **Deployment-fel**: Loggar stdout/stderr och returnerar 500 med detaljer
- **Ohanterade fel**: Global error handler returnerar 500

## CI/CD - GitHub Actions

Projektet använder GitHub Actions för att automatiskt bygga och publicera Docker-bilden till GitHub Container Registry (GHCR).

### Workflow: `buildimage.yml`

**Triggas vid:** Push till `main`-branchen

**Plats:** `.github/workflows/buildimage.yml`

```yaml
name: Create and publish Docker image

on:
  push:
    branches: ['main']

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build-and-push-image:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Log in to the Container registry
        uses: docker/login-action@v2
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.DEPLOY_TOKEN }}

      - name: Extract metadata (tags, labels) for Docker
        id: meta
        uses: docker/metadata-action@v4
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}

      - name: Build and push Docker image
        uses: docker/build-push-action@v3
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

### Förutsättningar för Actions

1. **DEPLOY_TOKEN** – En Personal Access Token (PAT) eller repository secret med `write:packages`-behörighet måste läggas till under **Settings → Secrets and variables → Actions**.

2. **Package-åtkomst** – Se till att GHCR-paketet har rätt åtkomsträttigheter (repository-baserad eller organisation-baserad).

### Publicerad bild

Bilden publiceras automatiskt till:
```
ghcr.io/<owner>/webhook-apps:main
```

Denna referens används i `docker-compose.yml` under `image:`.

---

## Licens

Internt projekt för KTH Biblioteket.