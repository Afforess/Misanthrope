-----------------------------------------------------------------------------------------------------------------------
-- linkedlist.lua - v1.0.2 (2013-08)
-- Michael Ebens - https://gist.github.com/BlackBulletIV
-- Double Linked List / Deque (Deck) Container
-- https://gist.github.com/BlackBulletIV/4084042
-----------------------------------------------------------------------------------------------------------------------

--[[
	This returns an Container Creator for a Double Linked List
	with Deque (Deck) method names.  See example below.
	
	IMPORTANT: The list items HAVE to be tables and the tables
	should not use '_next' or '_prev' for anything other than 
	what is needed internally by the container.
	
	WARNINGS:
	* Do not remove items while iterating, store them in a
	  table using table.insert(removelist, itr) and then use ipairs
	  on removelist.
	* Do not use the same table in more than one list.  You might
	  want to modify the node to have an _item reference and that
	  would remove the 'table' constraint above.
]]--

--[[
	deque = require 'deque'

	local a = { 3 }
	local b = { 4 }
	local l = deque({ 2 }, a, b, { 5 }) -- only use tables
	 
	l:pop_back()
	l:pop_front()
	l:push_back({ 6 })
	l:push_front({ 7 })
	l:remove(a)
	l:insert({ 8 }, b)
	print("length", l.length)
	for v in l:iterate() do print(v[1]) end
]]--

local list = {}
list.__index = list

----------------------------------------------------------
-- Ctor for Creating a new List 
----------------------------------------------------------
setmetatable(list, { __call = function(_, ...)
	local t = setmetatable({ length = 0 }, list)
	for _, v in ipairs{...} do t:push_back(v) end
	return t
end })

----------------------------------------------------------
-- Adds a new item to the end of the list
----------------------------------------------------------
function list:push_back(t)
	if not t or type(t) ~= 'table' then
		error("Only add TABLES. [{" .. type(t) .. "}: " .. tostring(t) .. "] is NOT a TABLE.")
	end
	
	if self.last then
		self.last._next = t
		t._prev = self.last
		self.last = t
	else
		-- this is the first node
		self.first = t
		self.last = t
	end

	self.length = self.length + 1
end

----------------------------------------------------------
-- Add a new item to the beginning of the list
----------------------------------------------------------
function list:push_front(t)
	if not t or type(t) ~= 'table' then
		error("Only add TABLES. [{" .. type(t) .. "}: " .. tostring(t) .. "] is NOT a TABLE.")
	end
	
	if self.first then
		self.first._prev = t
		t._next = self.first
		self.first = t
	else
		self.first = t
		self.last = t
	end

	self.length = self.length + 1
end

----------------------------------------------------------
-- Insert an item after the specified value
----------------------------------------------------------
function list:insert(t, after)
	if not t or type(t) ~= 'table' then
		error("Only add TABLES. [{" .. type(t) .. "}: " .. tostring(t) .. "] is NOT a TABLE.")
	end
	
	if after then
		if after._next then
			after._next._prev = t
			t._next = after._next
		else
			self.last = t
		end

		t._prev = after    
		after._next = t
		self.length = self.length + 1
		
	elseif not self.first then
		-- this is the first node
		self.first = t
		self.last = t
	end
end

----------------------------------------------------------
-- Removes an item from the end of the list and returns that value
----------------------------------------------------------
function list:pop_back()
	if not self.last then return end
	local ret = self.last

	if ret._prev then
		ret._prev._next = nil
		self.last = ret._prev
		ret._prev = nil
	else
		-- this was the only node
		self.first = nil
		self.last = nil
	end

	self.length = self.length - 1
	return ret
end

----------------------------------------------------------
-- Removes an item from the beginning of the list and returns that value
----------------------------------------------------------
function list:pop_front()
	if not self.first then return end
	local ret = self.first

	if ret._next then
		ret._next._prev = nil
		self.first = ret._next
		ret._next = nil
	else
		self.first = nil
		self.last = nil
	end

	self.length = self.length - 1
	return ret
end

----------------------------------------------------------
-- Removes the specified Node from the List
----------------------------------------------------------
function list:remove(t)
	if not t or type(t) ~= 'table' then
		error("Only remove TABLES. [{" .. type(t) .. "}: " .. tostring(t) .. "] is NOT a TABLE.")
	end
	
	if t._next then
		if t._prev then
			t._next._prev = t._prev
			t._prev._next = t._next
		else
			-- this was the first node
			t._next._prev = nil
			self.first = t._next
		end
	elseif t._prev then
		-- this was the last node
		t._prev._next = nil
		self.last = t._prev
	else
		-- this was the only node
		self.first = nil
		self.last = nil
	end

	t._next = nil
	t._prev = nil
	self.length = self.length - 1
end

----------------------------------------------------------
-- Returns the next node in the list after current
----------------------------------------------------------
local function iterate(self, current)
	if not current then
		current = self.first
	elseif current then
		current = current._next
	end

	return current
end

----------------------------------------------------------
-- Returns an iterator function closure
----------------------------------------------------------
function list:iterate()
	return iterate, self, nil
end

return list
