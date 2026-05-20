# Lua scripting API

Reference for scripts running in the embedded Lua environment tied to a game client.

---

## Standard Lua libraries

These libraries are available globally:

| Library  | Typical use                             |
| -------- | --------------------------------------- |
| `base`   | Core Lua (`print`, `pairs`, `error`, …) |
| `string` | String operations                       |
| `table`  | Table helpers                           |
| `math`   | Math functions                          |
| `bit32`  | 32-bit bitwise operations               |

---

## Execution model and limits

- Main script execution and **`runThread`** tasks share an **instruction budget**. When the budget is exceeded, execution **yields** and resumes on later ticks.
- **`sleep(ms)`** only works inside code started with **`runThread`**. Using it from the main script or from an **event callback** raises: `Cannot use sleep() outside of a thread`.
- **Event handlers** registered with **`GameClient:on`** / **`once`** have a large per-callback budget (~1 million instructions). Exceeding it raises: `Event callback exceeded instruction limit!`.
- Serious Lua errors in threads or events may **stop** the script; check **`ScriptEngine:error()`** for the last failure.

---

## JSON helpers

### `parseJson(jsonString)`

- **Arguments:** `jsonString` — JSON text.
- **Returns:** Lua value: `null` → `nil`, plus booleans, numbers, strings, arrays (1-based tables), and objects (string-keyed tables).

### `toJson(luaTable)`

- **Arguments:** `luaTable` — Lua table.
- **Returns:** Compact JSON string (no extra whitespace).
- **Encoding rules:**
  - **Arrays:** tables with contiguous integer keys starting at `1` become JSON arrays.
  - **Empty `{}`** from Lua may serialize as an empty JSON object depending on content.
  - **Objects:** other tables become JSON objects. Keys must be **strings** or **integers** (other key types are skipped). Integer keys become string keys in JSON.

---

## Global accessors (current client)

These refer to the **client that owns** the running script:

| Function           | Returns                                             |
| ------------------ | --------------------------------------------------- |
| `getInventory()`   | Current inventory                                   |
| `getWorld()`       | Current world                                       |
| `getScripting()`   | Script engine handle                                |
| `getConsole()`     | In-game console                                     |
| `getLogger()`      | Logger                                              |
| `getPreferences()` | Preferences                                         |
| `getPhysics()`     | Physics interface (capabilities depend on the host) |

---

## Item definitions

### `getInfo(blockType)`

- **Arguments:** `blockType` — numeric block/item id.
- **Returns:** Item metadata (`ItemInfo`).

### `getInfos()`

- **Returns:** Ordered list of item infos (table / array).

### `ItemInfo` (read-only fields)

| Field       | Description    |
| ----------- | -------------- |
| `id`        | Block/item id  |
| `name`      | Display name   |
| `flags`     | Item flags     |
| `collision` | Collision info |

---

## Item packs

### `getPack(packId)`

- **Arguments:** `packId` — pack identifier string.
- **Returns:** Pack info (`ItemPack`).

### `getPacks()`

- **Returns:** Table of all packs.

### `ItemPack` (read-only fields)

| Field      | Description       |
| ---------- | ----------------- |
| `id`       | Pack id           |
| `price`    | Price             |
| `discount` | Discount          |
| `drops`    | Drop table        |
| `category` | Category          |
| `vip`      | VIP-only          |
| `steam`    | Steam-only        |
| `onetime`  | One-time purchase |
| `weight`   | Total weight      |

### `ItemDrops` (read-only fields)

| Field           | Description         |
| --------------- | ------------------- |
| `id`            | Drop id             |
| `amount`        | Amount              |
| `inventoryType` | Inventory item type |
| `weight`        | Weight              |

---

## Proxies

### `addProxy(data)`

- **Arguments:** `data` — proxy string in the format expected by the app (e.g. host:port or full URI).
- **Returns:** Success or handle depending on the host.

### `removeProxy(data)`

- Removes the proxy matching `data`.

### `getProxies()`

- **Returns:** Table of `Proxy` objects.

