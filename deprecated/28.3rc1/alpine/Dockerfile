# Build stage for Bitcoin Core
FROM alpine as bitcoin-core

RUN apk --no-cache add \
  autoconf \
  automake \
  boost-dev \
  build-base \
  chrpath \
  file \
  gnupg \
  git \
  libevent-dev \
  libtool \
  linux-headers \
  sqlite-dev \
  zeromq-dev

ENV BITCOIN_VERSION=28.3rc1
ENV BITCOIN_PREFIX=/opt/bitcoin-${BITCOIN_VERSION}
ENV BITCOIN_SOURCE_DIR=/bitcoin/src
ENV SIGS_REPO_URL="https://github.com/bitcoin-core/guix.sigs.git"
ENV SIGS_CLONE_DIR="guix.sigs"
ENV VERIFY_SCRIPT_URL="https://raw.githubusercontent.com/bitcoin/bitcoin/v${BITCOIN_VERSION}/contrib/verify-binaries/verify.py"

WORKDIR /bitcoin
COPY verify-${BITCOIN_VERSION}.py .

RUN set -ex \
  && if echo $BITCOIN_VERSION | grep -q "rc" ; then \
       VERIFY_VERSION=$(echo $BITCOIN_VERSION | sed 's/\(.*\)rc\([0-9]*\)/\1-rc\2/'); \
       ADDRESS="https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION%%rc*}/test.rc${BITCOIN_VERSION##*rc}"; \
     else \
       VERIFY_VERSION=$BITCOIN_VERSION; \
       ADDRESS="https://bitcoincore.org/bin/bitcoin-core-${VERIFY_VERSION}"; \
     fi \
  && echo "$VERIFY_VERSION" \
  && wget ${ADDRESS}/bitcoin-${BITCOIN_VERSION}.tar.gz \
  && wget ${ADDRESS}/SHA256SUMS \
  && wget ${ADDRESS}/SHA256SUMS.asc \
  && git clone ${SIGS_REPO_URL} ${SIGS_CLONE_DIR} \
  && gpg --import "${SIGS_CLONE_DIR}"/builder-keys/* \
  && ./verify-${BITCOIN_VERSION}.py bin SHA256SUMS \
    "bitcoin-${BITCOIN_VERSION}.tar.gz" \
  && mkdir -p ${BITCOIN_SOURCE_DIR} \
  && tar -xzf "bitcoin-${BITCOIN_VERSION}.tar.gz" -C ${BITCOIN_SOURCE_DIR} \
  && rm -rf ${SIGS_CLONE_DIR}

WORKDIR "${BITCOIN_SOURCE_DIR}/bitcoin-${BITCOIN_VERSION}"

RUN ./autogen.sh
RUN ./configure \
  --prefix=${BITCOIN_PREFIX} \
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
RUN make -j`nproc` install
RUN strip ${BITCOIN_PREFIX}/bin/bitcoin-cli
RUN strip ${BITCOIN_PREFIX}/bin/bitcoin-tx
RUN strip ${BITCOIN_PREFIX}/bin/bitcoind

# Build stage for compiled artifacts
FROM alpine

ARG UID=100
ARG GID=101

LABEL maintainer.0="Will Clark (@willcl-ark)"

RUN addgroup bitcoin --gid ${GID} --system
RUN adduser --uid ${UID} --system bitcoin --ingroup bitcoin
RUN apk --no-cache add \
  libevent \
  libzmq \
  shadow \
  sqlite-libs \
  su-exec

ENV BITCOIN_DATA=/home/bitcoin/.bitcoin
ENV BITCOIN_VERSION=28.3rc1
ENV BITCOIN_PREFIX=/opt/bitcoin-${BITCOIN_VERSION}
ENV PATH=${BITCOIN_PREFIX}/bin:$PATH

COPY --from=bitcoin-core /opt /opt
COPY docker-entrypoint.sh /entrypoint.sh

RUN if echo "$BITCOIN_VERSION" | grep -q "rc"; then \
    PADDED_VERSION=$(echo $BITCOIN_VERSION | sed 's/\([0-9]\+\)\.\([0-9]\+\)rc/\1.\2.0rc/'); \
  else \
    PADDED_VERSION=$BITCOIN_VERSION; \
  fi

VOLUME ["/home/bitcoin/.bitcoin"]

EXPOSE 8332 8333 18332 18333 18444

ENTRYPOINT ["/entrypoint.sh"]

RUN bitcoind -version | grep "Bitcoin Core version v${PADDED_VERSION}"

CMD ["bitcoind"]
