

GS_ItemTypes = {
	["INVTYPE_RELIC"] = { ["SlotMOD"] = 0.3164, ["ItemSlot"] = 18, ["Enchantable"] = false},
	["INVTYPE_TRINKET"] = { ["SlotMOD"] = 0.5625, ["ItemSlot"] = 33, ["Enchantable"] = false },
	["INVTYPE_2HWEAPON"] = { ["SlotMOD"] = 2.000, ["ItemSlot"] = 16, ["Enchantable"] = true },
	["INVTYPE_WEAPONMAINHAND"] = { ["SlotMOD"] = 1.0000, ["ItemSlot"] = 16, ["Enchantable"] = true },
	["INVTYPE_WEAPONOFFHAND"] = { ["SlotMOD"] = 1.0000, ["ItemSlot"] = 17, ["Enchantable"] = true },
	["INVTYPE_RANGED"] = { ["SlotMOD"] = 0.3164, ["ItemSlot"] = 18, ["Enchantable"] = true },
	["INVTYPE_THROWN"] = { ["SlotMOD"] = 0.3164, ["ItemSlot"] = 18, ["Enchantable"] = false },
	["INVTYPE_RANGEDRIGHT"] = { ["SlotMOD"] = 0.3164, ["ItemSlot"] = 18, ["Enchantable"] = false },
	["INVTYPE_SHIELD"] = { ["SlotMOD"] = 1.0000, ["ItemSlot"] = 17, ["Enchantable"] = true },
	["INVTYPE_WEAPON"] = { ["SlotMOD"] = 1.0000, ["ItemSlot"] = 36, ["Enchantable"] = true },
	["INVTYPE_HOLDABLE"] = { ["SlotMOD"] = 1.0000, ["ItemSlot"] = 17, ["Enchantable"] = false },
	["INVTYPE_HEAD"] = { ["SlotMOD"] = 1.0000, ["ItemSlot"] = 1, ["Enchantable"] = true },
	["INVTYPE_NECK"] = { ["SlotMOD"] = 0.5625, ["ItemSlot"] = 2, ["Enchantable"] = false },
	["INVTYPE_SHOULDER"] = { ["SlotMOD"] = 0.7500, ["ItemSlot"] = 3, ["Enchantable"] = true },
	["INVTYPE_CHEST"] = { ["SlotMOD"] = 1.0000, ["ItemSlot"] = 5, ["Enchantable"] = true },
	["INVTYPE_ROBE"] = { ["SlotMOD"] = 1.0000, ["ItemSlot"] = 5, ["Enchantable"] = true },
	["INVTYPE_WAIST"] = { ["SlotMOD"] = 0.7500, ["ItemSlot"] = 6, ["Enchantable"] = false },
	["INVTYPE_LEGS"] = { ["SlotMOD"] = 1.0000, ["ItemSlot"] = 7, ["Enchantable"] = true },
	["INVTYPE_FEET"] = { ["SlotMOD"] = 0.75, ["ItemSlot"] = 8, ["Enchantable"] = true },
	["INVTYPE_WRIST"] = { ["SlotMOD"] = 0.5625, ["ItemSlot"] = 9, ["Enchantable"] = true },
	["INVTYPE_HAND"] = { ["SlotMOD"] = 0.7500, ["ItemSlot"] = 10, ["Enchantable"] = true },
	["INVTYPE_FINGER"] = { ["SlotMOD"] = 0.5625, ["ItemSlot"] = 31, ["Enchantable"] = false },
	["INVTYPE_CLOAK"] = { ["SlotMOD"] = 0.5625, ["ItemSlot"] = 15, ["Enchantable"] = true },
	
	--Lol Shirt
	["INVTYPE_BODY"] = { ["SlotMOD"] = 0, ["ItemSlot"] = 4, ["Enchantable"] = false },
}




GS_DefaultSettings = {
	["Player"] = 1,
	["Item"] = 1,
	["Show"] = 1,
	["Special"] = 1,
	["Level"] = -1,
	["Average"] = -1,
	["IncludeEnchants"] = true,
	["MustTarget"] = false,
	["showCharacterGS2"] = true,
	["showCharacterLegacy"] = true,
	["showCharacterPvp"] = true,
	["showCharacterAverage"] = false,
	["showCharacterCapSummary"] = true,
	["showCharacterCompare"] = false,
	["showCharacterSpecial"] = true,
	["showItemGS2"] = true,
	["showItemLegacy"] = true,
	["showItemPvp"] = true,
	["showItemLevel"] = false,
	["enableExplainTooltip"] = true,
	["showExplainHeader"] = true,
	["showExplainLegacy"] = true,
	["showExplainPveFormula"] = true,
	["showExplainPveParts"] = true,
	["showExplainPveTotals"] = true,
	["showExplainPvpFormula"] = true,
	["showExplainPvpParts"] = true,
	["showExplainPvpTotals"] = true,
	["showExplainFlags"] = true,
	["showExplainTopPveStats"] = true,
	["showExplainTopPvpStats"] = true,
	["showMinimapButton"] = true,
	["minimapAngle"] = 225,
}


