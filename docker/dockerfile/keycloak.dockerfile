FROM quay.io/keycloak/keycloak:latest

USER root

RUN microdnf install -y jq python3-pip \
    && pip3 install awscli \
    && mkdir -p /etc/x509/https/ \
    && chown -R root:jboss /etc/x509/https/ \
    && chmod -R 0770 /etc/x509/https/

USER jboss

RUN curl https://raw.githubusercontent.com/zevrant/zevrant-services-pipeline/master/bash/zevrant-services-start.sh > ~/startup.sh \
    && curl https://raw.githubusercontent.com/zevrant/zevrant-services-pipeline/master/bash/openssl.conf > /opt/jboss/openssl.conf

ENTRYPOINT password=`date +%s | sha256sum | base64 | head -c 32` \
    && bash ~/startup.sh $SERVICE_NAME $password $ADDITIONAL_IP\
    && echo $password | openssl pkcs12 -in ~/zevrant-services.p12 -out /etc/x509/https/tls.key -passout pass: -nodes -nocerts -passin pass:$password \
    && openssl pkcs12 -in ~/zevrant-services.p12 -out /etc/x509/https/tls.crt -nokeys -passout pass: -passin pass:$password \
    && /opt/jboss/tools/docker-entrypoint.sh

CMD ["-b", "0.0.0.0"]
