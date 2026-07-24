FROM node:16-alpine

# Installera git, docker och docker-compose
RUN apk add --no-cache \
    git \
    docker \
    bash \
    wget \
    ca-certificates

# Installera Docker Compose v2
RUN mkdir -p /usr/local/lib/docker/cli-plugins \
    && wget -q -O /usr/local/lib/docker/cli-plugins/docker-compose \
    "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
    && chmod +x /usr/local/lib/docker/cli-plugins/docker-compose \
    && ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose

# Installera/uppdatera buildx
RUN mkdir -p /usr/local/lib/docker/cli-plugins \
    && wget -q -O /usr/local/lib/docker/cli-plugins/docker-buildx \
    "https://github.com/docker/buildx/releases/latest/download/buildx-$(uname -s)-$(uname -m)" \
    && chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx

# Verifiera installationer
RUN docker --version \
    && docker-compose --version \
    && docker buildx version

WORKDIR /app

COPY . .

RUN chmod +x /app/deploy.sh
RUN npm install

EXPOSE 80

CMD ["npm", "start"]