### `distributeProxies(limit)`

- Sets how proxies are shared across clients (non-negative cap), then redistributes.

### `Proxy`

| Field  | Type        | Description               |
| ------ | ----------- | ------------------------- |
| `key`  | string      | Proxy key                 |
| `info` | `ProxyInfo` | Parsed connection details |

### `ProxyInfo`

| Field  | Description |
| ------ | ----------- |
| `ip`   | Host        |
| `port` | Port        |
| `user` | Username    |
| `pass` | Password    |

---

## Credentials (table)

Optional keys when creating or updating a client:

| Key        | Meaning          |
| ---------- | ---------------- |
| `device`   | Device id        |
| `email`    | Account email    |
| `password` | Account password |

---

## Multi-client API

### `addClient([credentials])`

- **Returns:** A new `GameClient`.
- With no argument, creates a client with empty credentials; with a table, fills credentials from the keys above.

### `updateClient([clientId], [credentials])`

- If `clientId` is omitted, updates the **current** script’s client.
- Credential fields are replaced from the table when given; omitted table clears to empty credentials.

### `removeClient([clientId])`

- With id: removes that client.
- Without arguments: removes the **current** script client.

### `getClient([clientId])`

- With id: that client.
- Without arguments: the **current** script client.

### `getClients()`

- **Returns:** Table of all connected/managed clients.

---

## `GameClient`

### Identity and economy

| Field       | Type               | Description       |
| ----------- | ------------------ | ----------------- |
| `id`        | string             | Client id         |
| `gems`      | number             | Gem balance       |
| `bytecoins` | number             | Bytecoin balance  |
| `status`    | `GameClientStatus` | Connection status |

### Subsystems

| Method          | Returns           |
| --------------- | ----------------- |
| `inventory()`   | Inventory         |
| `world()`       | World             |
| `console()`     | Console           |
| `logger()`      | Logger            |
| `preferences()` | Preferences       |
| `physics()`     | Physics interface |
| `scripting()`   | Script engine     |
| `chatting()`    | Chatting service  |

### Connection

| Method                        | Description                                           |
| ----------------------------- | ----------------------------------------------------- |
| `connect()`                   | Connect                                               |
| `disconnect()`                | Disconnect                                            |
| `connected()`                 | Whether connected                                     |
| `ping()`                      | Round-trip time (ms or host units)                    |
| `send(packetId, paramsTable)` | Send a packet; `paramsTable` is encoded like `toJson` |

### Navigation

| Method         | Description                |
| -------------- | -------------------------- |
| `navigation()` | Current navigation / world |

### Movement

| Method                            | Description                                   |
| --------------------------------- | --------------------------------------------- |
| `point()`                         | Tile coordinates (`Vector2i`)                 |
| `position()`                      | World position (`Vector2`)                    |
| `setPoint(point, teleport)`       | Snap to tile                                  |
| `setPosition(position, teleport)` | Snap to world position                        |
| `movePoint(point)`                | Move on grid; returns whether accepted        |
| `movePosition(position)`          | Move in world space; returns whether accepted |
| `respawn()`                       | Respawn                                       |
| `enter()`                         | Enter door / context action                   |

### Pathfinding

| Method            | Description              |
| ----------------- | ------------------------ |
| `getPath(point)`  | Waypoints toward `point` |
| `findPath(point)` | Start pathfinding        |
| `pathfinding()`   | Whether a path is active |
| `clearPath()`     | Cancel path              |

### Chat and status

| Method            | Description                    |
| ----------------- | ------------------------------ |
| `say(message)`    | Send chat                      |
| `setStatus(icon)` | Status icon (`StatusIconType`) |

### Worlds and warping

| Method          | Description                                            |
| --------------- | ------------------------------------------------------ |
| `warp(name)`    | Warp (world name or `"name:id"` style, per game rules) |
| `leave()`       | Leave world                                            |
| `nether(level)` | Enter nether                                           |
| `mines(level)`  | Enter mines                                            |
| `exitNether()`  | Leave nether                                           |

