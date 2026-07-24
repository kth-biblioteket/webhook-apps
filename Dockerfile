FROM node:16-alpine

# Installera git, docker och docker-compose
RUN apk add --no-cache \
    git \
    docker \
    bash \
    wget 

# Installera wget om det inte finns
RUN apk add --no-cache wget

# Installera Docker Compose v2 som Docker-plugin
RUN mkdir -p /usr/local/lib/docker/cli-plugins \
    && wget -O /usr/local/lib/docker/cli-plugins/docker-compose \
    "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
    && chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Verifiera installationen
RUN docker compose version

WORKDIR /app

COPY . .

RUN chmod +x /app/deploy.sh
RUN npm install

EXPOSE 80

CMD ["npm", "start"]