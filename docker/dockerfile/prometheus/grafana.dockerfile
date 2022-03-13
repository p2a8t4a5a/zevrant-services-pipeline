FROM grafana/grafana:latest

RUN curl 'http://zevrant-01.zevrant-services.com:7644/cacert.pem' -o /usr/local/share/ca-certificates/zevrant-services-ca-root.crt \
    && update-ca-certificates


ENTRYPOINT password=`date +%s | sha256sum | base64 | head -c 32` \
    && bash ~/startup.sh $SERVICE_NAME $password $ADDITIONAL_IP\
    && echo $password | openssl pkcs12 -in ~/zevrant-services.p12 -out /etc/x509/https/tls.key -passout pass: -nodes -nocerts -passin pass:$password \
    && openssl pkcs12 -in ~/zevrant-services.p12 -out /etc/x509/https/tls.crt -nokeys -passout pass: -passin pass:$password \
    &&