### Inventory actions

| Method                              | Description      |
| ----------------------------------- | ---------------- |
| `drop(blockType, invType, amount)`  | Drop items       |
| `trash(blockType, invType, amount)` | Trash items      |
| `use(blockType)`                    | Use consumable   |
| `wear(blockType)`                   | Equip wearable   |
| `unwear(blockType)`                 | Unequip          |
| `wearing(blockType)`                | Whether equipped |
| `expandInventory()`                 | Expand storage   |

### Tiles

| Method                             | Description |
| ---------------------------------- | ----------- |
| `hit(point)`                       | Punch tile  |
| `place(point, blockType, invType)` | Place block |

### Collecting and shop

| Method                   | Description          |
| ------------------------ | -------------------- |
| `collect(collectableId)` | Pick up collectable  |
| `collectGift(point)`     | Collect gift at tile |
| `buy(packId)`            | Purchase pack        |

### Misc

| Method                     | Description      |
| -------------------------- | ---------------- |
| `isInTutorial()`           | In tutorial      |
| `setFaceAnimation(animId)` | Face animation   |
| `setIsVisible(visible)`    | Visibility       |
| `setIsOnline(online)`      | Online indicator |
| `setZoomLevel(level)`      | Zoom preset      |
| `setZoomValue(value)`      | Zoom amount      |

### Events

| Method                      | Description                                                               |
| --------------------------- | ------------------------------------------------------------------------- |
| `on(eventType, callback)`   | Listen for `eventType`; callback receives decoded payload (one argument). |
| `once(eventType, callback)` | Same, but fired only once.                                                |

Errors inside callbacks may stop the script; use `pcall` inside handlers if you need to recover.

---

## Enums

### `GameClientStatus`

`offline`, `online`, `timeout`, `alreadyOn`, `authError`, `ipBanned`, `deviceBanned`, `rateLimited`, `kicked`, `accountBanned`, `serverFull`, `versionUpdate`, `changingSubserver`, `maintenance`, `jwtError`

### `StatusIconType`

`none`, `menu`, `typing`, `trading`, `card`

### `InventoryItemType`

`block`, `background`, `seed`, `water`, `wearable`, `weapon`, `throwable`, `consumable`, `shard`, `blueprint`, `familiar`, `food`, `wiring`

---

## `Vector2` / `Vector2i`

Typical construction: `Vector2.new(x, y)` with floats, `Vector2i.new(x, y)` with integers (exact name follows Lua bindings).

### `Vector2`

| Member          | Description   |
| --------------- | ------------- |
| `x`, `y`        | Components    |
| `point()`       | Related point |
| `equals(other)` | Equality      |

### `Vector2i`

| Member          | Description            |
| --------------- | ---------------------- |
| `x`, `y`        | Integer grid coords    |
| `position()`    | Related world position |
| `equals(other)` | Equality               |

---

## `Inventory`

| Member / method             | Description                   |
| --------------------------- | ----------------------------- |
| `slots`                     | Slot count                    |
| `items`                     | List of items                 |
| `count(blockType, invType)` | Count for that stack type     |
| `item(slot)`                | Item at slot index            |
| `item(blockType, invType)`  | Item by id and inventory type |

### `InventoryItem`

| Field    | Description         |
| -------- | ------------------- |
| `id`     | Block type id       |
| `type`   | `InventoryItemType` |
| `amount` | Amount              |

---

## `World`

| Field / method    | Description           |
| ----------------- | --------------------- |
| `id`              | World id              |
| `size`            | Dimensions            |
| `entrance`        | Spawn / start         |
| `tile(point)`     | `Tile` at coordinates |
| `tiles`           | All tiles             |
| `player(userId)`  | Player by id          |
| `players`         | All players           |
| `collectable(id)` | Collectable by id     |
| `collectables`    | All collectables      |
| `enemy(id)`       | Enemy by id           |
| `enemies`         | All enemies           |
| `growscan()`      | Growscan helper       |

