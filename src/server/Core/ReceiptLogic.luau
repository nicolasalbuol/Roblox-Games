-- Idempotent developer-product receipt handling, independent of Roblox APIs (testable).
-- deps: getProfile(userId), grant(profile, productId) -> boolean, save(profile) -> boolean, now(), maxHistory

local ReceiptLogic = {}

local function trim(receipts, max: number)
	local entries = {}
	for id, t in receipts do
		entries[#entries + 1] = { id, t }
	end
	if #entries <= max then
		return
	end
	table.sort(entries, function(a, b)
		return a[2] < b[2]
	end)
	for k = 1, #entries - max do
		receipts[entries[k][1]] = nil
	end
end

-- Returns "Granted" only after the grant is persisted; otherwise "NotProcessedYet" so Roblox retries.
function ReceiptLogic.process(info, deps): string
	local profile = deps.getProfile(info.PlayerId)
	if not profile then
		return "NotProcessedYet"
	end
	local receipts = profile.data.receipts
	local id = tostring(info.PurchaseId)
	if receipts[id] == nil then
		if not deps.grant(profile, info.ProductId) then
			return "NotProcessedYet"
		end
		receipts[id] = deps.now()
		trim(receipts, deps.maxHistory)
	end
	return if deps.save(profile) then "Granted" else "NotProcessedYet"
end

return ReceiptLogic