GS_Special = {
	["A"] = "Author of GearScore",
	["B"] = "Official Sponsor of GearScore",
	["C"] = "Official GearScore Guild",
	["D"] = "Official Nemesis of GearScore",
	["E"] = "Killing Machine",
	["F"] = "Petscore: 9001",
 	["Pauladin"] = { ["Realm"] = "Elune", ["Type"] = "B" },
 	
 	["Wolfric"] = { ["Realm"] = "Khaz'Goroth", ["Type"] = "B" },
 	["Coastar"] = { ["Realm"] = "Khaz'Goroth", ["Type"] = "B" },
 	["Alekzander"] = { ["Realm"] = "Agamaggan", ["Type"] = "B" },
 	["Decks"] = { ["Realm"] = "Detheroc", ["Type"] = "B" },
 	["Dram"] = { ["Realm"] = "Duskwood", ["Type"] = "B" },
 	["Moophasa"] = { ["Realm"] = "Silver Hand", ["Type"] = "B" },
 	["Spirts"] = { ["Realm"] = "Khaz'Goroth", ["Type"] = "B" },
 	--["Wizzardly"] = { ["Realm"] = "Khaz'Goroth", ["Type"] = "B" },
 	--["Cloroangel"] = { ["Realm"] = "Khaz'Goroth", ["Type"] = "B" },
 	["Aeonel"] = { ["Realm"] = "Proudmoore", ["Type"] = "B" },
	["Lollygimon"] = { ["Realm"] = "Caelestrasz", ["Type"] = "B" },  		
	["Midshipman"] = { ["Realm"] = "Fenris", ["Type"] = "B" },  		
	["Saruk"] = { ["Realm"] = "Mal'Ganis", ["Type"] = "B" },  		
	["Volstormbrew"] = { ["Realm"] = "Detheroc", ["Type"] = "B" },  		
	["Shinnobe"] = { ["Realm"] = "Stormreaver", ["Type"] = "B" },  		
	["Spontaneous"] = { ["Realm"] = "Stormreaver", ["Type"] = "B" },  		
	["Nias"] = { ["Realm"] = "Stormreaver", ["Type"] = "B" },  		
	["Yaks"] = { ["Realm"] = "Balnazzar", ["Type"] = "B" },  		
	["Andresh"] = { ["Realm"] = "Uldaman", ["Type"] = "B" },  		
	["Atelyn"] = { ["Realm"] = "Thunderhorn", ["Type"] = "B" },  
	["UltraJames"] = { ["Realm"] = "Stormscale", ["Type"] = "B" }, 		
	--["Jubali"] = { ["Realm"] = "Frostmourne", ["Type"] = "B" }, 
	["Dalha"] = { ["Realm"] = "Dragonblight", ["Type"] = "B" }, 
	["Delitahyral"] = { ["Realm"] = "Shandris", ["Type"] = "B" }, 
	["Deathhaeven"] = { ["Realm"] = "Eldre'thalas", ["Type"] = "B" }, 
	["Nareli"] = { ["Realm"] = "Detheroc", ["Type"] = "D" }, 
	["Dalha"] = { ["Realm"] = "Dragonblight", ["Type"] = "B" }, 
	["Neisha"] = { ["Realm"] = "Stormreaver", ["Type"] = "B" }, 
	["Tentontotem"] = { ["Realm"] = "Destromath", ["Type"] = "B" }, 
	["GryphonMD"] = { ["Realm"] = "Kargath", ["Type"] = "B" }, 
	["Judeondethus"] = { ["Realm"] = "Detheroc", ["Type"] = "B" }, 	
	["Greatmelinko"] = { ["Realm"] = "Detheroc", ["Type"] = "B" }, 
	["Eshia"] = { ["Realm"] = "Stormreaver", ["Type"] = "B" }, 
 	["Greatmelinko"] = { ["Realm"] = "Detheroc", ["Type"] = "B" }, 
 	["Hiivolt"] = { ["Realm"] = "Detheroc", ["Type"] = "B" }, 
 	["Tlor"] = { ["Realm"] = "Kirin Tor", ["Type"] = "B" }, 
 	["Arachna"] = { ["Realm"] = "Kel'Thuzad", ["Type"] = "B" },
 	["Belarr"] = { ["Realm"] = "Misha", ["Type"] = "B" }, 
 	["Zarniwhoop"] = { ["Realm"] = "Ysera", ["Type"] = "B" },  
 	["Faculty"] = { ["Realm"] = "Feathermoon", ["Type"] = "B" },  
 	["Round"] = { ["Realm"] = "Thunderhorn", ["Type"] = "B" }, 
 	["Berlioz"] = { ["Realm"] = "Thunderhorn", ["Type"] = "B" }, 
 	["Huzzan"] = { ["Realm"] = "Detheroc", ["Type"] = "B" }, 
 	["Lawlcat"] = { ["Realm"] = "Detheroc", ["Type"] = "B" },  	
 	["Khyu"] = { ["Realm"] = "Aggramar", ["Type"] = "B" },  	
 	["Tricksybell"] = { ["Realm"] = "Dentarg", ["Type"] = "B" },  	
 	["Quixotek"] = { ["Realm"] = "Kel'Thuzad", ["Type"] = "B" },  	
 	["Chetnik"] = { ["Realm"] = "Gurubashi", ["Type"] = "B" },  	
 	["Tekfour"] = { ["Realm"] = "Dreadmaul", ["Type"] = "B" }, 
 	["Tekfrost"] = { ["Realm"] = "Dreadmaul", ["Type"] = "B" }, 
 	["Adi"] = { ["Realm"] = "Elune", ["Type"] = "B" }, 
 	["Adibou"] = { ["Realm"] = "Elune", ["Type"] = "B" },  	 	
 	["Zinya"] = { ["Realm"] = "Azjol-Nerub", ["Type"] = "B" }, 
 	["Temmi"] = { ["Realm"] = "Dath'Remar", ["Type"] = "B" }, 
	["Tejal"] = { ["Realm"] = "Cairne", ["Type"] = "B" }, 
	["Doriecycline"] = { ["Realm"] = "Dreadmaul", ["Type"] = "B" }, 
	["Cayman"] = { ["Realm"] = "Shandris", ["Type"] = "B" }, 
 	["Verîx"] = { ["Realm"] = "Stormreaver", ["Type"] = "B" },
 	["Asulla"] = { ["Realm"] = "Stormreaver", ["Type"] = "B" },
	["Halcyana"] = { ["Realm"] = "Detheroc", ["Type"] = "B" },
	["Midiga"] = { ["Realm"] = "Stormreaver", ["Type"] = "B" },	
	 	
----------------------------
	["Midiga"] = { ["Realm"] = "IceCrown", ["Type"] = "B" },		 	
	["Drgoodhead "] = { ["Realm"] = "Stormreaver", ["Type"] = "B" },		 	
	["Squirrelly"] = { ["Realm"] = "Elune", ["Type"] = "B" },		 	
	["Atewheaties"] = { ["Realm"] = "Elune", ["Type"] = "B" },		 	
	["Shz"] = { ["Realm"] = "Gorefiend", ["Type"] = "B" },		 	
	["Zevilone"] = { ["Realm"] = "Llane", ["Type"] = "B" },		 	
	["Thorkeld"] = { ["Realm"] = "Shadow Council", ["Type"] = "B" },		 	
	["Vaxum"] = { ["Realm"] = "Spirestone", ["Type"] = "B" },		 	
	["Muru"] = { ["Realm"] = "Spirestone", ["Type"] = "B" },		 	
	["Moodle"] = { ["Realm"] = "Spirestone", ["Type"] = "B" },		 	
	["Anzio"] = { ["Realm"] = "Bladefist", ["Type"] = "B" },		 	
	["Ggoddess"] = { ["Realm"] = "Madoran", ["Type"] = "B" },		 	
	["Rakkan"] = { ["Realm"] = "Lothar", ["Type"] = "B" },		 	
	["Taliaran"] = { ["Realm"] = "Grim Batol", ["Type"] = "B" },		 	
	["Dartagg"] = { ["Realm"] = "Crushridge", ["Type"] = "B" },		 	
	["Sethr"] = { ["Realm"] = "Crushridge", ["Type"] = "B" },		 	
	["Diosan"] = { ["Realm"] = "Scarlet Crusade", ["Type"] = "B" },		 	
	["Renth"] = { ["Realm"] = "Dragonblight", ["Type"] = "B" },		 	
	["Wherezwaldo"] = { ["Realm"] = "Magtheridon", ["Type"] = "B" },		 	
	["Mif"] = { ["Realm"] = "Proudmoore", ["Type"] = "B" },		 	
	["Lotorin"] = { ["Realm"] = "Thunderhorn", ["Type"] = "B" },		 	
	["Starrìe"] = { ["Realm"] = "Malfurion", ["Type"] = "B" },		 	
	["Jthome"] = { ["Realm"] = "Lightning's Blade", ["Type"] = "B" },		 	
	["Retmeat"] = { ["Realm"] = "Cairne", ["Type"] = "B" },		 	
	["Catzilla"] = { ["Realm"] = "Draenor", ["Type"] = "B" },		 	
	["Lonnie"] = { ["Realm"] = "Draenor", ["Type"] = "B" },		 	
	["Millantis"] = { ["Realm"] = "Archimonde", ["Type"] = "B" },		 	
	["Benzy"] = { ["Realm"] = "Alterac Mountains", ["Type"] = "B" },		 	
	["Deaddolly"] = { ["Realm"] = "Windrunner", ["Type"] = "B" },		 	
	["Erd"] = { ["Realm"] = "Burning Legion", ["Type"] = "B" },		 	
	["Enigmà"] = { ["Realm"] = "Darksorrow", ["Type"] = "B" },		 	
	["Deaddolly"] = { ["Realm"] = "Windrunner", ["Type"] = "B" },		 	
	["Dragonas"] = { ["Realm"] = "Lethon", ["Type"] = "B" },		 	
	["Salamando"] = { ["Realm"] = "Khadgar", ["Type"] = "B" },		 	
	["Alzinator"] = { ["Realm"] = "Shadowsong", ["Type"] = "B" },		 	
	["Junebee"] = { ["Realm"] = "Turalyon", ["Type"] = "B" },		 		
------------------------------	 	
-- 6/3/2010
	["Neysaa"] = { ["Realm"] = "Skywall", ["Type"] = "B" },			 	
	["Halcyana"] = { ["Realm"] = "Detheroc", ["Type"] = "E" },
	["Kobekuro"] = { ["Realm"] = "Detheroc", ["Type"] = "E" },
	["Kobeyama"] = { ["Realm"] = "Detheroc", ["Type"] = "E" },
	["Sophiayuki"] = { ["Realm"] = "Detheroc", ["Type"] = "E" },
	["Praetori"] = { ["Realm"] = "Draenor", ["Type"] = "B" },
	["Strahdvonzar"] = { ["Realm"] = "Quel'Thalas", ["Type"] = "B" },
	["Rhakark"] = { ["Realm"] = "Kirin Tor", ["Type"] = "B" },
	["Jazzia"] = { ["Realm"] = "Earthen Ring", ["Type"] = "B" },
	["Diilemmaz"] = { ["Realm"] = "Proudmoore", ["Type"] = "B" },
	["Evilenigma"] = { ["Realm"] = "Darksorrow", ["Type"] = "B" },
	["Bittles"] = { ["Realm"] = "Detheroc", ["Type"] = "B" },
	["Soilwork"] = { ["Realm"] = "Kirin Tor", ["Type"] = "B" },
	["Flayrot"] = { ["Realm"] = "Lothar", ["Type"] = "B" },
	["Direbear"] = { ["Realm"] = "Quel'Thalas", ["Type"] = "F" },
	["Vampiroth"] = { ["Realm"] = "Zul'jin", ["Type"] = "B" },
	["Tumtumm"] = { ["Realm"] = "Proudmoore", ["Type"] = "B" },
	["Winsticles"] = { ["Realm"] = "Frostmourne", ["Type"] = "B" },
	["Rekviem"] = { ["Realm"] = "Elune", ["Type"] = "B" },
	["Rîddîck"] = { ["Realm"] = "Madoran", ["Type"] = "B" },
	["Drakekitty"] = { ["Realm"] = "Proudmoore", ["Type"] = "B" },
	["Paladio"] = { ["Realm"] = "Area 52", ["Type"] = "B" },
	["Modellista"] = { ["Realm"] = "Khaz'Goroth", ["Type"] = "B" },
	["Cablitin"] = { ["Realm"] = "Proudmoore", ["Type"] = "B" },
	["Sneakycab"] = { ["Realm"] = "Proudmoore", ["Type"] = "B" },
	["Uselessllama"] = { ["Realm"] = "Spirestone", ["Type"] = "B" },
	["Penetråtion"] = { ["Realm"] = "Caelestrasz", ["Type"] = "B" },	 	
	
	["Funstar"] = { ["Realm"] = "Mal'Ganis", ["Type"] = "B" },
	["Omnimen"] = { ["Realm"] = "Agamaggen", ["Type"] = "B" },
	["Dotimusprime"] = { ["Realm"] = "Black DragonFlight", ["Type"] = "B" },
	["Sajuukkhar"] = { ["Realm"] = "Nordrassil", ["Type"] = "B" },
	["Noggienog"] = { ["Realm"] = "Windrunner", ["Type"] = "B" },
	["Stevelrwin"] = { ["Realm"] = "Aggramar", ["Type"] = "B" },
	["Facerollftw"] = { ["Realm"] = "Aggramar", ["Type"] = "B" },
	["Healsforhugs"] = { ["Realm"] = "Aggramar", ["Type"] = "B" },
	["Droodzz"] = { ["Realm"] = "Bruning Legion", ["Type"] = "B" },
	
	 	
------------------------------	 	 	
	["Arxkanite"] = { ["Realm"] = "Detheroc", ["Type"] = "A" },
	["Josephsmith"] = { ["Realm"] = "Detheroc", ["Type"] = "B" },
	["Choku"] = { ["Realm"] = "Magtheridon", ["Type"] = "B" },
	["Murmilude"] = { ["Realm"] = "Blade's Edge", ["Type"] = "B" },
	["Rangitor"] = { ["Realm"] = "Khaz'Goroth", ["Type"] = "B" },
	["Keightie"] = { ["Realm"] = "Detheroc", ["Type"] = "B" },
    	--["Kymax"] = { ["Realm"] = "Detheroc", ["Type"] = "A" },
    	["Zanier"] = { ["Realm"] = "Cairne", ["Type"] = "B" },    
    	--["Cuppycakes"] = { ["Realm"] = "Detheroc", ["Type"] = "A" },
    	--["Sausagefest"] = { ["Realm"] = "Detheroc", ["Type"] = "B" },
    	["Rogue Angels"] = { ["Realm"] = "Detheroc", ["Type"] = "C" },
}


