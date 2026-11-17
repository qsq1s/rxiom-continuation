--!strict
-- Rasteryzacja małych ikon: kształt opisany funkcją w siatce 24x24 (jak ikony Material) jest
-- próbkowany kilka razy na piksel, więc krawędzie wychodzą wygładzone zamiast schodkowe.
-- Czysta matematyka bez API Robloxa (da się testować poza grą).

export type Shape = (x: number, y: number) -> boolean

local Raster = {}

local GRID = 24
local SAMPLES = 4

-- Pokrycie każdego piksela (0..1) dla ikony `size` x `size`; wynik[y][x], indeksy od 1.
function Raster.coverage(size: number, inside: Shape): { { number } }
	local scale = GRID / size
	local rows = table.create(size)
	for py = 0, size - 1 do
		local row = table.create(size, 0)
		for px = 0, size - 1 do
			local hits = 0
			for sy = 0, SAMPLES - 1 do
				local y = (py + (sy + 0.5) / SAMPLES) * scale
				for sx = 0, SAMPLES - 1 do
					if inside((px + (sx + 0.5) / SAMPLES) * scale, y) then
						hits += 1
					end
				end
			end
			row[px + 1] = hits / (SAMPLES * SAMPLES)
		end
		rows[py + 1] = row
	end
	return rows
end

local function inTriangle(x: number, y: number, a: Vector2, b: Vector2, c: Vector2): boolean
	local function side(p: Vector2, q: Vector2): number
		return (x - q.X) * (p.Y - q.Y) - (p.X - q.X) * (y - q.Y)
	end
	local d1, d2, d3 = side(a, b), side(b, c), side(c, a)
	local negative = d1 < 0 or d2 < 0 or d3 < 0
	local positive = d1 > 0 or d2 > 0 or d3 > 0
	return not (negative and positive)
end

-- Odśwież: dwie strzałki biegnące po okręgu zgodnie z ruchem wskazówek zegara. Prawa zaczyna się
-- zaokrąglonym końcem u góry i kończy grotem w dół na godzinie 3; lewa to ta sama strzałka
-- obrócona o 180°.
local CENTER = 12
local RADIUS = 7.2
local THICKNESS = 2.6
local START = math.rad(-125)
local HEAD_HALF = 3.5
local HEAD_LENGTH = 4.4

local capCenter = Vector2.new(CENTER + RADIUS * math.cos(START), CENTER + RADIUS * math.sin(START))
local headA = Vector2.new(CENTER + RADIUS - HEAD_HALF, CENTER)
local headB = Vector2.new(CENTER + RADIUS + HEAD_HALF, CENTER)
local headTip = Vector2.new(CENTER + RADIUS, CENTER + HEAD_LENGTH)

local function halfSync(x: number, y: number): boolean
	local dx, dy = x - CENTER, y - CENTER
	local distance = math.sqrt(dx * dx + dy * dy)
	if math.abs(distance - RADIUS) <= THICKNESS / 2 then
		local angle = math.atan2(dy, dx)
		if angle >= START and angle <= 0 then
			return true
		end
	end
	local cx, cy = x - capCenter.X, y - capCenter.Y
	if cx * cx + cy * cy <= (THICKNESS / 2) ^ 2 then
		return true
	end
	return inTriangle(x, y, headA, headB, headTip)
end

function Raster.sync(x: number, y: number): boolean
	return halfSync(x, y) or halfSync(GRID - x, GRID - y)
end

return table.freeze(Raster)
