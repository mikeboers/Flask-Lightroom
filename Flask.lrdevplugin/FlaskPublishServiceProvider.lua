
local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrHttp = import 'LrHttp'
local LrPathUtils = import 'LrPathUtils'
local LrLogger = import 'LrLogger'

local utils = require 'FlaskUtils'


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
	{key='endpointURL', default='http://example.com/api/lightroom'},
	{key='extraHeaders', default=''},
	{key='extraData', default=''},
	{key='metadataToInclude', default='title,caption,keywordTags'},
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
					value = bind 'endpointURL',
					immediate = false,
					width = 375
				},
			},

			f:row {
				f:static_text {
					title = "Extra Headers\n(one per line)",
					width = share 'FlaskTitleSectionLabel'
				},
				f:edit_field {
					value = bind 'extraHeaders',
					immediate = false,
					width = 375,
					height_in_lines = 5,
				},
			},

			f:row {
				f:static_text {
					title = "Metadata to Include\n(comma or space seperated)",
					width = share 'FlaskTitleSectionLabel'
				},
				f:edit_field {
					value = bind 'metadataToInclude',
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
	local postHeaders = {}

	-- Include requested metadata.
	for name in string.gmatch(propertyTable.metadataToInclude, "%a+") do
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

	-- Add published ID
	if params.rendition.publishedPhotoId then
		postData[#postData + 1] = {name="publishedPhotoID", value=params.rendition.publishedPhotoId}
	else
		local globalRemoteId = utils.getServiceMetadata(params.service, params.photo, 'lastRemoteId')
		if globalRemoteId then
			postData[#postData + 1] = {name="publishedPhotoID", value=globalRemoteId}
		end
	end

	-- Add collection name and ID
	postData[#postData + 1] = {name="collectionName", value=params.collection:getName()}
	if params.collection:getRemoteId() then
		postData[#postData + 1] = {name="publishedCollectionID", value=params.collection:getRemoteId()}
	end

	-- Add extra headers.
	for line in string.gmatch(propertyTable.extraHeaders, "[^\n]+") do
		local field, value = string.match(line, "^%s*(%S+)%s*:%s*(.+)%s*$")
		if field and value then
			postHeaders[#postHeaders + 1] = {field=field, value=value}
		end
	end

	-- Log what we are posting.
	log = string.format("POST to %s:", propertyTable.endpointURL)
	for i = 1, #postHeaders do
		log = log .. string.format("\n\t%s: %s", postHeaders[i].field, postHeaders[i].value)
	end
	for i = 1, #postData do
		log = log .. string.format("\n\t%s=\"%s\"", postData[i].name, postData[i].value)
	end
	logger:trace(log)

	-- Add the photo itself.
	local filePath = params.filePath
	local fileName = LrPathUtils.leafName(filePath)
	postData[#postData + 1] = {
		name='photo',
		fileName=fileName,
		filePath=filePath,
		contentType='image/jpeg', -- So far we only allow JPEGs.
	}

	-- POST!
	local body, headers = LrHttp.postMultipart(propertyTable.endpointURL, postData, postHeaders, 5)

	-- Lets be verbose while formating the response.
	local res = {}
	log = string.format("POST returned %s", headers.status)
	for i = 1, #headers do
		local header = headers[i]
		log = log .. string.format("\n\t%s: %s", header.field, header.value)
		res[header.field] = header.value
	end
	logger:trace(log)
	res.status = headers.status

	return res

end

publisher.processRenderedPhotos = function(functionContext, exportContext)

	-- See page 54 of the PDF for an example loop.
	
	local catalog = LrApplication.activeCatalog()
	local session = exportContext.exportSession
	local service = exportContext.publishService
	local propertyTable = assert(exportContext.propertyTable)
	local collection = exportContext.publishedCollection

	local nPhotos = session:countRenditions()
	local progressScope = exportContext:configureProgress({
		title = nPhotos > 1
			and string.format("Uploading %d photos to Flask", nPhotos)
			or "Uploading one photo to Flask"
	})

	for i, rendition in exportContext:renditions { stopIfCanceled = true } do
	
		-- Update progress.
		progressScope:setPortionComplete((i - 1) / nPhotos)
		
		-- Get next photo.
		local photo = rendition.photo
		if not rendition.wasSkipped then

			local success, pathOrMessage = rendition:waitForRender()

			-- Update progress.
			progressScope:setPortionComplete((i - 0.5) / nPhotos)
			if progressScope:isCanceled() then break end
			
			-- Hand off to the uploader.
			if success then

				local res = uploadPhoto(propertyTable, {
					service = service,
					collection = collection,
					rendition = rendition,
					photo = photo,
					filePath = pathOrMessage,
				})

				if (res.status == 200 or res.status == 201) and res.Location and res.Location ~= "" then

					rendition:recordPublishedPhotoId(res.Location)
					rendition:recordPublishedPhotoUrl(res.Location)
					logger:trace(string.format('photo ID/URL %s', res.Location))

					-- We need write access for utils.setServiceMetadata
					-- and for collection:setRemoteId/Url.
					catalog:withWriteAccessDo("FlaskPublishServiceProvider.processRenderedPhotos", function()

						utils.setServiceMetadata(service, photo, 'lastRemoteId', res.Location)

						-- Remember the URL for the collection as well.
						if (res.Link and res.Link ~= "") then
							local linkUrl = string.match(res.Link, "^(.+); rel=collection$")
							if (linkUrl) then
								collection:setRemoteId(linkUrl)
								collection:setRemoteUrl(linkUrl)
								logger:trace(string.format('collection ID/URL %s', linkUrl))
							else
								logger:trace(string.format("malformed link header: %s", res.Link))
							end
						end

					end)

				else
					logger:trace(string.format('Upload failed with code %s and location %s', res.status, res.Location))

				end

			end

		end
	end
end


return publisher
