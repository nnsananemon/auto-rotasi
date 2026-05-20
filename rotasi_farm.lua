-- ==========================================
-- ⚙️ PENGATURAN FARMING
-- ==========================================
local FARM_WORLD = "BYWQ:JEM" -- Format: NamaWorld:PortalID
local FARM_ROW_Y = 7 -- Y coordinate baris yang mau di-farm
local START_X = 1
local END_X = 33

-- Posisi Presisi Drop & Storage
local STORAGE_X = 5
local STORAGE_Y = 23

-- Posisi Portal (Tempat PNB)
local PORTAL_X = 36
local PORTAL_Y = 7

local ITEM_ID = 78
local SEED_ID = 79
local HIT_REQUIRED = 6

local TARGET_SEED = 200
local KEEP_SEED = 100
local LURE_PACK = "lure_pack" -- ID Pack Lure

-- ==========================================
-- 🔧 INISIALISASI & UTILITY
-- ==========================================
local client = getClient()

local InventoryItemType = {
    block = 0, background = 1, seed = 2, water = 3,
    wearable = 4, weapon = 5, throwable = 6, consumable = 7,
    shard = 8, blueprint = 9, familiar = 10, food = 11, wiring = 12
}

function go_to(x, y)
    if not client:connected() then return end
    local target = Vector2i.new(x, y)
    if client:point().x == target.x and client:point().y == target.y then 
        return 
    end
    
    local succeeded = client:findPath(target)
    while succeeded and client:pathfinding() do
        if not client:connected() then break end 
        sleep(100)
    end
end

function warp_to_farm()
    while not client:connected() do 
        print("⏳ Menunggu Auto-Reconnect...")
        sleep(2000) 
    end
    
    local current_nav = client:navigation():lower()
    local target_nav = FARM_WORLD:lower():gsub(":%w+", "")
    
    if current_nav == "menu" or current_nav ~= target_nav then
        print("🚀 Warp ke " .. FARM_WORLD)
        client:warp(FARM_WORLD)
        sleep(5000)
        while client:pathfinding() do sleep(100) end
    end
end

-- ==========================================
-- 🎒 FIX INVENTORY CHECKER (100% AKURAT)
-- ==========================================
function get_seed_count()
    local inv = client:inventory()
    if not inv then return 0 end
    
    -- Loop manual satu per satu isi backpack
    for _, item in pairs(inv.items) do
        if item.id == SEED_ID then
            return item.amount
        end
    end
    return 0
end

function get_block_count()
    local inv = client:inventory()
    if not inv then return 0 end
    
    -- Loop manual satu per satu isi backpack
    for _, item in pairs(inv.items) do
        if item.id == ITEM_ID then
            return item.amount
        end
    end
    return 0
end

-- ==========================================
-- 🧲 AREA COLLECTOR
-- ==========================================
function collect_area(radius)
    if not client:connected() then return end
    local world = client:world()
    if not world then return end
    
    local my_pos = client:point()
    
    for id, collectable in pairs(world.collectables) do
        local item_pos = collectable:point()
        local dist = math.abs(my_pos.x - item_pos.x) + math.abs(my_pos.y - item_pos.y)
        if dist <= radius then
            client:collect(id)
            sleep(50)
        end
    end
end

-- ==========================================
-- 📦 STORAGE & SHOP 
-- ==========================================
local storage_is_empty = false 

function manage_storage()
    if not client:connected() then return end
    local seed_count = get_seed_count()
    if seed_count >= TARGET_SEED then
        go_to(STORAGE_X, STORAGE_Y)
        
        if client:point().x == STORAGE_X and client:point().y == STORAGE_Y then
            local drop_amount = seed_count - KEEP_SEED
            client:drop(SEED_ID, InventoryItemType.seed, drop_amount)
            
            storage_is_empty = false 
            
            sleep(1000)
            client:buy(LURE_PACK)
            sleep(1000)
            print("✅ Berhasil drop " .. drop_amount .. " seeds & beli lure.")
        end
    end
end

function take_seed()
    if not client:connected() then return end
    if storage_is_empty then return end 
    
    if get_seed_count() == 0 then
        print("🚶 Mengambil seed di storage...")
        go_to(STORAGE_X, STORAGE_Y)
        collect_area(2)
        sleep(1000)
        
        if get_seed_count() == 0 then
            print("⚠️ Storage kosong! Mengingat status agar tidak stuck.")
            storage_is_empty = true 
        end
    end
end

