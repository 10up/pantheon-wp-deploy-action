FROM debian:stable-slim

ARG PHP_VERSION=8.2

LABEL "com.github.actions.name"="Pantheon WordPress Deploy Action"
LABEL "com.github.actions.description"="Deploys a WordPress site to Pantheon"
LABEL "com.github.actions.icon"="send"
LABEL "com.github.actions.color"="blue"

LABEL maintainer="10upbot <10upbot+github@10up.com>"
LABEL version="1.0.0"
LABEL repository="https://github.com/10up/pantheon-wp-deploy-action"

RUN apt-get update \
	&& apt-get install -y curl \
    apt-transport-https \
    ca-certificates \
    git \
    lsb-release \
    rsync \
    wget \
	&& apt-get clean -y \
	&& rm -rf /var/lib/apt/lists/* 

RUN wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg \
  && echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list \
  && apt update \
  && apt install -y \
    php${PHP_VERSION} \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-xmlrpc \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-cli \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/* 

RUN mkdir ~/terminus && \
  cd ~/terminus && \
  curl -L https://github.com/pantheon-systems/terminus/releases/download/`curl --silent "https://api.github.com/repos/pantheon-systems/terminus/releases/latest" | perl -nle'print $& while m#"tag_name": "\K[^"]*#g'`/terminus.phar --output terminus && chmod +x terminus && \
  ln -s ~/terminus/terminus /usr/local/bin/terminus

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]