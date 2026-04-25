---Constants---
local W, H        = 600, 600
local CELL        = 140
local GRID_X      = (W - CELL * 3) / 2      -- left edge of grid
local GRID_Y      = 160                      -- top  edge of grid
local MAX_ROUNDS  = 10

---Colours---
local C = {
    bg        = {0.36, 0.65, 0.84},
    grid      = {1,    1,    1,    0.9},
    cellHover = {1,    1,    1,    0.25},
    X         = {0.85, 0.22, 0.22},
    O         = {0.22, 0.45, 0.85},
    white     = {1,    1,    1},
    yellow    = {1,    0.92, 0.23},
    dark      = {0.12, 0.12, 0.12},
    panel     = {1,    1,    1,    0.18},
    btnBg     = {0.18, 0.42, 0.62},
    btnHover  = {0.25, 0.55, 0.78},
    btnSel    = {0.10, 0.68, 0.38},   -- selected difficulty button (green)
    winLine   = {1,    0.88, 0.1, 0.95},
}

local fnt = {}

---State---
local state          -- "menu" | "playing" | "roundEnd" | "gameEnd"
local board          -- 3×3 table; nil=empty, "X"=player, "O"=AI
local playerScore
local aiScore
local round
local roundWinner    -- "X" | "O" | "draw"
local winCells       -- list of {r,c} for the winning line
local aiThinking     -- a small delay so AI move feels natural
local aiTimer
local hoverCell      -- {r,c} or nil
local difficulty     -- "easy" | "hard"

---Helpers---
local function newBoard()
    local b = {}
    for r = 1, 3 do b[r] = {nil, nil, nil} end
    return b
end

local function boardCopy(b)
    local nb = {}
    for r = 1, 3 do nb[r] = {b[r][1], b[r][2], b[r][3]} end
    return nb
end

local function checkWinner(b)
    local lines = {
        {{1,1},{1,2},{1,3}}, {{2,1},{2,2},{2,3}}, {{3,1},{3,2},{3,3}},
        {{1,1},{2,1},{3,1}}, {{1,2},{2,2},{3,2}}, {{1,3},{2,3},{3,3}},
        {{1,1},{2,2},{3,3}}, {{1,3},{2,2},{3,1}},
    }
    for _, line in ipairs(lines) do
        local a,b2,c = line[1],line[2],line[3]
        local v = b[a[1]][a[2]]
        if v and v == b[b2[1]][b2[2]] and v == b[c[1]][c[2]] then
            return v, line
        end
    end
    -- check draw
    for r = 1,3 do for c = 1,3 do
        if not b[r][c] then return nil end
    end end
    return "draw"
end

---Minimax (Hard)---
local function minimax(b, isMax, alpha, beta)
    local winner = checkWinner(b)
    if winner == "O"    then return  10 end
    if winner == "X"    then return -10 end
    if winner == "draw" then return   0 end

    if isMax then
        local best = -math.huge
        for r = 1,3 do for c = 1,3 do
            if not b[r][c] then
                b[r][c] = "O"
                local score = minimax(b, false, alpha, beta)
                b[r][c] = nil
                best  = math.max(best,  score)
                alpha = math.max(alpha, best)
                if beta <= alpha then return best end
            end
        end end
        return best
    else
        local best = math.huge
        for r = 1,3 do for c = 1,3 do
            if not b[r][c] then
                b[r][c] = "X"
                local score = minimax(b, true, alpha, beta)
                b[r][c] = nil
                best = math.min(best,  score)
                beta = math.min(beta,  best)
                if beta <= alpha then return best end
            end
        end end
        return best
    end
end

local function bestAIMove(b)
    local bestScore, br, bc = -math.huge, nil, nil
    for r = 1,3 do for c = 1,3 do
        if not b[r][c] then
            b[r][c] = "O"
            local s = minimax(b, false, -math.huge, math.huge)
            b[r][c] = nil
            if s > bestScore then bestScore, br, bc = s, r, c end
        end
    end end
    return br, bc
end

---Minimax (Easy)---
--uses the hard mode algorithm as a base to strip this version down by limiting 
--its thinking mode and adding random elements which gives disadavantages, but that
--doesnt mean it wont try to win (AI used here)
local function minimaxEasy(b, isMax, alpha, beta, depth)
    local winner = checkWinner(b)
    if winner == "O"    then return  10 end
    if winner == "X"    then return -10 end
    if winner == "draw" then return   0 end
    if depth >= 2 then return 0 end

    if isMax then
        local best = -math.huge
        for r = 1,3 do for c = 1,3 do
            if not b[r][c] then
                b[r][c] = "O"
                local score = minimaxEasy(b, false, alpha, beta, depth + 1)
                b[r][c] = nil
                best  = math.max(best,  score)
                alpha = math.max(alpha, best)
                if beta <= alpha then return best end
            end
        end end
        return best
    else
        local best = math.huge
        for r = 1,3 do for c = 1,3 do
            if not b[r][c] then
                b[r][c] = "X"
                local score = minimaxEasy(b, true, alpha, beta, depth + 1)
                b[r][c] = nil
                best = math.min(best,  score)
                beta = math.min(beta,  best)
                if beta <= alpha then return best end
            end
        end end
        return best
    end
