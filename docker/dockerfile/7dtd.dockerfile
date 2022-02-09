FROM docker.io/cm2network/steamcmd:latest

USER root
#OS Update and Setup
RUN apt-get update \
    && apt-get upgrade -y \
    && mkdir -p /opt/7dtd \
    && useradd -m -d /opt/7dtd 7dtd

USER steam
#Install 7dtd
RUN echo "@ShutdownOnFailedCommand 1 //set to 0 if updating multiple servers at once" > 7dtdInstall.txt \
    && echo "@NoPromptForPassword 1" >> 7dtdInstall.txt \
    && echo "force_install_dir /opt/7dtd" >> 7dtdInstall.txt \
    && echo "login anonymous" >> 7dtdInstall.txt \
    && echo "app_update 294420 validate" >> 7dtdInstall.txt \
    && echo "quit" >> 7dtdInstall.txt \
    && ./steamcmd.sh +runscript 7dtdInstall.txt

#Configure 7dtd


CMD  '/home/steam/Steam/steamapps/common/7 Days to Die Dedicated Server/startserver.sh' -configfile=serverconfig.xml
