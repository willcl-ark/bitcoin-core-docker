# Build stage for Bitcoin Core
FROM alpine:3.20 AS build

RUN apk --no-cache add \
    boost-dev \
    build-base \
    chrpath \
    cmake \
    file \
    gnupg \
    git \
    libevent-dev \
    libressl \
    libtool \
    linux-headers \
    sqlite-dev \
    zeromq-dev

ENV BITCOIN_PREFIX=/opt/bitcoin
WORKDIR /src
RUN git clone -b "master" --single-branch --depth 1 "https://github.com/bitcoin/bitcoin.git"
WORKDIR /src/bitcoin

RUN cmake -B build -DBUILD_TESTS=OFF -DBUILD_UTIL=OFF -DBUILD_TX=ON -DCMAKE_BUILD_TYPE=MinSizeRel -DWITH_CCACHE=OFF -DCMAKE_INSTALL_PREFIX:PATH="${BITCOIN_PREFIX}" && \
    cmake --build build -j$(nproc) && \
    strip build/src/bitcoin-cli build/src/bitcoin-tx build/src/bitcoind && \
    cmake --install build

# Copy build artefacts
FROM alpine:3.20

ARG UID=100
ARG GID=101

LABEL maintainer.0="Will Clark (@willcl-ark)"

RUN addgroup --gid ${GID} --system bitcoin && \
    adduser --uid ${UID} --system bitcoin --ingroup bitcoin
RUN apk --no-cache add \
    bash \
    libevent \
    libzmq \
    shadow \
    sqlite-libs \
    su-exec

ENV BITCOIN_DATA=/home/bitcoin/.bitcoin
ENV PATH=/opt/bin:$PATH

COPY --from=build /opt/bitcoin /opt
COPY docker-entrypoint.sh /entrypoint.sh

VOLUME ["/home/bitcoin/.bitcoin"]

EXPOSE 8332 8333 18332 18333 18443 18444 38333 38332

ENTRYPOINT ["/entrypoint.sh"]

CMD ["bitcoind"]
