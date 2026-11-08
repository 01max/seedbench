# syntax=docker/dockerfile:1
FROM ruby:4.0.9-slim-trixie@sha256:d8cb2c0714bdaba0f318af897a01d2dbde3cfa8e62d47e99cea55feb13c0e90d AS base

WORKDIR /app
ENV BUNDLE_DEPLOYMENT=1 BUNDLE_PATH=/usr/local/bundle \
    RAILS_ENV=production BOOTSNAP_CACHE_DIR=/tmp/bootsnap \
    CALIBRE_CONFIG_DIRECTORY=/tmp/calibre QT_QPA_PLATFORM=offscreen \
    SEEDBENCH_STATE_ROOT=/state SEEDBENCH_SCRATCH_ROOT=/scratch \
    SEEDBENCH_PAYLOAD_ROOT=/payloads PIDFILE=/tmp/server.pid HOME=/tmp/rails-home

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates libyaml-0-2 libsqlite3-0 calibre fonts-dejavu-core \
       mktorrent poppler-utils tesseract-ocr tesseract-ocr-fra \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 1000 rails \
    && useradd --uid 1000 --gid 1000 --create-home rails \
    && mkdir -p /state /scratch /payloads \
    && chown rails:rails /state /scratch /payloads

FROM base AS gems
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential git pkg-config libyaml-dev libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*
COPY Gemfile Gemfile.lock ./
RUN bundle config set without development:test \
    && bundle install \
    && rm -rf /usr/local/bundle/cache
FROM gems AS build
COPY . .
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

FROM base AS application
ENV BUNDLE_WITHOUT=development:test
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build --chown=rails:rails /app /app
RUN rm -rf /app/tmp /app/log \
    && ln -s /tmp/rails-tmp /app/tmp \
    && ln -s /tmp/rails-log /app/log
USER rails:rails
EXPOSE 3000
ENTRYPOINT ["/app/bin/container-entrypoint"]
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]

FROM gems AS quality-gems
ENV BUNDLE_WITHOUT="" RAILS_ENV=test
RUN bundle config unset without \
    && bundle install \
    && rm -rf /usr/local/bundle/cache

FROM quality-gems AS quality
COPY --chown=rails:rails . .
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile \
    && rm -rf /app/tmp /app/log \
    && ln -s /tmp/rails-tmp /app/tmp \
    && ln -s /tmp/rails-log /app/log
USER rails:rails
ENTRYPOINT ["/app/bin/container-entrypoint"]
CMD ["bundle", "exec", "rspec"]
