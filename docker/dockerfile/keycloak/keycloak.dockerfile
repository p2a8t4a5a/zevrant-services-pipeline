FROM quay.io/keycloak/keycloak:latest

RUN whoami && groups

USER root

RUN microdnf install -y jq python3-pip openssl \
    && mkdir -p /etc/x509/https/ \
#    && chown -R root:jboss /etc/x509/https/ \
    && chmod -R 0770 /etc/x509/https/

RUN curl http://zevrant-01.zevrant-services.com:7644/cacert.pem -o /etc/pki/ca-trust/source/anchors/zevrant-services.pem \
    && cat /etc/pki/ca-trust/source/anchors/zevrant-services.pem \
    && update-ca-trust

USER keycloak

RUN curl https://raw.githubusercontent.com/zevrant/zevrant-services-pipeline/master/bash/zevrant-services-start.sh > ~/startup.sh \
  && curl https://raw.githubusercontent.com/zevrant/zevrant-services-pipeline/master/bash/openssl.conf > ~/openssl.conf


ENTRYPOINT password=`date +%s | sha256sum | base64 | head -c 32` \
    && bash ~/startup.sh $SERVICE_NAME $password $ADDITIONAL_IP\
    && echo $password | openssl pkcs12 -in ~/zevrant-services.p12 -out /etc/x509/https/tls.key -passout pass: -nodes -nocerts -passin pass:$password \
    && openssl pkcs12 -in ~/zevrant-services.p12 -out /etc/x509/https/tls.crt -nokeys -passout pass: -passin pass:$password \
    && KC_HOSTNAME=$EXTERNAL_HOSTNAME KC_DB=postgres KC_METRICS_ENABLED=true KC_HTTPS_KEY_STORE_FILE=~/zevrant-services.p12 KC_HTTPS_KEY_STORE_PASSWORD=$password /opt/keycloak/bin/kc.sh start --db-password '$DB_PASSWORD' --auto-build --db-url $DB_ADDR --db-username $DB_USER \
    && /opt/keycloak/bin/kc.sh start

CMD ["-b", "0.0.0.0"]
