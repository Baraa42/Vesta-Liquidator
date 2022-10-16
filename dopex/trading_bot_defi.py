import time
from arbitrager_defi import Arbitrager


TARGET_PROFIT = 10
TARGET_APR = 10
SLEEP_TIME = 30
KEY_WORD = "-C"
TRADING = False


# objectif scrap data
config_eth = {
    "is_test": False,
    "index": "eth_usd",
    "spot": "ETH",
    "wallet": "0x",
    "sleep_period": 10,
    "expiry": 1666339200,
    "order_sizes": [1, 2, 5, 10, 25],
}


agent = Arbitrager(config_eth)


def run_search():
    df = agent.get_arb_data()
    print(df)
    df.sort_values("APR", inplace=True)
    df_opp = df[df["APR"] >= TARGET_APR]
    apr_max = -1
    row_max = None
    if len(df_opp) > 0:
        for row in df_opp.iterrows():
            row = row[1]
            instrument = row["instrument_name"]
            if KEY_WORD in instrument:
                apr = row["APR"]
                print(f"Found opportunity for this week, searching {instrument}. apr: {apr}")
                try:
                    df_instrument = agent.search_instrument(instrument)
                    df_instrument.sort_values("APR", inplace=True)
                    print(df_instrument)
                    for row in df_instrument.iterrows():
                        row = row[1]
                        if row["PNL (USD)"] > TARGET_PROFIT:
                            order_size = row["Order Sizes"]
                            print(
                                f"instrument: {instrument}.. order_size: {order_size}. pnl: {round(row['PNL (USD)'],2)}. apr: {round(row['APR'],2)}"
                            )
                            if row["APR"] > apr_max:
                                row_max = row
                                apr_max = row["APR"]

                except:
                    print(f"Review search_instrument function, row: {row}")
        if TRADING and row_max:
            agent.do_trade(row["instrument_name"], row["Order Sizes"])
    return df


# running each half minute
def run_bot():
    print("start of the loop")
    i = 0
    while True:
        print(f"entering loop {i}...")
        try:
            run_search()
            i = i + 1
            time.sleep(SLEEP_TIME)
        except:
            try:
                agent.update()
                run_search()
                i = i + 1
                time.sleep(SLEEP_TIME)
            except Exception as e:
                i = i + 1
                time.sleep(SLEEP_TIME)


run_bot()
