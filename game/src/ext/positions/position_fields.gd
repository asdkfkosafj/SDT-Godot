extends RefCounted
## The keys of an animtools position file (animtools V40's format), in the order animtools writes them, with the
## value a full position starts from (animtools' reset values: for the oral keys these are the vanilla "default"
## position's). Props add six keys each. Written from the mod's position files and its documentation.
##
## Kinds are not stored here yet: every value is a number (a flag is 0 / 1, "unset" is -5000 or -999, angles of the
## tweens and the torso are radians, the penis offsets and hand angles degrees).

const VERSION := 40   # the posversion this port reads as current (animtools V40)

## [key, default] in animtools' writing order (its saveme / generatesettings); posversion is written first.
const FIELDS: Array = [
	["positiontype", 0.0], ["camerax", 290.0], ["cameray", 50.0], ["zoom", 0.4], ["scenerotation", 0.0],
	["hertweenstartx", -40.0], ["hertweenstarty", 270.0], ["hertweenendx", 250.0], ["hertweenendy", 367.3],
	["histweenstartx", 420.0], ["histweenstarty", 135.0], ["histweenendx", 340.0], ["histweenendy", 135.0],
	["leftfootx", 625.0], ["leftfooty", 1315.0], ["rightfootx", 620.0], ["rightfooty", 1168.0],
	["torsox", 160.0], ["torsoy", 1240.0], ["torsox2", 160.0], ["torsoy2", 1240.0],
	["histweenstartskewx", 0.0], ["histweenstartskewy", 0.0], ["histweenendskewx", 0.0], ["histweenendskewy", 0.0],
	["histweenstartang", -0.05235987755982988], ["histweenendangle", 0.0], ["offpathposmovement", 80.0],
	["hertweenstartang", -0.2617993877991494], ["hertweenendangle", -0.3490658503988659],
	["torsominang", 4.3], ["torsoikoffsetang", 2.245844289545065], ["torsoendrotationangle", 0.0],
	["leftlegoffsetangle", -5000.0], ["leftlegcalfangle", -5000.0], ["torsoanglemodifier", 0.61],
	["torsomindistance", 180.0], ["torsodistancemultiplier", 35.0], ["torsostartdistance", 130.0],
	["torsostartangle", 3.43],
	["himhidden", 1.0], ["himpenishidden", -1.0], ["himloaderarmhidden", -1.0], ["himreversed", 0.0],
	["himflipped", 0.0], ["behindleg", 0.0], ["hidehershadow", 0.0],
	["undovanillavigourmovechanges", 0.0], ["undoallvanillavigourincreases", 0.0], ["resistivevigor", 1.0],
	["continuousresistivevigourmult", 0.8], ["resistivevigourspaceheldmult", 0.05], ["resistivevigourmult", 0.3],
	["resistivevigourspeedmult", 0.5],
	["armpostypeleft", -1.0], ["armpostyperight", -1.0],
	["armposx", -5000.0], ["armposy", -5000.0], ["armposxend", -5000.0], ["armposyend", -5000.0],
	["armpos2x", -5000.0], ["armpos2y", -5000.0], ["armpos2xend", -5000.0], ["armpos2yend", -5000.0],
	["allowleftarmtap", 1.0], ["allowrightarmtap", 1.0],
	["handangler", -50.0], ["handanglel", -50.0], ["handanglerend", -5000.0], ["handanglelend", -5000.0],
	["handrinverted", 0.0], ["handlinverted", 0.0], ["rubhandright", 0.0], ["rubhandleft", 0.0],
	["setpenisoutbehind", 0.0], ["leftbreastbehind", 0.0],
	["hispenisrotationoffset", 0.0], ["hispenisrotationoffsetend", 0.0], ["usesteadypenis", 0.0],
	["bodycontactsounds", 0.0], ["bodycontactsoundsinspeed", 0.1], ["bodycontactsoundsoutspeed", -0.1],
	["hidestrandsinbodycontact", 0.0], ["adjustspeedinbodycontact", 0.0],
	["pleasurefromcontact", 0.0], ["pleasurefromcontactmult", 1.5],
	["changegravityforstrands", 0.0], ["changegravityforhairstrands", 0.0], ["angledgravity", 2.0],
	["resistancewithbodycontact", 0.0], ["resistancestartingdistance", 20.0], ["startingresistance", 3.5],
	["minresistance", -0.01], ["movementresistancemult", 0.02], ["resistoverriderate", 0.01],
	["resistoverridereturnrate", 0.2], ["resistoverridemax", 200.0], ["resistnormalizerate", 0.002],
	["resistdecreaserate", 0.001],
	["userightclosehand", 0.0], ["useleftclosehand", 0.0], ["spaceholdresist", 0.0], ["enablelicking", 2.0],
	["hisarmfree", 2.0], ["usepenisrangebodycontactmask", 1.0], ["zoompointx", 105.0], ["zoompointy", 180.0],
	["maxpenissize", 999.0], ["dominant", 0.0],
	["bodycontactvigour", 0.0], ["bodycontactvigourspeedmult", 1.0], ["bodycontactvigourcontinuousamount", 3.0],
	["DAhermasterbate", 0.0], ["allowleftarmdrop", 1.0], ["allowrightarmdrop", 1.0],
	["enablehiscustomarm", 0.0],
	["shoulderpointstartx", 60.0], ["shoulderpointstarty", -445.0], ["shoulderpointendx", 225.0],
	["shoulderpointendy", -590.0], ["handpointrestx", -270.0], ["handpointresty", -160.0],
	["handpointstartx", -175.0], ["handpointstarty", 40.0], ["handpointendx", 175.0], ["handpointendy", 130.0],
	["reversescreen", 0.0], ["altarmfollows", 1.0],
	["handpointaltrestx", -270.0], ["handpointaltresty", -160.0], ["handpointaltstartx", -175.0],
	["handpointaltstarty", 40.0], ["handpointaltendx", 175.0], ["handpointaltendy", 130.0],
	["hishandstartrotation", -5000.0], ["hishandendrotation", -5000.0], ["hishandrottarget", 1.0],
	["savedBodySize", -999.0],
]

