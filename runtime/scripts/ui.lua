-- UI Module

local ui = {}
local ffi = require 'ffi'
local debugger = require 'debugger'
local helpers = require 'helpers'
local core = require 'core'
local SDL =   require 'sdlkeys'
local bit = require 'bit'
local lexer = require 'lexer'

ffi.cdef
[[
    void ui_drawNode(float x, float y, float w, float h, int widget_state, const char* title, char r, char g, char b, char a);
    void ui_drawPort(float x, float y, int widget_state, char r, char g, char b, char a);
    void ui_drawWire(float px, float py, float qx, float qy, int start_state, int end_state);
    void ui_dbgTextPrintf(int y, const char *str);
    uint8_t ui_getKeyboardState(uint16_t key);
    void ui_warpMouseInWindow(int x, int y);
    void ui_saveNVGState();
    void ui_restoreNVG();
    void ui_setTextProperties(const char* font, float size, int align);
    void ui_setTextColor(int r, int g, int b, int a);
    void ui_drawText(float x, float y, const char* str);
]]

local C = ffi.C

ui.drawNode = ffi.C.ui_drawNode
ui.drawPort = ffi.C.ui_drawPort
ui.dbgText = ffi.C.ui_dbgTextPrintf
ui.drawWire = ffi.C.ui_drawWire
ui.getKeyboardState = ffi.C.ui_getKeyboardState
ui.warpMouse = ffi.C.ui_warpMouseInWindow

local BNDWidgetState = { Default = 0, Hover = 1, Active = 2 }

function ui.createNode(id, x, y, w, h, module, submodule, constant_inputs)
    local node = {}
    node.sx = x
    node.sy = y
    node.w = w
    node.h = h
    node.id = id
    node.bndWidgetState = BNDWidgetState.Default
    node.constants = {}
    node.connections = {}
    node.ports = {}
    node.xform_name = module .. "/" .. submodule
    node.xform = core.cloneTransform(node, lexer.getTransform(module,submodule))
    if constant_inputs then
        for input_name, constant in pairs(constant_inputs) do
            node.constants[input_name] = constant
        end
    end

    -- Calculate input port locations
    local i = 1
    local input_cnt = helpers.tableLength(node.xform.inputs)
    for input_name, input in pairs(node.xform.inputs) do
        local port = { name = input_name, type = input.type }
        port.x = (1/(input_cnt+1)) * i
        port.y = 0.85
        port.bndWidgetState = BNDWidgetState.Default
        port.is_input = true
        port.is_output = false
        node.ports[input_name] = port
        i = i+1
    end

    -- Calculate output port locations
    i = 1
    local output_cnt = helpers.tableLength(node.xform.outputs)
    for output_name, output in pairs(node.xform.outputs) do
        local port = { name = output_name, type = output.type}
        port.x = (1/(output_cnt+1)) * i
        port.y = 0.2
        port.bndWidgetState = BNDWidgetState.Default
        port.is_input = false
        port.is_output = true
        node.ports[output_name] = port
        i = i+1
    end

    core.nodes[id] = node
    --table.insert(core.nodes, node)
    return node
end

function ui.shutdown()
end

local function drawNode(node)
    ui.drawNode(node.x, node.y, node.w, node.h, node.bndWidgetState, node.xform.dispname, 255, 50, 100, 255)
    for name, port in pairs(node.ports) do
        if port.is_input then
            ui.drawPort(node.x + port.x * node.w, node.y + port.y * node.h, port.bndWidgetState, 0, 100, 255, 255)
        else
            ui.drawPort(node.x + port.x * node.w, node.y + port.y * node.h, port.bndWidgetState, 0, 255, 100, 255)
        end
    end
    -- Draw the input connections
    for inport_name, connection in pairs(node.connections) do
        local node_in = node
        local node_out = core.nodes[connection.out_node_id]
        local port_in = node.ports[inport_name]
        local port_out = node_out.ports[connection.port_name]
        local node_inx = node_in.x + port_in.x * node_in.w
        local node_iny = node_in.y + port_in.y * node_in.h
        local node_outx = node_out.x + port_out.x * node_out.w
        local node_outy = node_out.y + port_out.y * node_out.h
        if node_inx < node_outx then
        ui.drawWire(node_inx,
                    node_iny,
                    node_outx,
                    node_outy,
                    BNDWidgetState.Active, BNDWidgetState.Active)
        else
        ui.drawWire(node_outx,
                    node_outy,
                    node_inx,
                    node_iny,
                    BNDWidgetState.Active, BNDWidgetState.Active)
        end
    end
