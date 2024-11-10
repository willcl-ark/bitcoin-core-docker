FROM debian:bookworm-slim AS build

LABEL maintainer.0="Will Clark (@willcl-ark)"

RUN apt-get update -y \
  && apt-get install -y build-essential git ca-certificates cmake pkg-config python3 libevent-dev libboost-dev libsqlite3-dev libzmq3-dev systemtap-sdt-dev --no-install-recommends \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV BITCOIN_PREFIX=/opt/bitcoin
WORKDIR /src
RUN git clone -b "master" --single-branch --depth 1 "https://github.com/bitcoin/bitcoin.git"
WORKDIR /src/bitcoin

RUN set -ex \
  && cmake -B build -DBUILD_TESTS=OFF -DBUILD_UTIL=OFF -DBUILD_TX=ON -DCMAKE_BUILD_TYPE=MinSizeRel -DWITH_CCACHE=OFF -DCMAKE_INSTALL_PREFIX:PATH="${BITCOIN_PREFIX}" \
  && cmake --build build -j$(nproc) \
  && strip build/src/bitcoin-cli build/src/bitcoin-tx build/src/bitcoind \
  && cmake --install build

# Second stage
FROM debian:bookworm-slim

ARG UID=101
ARG GID=101

ENV BITCOIN_DATA=/home/bitcoin/.bitcoin

RUN groupadd --gid ${GID} bitcoin \
  && useradd --create-home --no-log-init -u ${UID} -g ${GID} bitcoin \
  && apt-get update -y \
  && apt-get install -y libevent-dev libboost-dev libsqlite3-dev libzmq3-dev systemtap-sdt-dev --no-install-recommends \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=build /opt/bitcoin /opt
ENV PATH=/opt/bin:$PATH

COPY docker-entrypoint.sh /entrypoint.sh

VOLUME ["/home/bitcoin/.bitcoin"]
EXPOSE 8332 8333 18332 18333 18443 18444 38333 38332

ENTRYPOINT ["/entrypoint.sh"]
RUN bitcoind -version | grep "Bitcoin Core daemon version"
CMD ["bitcoind"]
