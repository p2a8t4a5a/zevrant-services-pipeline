FROM ubuntu:latest

EXPOSE 30000

RUN apt-get update \
    && apt-get full-upgrade -y \
    && apt-get install -y curl jq\
    && apt-get clean \
    && mkdir -p /usr/local/nvm \
    && curl 'http://zevrant-01.zevrant-services.com:7644/cacert.pem' -o /usr/local/share/ca-certificates/zevrant-services-ca-root.crt \
    && update-ca-certificates

ENV NVM_DIR /usr/local/nvm
#ENV NODE_VERSION 10.18.0

# Install nvm with node and npm
RUN curl https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash \
    && . $NVM_DIR/nvm.sh \
    && echo '. $NVM_DIR/nvm.sh' >> ~/.bashrc \
    && nvm install --lts \
    && nvm -v \
    && npm -v \
    && node -v

#ENV NODE_PATH $NVM_DIR/v$NODE_VERSION/lib/node_modules
#ENV PATH $NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

RUN useradd foundry;\
  usermod -u 36543 foundry;

RUN mkdir -p /opt/foundry \
    && mkdir -p /home/foundry/.local/share/ \
    && mkdir -p /home/foundry/.local/share/FoundryVTT \
    && chown -R foundry:foundry /opt/foundry \
    && chown -R foundry:foundry /home/foundry

USER foundry

ENV DATA_PATH=/home/foundry/.local/share/FoundryVTT
ENV NVM_DIR /usr/local/nvm
ENV PATH=$PATH:$NVM_DIR
RUN echo '. $NVM_DIR/nvm.sh' >> ~/.bashrc \
    && . $NVM_DIR/nvm.sh \
    && nvm use default \
    && node -v \
    && npm -v

RUN curl https://raw.githubusercontent.com/zevrant/zevrant-services-pipeline/master/bash/zevrant-services-start.sh > ~/startup.sh \
    && curl https://raw.githubusercontent.com/zevrant/zevrant-services-pipeline/master/bash/openssl.conf > ~/openssl.conf

COPY ./foundry /opt/foundry/

CMD . $NVM_DIR/nvm.sh \
    && password=`date +%s | sha256sum | base64 | head -c 32` \
    && bash ~/startup.sh $SERVICE_NAME $password \
    && echo $password | openssl pkcs12 -in ~/zevrant-services.p12 -out ~/tls.key -passout pass: -nodes -nocerts -passin pass:$password \
    && openssl pkcs12 -in ~/zevrant-services.p12 -out ~/tls.crt -nokeys -passout pass: -passin pass:$password \
    && sed -i "s~\"sslCert\": .*,\$~\"sslCert\": \"/home/foundry/tls.crt\",~g" ${DATA_PATH}/Config/options.json \
    && sed -i "s~\"sslKey\": .*,\$~\"sslKey\": \"/home/foundry/tls.key\",~g" ${DATA_PATH}/Config/options.json \
    && echo "using data from $DATA_PATH" \
    && node /opt/foundry/resources/app/main.js --dataPath $DATA_PATH --noupnp --noupdate --adminKey=$INITIAL_ADMIN_KEY
