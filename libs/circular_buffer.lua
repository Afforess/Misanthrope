circular_buffer = {}
circular_buffer.__index = circular_buffer

function circular_buffer.new()
    return {start_index = 1, end_index = 0, internal_table = {}, count = 0, dead_count = 0}
end

function circular_buffer.reset(list)
    list.start_index = 1
    list.end_index = 0
    list.internal_table = {}
    list.count = 0
    list.dead_count = 0
end

function circular_buffer.append(list, item)
    if list.dead_count > 10000 then
        local old_table = list.internal_table
        local old_start = list.start_index
        local old_end = list.end_index
        circular_buffer.reset(list)
        for i = old_start, old_end do
            if old_table[i] ~= nil then
                circular_buffer.append(list, old_table[i].value)
            end
        end
    end
    
    local index = list.end_index + 1
    local node = {value = item, index = index}
    list.internal_table[index] = node
    list.count = list.count + 1
    list.end_index = index
end

function circular_buffer.pop(list)
    if list.count == 0 then
        if list.dead_count > 0 then
            circular_buffer.reset(list)
        end
        return nil
    elseif list.count == 1 then
        local node = list.internal_table[list.start_index]
        circular_buffer.reset(list)
        return node.value
    else
        local node = list.internal_table[list.start_index]
        list.internal_table[list.start_index] = nil
        for i = list.start_index + 1, list.end_index do
            if list.internal_table[i] ~= nil then
                list.start_index = i
                break
            end
        end
        list.count = list.count - 1
        list.dead_count = list.dead_count + 1
        return node.value
    end
end

function circular_buffer.remove(list, node)
    if list.count == 1 then
        circular_buffer.reset(list)
    else
        list.internal_table[node.index] = nil
        list.count = list.count - 1
        list.dead_count = list.dead_count + 1
        -- find a new start index if we just erased it
        if node.index == list.start_index then
            for i = list.start_index + 1, list.end_index do
                if list.internal_table[i] ~= nil then
                    list.start_index = i
                    break
                end
            end
        -- find a new end index if we just erased it
        elseif node.index == list.end_index then
            for i = list.end_index, list.start_index, -1 do
                if list.internal_table[i] ~= nil then
                    list.end_index = i
                    break
                end
            end
        end
    end
end

function circular_buffer.iterator(list)
    local iterator = {list = list, current_index = list.start_index, _next = list.count > 0}
    function iterator.next()
        if iterator.has_next() then
            local node = iterator.next_node()
            if node then
                return node.value
            end
        end
        return nil
    end

    function iterator.next_node()
        local cur = iterator.current_index
        local any_next = iterator._next
        iterator._next = false
        for i = cur + 1, iterator.list.end_index do
            if iterator.list.internal_table[i] ~= nil then
                iterator.current_index = i
                iterator._next = true
                break
            end
        end
        if any_next then
            return iterator.list.internal_table[cur]
        else
            return nil
        end
    end

    function iterator.has_next()
        return iterator._next
    end
    return iterator
end
