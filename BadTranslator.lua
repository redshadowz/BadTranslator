BadTranslator = { ["WordDetect"] = {},["Config"] = {0.00001,0.000001}}
local BT_Languages = {}
local BT_Frame = CreateFrame'Frame'
BT_Frame:Hide()
BT_Frame:SetScript('OnEvent', function(self,event,...) self[event](self,event,...) end)
BT_Frame:RegisterEvent("ADDON_LOADED")
function BT_Frame:ADDON_LOADED()
	SLASH_BadTranslator1 = "/bt"
	SLASH_BadTranslator3 = "/badtranslator"
	SlashCmdList["BadTranslator"] = BT_SlashCommand
	BT_Frame:UnregisterEvent("ADDON_LOADED")

	if not BadTranslator then BadTranslator = {} end
	if not BadTranslator["WordDetect"] then BadTranslator["WordDetect"] = {} end
	if not BadTranslator["Config"] then BadTranslator["Config"] = {0.00001,0.000001} end
end
function BT_SlashCommand(arg1)
	local _,_,cmd,param = string.find(arg1, "^ ?(%a+) +(.*)")
	cmd = (cmd and strlower(cmd)) or strlower(arg1)
	if cmd == "" then
		DEFAULT_CHAT_FRAME:AddMessage("'/bt' <message> to display translation.")
		DEFAULT_CHAT_FRAME:AddMessage("'/bt db new' to create a fresh database from installed languages.")
		DEFAULT_CHAT_FRAME:AddMessage("'/bt db add' to add languages to the existing database.")
		DEFAULT_CHAT_FRAME:AddMessage("'/bt db export' to create an exportable database(add only).")
		DEFAULT_CHAT_FRAME:AddMessage("'/bt db export new' to create a fresh exportable database.")
		DEFAULT_CHAT_FRAME:AddMessage("'/bt clear' to wipe export databases.")
		DEFAULT_CHAT_FRAME:AddMessage("'/bt clear all' to clear all databases.")
		DEFAULT_CHAT_FRAME:AddMessage("'/bt list' to show processed languages.")
		DEFAULT_CHAT_FRAME:AddMessage("'/bt dlimit #' words per million for detection = "..(BadTranslator["Config"][1]*1000000).." (Default: 10)")
		DEFAULT_CHAT_FRAME:AddMessage("'/bt xlimit #' words per million for export = "..(BadTranslator["Config"][2]*1000000).." (Default: 1)")
		DEFAULT_CHAT_FRAME:AddMessage("'/bt finish' to finish a previous process that timed out.")
		DEFAULT_CHAT_FRAME:AddMessage("*Exports to BadTranslator.lua in the WTF folder.")
	elseif (cmd == "db" or cmd == "database") and (not param or param == "new" or param == "add" or param == "export" or param == "export new") then
		if not param then
			DEFAULT_CHAT_FRAME:AddMessage("DB options are 'new', 'add', 'export', and 'export new'.") return
		elseif param == "new" then
			BT_GetListOfUsedWords()
		elseif param == "add" then
			BT_GetListOfUsedWords(true)
		elseif param == "export" then
			BT_GetListOfUsedWords(true,true)
		elseif param == "export new" then
			BT_GetListOfUsedWords(nil,true)
		end
	elseif not param and (cmd == "list") then
		if not BadTranslator["LANGUAGES"] then
			DEFAULT_CHAT_FRAME:AddMessage("No languages have been processed.")
		else
			local langString = ""
			for entryName,_ in pairs(BadTranslator["LANGUAGES"]) do langString = langString..strupper(entryName).."," end
			DEFAULT_CHAT_FRAME:AddMessage("Installed: "..strsub(langString,1,-2))
		end
	elseif cmd == "clear" and (not param or param == "all") then
		for entryName,data in pairs(BadTranslator) do if (param == "all" and entryName ~= "Config") or (not param and entryName ~= "WordDetect" and entryName ~= "LANGUAGES" and entryName ~= "Config") then
				DEFAULT_CHAT_FRAME:AddMessage("Cleared "..entryName.."...")
				BadTranslator[entryName] = nil
			end
		end
	elseif (cmd == "dlimit") and (not param or tonumber(param)) then
		if not param then DEFAULT_CHAT_FRAME:AddMessage("No number given. Usage is '/bt dlimit #'") elseif tonumber(param) < 1 or tonumber(param) > 1000000 then DEFAULT_CHAT_FRAME:AddMessage("Number out of range.") else BadTranslator["Config"][1] = tonumber(param)/1000000 DEFAULT_CHAT_FRAME:AddMessage("Detection limit has been set to "..(BadTranslator["Config"][1]*1000000).." words per million.") end
	elseif (cmd == "xlimit") then
		if not param then DEFAULT_CHAT_FRAME:AddMessage("No number given. Usage is '/bt xlimit #'") elseif tonumber(param) < 1 or tonumber(param) > 1000000 then DEFAULT_CHAT_FRAME:AddMessage("Number out of range.") else BadTranslator["Config"][2] = tonumber(param)/1000000 DEFAULT_CHAT_FRAME:AddMessage("Export limit has been set to "..(BadTranslator["Config"][2]*1000000).." words per million.") end
	elseif not param and (cmd == "finish") then
		if BadTranslator["NOTFINISHED"] then BT_GetListOfUsedWords(true,BadTranslator["NOTFINISHED"],true) else DEFAULT_CHAT_FRAME:AddMessage("There is nothing to finish.") end
	else
		arg1 = BT_TranslateString(arg1)
		DEFAULT_CHAT_FRAME:AddMessage(arg1)
	end
