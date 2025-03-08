#!/bin/bash
set -euo pipefail  # 명령어 실패 시 스크립트 종료

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

# docker network 생성 (이미 존재하면 스킵)
if docker network ls --format '{{.Name}}' | grep -q '^nansan-network$'; then
  log "Docker network 'nansan-network'가 이미 존재합니다. 생성 스킵."
else
  log "Docker network 'nansan-network' 생성 중."
  docker network create --driver bridge nansan-network
fi

# rabbitmq 이미지 빌드
log "rabbitmq 이미지 빌드 시작."
docker build -t rabbitmq:latest .

# rabbitmq 작업 공간을 mount할 폴더 미리 생성
log "rabbitmq의 volume을 mount할 Host Machine에 /var/rabbitmq 만드는중..."
sudo mkdir -p /var/rabbitmq
sudo chown -R 1000:1000 /var/rabbitmq

# Vault 서버 주소와 토큰, 시크릿 경로 설정
VAULT_ADDR="http://127.0.0.1:8200"
VAULT_TOKEN="insert your token"
SECRET_PATH="rabbitmq/data/authentication"

# Vault API 호출하여 시크릿 조회
response=$(curl --silent --header "X-Vault-Token: ${VAULT_TOKEN}" ${VAULT_ADDR}/v1/${SECRET_PATH})

# 에러 체크: 응답이 비어있거나 오류가 있을 경우
if [ -z "$response" ]; then
  echo "Vault에서 시크릿을 가져오지 못했습니다."
  exit 1
fi

# jq를 사용해 JSON 응답에서 사용자 이름과 비밀번호 추출 (jq가 설치되어 있어야 함)
RABBITMQ_DEFAULT_USER=$(echo "$response" | jq -r '.data.data.RABBITMQ_DEFAULT_USER')
RABBITMQ_DEFAULT_PASS=$(echo "$response" | jq -r '.data.data.RABBITMQ_DEFAULT_PASS')

# Docker Compose로 서비스 실행
log "Docker Compose로 서비스 실행 중..."
docker compose up -d

echo "작업이 완료되었습니다."