GS_Rarity = {
	[0] = { Red = 0.55,	Green = 0.55, Blue = 0.55 },
	[1] = {	Red = 1.00,	Green = 1.00, Blue = 1.00 },
	[2] = {	Red = 0.12,	Green = 1.00, Blue = 0.00 },
	[3] = {	Red = 0.00,	Green = 0.50, Blue = 1.00 },
	[4] = {	Red = 0.69, Green = 0.28, Blue = 0.97 },
	[5] = { Red = 0.94,	Green = 0.09, Blue = 0.00 },
	[6] = {	Red = 1.00,	Green = 0.00, Blue = 0.00 },
	[7] = {	Red = 0.90,	Green = 0.80, Blue = 0.50 },
}

GS_Formula = {
	["A"] = {
		[4] = { ["A"] = 91.4500, ["B"] = 0.6500 },
		[3] = { ["A"] = 81.3750, ["B"] = 0.8125 },
		[2] = { ["A"] = 73.0000, ["B"] = 1.0000 }
	},
	["B"] = {
		[4] = { ["A"] = 26.0000, ["B"] = 1.2000 },
		[3] = { ["A"] = 0.7500, ["B"] = 1.8000 },
		[2] = { ["A"] = 8.0000, ["B"] = 2.0000 },
		[1] = { ["A"] = 0.0000, ["B"] = 2.2500 }
	}
}

