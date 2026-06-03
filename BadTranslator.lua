BadTranslator = { ["WordList"] = {},["WordDetect"] = {} }
local BT_Languages = {}
local BT_Frame = CreateFrame'Frame'
BT_Frame:Hide()
BT_Frame:SetScript('OnEvent', function(self,event,...) self[event](self,event,...) end)
BT_Frame:RegisterEvent("ADDON_LOADED")
function BT_Frame:ADDON_LOADED()
	SLASH_BadTranslator1 = "/bt"
	SLASH_BadTranslator2 = "/translate"
	SLASH_BadTranslator3 = "/badtranslator"
	SlashCmdList["BadTranslator"] = BT_Slash_Command
	BT_Frame:UnregisterEvent("ADDON_LOADED")

	local ascii = "«àćœƒțЖфґ—"
	BT_DetectAscii = {} -- Make Ascii byte detection
	for i=1, strlen(ascii),2 do BT_DetectAscii[strsub(ascii,i,i)] = true end
	local chinese = "價“《一怀瀑耀退兀"
	BT_DetectChinese = {} -- Make Chinese byte detection
	for i=1, strlen(chinese),3 do BT_DetectChinese[strsub(chinese,i,i)] = true end
	BT_DetectPunctuation = strsub("—",1,1)
end
BT_Slash_Command = function(arg1)
	if arg1 and gsub(strlower(arg1),"[%p%s]","") == "database" or gsub(strlower(arg1),"[%p%s]","") == "db" then if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("Building database...") end BT_GetListOfUsedWords() if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("Finished building database.") end
	elseif arg1 and arg1 ~= "" then if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(BT_TranslateString(arg1)) end
	else DEFAULT_CHAT_FRAME:AddMessage("'/bt/translate/badtranslator' <message> to display translation.") if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("'/bt database/db' to build a database from installed languages.") end end
end

-- Need to split single word from multi-word for detection
-- Can I import/split German compound words for items? when importing Chinese, can I split for proper names? automatically add for proper name and title or whatever... do same for words with '
-- "gogogogo" and letter/space/letter/space trimming would need to be done postprocessing or in groupfinder itself
-- Need to put Chinese into groupfinder, need to auto-translate with groupfinder
-- need to add BT_EXCLUSIONS for every mob or quest name(BT_EXCLUSIONS should apply to the entire wordlists, and even word imports)

