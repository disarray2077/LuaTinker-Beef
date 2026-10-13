local levels = require('levels')

local min, max, floor, sqrt = math.min, math.max, math.floor, math.sqrt

local W, H = 960, 640
local GRAV, BUOY = 900, 320
local Game = {WIDTH=W, HEIGHT=H, STEP=1/120}
Game.__index = Game

function Game.new()
    return setmetatable({best={0,0,0,0,0}, level=1, state='playing'}, Game)
end

local function distance(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return sqrt(dx * dx + dy * dy)
end

local function near(ax, ay, bx, by, radius)
    local dx, dy = ax - bx, ay - by
    return dx * dx + dy * dy < radius * radius
end

function Game:addRope(anchorX, anchorY, length)
    local candy = self.candy

    local segments = max(2, floor(length / 12 + 0.5))
    local segmentLength = length / segments

    local dx, dy = candy.x - anchorX, candy.y - anchorY
    local d = sqrt(dx * dx + dy * dy)
    if d > 1e-4 then
        dx, dy = dx / d, dy / d
    else
        dx, dy = 0, 1
    end

    local rope = {
        x=anchorX,
        y=anchorY,
        seg=segmentLength,
        maxLen=length,
        attached=true,
        fade=1,
        points={}
    }

    for i = 0, segments - 1 do
        local x, y = anchorX + dx * segmentLength * i, anchorY + dy * segmentLength * i
        rope.points[#rope.points + 1] = { x = x, y = y, px = x, py = y }
    end

    self.ropes[#self.ropes + 1] = rope
end

function Game:loadLevel(index)
    local def = assert(levels[index], "invalid level")

    self.level = index
    self.state = "playing"
    self.time, self.stateTime, self.starsGot = 0, 0, 0

    self.candy = {
        x = def.cx,
        y = def.cy,
        px = def.cx,
        py = def.cy,
        radius = 14,
        alive = true,
        inBubble = def.inBubble or false
    }
    self.frog = { x = def.fx, y = def.fy }
    self.ropes, self.hooks, self.stars, self.bubbles, self.spikes, self.trail = {}, {}, {}, {}, {}, {}

    for _, h in ipairs(def.hooks) do
        self.hooks[#self.hooks + 1] = {x=h[1], y=h[2], radius=h[4], used=h[4] <= 0}
        if h[4] <= 0 then
            local length = h[3] > 0 and h[3] or distance(def.cx, def.cy, h[1], h[2])
            self:addRope(h[1], h[2], length)
        end
    end

    for _, s in ipairs(def.stars) do
        self.stars[#self.stars + 1] = {x=s[1], y=s[2], got=false}
    end

    for _, b in ipairs(def.bubbles) do
        self.bubbles[#self.bubbles + 1] = {x=b[1], y=b[2], radius=26, active=true}
    end

    for _, s in ipairs(def.spikes) do
        self.spikes[#self.spikes + 1] = {x=s[1], y=s[2], w=s[3], h=s[4], dir=s[5]}
    end
end

function Game:finish(state)
    self.state = state
    self.stateTime = 0
    self.candy.alive = false

    for _, rope in ipairs(self.ropes) do
        rope.attached = false
    end

    if state == "won" then
        self.best[self.level] = max(self.best[self.level], self.starsGot)
        print("Level " .. self.level .. " won with " .. self.starsGot .. " stars")
    else
        print("Level " .. self.level .. " lost")
    end
end

local function segmentCrosses(ax, ay, bx, by, cx, cy, dx, dy)
    local function cross(ux, uy, vx, vy)
        return ux * vy - uy * vx
    end
    local d1 = cross(dx - cx, dy - cy, ax - cx, ay - cy)
    local d2 = cross(dx - cx, dy - cy, bx - cx, by - cy)
    local d3 = cross(bx - ax, by - ay, cx - ax, cy - ay)
    local d4 = cross(bx - ax, by - ay, dx - ax, dy - ay)
    return (d1 > 0) ~= (d2 > 0) and (d3 > 0) ~= (d4 > 0)
end

local function pointSegmentDistance(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local squared = dx * dx + dy * dy
    local t = squared > 1e-8 and max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / squared)) or 0
    return distance(px, py, ax + t * dx, ay + t * dy)
end

function Game:cut(ax, ay, bx, by)
    self.trail[#self.trail + 1] = { x = bx, y = by, time = self.time }

    if self.state ~= "playing" then
        return
    end

    for _, rope in ipairs(self.ropes) do
        if rope.attached then
            local points = rope.points
            for i = 1, #points do
                local a = points[i]
                local b = points[i + 1] or self.candy
                if segmentCrosses(ax, ay, bx, by, a.x, a.y, b.x, b.y) or
                   pointSegmentDistance(bx, by, a.x, a.y, b.x, b.y) < 7 then
                    rope.attached = false
                    for j = #points, i + 1, -1 do
                        points[j] = nil
                    end
                    break
                end
            end
        end
    end
end

function Game:click(x, y)
    self.trail[#self.trail + 1] = {x=x, y=y, time=self.time}

    local candy = self.candy
    if self.state == "playing" and candy.inBubble and near(x, y, candy.x, candy.y, 34) then
        candy.inBubble = false
        return
    end

    self:cut(x, y, x, y)
end

local function constrainCandy(candy, ropes)
    for _, rope in ipairs(ropes) do
        if rope.attached then
            local dx = candy.x - rope.x
            local dy = candy.y - rope.y
            local length = sqrt(dx * dx + dy * dy)
            if length > rope.maxLen and length > 1e-5 then
                candy.x = rope.x + dx * rope.maxLen / length
                candy.y = rope.y + dy * rope.maxLen / length
            end
        end
    end
end

local function solveSegment(a, b, maxLength, weightA, weightB)
    local dx = b.x - a.x
    local dy = b.y - a.y
    local length = sqrt(dx * dx + dy * dy)
    if not (length > maxLength and length >= 1e-5) then
        return
    end

    local weight = weightA + weightB
    if weight == 0 then
        return
    end

    local correction = (length - maxLength) / length
    a.x = a.x + dx * correction * weightA / weight
    a.y = a.y + dy * correction * weightA / weight
    if weightB > 0 then
        b.x = b.x - dx * correction * weightB / weight
        b.y = b.y - dy * correction * weightB / weight
    end
end

local function solveRope(rope, candy)
    local points = rope.points
    local anchor = points[1]
    anchor.x, anchor.y = rope.x, rope.y
    anchor.px, anchor.py = rope.x, rope.y

    for i = 1, #points do
        local toCandy = i == #points
        if toCandy and not rope.attached then
            break
        end

        local a = points[i]
        local b = toCandy and candy or points[i + 1]
        local weightA = i == 1 and 0 or 1
        local weightB = toCandy and 0 or 1
        solveSegment(a, b, rope.seg, weightA, weightB)
    end
end

function Game:step(dt)
    self.time = self.time + dt
    self.stateTime = self.stateTime + dt
    
    while #self.trail > 0 and self.time - self.trail[1].time > 0.3 do
        table.remove(self.trail, 1)
    end
    
    for i = #self.ropes, 1, -1 do
        local rope = self.ropes[i]
        if not rope.attached then
            rope.fade = rope.fade - dt * 1.2
            if rope.fade <= 0 then
                table.remove(self.ropes, i)
            end
        end
    end

    local sim = self.state == "playing"
    local candy = self.candy

    for _, rope in ipairs(self.ropes) do
        for i = 2, #rope.points do
            local q = rope.points[i]
            local vx, vy = (q.x - q.px) * 0.995, (q.y - q.py) * 0.995
            q.px, q.py = q.x, q.y
            q.x = q.x + vx
            q.y = q.y + vy + GRAV * dt * dt
        end
    end

    if sim then
        local g = candy.inBubble and -BUOY or GRAV
        local damp = candy.inBubble and 0.99 or 0.999
        local vx, vy = (candy.x - candy.px) * damp, (candy.y - candy.py) * damp
        candy.px, candy.py = candy.x, candy.y
        candy.x = candy.x + vx
        candy.y = candy.y + vy + g * dt * dt
    end

    for _ = 1, 10 do
        if sim then
            constrainCandy(candy, self.ropes)
        end
        for _, rope in ipairs(self.ropes) do
            solveRope(rope, candy)
        end
    end

    if not sim then
        return
    end

    for _, s in ipairs(self.stars) do
        if not s.got and near(candy.x, candy.y, s.x, s.y, candy.radius + 14) then
            s.got = true
            self.starsGot = self.starsGot + 1
        end
    end

    for _, b in ipairs(self.bubbles) do
        if b.active and not candy.inBubble and near(candy.x, candy.y, b.x, b.y, b.radius) then
            b.active = false
            candy.inBubble = true
            local vx, vy = candy.x - candy.px, candy.y - candy.py
            candy.px = candy.x - vx * 0.3
            candy.py = candy.y - vy * 0.3
        end
    end

    for _, h in ipairs(self.hooks) do
        if not h.used and h.radius > 0 and near(candy.x, candy.y, h.x, h.y, h.radius) then
            h.used = true
            self:addRope(h.x, h.y, distance(candy.x, candy.y, h.x, h.y))
        end
    end

    for _, spike in ipairs(self.spikes) do
        local x = max(spike.x, min(spike.x + spike.w, candy.x))
        local y = max(spike.y, min(spike.y + spike.h, candy.y))
        if near(x, y, candy.x, candy.y, candy.radius - 3) then
            self:finish("lost")
            return
        end
    end

    if near(candy.x, candy.y, self.frog.x, self.frog.y, 44) then
        self:finish("won")
        return
    end

    if candy.y > H + 40 or candy.x < -40 or candy.x > W + 40 or candy.y < -60 then
        self:finish("lost")
    end
end

return Game
