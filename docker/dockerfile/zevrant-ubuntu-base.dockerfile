FROM docker.io/ubuntu:latest

RUN apt-get update\
    && apt-get upgrade -y

RUN DEBIAN_FRONTEND="noninteractive" apt-get -y install openjdk-11-jdk python3 python3-pip wget iproute2 net-tools jq curl \
    && ln -sf /usr/lib/jvm/java-1.11.0-openjdk-amd64/ /usr/bin/java \
    && apt-get autoremove -y \
    && apt-get clean

ENV JAVA_HOME /usr/lib/jvm/java-1.11.0-openjdk-amd64/

ENV PATH /usr/local/scripts:/usr/local/scripts/python:$JAVA_HOME/bin:$PATH:$NODEJS_HOME/bin

RUN pip3 install awscli

RUN groupadd --system developers

COPY trusted-certs/zevrant-services-ca-root.crt zevrant-services-ca-root.crt

RUN echo yes | keytool --import --alias zevrant-services-root-ca --file zevrant-services-ca-root.crt --keystore $JAVA_HOME/lib/security/cacerts -storepass changeit \
    && rm zevrant-services-ca-root.crt
