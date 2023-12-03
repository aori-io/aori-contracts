#!/bin/bash

test() {
	NETWORK=$1

    forge test -f $NETWORK --via-ir
}

test $1