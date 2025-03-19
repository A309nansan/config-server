#!/bin/bash

# 명령어 실패 시 스크립트 종료
set -euo pipefail

# 로그 출력 함수
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# 에러 발생 시 로그와 함께 종료하는 함수
error() {
  log "Error on line $1"
  exit 1
}

trap 'error $LINENO' ERR

log "스크립트 실행 시작."

# docker network 생성
if docker network ls --format '{{.Name}}' | grep -q '^nansan-network$'; then
  log "Docker network named 'nansan-network' is already existed."
else
  log "Docker network named 'nansan-network' is creating..."
  docker network create --driver bridge nansan-network
fi

# 필요한 환경변수를 Vault에서 가져오기
log "Get credential data from vault..."

TOKEN_RESPONSES=$(curl -s --request POST \
  --data "{\"role_id\":\"${ROLE_ID}\", \"secret_id\":\"${SECRET_ID}\"}" \
  https://vault.nansan.site/v1/auth/approle/login)

CLIENT_TOKEN=$(echo "$TOKEN_RESPONSES" | jq -r '.auth.client_token')

SECRET_RESPONSE=$(curl -s --header "X-Vault-Token: ${CLIENT_TOKEN}" \
  --request GET https://vault.nansan.site/v1/kv/data/auth)

CONFIG_SERVER_NAME=$(echo "$SECRET_RESPONSE" | jq -r '.data.data.configserver.username')
CONFIG_SERVER_PASSWORD=$(echo "$SECRET_RESPONSE" | jq -r '.data.data.configserver.password')
CONFIG_SERVER_GIT_URI=$(echo "$SECRET_RESPONSE" | jq -r '.data.data.configserver.server.git.uri')
GIT_USERNAME=$(echo "$SECRET_RESPONSE" | jq -r '.data.data.configserver.server.git.username')
GIT_PASSWORD=$(echo "$SECRET_RESPONSE" | jq -r '.data.data.configserver.server.git.password')
RABBITMQ_USERNAME=$(echo "$SECRET_RESPONSE" | jq -r '.data.data.rabbitmq.username')
RABBITMQ_PASSWORD=$(echo "$SECRET_RESPONSE" | jq -r '.data.data.rabbitmq.password')

# `BCrypt` 비밀번호 자동 생성
log "Generating BCrypt hashed password..."
CONFIG_SERVER_BCRYPT_PASSWORD=$(python3 -c "import bcrypt, sys; print(bcrypt.hashpw(sys.argv[1].encode(), bcrypt.gensalt()).decode())" "${CONFIG_SERVER_PASSWORD}")

if [[ -z "$CONFIG_SERVER_BCRYPT_PASSWORD" ]]; then
  log "BCrypt password generation failed!"
  exit 1
fi

# Build Gradle
log "build gradle"
./gradlew clean build

# 기존 config-server 이미지를 삭제하고 새로 빌드
log "config-server image remove and build."
docker rmi config-server:latest || true
docker build -t config-server:latest .

# Docker로 config-server 서비스 실행
log "Execute config-server..."
docker run -d \
  --name config-server \
  --restart unless-stopped \
  -e CONFIG_SERVER_NAME=${CONFIG_SERVER_NAME} \
  -e CONFIG_SERVER_PASSWORD=${CONFIG_SERVER_BCRYPT_PASSWORD} \
  -e CONFIG_SERVER_GIT_URI=${CONFIG_SERVER_GIT_URI} \
  -e GIT_USERNAME=${GIT_USERNAME} \
  -e GIT_PASSWORD=${GIT_PASSWORD} \
  -e RABBITMQ_USERNAME=${RABBITMQ_USERNAME} \
  -e RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD} \
  -e VAULT_SERVER_URI=${VAULT_SERVER_URI} \
  -e APP_ROLE_ROLE_ID=${APP_ROLE_ROLE_ID} \
  -e APP_ROLE_SECRET_ID=${APP_ROLE_SECRET_ID} \
  -p 8888:8888 \
  -v /var/config-server:/app/data \
  --network nansan-network \
  config-server:latest

echo "==== Succeed!!! ===="