end

-- Groupfinder has to keep the original table structure to show translations in chat and menus(not just detection)

function BT_ProcessStringToTable(arg1,getLanguage,noSpaces,savePunctuation,imported)
-- 'noSpaces'(doesn't add spaces after Chinese letters)... 'savePunctuation'(saves Chinese and Ascii punctuation in original table), 'imported'(doesn't check for links)... Returns "wordTable or wordData, tableLen"
-- Table Structure = { [1] = String Snippet = { [1] = Original String, [2] = { [1] = { [1] = original word/number/punctuation/chinese character, [2] = strlower(no ascii) }, [2] = space or blank, [3/4] = repeat pattern from 1/2 }, [2] = repeat pattern from 1 }
	local wordTable,languageID,cTable,wordData,tTable,pTable = {},{},{},{}
	local stringA,stringB,stringC,stringD,stringE
	local strPos,sLastPos,tPos,tVal,pVal,lfs,lfe = 1
	if not imported then
		arg1 = gsub(arg1,"%s%s+"," ")
		while true do -- Save any hyperlinks... This should do urls, hitems/hplayer/hspells/etc...
			if string.find(arg1,"|H") then
				_,lfe,stringA,stringB,stringC,stringD,stringE = string.find(arg1,"(.-)(|[%x%p]+H(%a+).-|h%[)(.-)(%]|h|r)",strPos)
				if stringA then
					if stringA ~= "" then table.insert(wordTable, {stringA}) end
					table.insert(wordTable, stringB)
					table.insert(wordTable, {stringD})
					table.insert(wordTable, stringE)
					strPos = lfe+1
				else
					stringA = string.sub(arg1,strPos)
					if stringA ~= "" then table.insert(wordTable, {string.sub(arg1,strPos)}) end
					break
				end
			else
				table.insert(wordTable, {arg1})
				break
			end
		end
	end
	local tableLen = wordTable[1] and getn(wordTable) or 1
	for i=1, tableLen do
		if imported or wordTable[i][1] then
			if not imported then stringE = wordTable[i][1] wordTable[i][2] = {} tTable = wordTable[i][2] else stringE = arg1 tTable = wordTable end
			strPos = 1
			while true do
				_,lfe,stringA,stringB = string.find(stringE, "(.-)([%s%p%d]+)",strPos) if stringA == "" then table.insert(tTable, {stringB,stringB}) table.insert(tTable, "") strPos = lfe+1 _,lfe,stringA,stringB = string.find(stringE, "(.-)([%s%p%d]+)",strPos) end if not stringA then _,lfe,stringA = string.find(stringE, "(.+)",strPos) stringB = "" if not stringA then break end end
				strPos = lfe+1
				stringC = string.lower(stringA) sLastPos = 1 tPos = 1 pVal = nil
				while true do
					lfs = strbyte(stringC,tPos)
					if not lfs then break end
					if lfs > 127 then
						if BT_WORD_ACCENT_ASCII_LETTERS[lfs] then
							if lfs == 226 then
								lfs = BT_WORD_ACCENT_ASCII_LETTERS[strsub(stringC,tPos,tPos+2)]
								if not lfs then if not BadTranslator["MISSING"] then BadTranslator["MISSING"] = {} end table.insert(BadTranslator["MISSING"],{strPos,stringA,strsub(stringC,tPos,tPos+2),stringE}) if strbyte(stringC,tPos+2) == 128 then lfs = BT_WORD_ACCENT_ASCII_LETTERS[strsub(stringC,tPos,tPos+3)] if not lfs then lfs = strsub(stringC,tPos,tPos+3) end tVal = 4 else lfs = strsub(stringC,tPos,tPos+2) tVal = 3 end else tVal = 3 end
								if lfs ~= pVal then
									if cTable[1] then
										table.insert(tTable, {strsub(stringA,sLastPos,tPos-1),table.concat(cTable)}) cTable = {}
										if lfs == " " then
											table.insert(tTable, " ")
										else
											table.insert(tTable, "")
											table.insert(tTable, { savePunctuation and strsub(stringA,tPos,tPos+2) or lfs, lfs})
											table.insert(tTable, "")
										end
									else
										table.insert(tTable, { savePunctuation and strsub(stringA,tPos,tPos+2) or lfs, lfs})
										table.insert(tTable, "")
									end
								end
								tPos = tPos + tVal
								sLastPos = tPos
							else
								lfs = BT_WORD_ACCENT_ASCII_LETTERS[strsub(stringC,tPos,tPos+1)]
								if not lfs then lfs = strsub(stringC,tPos,tPos+1) if not BadTranslator["MISSING"] then BadTranslator["MISSING"] = {} end table.insert(BadTranslator["MISSING"],{strPos,stringA,strsub(stringC,tPos,tPos+2),stringE}) end
								tPos = tPos + 2
								if lfs ~= pVal then
									table.insert(cTable, lfs)
								elseif BT_WORD_ALLOW_TWO_CHARACTERS[lfs] then
									table.insert(cTable, lfs)
									while true do if BT_WORD_ACCENT_ASCII_LETTERS[strbyte(stringC,tPos)] and BT_WORD_ACCENT_ASCII_LETTERS[strsub(stringC,tPos,tPos+1)] == lfs then tPos = tPos + 2 else break end end
								end
							end
						elseif BT_WORD_ASIAN_LANGUAGES[lfs] then
							lfs = strsub(stringC,tPos,tPos+2)
							if cTable[1] then
								table.insert(tTable, {strsub(stringA,sLastPos,tPos-1),table.concat(cTable)}) cTable = {}
								pTable = BT_WORD_ASIAN_LANGUAGES_PUNCTUATION[lfs]
								table.insert(tTable, (noSpaces or (pTable and not pTable[2]) or (not strbyte(stringC,tPos+3) and BT_WORD_PUNCTUATION_NO_SPACE[strbyte(stringB)])) and "" or " ")
							else
								pTable = BT_WORD_ASIAN_LANGUAGES_PUNCTUATION[lfs]
							end
							if not languageID["cn"] then languageID["cn"] = 1 end
							while true do
								tPos = tPos + 3
								if pTable then -- Punctuation
									table.insert(tTable, {savePunctuation and lfs or pTable[1], pTable[1]})
									table.insert(tTable, (noSpaces or not pTable[2] or (BT_WORD_ASIAN_LANGUAGES_PUNCTUATION[strsub(stringC,tPos,tPos+2)]) or (not strbyte(stringC,tPos) and BT_WORD_PUNCTUATION_NO_SPACE[strbyte(stringB)])) and "" or " ")
								else -- Not punctuation
									table.insert(tTable, {lfs,lfs})
									table.insert(tTable, (noSpaces or BT_WORD_ASIAN_LANGUAGES_PUNCTUATION[strsub(stringC,tPos,tPos+2)] or (not strbyte(stringC,tPos) and BT_WORD_PUNCTUATION_NO_SPACE[strbyte(stringB)])) and "" or " ")
								end
								if BT_WORD_ASIAN_LANGUAGES[strbyte(stringC,tPos)] then
									lfs = strsub(stringC,tPos,tPos+2)
									pTable = BT_WORD_ASIAN_LANGUAGES_PUNCTUATION[lfs]
									languageID["cn"] = languageID["cn"] + 1
								else
									break
								end
							end
							sLastPos = tPos
						else
							tPos = tPos + 1
							table.insert(cTable, strchar(lfs))
						end
					else
						tPos = tPos + 1
						if lfs ~= pVal then
							if lfs == tVal and strbyte(stringC,tPos) == pVal and strbyte(stringC,tPos+1) == lfs then
								table.insert(cTable, strsub(stringC,tPos-1,tPos))
								tPos = tPos + 2
								while true do if strbyte(stringC,tPos) == pVal then tPos = tPos + 1 if strbyte(stringC,tPos) == lfs then tPos = tPos + 1 else break end else break end end
							else
								table.insert(cTable, strchar(lfs))
							end
						elseif BT_WORD_ALLOW_TWO_CHARACTERS[lfs] then
							table.insert(cTable, strchar(lfs))
							tVal = strbyte(stringC,tPos)
							if tVal == lfs then if tVal == 105 then table.insert(cTable, "i") end tPos = tPos + 1 while true do if strbyte(stringC,tPos) == lfs then tPos = tPos + 1 else break end end end
						end					
					end
					tVal = pVal
					pVal = lfs
				end
				stringC = table.concat(cTable)
				table.insert(tTable, {strsub(stringA,sLastPos),stringC})
				if stringB == " " then
					table.insert(tTable, " ")
				else
					cTable = {} tPos = 1 tVal = nil pVal = nil
					while true do -- Separate spaces from stringB
						lfs = strsub(stringB,tPos,tPos)
						if lfs ~= pVal then
							if lfs == " " then
								if cTable[1] then
									stringD = table.concat(cTable)
									if not tVal then table.insert(tTable, "") end
									table.insert(tTable, {stringD,stringD})
									cTable = {}
								end
								table.insert(tTable, " ")
								while true do if strbyte(stringB,tPos+1) == 32 then tPos = tPos + 1 else break end end
								tVal = true
							else
								if lfs == "" then break end
								if lfs ~= pVal then table.insert(cTable, lfs) end
							end
							pVal = lfs
						end
						tPos = tPos + 1
					end
					stringB = table.concat(cTable)
					if cTable[1] then if not tVal then table.insert(tTable, "") end table.insert(tTable, {stringB,stringB}) table.insert(tTable, "") elseif not tVal then table.insert(tTable, stringB) end
				end
				if getLanguage and BadTranslator["WordDetect"][stringC] then for lang,_ in pairs(BadTranslator["WordDetect"][stringC]) do if not languageID[lang] then languageID[lang] = 1 else languageID[lang] = languageID[lang] + 1 end end end
				cTable = {}
			end
		end
	end
	if getLanguage then
		tVal = 0
		for langID,totalLang in pairs(languageID) do if totalLang > tVal then tVal = totalLang end end
		for langID,totalLang in pairs(languageID) do
			if totalLang > tVal/2 then
				wordData[langID] = {}
				for j=1, getn(wordTable) do
					wordData[langID][j] = {}
					if wordTable[j][1] then for i=1, getn(wordTable[j][2]) do table.insert(wordData[langID][j], wordTable[j][2][i]) end else wordData[langID][j] = wordTable[j] end
				end
			end
		end
		if tVal == 0 then
			wordData["en"] = {}
			for j=1, getn(wordTable) do
				wordData["en"][j] = {}
				if wordTable[j][1] then for i=1, getn(wordTable[j][2]) do table.insert(wordData["en"][j], wordTable[j][2][i]) end else wordData["en"][j] = wordTable[j] end
			end
		end
		return wordData, tableLen
	else
		return wordTable, tableLen
	end
end
function BT_TranslateString(arg1)
-- Can run 1000 times of " La Guild Leyendas Latam - Busca TANKES DPS HEALS - Lows para subir lvl, MAZMORRAS - QUEST ETC - SUSURRAM" in 150-220 ms.. This is on a 2014 mid-range processor.... old was 250 ms, new is 190 ms
-- Can run 1000 times of "黑石深淵任務團來法師，會路線++" in about 170 ms.. or about .017 ms.... Old was 170 ms.. new is 150 ms
-- Something I didn't expect, the more languages installed, the worse the performance. If only Spanish, I get 190 MS. With all languages installed, I get 320 ms... For Chinese alone I get 150 ms. With all languages I get 180 ms.
	local wordData,tableLen = BT_ProcessStringToTable(arg1,true) -- arg1,getLanguage,noSpaces,savePunctuation,imported
	local stringA,lfs,lfe,tLen = {}
	local languageName = "en"
	local prevTotal,totalFound = 0
	for languageID,data in pairs(wordData) do
		totalFound = 0
		if languageID ~= "en" and BT_Languages[languageID] then
			if languageID == "cn" then lfe = 18 else lfe = 6 end
			for i=1, tableLen do
				if data[i][1] then
					tLen = getn(data[i])
					for j=lfe,2,-2 do
						lfs = 1
						while lfs+j <= tLen do
							stringA = data[i][lfs][2]
							if stringA then
								for k=2, j, 2 do stringA = stringA..data[i][lfs+k][2] end
								if BT_UNIQUE_SINGLE_WORDS[languageID][stringA] then
									data[i][lfs] = {BT_UNIQUE_SINGLE_WORDS[languageID][stringA],"Z"} -- The Z is placeholder since multiple/single is processed separately
									for k=1, j do table.remove(data[i],lfs+1) tLen=tLen-1 end
									totalFound = totalFound + 1
								end
								lfs = lfs + 2
							else
								break
							end
						end
					end
					if languageID == "cn" then
						for j=1, tLen, 2 do
							stringA = data[i][j][2]
							if BT_UNIQUE_SINGLE_WORDS[languageID][stringA] then
								data[i][j] = BT_UNIQUE_SINGLE_WORDS[languageID][stringA]
								totalFound = totalFound + 1
							else
								data[i][j] = data[i][j][1]
							end
						end
					else
						for j=1, tLen, 2 do
							stringA = data[i][j][2]
							if BT_WORD_PUNCTUATION_NO_SPACE[strbyte(stringA)] then
								if BT_WORD_PUNCTUATION_CONNECTING[stringA] and j > 2 and tLen > j+2 then
									stringA = data[i][j-2][2]..data[i][j+2][2]
									if BT_UNIQUE_SINGLE_WORDS[languageID][stringA] then
										data[i][j] = BT_UNIQUE_SINGLE_WORDS[languageID][stringA]
										totalFound = totalFound + 1
									else
										data[i][j] = data[i][j][1]
									end
								else
									data[i][j] = data[i][j][1]
								end
							else
								if strlen(stringA) <= 3 then stringA = strlower(data[i][j][1]) end
								if BT_UNIQUE_SINGLE_WORDS[languageID][stringA] then
									data[i][j] = BT_UNIQUE_SINGLE_WORDS[languageID][stringA]
									totalFound = totalFound + 1
								else
									data[i][j] = data[i][j][1]
								end
							end
						end
					end
					data[i] = table.concat(data[i])
				end
			end
		else
			for i=1, tableLen do
				if data[i][1] then
					for j=1, getn(data[i]),2 do
						if BT_UNIQUE_SINGLE_WORDS[languageID][data[i][j][1]] then totalFound = totalFound + 1 elseif not BT_WORD_PUNCTUATION_NO_SPACE[strbyte(data[i][j][2])] then totalFound = totalFound + .25 end
						data[i][j] = data[i][j][1]
					end
					data[i] = table.concat(data[i])
				end
			end
		end
		if totalFound > prevTotal then languageName = languageID prevTotal = totalFound end
	end
	return table.concat(wordData[languageName]), languageName
end
function BT_ConvertBaseList(export) -- /script BT_ConvertBaseList() /script BT_ConvertBaseList(true)
-- This is for processing imported wordlists(["word"] = "translation")
-- Need to split single word from multi-word for detection
-- Can I import/split German compound words for items? when importing Chinese, can I split for proper names? automatically add for proper name and title or whatever.
	local StringA1,StringB1,StringC1,StringE1,StringB2,StringE2
	local wordTable,tempTable
	BadTranslator["IMPORTED"] = {}
	if export then BadTranslator["POSSIBLE"] = {} end
	for arg1,arg2 in pairs(BT_IMPORT_FOR_PROCESSING) do -- A)Original word, B) No Ascii letters, C) Include [!+-.,<=>] D) No punctuation E) No spaces
		wordTable = BT_ProcessStringToTable(arg1,nil,true,true,true) -- First word... arg1,getLanguage,noSpaces,savePunctuation,imported
		tempTable = BT_ProcessStringToTable(arg2,nil,true,true,true) -- Translation
		StringE1,StringE2 = "","","",""
		for j=1, getn(wordTable),2 do if not BT_WORD_PUNCTUATION_NO_SPACE[strbyte(wordTable[j][2])] then StringE1 = StringE1..wordTable[j][2] end end -- StringE1(stripped no spaces)
		for j=1, getn(tempTable),2 do if not BT_WORD_PUNCTUATION_NO_SPACE[strbyte(tempTable[j][2])] then StringE2 = StringE2..tempTable[j][2] end end -- StringE2(stripped)
		if StringE1 ~= StringE2 and (not export or not BT_EXCLUSIONS[StringE1]) then
			StringA1,StringB1,StringC1,StringB2 = "","",""
			for j=1, getn(wordTable),2 do -- StringA1,StringB1,StringC1... Always remove all spaces.
				StringA1 = StringA1..wordTable[j][1]
				StringB1 = StringB1..wordTable[j][2]
				if BT_WORD_PUNCTUATION_REPLACE[strbyte(wordTable[j][2])] then StringC1 = StringC1..BT_WORD_PUNCTUATION_REPLACE[strbyte(wordTable[j][2])] else StringC1 = StringC1..wordTable[j][2] end
			end
			if export then -- If exporting, only include word without punctuation
				for j=1, getn(tempTable),2 do if BT_WORD_PUNCTUATION_REPLACE[strbyte(tempTable[j][2])] then StringB2 = StringB2..BT_WORD_PUNCTUATION_REPLACE[strbyte(tempTable[j][2])] else StringB2 = StringB2..tempTable[j][2] end end -- StringB2
			else -- If not exporting, include original word if <= 3 letters, word without ascii, word without most punctuation, and fully stripped word.
				for j=1, getn(tempTable),2 do StringB2 = StringB2..tempTable[j][2]..tempTable[j+1] end
				if strlen(StringE1) <= 3 then BadTranslator["IMPORTED"][StringA1] = StringB2 end
				BadTranslator["IMPORTED"][StringB1] = StringB2
				BadTranslator["IMPORTED"][StringC1] = StringB2
			end
			BadTranslator["IMPORTED"][StringE1] = StringB2
		end
		if export then
			for j=1, getn(wordTable),2 do
				if not BadTranslator["IMPORTED"][wordTable[j][2]] then BadTranslator["POSSIBLE"][wordTable[j][2]] = StringE2 end
			end
		end
	end
