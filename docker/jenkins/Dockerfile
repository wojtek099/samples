FROM jenkins/jenkins:lts-alpine

ARG DOCKER_GROUP_ID

USER root

RUN getent group $DOCKER_GROUP_ID || addgroup -g $DOCKER_GROUP_ID docker
RUN addgroup jenkins `getent group $DOCKER_GROUP_ID | awk -F: '{printf $1}'` && \ 
    echo "user jenkins added to group: `getent group $DOCKER_GROUP_ID`"

# install docker-compose
RUN apk add --no-cache py-pip libffi-dev openssl-dev gcc libc-dev make
RUN curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
RUN chmod +x /usr/local/bin/docker-compose

# install docker-cli
RUN apk add --no-cache docker-cli

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN /usr/local/bin/install-plugins.sh < /usr/share/jenkins/ref/plugins.txt
# RUN echo 2.0 > /usr/share/jenkins/ref/jenkins.install.UpgradeWizard.state

USER jenkins
