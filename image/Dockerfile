FROM debian:stable-slim

LABEL "com.github.actions.name"="Pantheon WordPress Deploy Action"
LABEL "com.github.actions.description"="Deploys a WordPress site to Pantheon"
LABEL "com.github.actions.icon"="send"
LABEL "com.github.actions.color"="blue"

LABEL maintainer="10upbot <10upbot+github@10up.com>"
LABEL version="1.0.0"
LABEL repository="https://github.com/10up/pantheon-wp-deploy-action"

RUN apt-get update \
	&& apt-get install -y curl \
    git \
    rsync \
	&& apt-get clean -y \
	&& rm -rf /var/lib/apt/lists/* 

RUN mkdir ~/terminus && \
  cd ~/terminus && \
  curl -L https://github.com/pantheon-systems/terminus/releases/download/`curl --silent "https://api.github.com/repos/pantheon-systems/terminus/releases/latest" | perl -nle'print $& while m#"tag_name": "\K[^"]*#g'`/terminus.phar --output terminus && chmod +x terminus && \
  ln -s ~/terminus/terminus /usr/local/bin/terminus

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]