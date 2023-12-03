#!/bin/bash

test() {
	NETWORK=$1
    ADDRESS=$2
    SERVER_PRIVATE_KEY=$3

    AORI_PROTOCOL_ADDRESS=$ADDRESS SERVER_PRIVATE_KEY=$SERVER_PRIVATE_KEY forge test -f $NETWORK --via-ir --match-path test/E2E.t.sol
}

test $1 $2 $3