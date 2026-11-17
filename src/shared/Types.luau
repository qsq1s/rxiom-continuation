--!strict
-- Struktury danych przesyłane między serwerem a klientem.

export type Side = "Buy" | "Sell"

export type TimeframeStats = {
	Volume: number, -- $
	Buys: number,
	Sells: number,
	Change: number, -- %
}

-- Świeca: ceny w RX za token; T to początek okresu (czas serwera).
export type Candle = { T: number, O: number, H: number, L: number, C: number }

-- Poziom księgi zleceń graczy: cena (RX za token), suma pozostałych tokenów i liczba zleceń.
export type BookLevel = { Price: number, Tokens: number, Orders: number }

-- Bids malejąco, Asks rosnąco po cenie.
export type BookDepth = { Bids: { BookLevel }, Asks: { BookLevel } }

export type CoinSnapshot = {
	Ticker: string,
	Book: BookDepth,
	Price: number,
	PoolRx: number,
	PoolTokens: number,
	MarketCap: number,
	Liquidity: number,
	Holders: number,
	LaunchedAt: number,
	Stats: { [string]: TimeframeStats },
	Candle: Candle,
	Spark: { number },
}

export type TradeEvent = {
	Ticker: string,
	Side: Side,
	Rx: number,
	Tokens: number,
	MarketCap: number,
	Trader: string,
	IsPlayer: boolean,
	Time: number,
}

export type MarketSnapshot = {
	Time: number,
	Coins: { [string]: CoinSnapshot },
	Trades: { TradeEvent },
}

-- Wykonana transakcja gracza; Price to średnia cena wykonania (RX za token) bez prowizji.
export type Fill = {
	T: number,
	Side: Side,
	Price: number,
	Tokens: number,
}

-- BuyTokens/BuyValue liczą średnią cenę wejścia (BuyValue / BuyTokens) dla bieżącej pozycji.
export type Position = {
	Tokens: number,
	BoughtRx: number,
	SoldRx: number,
	BuyTokens: number,
	BuyValue: number,
	Fills: { Fill },
}

-- TP/SL po kupnie: sprzedaj Tokens, gdy MC ($) >= Above albo MC <= Below. Tokeny są zablokowane.
export type TriggerOrder = {
	Id: number,
	Ticker: string,
	Tokens: number,
	Fees: number,
	Above: number,
	Below: number,
	CreatedAt: number,
}

-- Zlecenie z limitem ceny w księdze. Price w RX za token, Tokens to pozostała ilość.
-- Kupno rezerwuje RX (Reserved), sprzedaż blokuje tokeny. Zlecenie jest zapisywane w profilu
-- i wisi w księdze, dopóki nie zostanie wykonane albo anulowane.
export type BookOrder = {
	Id: string,
	Ticker: string,
	Side: Side,
	Price: number,
	Tokens: number,
	Filled: number,
	Reserved: number,
	CreatedAt: number,
}

export type PortfolioState = {
	Balance: number,
	Positions: { [string]: Position },
	Orders: { BookOrder },
	Triggers: { TriggerOrder },
	FaucetReadyAt: number,
	Wallet: string?,
}

export type LoginResult = {
	Ok: boolean,
	Error: string?,
	Wallet: string?,
	-- true, gdy portfel został właśnie utworzony (pierwsze logowanie).
	New: boolean?,
}

-- Amount: RX przy kupnie, procent posiadanych tokenów przy sprzedaży.
export type TradeRequest = {
	Ticker: string,
	Side: Side,
	Amount: number,
	ExpectedOut: number,
	Slippage: number,
	PriorityFee: number,
	Tip: number,
	Bracket: { TakeProfit: number, StopLoss: number }?,
}

-- Zlecenie do księgi. Price w RX za token; Amount: RX przy kupnie, procent tokenów przy sprzedaży.
export type LimitRequest = {
	Ticker: string,
	Side: Side,
	Price: number,
	Amount: number,
}

export type ActionResult = {
	Ok: boolean,
	Error: string?,
	Rx: number?,
	Tokens: number?,
}

export type Notice = { Kind: "Success" | "Error" | "Info", Text: string }

export type InitialState = {
	Market: MarketSnapshot,
	Trades: { [string]: { TradeEvent } },
	Portfolio: PortfolioState?,
}

return {}
