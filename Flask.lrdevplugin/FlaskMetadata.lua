local LrLogger = import 'LrLogger'

local utils = require 'FlaskUtils'


local logger = LrLogger('FlaskMetadata')

logger:enable("print")
logger:info("Loading module...")



return {
    
    metadataFieldsForPhotos = {
        {
            id = "lastRemoteId",
            dataType = "string",
        }
    },

    -- This is updated whenever I need to test the update function, so it is
    -- guarantee not to track the plugin's version.
    schemaVersion = 12,

    updateFromEarlierSchemaVersion = function(catalog, previousVersion, progressScope)

        logger:trace(string.format('Updating schema for %s', _PLUGIN.id))
        catalog:assertHasPrivateWriteAccess("FlaskMetadata.updateFromEarlierSchemaVersion")

        local si, service
        local ci, collection
        local pi, publishedPhoto
        for si, service in ipairs(catalog:getPublishServices(_PLUGIN.id)) do
            for ci, collection in ipairs(service:getChildCollections()) do
                for pi, publishedPhoto in ipairs(collection:getPublishedPhotos()) do
                    if publishedPhoto:getRemoteId() then
                        local photo = publishedPhoto:getPhoto()
                        logger:trace(string.format(
                            "Upgrading lastRemoteId for %d to %s",
                            photo.localIdentifier,
                            publishedPhoto:getRemoteId()
                        ))
                        utils.setServiceMetadata(service, photo, 'lastRemoteId', publishedPhoto:getRemoteId())
                    end
                end
            end
        end

    end

}

