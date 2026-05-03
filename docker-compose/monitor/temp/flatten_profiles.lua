-- Flatten eBPF Profile Data for OpenSearch
-- Processes the complex nested profile structure and creates flat documents

function process_sample(sample, location_indices, dictionary, timestamp, duration, profile_attrs)
    local records = {}
    local string_table = dictionary.stringTable or {}
    local location_table = dictionary.locationTable or {}
    local function_table = dictionary.functionTable or {}
    local attribute_table = dictionary.attributeTable or {}

    -- Get sample attributes
    local attr_indices = sample.attributeIndices or {}
    local sample_attrs = {}
    for _, attr_idx in ipairs(attr_indices) do
        if attribute_table[attr_idx + 1] then
            local attr = attribute_table[attr_idx + 1]
            local key = attr.key or ""
            local value = attr.value or {}
            if value.stringValue then
                sample_attrs[key] = value.stringValue
            elseif value.intValue then
                sample_attrs[key] = value.intValue
            end
        end
    end

    -- Extract timestamps
    local timestamps = sample.timestampsUnixNano or {}

    -- Process each timestamp
    for _, ts_nano in ipairs(timestamps) do
        local record = {
            timestamp_unix_nano = tonumber(ts_nano) or 0,
            duration_nanos = tonumber(duration) or 0,
            sample_count = 1,
            sample_period = tonumber(profile_attrs.period) or 0,
        }

        -- Add sample attributes
        for k, v in pairs(sample_attrs) do
            record[k] = v
        end

        -- Resolve stack frames
        local locations_start = sample.locationsStartIndex or 0
        local locations_length = sample.locationsLength or 0

        local stack_frames = {}
        local top_function = {}
        local frame_type = "user"

        for i = 0, locations_length - 1 do
            local loc_idx = location_indices[locations_start + i + 1]
            if location_table[loc_idx + 1] then
                local location = location_table[loc_idx + 1]
                local address = location.address or "unknown"
                local lines = location.line or {}

                local frame = {
                    address = address,
                    functions = {}
                }

                for _, line in ipairs(lines) do
                    local func_idx = line.functionIndex or 0
                    if function_table[func_idx + 1] then
                        local func = function_table[func_idx + 1]
                        local name_idx = func.nameStrindex or 0
                        local filename_idx = func.filenameStrindex or -1

                        local func_name = string_table[name_idx + 1] or "unknown"
                        local filename = filename_idx >= 0 and string_table[filename_idx + 1] or "unknown"

                        table.insert(frame.functions, {
                            name = func_name,
                            filename = filename
                        })

                        if i == 0 then
                            top_function = {
                                name = func_name,
                                filename = filename,
                                address = address
                            }
                        end
                    end
                end

                -- Check frame type
                local loc_attr_indices = location.attributeIndices or {}
                for _, attr_idx in ipairs(loc_attr_indices) do
                    if attribute_table[attr_idx + 1] then
                        local attr = attribute_table[attr_idx + 1]
                        if attr.key == "profile.frame.type" and attr.value.stringValue == "kernel" then
                            frame_type = "kernel"
                        end
                    end
                end

                table.insert(stack_frames, frame)
            end
        end

        record.stack_frames = stack_frames
        record.top_function = top_function
        record.frame_type = frame_type

        table.insert(records, record)
    end

    return records
end

function flatten_profile(tag, timestamp, record)
    local flattened_records = {}
    local resource_profiles = record.resourceProfiles or {}

    for _, rp in ipairs(resource_profiles) do
        local resource = rp.resource or {}
        local resource_attrs = {}
        for _, attr in ipairs(resource.attributes or {}) do
            local key = attr.key or ""
            local value = attr.value or {}
            if value.stringValue then
                resource_attrs[key] = value.stringValue
            end
        end

        local scope_profiles = rp.scopeProfiles or {}

        for _, sp in ipairs(scope_profiles) do
            local scope = sp.scope or {}
            local profiles = sp.profiles or {}

            for _, profile in ipairs(profiles) do
                local samples = profile.sample or {}
                local location_indices = profile.locationIndices or {}
                local dictionary = record.dictionary or {}
                local time_nanos = profile.timeNanos or "0"
                local duration_nanos = profile.durationNanos or "0"

                for _, sample in ipairs(samples) do
                    local sample_records = process_sample(
                        sample,
                        location_indices,
                        dictionary,
                        time_nanos,
                        duration_nanos,
                        {
                            period = profile.period or "0"
                        }
                    )

                    for _, rec in ipairs(sample_records) do
                        -- Add resource and scope info
                        rec.resource = resource_attrs
                        rec.scope_name = scope.name or ""
                        rec.scope_version = scope.version or ""

                        -- Generate unique ID
                        rec._id = string.format("%s_%d", rec.timestamp_unix_nano, rec.thread_id or 0)

                        table.insert(flattened_records, 1, rec)
                    end
                end
            end
        end
    end

    -- Output each flattened record
    for _, rec in ipairs(flattened_records) do
        rec.timestamp_iso = os.date("!%Y-%m-%dT%H:%M:%SZ", rec.timestamp_unix_nano / 1000000000)
    end

    return 1, flattened_records
end
