local maputils = {}

local xml = dofile("/lib/xml.lua")

function maputils.parse(filename, sheets)
  local handle = fs.open(filename, "rb")
  local data = handle:read("*all")
  handle:close()

  local xmldata = xml.parse(data)

  local mapObject = xmldata.children[1]
  local mapMeta = {
    mapWidth = tonumber(mapObject.properties.width),
    mapHeight = tonumber(mapObject.properties.height),
    tileWidth = tonumber(mapObject.properties.tilewidth),
    tileHeight = tonumber(mapObject.properties.tileheight)
  }
  local idLookup = {}
  local mapLayers = {}

  for tlID = 1, #mapObject.children do
    local tlItem = mapObject.children[tlID]

    if tlItem.name == "tileset" then
      idLookup[#idLookup + 1] = {firstgid = tonumber(tlItem.properties.firstgid), source = tlItem.properties.source}
    elseif tlItem.name == "layer" then
      local mdata = tlItem.children[1].children[1].content
      local layerData = {}

      local i = 0
      local j = 1
      for word in mdata:gmatch("%d+") do
        i = i + 1
        if i > mapMeta.mapWidth then
          i = 1
          j = j + 1
        end

        if j == 1 then
          layerData[i] = {}
        end

        local id = tonumber(word)
        if id == 0 then layerData[i][j] = {0, 0} end

        local sheet = #idLookup
        for idL = 1, #idLookup do
          if idLookup[idL].firstgid > id then
            id = id - idLookup[idL].firstgid + 1
            sheet = idL - 1
            break
          end
        end

        layerData[i][j] = {id, sheet}
      end

      mapLayers[#mapLayers + 1] = {
        offsetX = tonumber(tlItem.properties.offsetx) or 0,
        offsetY = tonumber(tlItem.properties.offsety) or 0,
        layerData = layerData
      }
    end
  end

  local mapO = {
    idLookup = idLookup,
    mapLayers = mapLayers,
    mapMeta = mapMeta,
    sheets = {}
  }

  if sheets then
    for i = 1, #sheets do
      maputils.attachSpritesheet(mapO, sheets[i])
    end
  end

  return mapO
end

function maputils.attachSpritesheet(map, sprSht, margin, spacing)
  local w, h = sprSht:getWidth(), sprSht:getHeight()

  margin = margin or 0
  spacing = spacing or 0

  map.sheets[#map.sheets + 1] = {
    image = sprSht,
    width = (w - margin * 2 + spacing) / (map.mapMeta.tileWidth + spacing),
    height = (h - margin * 2 + spacing) / (map.mapMeta.tileHeight + spacing),
    margin = margin,
    spacing = spacing
  }
end

function maputils.render(map, dx, dy, sx, sy, w, h, remap)
  local mw, mh = map.mapMeta.mapWidth, map.mapMeta.mapHeight
  w = w or math.huge
  h = h or math.huge
  dx = dx or 0
  dy = dy or 0
  sx = sx or 0
  sy = sy or 0
  if mw > w then mw = w end
  if mh > h then mh = h end

  local sprW, sprH = map.mapMeta.tileWidth, map.mapMeta.tileHeight

  for i = 1, #map.mapLayers do
    local layer = map.mapLayers[i]
    local layerData = layer.layerData
    local layerOffsetX = layer.offsetX
    local layerOffsetY = layer.offsetY

    local px, py = dx + layerOffsetX, dy + layerOffsetY

    for x = sx + 1, mw do
      for y = sy + 1, mh do
        local tile = layerData[x][y]

        if tile[1] > 0 then
          local sheet = map.sheets[tile[2]]
          local tx = (tile[1] - 1) % sheet.width + 1
          local ty = math.floor((tile[1] - 1) / sheet.width) + 1

          sheet.image:render(px + (x - 1) * sprW, py + (y - 1) * sprH,
            sheet.margin + (tx - 1) * (sprW + sheet.spacing),
            sheet.margin + (ty - 1) * (sprH + sheet.spacing),
            sprW, sprH)
        end
      end
    end
  end
end

return maputils
