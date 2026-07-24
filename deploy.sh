#!/bin/sh

# Variabler från argument
GIT_EVENT=${1}
GIT_REPOSITORY=${2}
GIT_COMMIT=${3}
GIT_ACTION=${4}
DOCKER_PATH=${5}

# Logga start
echo "========================================="
echo "🚀 Starting deployment..."
echo "========================================="
echo "📋 Event: ${GIT_EVENT}"
echo "📂 Repository: ${GIT_REPOSITORY}"
echo "🔖 Commit: ${GIT_COMMIT}"
echo "⚡ Action: ${GIT_ACTION}"
echo "📁 Docker path: ${DOCKER_PATH}"
echo "========================================="

# Kontrollera att vi är i rätt katalog
cd /docker/${GIT_REPOSITORY} || {
    echo "❌ ERROR: Could not change to directory /docker/${GIT_REPOSITORY}"
    exit 1
}

echo "📂 Current directory: $(pwd)"

# Visa Docker Compose version
echo "🐳 Docker Compose version:"
docker compose version || {
    echo "❌ ERROR: Docker Compose v2 not found!"
    echo "ℹ️  Please install Docker Compose v2"
    exit 1
}

# Visa Docker version
echo "🐳 Docker version:"
docker --version

# Visa vilka containrar som körs innan deployment
echo "📊 Current containers before deployment:"
docker compose ps

# Pull nya images med loggning
echo "========================================="
echo "📥 Pulling latest images..."
echo "========================================="
docker compose pull 2>&1 | while IFS= read -r line; do
    echo "[PULL] $line"
done

# Kolla pull status
if [ $? -ne 0 ]; then
    echo "❌ ERROR: Failed to pull images!"
    exit 1
fi
echo "✅ Images pulled successfully"

# Stoppa containrar med loggning
echo "========================================="
echo "🛑 Stopping containers..."
echo "========================================="
docker compose down 2>&1 | while IFS= read -r line; do
    echo "[DOWN] $line"
done

# Starta containrar med loggning
echo "========================================="
echo "🚀 Starting containers with build..."
echo "========================================="
docker compose up -d --build 2>&1 | while IFS= read -r line; do
    echo "[UP] $line"
done

# Kolla start status
if [ $? -ne 0 ]; then
    echo "❌ ERROR: Failed to start containers!"
    exit 1
fi
echo "✅ Containers started successfully"

# Visa containerstatus efter deployment
echo "========================================="
echo "📊 Container status after deployment:"
echo "========================================="
docker compose ps

echo "========================================="
echo "✅ Deployment completed successfully!"
echo "========================================="
echo "📊 Summary:"
echo "   Repository: ${GIT_REPOSITORY}"
echo "   Commit: ${GIT_COMMIT}"
echo "   Containers running:"
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

# Logga avslut
echo "========================================="
echo "📅 Deployment finished at: $(date)"
echo "========================================="