-- Import/export needs to remove punctuation(')... option for returning with or without apostrophe

function BT_ProcessStringToTable(arg1,getLanguage,forGroupFinder,noSpaces,savePunctuation,notFromWoW)
-- 'savePunctuation'(saves Chinese and Ascii punctuation in original table), 'notFromWoW'(doesn't check for links)... 'forGroupFinder'(strips links and most punctuation)... 'noSpaces'(doesn't add spaces after Chinese letters)
-- Returns "wordTable,languageName"...  Table Structure = { [1] = String Snippet = { [1] = Original Snippet, [2] = { [1] = { [1] = original word or number or punctuation or chinese character, [2] = removed ascii }, [2] = space or blank, repeat pattern for [1]/[2] }, [2] = repeat }
	local languageName = "en"
	local wordTable,languageID,cTable,tTable,pTable = {},{},{}
	local stringA,stringB,stringC,stringD,stringE,runAlways
	local strPos,sLastPos,tPos,tVal,pVal,lfs,lfe = 1

	if notFromWoW then
		stringE = arg1
		tTable = wordTable
		runAlways = true
	elseif forGroupFinder then
		stringE = gsub(arg1, "|[%x%p]+H%a+.-|h%[(.-)%]|h|r"," %1 ")
		tTable = wordTable
		runAlways = true
	else
		arg1 = gsub(arg1,"%s%s+"," ")
		while true do -- Save any hyperlinks... This should do urls, hitems/hplayer/hspells/etc...
			if string.find(arg1,"|H") then
				_,lfe,stringA,stringB,stringC,stringD,stringE = string.find(arg1,"(.-)(|[%x%p]+H(%a+).-|h%[)(.-)(%]|h|r)",strPos)
				if stringA then
					table.insert(wordTable, {stringA})
					table.insert(wordTable, stringB)
					table.insert(wordTable, {stringD})
					table.insert(wordTable, stringE)
					strPos = lfe+1
				else
					table.insert(wordTable, {string.sub(arg1,strPos)})
					break
				end
			else
				table.insert(wordTable, {arg1})
				break
			end
		end
	end
	local tLen = wordTable[1] and getn(wordTable) or 1
	for i=1, tLen do
		if runAlways or wordTable[i][1] then
			if not runAlways then stringE = wordTable[i][1] wordTable[i][2] = {} tTable = wordTable[i][2] end
			strPos = 1
			while true do
				_,lfe,stringA,stringB = string.find(stringE, "(.-)([%s%p%d]+)",strPos) if stringA == "" then table.insert(tTable, {stringB,stringB}) table.insert(tTable, "") strPos = lfe+1 _,lfe,stringA,stringB = string.find(stringE, "(.-)([%s%p%d]+)",strPos) end if not stringA then _,lfe,stringA = string.find(stringE, "(.+)",strPos) stringB = "" if not stringA then break end end
				strPos = lfe+1
				stringC = string.lower(stringA) sLastPos = 1 tPos = 1 pVal = nil
				while true do
					lfs = strsub(stringC,tPos,tPos)
					if lfs == "" then break end
					if BT_DetectAscii[lfs] then
						if lfs == BT_DetectPunctuation then
							lfs = BT_WORD_ACCENT_ASCII_LETTERS[strsub(stringC,tPos,tPos+2)]
							if not lfs then if not BadTranslator["MISSING"] then BadTranslator["MISSING"] = {} end table.insert(BadTranslator["MISSING"],{strPos,stringA,strsub(stringC,tPos,tPos+2),stringE}) if strbyte(stringC,tPos+2) == 128 then lfs = BT_WORD_ACCENT_ASCII_LETTERS[strsub(stringC,tPos,tPos+3)] if not lfs then lfs = strsub(stringC,tPos,tPos+3) end tVal = 3 else lfs = strsub(stringC,tPos,tPos+2) tVal = 2 end else tVal = 2 end
							if lfs ~= pVal then
								if cTable[1] then
									table.insert(tTable, {strsub(stringA,sLastPos,tPos-1),table.concat(cTable)}) cTable = {}
									if lfs == " " then
										table.insert(tTable, " ")
									else
										table.insert(tTable, "")
										table.insert(tTable, { savePunctuation and strsub(stringA,tPos,tPos+2) or lfs, forGroupFinder and BT_WORD_PUNCTUATION_REPLACE[lfs] or lfs})
										table.insert(tTable, "")
									end
								else
									table.insert(tTable, { savePunctuation and strsub(stringA,tPos,tPos+2) or lfs, forGroupFinder and BT_WORD_PUNCTUATION_REPLACE[lfs] or lfs})
									table.insert(tTable, "")
								end
							end
							tPos = tPos + 3
							sLastPos = tPos
						else
							lfs = BT_WORD_ACCENT_ASCII_LETTERS[strsub(stringC,tPos,tPos+1)]
							if not lfs then lfs = strsub(stringC,tPos,tPos+1) if not BadTranslator["MISSING"] then BadTranslator["MISSING"] = {} end table.insert(BadTranslator["MISSING"],{strPos,stringA,strsub(stringC,tPos,tPos+2),stringE}) end
							tPos = tPos + 2
							if lfs ~= pVal then
								table.insert(cTable, lfs)
							elseif BT_WORD_ALLOW_TWO_CHARACTERS[lfs] then
								table.insert(cTable, lfs)
								while true do if BT_DetectAscii[strbyte(stringC,tPos)] and BT_WORD_ACCENT_ASCII_LETTERS[strsub(stringC,tPos,tPos+1)] == lfs then tPos = tPos + 2 else break end end
							end
						end
					elseif BT_DetectChinese[lfs] then
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
								table.insert(tTable, {savePunctuation and lfs or pTable[1], forGroupFinder and BT_WORD_PUNCTUATION_REPLACE[pTable[1]] or pTable[1]})
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
						if lfs ~= pVal then
							table.insert(cTable, lfs)
						elseif BT_WORD_ALLOW_TWO_CHARACTERS[lfs] then
							table.insert(cTable, lfs)
							tVal = strsub(stringC,tPos,tPos)
							if tVal == lfs then
								if tVal == "i" then table.insert(cTable, lfs) end
								tPos = tPos + 1
								while true do if strsub(stringC,tPos,tPos) == lfs then tPos = tPos + 1 else break end end
							end
						end					
					end
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
								if lfs ~= pVal then table.insert(cTable, forGroupFinder and BT_WORD_PUNCTUATION_REPLACE[lfs] or lfs) end
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
		lfe = 0
		for langID,totalLang in pairs(languageID) do if totalLang > lfe then lfe = totalLang languageName = langID end end -- find language
	end
	return wordTable, languageName, tLen
end
function BT_TranslateString(arg1)
-- Can run 1000 times of " La Guild Leyendas Latam - Busca TANKES DPS HEALS - Lows para subir lvl, MAZMORRAS - QUEST ETC - SUSURRAM" in 150-220 ms.. This is on a 2014 mid-range processor.... old was 250 ms, new is 190 ms
-- Can run 1000 times of "黑石深淵任務團來法師，會路線++" in about 170 ms.. or about .017 ms.... Old was 170 ms.. new is 150 ms
-- Something I didn't expect, the more languages installed, the worse the performance. If only Spanish, I get 190 MS. With all languages installed, I get 320 ms... For Chinese alone I get 150 ms. With all languages I get 180 ms.
	local wordTable,languageName,tLen = BT_ProcessStringToTable(arg1,true) -- arg1,getLanguage,forGroupFinder,noSpaces,savePunctuation,notFromWoW
	local stringA,lfs,lfe,tPos
	if languageName ~= "en" and BT_Languages[languageName] then
		if languageName == "cn" then lfe = 18 else lfe = 6 end
		for i=1, tLen do
			if wordTable[i][1] then
				tPos = getn(wordTable[i][2])
				for j=lfe,2,-2 do
					lfs = 1
					while lfs+j <= tPos do
						stringA = wordTable[i][2][lfs][2]
						if stringA then
							for k=2, j, 2 do stringA = stringA..wordTable[i][2][lfs+k][2] end
							if BT_UNIQUE_SINGLE_WORDS[languageName][stringA] then
								wordTable[i][2][lfs] = {BT_UNIQUE_SINGLE_WORDS[languageName][stringA],"Z"}
								for k=1, j do table.remove(wordTable[i][2],lfs+1) tPos=tPos-1 end
							end
							lfs = lfs + 2
						end
					end
				end
				if languageName == "cn" then
					for j=1, tPos, 2 do
						stringA = wordTable[i][2][j][2]
						if BT_UNIQUE_SINGLE_WORDS[languageName][stringA] then
							wordTable[i][2][j] = BT_UNIQUE_SINGLE_WORDS[languageName][stringA]
						else
							wordTable[i][2][j] = wordTable[i][2][j][1]
						end
					end
				else
					for j=1, tPos, 2 do
						stringA = wordTable[i][2][j][2]
						if strlen(stringA) <= 3 then stringA = strlower(wordTable[i][2][j][1]) end
						if BT_UNIQUE_SINGLE_WORDS[languageName][stringA] then
							wordTable[i][2][j] = BT_UNIQUE_SINGLE_WORDS[languageName][stringA]
						else
							wordTable[i][2][j] = wordTable[i][2][j][1]
						end
					end
				end
				wordTable[i] = table.concat(wordTable[i][2])
			end
		end
	else
		for i=1, tLen do
			if wordTable[i][1] then
				for j=1, getn(wordTable[i][2]),2 do
					wordTable[i][2][j] = wordTable[i][2][j][1]
				end
				wordTable[i] = table.concat(wordTable[i][2])
			end
		end
	end
	return table.concat(wordTable), languageName
end
function BT_ConvertBaseList(export) -- /script BT_ConvertBaseList() /script BT_ConvertBaseList(true)
	local StringA1,StringB1,StringC1,StringE1,StringB2,StringE2
	local wordTable,tempTable
	BadTranslator["IMPORTED"] = {}
	for arg1,arg2 in pairs(BT_FOREIGN_CONVERT["IMPORTED"]) do -- A)Original word, B) No Ascii letters, C) Include [!+-.,<=>] D) No punctuation E) No spaces
		wordTable = BT_ProcessStringToTable(arg1,nil,nil,true,true,true) -- First word... arg1,getLanguage,forGroupFinder,noSpaces,savePunctuation,notFromWoW
		tempTable = BT_ProcessStringToTable(arg2,nil,nil,true,true,true) -- Translation
		StringE1,StringE2 = "","","",""
		for j=1, getn(wordTable),2 do if not BT_WORD_PUNCTUATION_NO_SPACE[strbyte(wordTable[j][2])] then StringE1 = StringE1..wordTable[j][2] end end -- StringE1(stripped no spaces)
		for j=1, getn(tempTable),2 do if not BT_WORD_PUNCTUATION_NO_SPACE[strbyte(tempTable[j][2])] then StringE2 = StringE2..tempTable[j][2] end end -- StringE2(stripped)
		if StringE1 ~= StringE2 and (not export or not BT_EXCLUSIONS[StringE1]) then
			StringA1,StringB1,StringC1,StringB2 = "","",""
			for j=1, getn(wordTable),2 do -- StringA1,StringB1,StringC1... Always remove all spaces.
				StringA1 = StringA1..wordTable[j][1]
				StringB1 = StringB1..wordTable[j][2]
				if BT_WORD_PUNCTUATION_FIX[strbyte(wordTable[j][2])] then StringC1 = StringC1..BT_WORD_PUNCTUATION_FIX[strbyte(wordTable[j][2])] else StringC1 = StringC1..wordTable[j][2] end
			end
			if export then -- If exporting, only include word without punctuation
				for j=1, getn(tempTable),2 do if BT_WORD_PUNCTUATION_FIX[strbyte(tempTable[j][2])] then StringB2 = StringB2..BT_WORD_PUNCTUATION_FIX[strbyte(tempTable[j][2])] else StringB2 = StringB2..tempTable[j][2] end end -- StringB2
			else -- If not exporting, include original word if <= 3 letters, word without ascii, word without most punctuation, and fully stripped word.
				for j=1, getn(tempTable),2 do StringB2 = StringB2..tempTable[j][2]..tempTable[j+1] end
				if strlen(StringE1) <= 3 then BadTranslator["IMPORTED"][StringA1] = StringB2 end
				BadTranslator["IMPORTED"][StringB1] = StringB2
				BadTranslator["IMPORTED"][StringC1] = StringB2
			end
			BadTranslator["IMPORTED"][StringE1] = StringB2
		end
