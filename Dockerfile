FROM ruby:2.5-alpine
MAINTAINER Matt Conway <matt@simplygenius.com>

ENV APP_DIR /atmos
RUN mkdir -p $APP_DIR
WORKDIR $APP_DIR

COPY Gemfile Gemfile.lock *.gemspec $APP_DIR/
COPY lib/atmos/version.rb $APP_DIR/lib/atmos/

 # "build-base ruby-dev"
ENV BUILD_PACKAGES=""
ENV APP_PACKAGES="git"

RUN apk --update upgrade && \
    apk add \
      --virtual app \
      $APP_PACKAGES && \
    apk add \
      --virtual build_deps \
      $BUILD_PACKAGES && \
    bundle install --no-cache --system --without development && \
    rm -rf /root/.bundle && \
    apk del build_deps && \
    rm -rf /var/cache/apk/*

COPY pkg/*.gem $APP_DIR/pkg/
RUN gem install -l pkg/*.gem

ENV RUN_DIR /app
RUN mkdir -p $RUN_DIR
WORKDIR $RUN_DIR
VOLUME $RUN_DIR

ENTRYPOINT ["atmos"]
