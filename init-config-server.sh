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
  --request GET https://vault.nansan.site/v1/kv/data/authentication)

CONFIG_SERVER_USERNAME=$(echo "$SECRET_RESPONSE" | jq -r '.data.data.configserver.username')
CONFIG_SERVER_PASSWORD=$(echo "$SECRET_RESPONSE" | jq -r '.data.data.configserver.password')
PRIVATE_GIT_URI=$(echo "$SECRET_RESPONSE" | jq -r '.data.data.privategitrepo.uri')
PRIVATE_GIT_USERNAME=$(echo "$SECRET_RESPONSE" | jq -r '.data.data.privategitrepo.username')
PRIVATE_GIT_PASSWORD=$(echo "$SECRET_RESPONSE" | jq -r '.data.data.privategitrepo.password')
RABBITMQ_USERNAME=$(echo "$SECRET_RESPONSE" | jq -r '.data.data.rabbitmq.username')
RABBITMQ_PASSWORD=$(echo "$SECRET_RESPONSE" | jq -r '.data.data.rabbitmq.password')

# `BCrypt` 비밀번호 자동 생성
log "Generating BCrypt hashed password..."
CONFIG_SERVER_BCRYPT_PASSWORD=$(python3 -c "import bcrypt, sys; print(bcrypt.hashpw(sys.argv[1].encode(), bcrypt.gensalt()).decode())" "${CONFIG_SERVER_PASSWORD}")

# Build Gradle
log "build gradle"
./gradlew clean build

# 기존 인스턴스 삭제
log "config-server undeploy"
docker rm -f config-server

# 기존 config-server 이미지를 삭제하고 새로 빌드
log "config-server image remove and build."
docker rmi config-server:latest || true
docker build -t config-server:latest .

# Docker로 config-server 서비스 실행
log "Execute config-server..."
docker run -d \
  --name config-server \
  --dns 8.8.8.8 \
  --dns 1.1.1.1 \
  --restart unless-stopped \
  -v /var/config-server:/app/data \
  -p 13010:8888 \
  -e CONFIG_SERVER_USERNAME=${CONFIG_SERVER_USERNAME} \
  -e CONFIG_SERVER_PASSWORD=${CONFIG_SERVER_BCRYPT_PASSWORD} \
  -e PRIVATE_GIT_URI=${PRIVATE_GIT_URI} \
  -e PRIVATE_GIT_USERNAME=${PRIVATE_GIT_USERNAME} \
  -e PRIVATE_GIT_PASSWORD=${PRIVATE_GIT_PASSWORD} \
  -e RABBITMQ_USERNAME=${RABBITMQ_USERNAME} \
  -e RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD} \
  --network nansan-network \
  config-server:latest

echo "==== Succeed!!! ===="
