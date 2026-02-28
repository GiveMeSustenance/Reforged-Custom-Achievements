local _G = GLOBAL

local function dump_table(table)
    for k, v in pairs(table) do
        print("Key =")
        print(k)
        print("Value =")
        print(v)
    end
end

local function table_contains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end