GS_Quality = {
	[6000] = {
		["Red"] = { ["A"] = 0.94, ["B"] = 5000, ["C"] = 0.00006, ["D"] = 1 },
		["Green"] = { ["A"] = 0.47, ["B"] = 5000, ["C"] = 0.00047, ["D"] = -1 },
		["Blue"] = { ["A"] = 0, ["B"] = 0, ["C"] = 0, ["D"] = 0 },
		["Description"] = "Legendary"
	},
	[5000] = {
		["Red"] = { ["A"] = 0.69, ["B"] = 4000, ["C"] = 0.00025, ["D"] = 1 },
		["Green"] = { ["A"] = 0.28, ["B"] = 4000, ["C"] = 0.00019, ["D"] = 1 },
		["Blue"] = { ["A"] = 0.97, ["B"] = 4000, ["C"] = 0.00096, ["D"] = -1 },
		["Description"] = "Epic"
	},
	[4000] = {
		["Red"] = { ["A"] = 0.0, ["B"] = 3000, ["C"] = 0.00069, ["D"] = 1 },
		["Green"] = { ["A"] = 0.5, ["B"] = 3000, ["C"] = 0.00022, ["D"] = -1 },
		["Blue"] = { ["A"] = 1, ["B"] = 3000, ["C"] = 0.00003, ["D"] = -1 },
		["Description"] = "Superior"
	},
	[3000] = {
		["Red"] = { ["A"] = 0.12, ["B"] = 2000, ["C"] = 0.00012, ["D"] = -1 },
		["Green"] = { ["A"] = 1, ["B"] = 2000, ["C"] = 0.00050, ["D"] = -1 },
		["Blue"] = { ["A"] = 0, ["B"] = 2000, ["C"] = 0.001, ["D"] = 1 },
		["Description"] = "Uncommon"
	},
	[2000] = {
		["Red"] = { ["A"] = 1, ["B"] = 1000, ["C"] = 0.00088, ["D"] = -1 },
		["Green"] = { ["A"] = 1, ["B"] = 000, ["C"] = 0.00000, ["D"] = 0 },
		["Blue"] = { ["A"] = 1, ["B"] = 1000, ["C"] = 0.001, ["D"] = -1 },
		["Description"] = "Common"
	},
	[1000] = {
		["Red"] = { ["A"] = 0.55, ["B"] = 0, ["C"] = 0.00045, ["D"] = 1 },
		["Green"] = { ["A"] = 0.55, ["B"] = 0, ["C"] = 0.00045, ["D"] = 1 },
		["Blue"] = { ["A"] = 0.55, ["B"] = 0, ["C"] = 0.00045, ["D"] = 1 },
		["Description"] = "Trash"
	},
}



GS_CommandList = {
	[1] = "---GearScore Options List---",
	[2] = "/gs2 player -> Toggles display of scores on players.",
	[3] = "/gs2 item -> Toggles display of scores for items.",
	[4] = "/gs2 level -> Toggles iLevel information.",
	[5] = "/gs2 interface -> Opens the interface options page.",
	[6] = "/gs2 settings -> Opens the GearScore2 settings panel.",
}

GS_ShowSwitch = {[0] = 2,[1] = 3,[2] = 0,[3] = 1}
GS_ItemSwitch = {[0] = 3,[1] = 2,[2] = 1,[3] = 0}

GS_EnchantSlots = {
	["INVTYPE_HEAD"] = true,
	["INVTYPE_SHOULDER"] = true,
	["INVTYPE_CHEST"] = true,
	["INVTYPE_ROBE"] = true,
	["INVTYPE_LEGS"] = true,
	["INVTYPE_FEET"] = true,
	["INVTYPE_WRIST"] = true,
	["INVTYPE_HAND"] = true,
	["INVTYPE_CLOAK"] = true,
	["INVTYPE_2HWEAPON"] = true,
	["INVTYPE_WEAPONMAINHAND"] = true,
	["INVTYPE_WEAPONOFFHAND"] = true,
	["INVTYPE_WEAPON"] = true,
	["INVTYPE_SHIELD"] = true,
	["INVTYPE_RANGED"] = true,
}

GS_ArmorClassOrder = {
	["CLOTH"] = 1,
	["LEATHER"] = 2,
	["MAIL"] = 3,
	["PLATE"] = 4,
}

GS_SocketStatKeys = {
	EMPTY_SOCKET_RED = true,
	EMPTY_SOCKET_YELLOW = true,
	EMPTY_SOCKET_BLUE = true,
	EMPTY_SOCKET_META = true,
}

GS_StatAliases = {
	ITEM_MOD_STRENGTH_SHORT = "STR",
	ITEM_MOD_AGILITY_SHORT = "AGI",
	ITEM_MOD_STAMINA_SHORT = "STA",
	ITEM_MOD_INTELLECT_SHORT = "INT",
	ITEM_MOD_SPIRIT_SHORT = "SPI",
	ITEM_MOD_ATTACK_POWER_SHORT = "AP",
	ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RAP",
	ITEM_MOD_SPELL_POWER_SHORT = "SP",
	ITEM_MOD_HIT_RATING_SHORT = "HIT",
	ITEM_MOD_CRIT_RATING_SHORT = "CRIT",
	ITEM_MOD_HASTE_RATING_SHORT = "HASTE",
	ITEM_MOD_RESILIENCE_RATING_SHORT = "RESILIENCE",
	ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "ARP",
	ITEM_MOD_EXPERTISE_RATING_SHORT = "EXPERTISE",
	ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEFENSE",
	ITEM_MOD_DODGE_RATING_SHORT = "DODGE",
	ITEM_MOD_PARRY_RATING_SHORT = "PARRY",
	ITEM_MOD_BLOCK_RATING_SHORT = "BLOCK",
	ITEM_MOD_BLOCK_VALUE_SHORT = "BLOCKVALUE",
	ITEM_MOD_MANA_REGENERATION_SHORT = "MP5",
}

GS_EnchantValues = GS_EnchantValues or {}

GS_ClassDefaults = {
	WARRIOR = "FURY", PALADIN = "RETRIBUTION", HUNTER = "MARKSMANSHIP", ROGUE = "COMBAT",
	PRIEST = "SHADOW", DEATHKNIGHT = "UNHOLY", SHAMAN = "ELEMENTAL", MAGE = "ARCANE",
	WARLOCK = "AFFLICTION", DRUID = "BALANCE",
}

GS_ClassSpecOrder = {
	WARRIOR = { "ARMS", "FURY", "PROTECTION" },
	PALADIN = { "HOLY", "PROTECTION", "RETRIBUTION" },
	HUNTER = { "BEASTMASTERY", "MARKSMANSHIP", "SURVIVAL" },
	ROGUE = { "ASSASSINATION", "COMBAT", "SUBTLETY" },
	PRIEST = { "DISCIPLINE", "HOLY", "SHADOW" },
	DEATHKNIGHT = { "BLOOD", "FROST", "UNHOLY" },
	SHAMAN = { "ELEMENTAL", "ENHANCEMENT", "RESTORATION" },
	MAGE = { "ARCANE", "FIRE", "MAGE_FROST" },
	WARLOCK = { "AFFLICTION", "DEMONOLOGY", "DESTRUCTION" },
	DRUID = { "BALANCE", "FERAL", "DRUID_RESTORATION" },
}

