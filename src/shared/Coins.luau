--!strict
-- Coiny na rynku: stała lista (Discover) oraz coiny tworzone przez graczy (Pulse).
-- MarketCap i Liquidity (w $) wyznaczają startową pulę płynności; Activity to średnia liczba
-- transakcji botów na sekundę. Coiny z Pulse mają ustawione Creator.

local Config = require(script.Parent.Config)

export type CoinDef = {
	Ticker: string,
	Name: string,
	Color: Color3,
	Age: number,
	MarketCap: number,
	Liquidity: number,
	Holders: number,
	Activity: number,
	-- Tylko coiny z Pulse: nazwa gracza, który go stworzył.
	Creator: string?,
}

local MINUTE, DAY = 60, 86400

local function coin(
	ticker: string,
	name: string,
	hex: string,
	age: number,
	marketCap: number,
	liquidity: number,
	holders: number,
	activity: number
): CoinDef
	return table.freeze({
		Ticker = ticker,
		Name = name,
		Color = Color3.fromHex(hex),
		Age = age,
		MarketCap = marketCap,
		Liquidity = liquidity,
		Holders = holders,
		Activity = activity,
	})
end

-- Nazwy to zaślepki do podmiany na docelową listę.
local List: { CoinDef } = {
	coin("COIN1", "Placeholder One", "F5C542", 38 * MINUTE, 117_000, 14_200, 1082, 1.4),
	coin("COIN2", "Placeholder Two", "526FFF", 10 * MINUTE, 30_300, 7_030, 200, 1.1),
	coin("COIN3", "Placeholder Three", "2FE3AC", 22 * DAY, 14_500_000, 213_000, 31281, 0.8),
	coin("COIN4", "Placeholder Four", "EC397A", 1 * MINUTE, 14_000, 3_540, 237, 1.6),
	coin("COIN5", "Placeholder Five", "A855F7", 90 * DAY, 12_400_000, 241_000, 80492, 0.6),
	coin("COIN6", "Placeholder Six", "F7931A", 4 * MINUTE, 26_800, 5_790, 386, 1.8),
	coin("COIN7", "Placeholder Seven", "38BDF8", 2 * MINUTE, 9_600, 2_550, 226, 1.2),
	coin("COIN8", "Placeholder Eight", "84CC16", 3 * MINUTE, 11_900, 3_100, 150, 1.0),
}

local ByTicker: { [string]: CoinDef } = {}
for _, def in List do
	ByTicker[def.Ticker] = def
end

local Coins = {}

-- Stała lista coinów (Discover, dolny pasek).
Coins.List = table.freeze(List)
Coins.ByTicker = table.freeze(ByTicker)

local launched: { [string]: CoinDef } = {}

-- Dowolny znany coin: ze stałej listy albo z Pulse.
function Coins.get(ticker: string): CoinDef?
	return ByTicker[ticker] or launched[ticker]
end

function Coins.register(def: CoinDef)
	launched[def.Ticker] = def
end

function Coins.unregister(ticker: string)
	launched[ticker] = nil
end

-- Wszystkie znane coiny: najpierw stała lista, potem coiny z Pulse alfabetycznie.
function Coins.all(): { CoinDef }
	local result = table.clone(List)
	local extra = {}
	for _, def in launched do
		table.insert(extra, def)
	end
	table.sort(extra, function(a, b)
		return a.Ticker < b.Ticker
	end)
	table.move(extra, 1, #extra, #result + 1, result)
	return result
end

-- Ticker: 2-8 znaków A-Z i 0-9, co najmniej jedna litera.
function Coins.validTicker(ticker: any): boolean
	return typeof(ticker) == "string"
		and #ticker >= 2
		and #ticker <= 8
		and string.find(ticker, "^[A-Z0-9]+$") ~= nil
		and string.find(ticker, "%u") ~= nil
end

-- Nazwa coina z Pulse: 2-24 znaki, litery, cyfry, spacje i . - ! ? ' (bez znaków RichText).
function Coins.validName(name: any): boolean
	return typeof(name) == "string"
		and #name >= 2
		and #name <= 24
		and string.find(name, "^[%w %.%-!%?']+$") ~= nil
		and string.find(name, "%w") ~= nil
end

-- Definicja coina z Pulse; pula startowa wynika z Config.Launch.
function Coins.launch(ticker: string, name: string, color: Color3, creator: string): CoinDef
	return table.freeze({
		Ticker = ticker,
		Name = name,
		Color = color,
		Age = 0,
		MarketCap = Config.Launch.StartMarketCap,
		Liquidity = Config.Launch.PoolRx * 2 * Config.UsdPerRx,
		Holders = 0,
		Activity = Config.Launch.Activity,
		Creator = creator,
	})
end

return Coins