-- TODO: If export, go through each word in StringA1 longer than 3 letters. If not already in the database export them to a separate list.
	end
end
function BT_GetListOfUsedWords(export,addOnly) -- /script BT_GetListOfUsedWords(true) /script BT_GetListOfUsedWords()
	local totalwords,wordTable,wordString = {}
	if addOnly then BadTranslator["WordList"] = {} else BadTranslator = { ["WordList"] = {}, ["WordDetect"] = {} } end
	for entryName,data in pairs(BT_LANGUAGE_DETECT) do if not BadTranslator["WordDetect"][entryName] then BadTranslator["WordDetect"][entryName] = data end end
	if export then BadTranslator["OTHER"] = {} end
	for languageID,wtable in pairs(BT_FOREIGN_CONVERT) do
		if languageID ~= "IMPORTED" and not wtable["SKIP"] then
			BadTranslator["WordList"][languageID] = {}
			if export then BadTranslator["OTHER"][languageID] = {} end
			totalwords[languageID] = 0
			for i=1, getn(wtable) do
				wordTable = BT_ProcessStringToTable(wtable[i],nil,nil,true,true,true) -- arg1,getLanguage,forGroupFinder,noSpaces,savePunctuation,notFromWoW
				for j=1, getn(wordTable), 2 do
					wordString = wordTable[j][2]
					if wordString ~= "" and not BT_WORD_PUNCTUATION_NO_SPACE[strbyte(wordString)] then
						if BT_UNIQUE_SINGLE_WORDS[languageID][wordString] then
							if not BadTranslator["WordList"][languageID][wordString] then BadTranslator["WordList"][languageID][wordString] = { BT_UNIQUE_SINGLE_WORDS[languageID][wordString],1} else BadTranslator["WordList"][languageID][wordString][2] = BadTranslator["WordList"][languageID][wordString][2] + 1 end
						else
							if export and not BadTranslator["OTHER"][languageID][wordTable[j][1]] and BT_ENGLISH_WORDS and not BT_ENGLISH_WORDS[wordString] and strlen(wordString) > 2 then BadTranslator["OTHER"][languageID][wordTable[j][1]] = true end
						end
						totalwords[languageID] = totalwords[languageID] + 1
					end
				end
			end
		end
	end
	for languageID,wtable in pairs(BadTranslator["WordList"]) do
		for word,dtable in pairs(wtable) do
			if strlen(word) > 3 and not BT_EXCLUSIONS[word] and (languageID == "en" or not BT_ENGLISH_WORDS or not BT_ENGLISH_WORDS[word]) and (dtable[2] / totalwords[languageID]) > 0.00001 then
				if not BadTranslator["WordDetect"][word] then BadTranslator["WordDetect"][word] = {} end
				BadTranslator["WordDetect"][word][languageID] = true
			end
		end
	end
	if export then
		BadTranslator["Export"] = { ["WordList"] = {}, ["WordDetect"] = {}, }
		for languageID,wtable in pairs(BadTranslator["WordList"]) do
			BadTranslator["Export"]["WordList"][languageID] = {}
			for word,dtable in pairs(wtable) do
				BadTranslator["Export"]["WordList"][languageID][word] = dtable[1]
			end
		end
		for word,wtable in pairs(BadTranslator["WordDetect"]) do
			BadTranslator["Export"]["WordDetect"][word] = "{"
			for languageID,_ in pairs(wtable) do BadTranslator["Export"]["WordDetect"][word] = BadTranslator["Export"]["WordDetect"][word].."[\""..languageID.."\"] = true," end
			BadTranslator["Export"]["WordDetect"][word] = BadTranslator["Export"]["WordDetect"][word].."},"
		end
	else
		BadTranslator["Export"] = nil
	end
	BadTranslator["WordList"] = nil