end

local function max(a,b)
    if a > b then
        return a
    end
    return b
end

local zooming = {
    -- Center x,y
    cx = 0,
    cy = 0,
    zoom = 1,
    aspect = 1600 / 900
}
function ui.drawNodes()
    -- Wiggle
    -- for _k, node in pairs(core.nodes) do
        -- node.w = (math.sin(g_time * 2) + 1.0) * zooming.aspect * 40 + 160
        -- node.h = (math.sin(g_time * 2) + 1.0) / zooming.aspect * 10 + 60
    -- end
    for _k, node in pairs(core.nodes) do
         if node then
           drawNode(node)
        end
    end
end

local function pt_pt_dist2(px, py, qx, qy)
    local dx = px-qx
    local dy = py-qy
    return dx*dx + dy*dy
end
local function pt_aabb_test(minx, miny, w, h, px, py)
    if minx < px and px < minx + w and miny < py and py < miny + h then
        return true
    end
    return false
end
local function pt_aabb_relative(minx, miny, w, h, px, py)
    return (px - minx) / w, (py - miny) / h
end

local function ports_pt_intersect(node, px, py)
    local isect = nil
    local radius = 0.006
    for _k, port in pairs(node.ports) do
        local dist2 = pt_pt_dist2(px, py, port.x, port.y)
        if dist2 < radius then
            port.bndWidgetState = BNDWidgetState.Hover
            isect = port
        else
            port.bndWidgetState = BNDWidgetState.Default
        end
    end
    return isect
end

local function nodes_pt_intersect(px, py)
    local isect = nil
    for _k, node in pairs(core.nodes) do
        insideAABB = pt_aabb_test(node.x, node.y, node.w, node.h, px, py)
        if insideAABB and not isect then
            node.bndWidgetState = BNDWidgetState.Hover
            isect = node
        else
            node.bndWidgetState = BNDWidgetState.Default
        end
    end
    return isect
end

-- Holds data for dragging
local MouseDrag =
{
    mx = nil,       -- To calculate total delta vector
    my = nil,
    anchorx = {},  -- Starting(Anchor) point of the node before dragging, new_pos = anchor + delta
    anchory = {},
}
local HoveredNode
local SelectedNodes = {}

-- States
local MouseX, MouseY
local IHoldLCTRL
local IPressLMB, IHoldLMB, IReleaseLMB
local IPressRMB, IHoldRMB, IReleaseRMB
local DraggingNodes, DraggingConnectors, DraggingWorkspace
local IPressEnter
local IPressHome
local IPressTab
local IHoldLShift

function ui.start()
    MouseX, MouseY = g_mouseState.mx, g_mouseState.my
    IPressLMB = g_mouseState.left == KeyEvent.Press
    IPressRMB = g_mouseState.right == KeyEvent.Press
    IReleaseRMB = g_mouseState.right == KeyEvent.Release
    IReleaseLMB = g_mouseState.left == KeyEvent.Release
    IHoldLMB = g_mouseState.left == KeyEvent.Hold
    IHoldRMB = g_mouseState.right == KeyEvent.Hold
    IPressEnter = ui.getKeyboardState(SDL.Key.RETURN) == KeyEvent.Press
    IPressHome = ui.getKeyboardState(SDL.Key.HOME) == KeyEvent.Press
    IPressTab  = ui.getKeyboardState(SDL.Key.TAB) == KeyEvent.Press
    IHoldLCTRL = ui.getKeyboardState(SDL.Key.LCTRL) == KeyEvent.Hold
    IHoldLShift  = ui.getKeyboardState(SDL.Key.LSHIFT) == KeyEvent.Hold
end

local InputNode, OutputNode, InputPort, OutputPort
local PortStart, PortEnd, NodeStart, NodeEnd

