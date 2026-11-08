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
ARG APP_UID=1000
ARG APP_GID=1000
ARG STATE_ROOT=/state
ARG SCRATCH_ROOT=/scratch
ARG PAYLOAD_ROOT=/payloads
ENV BUNDLE_WITHOUT=development:test \
    SEEDBENCH_STATE_ROOT=${STATE_ROOT} SEEDBENCH_SCRATCH_ROOT=${SCRATCH_ROOT} \
    SEEDBENCH_PAYLOAD_ROOT=${PAYLOAD_ROOT}
RUN groupmod --non-unique --gid "$APP_GID" rails \
    && usermod --non-unique --uid "$APP_UID" --gid rails rails \
    && mkdir -p "$SEEDBENCH_STATE_ROOT" "$SEEDBENCH_SCRATCH_ROOT" "$SEEDBENCH_PAYLOAD_ROOT" \
    && chown rails:rails "$SEEDBENCH_STATE_ROOT" "$SEEDBENCH_SCRATCH_ROOT" "$SEEDBENCH_PAYLOAD_ROOT"
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
RUN apt-get update \
    && apt-get install -y --no-install-recommends chromium chromium-driver python3-pil python3-reportlab \
    && rm -rf /var/lib/apt/lists/* \
    && bundle config unset without \
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
