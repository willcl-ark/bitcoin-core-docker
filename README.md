# bitcoin/bitcoin

[![bitcoin/bitcoin][docker-pulls-image]][docker-hub-url] [![bitcoin/bitcoin][docker-stars-image]][docker-hub-url] [![bitcoin/bitcoin][docker-size-image]][docker-hub-url]

## About the images

These images are built with support for the following platforms:

| Image                               | Platforms                              |
|-------------------------------------|----------------------------------------|
| &lt;tag&gt;:&lt;version&gt;         | linux/amd64, linux/arm64, linux/arm/v7 |
| &lt;tag&gt;:&lt;version&gt;-alpine; | linux/amd64                            |

The Debian-based (non-alpine) images use pre-built binaries pulled from bitcoincore.org or bitcoin.org (or both) as availability dictates. These binaries are built using the Bitcoin Core [reproducible build](https://github.com/bitcoin/bitcoin/blob/master/contrib/guix/README.md) system, and signatures attesting to them can be found in the [guix.sigs](https://github.com/bitcoin-core/guix.sigs) repo. Signatures are checked in the build process for these docker images using the [verify_binaries.py](https://github.com/bitcoin/bitcoin/tree/master/contrib/verify-binaries) script from the bitcoin/bitcoin git repository.

The alpine images are built from source inside the CI.

## Tags

- `27.0`, `27`, `latest` ([27/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/27/Dockerfile)) [**multi-platform**]
- `27.0-alpine`, `27-alpine` ([27/alpine/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/27/alpine/Dockerfile))

- `26.1`, `26`, `latest` ([26/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/26/Dockerfile)) [**multi-platform**]
- `26.1-alpine`, `26-alpine` ([26/alpine/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/26/alpine/Dockerfile))

- `25.2`, `25`, `latest` ([25/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/25/Dockerfile)) [**multi-platform**]
- `25.2-alpine`, `25-alpine` ([25/alpine/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/25/alpine/Dockerfile))

### Picking the right tag

- `bitcoin/bitcoin:latest`: this tag points to the latest stable release available of Bitcoin Core. Caution when using in production as blindly upgrading Bitcoin Core is a risky procedure.
- `bitcoin/bitcoin:alpine`: this tag points to the same version as above (i.e. "latest") but using the Alpine Linux distribution (a resource efficient Linux distribution with security in mind, but not officially supported by the Bitcoin Core team — use at your own risk).
- `bitcoin/bitcoin:<version>`: this tag format points to a specific release of Bitcoin Core (e.g. `27.0`).
- `bitcoin/bitcoin:<version>-alpine`: same as above but using binaries compiled from source using the Alpine Linux distribution.

## Usage

### How to use these images

This image contains the main binaries from the Bitcoin Core project - `bitcoind`, `bitcoin-cli` and `bitcoin-tx`. It behaves like a binary, so you can pass any arguments to the image and they will be forwarded to the `bitcoind` binary:

```sh
❯ docker run --rm -it bitcoin/bitcoin \
  -printtoconsole \
  -regtest=1 \
  -rpcallowip=172.17.0.0/16 \
  -rpcauth='foo:7d9ba5ae63c3d4dc30583ff4fe65a67e$9e3634e81c11659e3de036d0bf88f89cd169c1039e6e09607562d54765c649cc'
```

_Note: [learn more](#using-rpcauth-for-remote-authentication) about how `-rpcauth` works for remote authentication._

By default, `bitcoind` will run as user `bitcoin` in the group `bitcoin` for security reasons and with its default data directory set to `~/.bitcoin`. If you'd like to customize where `bitcoin` stores its data, you must use the `BITCOIN_DATA` environment variable. The directory will be automatically created with the correct permissions for the `bitcoin` user and `bitcoind` automatically configured to use it.

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
  image: bitcoin/bitcoin
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

Then, inside the running `bitcoin-server` container, locally execute the query to the daemon using `bitcoin-cli`:

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

In the background, `bitcoin-cli` read the information automatically from `/home/bitcoin/.bitcoin/regtest/.cookie`. In production, the path would not contain the regtest part.

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

1. Some shells require escaping the rpcauth line (e.g. zsh), as shown above.
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

- Testnet JSON-RPC: 18332
- P2P: 18333

#### Regtest

- JSON-RPC/REST: 18443 (_since 0.16+_, otherwise _18332_)
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