### `Tile`

| Field / method                              | Description                                          |
| ------------------------------------------- | ---------------------------------------------------- |
| `foreground`, `background`, `water`, `wire` | Layers / flags                                       |
| `point()`                                   | Tile point                                           |
| `position()`                                | Position with tile offset                            |
| `item()`                                    | Extra tile data as a Lua table (from JSON), or empty |
| `tree()`                                    | Tree / plant state                                   |

### `Tree`

| Field       | Description      |
| ----------- | ---------------- |
| `blockType` | Plant id         |
| `mixed`     | Is tree mixed    |
| `ready()`   | Ready to harvest |

### `Player`

| Field        | Description       |
| ------------ | ----------------- |
| `id`         | User id           |
| `name`       | Display name      |
| `point()`    | Position as point |
| `position()` | Raw position      |
| `level`      | Level             |

### `Collectable`

| Field                   | Description             |
| ----------------------- | ----------------------- |
| `id`                    | Collectable instance id |
| `amount`                | Amount                  |
| `blockType`             | Item id                 |
| `inventoryType`         | Inventory type          |
| `isGem`                 | Is gem drop             |
| `gemType`               | Gem variant             |
| `point()`, `position()` | Location                |

### `Growscan`

| Method           | Description          |
| ---------------- | -------------------- |
| `collectables()` | Scan results         |
| `gems()`         | Gem totals from scan |

---

## `ChattingService`

| Member         | Description                  |
| -------------- | ---------------------------- |
| `say(message)` | Queue next outgoing message  |
| `typing()`     | Whether chat input is active |
| `clear()`      | Clear queued typing          |

---

## `ScriptEngine`

| Member            | Description                                                            |
| ----------------- | ---------------------------------------------------------------------- |
| `execute(script)` | Queue script text to run                                               |
| `stop()`          | Stop and unload                                                        |
| `running()`       | Whether the script loop is active                                      |
| `error()`         | Last error, if any (often line + message; exact shape depends on host) |

---

## `Console`

| Member         | Description           |
| -------------- | --------------------- |
| `entries`      | Message history       |
| `enabled`      | Whether console is on |
| `clear()`      | Clear messages        |
| `add(message)` | Append a line         |

### `ConsoleMessage`

| Field       | Description     |
| ----------- | --------------- |
| `content`   | Text            |
| `timestamp` | Time            |
| `type`      | Kind of message |

---

## `Logger`

| Member     | Description                               |
| ---------- | ----------------------------------------- |
| `add(...)` | Write log line (arguments depend on host) |
| `clear()`  | Clear log                                 |
| `entries`  | Log lines                                 |

---

## `Preferences`

| Field               | Description                      |
| ------------------- | -------------------------------- |
| `reconnect`         | Auto-reconnect                   |
| `collect`           | Auto-collect                     |
| `reconnectInterval` | Delay between reconnect attempts |
| `collectInterval`   | Delay between collect attempts   |

---

## Threading API

### `runThread(function, ...)`

- Starts `function` in a separate schedulable task with optional arguments.
- **Returns:** Numeric **thread id** for `removeThread`.

### `removeThread(threadId)`

- Stops the given thread on the next opportunity.

### `sleep(milliseconds)`

- **Yielding.** Only inside **`runThread`** code. Pauses about `milliseconds` before continuing.

---

## Event delivery

- Events are processed while the script is **running**.
- Handlers get **one argument**: the event payload (decoded from JSON to Lua values).
- The special **`presend`** hook runs before sends and may not pass a payload.
- A failing handler can cause the whole script to stop; see **`ScriptEngine:error()`**.

## about events you can do

client:on("p", function(msg)
  -- any messages
end)

client:on("p:LW", function(msg)
  -- filtered message LW
end)

client:on("spawn", function()
  -- client spawn
end)

client:on("presend", function()
  -- Presend Hook directly from the application itself
end)

client:once("p", function(msg)
  -- run only once
end)

client:on("connect"/"disconnect", function()
  -- connected/disconnected
end)
