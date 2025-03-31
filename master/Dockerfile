FROM debian:bookworm-slim AS build

LABEL maintainer.0="Will Clark (@willcl-ark)"

RUN apt-get update -y \
  && apt-get install -y \
    build-essential \
    ca-certificates \
    ccache \
    clang-16 \
    cmake \
    git \
    libboost-dev \
    libevent-dev \
    libsqlite3-dev \
    libzmq3-dev \
    pkg-config \
    python3 \
    systemtap-sdt-dev \
    --no-install-recommends \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV BITCOIN_PREFIX=/opt/bitcoin
ARG COMMIT=master

WORKDIR /src

RUN git clone -b "$COMMIT" --single-branch --depth 1 "https://github.com/bitcoin/bitcoin.git" && \
    cd bitcoin && \
    git fetch origin "$COMMIT" && \
    git checkout "$COMMIT" && \
    git clean -fdx && \
    git rev-parse HEAD > /src/bitcoin_commit.hash

WORKDIR /src/bitcoin

RUN set -ex \
  && cmake -B build \
    -DBUILD_TESTS=OFF \
    -DBUILD_TX=ON \
    -DBUILD_UTIL=OFF \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_CXX_COMPILER=clang++-16 \
    -DCMAKE_C_COMPILER=clang-16 \
    -DCMAKE_INSTALL_PREFIX:PATH="${BITCOIN_PREFIX}" \
    -DWITH_CCACHE=ON \
  && cmake --build build -j$(nproc) \
  && strip build/bin/bitcoin-cli build/bin/bitcoin-tx build/bin/bitcoind \
  && cmake --install build

# Second stage
FROM debian:bookworm-slim

ARG UID=101
ARG GID=101

ENV BITCOIN_DATA=/home/bitcoin/.bitcoin

RUN groupadd --gid ${GID} bitcoin \
  && useradd --create-home --no-log-init -u ${UID} -g ${GID} bitcoin \
  && apt-get update -y \
  && apt-get install -y gosu libevent-dev libboost-dev libsqlite3-dev libzmq3-dev systemtap-sdt-dev --no-install-recommends \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=build /opt/bitcoin /opt
COPY --from=build /src/bitcoin_commit.hash /opt/bitcoin_commit.hash
ENV PATH=/opt/bin:$PATH

COPY docker-entrypoint.sh /entrypoint.sh

VOLUME ["/home/bitcoin/.bitcoin"]
EXPOSE 8332 8333 18332 18333 18443 18444 38333 38332

ENTRYPOINT ["/entrypoint.sh"]
RUN bitcoind -version | grep "Bitcoin Core daemon version"
CMD ["bitcoind"]
