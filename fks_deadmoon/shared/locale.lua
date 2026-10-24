-- Config.Locale picks a table from locales/. Missing keys fall back to English.

local lang = Config.Locale or 'en'
if not (Locales and Locales[lang]) then
    print(('^3[fks-deadmoon] Locale "%s" not found - using "en".^0'):format(tostring(lang)))
    lang = 'en'
end

function _L(key, ...)
    local s = Locales[lang][key] or (Locales.en or {})[key] or key
    if select('#', ...) > 0 then return s:format(...) end
    return s
end
