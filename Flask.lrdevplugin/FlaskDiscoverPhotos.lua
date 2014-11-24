local Lr = require 'Lr'

local JSON = require 'JSON'

local utils = require 'FlaskUtils'


local log = Lr.Logger()

log:enable('print')
log:info("Loading module...")


local append = function(t, x) t[#t + 1] = x end


local confirmRelink = function(localPhoto, remotePhoto)


    local ui = Lr.View.osFactory()
    -- local props = Lr.Binding.makePropertyTable(context)
    

    -- download the thumbnail
    local thumbnailUrl = remotePhoto.thumbnailUrl
    local tempDir = Lr.PathUtils.getStandardFilePath('temp')
    local thumbnailPath = Lr.PathUtils.child(tempDir, Lr.MD5.digest(thumbnailUrl) .. '.jpg')

    local fh = io.open(thumbnailPath, 'r')
    if fh then
        fh:close()
    else
        local body, headers = Lr.Http.get(thumbnailUrl)
        if not body then return end
        local fh = io.open(thumbnailPath, 'w')
        fh:write(body)
        fh:close()
    end

    log:info('thumbnail', thumbnailPath)

    local size = localPhoto:getRawMetadata('croppedDimensions')
    local target = 198
    if (size.width / target) < (size.height / target) then
        size.width = size.width * target / size.height
        size.height = target
    else
        size.height = size.height * target / size.width
        size.width = target
    end

    -- Create the contents for the dialog.
    local c = ui:row {

        -- bind_to_object = props,
        spacing = ui:control_spacing(),

        ui:column {

            spacing = ui:control_spacing(),

            width = 200,
            ui:static_text {
                title = localPhoto:getFormattedMetadata("fileName"),
                place_horizontal=0.5,
            },
            ui:row {
                height = 200,
                place_horizontal=0.5,
                ui:column {
                    place_vertical=0.5,
                    place_horizontal=0.5,
                    ui:catalog_photo {
                        photo = localPhoto,
                        width = size.width,
                        height = size.height,
                        frame_width = 1,
                    },
                },
            }
        },

        ui:column {
            
            width = 200,
            spacing = ui:control_spacing(),

            ui:static_text {
                title = remotePhoto.filename,
                place_horizontal=0.5,
            },

            ui:picture {
                value = thumbnailPath,
                width = 200,
                height = 200,
                frame_width = 1,
            },
        },

    }

    local res = Lr.Dialogs.presentModalDialog {
        title = "Confirm Relink",
        contents = c,
        actionVerb = 'Link',
        cancelVerb = 'Skip',
        otherVerb = 'Cancel',
    }

    log:trace(string.format('button: %s', res))
    if res == "cancel" then return "skip" end
    if res == "other" then return "cancel" end
    return res


end



Lr.Tasks.startAsyncTask(function()
Lr.FunctionContext.callWithContext('FlaskDiscoverPhotos', function(context)

    local catalog = Lr.Application.activeCatalog()

    local sources = {}
    local publishedCollections = {}

    local source, publishedCollection


    -- Split up the selections.
    for _, source in ipairs(catalog:getActiveSources()) do
        if source.type and source:type() == 'LrPublishedCollection' then
            append(publishedCollections, source)
        else
            append(sources, source)
        end
    end
    if #publishedCollections == 0 then
        error("Please select a published collecton.")
    elseif #sources == 0 then
        error("Please select a photo source.")
    end


    -- Collect all the remote photos.

    local date_taken_to_remote = {}
    for _, publishedCollection in ipairs(publishedCollections) do

        local service = publishedCollection:getService()
        if service:getPluginId() ~= _PLUGIN.id then
            error("Published collecton is not a Flask collection.")
        end
        local settings = service:getPublishSettings()

        local reqHeaders = {}

        -- Add extra headers.
        for line in string.gmatch(settings.extraHeaders, "[^\n]+") do
            local field, value = string.match(line, "^%s*(%S+)%s*:%s*(.+)%s*$")
            if field and value then
                reqHeaders[#reqHeaders + 1] = {field=field, value=value}
            end
        end

        local rawBody, rawHeaders = Lr.Http.get(
            settings.endpointURL .. '/list_photos?id=' .. publishedCollection:getRemoteId(),
            reqHeaders
        )
        local headers = {status = rawHeaders.status}
        for i = 1, #rawHeaders do
            local header = rawHeaders[i]
            headers[header.field] = header.value
        end

        log:trace(string.format('status: %s\n%s', headers.status, rawBody))

        local data = JSON:decode(rawBody)
        for _, remotePhoto in ipairs(data) do

            local dateTimeOriginal = Lr.Date.timeFromComponents(
                string.match(remotePhoto.dateTimeOriginal, '^(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)$')
            )

            date_taken_to_remote[dateTimeOriginal] = {publishedCollection, remotePhoto}
            log:trace(string.format('%d at %s -> %s', remotePhoto.id, dateTimeOriginal, remotePhoto.url))

        end


    end

    -- Look for photos in our sources that match.
    for _, source in ipairs(sources) do
        for _, photo in ipairs(source:getPhotos()) do

            local date_taken = photo:getRawMetadata('dateTimeOriginal')
            local remote_link = date_taken_to_remote[date_taken]

            if remote_link then

                local publishedCollection = remote_link[1]
                local remotePhoto = remote_link[2]

                local photoAlreadyPublished = false
                for _, publishedPhoto in ipairs(publishedCollection:getPublishedPhotos()) do
                    if publishedPhoto:getPhoto().localIdentifier == photo.localIdentifier then
                        photoAlreadyPublished = true
                    end
                end

                if not photoAlreadyPublished then

                    local button = confirmRelink(photo, remotePhoto)
                    if button == 'cancel' then
                        return -- break out of everything
                    end
                    if button == 'ok' then
                        log:trace(string.format('Relinking local %s to remote %s', photo.localIdentifier, remotePhoto.url))
                        catalog:withWriteAccessDo('FlaskDiscoverPhotos', function()
                            publishedCollection:addPhotoByRemoteId(
                                photo,
                                remotePhoto.url,
                                remotePhoto.url,
                                true
                            )
                        end)
                    end

                end

            end
        end
    end



end)
end)




