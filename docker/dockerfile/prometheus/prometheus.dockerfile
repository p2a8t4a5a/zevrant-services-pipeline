FROM ubuntu:latest

RUN apt-get update && apt-get full-upgrade -y && apt-get install -y curl jq

RUN mkdir -p /etc/prometheus /var/lib/prometheus \
    && mkdir -p /usr/local/share/ca-certificates/extra \
    && useradd --no-create-home --shell /bin/false prome \
    && useradd --no-create-home --shell /bin/false node_exporter \
    && curl https://raw.githubusercontent.com/zevrant/zevrant-services-pipeline/master/bash/zevrant-services.crt \
      -o /usr/local/share/ca-certificates/zevrant-services.crt \
    && update-ca-certificates -v \
    && ls -l /etc/ssl/certs/zevrant-services.pem

RUN url="$(curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest | jq .assets[10].browser_download_url)"\
    && curl -L $(echo "$url" | cut -c 2-$((${#url}-1))) -o prometheus.tar.gz \
    && tar xvf prometheus.tar.gz \
    && mv prometheus-* prometheus \
    && cp prometheus/prometheus /usr/local/bin/ \
    && cp prometheus/promtool /usr/local/bin/ \
    && chown prome:prome /usr/local/bin/prometheus \
    && cp -r prometheus/consoles /etc/prometheus \
    && cp -r prometheus/console_libraries /etc/prometheus \
    && chown -R prome:prome /etc/prometheus/consoles \
    && chown -R prome:prome /etc/prometheus/console_libraries \
    && rm -rf prometheus.tar.gz prometheus


#Install root ca cert
RUN curl 'http://zevrant-01.zevrant-services.com:7644/cacert.pem' -o /usr/local/share/ca-certificates/zevrant-services-ca-root.crt \
    && update-ca-certificates


ADD prometheus.yml /etc/prometheus/
ADD rules.yml /etc/prometheus

CMD /usr/local/bin/prometheus \
        --config.file /etc/prometheus/prometheus.yml \
        --storage.tsdb.path /var/lib/prometheus/ \
        --web.console.templates=/etc/prometheus/consoles \
        --web.console.libraries=/etc/prometheus/console_libraries
