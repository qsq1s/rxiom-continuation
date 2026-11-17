--!strict
-- Główny interfejs RXIOM: okno przeglądarki z rxiom.pro, a w nim strona z górnym paskiem,
-- podstronami Discover / coin / Portfolio, dolnym paskiem i powiadomieniami.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local UI = script.Parent
local Browser = require(UI.Browser)
local Theme = require(UI.Theme)
local Toast = require(UI.Toast)
local Util = require(UI.Util)

local BottomBar = require(script.BottomBar)
local CoinView = require(script.CoinView)
local DiscoverPage = require(script.DiscoverPage)
local PortfolioPage = require(script.PortfolioPage)
local TopBar = require(script.TopBar)

local create = Util.create

local CONTENT_PADDING = 32

type Page = { Name: "Discover" | "Coin" | "Portfolio", Ticker: string? }

local MainMenu = {}

local function hideDefaultCoreGui()
	-- Chat, lista graczy, plecak, emotki, zdrowie.
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)

	local chatWindow = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	local chatInput = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
	if chatWindow then
		chatWindow.Enabled = false
	end
	if chatInput then
		chatInput.Enabled = false
	end

	-- SetCore działa dopiero po załadowaniu CoreScripts, więc ponawiamy przez kilka sekund.
	-- Przycisku menu Robloxa (logo) nie da się ukryć; Roblox go wymaga.
	task.spawn(function()
		for _ = 1, 20 do
			if pcall(StarterGui.SetCore, StarterGui, "TopbarEnabled", false) then
				return
			end
			task.wait(0.5)
		end
	end)
end

local function pagePath(page: Page): string
	if page.Name == "Coin" then
		return "/meme/" .. string.lower(page.Ticker or "")
	elseif page.Name == "Portfolio" then
		return "/portfolio"
	end
	return "/discover"
end

export type Handle = {
	Gui: ScreenGui,
	-- Kontener strony rxiom.pro (pod przeglądarką, skalowany UIScale).
	Root: Frame,
	-- Pokazuje w przeglądarce podaną ścieżkę i blokuje nawigację (ekran logowania).
	Lock: (path: string) -> (),
	Unlock: () -> (),
}

function MainMenu.mount(): Handle
	hideDefaultCoreGui()

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui: ScreenGui = create("ScreenGui", {
		Name = "RXIOM",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	create("Frame", {
		Name = "Background",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Background,
		BorderSizePixel = 0,
		Parent = gui,
	})

	-- Strona rxiom.pro: skalowana UIScale, pozycjonowana pod przeglądarką w relayout().
	local root: Frame = create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local uiScale: UIScale = create("UIScale", { Parent = root })

	local site: Frame = create("Frame", {
		Name = "Site",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})
	local content: Frame = create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, TopBar.Height),
		Size = UDim2.new(1, 0, 1, -(TopBar.Height + BottomBar.Height)),
		Parent = site,
	}, { Util.padding(16, CONTENT_PADDING, 16, CONTENT_PADDING) })

	local pages: { [string]: GuiObject } = {}
	local history: { Page } = {}
	local position = 0
	-- Podczas logowania przeglądarka pokazuje stronę logowania i nie da się nawigować.
	local locked = false
	local browser: Browser.Browser
	local topBar: TopBar.TopBar
	local coinView: CoinView.CoinView
	local portfolioPage: PortfolioPage.PortfolioPage

	local function render(page: Page)
		for name, frame in pages do
			frame.Visible = name == page.Name
		end
		if page.Name == "Coin" and page.Ticker then
			coinView.Open(page.Ticker)
		elseif page.Name == "Portfolio" then
			portfolioPage.Refresh()
		end
		topBar.SetActive(if page.Name == "Portfolio" then "Portfolio" else "Discover")
		if locked then
			return
		end
		browser.SetPath(pagePath(page))
		browser.SetHistory(position > 1, position < #history)
	end

	local function navigate(page: Page)
		local current = history[position]
		if current and current.Name == page.Name and current.Ticker == page.Ticker then
			render(page)
			return
		end
		-- Nowa strona ucina historię "dalej", jak w przeglądarce.
		for i = #history, position + 1, -1 do
			history[i] = nil
		end
		table.insert(history, page)
		position = #history
		render(page)
	end

	local function openCoin(ticker: string)
		navigate({ Name = "Coin", Ticker = ticker })
	end

	local navigation: TopBar.Navigation = {
		Discover = function()
			navigate({ Name = "Discover" })
		end,
		Portfolio = function()
			navigate({ Name = "Portfolio" })
		end,
	}

	browser = Browser.new({
		Back = function()
			if not locked and position > 1 then
				position -= 1
				render(history[position])
			end
		end,
		Forward = function()
			if not locked and position < #history then
				position += 1
				render(history[position])
			end
		end,
	})
	browser.Frame.Parent = gui

	topBar = TopBar.new(navigation)
	topBar.Frame.Parent = site

	-- Discover: karta "Prices" + "Top Movers"
	local discover = DiscoverPage.new(openCoin)
	discover.Frame.Parent = content
	pages.Discover = discover.Frame

	coinView = CoinView.new(navigation.Discover)
	coinView.Frame.Parent = content
	pages.Coin = coinView.Frame

	portfolioPage = PortfolioPage.new(openCoin)
	portfolioPage.Frame.Parent = content
	pages.Portfolio = portfolioPage.Frame

	BottomBar.new().Frame.Parent = site
	Toast.mount(site, BottomBar.Height + 16)

	navigation.Discover()

	local function relayout()
		local viewport = gui.AbsoluteSize
		if viewport.X <= 0 or viewport.Y <= 0 then
			return
		end

		-- Przeglądarka w pikselach ekranu; pasek adresu zaczyna się za przyciskami Robloxa.
		local inset = GuiService.TopbarInset
		local hasTopbar = inset.Width > 0
		local chromeHeight =
			browser.Layout(if hasTopbar then inset.Min.X + 8 else 0, if hasTopbar then inset.Max.Y else 0)

		-- Strona pod nią: projektowana pod Theme.DesignSize i skalowana UIScale do wolnego miejsca.
		local available = Vector2.new(viewport.X, math.max(1, viewport.Y - chromeHeight))
		local design = Theme.DesignSize
		local scale = math.clamp(math.min(available.X / design.X, available.Y / design.Y), 0.5, 2)
		uiScale.Scale = scale
		Util.setScale(scale)
		root.Position = UDim2.fromOffset(0, chromeHeight)
		root.Size = UDim2.fromOffset(available.X / scale, available.Y / scale)
	end

	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(relayout)
	relayout()

	return {
		Gui = gui,
		Root = root,
		Lock = function(path: string)
			locked = true
			browser.SetPath(path)
			browser.SetHistory(false, false)
		end,
		Unlock = function()
			locked = false
			local page = history[position]
			if page then
				render(page)
			end
		end,
	}
end

return MainMenu