end

function BT_LinkDatabase(language,origDB,importedDB)
	origDB[language] = importedDB
	BT_Languages[language] = true
end
function BT_SeparateImportedSentencesByLanguage() -- /script BT_SeparateImportedSentencesByLanguage()
-- This read all imported sentences from BT_FOREIGN_CONVERT["IMPORTED"] and splits them by language... Mainly to guarantee the discord messages are foreign and not someone speaking English in a non-English channel.
	local wordString,language
	BadTranslator["Separate"] = {}
	for i=1, getn(BT_FOREIGN_CONVERT["IMPORTED"]) do
		wordString,language = BT_ProcessStringToTable(BT_FOREIGN_CONVERT["IMPORTED"][i])
		if not BadTranslator["Separate"][language] then BadTranslator["Separate"][language] = {} end
		table.insert(BadTranslator["Separate"][language], wordString)
	end
end

local displayposition = 1 -- Temporary functions
function BT_ReadChinese() -- /script BT_ReadChinese()
	--local origTime = GetTime()
	for i=1, 10 do
		DEFAULT_CHAT_FRAME:AddMessage(BT_TranslateString(BT_CHINESE_CONVERT[displayposition]))
		displayposition = displayposition + 1
	end
	--print(origTime.." - "..GetTime())
end
function BT_TempFunction() -- /script BT_TempFunction()
	local wordString = "yellowfever"
	local wordTable = {{"hello","hello"},{"hello","hello"},{"hello","hello"},{"hello","hello"},{"hello","hello"}}
	local tempTable = {}
	local tempVal,tVal,lfs,lfe = 1, 10

	local phrase = " La Guild Leyendas Latam - Busca TANKES DPS HEALS - Lows para subir lvl, MAZMORRAS - QUEST ETC - SUSURRAM"
	--local phrase = "黑石深淵任務團來法師，會路線++"
	local origTime = GetTime()
	for i=1, 1000 do BT_TranslateString(phrase) end
	--for i=1, 1000 do GF_GetTypes(phrase) end -- 650 ms, so only about 2x
	print(GetTime()-origTime)
	--print(BT_TranslateString(phrase))
