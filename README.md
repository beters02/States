# States

This project is a compact and efficient module designed for Roblox that manages replicated states.


## Example Usage

State created within Script A:
```lua
local stateProperties = {id = "TestState", replicated = true, clientReadOnly = false}
local stateVariables = {test = false}
local state = States:Create(stateProperties, stateVariables)
state:set("test", true)
```

State accessed from Script B:
```lua
local state = States:Get("TestState")
state:get("test") -- returns true
```



## API Reference

#### States Module

- **Create**
    - `States:Create(properties: StateProperties, defaultVar: table) -> State`
    - Creates a new state with specified properties and default variables.

- **Get**
    - `States:Get(ID: string) -> State`
    - Retrieves an existing state by its ID.

#### State Object

- **get**
    - `State:get(key: string) -> any`
    - Retrieves the value of a key from the state.

- **set**
    - `State:set(key: string, variant: any) -> any`
    - Sets a new value for a key in the state.

- **changed**
    - `State:changed(callback: function) -> {Disconnect: () -> ()}`
    - Creates a connection to listen for changes in the state.