function ui.DragConnectors()
    local MouseOnPort = PortStart

    local Types = { Float = 0, Integer = 1, String = 2, VecN = 3, Other = 4}
    local GeneraliseType = function(Type)
        if Type == 'f16' or Type == 'f32' or Type == 'f64' then
            return Types.Float
        elseif Type == 'i8' or Type == 'i16' or Type == 'i32' or Type == 'i64' or  Type == 'u8' or Type == 'u16' or Type == 'u32' or Type == 'u64' then
            return Types.Float
        elseif Type == 'str' then
            return Types.String
        elseif Type == 'vec2' or Type == 'vec3' or Type == 'vec4' then
            return Types.VecN
        else
            return Types.Other
        end
    end
    local PortTypesMatch = function (TypeA, TypeB)
        local GenA = GeneraliseType(TypeA)
        local GenB = GeneraliseType(TypeB)
        if GenA == Types.Other or GenB == Types.Other then
            return TypeA == TypeB
        elseif GenA == GenB then
            return true
        else
            return false
        end
    end

    local FindConnection = function ()
        local relx, rely = pt_aabb_relative(HoveredNode.x, HoveredNode.y, HoveredNode.w, HoveredNode.h, MouseX, MouseY)
        -- not drag_connector ==> node_from == nil
        -- drag_connector ==> node_from ~= nil
        if not HoveredNode then
            return
        end

        -- If not dragging connectors, cache the node/port tuple
        if not DraggingConnectors then
            NodeStart = HoveredNode
            PortStart = ports_pt_intersect(HoveredNode, relx, rely)
            if PortStart and PortStart.is_input then
                InputNode = NodeStart
                InputPort = PortStart
            end
        else
            NodeEnd = HoveredNode
            PortEnd = ports_pt_intersect(HoveredNode, relx, rely)
            if InputPort then
                OutputNode = NodeEnd
                OutputPort = PortEnd
            else
                OutputNode = NodeStart
                OutputPort = PortStart
                InputNode = NodeEnd
                InputPort = PortEnd
            end
        end
    end

    local StartDraggingConnector = function ()
        MouseDrag.mx = MouseX
        MouseDrag.my = MouseY
        MouseDrag.canchorx = NodeStart.x + NodeStart.w * PortStart.x
        MouseDrag.canchory = NodeStart.y + NodeStart.h * PortStart.y
        DraggingConnectors = true
    end
    local StopDraggingConnector = function ()
        DraggingConnectors = false
        DraggingExistingConnection = false
        NodeStart = nil
        PortStart = nil
        NodeEnd = nil
        PortEnd = nil
    end
    local DragExistingConnection = function ()
        -- If it is an input port and a binding exists
        if NodeStart.connections[PortStart.name] then
            debugger.print("Dragging existing conn")
            DraggingExistingConnection = true
            -- Then, it is as if we're dragging from that OutputNode's output
            OutputNode = core.nodes[InputNode.connections[InputPort.name].out_node_id]
            OutputPort = OutputNode.ports[InputNode.connections[InputPort.name].port_name]
            -- New NodeStart is the input NodeStart's connection node
            NodeStart = OutputNode
            PortStart = OutputPort
            InputNode.connections[InputPort.name] = nil
        end
    end
    local CreateConnection = function ()
        if not (NodeStart == NodeEnd) and not (PortStart.is_input == PortEnd.is_input) then
            -- Lets connect those ports = Make the xform input/output connections
            InputNode, OutputNode = NodeStart, NodeEnd
            InputPort, OutputPort = PortStart, PortEnd
            -- Swap inputs if PortEnd is an input
            if PortEnd.is_input then
                InputNode, OutputNode = NodeEnd, NodeStart
                InputPort, OutputPort = PortEnd, PortStart
            end
            --if PortTypesMatch(InputPort.type, OutputPort.type) then
                -- Connect the port that is an input of a node to the output port
                InputNode.connections[InputPort.name] = {out_node_id = OutputNode.id, port_name = OutputPort.name}
                C.nw_send("UpdateConn " .. InputNode.id .. " " .. InputPort.name .. " " .. tostring(OutputNode.id) .. " " .. OutputPort.name)
            --end
        end
    end

    if not DraggingNodes and HoveredNode then
        FindConnection()
    end
    if IPressLMB and MouseOnPort and HoveredNode then
        DragExistingConnection()
        StartDraggingConnector()
    end

    if IHoldLMB and DraggingConnectors then
        if MouseDrag.canchorx < MouseX then
            ui.drawWire(MouseDrag.canchorx, MouseDrag.canchory, MouseX, MouseY, BNDWidgetState.Active, BNDWidgetState.Active)
        else
            ui.drawWire(MouseX, MouseY, MouseDrag.canchorx, MouseDrag.canchory, BNDWidgetState.Active, BNDWidgetState.Active)
        end
    end

    if IReleaseLMB and DraggingConnectors then
        if NodeEnd and PortEnd then
            CreateConnection()
        elseif DraggingExistingConnection then
            C.nw_send("DeleteConn " .. tostring(InputNode.id) .. " " .. InputPort.name)
        end
        StopDraggingConnector()
    end
