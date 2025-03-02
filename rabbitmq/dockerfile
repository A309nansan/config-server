FROM rabbitmq:3-management

# 시간 동기화 설정: Asia/Seoul 타임존으로 설정
ENV TZ=Asia/Seoul
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 기본 포트 노출
EXPOSE 5672 15672