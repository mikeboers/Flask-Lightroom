
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrHttp = import 'LrHttp'
local LrPathUtils = import 'LrPathUtils'
local LrLogger = import 'LrLogger'

local bind = LrView.bind
local share = LrView.share

local logger = LrLogger('Flask')

logger:enable("print")
logger:info("Loading module...")


local publisher = {}


-- This is a publisher.
publisher.supportsIncrementalPublish = 'only'


publisher.allowFileFormats = { 'JPEG' }
publisher.allowColorSpaces = { 'sRGB' }

publisher.hideSections = { 'exportLocation', 'video' }
publisher.hidePrintResolution = true
publisher.canExportVideo = false


publisher.exportPresetFields = {
	{key='url', default='http://example.com/api/lightroom'},
	{key='extraData', default=''},
	{key='metadata', default='title,caption,keywordTags'},
}

-- publisher.startDialog = function(propertyTable)
-- end


local function url_decode(url)
	return (url:gsub('+', ' '):gsub("%%(%x%x)", function(encoded)
		return string.char(tonumber(encoded, 16))
	end))
end

function url_split(url)
	local data = {}
	for pair in url:gmatch("[^&]+") do
	    local key, value = pair:match("([^=]*)=(.*)")
	    if not key then
	    	error("Invalid query string")
	   	end
	    data[key] = url_decode(value)
	end
	return data
end


publisher.sectionsForTopOfDialog = function(f, propertyTable)
	return {
		{
			title = "Flask",

			f:row {
				f:static_text {
					title = "Endpoint URL",
					width = share 'FlaskTitleSectionLabel'
				},
				f:edit_field {
					value = bind 'url',
					immediate = false,
					width = 375
				},
			},

			f:row {
				f:static_text {
					title = "HMAC Key",
					width = share 'FlaskTitleSectionLabel'
				},
				f:edit_field {
					value = bind 'hmacKey',
					immediate = false,
					width = 375
				},
			},

			f:row {
				f:static_text {
					title = "Metadata to Include\n(comma or space seperated)",
					width = share 'FlaskTitleSectionLabel'
				},
				f:edit_field {
					value = bind 'metadata',
					immediate = false,
					width = 375,
					height_in_lines = 2,
				},
			},

			f:row {
				f:static_text {
					title = "Extra Data\n(query encoded)",
					width = share 'FlaskTitleSectionLabel'
				},
				f:edit_field {
					value = bind 'extraData',
					immediate = false,
					width = 375,
					height_in_lines = 5,
				},
			},

		}
	}

end


local uploadPhoto = function (propertyTable, params)
	
	local log

	local postData = {}

	-- Include requested metadata.
	for name in string.gmatch(propertyTable.metadata, "%a+") do
		local value = params.photo:getFormattedMetadata(name)
		if value then
			postData[#postData + 1] = {name=name, value=value}
		end
	end

	-- Add extra data over metadata.
	if propertyTable.extraData then
		for name, value in pairs(url_split(propertyTable.extraData)) do
			postData[#postData + 1] = {name=name, value=value}
		end
	end

	-- Log what we are posting.
	log = string.format("POST to %s:", propertyTable.url)
	for i = 1, #postData do
		log = log .. string.format("\n\t%s: \"%s\"", postData[i].name, postData[i].value)
	end
	logger:trace(log)

	-- Add the photo itself.
	local filePath = params.filePath
	local fileName = LrPathUtils.leafName(filePath)
	postData[#postData + 1] = {
		name='photo',
		fileName=fileName,
		filePath=filePath,
		contentType='image/jpeg',
	}


	local body, headers = LrHttp.postMultipart(propertyTable.url, postData, {}, 5)
	logger:tracef("Body: %s", body)

	log = "Response Headers:"
	for i = 1, #headers do
		local header = headers[i]
		log = log .. string.format("\n\t%s: \"%s\"", header.field, header.value)
	end
	logger:trace(log)

end

publisher.processRenderedPhotos = function(functionContext, exportContext)

	-- See page 54 of the PDF for an example loop.
	
	local exportSession = exportContext.exportSession
	local propertyTable = assert(exportContext.propertyTable)

	local nPhotos = exportSession:countRenditions()
	local progressScope = exportContext:configureProgress({
		title = nPhotos > 1
			and string.format("POSTing %d photos to Flask", nPhotos)
			or "POSTing one photo to Flask"
	})

	for i, rendition in exportContext:renditions { stopIfCanceled = true } do
	
		-- Update progress scope.
		
		progressScope:setPortionComplete((i - 1) / nPhotos)
		
		-- Get next photo.

		local photo = rendition.photo
		
		if not rendition.wasSkipped then

			local success, pathOrMessage = rendition:waitForRender()

			progressScope:setPortionComplete((i - 0.5) / nPhotos)
			if progressScope:isCanceled() then break end
			
			
			if success then
				uploadPhoto(propertyTable, {
					photo = photo,
					filePath = pathOrMessage,
				})
			end

		end
	end
end


return publisher