end

local function SearchInSelectedNodes(snode)
    for i, node in ipairs(SelectedNodes) do
        if node == snode then
            return i
        end
    end
    return nil
end

local function FindHoveredNode(MouseX, MouseY)
    return nodes_pt_intersect(MouseX, MouseY)
end

function ui.SelectNodes()
    -- This is the behaviour expected for holding CTRL, can override
    local SelectNodeCTRL = function ()
        FoundNode = SearchInSelectedNodes(HoveredNode)
        if FoundNode then
            table.remove(SelectedNodes, FoundNode)
        else
            table.insert(SelectedNodes, HoveredNode)
        end
    end

    local SelectNodeWithoutCTRL = function ()
        FoundNode = SearchInSelectedNodes(HoveredNode)
        if not FoundNode then
            SelectedNodes = {HoveredNode}
        end
    end

    if not DraggingNodes then
        HoveredNode = FindHoveredNode(MouseX, MouseY)
    end

    if IPressLMB and HoveredNode then
        if IHoldLCTRL then
            SelectNodeCTRL()
        elseif #SelectedNodes <= 1 then
            SelectNodeWithoutCTRL()
        end
    end

    if IPressLMB and not HoveredNode then
        SelectedNodes = {}
    end

    -- This behavior is for handling the CTRL
    if IReleaseLMB and HoveredNode then
        SelectNodeWithoutCTRL()
    end

    for i, node in ipairs(SelectedNodes) do
        node.bndWidgetState = BNDWidgetState.Active
    end
    return SelectedNodes
end

function ui.DragNodes()
    -- States
    local HoveredNodeAlreadySelected = SearchInSelectedNodes(HoveredNode)
    local HoveringAPort = not not(PortStart or PortEnd)

    -- Functional blocks
    local StartDraggingNodes = function ()
        MouseDrag.mx = MouseX
        MouseDrag.my = MouseY
        DraggingNodes = true
        for i, node in ipairs(SelectedNodes) do
            MouseDrag.anchorx[i] = node.sx
            MouseDrag.anchory[i] = node.sy
        end
    end

    local DragDaNodes = function ()
        for i, node in ipairs(SelectedNodes) do
            node.sx = MouseDrag.anchorx[i] + (MouseX - MouseDrag.mx) / zooming.zoom
            node.sy = MouseDrag.anchory[i] + (MouseY - MouseDrag.my) / zooming.zoom
            node.bndWidgetState = BNDWidgetState.Active
        end
    end

    local StopDraggingNodes = function ()
        for i, node in ipairs(SelectedNodes) do
            C.nw_send("UpdateNodePos " .. tostring(node.id) .. " " .. tostring(node.sx) .. " " .. tostring(node.sy))
        end
        DraggingNodes = false
    end

    -- Behavior description
    if IPressLMB and HoveredNodeAlreadySelected and not HoveringAPort then
        StartDraggingNodes()
    end

    if IHoldLMB and DraggingNodes then
        DragDaNodes()
    end

    if IReleaseLMB then
        StopDraggingNodes()
    end
end

function ui.getSelectedNodes()
    return SelectedNodes
end

function ui.drawWorkspace()
    local x, y = 2, 0

    C.ui_setTextProperties("header-bold", 25, 9)
    C.ui_setTextColor(255, 255, 255, 200)
    C.ui_drawText(x, y, g_statusMsg)
    C.ui_setTextProperties("header", 25, 9)
    y = y + 28

    if g_errorMsg then
        C.ui_drawText(x, y, g_errorMsg)
    end
end

local SelectedInput = 1

