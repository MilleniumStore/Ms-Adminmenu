Millennium = Millennium or {}

function Millennium.T(key)
    local locale = Locales[Config.Locale] or Locales.en
    return locale[key] or key
end

function Millennium.Trim(value)
    if type(value) ~= 'string' then return '' end
    return value:match('^%s*(.-)%s*$')
end

function Millennium.Clamp(value, minimum, maximum)
    value = tonumber(value)
    if not value then return nil end
    return math.max(minimum, math.min(maximum, value))
end