GS_SpecProfiles = {
	ARMS = { role = "MELEE", armor = "PLATE", shield = false, ranged = false, pve = { STR = 2.4, CRIT = 1.5, HIT = 1.8, HASTE = 1.1, ARP = 1.9, AP = 1.2, EXPERTISE = 1.4 }, pvp = { STR = 2.2, CRIT = 1.2, HIT = 0.8, HASTE = 0.9, ARP = 1.3, AP = 1.0, RESILIENCE = 2.2 } },
	FURY = { role = "MELEE", armor = "PLATE", shield = false, ranged = false, dualwield = true, pve = { STR = 2.6, CRIT = 1.5, HIT = 1.9, HASTE = 1.3, ARP = 1.9, AP = 1.1, EXPERTISE = 1.3 }, pvp = { STR = 2.0, CRIT = 1.0, HASTE = 0.8, AP = 0.9, RESILIENCE = 2.2 } },
	PROTECTION = { role = "TANK", armor = "PLATE", shield = true, ranged = false, pve = { STR = 0.8, DEFENSE = 2.8, DODGE = 2.1, PARRY = 2.0, BLOCK = 1.7, BLOCKVALUE = 1.2, HIT = 1.0, EXPERTISE = 1.2 }, pvp = { STR = 0.8, DODGE = 1.4, PARRY = 1.3, BLOCK = 1.2, RESILIENCE = 1.7 } },
	HOLY = { role = "HEALER", armor = "PLATE", shield = true, ranged = false, pve = { INT = 2.4, SP = 2.8, HASTE = 1.8, CRIT = 1.3, MP5 = 1.5, SPI = 0.4 }, pvp = { INT = 2.0, SP = 2.4, HASTE = 1.1, CRIT = 0.8, MP5 = 0.8, RESILIENCE = 2.2 } },
	RETRIBUTION = { role = "MELEE", armor = "PLATE", shield = false, ranged = false, pve = { STR = 2.6, CRIT = 1.5, HIT = 1.6, HASTE = 1.1, EXPERTISE = 1.3, AP = 1.0 }, pvp = { STR = 2.2, CRIT = 1.0, AP = 0.9, RESILIENCE = 2.2 } },
	BEASTMASTERY = { role = "RANGED", armor = "MAIL", shield = false, ranged = true, pve = { AGI = 2.5, RAP = 1.4, AP = 0.8, HIT = 1.7, CRIT = 1.5, HASTE = 1.0, ARP = 1.1 }, pvp = { AGI = 2.1, RAP = 1.0, CRIT = 1.0, HASTE = 0.7, RESILIENCE = 2.2 } },
	MARKSMANSHIP = { role = "RANGED", armor = "MAIL", shield = false, ranged = true, pve = { AGI = 2.6, RAP = 1.3, AP = 0.7, HIT = 1.8, CRIT = 1.6, HASTE = 1.0, ARP = 1.8 }, pvp = { AGI = 2.2, RAP = 1.0, CRIT = 1.0, ARP = 1.0, RESILIENCE = 2.2 } },
	SURVIVAL = { role = "RANGED", armor = "MAIL", shield = false, ranged = true, pve = { AGI = 2.7, RAP = 1.2, AP = 0.7, HIT = 1.7, CRIT = 1.4, HASTE = 1.0 }, pvp = { AGI = 2.2, CRIT = 1.0, HASTE = 0.8, RESILIENCE = 2.2 } },
	ASSASSINATION = { role = "MELEE", armor = "LEATHER", shield = false, ranged = false, dualwield = true, pve = { AGI = 2.5, AP = 1.2, HIT = 1.8, HASTE = 1.2, CRIT = 1.3, EXPERTISE = 1.4 }, pvp = { AGI = 2.2, AP = 1.0, HASTE = 0.8, CRIT = 0.9, RESILIENCE = 2.2 } },
	COMBAT = { role = "MELEE", armor = "LEATHER", shield = false, ranged = false, dualwield = true, pve = { AGI = 2.4, AP = 1.0, HIT = 1.9, HASTE = 1.4, CRIT = 1.2, ARP = 1.5, EXPERTISE = 1.4 }, pvp = { AGI = 2.0, AP = 0.9, HASTE = 0.7, CRIT = 0.8, RESILIENCE = 2.2 } },
	SUBTLETY = { role = "MELEE", armor = "LEATHER", shield = false, ranged = false, dualwield = true, pve = { AGI = 2.2, AP = 1.0, HIT = 1.5, HASTE = 0.8, CRIT = 1.2, ARP = 1.0, EXPERTISE = 1.1 }, pvp = { AGI = 2.3, AP = 1.0, CRIT = 1.0, RESILIENCE = 2.4 } },
	DISCIPLINE = { role = "HEALER", armor = "CLOTH", shield = false, ranged = false, pve = { INT = 2.4, SP = 2.7, CRIT = 1.5, HASTE = 1.4, MP5 = 1.1, SPI = 0.8 }, pvp = { INT = 2.1, SP = 2.2, CRIT = 0.9, HASTE = 0.8, RESILIENCE = 2.4 } },
	SHADOW = { role = "CASTER", armor = "CLOTH", shield = false, ranged = false, pve = { INT = 1.7, SP = 2.8, HIT = 1.9, HASTE = 1.7, CRIT = 1.0, SPI = 1.2 }, pvp = { INT = 1.6, SP = 2.3, HASTE = 1.0, CRIT = 0.8, RESILIENCE = 2.3 } },
	BLOOD = { role = "TANK", armor = "PLATE", shield = false, ranged = false, pve = { STR = 1.0, DEFENSE = 2.8, DODGE = 2.0, PARRY = 2.0, HIT = 0.8, EXPERTISE = 1.0 }, pvp = { STR = 1.0, RESILIENCE = 2.0 } },
	FROST = { role = "MELEE", armor = "PLATE", shield = false, ranged = false, dualwield = true, pve = { STR = 2.5, HIT = 1.7, HASTE = 1.2, CRIT = 1.2, EXPERTISE = 1.3, AP = 0.9 }, pvp = { STR = 2.2, CRIT = 0.9, RESILIENCE = 2.2 } },
	UNHOLY = { role = "MELEE", armor = "PLATE", shield = false, ranged = false, pve = { STR = 2.5, HIT = 1.7, HASTE = 1.3, CRIT = 1.1, EXPERTISE = 1.2, AP = 1.0 }, pvp = { STR = 2.2, HASTE = 0.8, RESILIENCE = 2.2 } },
	ELEMENTAL = { role = "CASTER", armor = "MAIL", shield = true, ranged = false, pve = { INT = 1.7, SP = 2.8, HIT = 1.8, HASTE = 1.6, CRIT = 1.1, MP5 = 0.4 }, pvp = { INT = 1.5, SP = 2.3, HASTE = 0.9, CRIT = 0.8, RESILIENCE = 2.3 } },
	ENHANCEMENT = { role = "MELEE", armor = "MAIL", shield = false, ranged = false, dualwield = true, pve = { AGI = 2.0, AP = 1.2, HIT = 1.8, HASTE = 1.4, CRIT = 1.2, EXPERTISE = 1.4 }, pvp = { AGI = 1.8, AP = 1.0, HASTE = 0.9, RESILIENCE = 2.2 } },
	RESTORATION = { role = "HEALER", armor = "MAIL", shield = true, ranged = false, pve = { INT = 2.3, SP = 2.7, HASTE = 1.8, CRIT = 1.2, MP5 = 1.4, SPI = 0.2 }, pvp = { INT = 2.0, SP = 2.3, HASTE = 0.9, MP5 = 0.7, RESILIENCE = 2.3 } },
	ARCANE = { role = "CASTER", armor = "CLOTH", shield = false, ranged = false, pve = { INT = 1.9, SP = 2.7, HIT = 1.8, HASTE = 1.5, CRIT = 1.2, SPI = 0.4 }, pvp = { INT = 1.8, SP = 2.2, HASTE = 0.9, CRIT = 0.8, RESILIENCE = 2.2 } },
	FIRE = { role = "CASTER", armor = "CLOTH", shield = false, ranged = false, pve = { INT = 1.7, SP = 2.8, HIT = 1.7, HASTE = 1.6, CRIT = 1.3, SPI = 0.3 }, pvp = { INT = 1.6, SP = 2.3, HASTE = 1.0, CRIT = 0.8, RESILIENCE = 2.2 } },
	MAGE_FROST = { role = "CASTER", armor = "CLOTH", shield = false, ranged = false, pve = { INT = 1.7, SP = 2.6, HIT = 1.7, HASTE = 1.3, CRIT = 1.2 }, pvp = { INT = 1.6, SP = 2.3, HASTE = 0.9, CRIT = 0.8, RESILIENCE = 2.5 } },
	AFFLICTION = { role = "CASTER", armor = "CLOTH", shield = false, ranged = false, pve = { INT = 1.7, SP = 2.8, HIT = 1.8, HASTE = 1.6, CRIT = 1.0, SPI = 0.5 }, pvp = { INT = 1.6, SP = 2.3, HASTE = 1.0, RESILIENCE = 2.3 } },
	DEMONOLOGY = { role = "CASTER", armor = "CLOTH", shield = false, ranged = false, pve = { INT = 1.7, SP = 2.7, HIT = 1.7, HASTE = 1.4, CRIT = 1.1, SPI = 0.4 }, pvp = { INT = 1.6, SP = 2.2, HASTE = 0.9, RESILIENCE = 2.2 } },
	DESTRUCTION = { role = "CASTER", armor = "CLOTH", shield = false, ranged = false, pve = { INT = 1.7, SP = 2.8, HIT = 1.7, HASTE = 1.5, CRIT = 1.2, SPI = 0.3 }, pvp = { INT = 1.6, SP = 2.3, HASTE = 0.9, CRIT = 0.8, RESILIENCE = 2.3 } },
	BALANCE = { role = "CASTER", armor = "LEATHER", shield = false, ranged = false, pve = { INT = 1.8, SP = 2.8, HIT = 1.8, HASTE = 1.6, CRIT = 1.1, SPI = 0.5 }, pvp = { INT = 1.7, SP = 2.2, HASTE = 0.9, CRIT = 0.8, RESILIENCE = 2.3 } },
	FERAL = { role = "MELEE", armor = "LEATHER", shield = false, ranged = false, pve = { AGI = 2.5, AP = 1.1, HIT = 1.6, HASTE = 1.0, CRIT = 1.3, ARP = 1.5, EXPERTISE = 1.2 }, pvp = { AGI = 2.2, AP = 0.9, RESILIENCE = 2.3 } },
	DRUID_RESTORATION = { role = "HEALER", armor = "LEATHER", shield = false, ranged = false, pve = { INT = 2.4, SP = 2.7, HASTE = 1.9, CRIT = 1.0, MP5 = 1.1, SPI = 1.2 }, pvp = { INT = 2.0, SP = 2.2, HASTE = 0.9, SPI = 0.7, RESILIENCE = 2.4 } },
}

