local Lr = require 'Lr'

local JSON = require 'JSON'

local utils = require 'FlaskUtils'


local log = Lr.Logger()

log:enable('print')
log:info("Loading module...")


local append = function(t, x) t[#t + 1] = x end


Lr.Tasks.startAsyncTask(function()
Lr.FunctionContext.callWithContext('FlaskDiscoverCollections', function(context)

    local catalog = Lr.Application.activeCatalog()


    local servicesById = {}

    local service
    for _, service in ipairs(catalog:getPublishServices()) do
        if service:getPluginId() == _PLUGIN.id then
            servicesById[service.localIdentifier] = service
        end
    end


    for _, service in pairs(servicesById) do

        local settings = service:getPublishSettings()

        local collectionsById = {}

        local collection
        for _, collection in ipairs(service:getChildCollections()) do
            if collection:getRemoteId() then
                collectionsById[collection:getRemoteId()] = collection
            end
        end

        -- Add extra headers.
        local reqHeaders = {}
        for line in string.gmatch(settings.extraHeaders, "[^\n]+") do
            local field, value = string.match(line, "^%s*(%S+)%s*:%s*(.+)%s*$")
            if field and value then
                reqHeaders[#reqHeaders + 1] = {field=field, value=value}
            end
        end

        local rawBody, rawHeaders = Lr.Http.get(
            settings.endpointURL .. '/list_collections',
            reqHeaders
        )
        local headers = {status = rawHeaders.status}
        for i = 1, #rawHeaders do
            local header = rawHeaders[i]
            headers[header.field] = header.value
        end

        log:trace(string.format('status: %s\n%s', headers.status, rawBody))

        local data = JSON:decode(rawBody)
        for _, remoteCollection in ipairs(data) do

            log:trace(string.format('%d at %s -> %s', remoteCollection.id, remoteCollection.url, remoteCollection.title))

            if not collectionsById[remoteCollection.url] then
                catalog:withWriteAccessDo('FlaskDiscoverPhotos', function()
                    local collection = service:createPublishedCollection(
                        remoteCollection.title,
                        nil,
                        true
                    )
                    collection:setRemoteId(remoteCollection.url)
                    collection:setRemoteUrl(remoteCollection.url)
                end)
            end

        end

    end



end)
end)




