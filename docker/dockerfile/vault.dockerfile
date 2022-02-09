FROM docker.io/vault:latest

RUN apk update \
    && apk upgrade --update-cache --available\
    && apk add bash curl jq python3 py3-pip openssl \
    && pip3 install --upgrade pip \
    && pip3 install --no-cache-dir awscli \
    && rm -rf /var/cache/apk/* \
    && sed -i 's/\/bin\/ash/\/bin\/bash/g' /etc/passwd

RUN curl https://raw.githubusercontent.com/zevrant/zevrant-services-pipeline/master/bash/zevrant-services-start.sh > ~/startup.sh \
    && curl https://raw.githubusercontent.com/zevrant/zevrant-services-pipeline/master/bash/openssl.conf > ~/openssl.conf \
    && echo '#!/bin/bash' > /usr/local/bin/start.sh \
    && echo 'password=`date +%s | sha256sum | base64 | head -c 32`' >> /usr/local/bin/start.sh \
    && echo 'bash ~/startup.sh $SERVICE_NAME $password $ADDITIONAL_IP' >> /usr/local/bin/start.sh \
    && echo 'echo $password | openssl pkcs12 -in ~/zevrant-services.p12 -out /tmp/tls.key -passout pass: -nodes -nocerts -passin pass:$password' >> /usr/local/bin/start.sh \
    && echo 'openssl pkcs12 -in ~/zevrant-services.p12 -out /tmp/tls.crt -nokeys -passout pass: -passin pass:$password' >> /usr/local/bin/start.sh \
    && echo 'chown vault:vault /tmp/tls*' >> /usr/local/bin/start.sh \
    && echo 'docker-entrypoint.sh $@' >> /usr/local/bin/start.sh \
    && chmod +x /usr/local/bin/start.sh

COPY trusted-certs/zevrant-services-ca-root.crt zevrant-services-root-ca.crt

#Add custom ca to trusted cas
RUN cat zevrant-services-root-ca.crt >> /etc/ssl/certs/ca-certificates.crt

ENTRYPOINT ["start.sh"]