--/script print(BT_TranslateString("¿Habéis descansado?Este será nuestro siguiente paso: hay ogros rodeando la Torre de Arathor en Stromgarde. Tendremos que activar las defensas de la torre pa’"))
	--local lfs,lfe,lfd = 33,34,35
--[[
--	113/210/112/325
	local wordTable
	for _,sentence in pairs(BT_FOREIGN_CONVERT["IMPORTED"]) do
		wordTable = BT_ProcessStringToTable(sentence,nil,nil,true,true,true) -- arg1,getLanguage,forGroupFinder,noSpaces,savePunctuation,notFromWoW
		for j=1, getn(wordTable[1][2]),2 do
			print("("..wordTable[1][2][j][2]..")")
			print("("..wordTable[1][2][j+1]..")")
-- /bt La Guild Leyendas Latam - Busca TANKES DPS HEALS - Lows para subir lvl, MAZMORRAS - QUEST ETC - SUSURRAM
		end
	end
	local origTime = GetTime() for i=1, 1000 do BT_TranslateString("黑石深淵任務團來法師，會路線++") end print(origTime.." - "..GetTime()) print(BT_TranslateString("黑石深淵任務團來法師，會路線++"))
	origTime = GetTime() for i=1, 1000000 do word = strchar(lfs)..strchar(lfe) end print(origTime.." - "..GetTime())
	origTime = GetTime() for i=1, 1000000 do word = strsub(wordString,3,6) end print(origTime.." - "..GetTime())
	origTime = GetTime() for i=1, 1000000 do word = strchar(lfs)..strchar(lfe)..strchar(lfd) end print(origTime.." - "..GetTime())
	local origTime = GetTime() for i=1, 1000000 do word = strsub(wordString,3,4) end print(origTime.." - "..GetTime())
	origTime = GetTime() for i=1, 1000000 do word = strchar(lfs) end print(origTime.." - "..GetTime())
--]]
--[[
	local origTime = GetTime() -- 725 ms
	for i=1, 1000000 do
		local wordString = ""
		for i=1, getn(wordTable) do
			wordString = wordString..wordTable[i][1]
		end
	end
	print(origTime.." - "..GetTime())

	local origTime = GetTime() -- 789 ms
	for i=1, 1000000 do
		for i=1, getn(wordTable) do
			tempTable[i] = wordTable[i][1]
		end
		table.concat(tempTable)
	end
	print(origTime.." - "..GetTime())
--]]
--[[
	local origTime = GetTime() -- 2.34 seconds(yellowfever)... 6.8 seconds(yellowfeveryellowfeveryellowfever)... 11.19 seconds(yellowfeveryellowfeveryellowfeveryellowfeveryellowfever)
	for i=1, 1000000 do
		tempVal = 1
		while true do
			lfs = strbyte(wordString,tempVal)
			if not lfs then break end	
			lfe = strchar(lfs)
			--table.insert(wordTable,strchar(lfs))
			tempVal = tempVal + 1
		end
		--table.concat(tempTable)
		--tempTable = {}
	end
	print(GetTime()-origTime)

	local origTime = GetTime() -- 1.57 seconds... 4.43... 7.33
	for i=1, 1000000 do
		tempVal = 1
		while true do
			lfs = strsub(wordString,tempVal,tempVal+1)
			if lfs == "" then break end	
			--lfe = strchar(lfs)
--			if not lfs then break end	
			--table.insert(wordTable,strchar(lfs))
			tempVal = tempVal + 1
		end
		--table.concat(tempTable)
		--tempTable = {}
	end
	print(GetTime()-origTime)
--]]
--[[
	local word = "ÅÆÈÐÂÒÄÑÃ"
	tempVal = 1
	while true do
		lfs = strsub(word,tempVal,tempVal+1)
		if lfs == "" then break end
		print(lfs)
		tempVal = tempVal + 1
	end
--]]
--[[
	local origTime = GetTime() -- .097
	for i=1, 1000000 do
		lfs = strbyte(wordString,10)
	end
	print(GetTime()-origTime)

	local origTime = GetTime() -- .097
	for i=1, 1000000 do
		lfs = strbyte(wordString,1)
	end
	print(GetTime()-origTime)

	local origTime = GetTime() -- .09
	for i=1, 1000000 do
		lfs = strchar(120)
	end
	print(GetTime()-origTime)
--]]
--[[
	local origTime = GetTime() -- .107
	for i=1, 1000000 do
		lfs = strsub(wordString,tempVal,tempVal) -- string.sub a single letter at start of sentence
	end
	print(GetTime()-origTime)

	local origTime = GetTime() -- .109
	for i=1, 1000000 do
		lfs = strsub(wordString,tVal,tVal) -- string.sub a single letter at position 10 of sentence
	end
	print(GetTime()-origTime)
--]]
--[[
	--BadTranslator["ASCII"] = {}
	BT_WORD_ACCENT_ASCII_TEMP = {}
	for ascii,letter in pairs(BT_WORD_ACCENT_ASCII_LETTERS) do -- 
		BT_WORD_ACCENT_ASCII_TEMP[strsub(ascii,1,1)] = ascii
		--BadTranslator["ASCII"][strsub(ascii,1,1)] = ascii
	end
--]]
	--local word = "《金属的延展性》？是的，我知道这本书。那是本非常好的书，是十几年前一位矮人矿工马戈尔夫·布拉贡写的。他的一生似乎都奉献给了卡兹莫丹的群山，整日在那里挖矿。他是个很聪明的家伙！但这书在哪来着？哦，对了，《金属的延展性》！这本书被我送到北郡修道院去了。那里的管理员帕克斯"
	--local origTime = GetTime() -- 