function ui.drawNodeInfo(node, y)
    if not current_node then
        return
    end
    local w, h= 1600, 900
    local x, y = 2, 80
    local header_size = 30
    local param_size = 22
    local align = 1
    local input_cnt = helpers.tableLength(current_node.xform.inputs)
    local output_cnt = helpers.tableLength(current_node.xform.outputs)
    C.ui_setTextProperties("header-bold", header_size, align)
    C.ui_setTextColor(255, 255, 255, 50)
    C.ui_drawText(x, y, "Inputs")
    y = y + param_size

    C.ui_setTextColor(255, 255, 255, 255)
    local _i = 1
    for name, input in pairs(node.xform.input_values) do
        connection = node.connections[name]
        if _i == SelectedInput then
            C.ui_setTextColor(255, 150, 100, 255)
        else
            C.ui_setTextColor(255, 255, 255, 255)
        end
        C.ui_setTextProperties("header-bold", param_size, align)
        C.ui_drawText(x, y, name)
        y = y + param_size
        C.ui_setTextProperties("header", param_size - 2, align)
        if not connection then
            C.ui_drawText(x, y, tostring(node.constants[name]))
        else
            C.ui_drawText(x, y, tostring(core.nodes[connection.out_node_id].xform.output_values[connection.port_name]))
        end
        y = y + param_size
        _i = _i + 1
    end

    C.ui_setTextProperties("header-bold", header_size, align)
    C.ui_setTextColor(255, 255, 255, 50)
    C.ui_drawText(x, y, "Outputs")
    y = y + param_size

    C.ui_setTextColor(255, 255, 255, 255)
    for name, output in pairs(node.xform.output_values) do
        C.ui_setTextProperties("header-bold", param_size, align)
        C.ui_drawText(x, y, name)
        y = y + param_size
        C.ui_setTextProperties("header", param_size - 2, align)
        C.ui_drawText(x, y, tostring(output))
        y = y + param_size
    end
end

function ui.dragWorkspace()
    local ZoomIn = function ()
        zooming.zoom = zooming.zoom + 0.01
    end

    local ZoomOut = function ()
        zooming.zoom = zooming.zoom - 0.01
    end

    local StartDraggingWorkspace = function (CenterX, CenterY)
        DraggingWorkspace = true
        MouseDrag.mx = g_mouseState.mx
        MouseDrag.my = g_mouseState.my
        MouseDrag.wanchorx = CenterX
        MouseDrag.wanchory = CenterY
    end

    local DragWorkspace = function ()
        zooming.cx = MouseDrag.wanchorx + (MouseDrag.mx - g_mouseState.mx) / zooming.zoom
        zooming.cy = MouseDrag.wanchory + (MouseDrag.my - g_mouseState.my) / zooming.zoom
    end

    local StopDraggingWorkspace = function ()
        DraggingWorkspace = false
    end

    local UpdateNodePositions = function (CenterX, CenterY, ZoomAmount)
        for _k, node in pairs(core.nodes) do
            node.x = (-CenterX + node.sx) * ZoomAmount
            node.y = (-CenterY + node.sy) * ZoomAmount
            node.w = 180 * ZoomAmount
            node.h = 40 * ZoomAmount
        end
    end

    local IHoldPageUp = ui.getKeyboardState(SDL.Key.PAGEUP) == KeyEvent.Hold
    local IHoldPageDown = ui.getKeyboardState(SDL.Key.PAGEDOWN) == KeyEvent.Hold

    if IHoldPageUp then
        ZoomIn()
    elseif IHoldPageDown then
        ZoomOut()
    end

    local CenterX = zooming.cx
    local CenterY = zooming.cy
    local ZoomAmount = zooming.zoom -- [1,2]

    UpdateNodePositions(CenterX, CenterY, ZoomAmount)

    if IPressRMB and not (DraggingNodes or DraggingConnector) then
        StartDraggingWorkspace(CenterX, CenterY)
    end

    if IHoldRMB and DraggingWorkspace then
        DragWorkspace()
    end

    if IReleaseRMB then
        StopDraggingWorkspace()
    end
end

local EnteringCommands = false

