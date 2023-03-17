FROM node:16-alpine

# Installera git
RUN apk add --no-cache git

# Installera docker client
RUN apk add --no-cache docker

# Installera docker-compose
RUN apk update && \
    apk add --no-cache docker-compose

WORKDIR /app

COPY . .

# Gör skriptet körbart
RUN chmod +x /app/deploy.sh

RUN npm install

EXPOSE 80

CMD ["npm", "start"]