
# Mainnets
./commands/e2e.sh mainnet $1 $2 && echo "Finished testing mainnet" &
./commands/e2e.sh polygon $1 $2 && echo "Finished testing polygon" &

# Testnets
./commands/e2e.sh goerli $1 $2 && echo "Finished testing goerli" &
./commands/e2e.sh sepolia $1 $2 && echo "Finished testing sepolia" &

wait
echo "Finished testing all networks"