function ui.Proceed(CurrentNode)
    local StartEnteringCommands = function ()
        EnteringCommands = true
    end
    local ToggleEnteringCommands = function ()
        EnteringCommands = not EnteringCommands
    end
    local ToggleTransformList = function ()
        ShowTransformList = not ShowTransformList
    end
    local ProcessCommand = function(CommandName, CommandParameters)
        if     CommandName == 'c' then
            ui.createNode(MouseX, MouseY, CommandParameters[1], CommandParameters[2])
        elseif CommandName == 'h' or CommandName == 'help' then
            ToggleTransformList()
        end
    end
    local DrawTheModuleName = function (x, y)
        C.ui_setTextProperties("header-bold", 25, 9)
        C.ui_setTextColor(255, 255, 255, 200)
        C.ui_drawText(x, y, "Core")
    end
    local DrawTheTransformNames = function (x, y, module)
        C.ui_setTextProperties("header", 20, 9)
        C.ui_setTextColor(255, 255, 255, 150)
        for name, xform in pairs(module) do
            local head, tail = string.find(name, "_xform")
            if head then
                C.ui_drawText(x, y, name)
                y = y + 20
            end
        end
    end
    local LetsDrawTheTransformList = function(x, y)
        DrawTheModuleName(x, y)
        y = y + 20
        DrawTheTransformNames(x, y, core)
    end
    local SelectNextInput = function (CurrentNode)
        SelectedInput = ((SelectedInput) % helpers.tableLength(CurrentNode.xform.inputs)) + 1
    end
    local SelectPrevInput = function (CurrentNode)
        if SelectedInput == 1 then
            SelectedInput = helpers.tableLength(CurrentNode.xform.inputs)
        else
            SelectedInput = SelectedInput - 1
        end
    end

    if IPressEnter and not EnteringCommands then
        StartEnteringCommands()
    elseif IPressEnter and EnteringCommands then
        ProcessCommand(CommandName, CommandParameters)
    end

    if IPressHome then
        ToggleTransformList()
    end

    if ShowTransformList then
        LetsDrawTheTransformList(1400, 0)
    end

    if IPressTab then
        if IHoldLShift then
            SelectPrevInput(CurrentNode)
        else
            SelectNextInput(CurrentNode)
        end
    end
end

ui.EditingText = false
ui.ForwardedText = ""
ui.EnteredText = ""
local function StopEditing()
    ui.EditingText = false
    ui.ForwardedText = ""
end
function ui.EditText()
    if (ui.getKeyboardState(SDL.Key.RETURN) == KeyEvent.Press) and ui.EditingText then
        ui.EnterText()
    elseif (ui.getKeyboardState(SDL.Key.RETURN) == KeyEvent.Press) and not ui.EditingText then
        ui.EditingText = true
    end
    if (ui.getKeyboardState(SDL.Key.ESCAPE) == KeyEvent.Press) and ui.EditingText then
        StopEditing()
    end
    if (ui.getKeyboardState(SDL.Key.BACKSPACE) == KeyEvent.Press) and ui.EditingText then
        ui.ForwardedText = string.sub(ui.ForwardedText, 1, -2)
    end
    if ui.EditingText then
        C.ui_drawText(0, 30, "!cmd: " .. ui.ForwardedText)
    end
end

local function CreateNodeReq(args)
    if not args or #args < 1 then
        return
    end
    local xform = args[1]
    cmp = helpers.split(xform, '/')
    local module, submodule = cmp[1], cmp[2]
    local xformTable = lexer.getTransform(module, submodule)
    if not xformTable then
        return
    end
    req = "CreateNode " .. table.concat({g_mouseState.mx, g_mouseState.my, 180, 90,  xform, xformTable.name}, " ")
    if #args > 1 then
        req = req .. " " .. table.concat(args, " ")
    end
    C.nw_send(req)
end

local CmdMap = {
    cn = CreateNodeReq
}

function ui.KeyboardControls(selected_nodes)
    if (ui.getKeyboardState(SDL.Key.DELETE) == KeyEvent.Press) and selected_nodes then
        for idx, node in ipairs(selected_nodes) do
            C.nw_send("DeleteNode " .. tostring(node.id))
        end
    end
end

function ui.EnterText()
   args = helpers.SplitWhitespace(ui.ForwardedText)
   cmd = args[1]
   table.remove(args, 1)
   if CmdMap[cmd] then
       CmdMap[cmd](args)
   end
   StopEditing()
end

function portTextEdit(text)
    if ui.EditingText then
            ui.ForwardedText = ui.ForwardedText .. text
    end
end

return ui
