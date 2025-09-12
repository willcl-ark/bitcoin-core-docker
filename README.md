# bitcoin/bitcoin

[![bitcoin/bitcoin][docker-pulls-image]][docker-hub-url] [![bitcoin/bitcoin][docker-stars-image]][docker-hub-url] [![bitcoin/bitcoin][docker-size-image]][docker-hub-url]

## About the images

> [!IMPORTANT]
> These are **unofficial** Bitcoin Core images, not endorsed or associated with the Bitcoin Core project on Github: github.com/bitcoin/bitcoin

- The images are aimed at testing environments (e.g. for downstream or bitcoin-adjacent projects). For production use, you should build from source or verify binaries yourself (see [bitcoincore.org/en/download/](https://bitcoincore.org/en/download/)).

- The images are built using Nix flakes in this repo: https://github.com/willcl-ark/bitcoin-core-docker

- **Binary Verification**: Instead of GPG signature verification of the binary tarballs from bitcoincore.org, this project uses Nix's content-addressable storage with cryptographic hashes locked in the flake configuration. Each binary download is verified against pre-computed SHA-256 hashes (from the SHASUMS file), providing equivalent security, so long as the binary hashes here are known-good.

- Multi-architecture support for all major platforms:
  | Architecture | Docker Platform | Nix System |
  |-------------|----------------|------------|
  | AMD64 | linux/amd64 | x86_64-linux |
  | ARM64 | linux/arm64 | aarch64-linux |
  | ARMv7 | linux/arm/v7 | armv7l-linux |
  | PowerPC64 | linux/ppc64le | powerpc64-linux |
  | RISC-V 64 | linux/riscv64 | riscv64-linux |

- All non-master images use official Bitcoin Core binaries from bitcoincore.org, built with the [reproducible Guix build system](https://github.com/bitcoin/bitcoin/blob/master/contrib/guix/README.md).

- Each Bitcoin Core version is managed as a separate Nix flake with locked dependencies, ensuring ~ reproducible builds and allowing different versions to use appropriate toolchain versions.

## Build System

This project uses [Nix flakes](https://nixos.wiki/wiki/Flakes) for reproducible, multi-architecture Docker image builds:

### Binary Verification Approach

**Previous approach** (Docker-based CI): Used GPG signature verification with `verify_binaries.py` script during Docker build.

**Current approach** (Nix flakes): Uses the SHA256SUMS files directly from bitcoincore.org. Each version directory contains a copy of the SHA256SUMS file which is parsed automatically:

```nix
# Each version references its SHA256SUMS file, hosted also on bitcoincore.org
versions = {
  "29.1" = shasumsLib.shasumsToVersionConfig {
    version = "29.1";
    urlPath = "bitcoin-core-29.1/";
    tags = ["29.1" "29" "latest"];
    shasumsPath = ./SHA256SUMS;
  };
};
```

This approach provides:

- **Equivalent security**: SHA-256 hashes provide the same tamper detection as GPG signatures
- **Simpler verification**: No need to manage GPG keyrings or signature files
- **Immutable builds**: Hash mismatches cause immediate build failures

### Multi-Architecture Support

The flake builds images for all supported architectures in parallel and creates Docker manifests for seamless multi-platform deployment. Use the included justfile for easy building:

```bash
# Build specific architecture
just build 29.1 amd64

# Build all architectures
just build-all 29.1

# Push with multi-arch manifest
just push 29.1 docker.io/youruser
```

## Tags

- `29.1`, `29`, `latest` ([29.1/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/29.1/Dockerfile)) [**multi-platform**]
- `29.1-alpine`, `29-alpine` ([29.1/alpine/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/29.1/alpine/Dockerfile))
- `28.2`, `28` ([28.2/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/28.2/Dockerfile)) \[**multi-platform**\]
- `28.2-alpine`, `28-alpine`, `alpine` ([28.2/alpine/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/28.2/alpine/Dockerfile))
- `27.2`, `27` ([27.2/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/27.2/Dockerfile)) \[**multi-platform**\]
- `27.2-alpine`, `27-alpine` ([27.2/alpine/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/27.2/alpine/Dockerfile))

## Release Candidates

- `30.0rc1` ([30.0rc1/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/30.0rc1/Dockerfile)) \[**multi-platform**\]
- `29.1rc2` ([29.1rc2/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/29.1rc2/Dockerfile)) \[**multi-platform**\]

### Picking the right tag

#### Latest released version

This tag refers to the latest major version, and the latest minor and patch of this version where applicable.

- `bitcoin/bitcoin:latest`: Release binaries directly from bitcoincore.org. Caution when specifying this tag in production as blindly upgrading Bitcoin Core major versions can introduce new behaviours.

#### Specific released version

These tags refer to a specific version of Bitcoin Core.

- `bitcoin/bitcoin:<version>`: Release binaries of a specific release directly from bitcoincore.org (e.g. `27.1` or `26`).

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

By default, `bitcoind` runs with `/data` as its working directory and data directory. The container runs as root and does not create a dedicated `bitcoin` user. To persist blockchain data, mount a volume to `/data`:

```sh
❯ docker run -v ${PWD}/data:/data -it --rm bitcoin/bitcoin \
  -printtoconsole \
  -regtest=1
```

You can also customize the data directory by overriding the default `-datadir=/data` argument:

```sh
❯ docker run -v ${PWD}/bitcoin-data:/var/lib/bitcoin --rm -it bitcoin/bitcoin \
  -printtoconsole \
  -regtest=1 \
  -datadir=/var/lib/bitcoin
```

You can optionally create a service using `docker-compose`:

```yml
bitcoin-core:
  image: bitcoin/bitcoin:latest
  command:
    -printtoconsole
    -regtest=1
```

### File Permissions

The container runs as root by default. If you need to manage file permissions for the data directory, you can:

1. Set permissions on the host directory before mounting:
```sh
❯ mkdir -p ./data
❯ chmod 755 ./data
❯ docker run -v ${PWD}/data:/data -it --rm bitcoin/bitcoin -printtoconsole -regtest=1
```

2. Or use Docker's `--user` flag to run as a specific user:
```sh
❯ docker run --user 1000:1000 -v ${PWD}/data:/data -it --rm bitcoin/bitcoin \
  -printtoconsole \
  -regtest=1
```

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
❯ docker exec bitcoin-server bitcoin-cli -regtest getmininginfo

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

`bitcoin-cli` reads the authentication credentials automatically from the [data directory](https://github.com/bitcoin/bitcoin/blob/master/doc/files.md#data-directory-layout), which in these images defaults to `/data/.cookie`.

#### Using rpcauth for remote authentication

Before setting up remote authentication, you will need to generate the `rpcauth` line that will hold the credentials for the Bitcoind Core daemon. You can either do this yourself by constructing the line with the format `<user>:<salt>$<hash>` or use the official [`rpcauth.py`](https://github.com/bitcoin/bitcoin/blob/master/share/rpcauth/rpcauth.py) script to generate this line for you, including a random password that is printed to the console.

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
1. It is now perfectly fine to pass the rpcauth line as a command line argument. Unlike `-rpcpassword`, the content is hashed so even if the arguments would be exposed, they would not allow the attacker to get the actual password.

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
