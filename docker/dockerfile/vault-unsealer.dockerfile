FROM ubuntu:latest

RUN apt-get update \
    && apt-get update -y \
    && apt-get install -y curl jq

COPY trusted-certs/zevrant-services-ca-root.crt /usr/local/share/ca-certificates/zevrant-services.crt

RUN update-ca-certificates

RUN echo 'echo "Starting unsealer"' > /usr/local/bin/start.sh \
    && echo 'status=""' >> /usr/local/bin/start.sh \
    && echo 'while true' >> /usr/local/bin/start.sh \
    && echo 'do' >> /usr/local/bin/start.sh \
    && echo '    echo $URL'  >> /usr/local/bin/start.sh \
    && echo '    status=$(curl -s https://${URL}:8200/v1/sys/seal-status)' >> /usr/local/bin/start.sh \
    && echo '    echo $status' >> /usr/local/bin/start.sh \
    && echo '    status=$(echo $status | jq .sealed)' >> /usr/local/bin/start.sh \
    && echo '    if [ true == "$status" ];' >> /usr/local/bin/start.sh \
    && echo '    then' >> /usr/local/bin/start.sh \
    && echo '        echo "Unsealing"' >> /usr/local/bin/start.sh \
    && echo '        curl -s --request PUT --data "{\"key\": \"$(echo $KEY1)\"}" https://${URL}:8200/v1/sys/unseal' >> /usr/local/bin/start.sh \
    && echo '        curl -s --request PUT --data "{\"key\": \"$(echo $KEY2)\"}" https://${URL}:8200/v1/sys/unseal' >> /usr/local/bin/start.sh \
    && echo '        curl -s --request PUT --data "{\"key\": \"$(echo $KEY3)\"}" https://${URL}:8200/v1/sys/unseal' >> /usr/local/bin/start.sh \
    && echo '        status=$(curl -s https://${URL}:8200/v1/sys/seal-status | jq .sealed)' >> /usr/local/bin/start.sh \
    && echo '    fi' >> /usr/local/bin/start.sh \
    && echo '    sleep 10' >> /usr/local/bin/start.sh \
    && echo 'done' >> /usr/local/bin/start.sh


ENTRYPOINT bash /usr/local/bin/start.sh
