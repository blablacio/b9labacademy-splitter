# B9lab Academy Splitter

Splitter is a smart contract that enables the following functionality:
- Splitting the amount sent to the contract between all peers
- Adding and removing peers (only contract owner)
- Claiming balances by peers

## Installation

You need a recent version of [Docker](https://docs.docker.com/install/) and [Docker Compose](https://docs.docker.com/compose/install/)

## Usage

```
docker-compose build
docker-compose up -d
```

You can then check tests output:
```
docker logs -f splitter-tests
```