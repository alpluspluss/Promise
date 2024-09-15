--[[
    Promise -> An implementation of 'Promise' in Luau. The purpose is solely for practice!
]]

--!optimize 2

export type Promise<T> = {
	__index: Promise<T>,
	_state: number,
	_value: T?,
	_reason: any?,
	_callbacks: { [number]: (T) -> () },
	_errorCallbacks: { [number]: (any) -> () },
	new: <U>(callback: (resolve: (U) -> (), reject: (any) -> ()) -> ()) -> Promise<U>,
	Resolve: (self: Promise<T>, value: T) -> (),
	Reject: (self: Promise<T>, reason: any) -> (),
	AndThen: <U, W>(self: Promise<T>, successCallback: ((T) -> U)?, failureCallback: ((any) -> W)?) -> Promise<U>,
	Catch: <W>(self: Promise<T>, callback: (any) -> W) -> Promise<W>,
}

local STATES = {
	PENDING = 0,
	REJECTED = 1,
	RESOLVED = 2
}

local Promise = {}
Promise.__index = Promise

function Promise.new<T>(callback: (resolve: (T) -> (), reject: (any) -> ()) -> ()): Promise<T>
	local self = setmetatable({}, Promise)
	self._state = STATES.PENDING
	self._callbacks = {}
	self._errorCallbacks = {}

	local function Resolve(value: T)
		if self._state == STATES.PENDING then
			self._state = STATES.RESOLVED
			self._value = value
			for _, callbackFn in ipairs(self._callbacks) do
				coroutine.wrap(callbackFn)(value)
			end
		end
	end

	local function Reject(reason: any)
		if self._state == STATES.PENDING then
			self._state = STATES.REJECTED
			self._reason = reason
			for _, callbackFn in ipairs(self._errorCallbacks) do
				coroutine.wrap(callbackFn)(reason)
			end
		end
	end

	coroutine.wrap(function()
		local success, erro = pcall(callback, Resolve, Reject)
		if not success then
			Reject(erro)
		end
	end)()

	return self
end

function Promise.Resolve<T>(self: Promise<T>, value: T): ()
	if self._state == STATES.PENDING then
		self._state = STATES.RESOLVED
		self._value = value
		for _, callback in ipairs(self._callbacks) do
			coroutine.wrap(callback)(value)
		end
	end
end

function Promise.Reject<T>(self: Promise<T>, reason: any)
	if self._state == STATES.PENDING then
		self._state = STATES.REJECTED
		self._reason = reason
		for _, callback in ipairs(self._errorCallbacks) do
			coroutine.wrap(callback)(reason)
		end
	end
end

function Promise.AndThen<T, U, W>(self: Promise<T>, successCallback: ((T) -> U)?, failureCallback: ((any) -> W)?): Promise<U | W>
	return Promise.new(function(resolve, reject)
		local function HandleSuccess(value: T)
			if successCallback then
				local success, result = pcall(successCallback, value)
				if success then
					resolve(result)
				else
					reject(result)
				end
			else
				resolve(value)
			end
		end

		local function HandleFailure(reason: any)
			if failureCallback then
				local success, result = pcall(failureCallback, reason)
				if success then
					resolve(result)
				else
					reject(result)
				end
			else
				reject(reason)
			end
		end

		if self._state == STATES.RESOLVED then
			HandleSuccess(self._value :: T)
		elseif self._state == STATES.REJECTED then
			HandleFailure(self._reason)
		else
			self._callbacks[#self._callbacks + 1] = HandleSuccess
			self._errorCallbacks[#self._errorCallbacks + 1] = HandleFailure
		end
	end)
end

function Promise.Catch<T, W>(self: Promise<T>, callback: (any) -> W): Promise<W>
	return self:AndThen(nil, callback)
end

return Promise
