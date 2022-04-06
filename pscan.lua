local function pscan(_keys, args)
  local pattern = args[1];
  local cursor = args[2];

  if pattern == nil or cursor == nil then
    return redis.error_reply('Wrong number of regular arguments for function \'pscan\'');
  end

  -- Scan with the given cursor
  local scan_results = redis.call('scan', cursor);

  -- Filter the results with the given pattern
  local matched_keys = {};
  for _, key in ipairs(scan_results[2]) do
    if key:match(pattern) then
      table.insert(matched_keys, key);
    end
  end

  -- Return the new cursor for the next scan and the filtered results
  return { scan_results[1], matched_keys };
end

redis.register_function('pscan', pscan);