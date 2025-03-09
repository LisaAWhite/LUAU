local mod = dmhub.GetModLoading()

RegisterGameType("CharacterFeaturePrefabs")

--an instance of CharacterFeaturePrefabs represents an entire collection of prefabs.
CharacterFeaturePrefabs.name = "New Prefabs"
CharacterFeaturePrefabs.details = ""
CharacterFeaturePrefabs.tableName = "featurePrefabs"

function CharacterFeaturePrefabs.FindPrefab(guid)

	local prefabTable = dmhub.GetTable(CharacterFeaturePrefabs.tableName) or {}

	for k,prefabSet in pairs(prefabTable) do
		local classLevel = prefabSet:GetClassLevel()
		for i,feature in ipairs(classLevel.features) do
			if feature.guid == guid then
				return feature
			end
		end
	end

	return nil
end

function CharacterFeaturePrefabs.GetAllPrefabs()

	local result = {}
	local prefabTable = dmhub.GetTable(CharacterFeaturePrefabs.tableName) or {}

	for k,prefabSet in pairs(prefabTable) do
		local classLevel = prefabSet:GetClassLevel()
		for i,feature in ipairs(classLevel.features) do
			result[feature.guid] = feature
		end
	end

	return result
end

function CharacterFeaturePrefabs.FillDropdownOptions(options)
	local result = {}
	local prefabs = CharacterFeaturePrefabs.GetAllPrefabs()
	for k,prefab in pairs(prefabs) do
		result[#result+1] = {
			id = k,
			text = prefab.name,
		}
	end

	table.sort(result, function(a,b) return a.text < b.text end)
	for i,item in ipairs(result) do
		options[#options+1] = item
	end
end

function CharacterFeaturePrefabs.CreateNew()
	return CharacterFeaturePrefabs.new{
	}
end

--this is where a prefab stores its modifiers etc, which are very similar to what a class gets.
function CharacterFeaturePrefabs:GetClassLevel()
	if self:try_get("modifierInfo") == nil then
		self.modifierInfo = ClassLevel:CreateNew()
	end

	return self.modifierInfo
end

function CharacterFeaturePrefabs:FeatureSourceName()
	return "Character Feature"
end


local SetPrefab = function(tableName, prefabPanel, prefabid)
	local prefabTable = dmhub.GetTable(tableName) or {}
	local prefab = prefabTable[prefabid]
	local UploadPrefab = function()
		dmhub.SetAndUploadTableItem(tableName, prefab)
	end

	local children = {}

	--the name of the prefab.
	children[#children+1] = gui.Panel{
		classes = {'formPanel'},
		gui.Label{
			text = 'Name:',
			valign = 'center',
			minWidth = 240,
		},
		gui.Input{
			text = prefab.name,
			change = function(element)
				prefab.name = element.text
				UploadPrefab()
			end,
		},
	}

	--prefab details/notes.
	children[#children+1] = gui.Panel{
		classes = {'formPanel'},
		height = 'auto',
		gui.Label{
			text = "Notes:",
			valign = "center",
			minWidth = 240,
		},
		gui.Input{
			text = prefab.details,
			multiline = true,
			minHeight = 50,
			height = 'auto',
			width = 400,
			textAlignment = "topleft",
			change = function(element)
				prefab.details = element.text
				UploadPrefab()
			end,
		}
	}

	children[#children+1] = prefab:GetClassLevel():CreateEditor(prefab, 0, {
		change = function(element)
			prefabPanel:FireEvent("change")
			UploadPrefab()
		end,
	})
	prefabPanel.children = children
end

function CharacterFeaturePrefabs.CreateEditor()
	local prefabPanel
	prefabPanel = gui.Panel{
		data = {
			SetPrefab = function(tableName, prefabid)
				SetPrefab(tableName, prefabPanel, prefabid)
			end,
		},
		vscroll = true,
		classes = 'class-panel',
		styles = {
			{
				halign = "left",
			},
			{
				classes = {'class-panel'},
				width = 1200,
				height = '90%',
				halign = 'left',
				flow = 'vertical',
				pad = 20,
			},
			{
				classes = {'label'},
				color = 'white',
				fontSize = 22,
				width = 'auto',
				height = 'auto',
			},
			{
				classes = {'input'},
				width = 200,
				height = 26,
				fontSize = 18,
				color = 'white',
			},
			{
				classes = {'formPanel'},
				flow = 'horizontal',
				width = 'auto',
				height = 'auto',
				halign = 'left',
				vmargin = 2,
			},

		},
	}

	return prefabPanel
end
