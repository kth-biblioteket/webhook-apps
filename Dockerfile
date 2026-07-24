FROM node:16-alpine

# Installera alla nödvändiga paket i ett lager
RUN apk add --no-cache \
    git \
    docker \
    bash \
    wget \
    ca-certificates \
    && mkdir -p /usr/local/lib/docker/cli-plugins \
    && wget -q -O /usr/local/lib/docker/cli-plugins/docker-compose \
        "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
    && chmod +x /usr/local/lib/docker/cli-plugins/docker-compose \
    && ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose \
    # Verifiera
    && docker --version \
    && docker-compose --version

WORKDIR /app

COPY . .

# Gör skriptet körbart
RUN chmod +x /app/deploy.sh

RUN npm install

EXPOSE 80

CMD ["npm", "start"]