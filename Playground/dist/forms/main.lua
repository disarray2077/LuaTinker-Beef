-- A checklist built with native BeefForms controls and Lua event handlers.
Forms.UseBackend(Forms.ApplicationBackend.SDL2OpenGL)
Forms.EnableVisualStyles()

local form = Forms.Form()
local tasks = {}
local frames = 0

local function run()
    form.Text = "Checklist — LuaTinker + BeefForms"
    form.ClientSize = Forms.Size(640, 480)
    form.MinimumSize = Forms.Size(420, 320)

    local heading = Forms.Label()
    heading.Text = "What would you like to get done?"
    heading.Location = Forms.Point(20, 18)
    heading.Size = Forms.Size(600, 24)
    form.Controls:Add(give_ownership(heading))

    local input = Forms.TextBox()
    input.Location = Forms.Point(20, 52)
    input.Size = Forms.Size(488, 28)
    input.Anchor = Forms.AnchorStyles.Top | Forms.AnchorStyles.Left | Forms.AnchorStyles.Right
    form.Controls:Add(give_ownership(input))

    local add = Forms.Button()
    add.Text = "Add task"
    add.Location = Forms.Point(520, 50)
    add.Size = Forms.Size(100, 30)
    add.Anchor = Forms.AnchorStyles.Top | Forms.AnchorStyles.Right
    add.Enabled = false
    form.Controls:Add(give_ownership(add))

    local list = Forms.TableLayoutPanel()
    list.Location = Forms.Point(20, 96)
    list.Size = Forms.Size(600, 304)
    list.Anchor = Forms.AnchorStyles.Top | Forms.AnchorStyles.Bottom | Forms.AnchorStyles.Left | Forms.AnchorStyles.Right
    list.BorderStyle = Forms.BorderStyle.FixedSingle
    list.AutoScroll = true
    list.ColumnCount = 1
    list.ColumnStyles:Add(Forms.ColumnStyle(Forms.SizeType.Percent, 100))
    form.Controls:Add(give_ownership(list))

    local summary = Forms.Label()
    summary.Location = Forms.Point(20, 424)
    summary.Size = Forms.Size(360, 24)
    summary.Anchor = Forms.AnchorStyles.Bottom | Forms.AnchorStyles.Left
    form.Controls:Add(give_ownership(summary))

    local clear = Forms.Button()
    clear.Text = "Clear completed"
    clear.Location = Forms.Point(460, 418)
    clear.Size = Forms.Size(160, 32)
    clear.Anchor = Forms.AnchorStyles.Bottom | Forms.AnchorStyles.Right
    form.Controls:Add(give_ownership(clear))

    local function refresh()
        local completed = 0
        for _, task in ipairs(tasks) do
            if task.Checked then
                completed = completed + 1
            end
        end
        summary.Text = string.format("%d of %d tasks complete", completed, #tasks)
        clear.Enabled = completed > 0
    end

    local function addTask(text)
        local task = Forms.CheckBox()
        task.Text = text
        task.Size = Forms.Size(0, 34)
        task.Anchor = Forms.AnchorStyles.Top | Forms.AnchorStyles.Left | Forms.AnchorStyles.Right
        list.Controls:Add(give_ownership(task))
        task.CheckedChanged:Add(function() refresh() end)
        tasks[#tasks + 1] = task
        refresh()
    end

    input.TextChanged:Add(function()
        add.Enabled = input.Text:match("%S") ~= nil
    end)

    add.Click:Add(function()
        local text = input.Text:match("^%s*(.-)%s*$")
        if text == "" then
            return
        end
        addTask(text)
        input.Text = ""
        input:Focus()
    end)

    clear.Click:Add(function()
        for index = #tasks, 1, -1 do
            local task = tasks[index]
            if task.Checked then
                task.CheckedChanged:Dispose()
                list.Controls:Remove(task)
                take_ownership(task)
                table.remove(tasks, index)
            end
        end
        refresh()
    end)

    addTask("Try adding your own task")
    addTask("Check a task to mark it complete")
    addTask("Resize the window to see native anchoring")

    form:Show()
    input:Focus()

    local maxFrames = tonumber(os.getenv("PLAYGROUND_MAX_FRAMES"))
    while form.IsHandleCreated and (not maxFrames or frames < maxFrames) do
        Forms.DoEvents()
        SDL.Delay(16)
        frames = frames + 1
    end
end

local ok, err = xpcall(run, debug.traceback)
form:Close()
form = nil
tasks = nil
collectgarbage("collect")

if not ok then
    error(err, 0)
end
