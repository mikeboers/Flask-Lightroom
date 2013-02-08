
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrHttp = import 'LrHttp'
local LrPathUtils = import 'LrPathUtils'
local LrLogger = import 'LrLogger'

local bind = LrView.bind
local share = LrView.share

local logger = LrLogger('WebHooks')

logger:enable("print")
logger:trace("Loading module...")


local publisher = {}


-- This is a publisher.
publisher.supportsIncrementalPublish = 'only'


publisher.allowFileFormats = { 'JPEG' }
publisher.allowColorSpaces = { 'sRGB' }

publisher.hideSections = { 'exportLocation', 'video' }
publisher.hidePrintResolution = true
publisher.canExportVideo = false


publisher.exportPresetFields = {
	{ key = 'url', default = 'http://example.com/endpoint' },
	{ key = 'method', default = 'POST' }
}

-- publisher.startDialog = function( propertyTable )
-- end


publisher.sectionsForTopOfDialog = function( f, propertyTable )
	return {
		{
			title = "Web Hooks",

			f:row {
				f:static_text {
					title = "URL",
					width = share 'WebHookTitleSectionLabel'
				},
				f:edit_field {
					value = bind 'url',
					immediate = false,
					width = 450
				}
			},

			f:row {
				f:static_text {
					title = "Method",
					width = share 'WebHookTitleSectionLabel'
				},
				f:popup_menu {
					value = bind 'method',
					items = {
						{ value = 'POST', title = 'POST' },
					}
				}
			}

		}
	}

end


local uploadPhoto = function ( propertyTable, params )

	local form = {
		-- key = "value"
		title = params.photo:getFormattedMetadata( 'title' ),
		caption = params.photo:getFormattedMetadata( 'caption' ),
		keywordTags = params.photo:getFormattedMetadata( 'keywordTagsForExport' )
	}

	local mimeChunks = {}
	for argName, argValue in pairs( form ) do
		mimeChunks[ #mimeChunks + 1 ] = { name = argName, value = argValue }
	end

	-- local filePath = params.filePath
	-- local fileName = LrPathUtils.leafName( filePath )
	-- mimeChunks[ #mimeChunks + 1 ] = { name = 'photo', fileName = fileName, filePath = filePath, contentType = 'application/octet-stream' }

	logger:tracef("POSTing to %s", propertyTable.url)

	local result, hdrs = LrHttp.postMultipart( propertyTable.url, mimeChunks )

end

publisher.processRenderedPhotos = function( functionContext, exportContext )
	-- See page 54 of the PDF for an example loop.
	
	local exportSession = exportContext.exportSession
	local exportSettings = assert( exportContext.propertyTable )

	local nPhotos = exportSession:countRenditions()
	local progressScope = exportContext:configureProgress {
		title = nPhotos > 1
					and LOC( "POSTing ^1 photos to WebHook", nPhotos )
					or LOC "POSTing one photo to WebHook",
	}

	for i, rendition in exportContext:renditions { stopIfCanceled = true } do
	
		-- Update progress scope.
		
		progressScope:setPortionComplete( ( i - 1 ) / nPhotos )
		
		-- Get next photo.

		local photo = rendition.photo
		
		if not rendition.wasSkipped then

			local success, pathOrMessage = rendition:waitForRender()
			

			progressScope:setPortionComplete( ( i - 0.5 ) / nPhotos )
			if progressScope:isCanceled() then break end
			
			
			if success then
				uploadPhoto( exportSettings, {
					photo = photo,
					filePath = pathOrMessage,
				})
			end

		end
	end
end


return publisher