GS_RatingConversions = {
	MELEE_HIT = 32.78998947,
	SPELL_HIT = 26.231992,
	EXPERTISE = 8.196,
	DEFENSE = 4.9185,
}

GS_CapSegmentDefaults = {
	CRITICAL = 1.25,
	USEFUL = 0.60,
	OVERFLOW = 0.20,
	HIT_OVERFLOW = 0.50,
	DEFENSE_OVERFLOW = 0.55,
	ARP_OVERFLOW = 0.05,
}

GS_LiveCapBuffs = {
	HELPFUL = {
		{ spellId = 6562, meleeHitBonus = 1, spellHitBonus = 1 },
	},
	HARMFUL = {
		{ spellId = 33198, targetSpellHitBonus = 3 },
	},
}

GS_CapProfiles = {
	ARMS = {
		order = { "HIT", "EXPERTISE", "ARP" },
		pools = {
			HIT = { summary = "Hit", meleeHitBonus = 0, overflow = GS_CapSegmentDefaults.HIT_OVERFLOW, segments = { { mode = "MELEE_HIT_PERCENT", threshold = 8, mult = GS_CapSegmentDefaults.CRITICAL, label = "Special hit cap" } } },
			EXPERTISE = { summary = "Expertise", overflow = GS_CapSegmentDefaults.OVERFLOW, segments = { { mode = "EXPERTISE_POINTS", threshold = 26, mult = GS_CapSegmentDefaults.CRITICAL, label = "Expertise soft cap" } } },
			ARP = { summary = "Armor Penetration", overflow = GS_CapSegmentDefaults.ARP_OVERFLOW, segments = { { mode = "RATING", threshold = 1400, mult = GS_CapSegmentDefaults.CRITICAL, label = "Armor penetration hard cap" } } },
		},
	},
	FURY = {
		order = { "HIT", "EXPERTISE", "ARP" },
		pools = {
			HIT = { summary = "Hit", meleeHitBonus = 0, overflow = GS_CapSegmentDefaults.HIT_OVERFLOW, segments = { { mode = "MELEE_HIT_PERCENT", threshold = 8, mult = GS_CapSegmentDefaults.CRITICAL, label = "Special hit cap" } } },
			EXPERTISE = { summary = "Expertise", overflow = GS_CapSegmentDefaults.OVERFLOW, segments = { { mode = "EXPERTISE_POINTS", threshold = 26, mult = GS_CapSegmentDefaults.CRITICAL, label = "Expertise soft cap" } } },
			ARP = { summary = "Armor Penetration", overflow = GS_CapSegmentDefaults.ARP_OVERFLOW, segments = { { mode = "RATING", threshold = 1400, mult = GS_CapSegmentDefaults.CRITICAL, label = "Armor penetration hard cap" } } },
		},
	},
	PROTECTION = {
		order = { "DEFENSE", "EXPERTISE", "HIT" },
		pools = {
			DEFENSE = { summary = "Defense", overflow = GS_CapSegmentDefaults.DEFENSE_OVERFLOW, segments = { { mode = "DEFENSE_SKILL", threshold = 540, mult = GS_CapSegmentDefaults.CRITICAL, label = "Crit immunity cap" } } },
			EXPERTISE = { summary = "Expertise", overflow = GS_CapSegmentDefaults.OVERFLOW, segments = { { mode = "EXPERTISE_POINTS", threshold = 26, mult = GS_CapSegmentDefaults.CRITICAL, label = "Expertise soft cap" }, { mode = "EXPERTISE_POINTS", threshold = 56, mult = GS_CapSegmentDefaults.USEFUL, label = "Front-facing expertise cap" } } },
			HIT = { summary = "Hit", meleeHitBonus = 0, overflow = GS_CapSegmentDefaults.HIT_OVERFLOW, segments = { { mode = "MELEE_HIT_PERCENT", threshold = 8, mult = GS_CapSegmentDefaults.CRITICAL, label = "Taunt / special hit cap" } } },
		},
	},
	RETRIBUTION = {
		order = { "HIT", "EXPERTISE" },
		pools = {
			HIT = { summary = "Hit", meleeHitBonus = 0, overflow = GS_CapSegmentDefaults.HIT_OVERFLOW, segments = { { mode = "MELEE_HIT_PERCENT", threshold = 8, mult = GS_CapSegmentDefaults.CRITICAL, label = "Special hit cap" } } },
			EXPERTISE = { summary = "Expertise", overflow = GS_CapSegmentDefaults.OVERFLOW, segments = { { mode = "EXPERTISE_POINTS", threshold = 26, mult = GS_CapSegmentDefaults.CRITICAL, label = "Expertise soft cap" } } },
		},
	},
	BEASTMASTERY = {
		order = { "HIT" },
		pools = {
			HIT = { summary = "Hit", meleeHitBonus = 0, overflow = GS_CapSegmentDefaults.HIT_OVERFLOW, segments = { { mode = "MELEE_HIT_PERCENT", threshold = 8, mult = GS_CapSegmentDefaults.CRITICAL, label = "Ranged hit cap" } } },
		},
	},
	MARKSMANSHIP = {
		order = { "HIT", "ARP" },
		pools = {
			HIT = { summary = "Hit", meleeHitBonus = 0, overflow = GS_CapSegmentDefaults.HIT_OVERFLOW, segments = { { mode = "MELEE_HIT_PERCENT", threshold = 8, mult = GS_CapSegmentDefaults.CRITICAL, label = "Ranged hit cap" } } },
			ARP = { summary = "Armor Penetration", overflow = GS_CapSegmentDefaults.ARP_OVERFLOW, segments = { { mode = "RATING", threshold = 1400, mult = GS_CapSegmentDefaults.CRITICAL, label = "Armor penetration hard cap" } } },
		},
	},
	SURVIVAL = {
		order = { "HIT" },
		pools = {
			HIT = { summary = "Hit", meleeHitBonus = 0, overflow = GS_CapSegmentDefaults.HIT_OVERFLOW, segments = { { mode = "MELEE_HIT_PERCENT", threshold = 8, mult = GS_CapSegmentDefaults.CRITICAL, label = "Ranged hit cap" } } },
		},
	},
	ASSASSINATION = {
		order = { "HIT", "EXPERTISE" },
		pools = {
			HIT = { summary = "Hit", meleeHitBonus = 5, spellHitBonus = 5, progressMode = "SPELL_HIT_PERCENT", overflow = GS_CapSegmentDefaults.HIT_OVERFLOW, segments = { { mode = "MELEE_HIT_PERCENT", threshold = 8, mult = GS_CapSegmentDefaults.CRITICAL, label = "Special hit cap" }, { mode = "SPELL_HIT_PERCENT", threshold = 17, mult = GS_CapSegmentDefaults.USEFUL, label = "Poison hit cap" } } },
			EXPERTISE = { summary = "Expertise", overflow = GS_CapSegmentDefaults.OVERFLOW, segments = { { mode = "EXPERTISE_POINTS", threshold = 26, mult = GS_CapSegmentDefaults.CRITICAL, label = "Expertise soft cap" } } },
		},
	},
	COMBAT = {
		order = { "HIT", "EXPERTISE", "ARP" },
		pools = {
			HIT = { summary = "Hit", meleeHitBonus = 5, spellHitBonus = 5, progressMode = "SPELL_HIT_PERCENT", overflow = GS_CapSegmentDefaults.HIT_OVERFLOW, segments = { { mode = "MELEE_HIT_PERCENT", threshold = 8, mult = GS_CapSegmentDefaults.CRITICAL, label = "Special hit cap" }, { mode = "SPELL_HIT_PERCENT", threshold = 17, mult = GS_CapSegmentDefaults.USEFUL, label = "Poison hit cap" } } },
			EXPERTISE = { summary = "Expertise", overflow = GS_CapSegmentDefaults.OVERFLOW, segments = { { mode = "EXPERTISE_POINTS", threshold = 26, mult = GS_CapSegmentDefaults.CRITICAL, label = "Expertise soft cap" } } },
			ARP = { summary = "Armor Penetration", overflow = GS_CapSegmentDefaults.ARP_OVERFLOW, segments = { { mode = "RATING", threshold = 1400, mult = GS_CapSegmentDefaults.CRITICAL, label = "Armor penetration hard cap" } } },
		},
	},
	SUBTLETY = {
		order = { "HIT", "EXPERTISE" },
		pools = {
			HIT = { summary = "Hit", meleeHitBonus = 5, spellHitBonus = 5, progressMode = "SPELL_HIT_PERCENT", overflow = GS_CapSegmentDefaults.HIT_OVERFLOW, segments = { { mode = "MELEE_HIT_PERCENT", threshold = 8, mult = GS_CapSegmentDefaults.CRITICAL, label = "Special hit cap" }, { mode = "SPELL_HIT_PERCENT", threshold = 17, mult = GS_CapSegmentDefaults.USEFUL, label = "Poison hit cap" } } },
			EXPERTISE = { summary = "Expertise", overflow = GS_CapSegmentDefaults.OVERFLOW, segments = { { mode = "EXPERTISE_POINTS", threshold = 26, mult = GS_CapSegmentDefaults.CRITICAL, label = "Expertise soft cap" } } },
		},
	},
	SHADOW = {
		order = { "HIT" },
		pools = {
			HIT = { summary = "Spell Hit", spellHitBonus = 3, overflow = GS_CapSegmentDefaults.HIT_OVERFLOW, segments = { { mode = "SPELL_HIT_PERCENT", threshold = 17, mult = GS_CapSegmentDefaults.CRITICAL, label = "Spell hit cap" } } },
		},
	},
	BLOOD = {
		order = { "DEFENSE", "EXPERTISE", "HIT" },
		pools = {
			DEFENSE = { summary = "Defense", overflow = GS_CapSegmentDefaults.DEFENSE_OVERFLOW, segments = { { mode = "DEFENSE_SKILL", threshold = 540, mult = GS_CapSegmentDefaults.CRITICAL, label = "Crit immunity cap" } } },
			EXPERTISE = { summary = "Expertise", overflow = GS_CapSegmentDefaults.OVERFLOW, segments = { { mode = "EXPERTISE_POINTS", threshold = 26, mult = GS_CapSegmentDefaults.CRITICAL, label = "Expertise soft cap" }, { mode = "EXPERTISE_POINTS", threshold = 56, mult = GS_CapSegmentDefaults.USEFUL, label = "Front-facing expertise cap" } } },
			HIT = { summary = "Hit", meleeHitBonus = 0, overflow = GS_CapSegmentDefaults.HIT_OVERFLOW, segments = { { mode = "MELEE_HIT_PERCENT", threshold = 8, mult = GS_CapSegmentDefaults.CRITICAL, label = "Special hit cap" } } },
		},
	},
	FROST = {
		order = { "HIT", "EXPERTISE" },
		pools = {
			HIT = { summary = "Hit", meleeHitBonus = 0, overflow = GS_CapSegmentDefaults.HIT_OVERFLOW, segments = { { mode = "MELEE_HIT_PERCENT", threshold = 8, mult = GS_CapSegmentDefaults.CRITICAL, label = "Special hit cap" } } },
			EXPERTISE = { summary = "Expertise", overflow = GS_CapSegmentDefaults.OVERFLOW, segments = { { mode = "EXPERTISE_POINTS", threshold = 26, mult = GS_CapSegmentDefaults.CRITICAL, label = "Expertise soft cap" } } },
		},
	},
	UNHOLY = {
		order = { "HIT", "EXPERTISE" },
		pools = {
			HIT = { summary = "Hit", meleeHitBonus = 0, overflow = GS_CapSegmentDefaults.HIT_OVERFLOW, segments = { { mode = "MELEE_HIT_PERCENT", threshold = 8, mult = GS_CapSegmentDefaults.CRITICAL, label = "Special hit cap" } } },
			EXPERTISE = { summary = "Expertise", overflow = GS_CapSegmentDefaults.OVERFLOW, segments = { { mode = "EXPERTISE_POINTS", threshold = 26, mult = GS_CapSegmentDefaults.CRITICAL, label = "Expertise soft cap" } } },
		},
	},
	ELEMENTAL = {
		order = { "HIT" },
		pools = {
			HIT = { summary = "Spell Hit", spellHitBonus = 3, overflow = GS_CapSegmentDefaults.HIT_OVERFLOW, segments = { { mode = "SPELL_HIT_PERCENT", threshold = 17, mult = GS_CapSegmentDefaults.CRITICAL, label = "Spell hit cap" } } },
		},
	},
	ENHANCEMENT = {
		order = { "HIT", "EXPERTISE" },
		pools = {
			HIT = { summary = "Hit", meleeHitBonus = 3, spellHitBonus = 3, overflow = GS_CapSegmentDefaults.HIT_OVERFLOW, segments = { { mode = "MELEE_HIT_PERCENT", threshold = 8, mult = GS_CapSegmentDefaults.CRITICAL, label = "Special hit cap" }, { mode = "SPELL_HIT_PERCENT", threshold = 17, mult = GS_CapSegmentDefaults.USEFUL, label = "Spell hit cap" } } },
			EXPERTISE = { summary = "Expertise", overflow = GS_CapSegmentDefaults.OVERFLOW, segments = { { mode = "EXPERTISE_POINTS", threshold = 26, mult = GS_CapSegmentDefaults.CRITICAL, label = "Expertise soft cap" } } },
		},
	},
	ARCANE = {
		order = { "HIT" },
		pools = {
			HIT = { summary = "Spell Hit", spellHitBonus = 3, overflow = GS_CapSegmentDefaults.HIT_OVERFLOW, segments = { { mode = "SPELL_HIT_PERCENT", threshold = 17, mult = GS_CapSegmentDefaults.CRITICAL, label = "Spell hit cap" } } },
		},
	},
	FIRE = {
		order = { "HIT" },
		pools = {
			HIT = { summary = "Spell Hit", spellHitBonus = 3, overflow = GS_CapSegmentDefaults.HIT_OVERFLOW, segments = { { mode = "SPELL_HIT_PERCENT", threshold = 17, mult = GS_CapSegmentDefaults.CRITICAL, label = "Spell hit cap" } } },
		},
	},
	MAGE_FROST = {
		order = { "HIT" },
		pools = {
			HIT = { summary = "Spell Hit", spellHitBonus = 3, overflow = GS_CapSegmentDefaults.HIT_OVERFLOW, segments = { { mode = "SPELL_HIT_PERCENT", threshold = 17, mult = GS_CapSegmentDefaults.CRITICAL, label = "Spell hit cap" } } },
		},
	},
	AFFLICTION = {
		order = { "HIT" },
		pools = {
			HIT = { summary = "Spell Hit", spellHitBonus = 3, overflow = GS_CapSegmentDefaults.HIT_OVERFLOW, segments = { { mode = "SPELL_HIT_PERCENT", threshold = 17, mult = GS_CapSegmentDefaults.CRITICAL, label = "Spell hit cap" } } },
		},
	},
	DEMONOLOGY = {
		order = { "HIT" },
		pools = {
			HIT = { summary = "Spell Hit", spellHitBonus = 0, overflow = GS_CapSegmentDefaults.HIT_OVERFLOW, segments = { { mode = "SPELL_HIT_PERCENT", threshold = 17, mult = GS_CapSegmentDefaults.CRITICAL, label = "Spell hit cap" } } },
		},
	},
	DESTRUCTION = {
		order = { "HIT" },
		pools = {
			HIT = { summary = "Spell Hit", spellHitBonus = 0, overflow = GS_CapSegmentDefaults.HIT_OVERFLOW, segments = { { mode = "SPELL_HIT_PERCENT", threshold = 17, mult = GS_CapSegmentDefaults.CRITICAL, label = "Spell hit cap" } } },
		},
	},
	BALANCE = {
		order = { "HIT" },
		pools = {
			HIT = { summary = "Spell Hit", spellHitBonus = 4, overflow = GS_CapSegmentDefaults.HIT_OVERFLOW, segments = { { mode = "SPELL_HIT_PERCENT", threshold = 17, mult = GS_CapSegmentDefaults.CRITICAL, label = "Spell hit cap" } } },
		},
	},
	FERAL = {
		order = { "HIT", "EXPERTISE", "ARP" },
		pools = {
			HIT = { summary = "Hit", meleeHitBonus = 0, overflow = GS_CapSegmentDefaults.HIT_OVERFLOW, segments = { { mode = "MELEE_HIT_PERCENT", threshold = 8, mult = GS_CapSegmentDefaults.CRITICAL, label = "Special hit cap" } } },
			EXPERTISE = { summary = "Expertise", overflow = GS_CapSegmentDefaults.OVERFLOW, segments = { { mode = "EXPERTISE_POINTS", threshold = 26, mult = GS_CapSegmentDefaults.CRITICAL, label = "Expertise soft cap" } } },
			ARP = { summary = "Armor Penetration", overflow = GS_CapSegmentDefaults.ARP_OVERFLOW, segments = { { mode = "RATING", threshold = 1400, mult = GS_CapSegmentDefaults.CRITICAL, label = "Armor penetration hard cap" } } },
		},
	},
}
