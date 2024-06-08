# Build stage for Bitcoin Core
FROM alpine as bitcoin-core

RUN apk --no-cache add autoconf
RUN apk --no-cache add automake
RUN apk --no-cache add boost-dev
RUN apk --no-cache add build-base
RUN apk --no-cache add chrpath
RUN apk --no-cache add file
RUN apk --no-cache add gnupg
RUN apk --no-cache add git
RUN apk --no-cache add libevent-dev
RUN apk --no-cache add libressl
RUN apk --no-cache add libtool
RUN apk --no-cache add linux-headers
RUN apk --no-cache add sqlite-dev
RUN apk --no-cache add zeromq-dev

WORKDIR /src
RUN git clone -b "master" --single-branch --depth 1 "https://github.com/bitcoin/bitcoin.git"
WORKDIR /src/bitcoin

RUN ./autogen.sh
RUN ./configure \
  --prefix=/opt/bitcoin \
  --mandir=/usr/share/man \
  --disable-tests \
  --disable-bench \
  --disable-fuzz-binary \
  --disable-ccache \
  --with-gui=no \
  --with-utils \
  --without-libs \
  --with-sqlite=yes \
  --with-daemon
RUN make -j`nproc` -C src bitcoind bitcoin-cli bitcoin-tx
RUN strip src/bitcoin-cli
RUN strip src/bitcoin-tx
RUN strip src/bitcoind
RUN make install

# Build stage for compiled artifacts
FROM alpine

ARG UID=100
ARG GID=101

LABEL maintainer.0="Will Clark (@willcl-ark)"

RUN addgroup bitcoin --gid ${GID} --system
RUN adduser --uid ${UID} --system bitcoin --ingroup bitcoin
RUN apk --no-cache add \
  bash \
  libevent \
  libzmq \
  shadow \
  sqlite-dev \
  su-exec

ENV BITCOIN_DATA=/home/bitcoin/.bitcoin
ENV PATH=/opt/bin:$PATH

COPY --from=bitcoin-core /opt/bitcoin /opt
COPY docker-entrypoint.sh /entrypoint.sh

VOLUME ["/home/bitcoin/.bitcoin"]

EXPOSE 8332 8333 18332 18333 18443 18444 38333 38332

ENTRYPOINT ["/entrypoint.sh"]

CMD ["bitcoind"]
