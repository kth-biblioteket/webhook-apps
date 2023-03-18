#!/bin/sh

# variabler från argument
GIT_EVENT=${1}
GIT_REPOSITORY=${2}
GIT_COMMIT=${3}
GIT_ACTION=${4}
DOCKER_PATH=${5}

echo "Deploying application..."
echo {$GIT_EVENT}
cd /docker/$GIT_REPOSITORY
docker-compose pull
docker-compose down
docker-compose up -d --build
echo "Deployment successful!"