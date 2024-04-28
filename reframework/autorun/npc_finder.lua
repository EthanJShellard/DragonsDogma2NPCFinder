local modName = "NPC Finder"

local _NPCManager;
local function GetNPCManager()
    if _NPCManager == nil then
        _NPCManager = sdk.get_managed_singleton("app.NPCManager");
    end
    return _NPCManager;
end 

local _characterManager;
local function GetCharacterManager()
    if _characterManager == nil then
        _characterManager = sdk.get_managed_singleton("app.CharacterManager");
    end
    return _characterManager;
end

local _worldOffsetSystem
local function GetWorldOffsetSystem()
    if _worldOffsetSystem == nil then
        _worldOffsetSystem = sdk.get_managed_singleton("app.WorldOffsetSystem");
    end
    return _worldOffsetSystem;
end

local NPCDataArray = {};
local NPCDataFound = false;
local searchString = "";
local searchStringChange = false;

-- Returns 2D array, where dimension is NPC index,
-- (name, character id, index)  
local function GetNPCData()
    local NPCHolderList = GetNPCManager():get_NPCHolder_FullList();
    for itr, NPCHolder in ipairs(NPCHolderList:ToArray()) do
        local NPC = GetNPCManager():getNPCData(NPCHolder.CharaID);
        if NPC then
            NPCDataArray[itr] = {};
            NPCDataArray[itr][1] = NPC:get_Name();
            NPCDataArray[itr][2] = NPCHolder.CharaID;
            NPCDataArray[itr][3] = itr;
        end
    end
    NPCDataFound = #NPCDataArray > 0;

    -- sort alphabetically
    table.sort(NPCDataArray, function(a,b)
        return a[1] < b[1];
    end)
end

local _defaultHeightDamageForHuman;
local _defaultBaseDamageForHuman;
local _defaultDamagePerHeightForHuman;
local _defaultHeightDieForHuman;
local fallDamageEnabled = true;
local shouldDisableFallDamageDuringWarp = true;

local function SetIsFallDamageEnabled(enabled)
    local manualPlayer = GetCharacterManager():get_ManualPlayer();
    if manualPlayer then
        local fallDamageCalc = manualPlayer:get_field("<FallDamageParamCalc>k__BackingField");
        if fallDamageCalc then
            local fallDamageCalcParam = fallDamageCalc:get_field("<Param>k__BackingField");
            if fallDamageCalcParam then
                if enabled then
                    fallDamageCalcParam.HeightDamageForHuman = _defaultHeightDamageForHuman;
                    fallDamageCalcParam.BaseDamageForHuman = _defaultBaseDamageForHuman;
                    fallDamageCalcParam.DamagePerHeightForHuman = _defaultDamagePerHeightForHuman;
                    fallDamageCalcParam.HeightDieForHuman = _defaultHeightDieForHuman;
                else
                    if fallDamageEnabled then
                        _defaultHeightDamageForHuman = fallDamageCalcParam.HeightDamageForHuman;
                        _defaultBaseDamageForHuman = fallDamageCalcParam.BaseDamageForHuman;
                        _defaultDamagePerHeightForHuman = fallDamageCalcParam.DamagePerHeightForHuman;
                        _defaultHeightDieForHuman = fallDamageCalcParam.HeightDieForHuman;
                    end
                    fallDamageCalcParam.HeightDamageForHuman = 99999;
                    fallDamageCalcParam.BaseDamageForHuman = 0;
                    fallDamageCalcParam.DamagePerHeightForHuman = 0;
                    fallDamageCalcParam.HeightDieForHuman = 99999;
                end
            end
        end
    end
end

local warpCoroutine;
local warping = false;
local function WarpPlayerToNPCPosition(index)
    local NPCHolderList = GetNPCManager():get_NPCHolder_FullList();
    local playerCharacter = GetCharacterManager():get_ManualPlayer();
    if playerCharacter and NPCHolderList then
        local teleporter = playerCharacter:get_TelepotorProp();
        local NPCHolder = GetNPCManager():get_NPCHolder_FullList():ToArray()[index];
        if teleporter and NPCHolder then
            GetCharacterManager():requestStartPause(playerCharacter, 2);
            teleporter:teleport(GetWorldOffsetSystem():toUniversalPosition(NPCHolder:get_Position()));
            
            warping = true;
            warpCoroutine = coroutine.create(function()
                if shouldDisableFallDamageDuringWarp then
                    SetIsFallDamageEnabled(false);
                end

                local time = os.time();
                local newTime = time + 4;
                while (time < newTime) do
                    coroutine.yield();
                    time = os.time();
                end

                GetCharacterManager():requestEndPause(playerCharacter, 2);
                newTime = time + 2;

                while (time < newTime) do
                    coroutine.yield();
                    time = os.time();
                end

                if shouldDisableFallDamageDuringWarp then
                    SetIsFallDamageEnabled(true);
                end

                warping = false;
                -- Data seems to become invalid eventually. This should hopefully keep it up to date enough.
                NPCDataFound = false;
                GetNPCData();
            end);
        
            coroutine.resume(warpCoroutine);
        end
    end
end

re.on_frame(function()
    if warping then
        coroutine.resume(warpCoroutine);
    end
end)

re.on_draw_ui(function()
    if not NPCDataFound then 
        if imgui.tree_node(modName) then
            if imgui.button("Find NPCS") and GetNPCManager() then
                GetNPCData();
            end
            imgui.tree_pop();
        end
    else
        if warping then
            imgui.text('Warping...');
        else
            _, shouldDisableFallDamageDuringWarp = imgui.checkbox("Disable fall damage during warp: ", shouldDisableFallDamageDuringWarp);
            
            if imgui.tree_node(modName) then
                imgui.text("Search: ");
                imgui.same_line();
                searchStringChange, searchString = imgui.input_text("", searchString);
        
                imgui.spacing();
        
                for _, NPC in ipairs(NPCDataArray) do
                    if NPC[1] ~= "???" and string.find(NPC[1]:lower(), searchString:lower()) then
                        imgui.text(NPC[1]);
                        imgui.same_line();
                        if imgui.button("Warp To " .. NPC[1]) then
                            WarpPlayerToNPCPosition(NPC[3]);
                        end
                    end
                end
                imgui.tree_pop();
            end
        end
    end 
end
)