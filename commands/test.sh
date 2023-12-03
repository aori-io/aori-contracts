#!/bin/bash

test() {
	NETWORK=$1

    forge test -f $NETWORK --via-ir --match-path test/AoriProtocol.t.sol
}

test $1