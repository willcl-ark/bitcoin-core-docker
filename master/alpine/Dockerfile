# Build stage for Bitcoin Core
FROM alpine:3.21 AS build

RUN apk --no-cache add \
    boost-dev \
    build-base \
    capnproto \
    capnproto-dev \
    ccache \
    chrpath \
    clang18 \
    cmake \
    file \
    gnupg \
    git \
    libevent-dev \
    linux-headers \
    sqlite-dev \
    zeromq-dev

ENV BITCOIN_PREFIX=/opt/bitcoin
ARG COMMIT=master

WORKDIR /src
RUN git clone -b "$COMMIT" --single-branch --depth 1 "https://github.com/bitcoin/bitcoin.git" && \
    cd bitcoin && \
    git fetch origin "$COMMIT" && \
    git checkout "$COMMIT" && \
    git clean -fdx

WORKDIR /src/bitcoin

RUN cmake -B build \
    -DBUILD_TESTS=OFF \
    -DBUILD_TX=ON \
    -DBUILD_UTIL=OFF \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_CXX_COMPILER=clang++-18 \
    -DCMAKE_C_COMPILER=clang-18 \
    -DCMAKE_INSTALL_PREFIX:PATH="${BITCOIN_PREFIX}" \
    -DWITH_CCACHE=ON && \
    cmake --build build -j$(nproc) && \
    strip build/bin/bitcoin-cli build/bin/bitcoin-tx build/bin/bitcoind && \
    cmake --install build

# Copy build artefacts
FROM alpine:3.21

ARG UID=100
ARG GID=101

LABEL maintainer.0="Will Clark (@willcl-ark)"

RUN addgroup --gid ${GID} --system bitcoin && \
    adduser --uid ${UID} --system bitcoin --ingroup bitcoin
RUN apk --no-cache add \
    bash \
    capnproto \
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
