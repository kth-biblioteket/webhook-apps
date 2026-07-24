FROM node:16-alpine

# Installera baspaket
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

# Installera buildx (stabil version)
RUN mkdir -p /usr/local/lib/docker/cli-plugins \
    && wget -q -O /usr/local/lib/docker/cli-plugins/docker-buildx \
    "https://github.com/docker/buildx/releases/download/v0.14.1/buildx-v0.14.1.linux-amd64" \
    && chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx

# Verifiera
RUN docker --version \
    && docker buildx version \
    && docker-compose --version

WORKDIR /app

COPY . .

RUN chmod +x /app/deploy.sh
RUN npm install

EXPOSE 80

CMD ["npm", "start"]