
RandomName = {}

function RandomName.get_random_vowel()
    local r = math.random(38100)
    if (r < 8167) then return 'a' end
    if (r < 20869) then return 'e' end
    if (r < 27835) then return 'i' end
    if (r < 35342) then return 'o' end
    return 'u'
end

function RandomName.get_random_consonant()
    local r = math.random(34550) * 2

    if (r < 1492) then return 'b' end
    if (r < 4274) then return 'c' end
    if (r < 8527) then return 'd' end
    if (r < 10755) then return 'f' end
    if (r < 12770) then return 'g' end
    if (r < 18864) then return 'h' end
    if (r < 19017) then return 'j' end
    if (r < 19789) then return 'k' end
    if (r < 23814) then return 'l' end
    if (r < 26220) then return 'm' end
    if (r < 32969) then return 'n' end
    if (r < 34898) then return 'p' end
    if (r < 34993) then return 'q' end
    if (r < 40980) then return 'r' end
    if (r < 47307) then return 's' end
    if (r < 56363) then return 't' end
    if (r < 57341) then return 'v' end
    if (r < 59701) then return 'w' end
    if (r < 59851) then return 'x' end
    if (r < 61825) then return 'y' end
    return 'z'
end

function RandomName.generate_random_word(max_length)
    local letter = ""
    local str = ""
    local length = math.max(4, math.random(max_length))
    for i = 1, length do
        local r = math.random(1000)
        if i == 1 then r = r * 2 end
        if (r < 381) then
            letter = RandomName.get_random_vowel()
        else
            letter = RandomName.get_random_consonant()
        end
        if (i == 1) then
            letter = letter:upper()
        end
        str = str .. letter
    end
    return str
end

function RandomName.is_valid_name(name)
    local consonant_count = 0
    local vowel_count = 0
    local vowel_streak = 0
    local consonant_streak = 0

    name = name:lower()
    for i = 1, #name do
        local ch = name:sub(i,i)
        if (ch == 'a' or ch == 'e' or ch == 'i' or ch == 'o' or ch == 'u') then
            vowel_count = vowel_count + 1
            vowel_streak = vowel_streak + 1
            consonant_streak = 0
        else
            consonant_count = consonant_count + 1
            consonant_streak = consonant_streak + 1
            vowel_streak = 0
        end
        if consonant_streak > 3 or vowel_streak > 4 then
            return false
        end
    end
    --More than 75% of the word is vowels
    if ((vowel_count * 100 / math.max(1, vowel_count + consonant_count)) >= 75) then
        return false
    end
    --More than 70% of the word is consonants
    if ((consonant_count * 100 / math.max(1, vowel_count + consonant_count)) >= 70) then
        return false
    end
    return true
end

function RandomName.get_random_name(max_length)
    local random_name = ""
	local tries = 3
	max_length = math.max(4, max_length)
	while(tries > 0) do
		local name = RandomName.generate_random_word(max_length)
		if RandomName.is_valid_name(name) then
			--first word is always valid
			if #random_name == 0 then
				random_name = name
			else
				if (#random_name + #name <= max_length) then
					random_name = random_name .. " " .. name
				else
					tries = tries - 1
				end
			end
		end
	end
	return random_name;
end
