#!/bin/bash
set -e  # 명령어 실패 시 스크립트 종료

# 작업 디렉토리로 이동
cd /home/ubuntu/docker/jenkins/master-volume || { echo "디렉토리 이동 실패"; exit 1; }

# update-center-rootCAs 디렉토리 생성 (이미 존재해도 에러 없음)
mkdir -p update-center-rootCAs

# 인증서 다운로드
wget https://cdn.jsdelivr.net/gh/lework/jenkins-update-center/rootCA/update-center.crt -O ./update-center-rootCAs/update-center.crt

# UpdateCenter XML 파일 수정
sudo sed -i 's#https://updates.jenkins.io/update-center.json#https://raw.githubusercontent.com/lework/jenkins-update-center/master/updates/tencent/update-center.json#' ./hudson.model.UpdateCenter.xml

# Jenkins Docker 컨테이너 재시작
sudo docker restart jenkins-master

echo "작업이 완료되었습니다."