# bitcoin/bitcoin

[![bitcoin/bitcoin][docker-pulls-image]][docker-hub-url] [![bitcoin/bitcoin][docker-stars-image]][docker-hub-url] [![bitcoin/bitcoin][docker-size-image]][docker-hub-url]

## About the images

> [!IMPORTANT]
> These are **unofficial** Bitcoin Core images, not endorsed or associated with the Bitcoin Core project on Github: github.com/bitcoin/bitcoin

- The images are aimed at testing environments (e.g. for downstream or bitcoin-adjacent projects), as it is non-trivial to verify the authenticity of the bitcoin core binaries inside.
  - When using Bitcoin Core software for non-testing purposes you should always ensure that you have either: i) built it from source yourself, or ii) verfied your binary download (see [this page](https://bitcoincore.org/en/download/) for more information on how to do this).
- The images are built using CI workflows found in this repo: https://github.com/willcl-ark/bitcoin-core-docker
- The images are built with support for the following platforms:
  | Image                              | Platforms                              |
  |------------------------------------|----------------------------------------|
  | `bitcoin/bitcoin:latest`           | linux/amd64, linux/arm64, linux/arm/v7 |
  | `bitcoin/bitcoin:alpine`           | linux/amd64                            |
  | `bitcoin/bitcoin:<version>`        | linux/amd64, linux/arm64, linux/arm/v7 |
  | `bitcoin/bitcoin:<version>-alpine` | linux/amd64                            |
  | `bitcoin/bitcoin:master`           | linux/amd64, linux/arm64               |
  | `bitcoin/bitcoin:master-alpine`    | linux/amd64, linux/arm64               |

- The Debian-based (non-alpine) images use pre-built binaries pulled from bitcoincore.org or bitcoin.org (or both) as availability dictates. These binaries are built using the Bitcoin Core [reproducible build](https://github.com/bitcoin/bitcoin/blob/master/contrib/guix/README.md) system, and signatures attesting to them can be found in the [guix.sigs](https://github.com/bitcoin-core/guix.sigs) repo. Signatures are checked in the build process for these docker images using the [verify_binaries.py](https://github.com/bitcoin/bitcoin/tree/master/contrib/verify-binaries) script from the bitcoin/bitcoin git repository.
- The alpine images are built from source inside the CI.
- The nightly master image is source-built, and targeted at the linux/amd64 and linux/arm64 platforms.

## Tags

- `29.1`, `29`, `latest` ([29.1/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/29.1/Dockerfile)) [**multi-platform**]
- `29.1-alpine`, `29-alpine` ([29.1/alpine/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/29.1/alpine/Dockerfile))

- `28.2`, `28` ([28.2/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/28.2/Dockerfile)) [**multi-platform**]
- `28.2-alpine`, `28-alpine`, `alpine` ([28.2/alpine/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/28.2/alpine/Dockerfile))

- `27.2`, `27` ([27.2/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/27.2/Dockerfile)) [**multi-platform**]
- `27.2-alpine`, `27-alpine` ([27.2/alpine/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/27.2/alpine/Dockerfile))

## Release Candidates

- `30.0rc3` ([30.0rc3/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/30.0rc3/Dockerfile)) [**multi-platform**]
- `30.0rc3-alpine` ([30.0rc3/alpine/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/30.0rc3/alpine/Dockerfile))

- `29.2rc1` ([29.2rc1/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/29.2rc1/Dockerfile)) [**multi-platform**]
- `29.2rc1-alpine` ([29.2rc1/alpine/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/29.2rc1/alpine/Dockerfile))

- `28.3rc1` ([28.3rc1/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/28.3rc1/Dockerfile)) [**multi-platform**]
- `28.3rc1-alpine` ([28.3rc1/alpine/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/28.3rc1/alpine/Dockerfile))

### Picking the right tag

> [!IMPORTANT]
> The Alpine Linux distribution, whilst being a resource efficient Linux distribution with security in mind, is not officially supported by the Bitcoin Core team — use at your own risk.

#### Latest released version

These tags refer to the latest major version, and the latest minor and patch of this version where applicable.

- `bitcoin/bitcoin:latest`: Release binaries directly from bitcoincore.org. Caution when specifying this tag in production as blindly upgrading Bitcoin Core major versions can introduce new behaviours.
- `bitcoin/bitcoin:alpine`: Source-built binaries using the Alpine Linux distribution.

#### Specific released version

These tags refer to a specific version of Bitcoin Core.

- `bitcoin/bitcoin:<version>`: Release binaries of a specific release directly from bitcoincore.org (e.g. `27.1` or `26`).
- `bitcoin/bitcoin:<version>-alpine`: Source-built binaries of a specific release of Bitcoin Core (e.g. `27.1` or `26`) using the Alpine Linux distribution.

#### Nightly master build

This tag refers to a nightly build of https://github.com/bitcoin/bitcoin master branch using Alpine Linux.

- `bitcoin/bitcoin:master`: Source-built binaries on Debian Linux, compiled nightly using master branch pulled from https://github.com/bitcoin/bitcoin.
- `bitcoin/bitcoin:master-alpine`: Source-built binaries on Alpine Linux, compiled nightly using master branch pulled from https://github.com/bitcoin/bitcoin.

## Usage

### How to use these images

These images contain the main binaries from the Bitcoin Core project - `bitcoind`, `bitcoin-cli` and `bitcoin-tx`. The images behave like binaries, so you can pass arguments to the image and they will be forwarded to the `bitcoind` binary (by default, other binaries on demand):

```sh
❯ docker run --rm -it bitcoin/bitcoin \
  -printtoconsole \
  -regtest=1 \
  -rpcallowip=172.17.0.0/16 \
  -rpcauth='foo:7d9ba5ae63c3d4dc30583ff4fe65a67e$9e3634e81c11659e3de036d0bf88f89cd169c1039e6e09607562d54765c649cc'
```

_Note: [learn more](#using-rpcauth-for-remote-authentication) about how `-rpcauth` works for remote authentication._

By default, `bitcoind` will run as user `bitcoin` in the group `bitcoin` for security reasons and its default data directory is set to `/home/bitcoin/.bitcoin`. If you'd like to customize where `bitcoin` stores its data, you must use the `BITCOIN_DATA` environment variable. The directory will be automatically created with the correct permissions for the `bitcoin` user and `bitcoind` automatically configured to use it.

```sh
❯ docker run --env BITCOIN_DATA=/var/lib/bitcoin-core --rm -it bitcoin/bitcoin \
  -printtoconsole \
  -regtest=1
```

You can also mount a directory in a volume under `/home/bitcoin/.bitcoin` in case you want to access it on the host:

```sh
❯ docker run -v ${PWD}/data:/home/bitcoin/.bitcoin -it --rm bitcoin/bitcoin \
  -printtoconsole \
  -regtest=1
```

You can optionally create a service using `docker-compose`:

```yml
bitcoin-core:
  image: bitcoin/bitcoin:latest
  command:
    -printtoconsole
    -regtest=1
```

### Using a custom user id (UID) and group id (GID)

By default, images are created with a `bitcoin` user/group using a static UID/GID (`101:101` on Debian and `100:101` on Alpine). You may customize the user and group ids using the build arguments `UID` (`--build-arg UID=<uid>`) and `GID` (`--build-arg GID=<gid>`).

If you'd like to use the pre-built images, you can also customize the UID/GID on runtime via environment variables `$UID` and `$GID`:

```sh
❯ docker run -e UID=10000 -e GID=10000 -it --rm bitcoin/bitcoin \
  -printtoconsole \
  -regtest=1
```

This will recursively change the ownership of the `bitcoin` home directory and `$BITCOIN_DATA` to UID/GID `10000:10000`.

### Using RPC to interact with the daemon

There are two communications methods to interact with a running Bitcoin Core daemon.

The first one is using a cookie-based local authentication. It doesn't require any special authentication information as running a process locally under the same user that was used to launch the Bitcoin Core daemon allows it to read the cookie file previously generated by the daemon for clients. The downside of this method is that it requires local machine access.

The second option is making a remote procedure call using a username and password combination. This has the advantage of not requiring local machine access, but in order to keep your credentials safe you should use the newer `rpcauth` authentication mechanism.

#### Using cookie-based local authentication

Start by launch the Bitcoin Core daemon:

```sh
❯ docker run --rm --name bitcoin-server -it bitcoin/bitcoin \
  -printtoconsole \
  -regtest=1
```

Then, inside the running same `bitcoin-server` container, locally execute the query to the daemon using `bitcoin-cli`:

```sh
❯ docker exec --user bitcoin bitcoin-server bitcoin-cli -regtest getmininginfo

{
  "blocks": 0,
  "currentblocksize": 0,
  "currentblockweight": 0,
  "currentblocktx": 0,
  "difficulty": 4.656542373906925e-10,
  "errors": "",
  "networkhashps": 0,
  "pooledtx": 0,
  "chain": "regtest"
}
```

`bitcoin-cli` reads the authentication credentials automatically from the [data directory](https://github.com/bitcoin/bitcoin/blob/master/doc/files.md#data-directory-layout), on mainnet this means from `/home/bitcoin/.bitcoin/.cookie`.

#### Using rpcauth for remote authentication

Before setting up remote authentication, you will need to generate the `rpcauth` line that will hold the credentials for the Bitcoind Core daemon. You can either do this yourself by constructing the line with the format `<user>:<salt>$<hash>` or use the official [`rpcauth.py`](https://github.com/bitcoin/bitcoin/blob/master/share/rpcauth/rpcauth.py)  script to generate this line for you, including a random password that is printed to the console.

_Note: This is a Python 3 script. use `[...] | python3 - <username>` when executing on macOS._

Example:

```sh
❯ curl -sSL https://raw.githubusercontent.com/bitcoin/bitcoin/master/share/rpcauth/rpcauth.py | python - <username>

String to be appended to bitcoin.conf:
rpcauth=foo:7d9ba5ae63c3d4dc30583ff4fe65a67e$9e3634e81c11659e3de036d0bf88f89cd169c1039e6e09607562d54765c649cc
Your password:
qDDZdeQ5vw9XXFeVnXT4PZ--tGN2xNjjR4nrtyszZx0=
```

Note that for each run, even if the username remains the same, the output will be always different as a new salt and password are generated.

Now that you have your credentials, you need to start the Bitcoin Core daemon with the `-rpcauth` option. Alternatively, you could append the line to a `bitcoin.conf` file and mount it on the container.

Let's opt for the Docker way:

```sh
❯ docker run --rm --name bitcoin-server -it bitcoin/bitcoin \
  -printtoconsole \
  -regtest=1 \
  -rpcallowip=172.17.0.0/16 \
  -rpcauth='foo:7d9ba5ae63c3d4dc30583ff4fe65a67e$9e3634e81c11659e3de036d0bf88f89cd169c1039e6e09607562d54765c649cc'
```

Two important notes:

1. Some shells require escaping the rpcauth line (e.g. zsh).
2. It is now perfectly fine to pass the rpcauth line as a command line argument. Unlike `-rpcpassword`, the content is hashed so even if the arguments would be exposed, they would not allow the attacker to get the actual password.

To avoid any confusion about whether or not a remote call is being made, let's spin up another container to execute `bitcoin-cli` and connect it via the Docker network using the password generated above:

```sh
❯ docker run -it --link bitcoin-server --rm bitcoin/bitcoin \
  bitcoin-cli \
  -rpcconnect=bitcoin-server \
  -regtest \
  -rpcuser=foo\
  -stdinrpcpass \
  getbalance
```

Enter the password `qDDZdeQ5vw9XXFeVnXT4PZ--tGN2xNjjR4nrtyszZx0=` and hit enter:

```
0.00000000
```

### Exposing Ports

Depending on the network (mode) the Bitcoin Core daemon is running as well as the chosen runtime flags, several default ports may be available for mapping.

Ports can be exposed by mapping all of the available ones (using `-P` and based on what `EXPOSE` documents) or individually by adding `-p`. This mode allows assigning a dynamic port on the host (`-p <port>`) or assigning a fixed port `-p <hostPort>:<containerPort>`.

Example for running a node in `regtest` mode mapping JSON-RPC/REST (18443) and P2P (18444) ports:

```sh
docker run --rm -it \
  -p 18443:18443 \
  -p 18444:18444 \
  bitcoin/bitcoin \
  -printtoconsole \
  -regtest=1 \
  -rpcallowip=172.17.0.0/16 \
  -rpcbind=0.0.0.0 \
  -rpcauth='foo:7d9ba5ae63c3d4dc30583ff4fe65a67e$9e3634e81c11659e3de036d0bf88f89cd169c1039e6e09607562d54765c649cc'
```

To test that mapping worked, you can send a JSON-RPC curl request to the host port:

```
curl --data-binary '{"jsonrpc":"1.0","id":"1","method":"getnetworkinfo","params":[]}' http://foo:qDDZdeQ5vw9XXFeVnXT4PZ--tGN2xNjjR4nrtyszZx0=@127.0.0.1:18443/
```

#### Mainnet

- JSON-RPC/REST: 8332
- P2P: 8333

#### Testnet

- JSON-RPC: 18332
- P2P: 18333

#### Regtest

- JSON-RPC/REST: 18443
- P2P: 18444

#### Signet

- JSON-RPC/REST: 38332
- P2P: 38333

## License

[License information](https://github.com/bitcoin/bitcoin/blob/master/COPYING) for the software contained in this image.

[License information](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/LICENSE) for the [willcl-ark/bitcoin-core-docker][docker-hub-url] docker project.

[docker-hub-url]: https://hub.docker.com/r/bitcoin/bitcoin
[docker-pulls-image]: https://img.shields.io/docker/pulls/bitcoin/bitcoin.svg?style=flat-square
[docker-size-image]: https://img.shields.io/docker/image-size/bitcoin/bitcoin?style=flat-square
[docker-stars-image]: https://img.shields.io/docker/stars/bitcoin/bitcoin.svg?style=flat-square
