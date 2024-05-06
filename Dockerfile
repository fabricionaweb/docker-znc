# syntax=docker/dockerfile:1-labs
FROM public.ecr.aws/docker/library/alpine:3.19 AS base
ENV TZ=UTC
WORKDIR /src

# source backend stage =========================================================
FROM base AS source

# get and extract source from git
ARG VERSION
ADD https://github.com/znc/znc.git#${BRANCH:-znc-$VERSION} ./

# build stage ==================================================================
FROM base AS build-app

# build dependencies
RUN apk add --no-cache build-base cmake swig python3-dev perl-dev argon2-dev \
    openssl-dev cyrus-sasl-dev c-ares-dev gettext-dev icu-dev

# copy source
COPY --from=source /src ./

# build
ENV DESTDIR=/build
RUN ./configure --prefix=/usr --enable-argon --enable-python && \
    make && make install && \
    strip /build/usr/bin/znc

# runtime stage ================================================================
FROM base

ENV S6_VERBOSITY=0 S6_BEHAVIOUR_IF_STAGE2_FAILS=2 PUID=65534 PGID=65534
WORKDIR /config
VOLUME /config

# copy files
COPY --from=build-app /build/usr/share/znc /usr/share/znc
COPY --from=build-app /build/usr/lib/znc /usr/lib/znc
COPY --from=build-app /build/usr/bin/znc /app/
COPY ./rootfs/. /

# runtime dependencies
RUN apk add --no-cache argon2-libs icu-libs python3 tzdata s6-overlay curl

# run using s6-overlay
ENTRYPOINT ["/entrypoint.sh"]
