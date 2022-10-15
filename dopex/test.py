import os, sys, json, time
import requests
import numpy as np
import pandas as pd
from datetime import datetime
import web3
from web3 import Web3
from web3.middleware import geth_poa_middleware
from eth_abi import decode_abi
from dotenv import dotenv_values
from collections import OrderedDict
import dopex_agent
import deribit_agent

# Load .env
__ENV = dotenv_values("./.env")
__ENV["network"] = "arbitrum"

# Instantiate provider
w3 = Web3(Web3.HTTPProvider(__ENV["ARBITRUM_RPC_URL"]))
w3.middleware_onion.inject(geth_poa_middleware, layer=0)

with open("constants/contract_addresses.json") as jsonFile:
    contract_addresses = json.load(jsonFile)
    jsonFile.close()

with open("abis/ethweekly_abi.json") as jsonFile:
    ethweekly_abi = json.load(jsonFile)
    jsonFile.close()

ethweekly = w3.eth.contract(address=contract_addresses[__ENV["network"]]["ethweekly"]["address"], abi=ethweekly_abi)


def get_Epoch_data(_epoch):
    """
    Fetch data for a provided epoch.
    Returns an OrderedDict
    """

    HEADERS = (
        "expired",
        "start_time",
        "expiry",
        "settlement_price",
        "totalCollateralBalance",
        "collateralExchangeRate",
        "settlementCollateralExchangeRate",
        "strikes",
        "totalRewardsCollected",
        "rewardDistributionRatios",
        "rewardTokensToDistribute",
    )

    epochData = OrderedDict()
    epochData["epoch"] = _epoch

    epochData.update(OrderedDict(zip(HEADERS, ethweekly.functions.getEpochData(_epoch).call())))

    epochData["epoch"] = _epoch
    epochData["start_time"] = datetime.fromtimestamp(epochData["start_time"])
    epochData["expiry"] = datetime.fromtimestamp(epochData["expiry"])

    return epochData


def get_Epoch_Strike_Data(_epoch, _strikes):

    HEADERS = (
        "strikeToken",
        "totalCollateral",
        "activeCollateral",
        "totalPremiums",
        "checkpointPointer",
        "rewardStoredForPremiums",
        "rewardDistributionRatiosForPremiums",
    )

    epochStrikeData = OrderedDict()

    for strike in _strikes:
        epochStrikeData[strike] = OrderedDict(
            zip(HEADERS, ethweekly.functions.getEpochStrikeData(_epoch, strike).call())
        )

    return epochStrikeData


def makeTable(_epochData, _dopexAgent, _deribitAgent):

    tabledata = OrderedDict({k: v for k, v in _epochData.items() if k in ("expiry", "strikes")})

    __timestamp = int(tabledata["expiry"].timestamp())
    __sellPrices = []
    __instrument_name = None

    tabledata["strikes"] = list(map(lambda x: x // (10**8), tabledata["strikes"]))
    tabledata["Buy Prices"] = _dopexAgent.get_call_prices(tabledata["strikes"], __timestamp)

    for strike in tabledata["strikes"]:
        sellPrice = _deribitAgent.get_pure_quotes(
            _dopexAgent.get_timestamp_key(__timestamp) + str(strike) + "-C", [1], "short"
        )
        __sellPrices.append(sellPrice[0])

    tabledata["Sell Prices"] = __sellPrices

    df = pd.DataFrame(tabledata)
    df.rename(columns={"expiry": "Expiry", "strikes": "Strike Price"}, inplace=True)
    df["Strike Price"] = df["Strike Price"]

    return df


dopexAgent = dopex_agent.Dopex_Agent({"wallet": "0x"})  # Empty wallet for now
deribitAgent = deribit_agent.Deribit_Agent(deribit_agent.config)

currentEpoch = ethweekly.functions.currentEpoch().call()
epochData = get_Epoch_data(currentEpoch)
epochStrikeData = get_Epoch_Strike_Data(epochData["epoch"], epochData["strikes"])

print(makeTable(epochData, dopexAgent, deribitAgent))


# pnl = sell - buy
# apr = (sell - buy) / (strike*1.25) * [ (1 year) / (expiry - now)]
