--[[

    Reliable Replicated States.

    Initialied upon first require,
    Must be initialized from both Client and Server.

    Create a state by
]]

export type State = {
    _variables: table,

    get: (self: State, key: string) -> (any),
    set: (self: State, key: string, variant: any) -> (boolean, any),
    properties: StateProperties
}

export type StateProperties = {
    id: string,
    replicated: boolean,
    clientReadOnly: boolean,
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RF = script.Events.RemoteFunction
local RE = script.Events.RemoteEvent

local Util = {}
function Util.hardCopy(tab: table, ignoreStrIndex: table?)
    local self = {}
    for i, v in pairs(tab) do
        if ignoreStrIndex and table.find(ignoreStrIndex, v) then
            continue
        end
        self[i] = v
    end
    return self
end

function Util.fireAllClientsExcept(remote, player, ...)
    for _, plr in ipairs(Players:GetPlayers()) do
        if player ~= plr then
            remote:FireClient(...)
        end
    end
end

--@class
local State = {}
State.__index = State

function State.new(properties, defaultVariables)
    local self = {}
    self = setmetatable(self, State) :: State
    self.new = nil
    if not properties.replicated then self.setAsync = nil end

    self._variables = defaultVariables and Util.hardCopy(defaultVariables) or {}
    self.properties = properties :: StateProperties
    return self
end

function State:get(key: string)
    return self._variables[key]
end

function State:set(key: string, new: any)
    if self.properties.replicated then
        if RunService:IsClient() then
            assert(not self.properties.clientReadOnly, "Client cannot edit StateVariable " .. tostring(key) .. "!")
            local success, response = pcall(function()
                return RF:InvokeServer("_stateSetAsync", self.properties.id, key, new)
            end)
            assert(success, response)
            return response
        else
            RE:FireAllClients("_stateSetAsync", self.properties.id, key, new)
        end
    end

    self._variables[key] = new
    return new
end

--@summary Set a Replicated State's Variable without replicating
function State:setAsync(key: string, new: any)
    self._variables[key] = new
    return new
end
--

--@module
local States = {}
States._cache = {storedStates = {}}

function States:Create(properties: StateProperties, defaultVar: table)
    if properties.replicated then
        if RunService:IsClient() then
            local success, response = RF:InvokeServer("_stateCreateAsync", properties, defaultVar)
            assert(success, response)
        else
            RE:FireAllClients("_stateCreateAsync", properties, defaultVar)
        end
    end

    return States:_stateCreateAsync(properties, defaultVar)
end

function States:Get(ID: string)
    return States._cache.storedStates[ID] or false
end

function States:_stateCreateAsync(properties, defaultVar)
    local _state = State.new(properties, defaultVar)
    States._cache.storedStates[properties.ID] = _state
    return _state
end

function States:_stateSetAsync(id, key, new)
    local success, result = pcall(function()
        return States:Get(id):set(key, new)
    end)
    if not success then error(result) end
    return result
end

function States:_getCurrentReplicated()
    local _st = {}
    for _, s in ipairs(States._cache.storedStates) do
        if s.properties.replicated then
            table.insert(_st, {s.properties, s.defaultVar})
        end
    end
end

--@run
if RunService:IsServer() then
    local function ServerInvoke(_, action, ...)
        assert(States[action], "Action " .. tostring(action) .. " not found")

        local _args, success, result
        _args, success, result = table.pack(...), pcall(function()
            return States[action](States, _args)
        end)

        assert(success, result)
        
        _args = nil
        return result
    end
    RF.OnServerInvoke = ServerInvoke
elseif RunService:IsClient() then
    RE.OnClientEvent:Connect(function(action, ...)
        if States[action] then
            States[action](States, ...)
        end
    end)

    local statesToCreate = RF:InvokeServer("_getCurrentReplicated")
    assert(statesToCreate, "Could not get current states!")
    for _, st in pairs(statesToCreate) do
        pcall(function()
            States:_stateCreateAsync(st[1], st[2])
        end)
    end
    statesToCreate = nil
end

return States