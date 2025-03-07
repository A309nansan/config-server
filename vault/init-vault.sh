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

# vault 작업 공간을 mount할 폴더 미리 생성
log "vault의 volume을 mount할 Host Machine에 /var/vault 만드는중..."
sudo mkdir -p /var/vault/config
sudo chown -R 1000:1000 /var/vault
sudo chown -R 1000:1000 /var/vault/config

cp vault.json /var/vault/config

# Docker Compose로 서비스 실행
log "Docker Compose로 서비스 실행 중..."
docker compose up -d

echo "작업이 완료되었습니다."