end
function BT_GetListOfUsedWords(addOnly,export,finishOnly)
-- This is for building the word detection database. It's also for exporting words to groupfinder, and for finding potential words for further translation.
	local origTime = GetTime()
	local wordTable,wordString = {}
	if not finishOnly then if addOnly then if not BadTranslator["WordDetect"] then BadTranslator["WordDetect"] = {} end if not BadTranslator["LANGUAGES"] then BadTranslator["LANGUAGES"] = {} end else for entryName,data in pairs(BadTranslator) do if entryName ~= "Config" then BadTranslator[entryName] = nil end end BadTranslator["WordDetect"] = {} BadTranslator["LANGUAGES"] = {} end BadTranslator["WordList"] = {} BadTranslator["TOTALWORDS"] = {} if export then BadTranslator["OTHER"] = {} BadTranslator["Export"] = { ["WordList"] = {},["WordDetect"] = {} } end else if not BadTranslator["WordList"] or not BadTranslator["WordDetect"] or not BadTranslator["LANGUAGES"] or not BadTranslator["TOTALWORDS"] then DEFAULT_CHAT_FRAME:AddMessage("An error has occurred while trying to finish.") BadTranslator["NOTFINISHED"] = nil return end end
	for entryName,data in pairs(BT_LANGUAGE_DETECT) do if not BadTranslator["WordDetect"][entryName] then BadTranslator["WordDetect"][entryName] = data end end -- Add hardcoded English words
	for languageID,wtable in pairs(BT_FOREIGN_CONVERT) do
		if not wtable["SKIP"] and (not addOnly or not BadTranslator["LANGUAGES"][languageID]) then
			local langTime = GetTime()
			if GetTime()-origTime > 30 then BadTranslator["NOTFINISHED"] = export DEFAULT_CHAT_FRAME:AddMessage("Processed for "..(ceil((GetTime()-origTime)*100)/100).." seconds. Stopping. To finish processing, type '/bt finish'.") return end
			BadTranslator["WordList"][languageID] = {}
			if export then BadTranslator["OTHER"][languageID] = {} end
			BadTranslator["TOTALWORDS"][languageID] = 0
			for i=1, getn(wtable) do
				wordTable = BT_ProcessStringToTable(wtable[i],nil,true,true,true)
				for j=1, getn(wordTable), 2 do
					wordString = wordTable[j][2]
					if wordString ~= "" and not BT_WORD_PUNCTUATION_NO_SPACE[strbyte(wordString)] then
						if BT_UNIQUE_SINGLE_WORDS[languageID][wordString] then
							if not BadTranslator["WordList"][languageID][wordString] then BadTranslator["WordList"][languageID][wordString] = { BT_UNIQUE_SINGLE_WORDS[languageID][wordString],1} else BadTranslator["WordList"][languageID][wordString][2] = BadTranslator["WordList"][languageID][wordString][2] + 1 end
						elseif wordTable[j+4] and BT_WORD_PUNCTUATION_CONNECTING[wordTable[j+2][2]] and BT_UNIQUE_SINGLE_WORDS[languageID][wordString..wordTable[j+4][2]] then
							wordString = wordString..wordTable[j+4][2]
							if not BadTranslator["WordList"][languageID][wordString] then BadTranslator["WordList"][languageID][wordString] = { BT_UNIQUE_SINGLE_WORDS[languageID][wordString],1} else BadTranslator["WordList"][languageID][wordString][2] = BadTranslator["WordList"][languageID][wordString][2] + 1 end
						else
							if export and strlen(wordString) > 2 and not BadTranslator["OTHER"][languageID][wordTable[j][1]] and not BT_EXCLUSIONS[wordString] and (BT_ENGLISH_WORDS and not BT_ENGLISH_WORDS[wordString] or not BadTranslator["WordDetect"][wordString]) then BadTranslator["OTHER"][languageID][wordTable[j][1]] = true if wordTable[j+4] and BT_WORD_PUNCTUATION_CONNECTING[wordTable[j+2][2]] and wordTable[j+4][2] == "s" then BadTranslator["OTHER"][languageID][wordTable[j][1]..wordTable[j+4][1]] = true end end
						end
						BadTranslator["TOTALWORDS"][languageID] = BadTranslator["TOTALWORDS"][languageID] + 1
					end
				end
			end
			DEFAULT_CHAT_FRAME:AddMessage("Processed ("..strupper(languageID)..") in "..(ceil((GetTime()-langTime)*100)/100).." seconds.")
		else
			DEFAULT_CHAT_FRAME:AddMessage("Skipping ("..strupper(languageID)..")...")
		end
		BadTranslator["LANGUAGES"][languageID] = true
	end
	for languageID,wtable in pairs(BadTranslator["WordList"]) do
		for word,dtable in pairs(wtable) do
			if strlen(word) > 3 and not BT_EXCLUSIONS[word] and (languageID == "en" or not BT_ENGLISH_WORDS or not BT_ENGLISH_WORDS[word]) and (dtable[2] / BadTranslator["TOTALWORDS"][languageID]) > BadTranslator["Config"][1] then -- Languages have ~400-800k words
				if not BadTranslator["WordDetect"][word] then BadTranslator["WordDetect"][word] = {} BadTranslator["WordDetect"][word][languageID] = true end
			end
		end
	end
	if export then
		for languageID,wtable in pairs(BadTranslator["WordList"]) do
			local totalLang = 0
			BadTranslator["Export"]["WordList"][languageID] = {}
			for word,dtable in pairs(wtable) do
				if (dtable[2] / BadTranslator["TOTALWORDS"][languageID]) > BadTranslator["Config"][2] then BadTranslator["Export"]["WordList"][languageID][word] = dtable[1] totalLang = totalLang + 1 end
			end
			DEFAULT_CHAT_FRAME:AddMessage("Exported "..totalLang.." ("..strupper(languageID)..") words.")
		end
		local totalDetect = 0
		for word,wtable in pairs(BadTranslator["WordDetect"]) do
			BadTranslator["Export"]["WordDetect"][word] = "{"
			for languageID,_ in pairs(wtable) do BadTranslator["Export"]["WordDetect"][word] = BadTranslator["Export"]["WordDetect"][word].."[\""..languageID.."\"] = true," end
			BadTranslator["Export"]["WordDetect"][word] = BadTranslator["Export"]["WordDetect"][word].."},"
			totalDetect = totalDetect + 1
		end
		DEFAULT_CHAT_FRAME:AddMessage("Exported "..totalDetect.." detection words.")
	else
		BadTranslator["Export"] = nil
	end
	BadTranslator["WordList"] = nil
	BadTranslator["TOTALWORDS"] = nil
	BadTranslator["NOTFINISHED"] = nil
	DEFAULT_CHAT_FRAME:AddMessage("Finished processing languages.")