--[[
	BadTranslator["TEMP"] = {}
	for j=1, getn(BT_FOREIGN_CONVERT["IMPORTED"]) do
		wordString = BT_FOREIGN_CONVERT["IMPORTED"][j]
		for i=1, strlen(wordString) do
			lfs = strbyte(wordString,i)
			if lfs >= 227 then
				BT_WORD_ACCENT_ASCII_TEMP[strsub(wordString,i,i)] = true
				if BT_UNIQUE_SINGLE_WORDS["cn"][strsub(wordString,i,i+2)] then
					BadTranslator["TEMP"][strsub(wordString,i,i)] = strsub(wordString,i,i+2) --BT_UNIQUE_SINGLE_WORDS["cn"][strsub(wordString,i,i+2)]
				end
				i=i+2
			end
		end
	end
	for name,phrase in pairs (BT_UNIQUE_SINGLE_WORDS["cn"])
		lfs = strsub(name,i,i+2)
		
	end
	--print(GetTime()-origTime)
	--for ascii,letter in pairs(BadTranslator["TEMP"]) do
		--print(strbyte(ascii,1))
	--end
--]]
--[[

	BadTranslator["TEMP"] = {}
	for i=1, getn(BT_FOREIGN_CONVERT["IMPORTED"]) do
		wordString = BT_FOREIGN_CONVERT["IMPORTED"][i]
		lfs = strsub(wordString,1,1)
		if not BadTranslator["TEMP"][lfs] then BadTranslator["TEMP"][lfs] = i end --BT_UNIQUE_SINGLE_WORDS["cn"][strsub(wordString,i,i+2)]
	end
--]]
	--for ascii,_ in pairs(BT_WORD_ACCENT_ASCII_TEMP) do
		--print(strbyte(ascii,1))
	--end
end