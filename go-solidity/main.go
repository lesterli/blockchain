package main

import (
	"fmt"
	"log"
	"os"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/joho/godotenv"

	"github.com/lesterli/blockchain/go-solidity/bindings"
)

func main() {
	// load .env file
	err := godotenv.Load()
	if err != nil {
		log.Fatalf("Error loading .env file")
	}

	// Connect to a geth node (when using Infura, you need to use your own API key)
	conn, err := ethclient.Dial(os.Getenv("RPC"))
	if err != nil {
		log.Fatalf("Failed to connect to the Ethereum client: %v", err)
	}

	// Instantiate the contract and display its name
	address := common.HexToAddress("0x271B34781c76fB06bfc54eD9cfE7c817d89f7759")
	token, err := bindings.NewErc20(address, conn)
	if err != nil {
		log.Fatalf("Failed to instantiate a Token contract: %v", err)
	}

	// Access token properties
	name, err := token.Name(nil)
	if err != nil {
		log.Fatalf("Failed to retrieve token name: %v", err)
	}
	fmt.Println("Token name:", name)

	// Init
	l2OutputOracleAddr := common.HexToAddress("0x90E9c4f8a994a250F6aEfd61CAFb4F2e895D458F")
	l2OutputOracle, err := bindings.NewL2OutputOracle(l2OutputOracleAddr, conn)
	if err != nil {
		log.Fatalf("Failed to instantiate a L2OutputOracleProxy contract: %v", err)
	}
	version, err := l2OutputOracle.Version(&bind.CallOpts{})
	if err != nil {
		log.Fatalf("Failed to retrieve version: %v", err)
	}
	fmt.Println("Connected to L2OutputOracle", "version", version)
}
