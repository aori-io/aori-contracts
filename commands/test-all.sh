# Mainnets
./commands/test.sh mainnet && echo "Finished testing mainnet" &
./commands/test.sh polygon && echo "Finished testing polygon" &

# Testnets
./commands/test.sh goerli && echo "Finished testing goerli" &
./commands/test.sh sepolia && echo "Finished testing sepolia" &

wait
echo "Finished testing all networks"