FROM ruby:2.6-alpine
MAINTAINER Matt Conway <matt@simplygenius.com>

ENV APP_DIR /atmos
ENV RUN_DIR /app
ENV TF_VER=0.11.10
ENV TF_PKG=https://releases.hashicorp.com/terraform/${TF_VER}/terraform_${TF_VER}_linux_amd64.zip

RUN mkdir -p $APP_DIR $RUN_DIR
WORKDIR $APP_DIR

COPY . $APP_DIR/

ENV BUILD_PACKAGES=""
ENV APP_PACKAGES="bash curl git docker"

RUN apk --update upgrade && \
    apk add \
      --virtual app \
      $APP_PACKAGES && \
    apk add \
      --virtual build_deps \
      $BUILD_PACKAGES && \
    rake install && \
    apk del build_deps && \
    rm -rf /var/cache/apk/*

RUN curl -sL $TF_PKG > terraform.zip && \
    unzip terraform.zip && \
    mv terraform /usr/local/bin && \
    rm -f terraform.zip

WORKDIR $RUN_DIR
VOLUME $RUN_DIR

ENTRYPOINT ["atmos"]