end

function BT_LinkDatabase(language,origDB,importedDB) -- This is for registering language databases. It's called by the individual database addons.
	origDB[language] = importedDB
	BT_Languages[language] = true
end
function BT_SeparateImportedSentencesByLanguage() -- /script BT_SeparateImportedSentencesByLanguage()
-- This reads all sentences in BT_IMPORT_FOR_PROCESSING and splits them by language... I used it when importing discord messages to make sure the sentences were foreign and not English in a non-English channel. Should probably run again.
	local languageID
	BadTranslator["Separate"] = {}
	for i=1, getn(BT_IMPORT_FOR_PROCESSING) do
		_,languageID = BT_TranslateString(BT_IMPORT_FOR_PROCESSING[i])
		if not BadTranslator["Separate"][languageID] then BadTranslator["Separate"][languageID] = {} end
		table.insert(BadTranslator["Separate"][languageID], BT_IMPORT_FOR_PROCESSING[i])
	end
end

local displayposition = 1 -- This was just for reading through Chinese to see how well the translator is doing(it's terrible btw).
function BT_ReadChinese() -- /script BT_ReadChinese()
	for i=1, 10 do DEFAULT_CHAT_FRAME:AddMessage(BT_TranslateString(BT_CHINESE_CONVERT[displayposition])) displayposition = displayposition + 1 end
end