## The props: [name, x, y, scale] (animtools' <prop>defaults); keys <name>active / x / y / scalex / scaley /
## rotation, off by default.
const PROPS: Array = [
	["ottomon", -700.0, 100.0, 3.0], ["sybian_without_tool", -700.0, 100.0, 3.0],
	["stuffed_chair_left", -1400.0, -100.0, 3.5], ["stuffed_chair_right", -1400.0, -100.0, 3.5],
	["wood_table", -700.0, 100.0, 3.0], ["metal_table", -700.0, 100.0, 3.0], ["leather_couch", -700.0, 100.0, 3.0],
	["bed_right_higher", -700.0, 100.0, 3.0], ["bed_end", -700.0, 100.0, 3.0], ["staircase", -400.0, -900.0, 4.0],
	["lounge_chair", -700.0, -50.0, 2.5], ["sofa", -900.0, 50.0, 2.5], ["sofa_large", -450.0, -200.0, 2.5],
	["sofa_reclaime", -700.0, -150.0, 2.5],
]

## Keys older files carry that animtools reads but no longer writes (used by the version conversion, then dropped).
const LEGACY := {"anglepeniswhenreversed": 1.0, "handrontit": 0.0, "handlontit": 0.0}

## animtools' global settings (its settings file, V40 as shipped: the defaults of the matching options here). A
## position file may set them too (the _partial files that switch preV33herarmonlegs); such values are kept apart.
const SETTINGS := {
	"enablecharvoicesaving": 1, "enablesexexpsaving": 1, "enablecharpositionsaving": 0,
	"disablebodyintro": 0, "characterresistancepreset": 3, "dialogactionsenabled": 1, "disablesweatonchange": 1,
	"allowcamerazoomchanges": 1, "allowcameraxychanges": 1, "allowcamerarotationchanges": 1,
	"allowpenissizechanging": 1, "allowvigourchanges": 1, "resetarmsonpositionreset": 0,
	"reloadarmsaftercharcode": 1, "alwaysresetmissingsettings": 0, "pullbackonpositionchange": 1,
	"pullbackonpenischange": 0, "pullbackonzoomchange": 0, "allowoldzoompoint": 0,
	"preventswitchinganglehandsforoldpositions": 0, "useshade": 0, "disableshadeonpartial": 1,
	"shadertimelength": 18, "enableshadyDAinjection": 1, "hairgravityapplyoffset": 1, "maxhairrangetochange": 25,
	"minhairrangetochange": -25, "disableteethclenching": 0, "enablelegmountbodyscaling": 1,
	"legmountscalefactor": 80, "usefallbacklegmountbodyscaling": 0, "fallbacklegmountbodyscaling": 0.4,
	"usebackwardscompatarms": 1, "assumepartialsareofequalversion": 1, "usemovementvigourforvigorousbodyexited": 1,
	"disablevanillavigourdialogwhenbodycontact": 2, "nopullbackforherstationarypositions": 1,
	"nopullbackdistrequirement": 225, "spurtanglerandomamount": 0.5, "preV33herarmonlegs": 0,
	"handrubspeed": 0.05, "enablehandrubcharcodesave": 1, "managevanillalefthimarm": 1, "nosesquashposmin": 0.9,
	"disablebodycontactsounds": 0, "bodycontactentrysoundtype": 4, "bodycontactexitsoundtype": 4,
	"bodycontactentryexitspeeddiff": 0.055, "bodycontacthiltsounds": 1, "bodycontacthiltgrabsound": 1,
	"grabsoundbodycontacthiltspeedtarget": 0.7, "grabsoundbodycontacthiltspeedtargetcap": 2,
	"bodycontacthiltlicksound": 1, "licksoundbodycontacthiltspeedtarget": 0.2,
	"licksoundbodycontacthiltspeedtargetcap": 0.5, "bodycontacthiltsplatsound": 0,
	"splatsoundbodycontacthiltspeedtarget": 0.8, "splatsoundbodycontacthiltspeedtargetcap": 2,
	"bodycontacthilttouchsound": 1, "touchsoundbodycontacthiltspeedtarget": 0.5,
	"touchsoundbodycontacthiltspeedtargetcap": 0.7,
	"bodycontactspaceheldpushpriority": 1, "bodycontactspaceheldpushlife": 120,
	"bodycontactspaceheldpushdelaybuild": 500, "bodycontactspaceheldpushinhiltpriority": 1,
	"bodycontactspaceheldpushinhiltlife": 120, "bodycontactspaceheldpushinhiltdelaybuild": 500,
	"cuminherpriority": 2, "cuminherlife": 320, "bodycontacthiltpriority": 2, "bodycontacthiltlife": 320,
	"bodycontacthiltdelaybuild": 500, "bodyenteredpriority": 0, "bodyenteredlife": 80, "bodyentereddelaybuild": 1000,
	"bodyexitedpriority": 0, "bodyexitedlife": 80, "bodyexiteddelaybuild": 1000, "inbodypriority": 0,
	"inbodylife": 40, "inbodydelaybuild": 1000, "inbodytimerequirement": 50, "bodycontactloosepriority": 1,
	"bodycontactlooselife": 170, "bodycontactloosedelaybuild": 800, "vigorousbodyexitedpriority": 1,
	"vigorousbodyexitedlife": 130, "vigorousbodyexiteddelaybuild": 300, "vigorousbodyexitedrelaxpriority": 1,
	"vigorousbodyexitedrelaxlife": 160, "vigorousbodyexitedrelaxdelaybuild": 300,
	"vigorousbodyexitedrelaxtimerequirement": 90, "bodycontactresistivepriority": 1, "bodycontactresistivelife": 100,
	"bodycontactresistivedelaybuild": 200, "bodycontactresistivethreshhold": 1.3,
	"bodycontactmovementvigourpriority": 1, "bodycontactmovementvigourlife": 120,
	"bodycontactmovementvigourdelaybuild": 200,
	"autoclosemouth_closefororal": 0, "autoclosemouth_closefortit": 0, "autoclosemouth_closeforvaginal": 0,
	"autoclosemouth_closeforanal": 0, "autoclosemouth_closeforother": 0, "autoclosemouth_openfororal": 0,
	"autoclosemouth_openfortit": 0, "autoclosemouth_openforvaginal": 0, "autoclosemouth_openforanal": 0,
	"autoclosemouth_openforother": 0,
	"disablehunniepopsounds": 0, "currentvoicechar": 0, "matchAnimtoolsVoiceGrunts": 1,
	"playhardvigourrequired": 90, "playhardvigourrequiredhigh": 110, "playhardvigourchangerequired": 0.5,
	"playhardvigourchangerequiredhigh": 999, "playhardspeedrequired": 0, "playhardspeedrequiredhigh": 99,
	"playhardposrequired": 0, "playhardposrequiredhigh": 1.5, "playmediumvigourrequired": 40,
	"playmediumvigourrequiredhigh": 110, "playmediumvigourchangerequired": 4, "playmediumvigourchangerequiredhigh": 999,
	"playmediumspeedrequired": 0, "playmediumspeedrequiredhigh": 99, "playmediumposrequired": 0,
	"playmediumposrequiredhigh": 1.5, "playsoftvigourrequired": 10, "playsoftvigourrequiredhigh": 110,
	"playsoftvigourchangerequired": 5, "playsoftvigourchangerequiredhigh": 999, "playsoftspeedrequired": 0.02,
	"playsoftspeedrequiredhigh": 99, "playsoftposrequired": 0, "playsoftposrequiredhigh": 1.5,
	"soundlevellow": 0.4, "soundlevelmedium": 0.55, "soundlevelhigh": 0.7, "soundlevelmediumvigourchange": 10,
	"soundlevelhighvigourchange": 20, "masterrepeatdelay": 35, "masterrepeatdelayrandom": 10, "softrepeatdelay": 75,
	"mediumrepeatdelay": 55, "hardrepeatdelay": 35,
}

static var _defaults: Dictionary = {}
static var _order: PackedStringArray = PackedStringArray()


## Every position key -> its default, the props' keys included (a full position starts from these).
static func defaults() -> Dictionary:
	if _defaults.is_empty():
		for f in FIELDS:
			_defaults[f[0]] = f[1]
		for p in PROPS:
			_defaults[p[0] + "active"] = 0.0
			_defaults[p[0] + "x"] = p[1]
			_defaults[p[0] + "y"] = p[2]
			_defaults[p[0] + "scalex"] = p[3]
			_defaults[p[0] + "scaley"] = p[3]
			_defaults[p[0] + "rotation"] = 0.0
	return _defaults


## The keys in writing order (without posversion).
static func order() -> PackedStringArray:
	if _order.is_empty():
		for f in FIELDS:
			_order.append(f[0])
		for p in PROPS:
			for s in ["active", "x", "y", "scalex", "scaley", "rotation"]:
				_order.append(p[0] + s)
	return _order


static func is_field(key: String) -> bool:
	return defaults().has(key)