-- ==========================================
-- 🌱 LOGIC PEMBACAAN LAHAN (MENCEGAH CRASH)
-- ==========================================
function get_empty_tiles_count()
    local world = client:world()
    if not world then return 0 end
    
    local count = 0
    for x = START_X, END_X do
        local tile = world:tile(Vector2i.new(x, FARM_ROW_Y))
        if tile and tile.foreground == 0 then
            count = count + 1
        end
    end
    return count
end

function has_harvestable_trees()
    local world = client:world()
    if not world then return false end
    
    for x = START_X, END_X do
        local tile = world:tile(Vector2i.new(x, FARM_ROW_Y))
        if tile and tile.foreground ~= 0 then 
            local tree = tile:tree()
            if tree and tree:ready() then return true end
        end
    end
    return false
end

-- ==========================================
-- ⛏️ PNB DI KANAN BOT
-- ==========================================
function auto_pnb()
    local break_count = 0
    local target_pos = Vector2i.new(PORTAL_X + 1, PORTAL_Y)

    while get_block_count() > 0 do
        if not client:connected() then break end 
        local world = client:world()
        if not world then break end

        if client:point().x ~= PORTAL_X or client:point().y ~= PORTAL_Y then
            go_to(PORTAL_X, PORTAL_Y)
            sleep(300)
        end

        local tile = world:tile(target_pos)
        if not tile then break end

        if tile.foreground == 0 then
            client:place(target_pos, ITEM_ID, InventoryItemType.block)
            sleep(200)
        end
        
        tile = world:tile(target_pos)
        
        if tile.foreground ~= 0 then
            for i = 1, HIT_REQUIRED do
                if not client:connected() then break end 
                local check_tile = world:tile(target_pos)
                if check_tile and check_tile.foreground ~= 0 then
                    client:hit(target_pos)
                    sleep(200)
                else
                    break 
                end
            end
            break_count = break_count + 1
            
            if break_count % 50 == 0 then
                print("♻️ 50 Blocks hancur, mengambil drop...")
                collect_area(2)
            end
        end
    end
    
    if client:connected() then
        print("✅ PNB selesai. Mengambil sisa drop...")
        collect_area(2)
    end
end

-- ==========================================
-- 🌱 HARVEST & PLANT 
-- ==========================================
function harvest_trees()
    local world = client:world()
    if not world then return end

    print("🌳 Memanen pohon...")
    for x = START_X, END_X do
        if not client:connected() then break end 

        local target_pos = Vector2i.new(x, FARM_ROW_Y)
        local tile = world:tile(target_pos)
        
        if tile and tile.foreground ~= 0 then
            local tree = tile:tree()
            if tree and tree:ready() then
                go_to(x, FARM_ROW_Y - 1)
                client:hit(target_pos)
                sleep(150)
                collect_area(2)
            end
        end
    end
end

function plant_seeds()
    local world = client:world()
    if not world then return end

    print("🌱 Mulai menanam seed di lahan kosong...")
    for x = START_X, END_X do
        if not client:connected() or get_seed_count() == 0 then break end 
        
        local target_pos = Vector2i.new(x, FARM_ROW_Y)
        local tile = world:tile(target_pos)
        
        if tile and tile.foreground == 0 then
            go_to(x, FARM_ROW_Y - 1)
            -- Gunakan seed type 2 atau abaikan jika executor minta beda
            client:place(target_pos, SEED_ID, InventoryItemType.seed)
            sleep(150)
        end
    end
end

-- ==========================================
-- 🚀 MAIN LOOP
-- ==========================================
function main()
    print("Mulai Bot | Sistem Anti-Crash & Fix Inventory Aktif")
    
    while true do
        warp_to_farm() 
        
        if client:navigation() ~= "menu" and client:connected() then
            
            if get_block_count() > 0 then
                auto_pnb()
            
            elseif has_harvestable_trees() then
                harvest_trees()
            
            else
                local empty_tiles = get_empty_tiles_count()
                
                if empty_tiles > 0 then
                    -- Cek manual inventory, kalau beneran 0 baru ke storage
                    if get_seed_count() == 0 then
                        take_seed()
                    end
                    
                    manage_storage()
                    
                    -- Jika inventory ada isinya, langsung plant!
                    if get_seed_count() > 0 then
                        plant_seeds()
                    else
                        print("💤 Tidak ada seed di BP maupun Storage. Menunggu pohon matang...")
                        sleep(2000)
                    end
                else
                    print("⏳ Lahan penuh ditanami. Menunggu pohon siap panen...")
                    sleep(2000) 
                end
            end
            
        else
            sleep(2000)
        end
        
        sleep(500)
    end
end

main()
