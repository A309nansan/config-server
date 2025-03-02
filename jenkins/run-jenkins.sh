#!/bin/bash
set -e

# Docker 소켓의 그룹 ID를 가져와서 DOCKER_GID 환경 변수에 저장
export DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
echo "DOCKER_GID set to: ${DOCKER_GID}"

# Docker Compose로 서비스 실행
docker compose up -d