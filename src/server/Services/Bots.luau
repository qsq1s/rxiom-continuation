--!strict
-- Boty symulujące innych traderów, żeby rynek żył także przy kilku graczach na serwerze.
-- Każdy coin ma "sentyment" (losowy spacer z wygaszaniem) i słabe przyciąganie do ceny startowej,
-- dzięki czemu ceny pompują i zrzucają, ale nie uciekają w nieskończoność.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Amm = require(ReplicatedStorage.Shared.Amm)
local Config = require(ReplicatedStorage.Shared.Config)
local Market = require(script.Parent.Market)
local OrderBook = require(script.Parent.OrderBook)

local BASE58 = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

local Bots = {}

local rng = Random.new()
local sentiment: { [string]: number } = {}

local function walletName(): string
	local function part(n: number): string
		local chars = table.create(n)
		for i = 1, n do
			local index = rng:NextInteger(1, #BASE58)
			chars[i] = string.sub(BASE58, index, index)
		end
		return table.concat(chars)
	end
	return part(4) .. "..." .. part(4)
end

local function trade(ticker: string, state: Market.CoinState, s: number, t: number)
	local pool = state.Pool
	local reversion = math.clamp(0.2 * math.log(state.InitialPrice / Amm.price(pool)), -0.35, 0.35)
	local buyChance = math.clamp(0.5 + s + reversion, 0.08, 0.92)
	-- Rozkład z długim ogonem: zwykle małe transakcje, czasem wieloryb. Duże coiny ruszają się spokojniej.
	local calm = math.clamp(1 - math.log10(state.Def.MarketCap / 1e4) * 0.22, 0.25, 1)
	local size = pool.Rx * (0.0006 + rng:NextNumber() ^ 3 * 0.015) * calm

	if rng:NextNumber() < buyChance then
		OrderBook.buy(ticker, size, walletName(), false, t)
	else
		local tokens = pool.Tokens * size / (pool.Rx - size)
		OrderBook.sell(ticker, tokens, walletName(), false, t)
	end
end

local function stepCoin(ticker: string, state: Market.CoinState, dt: number, t: number)
	local s = sentiment[ticker] or 0
	s = s * math.max(0, 1 - 0.06 * dt) + rng:NextNumber(-1, 1) * 0.12 * math.sqrt(dt)
	-- Rzadkie gwałtowne zwroty: pompa albo dump.
	if rng:NextNumber() < dt / 240 then
		s += if rng:NextNumber() < 0.55 then 0.35 else -0.35
	end
	s = math.clamp(s, -0.45, 0.45)
	sentiment[ticker] = s

	-- Oczekiwana liczba transakcji w kroku; przy dłuższym kroku (rozgrzewka) bywa ich kilka.
	local expected = state.Def.Activity * dt
	local count = math.floor(expected) + (if rng:NextNumber() < expected % 1 then 1 else 0)
	for _ = 1, count do
		trade(ticker, state, s, t)
	end
end

function Bots.step(dt: number, t: number)
	for ticker, state in Market.all() do
		if t >= state.LaunchedAt then
			stepCoin(ticker, state, dt, t)
		end
	end
end

-- Symuluje ostatnie Config.WarmupSeconds handlu (lub krócej, jeśli coin jest młodszy), żeby zmiana
-- i wolumen 24h były pełne od startu serwera. Historia starsza niż zakres świec liczona jest
-- grubszym krokiem, bo trafia już tylko do statystyk.
function Bots.warmup()
	local finish = Market.now()
	local detailedFrom = finish - Config.CandleHistory * Config.CandleSeconds
	Market.setBroadcasting(false)
	local t = finish - Config.WarmupSeconds
	while t < finish do
		local detailed = t >= detailedFrom
		local step = if detailed then 0.5 else 2
		Bots.step(step, t)
		if detailed then
			Market.tick(t)
		end
		t += step
	end
	Market.setBroadcasting(true)
end

return Bots
