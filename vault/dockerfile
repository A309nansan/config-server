FROM hashicorp/vault:latest

# 시간 동기화 설정: Asia/Seoul 타임존으로 설정
ENV TZ=Asia/Seoul
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

EXPOSE 8200

# 공식 이미지는 기본적으로 dev 옵션으로 실행되도록 강제 주입하기 때문에 옵션을 reset
ENTRYPOINT []

CMD ["vault", "server", "-config=/vault/config/vault.json"]