end

-- Among all moves that share the best minimax score, pick one at random.
-- This prevents the easy AI from always playing the same deterministic
-- sequence, making it feel more natural and less predictable.
local function bestAIMoveEasy(b)
    local bestScore = -math.huge
    local candidates = {}

    for r = 1,3 do for c = 1,3 do
        if not b[r][c] then
            b[r][c] = "O"
            local s = minimaxEasy(b, false, -math.huge, math.huge, 0)
            b[r][c] = nil
            if s > bestScore then
                bestScore  = s
                candidates = {{r, c}}
            elseif s == bestScore then
                candidates[#candidates + 1] = {r, c}
            end
        end
    end end

    if #candidates == 0 then return nil, nil end
    local pick = candidates[math.random(#candidates)]
    return pick[1], pick[2]
end

---Grid helpers---
local function cellRect(r, c)
    local x = GRID_X + (c-1)*CELL
    local y = GRID_Y + (r-1)*CELL
    return x, y, CELL, CELL
end

---button helpers---
local function cellAt(mx, my)
    for r = 1,3 do for c = 1,3 do
        local x,y,w,h2 = cellRect(r,c)
        if mx>=x and mx<x+w and my>=y and my<y+h2 then
            return r,c
        end
    end end
end

local function drawButton(lbl, x, y, w, h2, hover, selected)
    local col
    if selected then
        col = C.btnSel
    elseif hover then
        col = C.btnHover
    else
        col = C.btnBg
    end
    love.graphics.setColor(col)
    love.graphics.rectangle("fill", x, y, w, h2, 8, 8)
    love.graphics.setColor(C.yellow)
    love.graphics.setFont(fnt.med)
    love.graphics.printf(lbl, x, y + h2/2 - fnt.med:getHeight()/2, w, "center")
end

local function btnHit(mx, my, x, y, w, h2)
    return mx>=x and mx<=x+w and my>=y and my<=y+h2
end

---Initialise---
function love.load()
    love.window.setTitle("Tic Tac Toe")
    love.window.setMode(W, H, {resizable=false})

    fnt.small = love.graphics.newFont(16)
    fnt.med   = love.graphics.newFont(22)
    fnt.large = love.graphics.newFont(36)
    fnt.title = love.graphics.newFont(52)
    fnt.sym   = love.graphics.newFont(80)   -- X / O symbols

    math.randomseed(os.time())  -- seed RNG for easy mode tie-breaking

    difficulty = "hard"         -- default difficulty
    state      = "menu"
    playerScore, aiScore, round = 0, 0, 0
end

local function startRound()
    board       = newBoard()
    roundWinner = nil
    winCells    = nil
    aiThinking  = false
    aiTimer     = 0
    state       = "playing"
end

---Update---
function love.update(dt)
    local mx, my = love.mouse.getPosition()
    hoverCell = nil

    if state == "playing" then
        local r,c = cellAt(mx,my)
        if r and not board[r][c] and not aiThinking then
            hoverCell = {r,c}
        end

        if aiThinking then
            aiTimer = aiTimer + dt
            if aiTimer >= 0.45 then
                aiThinking = false

                -- choose a move based on current difficulty
                local ar, ac
                if difficulty == "easy" then
                    ar, ac = bestAIMoveEasy(board)
                else
                    ar, ac = bestAIMove(board)
                end

                if ar then
                    board[ar][ac] = "O"
                    local w, wc = checkWinner(board)
                    if w then
                        winCells    = wc
                        roundWinner = w
                        if w == "X" then playerScore = playerScore + 1
                        elseif w == "O" then aiScore = aiScore + 1
                        end
                        state = "roundEnd"
                    end
                end
            end
        end
    end
end

---Input---
function love.mousepressed(mx, my, btn)
    if btn ~= 1 then return end

    ---Menu---
    if state == "menu" then
        -- Difficulty buttons
        if btnHit(mx,my, W/2-120, 285, 110, 44) then
            difficulty = "easy"
        end
        if btnHit(mx,my, W/2+10,  285, 110, 44) then
            difficulty = "hard"
        end

        -- Start Game button
        if btnHit(mx,my, W/2-100, 355, 200, 48) then
            playerScore, aiScore, round = 0, 0, 0
            round = 1
            startRound()
        end
    end

    ---Playing---
    if state == "playing" and not aiThinking then
        local r,c = cellAt(mx,my)
        if r and not board[r][c] then
            board[r][c] = "X"
            local w, wc = checkWinner(board)
            if w then
                winCells    = wc
                roundWinner = w
                if w == "X" then playerScore = playerScore + 1
                elseif w == "O" then aiScore = aiScore + 1
                end
                state = "roundEnd"
            else
                aiThinking = true
                aiTimer    = 0
            end
        end
    end

    ---Round End---
    if state == "roundEnd" then
        if btnHit(mx,my, W/2-110, H-110, 220, 48) then
            if round >= MAX_ROUNDS then
                state = "gameEnd"
            else
                round = round + 1
                startRound()
            end
        end
    end

--- Game End ---
    if state == "gameEnd" then
        if btnHit(mx,my, W/2-110, H-110, 220, 48) then
            state = "menu"
        end
    end
end

 ---Draw---
local function drawBackground()
    love.graphics.setColor(C.bg)
    love.graphics.rectangle("fill", 0, 0, W, H)
end

local function drawGrid()
    love.graphics.setColor(C.grid)
    love.graphics.setLineWidth(4)
    for i = 1, 2 do
        -- vertical
        love.graphics.line(GRID_X + i*CELL, GRID_Y,
                           GRID_X + i*CELL, GRID_Y + 3*CELL)
        -- horizontal
        love.graphics.line(GRID_X,          GRID_Y + i*CELL,
                           GRID_X + 3*CELL, GRID_Y + i*CELL)
    end
    love.graphics.setLineWidth(1)
end

local function drawSymbols()
    love.graphics.setFont(fnt.sym)
    for r = 1,3 do for c = 1,3 do
        local v = board[r][c]
        if v then
            local x,y = cellRect(r,c)
            love.graphics.setColor(v=="X" and C.X or C.O)
            love.graphics.printf(v, x, y + CELL/2 - fnt.sym:getHeight()/2, CELL, "center")
        end
    end end
end

local function drawHover()
    if not hoverCell then return end
    local r,c = hoverCell[1], hoverCell[2]
    local x,y = cellRect(r,c)
    love.graphics.setColor(C.cellHover)
    love.graphics.rectangle("fill", x+2, y+2, CELL-4, CELL-4, 6,6)
end

local function drawWinLine()
    if not winCells or winCells == true then return end
    local a,b2,c = winCells[1], winCells[2], winCells[3]
    local function mid(cell)
        local cx,cy = cellRect(cell[1], cell[2])
        return cx + CELL/2, cy + CELL/2
    end
    local x1,y1 = mid(a)
    local x2,y2 = mid(c)
    love.graphics.setColor(C.winLine)
    love.graphics.setLineWidth(7)
    love.graphics.line(x1,y1, x2,y2)
    love.graphics.setLineWidth(1)
end

local function drawScoreBar()
    -- top panel
    love.graphics.setColor(C.panel)
    love.graphics.rectangle("fill", 0, 0, W, 50)
    love.graphics.setFont(fnt.med)
    love.graphics.setColor(C.white)
    love.graphics.printf("Round "..round.." / "..MAX_ROUNDS, 0, 14, W, "center")

    ---difficulty badge---
    local badge = difficulty == "easy" and "EASY" or "HARD"
    local badgeCol = difficulty == "easy" and C.btnSel or {0.80, 0.22, 0.22}
    love.graphics.setColor(badgeCol)
    love.graphics.rectangle("fill", W - 80, 10, 68, 28, 6, 6)
    love.graphics.setColor(C.white)
    love.graphics.setFont(fnt.small)
    love.graphics.printf(badge, W - 80, 18, 68, "center")

    -- side scores
    love.graphics.setColor(C.X)
    love.graphics.setFont(fnt.large)
    love.graphics.printf("Player\n"..playerScore, 0, 55, W/2 - 10, "right")
    love.graphics.setColor(C.O)
    love.graphics.printf("AI\n"..aiScore, W/2+10, 55, W/2-10, "left")
end

function love.draw()
    drawBackground()

    ---Menu---
    if state == "menu" then
        love.graphics.setFont(fnt.title)
        love.graphics.setColor(C.white)
        love.graphics.printf("Tic Tac Toe", 0, 80, W, "center")

        love.graphics.setFont(fnt.med)
        love.graphics.setColor(C.yellow)
        love.graphics.printf("You are  X  |  AI is  O", 0, 165, W, "center")
        love.graphics.printf("Welcome to Tic tac toe", 0, 198, W, "center")

        -- Difficulty label
        love.graphics.setFont(fnt.med)
        love.graphics.setColor(C.white)
        love.graphics.printf("Select Difficulty", 0, 248, W, "center")

        local mx,my = love.mouse.getPosition()

        -- Easy button  (left of centre)
        drawButton("Easy",
            W/2-120, 285, 110, 44,
            btnHit(mx,my, W/2-120, 285, 110, 44),
            difficulty == "easy")

        -- Hard button  (right of centre)
        drawButton("Hard",
            W/2+10, 285, 110, 44,
            btnHit(mx,my, W/2+10, 285, 110, 44),
            difficulty == "hard")

        -- Start button
        drawButton("Start Game", W/2-100, 355, 200, 48,
            btnHit(mx,my, W/2-100, 355, 200, 48))

        love.graphics.setFont(fnt.small)
        love.graphics.setColor(C.white)
        return
    end

    ---Playing---
    if state == "playing" then
        drawScoreBar()
        drawHover()
        drawGrid()
        drawSymbols()

        love.graphics.setFont(fnt.small)
        love.graphics.setColor(C.white)
        if aiThinking then
            love.graphics.printf("AI is thinking…", 0, GRID_Y + 3*CELL + 18, W, "center")
        else
            love.graphics.printf("Your turn – click a square", 0, GRID_Y + 3*CELL + 18, W, "center")
        end
        return
    end

    ---Round End---
    if state == "roundEnd" then
        drawScoreBar()
        drawGrid()
        drawSymbols()
        drawWinLine()

        -- semi-transparent overlay panel
        love.graphics.setColor(0, 0, 0, 0.52)
        love.graphics.rectangle("fill", 60, GRID_Y + 3*CELL + 8, W-120, 120, 10,10)

        love.graphics.setFont(fnt.large)
        local msg
        if roundWinner == "X" then
            love.graphics.setColor(C.X)
            msg = "You win this round!"
        elseif roundWinner == "O" then
            love.graphics.setColor(C.O)
            msg = "AI wins this round!"
        else
            love.graphics.setColor(C.yellow)
            msg = "It's a Draw!"
        end
        love.graphics.printf(msg, 60, GRID_Y + 3*CELL + 18, W-120, "center")

        love.graphics.setFont(fnt.med)
        love.graphics.setColor(C.white)
        local sub = string.format("Score  —  Player: %d   AI: %d", playerScore, aiScore)
        love.graphics.printf(sub, 60, GRID_Y + 3*CELL + 62, W-120, "center")

        -- Next / Finish button
        local mx,my = love.mouse.getPosition()
        local btnLbl = (round >= MAX_ROUNDS) and "See Final Score" or "Next Round  ›"
        drawButton(btnLbl, W/2-110, H-110, 220, 48,
            btnHit(mx,my, W/2-110, H-110, 220, 48))
        return
    end

    ---Game End---
    if state == "gameEnd" then
        love.graphics.setFont(fnt.title)
        love.graphics.setColor(C.white)
        love.graphics.printf("Game Over!", 0, 80, W, "center")

        -- result panel
        love.graphics.setColor(C.panel)
        love.graphics.rectangle("fill", 80, 170, W-160, 220, 14,14)

        love.graphics.setFont(fnt.large)
        love.graphics.setColor(C.white)
        love.graphics.printf("Final Score", 80, 188, W-160, "center")

        love.graphics.setFont(fnt.sym)
        love.graphics.setColor(C.X)
        love.graphics.printf(tostring(playerScore), 80, 230, (W-160)/2, "center")
        love.graphics.setColor(C.O)
        love.graphics.printf(tostring(aiScore), 80 + (W-160)/2, 230, (W-160)/2, "center")

        love.graphics.setFont(fnt.med)
        love.graphics.setColor(C.white)
        love.graphics.printf("Player  (X)", 80, 320, (W-160)/2, "center")
        love.graphics.printf("AI  (O)",     80+(W-160)/2, 320, (W-160)/2, "center")

        -- winner announcement
        love.graphics.setFont(fnt.large)
        local verdict, vc
        if playerScore > aiScore then
            verdict, vc = "You Win!", C.X
        elseif aiScore > playerScore then
            verdict, vc = "AI Wins!", C.O
        else
            verdict, vc = "It's a Tie!", C.yellow
        end
        love.graphics.setColor(vc)
        love.graphics.printf(verdict, 0, 410, W, "center")

        local mx,my = love.mouse.getPosition()
        drawButton("Back to Main Menu", W/2-110, H-110, 220, 48,
            btnHit(mx,my, W/2-110, H-110, 220, 48))
    end
end
