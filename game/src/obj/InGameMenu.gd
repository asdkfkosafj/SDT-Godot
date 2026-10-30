class_name InGameMenu
extends FlashMovieClip
## Port of obj.InGameMenu: the slide-up options drawer (scene / customisation / modding / options / help tabs),
## colour pickers, character save string (getSaveDataString / loadData) and stored-character backups.
## Drafted with tools/porting/as3_to_gd.py and reviewed by hand against the original.

var tabLabels
var helpMenu
var characterMenu
var customMenu
var sceneMenu
var optionsMenu
var menuDrawerLip
var rgbPicker
var moddingMenu
var closeButton
var tab1
var tab2
var tab3
var hslPicker
var tab4
var charStoring
var tab5
var slideIn = 600
var slideOut = 830
var slidingIn = false
var slidingOut = false
var slideSmooth = 2
var menuOpen = false
var menuOver = false
var drawerArrowShowing = false
var overTimer = 0
var offTimer = 0
var openDelay = 15
var closeDelay = 15
var currentTab = 1
var costumeMenuScroller
var costumeMenu
var himMenuScroller
var himMenu
var charNames
var charMenuOpen = false
var charMenuJustOpened = false
var charStoringOpen = false
var charStoringJustOpened = false
var irisTypes
var skinTypes
var rgbPickerOpen = false
var rgbPickerJustOpened = false
var rgbPickerTarget
var rgbTargetFill
var eyedropperOn = false
var eyedropperCursor
var hslPickerOpen = false
var hslPickerJustOpened = false
var hslPickerTarget
var hslPickerRemoveTarget
var lipstickSwatch
var irisSwatch
var eyebrowSwatch
var eyeShadowSwatch
var blushSwatch
var legwearSwatch
var underwearSwatch
var currentSwatch
var clipboardSwatch
var clipboardARGB
var storedCharsBackup
var savingStoredCharsBackup = false
var browsingForStoredCharsBackup = false
var dialogueFile
var savingDialogue = false
var browsingForDialogue = false
var onlyLoadCostume = false


func _init():
	super()
	var _loc2_ = null
	var _loc3_ = null
	y = slideOut
	storedCharsBackup = FlashFileReference.new()
	storedCharsBackup.start_dir = Flash.mods_dir("Characters")
	storedCharsBackup.addEventListener(FlashEvent.COMPLETE,storedCharsCompleteHandler)
	storedCharsBackup.addEventListener(FlashEvent.SELECT,storedCharsSelectHandler)
	storedCharsBackup.addEventListener(FlashEvent.CANCEL,storedCharsCancelHandler)
	dialogueFile = FlashFileReference.new()
	dialogueFile.start_dir = Flash.mods_dir("Dialogue")
	dialogueFile.addEventListener(FlashEvent.COMPLETE,dialogueCompleteHandler)
	dialogueFile.addEventListener(FlashEvent.SELECT,dialogueSelectHandler)
	dialogueFile.addEventListener(FlashEvent.CANCEL,dialogueCancelHandler)
	clipboardSwatch = Flash.create("PickerSwatch")
	clipboardSwatch.cross.visible = false
	clipboardSwatch.visible = false
	addChild(clipboardSwatch)
	lipstickSwatch = []
	lipstickSwatch.append({ "r":0, "g":0, "b":0, "a":0 })
	lipstickSwatch.append({ "r":84, "g":0, "b":6, "a":1 })
	lipstickSwatch.append({ "r":197, "g":64, "b":109, "a":1 })
	lipstickSwatch.append({ "r":255, "g":167, "b":188, "a":1 })
	lipstickSwatch.append({ "r":232, "g":188, "b":242, "a":1 })
	lipstickSwatch.append({ "r":105, "g":39, "b":178, "a":1 })
	lipstickSwatch.append({ "r":63, "g":118, "b":162, "a":1 })
	lipstickSwatch.append({ "r":0, "g":0, "b":0, "a":1 })
	lipstickSwatch.append({ "r":255, "g":255, "b":255, "a":1 })
	irisSwatch = []
	irisSwatch.append({ "r":0, "g":0, "b":0, "a":0 })
	irisSwatch.append({ "r":56, "g":100, "b":137, "a":1 })
	irisSwatch.append({ "r":66, "g":90, "b":120, "a":1 })
	irisSwatch.append({ "r":46, "g":111, "b":100, "a":1 })
	irisSwatch.append({ "r":23, "g":57, "b":102, "a":1 })
	irisSwatch.append({ "r":71, "g":18, "b":28, "a":1 })
	irisSwatch.append({ "r":62, "g":39, "b":29, "a":1 })
	irisSwatch.append({ "r":70, "g":100, "b":37, "a":1 })
	irisSwatch.append({ "r":0, "g":0, "b":0, "a":1 })
	eyebrowSwatch = []
	eyebrowSwatch.append({ "r":0, "g":0, "b":0, "a":0 })
	eyebrowSwatch.append({ "r":89, "g":67, "b":51, "a":1 })
	eyebrowSwatch.append({ "r":189, "g":142, "b":61, "a":1 })
	eyebrowSwatch.append({ "r":87, "g":53, "b":32, "a":1 })
	eyebrowSwatch.append({ "r":105, "g":121, "b":137, "a":1 })
	eyebrowSwatch.append({ "r":33, "g":33, "b":51, "a":1 })
	eyebrowSwatch.append({ "r":50, "g":34, "b":33, "a":1 })
	eyebrowSwatch.append({ "r":0, "g":0, "b":0, "a":1 })
	eyebrowSwatch.append({ "r":255, "g":255, "b":255, "a":1 })
	eyeShadowSwatch = []
	eyeShadowSwatch.append({ "r":0, "g":0, "b":0, "a":0 })
	eyeShadowSwatch.append({ "r":55, "g":26, "b":99, "a":1 })
	eyeShadowSwatch.append({ "r":124, "g":20, "b":178, "a":1 })
	eyeShadowSwatch.append({ "r":24, "g":12, "b":90, "a":1 })
	eyeShadowSwatch.append({ "r":255, "g":48, "b":109, "a":1 })
	eyeShadowSwatch.append({ "r":0, "g":66, "b":137, "a":1 })
	eyeShadowSwatch.append({ "r":16, "g":58, "b":24, "a":1 })
	eyeShadowSwatch.append({ "r":0, "g":0, "b":0, "a":1 })
	eyeShadowSwatch.append({ "r":255, "g":255, "b":255, "a":1 })
	legwearSwatch = []
	legwearSwatch.append({ "r":0, "g":0, "b":0, "a":0 })
	legwearSwatch.append({ "r":22, "g":8, "b":0, "a":1 })
	legwearSwatch.append({ "r":82, "g":0, "b":6, "a":1 })
	legwearSwatch.append({ "r":255, "g":126, "b":167, "a":0.8 })
	legwearSwatch.append({ "r":0, "g":26, "b":114, "a":1 })
	legwearSwatch.append({ "r":74, "g":20, "b":126, "a":0.9 })
	legwearSwatch.append({ "r":63, "g":118, "b":162, "a":1 })
	legwearSwatch.append({ "r":0, "g":0, "b":0, "a":1 })
	legwearSwatch.append({ "r":255, "g":255, "b":255, "a":0.8 })
	underwearSwatch = lipstickSwatch.slice(1)
	underwearSwatch.insert(underwearSwatch.size() - 2, { "r":128, "g":128, "b":128, "a":1 })
	blushSwatch = eyeShadowSwatch.duplicate()
	blushSwatch[0] = { "r":196, "g":80, "b":77, "a":0.35 }
	var _loc1_ = 0
	while _loc1_ <= 8:
		rgbPicker["swatch" + str(_loc1_)].cross.visible = false
		_loc2_ = getSwatchHandler(_loc1_)
		rgbPicker["swatch" + str(_loc1_)].addEventListener(FlashEvent.CLICK,_loc2_)
		_loc1_ += 1
	rgbPicker.visible = false
	rgbPicker.rSlider.giveLabel(rgbPicker.rLabel)
	rgbPicker.gSlider.giveLabel(rgbPicker.gLabel)
	rgbPicker.bSlider.giveLabel(rgbPicker.bLabel)
	rgbPicker.alphaControls.aSlider.giveLabel(rgbPicker.alphaControls.aLabel)
	hslPicker.visible = false
	hslPicker.swatch0.cross.visible = true
	hslPicker.swatch0.swatchFill.alpha = 0
	hslPicker.hSlider.giveLabel(hslPicker.hLabel)
	hslPicker.sSlider.giveLabel(hslPicker.sLabel)
	hslPicker.lSlider.giveLabel(hslPicker.lLabel)
	hslPicker.cSlider.giveLabel(hslPicker.cLabel)
	hslPicker.hSlider.setLabelRange(-180,360)
	hslPicker.sSlider.setLabelRange(0,400)
	hslPicker.lSlider.setLabelRange(0,400)
	hslPicker.cSlider.setLabelRange(0,400)
	hslPicker.swatch0.addEventListener(FlashEvent.CLICK,hslRemoveClicked)
	tabLabels.mouseEnabled = false
	tabLabels.mouseChildren = false
	addEventListener(FlashEvent.ENTER_FRAME,tick)
	addEventListener(FlashEvent.ROLL_OVER,rolledOver)
	addEventListener(FlashEvent.ROLL_OUT,rolledOut)
	addEventListener(FlashEvent.CLICK,menuClicked)
	menuDrawerLip.arrow.addEventListener(FlashEvent.CLICK,drawerArrowClicked)
	tab1.addEventListener(FlashEvent.CLICK,tab1Clicked)
	tab2.addEventListener(FlashEvent.CLICK,tab2Clicked)
	tab3.addEventListener(FlashEvent.CLICK,tab3Clicked)
	tab4.addEventListener(FlashEvent.CLICK,tab4Clicked)
	tab5.addEventListener(FlashEvent.CLICK,tab5Clicked)
	closeButton.addEventListener(FlashEvent.CLICK,closeClicked)
	characterMenu.closeButton.addEventListener(FlashEvent.CLICK,characterMenuCloseClicked)
	characterMenu.giveButton(sceneMenu.mbCharacterMenu)
	charNames = g.characterControl.getCharacterList()
	characterMenu.instanceBaseChars(charNames)
	characterMenu.visible = false
	sceneMenu.mbCharacterMenu.addEventListener(FlashEvent.CLICK,mbCharacterMenuClicked)
	_loc1_ = 1
	while _loc1_ <= g.bgNum:
		_loc3_ = getBGHandler(_loc1_)
		sceneMenu["cbBG" + str(_loc1_)].addEventListener(FlashEvent.CLICK,_loc3_)
		_loc1_ += 1
	sceneMenu.cbStyle1.addEventListener(FlashEvent.CLICK,style1Clicked)
	sceneMenu.cbStyle2.addEventListener(FlashEvent.CLICK,style2Clicked)
	sceneMenu.cbMoodNormal.addEventListener(FlashEvent.CLICK,moodNormalClicked)
	sceneMenu.cbMoodHappy.addEventListener(FlashEvent.CLICK,moodHappyClicked)
	sceneMenu.cbMoodAngry.addEventListener(FlashEvent.CLICK,moodAngryClicked)
	sceneMenu.cbMoodAhegao.addEventListener(FlashEvent.CLICK,moodAhegaoClicked)
	sceneMenu.zoomSlider.setRangeEnd(75)
	sceneMenu.zoomSlider.addEventListener("handleReleased",zoomSliderReleased)
	sceneMenu.zoomSlider.addEventListener("sliderChanged",zoomSliderChanged)
	sceneMenu.mbDefaultZoom.addEventListener(FlashEvent.CLICK,mbDefaultZoomClicked)
	himMenu = sceneMenu.himMenu
	HimBody.setBodyMenuContainer(himMenu.bodyMenuContainer)
	himMenuScroller = ScrollingArea.new(200,180,himMenu,60)
	himMenuScroller.x = 135
	himMenuScroller.y = -91
	sceneMenu.addChild(himMenuScroller)
	g.him.setHimMenu(himMenu,underwearSwatch)
	himMenu.penisLengthSlider.setRangeEnd(98)
	himMenu.penisLengthSlider.addEventListener("handleReleased",penisLengthSliderReleased)
	himMenu.penisLengthSlider.addEventListener("sliderChanged",penisLengthSliderChanged)
	himMenu.mbDefaultPenisLength.addEventListener(FlashEvent.CLICK,mbDefaultPenisLengthClicked)
	himMenu.penisWidthSlider.setRangeEnd(98)
	himMenu.penisWidthSlider.addEventListener("handleReleased",penisWidthSliderReleased)
	himMenu.penisWidthSlider.addEventListener("sliderChanged",penisWidthSliderChanged)
	himMenu.mbDefaultPenisWidth.addEventListener(FlashEvent.CLICK,mbDefaultPenisWidthClicked)
	himMenu.mlBody.leftArrow.addEventListener(FlashEvent.CLICK,hisBodyLeftClicked)
	himMenu.mlBody.rightArrow.addEventListener(FlashEvent.CLICK,hisBodyRightClicked)
	himMenu.mlHisArm.leftArrow.addEventListener(FlashEvent.CLICK,hisArmLeftClicked)
	himMenu.mlHisArm.rightArrow.addEventListener(FlashEvent.CLICK,hisArmRightClicked)
	himMenu.mlHisLeftArm.leftArrow.addEventListener(FlashEvent.CLICK,hisLeftArmLeftClicked)
	himMenu.mlHisLeftArm.rightArrow.addEventListener(FlashEvent.CLICK,hisLeftArmRightClicked)
	himMenu.mlBalls.leftArrow.addEventListener(FlashEvent.CLICK,ballsLeftClicked)
	himMenu.mlBalls.rightArrow.addEventListener(FlashEvent.CLICK,ballsRightClicked)
	himMenu.ballSizeSlider.setRangeEnd(98)
	himMenu.ballSizeSlider.addEventListener("handleReleased",ballSizeSliderReleased)
	himMenu.ballSizeSlider.addEventListener("sliderChanged",ballSizeSliderChanged)
	himMenu.mbDefaultBallSize.addEventListener(FlashEvent.CLICK,mbDefaultBallSizeClicked)
	costumeMenu = sceneMenu.costumeMenu
	costumeMenuScroller = ScrollingArea.new(220,180,costumeMenu,60)
	costumeMenuScroller.x = -98
	costumeMenuScroller.y = -91
	sceneMenu.addChild(costumeMenuScroller)
	g.her.setMenu(costumeMenu,underwearSwatch)
	costumeMenu.resistanceSlider.setRangeEnd(119)
	costumeMenu.resistanceSlider.addEventListener("handleReleased",resistanceSliderReleased)
	costumeMenu.resistanceSlider.addEventListener("sliderChanged",resistanceSliderChanged)
	costumeMenu.cbResetResistance.addEventListener(FlashEvent.CLICK,cbResetResistanceClicked)
	costumeMenu.mbDefaultResistance.addEventListener(FlashEvent.CLICK,mbDefaultResistanceClicked)
	costumeMenu.throatResistanceSlider.setRangeEnd(119)
	costumeMenu.throatResistanceSlider.addEventListener("handleReleased",throatResistanceSliderReleased)
	costumeMenu.throatResistanceSlider.addEventListener("sliderChanged",throatResistanceSliderChanged)
	costumeMenu.mbDefaultThroatResistance.addEventListener(FlashEvent.CLICK,mbDefaultThroatResistanceClicked)
	costumeMenu.mlLeftArm.leftArrow.addEventListener(FlashEvent.CLICK,leftArmLeftClicked)
	costumeMenu.mlLeftArm.rightArrow.addEventListener(FlashEvent.CLICK,leftArmRightClicked)
	costumeMenu.mlRightArm.leftArrow.addEventListener(FlashEvent.CLICK,rightArmLeftClicked)
	costumeMenu.mlRightArm.rightArrow.addEventListener(FlashEvent.CLICK,rightArmRightClicked)
	g.her.tan.registerMenuItems(costumeMenu.mlTan,costumeMenu.tanAlphaSlider)
	costumeMenu.mbSelectCostume.addEventListener(FlashEvent.CLICK,selectCostumeClicked)
	g.characterControl.collarControl.registerMenuList(costumeMenu.mlCollar)
	g.characterControl.collarControl.registerRGBButton(costumeMenu.rgbCollar,underwearSwatch,256,false)
	g.characterControl.collarControl.registerSecondaryRGBButton(costumeMenu.rgbCollar2,underwearSwatch,256,false)
	g.characterControl.gagControl.registerMenuList(costumeMenu.mlGag)
	g.characterControl.gagControl.registerRGBButton(costumeMenu.rgbGag,underwearSwatch,256,false)
	g.characterControl.cuffsControl.registerMenuList(costumeMenu.mlCuffs)
	g.characterControl.cuffsControl.registerRGBButton(costumeMenu.rgbCuffs,underwearSwatch,256,false)
	g.characterControl.cuffsControl.registerSecondaryRGBButton(costumeMenu.rgbCuffs2,underwearSwatch,256,false)
	g.characterControl.ankleCuffsControl.registerMenuList(costumeMenu.mlAnkleCuffs)
	g.characterControl.ankleCuffsControl.registerRGBButton(costumeMenu.rgbAnkleCuffs,underwearSwatch,256,false)
	g.characterControl.ankleCuffsControl.registerSecondaryRGBButton(costumeMenu.rgbAnkleCuffs2,underwearSwatch,256,false)
	g.characterControl.armwearControl.registerMenuList(costumeMenu.mlArmwear)
	g.characterControl.armwearControl.registerRGBButton(costumeMenu.rgbArmwear,underwearSwatch,256,false)
	g.characterControl.topControl.registerMenuList(costumeMenu.mlTop)
	g.characterControl.topControl.registerRGBButton(costumeMenu.rgbTop,underwearSwatch,256)
	g.characterControl.bottomsControl.registerMenuList(costumeMenu.mlBottoms)
	g.characterControl.bottomsControl.registerRGBButton(costumeMenu.rgbBottoms,underwearSwatch,256,false)
	g.characterControl.bottomsControl.registerSecondaryRGBButton(costumeMenu.rgbBottoms2,underwearSwatch,256,false)
	g.characterControl.legwearControl.registerMenuList(costumeMenu.mlLegwear)
	g.characterControl.legwearControl.registerRGBButton(costumeMenu.rgbLegwear,legwearSwatch,256)
	g.characterControl.legwearControl.registerSecondaryRGBButton(costumeMenu.rgbLegwear2,legwearSwatch,256)
	g.characterControl.legwearBControl.registerMenuList(costumeMenu.mlLegwearB)
	g.characterControl.legwearBControl.registerRGBButton(costumeMenu.rgbLegwearB,legwearSwatch,256)
	g.characterControl.legwearBControl.registerSecondaryRGBButton(costumeMenu.rgbLegwearB2,legwearSwatch,256)
	g.characterControl.footwearControl.registerMenuList(costumeMenu.mlFootwear)
	g.characterControl.footwearControl.registerRGBButton(costumeMenu.rgbFootwear,underwearSwatch,256,false)
	g.characterControl.footwearControl.registerSecondaryRGBButton(costumeMenu.rgbFootwear2,underwearSwatch,256,false)
	g.characterControl.eyewearControl.registerMenuList(costumeMenu.mlEyewear)
	g.characterControl.eyewearControl.registerRGBButton(costumeMenu.rgbEyewear,underwearSwatch,256,false)
	g.characterControl.pantiesControl.registerMenuList(costumeMenu.mlPanties)
	g.characterControl.pantiesControl.registerRGBButton(costumeMenu.rgbPanties,underwearSwatch,256,false)
	g.characterControl.braControl.registerMenuList(costumeMenu.mlBra)
	g.characterControl.braControl.registerRGBButton(costumeMenu.rgbBra,underwearSwatch,256,false)
	g.characterControl.tonguePiercingControl.registerMenuList(costumeMenu.mlTonguePiercing)
	g.characterControl.tonguePiercingControl.registerRGBButton(costumeMenu.rgbTonguePiercing,underwearSwatch,256,false)
	g.characterControl.nipplePiercingControl.registerMenuList(costumeMenu.mlNipplePiercing)
	g.characterControl.nipplePiercingControl.registerRGBButton(costumeMenu.rgbNipplePiercing,underwearSwatch,256,false)
	g.characterControl.bellyPiercingControl.registerMenuList(costumeMenu.mlBellyPiercing)
	g.characterControl.bellyPiercingControl.registerRGBButton(costumeMenu.rgbBellyPiercing,underwearSwatch,256,false)
	g.characterControl.earringControl.registerMenuList(costumeMenu.mlEarring)
	g.characterControl.earringControl.registerRGBButton(costumeMenu.rgbEarring,underwearSwatch,256,false)
	g.characterControl.headwearControl.registerMenuList(costumeMenu.mlHeadwear)
	_setupBGPicker()
	_setupDialoguePicker()
	g.characterControl.headwearControl.registerRGBButton(costumeMenu.rgbHeadwear,underwearSwatch,256,false)
	g.characterControl.headwearControl.registerSecondaryRGBButton(costumeMenu.rgbHeadwear2,underwearSwatch,256,false)
	sceneMenu.cbAuto.addEventListener(FlashEvent.CLICK,cbAutoClicked)
	sceneMenu.mlAuto.leftArrow.addEventListener(FlashEvent.CLICK,autoLeftClicked)
	sceneMenu.mlAuto.rightArrow.addEventListener(FlashEvent.CLICK,autoRightClicked)
	customMenu.mlHair.leftArrow.addEventListener(FlashEvent.CLICK,hairLeftClicked)
	customMenu.mlHair.rightArrow.addEventListener(FlashEvent.CLICK,hairRightClicked)
	customMenu.mlIris.leftArrow.addEventListener(FlashEvent.CLICK,irisLeftClicked)
	customMenu.mlIris.rightArrow.addEventListener(FlashEvent.CLICK,irisRightClicked)
	customMenu.mlSkin.leftArrow.addEventListener(FlashEvent.CLICK,skinLeftClicked)
	customMenu.mlSkin.rightArrow.addEventListener(FlashEvent.CLICK,skinRightClicked)
	customMenu.mlNose.leftArrow.addEventListener(FlashEvent.CLICK,noseLeftClicked)
	customMenu.mlNose.rightArrow.addEventListener(FlashEvent.CLICK,noseRightClicked)
	customMenu.mlEar.leftArrow.addEventListener(FlashEvent.CLICK,earLeftClicked)
	customMenu.mlEar.rightArrow.addEventListener(FlashEvent.CLICK,earRightClicked)
	customMenu.mlEyebrows.leftArrow.addEventListener(FlashEvent.CLICK,eyebrowsLeftClicked)
	customMenu.mlEyebrows.rightArrow.addEventListener(FlashEvent.CLICK,eyebrowsRightClicked)
	customMenu.breastSlider.setRangeEnd(100)
	customMenu.breastSlider.addEventListener("handleReleased",breastSliderReleased)
	customMenu.breastSlider.addEventListener("sliderChanged",breastSliderChanged)
	customMenu.bodySlider.setRangeEnd(100)
	customMenu.bodySlider.addEventListener("handleReleased",bodySliderReleased)
	customMenu.bodySlider.addEventListener("sliderChanged",bodySliderChanged)
	customMenu.mbDefaultBodyScale.addEventListener(FlashEvent.CLICK,mbDefaultBodyScaleClicked)
	customMenu.mascaraSlider.setRangeEnd(70)
	customMenu.mascaraSlider.addEventListener("handleReleased",mascaraSliderReleased)
	customMenu.mascaraSlider.addEventListener("sliderChanged",mascaraSliderChanged)
	customMenu.mbDefaultMascara.addEventListener(FlashEvent.CLICK,defaultMascaraClicked)
	customMenu.frecklesSlider.setRangeEnd(70)
	customMenu.frecklesSlider.addEventListener("handleReleased",frecklesSliderReleased)
	customMenu.frecklesSlider.addEventListener("sliderChanged",frecklesSliderChanged)
	customMenu.mbDefaultFreckles.addEventListener(FlashEvent.CLICK,defaultFrecklesClicked)
	customMenu.rgbEyeShadow.addEventListener(FlashEvent.CLICK,rgbEyeShadowClicked)
	customMenu.rgbLipstick.addEventListener(FlashEvent.CLICK,rgbLipstickClicked)
	customMenu.rgbIris.addEventListener(FlashEvent.CLICK,rgbIrisClicked)
	customMenu.rgbEyebrowFill.addEventListener(FlashEvent.CLICK,rgbEyebrowFillClicked)
	customMenu.rgbEyebrowLine.addEventListener(FlashEvent.CLICK,rgbEyebrowLineClicked)
	customMenu.rgbSclera.addEventListener(FlashEvent.CLICK,rgbScleraClicked)
	customMenu.rgbBlush.addEventListener(FlashEvent.CLICK,rgbBlushClicked)
	customMenu.rgbMascara.addEventListener(FlashEvent.CLICK,rgbMascaraClicked)
	customMenu.rgbFreckles.addEventListener(FlashEvent.CLICK,rgbFrecklesClicked)
	customMenu.rgbNailPolish.addEventListener(FlashEvent.CLICK,rgbNailPolishClicked)
	customMenu.dialogueNameTF.addEventListener(FlashEvent.CHANGE,dialogueNameChanged)
	customMenu.dialogueNameTF.addEventListener(FlashEvent.FOCUS_IN,textFieldFocusIn)
	customMenu.dialogueNameTF.addEventListener(FlashEvent.FOCUS_OUT,textFieldFocusOut)
	customMenu.mbClearDialogueName.addEventListener(FlashEvent.CLICK,mbClearDialogueNameClicked)
	customMenu.hslHerSkin.addEventListener(FlashEvent.CLICK,hslHerSkinClicked)
	customMenu.hslHerHair.addEventListener(FlashEvent.CLICK,hslHerHairClicked)
	customMenu.hslHisSkin.addEventListener(FlashEvent.CLICK,hslHisSkinClicked)
	customMenu.mbClearTints.addEventListener(FlashEvent.CLICK,clearTintsClicked)
	rgbPicker.closeButton.addEventListener(FlashEvent.CLICK,rgbPickerCloseClicked)
	rgbPicker.rSlider.addEventListener("handleReleased",rgbPickerReleased)
	rgbPicker.gSlider.addEventListener("handleReleased",rgbPickerReleased)
	rgbPicker.bSlider.addEventListener("handleReleased",rgbPickerReleased)
	rgbPicker.alphaControls.aSlider.addEventListener("handleReleased",rgbPickerReleased)
	rgbPicker.rSlider.addEventListener("sliderChanged",rgbPickerChanged)
	rgbPicker.gSlider.addEventListener("sliderChanged",rgbPickerChanged)
	rgbPicker.bSlider.addEventListener("sliderChanged",rgbPickerChanged)
	rgbPicker.alphaControls.aSlider.addEventListener("sliderChanged",rgbPickerChanged)
	rgbPicker.rLabel.addEventListener(FlashEvent.CHANGE,rgbPickerLabelChanged)
	rgbPicker.gLabel.addEventListener(FlashEvent.CHANGE,rgbPickerLabelChanged)
	rgbPicker.bLabel.addEventListener(FlashEvent.CHANGE,rgbPickerLabelChanged)
	rgbPicker.alphaControls.aLabel.addEventListener(FlashEvent.CHANGE,rgbPickerLabelChanged)
	rgbPicker.mbCopySwatch.addEventListener(FlashEvent.CLICK,copyRGBSwatchClicked)
	rgbPicker.mbPasteSwatch.addEventListener(FlashEvent.CLICK,pasteRGBSwatchClicked)
	rgbPicker.mbEyedropper.addEventListener(FlashEvent.CLICK,eyedropperClicked)
	hslPicker.closeButton.addEventListener(FlashEvent.CLICK,hslPickerCloseClicked)
	hslPicker.hSlider.addEventListener("handleReleased",hslPickerReleased)
	hslPicker.sSlider.addEventListener("handleReleased",hslPickerReleased)
	hslPicker.lSlider.addEventListener("handleReleased",hslPickerReleased)
	hslPicker.cSlider.addEventListener("handleReleased",hslPickerReleased)
	hslPicker.hSlider.addEventListener("sliderChanged",hslPickerChanged)
	hslPicker.sSlider.addEventListener("sliderChanged",hslPickerChanged)
	hslPicker.lSlider.addEventListener("sliderChanged",hslPickerChanged)
	hslPicker.cSlider.addEventListener("sliderChanged",hslPickerChanged)
	hslPicker.hLabel.addEventListener(FlashEvent.CHANGE,hslPickerLabelChanged)
	hslPicker.sLabel.addEventListener(FlashEvent.CHANGE,hslPickerLabelChanged)
	hslPicker.lLabel.addEventListener(FlashEvent.CHANGE,hslPickerLabelChanged)
	hslPicker.cLabel.addEventListener(FlashEvent.CHANGE,hslPickerLabelChanged)
	customMenu.cbLipstickSmearing.addEventListener(FlashEvent.CLICK,lipstickSmearingClicked)
	customMenu.mbShuffle.addEventListener(FlashEvent.CLICK,shuffleClicked)
	moddingMenu.mbGenerate.addEventListener(FlashEvent.CLICK,generateClicked)
	moddingMenu.mbLoad.addEventListener(FlashEvent.CLICK,loadClicked)
	moddingMenu.mbSaveDialogue.addEventListener(FlashEvent.CLICK,saveDialogueClicked)
	moddingMenu.mbLoadDialogue.addEventListener(FlashEvent.CLICK,loadDialogueClicked)
	moddingMenu.mbResetDefaultDialogue.addEventListener(FlashEvent.CLICK,resetDefaultDialogueClicked)
	moddingMenu.mbEditDialogue.addEventListener(FlashEvent.CLICK,editDialogueClicked)
	moddingMenu.mbStoreChar.addEventListener(FlashEvent.CLICK,storeCharClicked)
	moddingMenu.mbSaveBackup.addEventListener(FlashEvent.CLICK,saveBackupClicked)
	moddingMenu.mbLoadBackup.addEventListener(FlashEvent.CLICK,loadBackupClicked)
	moddingMenu.cbOverwriteCharList.addEventListener(FlashEvent.CLICK,cbOverwriteCharListClicked)
	moddingMenu.saveDataTF.addEventListener(FlashEvent.FOCUS_IN,textFieldFocusIn)
	moddingMenu.saveDataTF.addEventListener(FlashEvent.FOCUS_OUT,textFieldFocusOut)
	moddingMenu.dialogueLibraryName.addEventListener(FlashEvent.FOCUS_IN,textFieldFocusIn)
	moddingMenu.dialogueLibraryName.addEventListener(FlashEvent.FOCUS_OUT,textFieldFocusOut)
	moddingMenu.dialogueLibraryName.addEventListener(FlashEvent.CHANGE,dialogueLibraryNameChanged)
	charStoring.addEventListener("CHAR_STORED",characterStoredSuccessfully)
	charStoring.addEventListener("CHAR_DELETED",characterDeleted)
	charStoring.closeButton.addEventListener(FlashEvent.CLICK,charStoringCloseClicked)
	charStoring.visible = false
	optionsMenu.cbStrandShaders.addEventListener(FlashEvent.CLICK,cbStrandShadersClicked)
	optionsMenu.cbShowMouse.addEventListener(FlashEvent.CLICK,cbShowMouseClicked)
	optionsMenu.cbHoverOptions.addEventListener(FlashEvent.CLICK,cbHoverOptionsClicked)
	optionsMenu.cbLowQuality.addEventListener(FlashEvent.CLICK,cbLowQualityClicked)
	optionsMenu.cbMedQuality.addEventListener(FlashEvent.CLICK,cbMedQualityClicked)
	optionsMenu.cbHighQuality.addEventListener(FlashEvent.CLICK,cbHighQualityClicked)
	optionsMenu.cbMirrored.addEventListener(FlashEvent.CLICK,cbMirroredClicked)
	optionsMenu.volumeSlider.addEventListener("handleReleased",volumeChanged)
	optionsMenu.cbSpit.addEventListener(FlashEvent.CLICK,cbSpitClicked)
	optionsMenu.cbTears.addEventListener(FlashEvent.CLICK,cbTearsClicked)
	optionsMenu.cbMascara.addEventListener(FlashEvent.CLICK,cbMascaraClicked)
	optionsMenu.cbSmudging.addEventListener(FlashEvent.CLICK,cbSmudgingClicked)
	optionsMenu.cbNostrilSpray.addEventListener(FlashEvent.CLICK,cbNostrilSprayClicked)
	optionsMenu.cbSweat.addEventListener(FlashEvent.CLICK,cbSweatClicked)
	optionsMenu.cbDialogue.addEventListener(FlashEvent.CLICK,cbDialogueClicked)
	optionsMenu.throatBulgeSlider.setRangeEnd(100)
	optionsMenu.throatBulgeSlider.addEventListener("handleReleased",throatBulgeSliderReleased)
	optionsMenu.throatBulgeSlider.addEventListener("sliderChanged",throatBulgeSliderChanged)
	optionsMenu.mbDefaultThroatBulge.addEventListener(FlashEvent.CLICK,mbDefaultThroatBulgeClicked)
	optionsMenu.cbInvertControls.addEventListener(FlashEvent.CLICK,cbInvertControlsClicked)
	optionsMenu.cbDoubleSizeScreenshot.addEventListener(FlashEvent.CLICK,cbDoubleSizeScreenshotClicked)
	optionsMenu.cbIntroSound.addEventListener(FlashEvent.CLICK,cbIntroSoundClicked)
	optionsMenu.cbBreathing.addEventListener(FlashEvent.CLICK,cbBreathingClicked)
	optionsMenu.cbGagging.addEventListener(FlashEvent.CLICK,cbGaggingClicked)
	optionsMenu.cbCoughing.addEventListener(FlashEvent.CLICK,cbCoughingClicked)
	optionsMenu.cbTongue.addEventListener(FlashEvent.CLICK,cbTongueClicked)
	optionsMenu.mbClearSpit.addEventListener(FlashEvent.CLICK,clearSpitClicked)
	optionsMenu.mbClearCum.addEventListener(FlashEvent.CLICK,clearCumClicked)
	optionsMenu.mbClearMascara.addEventListener(FlashEvent.CLICK,clearMascaraClicked)
	optionsMenu.mbClearLipstick.addEventListener(FlashEvent.CLICK,clearLipstickClicked)
	optionsMenu.mbClearAll.addEventListener(FlashEvent.CLICK,clearAllClicked)
	optionsMenu.secretOptions.cbBukkakeMode.addEventListener(FlashEvent.CLICK,cbBukkakeModeClicked)
	costumeMenu.mbSelectCostume.labelContainer.buttonLabel.text = "Select..."
	optionsMenu.mbClearSpit.labelContainer.buttonLabel.text = "Spit"
	optionsMenu.mbClearCum.labelContainer.buttonLabel.text = "Cum"
	optionsMenu.mbClearMascara.labelContainer.buttonLabel.text = "Mascara"
	optionsMenu.mbClearAll.labelContainer.buttonLabel.text = "All"
	optionsMenu.mbClearLipstick.labelContainer.buttonLabel.text = "Lipstick"
	customMenu.mbShuffle.labelContainer.buttonLabel.text = "Shuffle"
	customMenu.mbClearTints.labelContainer.buttonLabel.text = "Clear All"
	moddingMenu.mbGenerate.labelContainer.buttonLabel.text = "Generate"
	moddingMenu.mbLoad.labelContainer.buttonLabel.text = "Load"
	moddingMenu.mbSaveDialogue.labelContainer.buttonLabel.text = "Save..."
	moddingMenu.mbLoadDialogue.labelContainer.buttonLabel.text = "Load..."
	moddingMenu.mbEditDialogue.labelContainer.buttonLabel.text = "Edit..."
	moddingMenu.mbImportHair.labelContainer.buttonLabel.text = "Hair..."
	moddingMenu.mbImportBackground.labelContainer.buttonLabel.text = "Background..."
	moddingMenu.mbImportMod.labelContainer.buttonLabel.text = "Swf mod..."
	moddingMenu.mbStoreChar.labelContainer.buttonLabel.text = "Save Character..."
	moddingMenu.mbSaveBackup.labelContainer.buttonLabel.text = "Save..."
	moddingMenu.mbLoadBackup.labelContainer.buttonLabel.text = "Load..."
	eyedropperCursor = Flash.create("EyedropperIcon")
	addChild(eyedropperCursor)
	eyedropperCursor.visible = false
	updateMoods()
	updateHisBodyList()
	updateArmsList()
	updateHisArmList()
	updateHisLeftArmList()
	updateBallsList()
	updateResistanceSlider()
	setCBResetResistance()
	updateThroatResistanceSlider()
	setCBAuto()
	updateAutoList()
	updateZoomSlider()
	updatePenisLengthSlider()
	updatePenisWidthSlider()
	updateBallSizeSlider()
	updateHairList()
	irisTypes = g.characterControl.getIrisList()
	updateIrisList()
	skinTypes = g.characterControl.getSkinList()
	updateSkinList()
	updateNoseList()
	updateEyebrowsList()
	updateEarList()
	updateBreastSlider()
	updateBodySlider()
	updateMascaraSlider()
	updateFrecklesSlider()
	updateLipstickSmearing()
	updateCBSpit()
	updateCBSweat()
	updateCBTears()
	updateCBMascara()
	updateCBSmudging()
	updateCBNostrilSpray()
	updateCBIntroSound()
	updateCBBreathing()
	updateCBGagging()
	updateCBCoughing()
	updateCBTongue()
	updateThroatBulgeSlider()
	updateCBDialogue()
	updateCBDoubleSizeScreenshot()
	updateTabs()
	setcbStrandShaders()
	setcbShowMouse()
	setQualityCBs()
	setcbHoverOptions()
	setcbMirrored()
	setBGCheckboxes()
	setStyleCheckboxes()
	setDialogueLibraryName("Default")
	updateOverwriteCharList()


func updateHimMenuContent():
	himMenuScroller.updateContent()


func updateCostumeMenuContent():
	costumeMenuScroller.updateContent()


var onlyLoadingCostume: bool:
	get: return onlyLoadCostume
	set(value): onlyLoadCostume = value


func showError(param1):
	pass

func textFieldFocusIn(param1 = null):
	g.inTextField = true


func textFieldFocusOut(param1 = null):
	g.inTextField = false


func getSwatchHandler(param1):
	var swatchID = param1
	var swatchFunc = func(_e = null):
		setRGBPicker(currentSwatch[swatchID])
		g.saveData.saveCharData()
	return swatchFunc


func getBGHandler(param1):
	var bgID = param1
	var bgCBFunc = func(_e = null):
		g.characterControl.setBackground(bgID)
		g.saveData.saveCharData()
		setBGCheckboxes()
	return bgCBFunc


func setBGCheckboxes():
	var _loc1_ = 1
	while _loc1_ <= g.bgNum:
		if _loc1_ == g.bgID:
			sceneMenu["cbBG" + str(_loc1_)].setOn()
		else:
			sceneMenu["cbBG" + str(_loc1_)].setOff()
		_loc1_ += 1
	updateBGPicker()


## Port extension: the four BG checkboxes are replaced by a picker like the costume ones: the built-in
## backgrounds, then the background mods and images in Mods/Backgrounds (see ModCatalog). bgModIndex is the one
## applied through the picker (-1: a built-in background).
const BG_NAMES := ["Lab", "Dungeon", "Classroom", "White"]
var bgPicker: FlashMovieClip = null
var bgModIndex := -1


func _setupBGPicker():
	var first = sceneMenu.cbBG1
	for i in range(1, g.bgNum + 1):
		sceneMenu["cbBG" + str(i)].visible = false
	bgPicker = Flash.create_char(costumeMenu.mlCollar._library, costumeMenu.mlCollar._char_id)
	sceneMenu.addChild(bgPicker)
	bgPicker.itemLabel.autoSize = "center"
	var b: Rect2 = bgPicker.getBounds(bgPicker)
	var cb: Rect2 = first.getBounds(sceneMenu)
	bgPicker.x = cb.position.x - b.position.x - 2
	bgPicker.y = cb.get_center().y - b.get_center().y
	bgPicker.leftArrow.addEventListener(FlashEvent.CLICK, func(_e = null): _stepBG(-1))
	bgPicker.rightArrow.addEventListener(FlashEvent.CLICK, func(_e = null): _stepBG(1))
	updateBGPicker()


## Port extension: the custom dialogue name in the Modding tab becomes a picker: Default, then the dialogue files
## (.txt) in Mods/Dialogue, re-read on every step. Choosing one loads it like "Load..."; Default resets like the
## reset button. The label shows the current dialogue's name (also after Load... or the editor).
var dialoguePicker: FlashMovieClip = null
var dialogueFileIndex := -1


func _setupDialoguePicker():
	var field = moddingMenu.dialogueLibraryName
	dialoguePicker = Flash.create_char(costumeMenu.mlCollar._library, costumeMenu.mlCollar._char_id)
	moddingMenu.addChild(dialoguePicker)
	dialoguePicker.itemLabel.autoSize = "center"
	var b: Rect2 = dialoguePicker.getBounds(dialoguePicker)
	var fb: Rect2 = field.getBounds(moddingMenu)
	dialoguePicker.x = fb.get_center().x - b.get_center().x
	dialoguePicker.y = fb.get_center().y - b.get_center().y
	field.visible = false
	dialoguePicker.leftArrow.addEventListener(FlashEvent.CLICK, func(_e = null): _stepDialogue(-1))
	dialoguePicker.rightArrow.addEventListener(FlashEvent.CLICK, func(_e = null): _stepDialogue(1))
	CharacterElementHelper.setPickerLabel(dialoguePicker, str(field.text))


static func _dialogueFiles(dir: String = "") -> Array:
	if dir == "":
		dir = Flash.mods_dir("Dialogue")
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.get_extension().to_lower() == "txt":
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_dialogueFiles(dir.path_join(sub)))
	out.sort()
	return out


func _stepDialogue(d: int):
	var files := _dialogueFiles()
	var cur: int = dialogueFileIndex + 1 if dialogueFileIndex >= 0 and dialogueFileIndex < files.size() else 0
	var i: int = max(0, min(files.size(), cur + d))
	if i == cur:
		return
	if i == 0:
		dialogueFileIndex = -1
		g.dialogueControl.resetCustomDialogue()
	else:
		dialogueFileIndex = i - 1
		g.dialogueControl.loadCustomDialogue(Flash.bytes_to_string(FileAccess.get_file_as_bytes(files[i - 1])))
		if moddingMenu.dialogueLibraryName.text == "No name":
			# dialogue without a dialogue_name line: show which file it is
			CharacterElementHelper.setPickerLabel(dialoguePicker, files[i - 1].get_file().get_basename())


func updateBGPicker():
	if bgPicker == null:
		return
	var mods: Array = g.modCatalog.bg_entries if g.modCatalog else []
	if bgModIndex >= 0 and bgModIndex < mods.size():
		CharacterElementHelper.setPickerLabel(bgPicker, mods[bgModIndex]["title"])
	else:
		bgModIndex = -1
		CharacterElementHelper.setPickerLabel(bgPicker, BG_NAMES[clampi(g.bgID - 1, 0, BG_NAMES.size() - 1)])


func _stepBG(d: int):
	var n: int = BG_NAMES.size()
	var mods: Array = g.modCatalog.bg_entries if g.modCatalog else []
	var cur: int = n + bgModIndex if bgModIndex >= 0 else g.bgID - 1
	var i: int = max(0, min(n + mods.size() - 1, cur + d))
	if i == cur and i >= n:
		return
	g.customElementLoader.clearCustomBackground()
	if i < n:
		bgModIndex = -1
		g.characterControl.setBackground(i + 1)
	else:
		bgModIndex = i - n
		var e: Dictionary = mods[bgModIndex]
		if e.get("image", false):
			g.customElementLoader.tryToLoadBGFile(Flash.resolve_content_path(e["path"]))
		else:
			g.modCatalog.apply(e)
	setBGCheckboxes()
	g.saveData.saveCharData()


func setStyleCheckboxes():
	var _loc1_ = 1
	while _loc1_ < 3:
		if _loc1_ == g.animationControl.currentAnimationID:
			sceneMenu["cbStyle" + str(_loc1_)].setOn()
		else:
			sceneMenu["cbStyle" + str(_loc1_)].setOff()
		_loc1_ += 1


func mouseReleased(param1 = null):
	if eyedropperOn:
		eyedropperDone()


func mouseMoved(param1, param2):
	var _loc3_ = null
	if eyedropperOn:
		eyedropperCursor.x = mouseX
		eyedropperCursor.y = mouseY
		_loc3_ = ARGBObject.new()
		_loc3_.setARGB(g.getEyedropperPoint(param1,param2))
		_loc3_.a = rgbPicker.alphaControls.aSlider.currentValue() / 255
		setRGBPicker(_loc3_)


func tick(param1 = null):
	if slidingIn:
		y += (slideIn - y) / slideSmooth
		if abs(y - slideIn) < 0.1:
			y = slideIn
			slidingIn = false
			if not g.hoverOptions:
				mouseEnabled = false
		menuDrawerLip.y = -230 + slideOut - y
	elif slidingOut:
		y += (slideOut - y) / slideSmooth
		if abs(y - slideOut) < 0.1:
			finishSlideout()
		menuDrawerLip.y = -230 + slideOut - y
	if g.hoverOptions and g.gameRunning and not g.gamePaused and not menuOpen and menuOver and not g.penisOut:
		overTimer += 1
		if overTimer >= openDelay:
			openMenu()
	if g.hoverOptions and menuOpen and not menuOver and not charStoringOpen and not g.customElementLoader.browsing and not savingStoredCharsBackup and not browsingForStoredCharsBackup and not savingDialogue and not browsingForDialogue:
		offTimer += 1
		if offTimer >= closeDelay:
			closeMenu()
	if clipboardSwatch.visible == true:
		clipboardSwatch.x = mouseX + 10
		clipboardSwatch.y = mouseY - 10
		clipboardSwatch.alpha = max(0,clipboardSwatch.alpha - 0.02)
		if clipboardSwatch.alpha == 0:
			clipboardSwatch.visible = false


func finishSlideout():
	y = slideOut
	slidingOut = false
	menuOpen = false
	offTimer = 0
	if rgbPickerOpen:
		closeRGBPicker()
	if hslPickerOpen:
		closeHSLPicker()
	if charMenuOpen:
		closeCharacterMenu()
	if charStoringOpen:
		closeCharStoring()
	menuDrawerLip.y = -230 + slideOut - y


func rolledOver(param1 = null):
	if not g.controlLocked:
		menuOver = true
		offTimer = 0
		overTimer = 0
		if menuOpen:
			openMenu()
		elif g.hoverOptions and g.gameRunning and not g.penisOut:
			menuDrawerLip.arrow.gotoAndPlay("FadeIn")
			drawerArrowShowing = true


func rolledOut(param1 = null):
	menuOver = false
	overTimer = 0
	offTimer = 0
	if drawerArrowShowing:
		menuDrawerLip.arrow.gotoAndPlay("FadeOut")
		drawerArrowShowing = false


func drawerArrowClicked(param1 = null):
	if g.hoverOptions and g.gameRunning:
		openMenu()


func menuClicked(param1 = null):
	if rgbPickerOpen and not rgbPickerJustOpened and not rgbPicker.contains(param1.target):
		closeRGBPicker()
	if hslPickerOpen and not hslPickerJustOpened and not hslPicker.contains(param1.target):
		closeHSLPicker()
	if charMenuOpen and not charMenuJustOpened and not characterMenu.contains(param1.target):
		closeCharacterMenu()
	if charStoringOpen and not charStoringJustOpened and not charStoring.contains(param1.target) and not charStoring.deletingFolderLine:
		closeCharStoring()
	charMenuJustOpened = false
	charStoringJustOpened = false
	rgbPickerJustOpened = false
	hslPickerJustOpened = false


func toggleMenu(param1 = false, param2 = 1):
	if SDTMenu.active():   # port addition: the new menu (SDTMenu) replaces this one unless Classic / Vanilla
		SDTMenu.instance.toggle_tab(param2)
		return
	if param2 == currentTab:
		if (menuOpen or slidingIn) and not slidingOut:
			closeMenu()
		else:
			openMenu(param1)
	elif (menuOpen or slidingIn) and not slidingOut:
		currentTab = param2
		updateTabs()
	else:
		currentTab = param2
		updateTabs()
		openMenu(param1)


func openMenu(param1 = false):
	if SDTMenu.active():   # port addition: see toggleMenu
		SDTMenu.instance.open_menu()
		return
	g.gamePaused = true
	slidingIn = true
	slidingOut = false
	menuOpen = true
	mouseEnabled = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if param1:
		offTimer = -15
	if drawerArrowShowing:
		menuDrawerLip.arrow.gotoAndPlay("FadeOut")
		drawerArrowShowing = false


func closeMenu():
	if menuOpen:
		g.gamePaused = false
		g.inTextField = false
		slidingOut = true
		slidingIn = false
		clipboardSwatch.visible = false
		if g.showMouse:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif g.gameRunning:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if Hooks.has(&"InGameMenu.closeMenu"):   # HOOK
		Hooks.after(&"InGameMenu.closeMenu", self)


func closeClicked(param1 = null):
	closeMenu()


func tab1Clicked(param1 = null):
	currentTab = 1
	updateTabs()


func tab2Clicked(param1 = null):
	currentTab = 2
	updateTabs()


func tab3Clicked(param1 = null):
	currentTab = 3
	updateTabs()


func tab4Clicked(param1 = null):
	currentTab = 4
	updateTabs()


func tab5Clicked(param1 = null):
	currentTab = 5
	updateTabs()


func updateTabs():
	tab1.setOff()
	tab2.setOff()
	tab3.setOff()
	tab4.setOff()
	tab5.setOff()
	sceneMenu.visible = false
	customMenu.visible = false
	moddingMenu.visible = false
	optionsMenu.visible = false
	helpMenu.visible = false
	if currentTab == 1:
		tab1.setOn()
		sceneMenu.visible = true
	elif currentTab == 2:
		tab2.setOn()
		customMenu.visible = true
	elif currentTab == 3:
		tab3.setOn()
		moddingMenu.visible = true
	elif currentTab == 4:
		tab4.setOn()
		optionsMenu.visible = true
	elif currentTab == 5:
		tab5.setOn()
		helpMenu.visible = true
	if rgbPickerOpen:
		closeRGBPicker()
	if hslPickerOpen:
		closeHSLPicker()
	if charMenuOpen:
		closeCharacterMenu()
	if charStoringOpen:
		closeCharStoring()
	if Hooks.has(&"InGameMenu.updateTabs"):   # HOOK
		Hooks.after(&"InGameMenu.updateTabs", self)


func characterMenuCloseClicked(param1 = null):
	closeCharacterMenu()


func mbCharacterMenuClicked(param1 = null):
	openCharacterMenu()


func selectCostumeClicked(param1 = null):
	onlyLoadCostume = true
	openCharacterMenu()


func closeCharacterMenu():
	characterMenu.visible = false
	charMenuOpen = false
	onlyLoadCostume = false


func openCharacterMenu():
	characterMenu.visible = true
	charMenuJustOpened = true
	charMenuOpen = true


func updateCharMenu(param1, param2 = false, param3 = false):
	characterMenu.select(param1,param2,param3)


func moodNormalClicked(param1 = null):
	g.her.setMood(Her.NORMAL_MOOD)
	updateMoods()
	g.saveData.saveCharData()


func moodHappyClicked(param1 = null):
	g.her.setMood(Her.HAPPY_MOOD)
	updateMoods()
	g.saveData.saveCharData()


func moodAngryClicked(param1 = null):
	g.her.setMood(Her.ANGRY_MOOD)
	updateMoods()
	g.saveData.saveCharData()


func moodAhegaoClicked(param1 = null):
	g.her.setMood(Her.AHEGAO_MOOD)
	updateMoods()
	g.saveData.saveCharData()


func updateMoods():
	sceneMenu.cbMoodNormal.setOff()
	sceneMenu.cbMoodHappy.setOff()
	sceneMenu.cbMoodAngry.setOff()
	sceneMenu.cbMoodAhegao.setOff()
	if g.her.mood == Her.NORMAL_MOOD:
		sceneMenu.cbMoodNormal.setOn()
	elif g.her.mood == Her.HAPPY_MOOD:
		sceneMenu.cbMoodHappy.setOn()
	elif g.her.mood == Her.ANGRY_MOOD:
		sceneMenu.cbMoodAngry.setOn()
	elif g.her.mood == Her.AHEGAO_MOOD:
		sceneMenu.cbMoodAhegao.setOn()


func style1Clicked(param1 = null):
	g.animationControl.setAnimation(AnimationControl.DEFAULT)
	g.saveData.saveCharOptionsData()
	setStyleCheckboxes()


func style2Clicked(param1 = null):
	g.animationControl.setAnimation(AnimationControl.FACE_FUCK)
	g.saveData.saveCharOptionsData()
	setStyleCheckboxes()


func leftArmLeftClicked(param1 = null):
	var _loc2_ = Her.stepArmPosition(g.her.currentLeftArmPosition, -1, true)
	g.her.setLeftArmPosition(_loc2_)
	updateArmsList()
	g.saveData.saveCharData()


func leftArmRightClicked(param1 = null):
	var _loc2_ = Her.stepArmPosition(g.her.currentLeftArmPosition, +1, true)
	g.her.setLeftArmPosition(_loc2_)
	updateArmsList()
	g.saveData.saveCharData()


func rightArmLeftClicked(param1 = null):
	var _loc2_ = Her.stepArmPosition(g.her.currentRightArmPosition, -1, false)
	g.her.setRightArmPosition(_loc2_)
	updateArmsList()
	g.saveData.saveCharData()


func rightArmRightClicked(param1 = null):
	var _loc2_ = Her.stepArmPosition(g.her.currentRightArmPosition, +1, false)
	g.her.setRightArmPosition(_loc2_)
	updateArmsList()
	g.saveData.saveCharData()


func updateArmsList():
	costumeMenu.mlLeftArm.itemLabel.text = Her.armPositions[g.her.currentLeftArmPosition]
	costumeMenu.mlRightArm.itemLabel.text = Her.armPositions[g.her.currentRightArmPosition]


func hisBodyLeftClicked(param1 = null):
	var _loc2_ = max(0,min(g.him.bodyNameList.size() - 1,g.him.currentBodyID - 1))
	g.him.setBody(_loc2_)
	g.saveData.saveCharData()


func hisBodyRightClicked(param1 = null):
	var _loc2_ = max(0,min(g.him.bodyNameList.size() - 1,g.him.currentBodyID + 1))
	g.him.setBody(_loc2_)
	g.saveData.saveCharData()


func updateHisBodyList():
	himMenu.mlBody.itemLabel.text = g.him.bodyNameList[g.him.currentBodyID]


func hisArmLeftClicked(param1 = null):
	var _loc2_ = max(0,min(Him.armPositions.size() - 1,g.him.currentArmPosition - 1))
	g.him.setArmPosition(_loc2_,true)
	g.saveData.saveOptionsData()


func hisArmRightClicked(param1 = null):
	var _loc2_ = max(0,min(Him.armPositions.size() - 1,g.him.currentArmPosition + 1))
	g.him.setArmPosition(_loc2_,true)
	g.saveData.saveOptionsData()


func updateHisArmList():
	himMenu.mlHisArm.itemLabel.text = Him.armPositions[g.him.currentArmPosition]


func hisLeftArmLeftClicked(param1 = null):
	var _loc2_ = max(0,min(Him.leftArmPositions.size() - 1,g.him.currentLeftArmPosition - 1))
	g.him.setLeftArmPosition(_loc2_)
	g.saveData.saveOptionsData()


func hisLeftArmRightClicked(param1 = null):
	var _loc2_ = max(0,min(Him.leftArmPositions.size() - 1,g.him.currentLeftArmPosition + 1))
	g.him.setLeftArmPosition(_loc2_)
	g.saveData.saveOptionsData()


func updateHisLeftArmList():
	himMenu.mlHisLeftArm.itemLabel.text = Him.leftArmPositions[g.him.currentLeftArmPosition]


func ballsLeftClicked(param1 = null):
	var _loc2_ = max(0,min(g.him.ballsNameArray.size() - 1,g.him.currentBalls - 1))
	g.him.setBalls(_loc2_)
	g.saveData.saveCharData()


func ballsRightClicked(param1 = null):
	var _loc2_ = max(0,min(g.him.ballsNameArray.size() - 1,g.him.currentBalls + 1))
	g.him.setBalls(_loc2_)
	g.saveData.saveCharData()


func updateBallsList():
	himMenu.mlBalls.itemLabel.text = g.him.ballsNameArray[g.him.currentBalls]


func ballSizeSliderReleased(param1 = null):
	g.saveData.saveCharData()


func ballSizeSliderChanged(param1 = null):
	g.him.setBallSize(himMenu.ballSizeSlider.currentValue(100) * 0.01)


func updateBallSizeSlider():
	himMenu.ballSizeSlider.setPos(g.him.ballSizeSlider)


func mbDefaultBallSizeClicked(param1 = null):
	g.him.setBallScale(Him.DEFAULT_BALL_SIZE)
	updateBallSizeSlider()
	g.saveData.saveCharData()


func resistanceSliderReleased(param1 = null):
	g.her.startIntro()
	g.him.resetSpit()
	g.saveData.saveOptionsData()


func resistanceSliderChanged(param1 = null):
	g.her.setIntroResistance(costumeMenu.resistanceSlider.currentValue(100))


func updateResistanceSlider(param1 = false):
	costumeMenu.resistanceSlider.setPos(g.introResistance / 100)
	if param1:
		g.her.setIntroResistance(costumeMenu.resistanceSlider.currentValue(100))


func cbResetResistanceClicked(param1 = null):
	g.resetIntroOnNewChar = not g.resetIntroOnNewChar
	setCBResetResistance()
	g.saveData.saveOptionsData()


func setCBResetResistance():
	if g.resetIntroOnNewChar:
		costumeMenu.cbResetResistance.setOn()
	else:
		costumeMenu.cbResetResistance.setOff()


func mbDefaultResistanceClicked(param1 = null):
	g.her.setIntroResistance(g.defaultResistance)
	updateResistanceSlider()
	g.her.startIntro()
	g.him.resetSpit()
	g.saveData.saveOptionsData()


func throatResistanceSliderReleased(param1 = null):
	g.saveData.saveCharData()


func throatResistanceSliderChanged(param1 = null):
	g.her.setThroatResistance(costumeMenu.throatResistanceSlider.currentValue(100))


func updateThroatResistanceSlider():
	costumeMenu.throatResistanceSlider.setPos(g.throatResistance / 100)


func mbDefaultThroatResistanceClicked(param1 = null):
	g.her.setThroatResistance(g.defaultThroatResistance)
	updateThroatResistanceSlider()
	g.saveData.saveCharData()


func zoomSliderReleased(param1 = null):
	g.saveData.saveOptionsData()


func zoomSliderChanged(param1 = null):
	g.sceneLayer.zoomTo(sceneMenu.zoomSlider.currentValue(100) * 0.01)


func updateZoomSlider():
	sceneMenu.zoomSlider.setPos(g.sceneZoom)


func mbDefaultZoomClicked(param1 = null):
	g.sceneLayer.zoomTo(g.defaultZoom)
	updateZoomSlider()
	g.saveData.saveOptionsData()


func penisLengthSliderReleased(param1 = null):
	g.saveData.saveCharData()


func penisLengthSliderChanged(param1 = null):
	g.him.setPenisLength(himMenu.penisLengthSlider.currentValue(100) * 0.01)
	updatePenisLengthSlider()
	updatePenisWidthSlider()


func updatePenisLengthSlider():
	himMenu.penisLengthSlider.setPos(g.him.penisLengthSlider)


func mbDefaultPenisLengthClicked(param1 = null):
	g.him.loadPenisScales(Him.DEFAULT_PENIS_SIZE,g.him.penisWidthScale)
	g.saveData.saveCharData()


func penisWidthSliderReleased(param1 = null):
	g.saveData.saveCharData()


func penisWidthSliderChanged(param1 = null):
	g.him.setPenisWidth(himMenu.penisWidthSlider.currentValue(100) * 0.01)


func updatePenisWidthSlider():
	himMenu.penisWidthSlider.setPos(g.him.penisWidthSlider)


func mbDefaultPenisWidthClicked(param1 = null):
	g.him.loadPenisScales(g.him.penisLengthScale,g.him.penisLengthScale)
	updatePenisWidthSlider()
	g.saveData.saveCharData()


func autoLeftClicked(param1 = null):
	var _loc2_ = max(0,min(AutomaticControl.autoModeNameList.size() - 1,g.autoMode - 1))
	g.setAuto(_loc2_)
	updateAutoList()
	g.saveData.saveOptionsData()


func autoRightClicked(param1 = null):
	var _loc2_ = max(0,min(AutomaticControl.autoModeNameList.size() - 1,g.autoMode + 1))
	g.setAuto(_loc2_)
	updateAutoList()
	g.saveData.saveOptionsData()


func updateAutoList():
	sceneMenu.mlAuto.itemLabel.text = AutomaticControl.autoModeNameList[g.autoMode]


func cbAutoClicked(param1 = null):
	g.toggleAutoMode()
	setCBAuto()


func setCBAuto():
	if g.autoModeOn:
		sceneMenu.cbAuto.setOn()
	else:
		sceneMenu.cbAuto.setOff()


func hairLeftClicked(param1 = null):
	_stepHair(-1)


func hairRightClicked(param1 = null):
	_stepHair(1)


## Port extension: after the built-in hairstyles the hair picker offers hair mods from the Mods folders
## (see ModCatalog); hairModIndex is the one applied through the picker (-1: a built-in hairstyle).
var hairModIndex := -1


func _stepHair(d: int) -> void:
	var n: int = charNames.size()
	var mods: Array = g.modCatalog.hair_entries if g.modCatalog else []
	var cur: int = n + hairModIndex if hairModIndex >= 0 else g.characterControl.currentHair
	var i: int = max(0, min(n + mods.size() - 1, cur + d))
	if i == cur and i >= n:
		return
	if i < n:
		hairModIndex = -1
		g.characterControl.setHair(i)
		updateHairList()
	else:
		_wearHairMod(mods[i - n])
	g.saveData.saveCharData()


## Port: puts on a hair mod from the catalog as the hair picker's choice (an image hair: as importing it does).
func _wearHairMod(e: Dictionary) -> void:
	if e.get("image", false):
		g.customElementLoader.clearModTypes([ModTypes.HAIR, ModTypes.DYNAMIC_HAIR])
		g.customElementLoader.tryToLoadHairFile(e["path"])
		hairModIndex = g.modCatalog.hair_entries.find(e)
		customMenu.mlHair.itemLabel.text = e["title"]
		return
	if g.characterControl.customHairLoaded:
		# imported image hair would stay on screen under the mod hair
		g.customElementLoader.clearCustomHair(false)
		g.characterControl.customHairLoaded = false
	if hairModIndex < 0:
		g.characterControl.clearHair()
	g.customElementLoader.clearModTypes([ModTypes.HAIR, ModTypes.DYNAMIC_HAIR])
	g.modCatalog.apply(e)
	hairModIndex = g.modCatalog.hair_entries.find(e)
	customMenu.mlHair.itemLabel.text = e["title"]


func irisLeftClicked(param1 = null):
	var _loc2_ = max(0,min(irisTypes.size() - 1,g.characterControl.currentIris - 1))
	g.characterControl.setIris(_loc2_)
	updateIrisList()
	g.saveData.saveCharData()


func irisRightClicked(param1 = null):
	var _loc2_ = max(0,min(irisTypes.size() - 1,g.characterControl.currentIris + 1))
	g.characterControl.setIris(_loc2_)
	updateIrisList()
	g.saveData.saveCharData()


func skinLeftClicked(param1 = null):
	var _loc2_ = max(0,min(skinTypes.size() - 1,g.characterControl.currentSkin - 1))
	g.characterControl.setSkin(_loc2_)
	updateSkinList()
	g.saveData.saveCharData()


func skinRightClicked(param1 = null):
	var _loc2_ = max(0,min(skinTypes.size() - 1,g.characterControl.currentSkin + 1))
	g.characterControl.setSkin(_loc2_)
	updateSkinList()
	g.saveData.saveCharData()


func noseLeftClicked(param1 = null):
	var _loc2_ = max(0,min(CharacterControl.noseTypeList.size() - 1,g.characterControl.currentNose - 1))
	g.characterControl.setNose(_loc2_)
	updateNoseList()
	g.saveData.saveCharData()


func noseRightClicked(param1 = null):
	var _loc2_ = max(0,min(CharacterControl.noseTypeList.size() - 1,g.characterControl.currentNose + 1))
	g.characterControl.setNose(_loc2_)
	updateNoseList()
	g.saveData.saveCharData()


func eyebrowsLeftClicked(param1 = null):
	var _loc2_ = max(0,min(CharacterControl.eyebrowsTypeList.size() - 1,g.characterControl.currentEyebrows - 1))
	g.characterControl.setEyebrows(_loc2_)
	updateEyebrowsList()
	g.saveData.saveCharData()


func eyebrowsRightClicked(param1 = null):
	var _loc2_ = max(0,min(CharacterControl.eyebrowsTypeList.size() - 1,g.characterControl.currentEyebrows + 1))
	g.characterControl.setEyebrows(_loc2_)
	updateEyebrowsList()
	g.saveData.saveCharData()


func earLeftClicked(param1 = null):
	var _loc2_ = max(0,min(CharacterControl.earTypeList.size() - 1,g.characterControl.currentEar - 1))
	g.characterControl.setEar(_loc2_)
	updateEarList()
	g.saveData.saveCharData()


func earRightClicked(param1 = null):
	var _loc2_ = max(0,min(CharacterControl.earTypeList.size() - 1,g.characterControl.currentEar + 1))
	g.characterControl.setEar(_loc2_)
	updateEarList()
	g.saveData.saveCharData()


func updateHairList():
	customMenu.mlHair.itemLabel.text = charNames[g.characterControl.currentHair]


func updateIrisList():
	customMenu.mlIris.itemLabel.text = irisTypes[g.characterControl.currentIris]


func updateSkinList():
	customMenu.mlSkin.itemLabel.text = skinTypes[g.characterControl.currentSkin]


func updateNoseList():
	customMenu.mlNose.itemLabel.text = CharacterControl.noseTypeList[g.characterControl.currentNose]


func updateEyebrowsList():
	customMenu.mlEyebrows.itemLabel.text = CharacterControl.eyebrowsTypeList[g.characterControl.currentEyebrows]


func updateEarList():
	customMenu.mlEar.itemLabel.text = CharacterControl.earTypeList[g.characterControl.currentEar]


func bodySliderReleased(param1 = null):
	g.saveData.saveCharData()


func bodySliderChanged(param1 = null):
	g.her.setBodyScaleFromSlider(customMenu.bodySlider.currentValue(100) / 100)


func updateBodySlider():
	customMenu.bodySlider.setPos(g.her.bodySize)


func mbDefaultBodyScaleClicked(param1 = null):
	g.her.setDefaultBodyScale()
	updateBodySlider()
	g.saveData.saveCharData()


func breastSliderReleased(param1 = null):
	g.strandControl.checkElementAnchors(g.her.torso.midLayer.rightBreast)
	g.saveData.saveCharData()


func breastSliderChanged(param1 = null):
	g.characterControl.setBreasts(customMenu.breastSlider.currentValue(149))


## Port (the new menu's reset): her own size, the stored size of a custom character or the built-in character's.
func defaultBreastSizeClicked(param1 = null):
	var cc = g.characterControl
	var size: int = cc.characters[cc.currentChar].breastSize if cc.currentChar < g.baseCharNum else cc.breastSize
	if cc.currentChar >= g.baseCharNum:
		for pair in str(g.storedChars[cc.currentChar - g.baseCharNum].charData).split(";"):
			if pair.begins_with("breasts:"):
				size = clampi(int(pair.substr(8).to_float()), 1, 149)
	cc.setBreasts(size)
	updateBreastSlider()
	breastSliderReleased()


func updateBreastSlider():
	customMenu.breastSlider.setPos(g.characterControl.breastSize / 149)


func mascaraSliderReleased(param1 = null):
	g.saveData.saveCharData()


func mascaraSliderChanged(param1 = null):
	g.mascaraAmount = customMenu.mascaraSlider.currentValue(100)


func defaultMascaraClicked(param1 = null):
	g.mascaraAmount = 20
	updateMascaraSlider()
	g.saveData.saveCharData()


func updateMascaraSlider():
	customMenu.mascaraSlider.setPos(g.mascaraAmount / 100)


func frecklesSliderReleased(param1 = null):
	g.saveData.saveCharData()


func frecklesSliderChanged(param1 = null):
	g.characterControl.setFreckleAmount(customMenu.frecklesSlider.currentValue(100))


func defaultFrecklesClicked(param1 = null):
	g.frecklesAmount = 0
	g.characterControl.setFreckles({ "r":60, "g":24, "b":24, "a":0.8 })
	g.characterControl.setFreckleAmount(0)
	updateFrecklesSlider()
	g.saveData.saveCharData()


func updateFrecklesSlider():
	customMenu.frecklesSlider.setPos(g.frecklesAmount / 100)


func lipstickSmearingClicked(param1 = null):
	g.smearLipstick = not g.smearLipstick
	updateLipstickSmearing()
	g.saveData.saveCharData()


func updateLipstickSmearing():
	if g.smearLipstick:
		customMenu.cbLipstickSmearing.setOn()
	else:
		customMenu.cbLipstickSmearing.setOff()


func dialogueNameChanged(param1 = null):
	g.customName = customMenu.dialogueNameTF.text
	g.saveData.saveCharOptionsData()


func mbClearDialogueNameClicked(param1 = null):
	customMenu.dialogueNameTF.text = ""
	g.customName = ""
	g.saveData.saveCharOptionsData()


func shuffleClicked(param1 = null):
	shuffle()


## Port: what shuffle() changes (all of it in the game) and which clothes also get random transparency; a
## before-hook can change both (args [parts, alpha]), e.g. regulaterandom. "herPenis" is not in the game's shuffle.
const SHUFFLE_PARTS := {"hair": true, "breasts": true, "bg": true, "him": true, "iris": true, "skin": true,
	"bodyScale": true, "lipstick": true, "eyeshadow": true, "nailpolish": true, "arms": true, "mood": true,
	"collar": true, "gag": true, "cuffs": true, "ankleCuffs": true, "eyewear": true, "panties": true, "armwear": true,
	"legwear": true, "legwearB": true, "bottoms": true, "footwear": true, "tops": true, "bra": true,
	"tonguePiercing": true, "nipplePiercing": true, "bellyPiercing": true, "earring": true, "headwear": true,
	"herPenis": false}
const SHUFFLE_ALPHA := {"legwear": true, "legwearB": true, "tops": true}


func shuffle():
	var parts: Dictionary = SHUFFLE_PARTS
	var alpha: Dictionary = SHUFFLE_ALPHA
	if Hooks.has(&"InGameMenu.shuffle"):   # HOOK
		var h := Hooks.before(&"InGameMenu.shuffle", self, [SHUFFLE_PARTS.duplicate(), SHUFFLE_ALPHA.duplicate()])
		if h.cancelled:
			return
		parts = h.args[0]
		alpha = h.args[1]
	var _loc1_ = []
	var _loc2_ = int(floor(randf() * 4)) + 1
	var _loc3_ = 0
	while _loc3_ < _loc2_:
		_loc1_.append(PaletteUtils.getHue(randf() * 360, PaletteUtils.midRandom(), PaletteUtils.midRandom() if randf() > 0.6 else 0.0))
		_loc3_ += 1
	var _loc4_ = []
	_loc3_ = 0
	while _loc3_ < 2:
		_loc4_.append(PaletteUtils.getHue(randf() * 190 + 170, randf(), randf() * 0.5 if randf() > 0.4 else randf()))
		_loc3_ += 1
	if parts.get("hair", false):
		var _loc5_ = int(floor(randf() * charNames.size()))
		g.characterControl.setHair(_loc5_)
		g.characterControl.randomCurrentElements()
		updateHairList()
	if parts.get("breasts", false):
		var _loc6_ = int(floor(randf() * 150))
		g.characterControl.setBreasts(_loc6_)
		updateBreastSlider()
	if parts.get("bg", false):
		var _loc7_ = int(ceil(randf() * g.bgNum))
		g.bg.gotoAndStop(_loc7_)
		g.bgID = _loc7_
		setBGCheckboxes()
	if parts.get("him", false):
		g.him.shuffle()
	if parts.get("iris", false):
		var _loc8_ = int(floor(randf() * irisTypes.size()))
		g.characterControl.setIris(_loc8_)
		updateIrisList()
		g.characterControl.setIrisFill(PaletteUtils.getHue(randf(),randf() * 0.8,PaletteUtils.midRandom() * 0.5))
	if parts.get("skin", false):
		var _loc9_ = int(floor(randf() * skinTypes.size()))
		g.characterControl.setSkin(_loc9_)
		updateSkinList()
	if parts.get("bodyScale", false):
		g.her.setBodyScaleFromSlider(randf())
		customMenu.bodySlider.setPos(g.her.bodySize)
	if parts.get("lipstick", false):
		g.characterControl.setLipstick(PaletteUtils.randomSwatch(_loc4_))
	if parts.get("eyeshadow", false):
		g.characterControl.setEyeShadow(PaletteUtils.randomSwatch(_loc4_))
	if parts.get("nailpolish", false):
		g.characterControl.setNailPolish(PaletteUtils.randomSwatch(_loc4_))
	if parts.get("arms", false):
		g.her.setRandomArmPosition()
		updateArmsList()
	if parts.get("mood", false):
		var _loc10_ = [Her.NORMAL_MOOD,Her.HAPPY_MOOD,Her.ANGRY_MOOD,Her.AHEGAO_MOOD]
		var _loc11_ = str(_loc10_[int(floor(randf() * _loc10_.size()))])
		g.her.setMood(_loc11_)
		updateMoods()
	var cc = g.characterControl
	# [part, element, chance of none (-1: the element's own)], in the game's order
	for c in [["collar", cc.collarControl, 0.4], ["gag", cc.gagControl, 0.8], ["cuffs", cc.cuffsControl, 0.4],
			["ankleCuffs", cc.ankleCuffsControl, 0.4], ["eyewear", cc.eyewearControl, 0.7],
			["panties", cc.pantiesControl, 0.4], ["armwear", cc.armwearControl, 0.5], ["legwear", cc.legwearControl, -1.0],
			["legwearB", cc.legwearBControl, 0.5], ["bottoms", cc.bottomsControl, 0.4],
			["footwear", cc.footwearControl, -1.0], ["tops", cc.topControl, 0.4], ["bra", cc.braControl, 0.4],
			["tonguePiercing", cc.tonguePiercingControl, 0.5], ["nipplePiercing", cc.nipplePiercingControl, 0.5],
			["bellyPiercing", cc.bellyPiercingControl, 0.5], ["earring", cc.earringControl, 0.5],
			["headwear", cc.headwearControl, 0.5]]:
		if parts.get(c[0], false):
			var a: bool = alpha.get(c[0], false)
			c[1].shuffle(PaletteUtils.randomSwatch(_loc1_, a), PaletteUtils.randomSwatch(_loc1_, a), c[2])
	if parts.get("herPenis", false):   # from regulaterandom: her penis's costume and size
		var hp = g.her.penisControl
		var a: bool = alpha.get("herPenis", false)
		hp.penisControl.shuffle(PaletteUtils.randomSwatch(_loc1_, a), PaletteUtils.randomSwatch(_loc1_, a), 0.5)
		var size: float = randf() * (hp.MAX_PENIS_SIZE - hp.MIN_PENIS_SIZE) + hp.MIN_PENIS_SIZE
		hp.loadPenisScales(size, size)
	if g.resetIntroOnNewChar:
		g.resetIntro()
	g.saveData.saveCharData()
	if Hooks.has(&"InGameMenu.shuffle"):   # HOOK
		Hooks.after(&"InGameMenu.shuffle", self, [parts, alpha])


func setDialogueLibraryName(param1):
	moddingMenu.dialogueLibraryName.text = param1
	if dialoguePicker != null:
		CharacterElementHelper.setPickerLabel(dialoguePicker, str(param1))
	if param1 == DialogueLibrary.DEFAULT_NAME:
		moddingMenu.dialogueLibraryName.type = "dynamic"
		moddingMenu.dialogueLibraryName.textColor = 6784420
	else:
		moddingMenu.dialogueLibraryName.type = "input"
		moddingMenu.dialogueLibraryName.textColor = 9030


func dialogueLibraryNameChanged(param1 = null):
	g.dialogueControl.setDialogueLibraryName(moddingMenu.dialogueLibraryName.text)
	moddingMenu.dialogueLibraryName.textColor = 9030


func resetDefaultDialogueClicked(param1 = null):
	g.dialogueControl.resetCustomDialogue()


func saveDialogueClicked(param1 = null):
	var _loc2_ = g.dialogueControl.exportDialogue()
	dialogueFile.save(_loc2_,"Dialogue.txt")
	savingDialogue = true
	browsingForDialogue = false


func loadDialogueClicked(param1 = null):
	browsingForDialogue = true
	savingDialogue = false
	dialogueFile.browse()


func editDialogueClicked(param1 = null):
	closeMenu()
	finishSlideout()
	g.dialogueEditor.open()
	g.dialogueEditor.showDialogue(g.dialogueControl.getCurrentDialogue(),g.dialogueControl.getCurrentFinishes())


func dialogueSelectHandler(param1 = null):
	if browsingForDialogue:
		dialogueFile.load()


func dialogueCompleteHandler(param1 = null):
	var dialogueBA = null
	var loadedDialogue = null
	var e = param1
	if browsingForDialogue:
		dialogueBA = dialogueFile.data
		loadedDialogue = Flash.bytes_to_string(dialogueBA)
		g.dialogueControl.loadCustomDialogue(loadedDialogue)
	elif savingDialogue:
		savingDialogue = false


func dialogueCancelHandler(param1 = null):
	browsingForDialogue = false
	savingDialogue = false


func storeCharClicked(param1 = null):
	if g.gameRunning:
		charStoring.setEditing(false)
		openCharStoring()


func characterStoredSuccessfully(param1 = null):
	closeCharStoring()
	currentTab = 1
	updateTabs()
	openCharacterMenu()


func characterDeleted(param1 = null):
	closeCharStoring()
	currentTab = 1
	updateTabs()
	openCharacterMenu()


func openCharStoring(param1 = true):
	if param1:
		charStoring.setupChar(getSaveDataString(false))
	charStoring.populateMods()
	charStoring.visible = true
	charStoringOpen = true
	charStoringJustOpened = true


func closeCharStoring():
	charStoring.visible = false
	charStoringOpen = false


func charStoringCloseClicked(param1 = null):
	closeCharStoring()


func editCharListClicked(param1 = null):
	pass

func saveBackupClicked(param1 = null):
	# The backup file is an AMF3-serialized Array, as written by Flash's ByteArray.writeObject.
	var _loc3_ = []
	for _loc4_ in g.storedChars:
		_loc3_.append(_loc4_.saveFileObject())
	_loc3_.append(characterMenu.getCharOrderObject())
	storedCharsBackup.save(AMF3.encode(_loc3_), "CustomChars.sdt")
	savingStoredCharsBackup = true
	browsingForStoredCharsBackup = false


func loadBackupClicked(param1 = null):
	browsingForStoredCharsBackup = true
	savingStoredCharsBackup = false
	storedCharsBackup.browse()


func storedCharsSelectHandler(param1 = null):
	if browsingForStoredCharsBackup:
		storedCharsBackup.load()


func storedCharsCompleteHandler(param1 = null):
	var storedCharsBA = null
	var newStoredChars = null
	var fileLoadedOkay = false
	var fileOkay = false
	var e = param1
	if browsingForStoredCharsBackup:
		storedCharsBA = storedCharsBackup.data
		fileLoadedOkay = false
		if storedCharsBA.size() > 1 and storedCharsBA[0] == 0x00 and storedCharsBA[1] == 0xBF:
			# Port extension: a Flash save (ChoIrrumatio.sol) instead of a backup file
			newStoredChars = _storedCharsFromSol(storedCharsBA, storedCharsBackup._path)
		else:
			newStoredChars = AMF3.decode(storedCharsBA)
		fileLoadedOkay = AMF3.lastError == ""
		if not fileLoadedOkay:
			showError("Error loading character file.")
		if fileLoadedOkay:
			fileOkay = true
			if not (newStoredChars is Array):
				fileOkay = false
			if fileOkay:
				instanceStoredCharFile(newStoredChars)
			else:
				showError("Error loading character file.")
	elif savingStoredCharsBackup:
		savingStoredCharsBackup = false


## Port extension: imports a backup file or a Flash save (.sol) from a path, like Load Backup.
func importStoredCharsFile(path: String) -> bool:
	var bytes := FileAccess.get_file_as_bytes(path)
	var chars = _storedCharsFromSol(bytes, path) if bytes.size() > 1 and bytes[0] == 0x00 and bytes[1] == 0xBF 		else AMF3.decode(bytes)
	if not chars is Array:
		showError("Error loading character file.")
		return false
	instanceStoredCharFile(chars)
	return true


## Port extension: the saved characters of a Flash save (ChoIrrumatio.sol from SDT / the Loader, with thumbnails
## from ChoIrrumatio_thumbs.sol next to it) as backup-file entries.
func _storedCharsFromSol(bytes: PackedByteArray, path: String):
	var data = AMF3.decode_sol(bytes)
	if data == null:
		return null
	if data.get("customCharNames") == null:
		# e.g. ChoIrrumatio_thumbs.sol or another game's save: not an error-free empty list, which "overwrite
		# list" would turn into deleting every stored character
		AMF3.lastError = "No saved characters in this file"
		return null
	var names := _solList(data.get("customCharNames"))
	var datas := _solList(data.get("customCharData"))
	var dialogues := _solList(data.get("customCharDialogue"))
	var shots = null
	var thumbs := path.get_base_dir().path_join("ChoIrrumatio_thumbs.sol")
	if path != "" and FileAccess.file_exists(thumbs):
		var t = AMF3.decode_sol(FileAccess.get_file_as_bytes(thumbs))
		if t != null:
			shots = _solList(t.get("customCharShots"))
		AMF3.lastError = ""
	var out := []
	for i in names.size():
		if names[i] == null:
			continue
		var o := {"charName": str(names[i]), "charData": str(datas[i]) if i < datas.size() and datas[i] != null else ""}
		if i < dialogues.size() and dialogues[i] != null:
			o["dialogue"] = dialogues[i]
		if shots is Array and i < shots.size() and shots[i] is PackedByteArray:
			o["shotBytes"] = shots[i]
		out.append(o)
	if data.get("baseCharOrder") != null and data.get("customCharOrder") != null:
		out.append({"charName": "", "baseCharOrder": _solList(data["baseCharOrder"]),
			"customCharOrder": _solList(data["customCharOrder"])})
	return out


## Flash arrays with gaps decode as Dictionaries (index -> value); turn them back into Arrays.
static func _solList(v) -> Array:
	if v is Array:
		return v
	var out := []
	if v is Dictionary:
		for k in v:
			var s := str(k)
			if s.is_valid_int() and int(s) >= 0:
				var i := int(s)
				if i >= out.size():
					out.resize(i + 1)
				out[i] = v[k]
	return out


func storedCharsCancelHandler(param1 = null):
	browsingForStoredCharsBackup = false
	savingStoredCharsBackup = false


func instanceStoredCharFile(param1):
	var _loc6_ = null
	if g.overwriteCharList:
		characterMenu.clearStoredChars()
	var _loc2_ = []
	var _loc3_ = []
	var _loc4_ = []
	for _loc5_ in param1:
		if _loc5_["charName"]:
			# port: adding to the list skips characters it has already (same name and code), so loading a file twice
			# (or importing from the Loader again) does not double them
			if not g.overwriteCharList and g.storedChars.any(func(c): return c.charName == str(_loc5_.charName) \
					and c.charData == str(_loc5_.charData)):
				continue
			_loc6_ = { "name":_loc5_.charName, "data":_loc5_.charData, "shotBytes":_loc5_.get("shotBytes") }
			if _loc5_.get("dialogue") != null:
				_loc6_["dialogue"] = _loc5_["dialogue"]
			_loc2_.append(_loc6_)
		elif _loc5_["baseCharOrder"]:
			_loc3_ = _loc5_["baseCharOrder"]
			_loc4_ = _loc5_["customCharOrder"]
	characterMenu.loadCustomChars(_loc2_)
	if _loc3_ and _loc4_:
		characterMenu.updateCharOrder(_loc3_,_loc4_)
		characterMenu.saveOrder()
	currentTab = 1
	updateTabs()
	openCharacterMenu()


func cbOverwriteCharListClicked(param1 = null):
	g.overwriteCharList = not g.overwriteCharList
	updateOverwriteCharList()


func updateOverwriteCharList():
	if g.overwriteCharList:
		moddingMenu.cbOverwriteCharList.setOn()
	else:
		moddingMenu.cbOverwriteCharList.setOff()


func editChar(param1):
	charStoring.setEditing(true,param1)
	openCharStoring()


func generateClicked(param1 = null):
	generateSaveData()


func generateSaveData():
	var _loc1_ = getSaveDataString()
	moddingMenu.saveDataTF.text = _loc1_
	stage.focus = moddingMenu.saveDataTF
	moddingMenu.saveDataTF.setSelection(0,moddingMenu.saveDataTF.text.length())


func _rgba(c) -> String:
	return _s(c.r) + "," + _s(c.g) + "," + _s(c.b) + "," + _s(g.sigRound(3, c.a))


func _hsl(c) -> String:
	return _s(c.h) + "," + _s(c.s) + "," + _s(c.l) + "," + _s(c.c)


## The character's save string ("key:value;..."), the format used by the save data, stored characters and the
## Generate / Load box. Numbers are formatted as AS3 did (no ".0" on whole numbers).
func getSaveDataString(includeFiles = true) -> String:
	var cc = g.characterControl
	var s: String = ""
	var charName: String = "charName:" + str(cc.currentName)
	var mood: String = "mood:" + g.her.mood
	var bodyScale: String = "bodyScale:" + _s(g.sigRound(6, g.her.bodyScale))
	var arms: String = "arms:" + g.dataName(Her.armPositions[g.her.currentLeftArmPosition]) + "," + g.dataName(Her.armPositions[g.her.currentRightArmPosition])
	var throat: String = "throatResist:" + _s(g.throatResistance)
	var hair: String = "hair:" + g.dataName(charNames[cc.currentHair]) + "," + ",".join(PackedStringArray(cc.currentElementsStatus.map(func(v): return _s(v))))
	var iris: String = "iris:" + g.dataName(irisTypes[cc.currentIris]) + "," + _rgba(cc.irisRGB)
	var breasts: String = "breasts:" + _s(cc.breastSize)
	var skin: String = "skin:" + g.dataName(skinTypes[cc.currentSkin])
	var nose: String = "nose:" + g.dataName(CharacterControl.noseTypeList[cc.currentNose])
	var ear: String = "ear:" + g.dataName(CharacterControl.earTypeList[cc.currentEar])
	var lipstick: String = "lipstick:" + ("1" if g.smearLipstick else "0") + "," + _rgba(cc.lipstickRGB)
	var eyeshadow: String = "eyeshadow:" + _rgba(cc.eyeShadowRGB)
	var sclera: String = "sclera:" + _rgba(cc.scleraRGB)
	var blush: String = "blush:" + _rgba(cc.blushRGB)
	var freckles: String = "freckles:" + _rgba(cc.frecklesRGB) + "," + _s(g.frecklesAmount)
	var mascara: String = "mascara:" + _rgba(cc.mascaraRGB) + "," + _s(g.mascaraAmount)
	var nailpolish: String = "nailpolish:" + _rgba(cc.nailPolishRGB)
	var eyebrow: String = "eyebrow:" + g.dataName(CharacterControl.eyebrowsTypeList[cc.currentEyebrows]) + "," + _rgba(cc.eyebrowFillRGB) + "," + _rgba(cc.eyebrowLineRGB)
	var hairhsl: String = "hairhsl:" + _hsl(cc.hairHSL)
	var skinhsl: String = "skinhsl:" + _hsl(cc.skinHSL)
	var hisskinhsl: String = "hisskinhsl:" + _hsl(cc.hisSkinHSL)
	var bg: String = "bg:" + _s(g.bgID)
	var him: String = g.him.getDataString()
	var collar: String = "collar:" + cc.collarControl.getDataString()
	var cuffs: String = "cuffs:" + cc.cuffsControl.getDataString()
	var ankleCuffs: String = cc.ankleCuffsControl.getOptionalDataString("ankleCuffs")
	var gag: String = "gag:" + cc.gagControl.getDataString()
	var panties: String = "panties:" + cc.pantiesControl.getDataString()
	var top: String = "top:" + cc.braControl.getDataString()
	var armwear: String = "armwear:" + cc.armwearControl.getDataString()
	var tops: String = cc.topControl.getOptionalDataString("tops")
	var bottoms: String = cc.bottomsControl.getOptionalDataString("bottoms")
	var legwear: String = "legwear:" + cc.legwearControl.getDataString()
	var legwearB: String = cc.legwearBControl.getOptionalDataString("legwearB")
	var footwear: String = "footwear:" + cc.footwearControl.getDataString()
	var eyewear: String = "eyewear:" + cc.eyewearControl.getDataString()
	var headwear: String = "headwear:" + cc.headwearControl.getDataString()
	var tonguePiercing: String = "tonguePiercing:" + cc.tonguePiercingControl.getDataString()
	var nipplePiercing: String = cc.nipplePiercingControl.getOptionalDataString("nipplePiercing")
	var bellyPiercing: String = cc.bellyPiercingControl.getOptionalDataString("bellyPiercing")
	var earring: String = cc.earringControl.getOptionalDataString("earring")
	var tan: String = g.her.tan.getDataString()
	s = charName + ";" if cc.currentName else ""
	s += mood + ";" + bodyScale + ";" + arms + ";" + throat + ";" + hair + ";" + iris + ";" + breasts + ";" + skin + ";" + nose + ";" + ear + g.her.getDataString()
	s += ";" + lipstick + ";" + eyeshadow + ";" + sclera + ";" + blush + ";" + freckles + ";" + mascara + ";" + nailpolish + ";" + eyebrow
	s += ";" + hairhsl + ";" + skinhsl + ";" + hisskinhsl + ";" + bg
	s += ";" + him
	s += ";" + collar + ";" + cuffs + ankleCuffs + ";" + gag + ";" + panties + ";" + top + ";" + armwear + bottoms + tops + ";" + legwear + legwearB + ";" + footwear + ";" + eyewear + ";" + headwear + ";" + tonguePiercing + nipplePiercing + bellyPiercing + earring + ";" + tan
	s += CharCode.save_fields(s)   # HOOK port extension: extension fields and kept unknown fields
	if includeFiles:
		var cel = g.customElementLoader
		if cel.customHairLoaded and cel.proxyHairPackage:
			if cel.proxyHairPackage.hasFilePath():
				s += ";customHair:" + cel.proxyHairPackage.path
		if cel.customBGLoaded and cel.proxyBGPackage:
			if cel.proxyBGPackage.hasFilePath():
				s += ";customBG:" + cel.proxyBGPackage.path
		s += cel.getSwfModsDataString()
	return s



func loadClicked(param1 = null):
	loadData(moddingMenu.saveDataTF.text)


func loadData(param1, param2 = true, param3 = false, param4 = null):
	var _loc9_ = null
	var _loc10_ = null
	var _loc11_ = null
	var _loc12_ = null
	var _loc13_ = null
	var _loc14_ = null
	var _loc15_ = null
	var _loc16_ = null
	var _loc17_ = null
	var _loc18_ = null
	var _loc19_ = null
	var _loc20_ = null
	var _loc21_ = null
	var _loc22_ = null
	var _loc23_ = null
	var _loc24_ = null
	var _loc25_ = null
	var _loc26_ = 0
	var _loc27_ = null
	var _loc28_ = null
	var _loc29_ = null
	var _loc30_ = null
	var _loc31_ = null
	var _loc32_ = 0
	var _loc5_ = Array(param1.split(";"))
	var _loc6_ = []
	for _loc7_ in _loc5_:
		_loc6_.append(Array(_loc7_.split(":")))
	_loc9_ = ""
	_loc10_ = ""
	_loc11_ = ""
	_loc12_ = ""
	_loc13_ = ""
	_loc14_ = []
	if param3:
		g.customElementLoader.clearInstancedMods()
	if param3:
		charStoring.setEditing(true,param4)
	if not CharCode.keep_unlisted:   # HOOK port extension: DialogueActions' [LOAD_CHARCODE] keeps unlisted items
		_resetUnlistedForLoad()
		if g.modCatalog:
			g.modCatalog.forget_named(null)   # port: mods the previous code named, still waiting for the mod scan
	if not onlyLoadCostume:
		updateBodySlider()
		updateArmsList()
	if not onlyLoadCostume:
		for _loc8_ in _loc6_:
			match _loc8_[0]:
				"charName":
					g.characterControl.currentName = _loc8_[1]
				"mood":
					g.her.setMood(_loc8_[1])
					updateMoods()
				"customHair":
					_loc9_ = ":".join(PackedStringArray(_loc8_.slice(1)))
				"customBG":
					_loc11_ = ":".join(PackedStringArray(_loc8_.slice(1)))
				"bodyScale":
					g.her.setBodyScale(AS3.Number(_loc8_[1]))
					updateBodySlider()
				"arms":
					_loc15_ = Array(_loc8_[1].split(","))
					if _loc15_.size() == 1:
						g.her.findLeftArmPosition(_loc15_[0])
						g.her.findRightArmPosition(_loc15_[0])
					elif _loc15_.size() == 2:
						g.her.findLeftArmPosition(_loc15_[0])
						g.her.findRightArmPosition(_loc15_[1])
					updateArmsList()
				"throatResist":
					g.her.setThroatResistance(max(0,min(100,_num0(_loc8_[1]))))
					updateThroatResistanceSlider()
				"hair":
					_loc10_ = str(_loc8_[1])
				"iris":
					_loc16_ = Array(_loc8_[1].split(","))
					g.characterControl.findIris(str(_loc16_[0]))
					if _loc16_.size() == 5:
						_loc16_[1] = Maths.round(_clampNum(_loc16_[1], 0, 255))
						_loc16_[2] = Maths.round(_clampNum(_loc16_[2], 0, 255))
						_loc16_[3] = Maths.round(_clampNum(_loc16_[3], 0, 255))
						_loc16_[4] = _clampNum(_loc16_[4], 0, 1)
						if not is_nan(_loc16_[1]) and not is_nan(_loc16_[2]) and not is_nan(_loc16_[3]) and not is_nan(_loc16_[4]):
							g.characterControl.setIrisFill({ "r":_loc16_[1], "g":_loc16_[2], "b":_loc16_[3], "a":_loc16_[4] })
				"nose":
					g.characterControl.findNose(_loc8_[1])
				"ear":
					g.characterControl.findEar(_loc8_[1])
				"breasts":
					g.characterControl.setBreasts(max(1,min(149,AS3.toInt(_loc8_[1]))))
				"skin":
					g.characterControl.findSkin(_loc8_[1])
				"sclera":
					checkAndLoadRGB(_loc8_[1],g.characterControl.setSclera)
				"eyebrow":
					_loc13_ = str(_loc8_[1])
				"hairhsl":
					_loc17_ = Array(_loc8_[1].split(","))
					if _loc8_[1] == "0,1,1,1":
						g.characterControl.removeHairHSL()
					elif _loc17_.size() == 4:
						_loc17_[0] = Maths.round(_clampNum(_loc17_[0], -180, 180))
						_loc17_[1] = _clampNum(_loc17_[1], 0, 4)
						_loc17_[2] = _clampNum(_loc17_[2], 0, 4)
						_loc17_[3] = _clampNum(_loc17_[3], 0, 4)
						if not is_nan(_loc17_[0]) and not is_nan(_loc17_[1]) and not is_nan(_loc17_[2]) and not is_nan(_loc17_[3]):
							g.characterControl.applyHairHSL({ "h":_loc17_[0], "s":_loc17_[1], "l":_loc17_[2], "c":_loc17_[3] })
				"skinhsl":
					_loc18_ = Array(_loc8_[1].split(","))
					if _loc8_[1] == "0,1,1,1":
						g.characterControl.removeSkinHSL()
					elif _loc18_.size() == 4:
						_loc18_[0] = Maths.round(_clampNum(_loc18_[0], -180, 180))
						_loc18_[1] = _clampNum(_loc18_[1], 0, 4)
						_loc18_[2] = _clampNum(_loc18_[2], 0, 4)
						_loc18_[3] = _clampNum(_loc18_[3], 0, 4)
						if not is_nan(_loc18_[0]) and not is_nan(_loc18_[1]) and not is_nan(_loc18_[2]) and not is_nan(_loc18_[3]):
							g.characterControl.applySkinHSL({ "h":_loc18_[0], "s":_loc18_[1], "l":_loc18_[2], "c":_loc18_[3] })
				"hisskinhsl":
					_loc19_ = Array(_loc8_[1].split(","))
					if _loc8_[1] == "0,1,1,1":
						g.characterControl.removeHisSkinHSL()
					elif _loc19_.size() == 4:
						_loc19_[0] = Maths.round(_clampNum(_loc19_[0], -180, 180))
						_loc19_[1] = _clampNum(_loc19_[1], 0, 4)
						_loc19_[2] = _clampNum(_loc19_[2], 0, 4)
						_loc19_[3] = _clampNum(_loc19_[3], 0, 4)
						if not is_nan(_loc19_[0]) and not is_nan(_loc19_[1]) and not is_nan(_loc19_[2]) and not is_nan(_loc19_[3]):
							g.characterControl.applyHisSkinHSL({ "h":_loc19_[0], "s":_loc19_[1], "l":_loc19_[2], "c":_loc19_[3] })
				"bg":
					_loc12_ = str(_loc8_[1])
				"him":
					_loc20_ = Array(_loc8_[1].split(","))
					g.him.loadLegacyData(_loc20_)
				"dialogue":
					_loc21_ = str(_loc8_[1])
					g.dialogueControl.loadCustomDialogue(_loc21_,param2)
	g.him.loadDataPairs(_loc6_)
	g.her.loadDataPairs(_loc6_)
	for _loc8_ in _loc6_:
		match _loc8_[0]:
			"swfMod":
				_loc14_.append(":".join(PackedStringArray(_loc8_.slice(1))))
			"lipstick":
				_loc22_ = Array(_loc8_[1].split(","))
				if _loc22_.size() > 0:
					g.smearLipstick = bool(AS3.Number(_loc22_[0]))
					updateLipstickSmearing()
				if _loc22_.size() == 5:
					_loc22_[1] = Maths.round(_clampNum(_loc22_[1], 0, 255))
					_loc22_[2] = Maths.round(_clampNum(_loc22_[2], 0, 255))
					_loc22_[3] = Maths.round(_clampNum(_loc22_[3], 0, 255))
					_loc22_[4] = _clampNum(_loc22_[4], 0, 1)
					if not is_nan(_loc22_[1]) and not is_nan(_loc22_[2]) and not is_nan(_loc22_[3]) and not is_nan(_loc22_[4]):
						g.characterControl.setLipstick({ "r":_loc22_[1], "g":_loc22_[2], "b":_loc22_[3], "a":_loc22_[4] })
			"eyeshadow":
				checkAndLoadRGB(_loc8_[1],g.characterControl.setEyeShadow)
			"blush":
				checkAndLoadRGB(_loc8_[1],g.characterControl.setBlush)
			"freckles":
				_loc23_ = Array(_loc8_[1].split(","))
				checkAndLoadRGB(",".join(PackedStringArray(_loc23_.slice(0,4))),g.characterControl.setFreckles)
				if _loc23_.size() > 4 and _loc23_[4]:
					g.characterControl.setFreckleAmount(_num0(_loc23_[_loc23_.size() - 1]))
					updateFrecklesSlider()
			"mascara":
				_loc24_ = Array(_loc8_[1].split(","))
				checkAndLoadRGB(",".join(PackedStringArray(_loc24_.slice(0,4))),g.characterControl.setMascara)
				if _loc24_.size() > 4 and _loc24_[4]:
					_loc26_ = AS3.toInt(_loc24_[4])
					_loc26_ = min(100,_loc26_)
					g.mascaraAmount = _loc26_
					updateMascaraSlider()
			"nailpolish":
				checkAndLoadRGB(_loc8_[1],g.characterControl.setNailPolish)
			"collar":
				g.characterControl.collarControl.loadDataString(_loc8_[1])
			"cuffs":
				g.characterControl.cuffsControl.loadDataString(_loc8_[1])
			"ankleCuffs":
				g.characterControl.ankleCuffsControl.loadDataString(_loc8_[1])
			"gag":
				g.characterControl.gagControl.loadDataString(_loc8_[1])
			"panties":
				_loc25_ = Array(_loc8_[1].split(","))
				if _loc25_[0] == "shorts":
					_loc25_[0] = "bikeshorts"
					g.characterControl.bottomsControl.loadDataString(",".join(PackedStringArray(_loc25_)))
				else:
					g.characterControl.pantiesControl.loadDataString(_loc8_[1])
			"top":
				g.characterControl.braControl.loadDataString(_loc8_[1])
			"armwear":
				g.characterControl.armwearControl.loadDataString(_loc8_[1])
			"bottoms":
				g.characterControl.bottomsControl.loadDataString(_loc8_[1])
			"tops":
				g.characterControl.topControl.loadDataString(_loc8_[1])
			"legwear":
				g.characterControl.legwearControl.loadDataString(_loc8_[1])
			"legwearB":
				g.characterControl.legwearBControl.loadDataString(_loc8_[1])
			"footwear":
				g.characterControl.footwearControl.loadDataString(_loc8_[1])
			"eyewear":
				g.characterControl.eyewearControl.loadDataString(_loc8_[1])
			"headwear":
				_loc8_[1] = (_loc8_[1]).replace("zeldastiara","zeldascirclet")
				g.characterControl.headwearControl.loadDataString(_loc8_[1])
			"tonguePiercing":
				g.characterControl.tonguePiercingControl.loadDataString(_loc8_[1])
			"nipplePiercing":
				g.characterControl.nipplePiercingControl.loadDataString(_loc8_[1])
			"bellyPiercing":
				g.characterControl.bellyPiercingControl.loadDataString(_loc8_[1])
			"earring":
				g.characterControl.earringControl.loadDataString(_loc8_[1])
	g.her.tan.loadDataPairs(_loc6_)
	if g.resetIntroOnNewChar and not onlyLoadCostume:
		g.resetIntro()
	if _loc14_.size() > 0:
		g.customElementLoader.tryToLoadSwfMods(_loc14_,true,onlyLoadCostume)
	if _loc9_ != "":
		if g.modCatalog:   # port: an image hair, no hair mod from the catalog
			g.modCatalog.forget_named("hair")
			hairModIndex = -1
		_loc27_ = g.customElementLoader.tryToLoadHairFile(_loc9_)
		if param3:
			_loc27_.contentLoaderInfo.addEventListener(FlashEvent.IO_ERROR,modIOError)
	elif _loc10_ != "":
		g.customElementLoader.clearCustomHair()
		_loc28_ = Array(_loc10_.split(","))
		if g.characterControl.findHair(_loc28_[0],false):
			if g.modCatalog:
				g.modCatalog.forget_named("hair")
		elif g.modCatalog:
			# port: not one of the game's hairstyles (a Loader character's mod hair): the installed hair mod of that name
			g.modCatalog.find_named("hair", _loc28_[0], _wearHairMod)
		g.characterControl.setCurrentElements(_loc28_.slice(1))
	if _loc13_ != "":
		_loc29_ = Array(_loc13_.split(","))
		if _loc29_.size() == 8:
			_loc29_ = (["normal"] + _loc29_)
		if _loc29_.size() == 9:
			_loc30_ = _loc29_.pop_front()
			_loc29_[0] = Maths.round(_clampNum(_loc29_[0], 0, 255))
			_loc29_[1] = Maths.round(_clampNum(_loc29_[1], 0, 255))
			_loc29_[2] = Maths.round(_clampNum(_loc29_[2], 0, 255))
			_loc29_[3] = _clampNum(_loc29_[3], 0, 1)
			_loc29_[4] = Maths.round(_clampNum(_loc29_[4], 0, 255))
			_loc29_[5] = Maths.round(_clampNum(_loc29_[5], 0, 255))
			_loc29_[6] = Maths.round(_clampNum(_loc29_[6], 0, 255))
			_loc29_[7] = _clampNum(_loc29_[7], 0, 1)
			if not is_nan(_loc29_[0]) and not is_nan(_loc29_[1]) and not is_nan(_loc29_[2]) and not is_nan(_loc29_[3]):
				g.characterControl.setEyebrowFill({ "r":_loc29_[0], "g":_loc29_[1], "b":_loc29_[2], "a":_loc29_[3] })
			if not is_nan(_loc29_[4]) and not is_nan(_loc29_[5]) and not is_nan(_loc29_[6]) and not is_nan(_loc29_[7]):
				g.characterControl.setEyebrowLine({ "r":_loc29_[4], "g":_loc29_[5], "b":_loc29_[6], "a":_loc29_[7] })
			g.characterControl.findEyebrows(_loc30_)
	if _loc11_ != "":
		_loc31_ = g.customElementLoader.tryToLoadBGFile(_loc11_)
		if param3:
			_loc31_.contentLoaderInfo.addEventListener(FlashEvent.IO_ERROR,modIOError)
	elif _loc12_ != "":
		g.customElementLoader.clearCustomBackground()
		_loc32_ = AS3.toInt(_loc12_)
		_loc32_ = min(g.bgNum,_loc32_)
		g.bg.gotoAndStop(_loc32_)
		g.bgID = _loc32_
		setBGCheckboxes()
	updateHairList()
	updateBreastSlider()
	updateIrisList()
	updateSkinList()
	updateNoseList()
	updateEarList()
	updateEyebrowsList()
	updateCharMenu(0,true)
	CharCode.load_fields(_loc6_, str(param1), onlyLoadCostume)   # HOOK port extension: extension fields
	if param2:
		g.saveData.saveCharData()


## loadData's reset of every clothing slot and of body scale, nose, eyebrows and ears (split out for the
## DialogueActions hook above; the original runs it inline).
func _resetUnlistedForLoad():
	g.characterControl.gagControl.findName("none")
	g.characterControl.legwearControl.findName("None")
	g.characterControl.legwearBControl.findName("None")
	g.characterControl.bottomsControl.findName("None")
	g.characterControl.ankleCuffsControl.findName("None")
	g.characterControl.topControl.findName("None")
	g.characterControl.headwearControl.findName("None")
	g.characterControl.armwearControl.findName("none")
	g.characterControl.pantiesControl.findName("none")
	g.characterControl.braControl.findName("none")
	g.characterControl.footwearControl.findName("none")
	g.characterControl.tonguePiercingControl.findName("none")
	g.characterControl.nipplePiercingControl.findName("none")
	g.characterControl.bellyPiercingControl.findName("none")
	g.characterControl.earringControl.findName("none")
	g.her.tan.setTan(0)
	if not onlyLoadCostume:
		g.her.setDefaultBodyScale()
		g.characterControl.setNose(0)
		g.characterControl.setEyebrows(0)
		g.characterControl.setEar(0)


func modIOError(param1 = null):
	openCharStoring()


func checkAndLoadRGB(param1, param2):
	var _loc3_ = Array(param1.split(","))
	if _loc3_.size() == 4:
		_loc3_[0] = Maths.round(_clampNum(_loc3_[0], 0, 255))
		_loc3_[1] = Maths.round(_clampNum(_loc3_[1], 0, 255))
		_loc3_[2] = Maths.round(_clampNum(_loc3_[2], 0, 255))
		_loc3_[3] = _clampNum(_loc3_[3], 0, 1)
		if not is_nan(_loc3_[0]) and not is_nan(_loc3_[1]) and not is_nan(_loc3_[2]) and not is_nan(_loc3_[3]):
			param2.call({ "r":_loc3_[0], "g":_loc3_[1], "b":_loc3_[2], "a":_loc3_[3] })


func populateRGBSwatch(param1):
	var _loc3_ = null
	var _loc2_ = 0
	while _loc2_ <= 8:
		_loc3_ = FlashColorTransform.new(1,1,1,1,param1[_loc2_].r,param1[_loc2_].g,param1[_loc2_].b)
		rgbPicker["swatch" + str(_loc2_)].swatchFill.colorTransform = _loc3_
		_loc2_ += 1
	if param1[0].a == 0:
		rgbPicker.swatch0.swatchFill.alpha = 0
		rgbPicker.swatch0.cross.visible = true
	else:
		rgbPicker.swatch0.swatchFill.alpha = 1
		rgbPicker.swatch0.cross.visible = false


func copyRGBSwatchClicked(param1 = null):
	clipboardARGB = AlphaRGBObject.new(rgbPicker.alphaControls.aSlider.currentValue() / 255,rgbPicker.rSlider.currentValue(),rgbPicker.gSlider.currentValue(),rgbPicker.bSlider.currentValue())
	var _loc2_ = FlashColorTransform.new(1,1,1,1,clipboardARGB.r,clipboardARGB.g,clipboardARGB.b)
	clipboardSwatch.swatchFill.colorTransform = _loc2_
	clipboardSwatch.alpha = 1
	clipboardSwatch.visible = true


func pasteRGBSwatchClicked(param1 = null):
	setRGBPicker(clipboardARGB)


func eyedropperClicked(param1 = null):
	eyedropperOn = true
	eyedropperCursor.visible = true
	eyedropperCursor.x = mouseX
	eyedropperCursor.y = mouseY
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	g.startEyedropper()


func eyedropperDone():
	eyedropperOn = false
	eyedropperCursor.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	g.stopEyedropper()
	g.saveData.saveCharData()


func rgbEyeShadowClicked(param1 = null):
	openRGBPicker(205,-157,eyeShadowSwatch,g.characterControl.eyeShadowRGB,g.characterControl.setEyeShadow)


func rgbLipstickClicked(param1 = null):
	openRGBPicker(205,-157,lipstickSwatch,g.characterControl.lipstickRGB,g.characterControl.setLipstick)


func rgbIrisClicked(param1 = null):
	openRGBPicker(205,-157,irisSwatch,g.characterControl.irisRGB,g.characterControl.setIrisFill)


func rgbEyebrowFillClicked(param1 = null):
	openRGBPicker(205,-157,eyebrowSwatch,g.characterControl.eyebrowFillRGB,g.characterControl.setEyebrowFill)


func rgbEyebrowLineClicked(param1 = null):
	openRGBPicker(205,-157,eyebrowSwatch,g.characterControl.eyebrowLineRGB,g.characterControl.setEyebrowLine)
	rgbPickerTarget = g.characterControl.setEyebrowLine


func rgbScleraClicked(param1 = null):
	openRGBPicker(205,-157,eyeShadowSwatch,g.characterControl.scleraRGB,g.characterControl.setSclera)


func rgbBlushClicked(param1 = null):
	openRGBPicker(205,-157,eyeShadowSwatch,g.characterControl.blushRGB,g.characterControl.setBlush)
	rgbPickerTarget = g.characterControl.setBlush


func rgbMascaraClicked(param1 = null):
	openRGBPicker(205,-157,eyeShadowSwatch,g.characterControl.mascaraRGB,g.characterControl.setMascara)


func rgbFrecklesClicked(param1 = null):
	openRGBPicker(205,-157,eyeShadowSwatch,g.characterControl.frecklesRGB,g.characterControl.setFreckles)


func rgbNailPolishClicked(param1 = null):
	openRGBPicker(205,-157,lipstickSwatch,g.characterControl.nailPolishRGB,g.characterControl.setNailPolish)


func hslHerHairClicked(param1 = null):
	openHSLPicker(373,-157,g.characterControl.hairHSL)
	hslPickerTarget = g.characterControl.applyHairHSL
	hslPickerRemoveTarget = g.characterControl.removeHairHSL


func hslHerSkinClicked(param1 = null):
	openHSLPicker(373,-157,g.characterControl.skinHSL)
	hslPickerTarget = g.characterControl.applySkinHSL
	hslPickerRemoveTarget = g.characterControl.removeSkinHSL


func hslHisSkinClicked(param1 = null):
	openHSLPicker(373,-157,g.characterControl.hisSkinHSL)
	hslPickerTarget = g.characterControl.applyHisSkinHSL
	hslPickerRemoveTarget = g.characterControl.removeHisSkinHSL


func clearTintsClicked(param1 = null):
	g.characterControl.removeHairHSL()
	g.characterControl.removeSkinHSL()
	g.characterControl.removeHisSkinHSL()
	g.saveData.saveCharData()


func rgbPickerCloseClicked(param1 = null):
	closeRGBPicker()


func openRGBPicker(param1, param2, param3, param4, param5, param6 = true, param7 = "rgbFill"):
	rgbPicker.visible = true
	rgbPicker.x = param1
	rgbPicker.y = param2
	populateRGBSwatch(param3)
	updateRGBPicker(param4)
	currentSwatch = param3
	rgbPickerTarget = param5
	rgbTargetFill = param7
	if param6:
		rgbPicker.alphaControls.visible = true
	else:
		rgbPicker.alphaControls.visible = false
	rgbPickerOpen = true
	rgbPickerJustOpened = true


func closeRGBPicker():
	rgbPicker.visible = false
	rgbPickerOpen = false


func rgbPickerReleased(param1 = null):
	g.saveData.saveCharData()


func rgbPickerChanged(param1 = null):
	rgbPickerTarget.call({ "r":rgbPicker.rSlider.currentValue(), "g":rgbPicker.gSlider.currentValue(), "b":rgbPicker.bSlider.currentValue(), "a":rgbPicker.alphaControls.aSlider.currentValue() / 255 },rgbTargetFill)
	updateRGBReference()


func rgbPickerLabelChanged(param1 = null):
	setRGBPickerFromLabels()
	rgbPickerTarget.call({ "r":rgbPicker.rSlider.currentValue(), "g":rgbPicker.gSlider.currentValue(), "b":rgbPicker.bSlider.currentValue(), "a":rgbPicker.alphaControls.aSlider.currentValue() / 255 },rgbTargetFill)
	g.saveData.saveCharData()


func setRGBPicker(param1):
	rgbPicker.rSlider.setPos(param1.r / 255)
	rgbPicker.gSlider.setPos(param1.g / 255)
	rgbPicker.bSlider.setPos(param1.b / 255)
	rgbPicker.alphaControls.aSlider.setPos(param1.a)
	rgbPickerTarget.call({ "r":rgbPicker.rSlider.currentValue(), "g":rgbPicker.gSlider.currentValue(), "b":rgbPicker.bSlider.currentValue(), "a":rgbPicker.alphaControls.aSlider.currentValue() / 255 },rgbTargetFill)
	updateRGBReference()


func setRGBPickerFromLabels():
	rgbPicker.rSlider.setFromLabel()
	rgbPicker.gSlider.setFromLabel()
	rgbPicker.bSlider.setFromLabel()
	rgbPicker.alphaControls.aSlider.setFromLabel()
	updateRGBReference()


func updateRGBPicker(param1):
	rgbPicker.rSlider.setPos(param1.r / 255)
	rgbPicker.gSlider.setPos(param1.g / 255)
	rgbPicker.bSlider.setPos(param1.b / 255)
	rgbPicker.alphaControls.aSlider.setPos(param1.a)
	updateRGBReference()


func updateRGBReference():
	var _loc1_ = FlashColorTransform.new(1,1,1,1,rgbPicker.rSlider.currentValue(),rgbPicker.gSlider.currentValue(),rgbPicker.bSlider.currentValue())
	rgbPicker.reference.swatchFill.colorTransform = _loc1_


func hslPickerCloseClicked(param1 = null):
	closeHSLPicker()


func openHSLPicker(param1, param2, param3):
	hslPicker.visible = true
	hslPicker.x = param1
	hslPicker.y = param2
	updateHSLPicker(param3)
	hslPickerOpen = true
	hslPickerJustOpened = true


func closeHSLPicker():
	hslPicker.visible = false
	hslPickerOpen = false


func hslRemoveClicked(param1 = null):
	hslPickerRemoveTarget.call()
	updateHSLPicker(g.characterControl.blankHSL)
	g.saveData.saveCharData()


func hslPickerReleased(param1 = null):
	g.saveData.saveCharData()


func hslPickerChanged(param1 = null):
	hslPickerTarget.call({ "h":hslPicker.hSlider.currentValue(360) - 180, "s":hslPicker.sSlider.currentValue(400) / 100, "l":hslPicker.lSlider.currentValue(400) / 100, "c":hslPicker.cSlider.currentValue(400) / 100 })


func hslPickerLabelChanged(param1 = null):
	setHSLPickerFromLabels()
	hslPickerTarget.call({ "h":hslPicker.hSlider.currentValue(360) - 180, "s":hslPicker.sSlider.currentValue(400) / 100, "l":hslPicker.lSlider.currentValue(400) / 100, "c":hslPicker.cSlider.currentValue(400) / 100 })
	g.saveData.saveCharData()


func setHSLPickerFromLabels():
	hslPicker.hSlider.setFromLabel()
	hslPicker.sSlider.setFromLabel()
	hslPicker.lSlider.setFromLabel()
	hslPicker.cSlider.setFromLabel()


func updateHSLPicker(param1):
	hslPicker.hSlider.setPos(param1.h / 360 + 0.5)
	hslPicker.sSlider.setPos(param1.s / 4)
	hslPicker.lSlider.setPos(param1.l / 4)
	hslPicker.cSlider.setPos(param1.c / 4)


func cbStrandShadersClicked(param1 = null):
	g.strandShaders = not g.strandShaders
	updateStrandShaders()
	g.saveData.saveOptionsData()


func updateStrandShaders():
	setcbStrandShaders()
	if g.strandShaders:
		g.strandBackLayer.filters = g.spitShaders
		g.strandFrontLayer.filters = g.spitShaders
		g.cumLayer.filters = g.cumShaders
		g.strandBackLayer.alpha = 1
		g.strandFrontLayer.alpha = 1
	else:
		g.strandBackLayer.filters = []
		g.strandFrontLayer.filters = []
		g.cumLayer.filters = []
		g.strandBackLayer.alpha = 0.25
		g.strandFrontLayer.alpha = 0.25


func setcbStrandShaders():
	if g.strandShaders:
		optionsMenu.cbStrandShaders.setOn()
	else:
		optionsMenu.cbStrandShaders.setOff()


func cbShowMouseClicked(param1 = null):
	g.showMouse = not g.showMouse
	setcbShowMouse()
	g.saveData.saveOptionsData()


func setcbShowMouse():
	if g.showMouse:
		optionsMenu.cbShowMouse.setOn()
	else:
		optionsMenu.cbShowMouse.setOff()


func cbLowQualityClicked(param1 = null):
	setQualityTo(0)
	setQualityCBs()
	g.saveData.saveOptionsData()


func cbMedQualityClicked(param1 = null):
	setQualityTo(1)
	setQualityCBs()
	g.saveData.saveOptionsData()


func cbHighQualityClicked(param1 = null):
	setQualityTo(2)
	setQualityCBs()
	g.saveData.saveOptionsData()


func setQualityTo(param1):
	g.qualitySetting = param1
	if param1 == 0:
		stage.quality = "low"
	elif param1 == 1:
		stage.quality = "medium"
	elif param1 == 2:
		stage.quality = "high"
	setQualityCBs()


func setQualityCBs():
	optionsMenu.cbLowQuality.setOff()
	optionsMenu.cbMedQuality.setOff()
	optionsMenu.cbHighQuality.setOff()
	if g.qualitySetting == 0:
		optionsMenu.cbLowQuality.setOn()
	elif g.qualitySetting == 1:
		optionsMenu.cbMedQuality.setOn()
	elif g.qualitySetting == 2:
		optionsMenu.cbHighQuality.setOn()


func cbHoverOptionsClicked(param1 = null):
	g.hoverOptions = not g.hoverOptions
	setcbHoverOptions()
	g.saveData.saveOptionsData()


func setcbHoverOptions():
	if g.hoverOptions:
		optionsMenu.cbHoverOptions.setOn()
	else:
		optionsMenu.cbHoverOptions.setOff()


func cbMirroredClicked(param1 = null):
	g.sceneLayer.toggleMirrored()
	setcbMirrored()
	g.saveData.saveOptionsData()


func setcbMirrored():
	if g.mirrored:
		optionsMenu.cbMirrored.setOn()
	else:
		optionsMenu.cbMirrored.setOff()


func volumeChanged(param1 = null):
	g.soundControl.changeVolume(optionsMenu.volumeSlider.currentValue())
	g.saveData.saveOptionsData()


func updateVolumeSlider(param1):
	if g.mute:
		optionsMenu.volumeSlider.setPos(0)
	else:
		optionsMenu.volumeSlider.setPos(param1)


func clearSpitClicked(param1 = null):
	g.strandControl.clearSpitStrands()


func clearCumClicked(param1 = null):
	g.strandControl.clearCumStrands()
	g.her.openEye()


func clearMascaraClicked(param1 = null):
	g.her.clearMascara()


func clearLipstickClicked(param1 = null):
	g.him.clearLipstick()


func clearAllClicked(param1 = null):
	g.strandControl.clearSpitStrands()
	g.strandControl.clearCumStrands()
	g.her.clearMascara()
	g.him.clearLipstick()


func cbSpitClicked(param1 = null):
	g.spit = not g.spit
	if not g.spit:
		g.strandControl.clearSpitStrands()
	updateCBSpit()
	g.saveData.saveCharOptionsData()


func updateCBSpit():
	if g.spit:
		optionsMenu.cbSpit.setOn()
	else:
		optionsMenu.cbSpit.setOff()


func cbTearsClicked(param1 = null):
	g.tears = not g.tears
	if not g.tears:
		g.her.clearMascara()
		g.her.clearTearSpots()
	updateCBTears()
	g.saveData.saveCharOptionsData()


func updateCBTears():
	if g.tears:
		optionsMenu.cbTears.setOn()
		optionsMenu.cbMascara.enable()
	else:
		optionsMenu.cbTears.setOff()
		optionsMenu.cbMascara.disable()


func cbMascaraClicked(param1 = null):
	g.mascara = not g.mascara
	updateCBMascara()
	g.saveData.saveCharOptionsData()


func updateCBMascara():
	if g.mascara:
		optionsMenu.cbMascara.setOn()
	else:
		optionsMenu.cbMascara.setOff()


func cbSmudgingClicked(param1 = null):
	g.smudging = not g.smudging
	updateCBSmudging()
	g.saveData.saveCharOptionsData()


func updateCBSmudging():
	if g.smudging:
		optionsMenu.cbSmudging.setOn()
	else:
		optionsMenu.cbSmudging.setOff()


func cbNostrilSprayClicked(param1 = null):
	g.nostrilSpray = not g.nostrilSpray
	updateCBNostrilSpray()
	g.saveData.saveCharOptionsData()


func updateCBNostrilSpray():
	if g.nostrilSpray:
		optionsMenu.cbNostrilSpray.setOn()
	else:
		optionsMenu.cbNostrilSpray.setOff()


func cbSweatClicked(param1 = null):
	g.sweat = not g.sweat
	if not g.sweat:
		Sweat.clearDroplets()
	updateCBSweat()
	g.saveData.saveCharOptionsData()


func updateCBSweat():
	if g.sweat:
		optionsMenu.cbSweat.setOn()
	else:
		optionsMenu.cbSweat.setOff()


func cbIntroSoundClicked(param1 = null):
	g.introSound = not g.introSound
	updateCBIntroSound()
	g.saveData.saveOptionsData()


func updateCBIntroSound():
	if g.introSound:
		optionsMenu.cbIntroSound.setOn()
	else:
		optionsMenu.cbIntroSound.setOff()


func cbBreathingClicked(param1 = null):
	g.breathing = not g.breathing
	g.her.breathingToggled()
	updateCBBreathing()
	g.saveData.saveOptionsData()


func updateCBBreathing():
	if g.breathing:
		optionsMenu.cbBreathing.setOn()
	else:
		optionsMenu.cbBreathing.setOff()


func cbGaggingClicked(param1 = null):
	g.gagging = not g.gagging
	updateCBGagging()
	g.saveData.saveCharOptionsData()


func updateCBGagging():
	if g.gagging:
		optionsMenu.cbGagging.setOn()
	else:
		optionsMenu.cbGagging.setOff()


func cbCoughingClicked(param1 = null):
	g.coughing = not g.coughing
	updateCBCoughing()
	g.saveData.saveCharOptionsData()


func updateCBCoughing():
	if g.coughing:
		optionsMenu.cbCoughing.setOn()
	else:
		optionsMenu.cbCoughing.setOff()


func cbTongueClicked(param1 = null):
	g.tongue = not g.tongue
	g.her.tongueToggled()
	updateCBTongue()
	g.saveData.saveCharOptionsData()


func updateCBTongue():
	if g.tongue:
		optionsMenu.cbTongue.setOn()
	else:
		optionsMenu.cbTongue.setOff()


func throatBulgeSliderReleased(param1 = null):
	g.saveData.saveCharOptionsData()


func throatBulgeSliderChanged(param1 = null):
	g.throatBulgeAmount = optionsMenu.throatBulgeSlider.currentValue(150) / 100
	g.her.throatBulgeChanged()


func updateThroatBulgeSlider():
	optionsMenu.throatBulgeSlider.setPos(g.throatBulgeAmount / 1.5)


func mbDefaultThroatBulgeClicked(param1 = null):
	g.throatBulgeAmount = 1
	g.her.throatBulgeChanged()
	updateThroatBulgeSlider()
	g.saveData.saveCharOptionsData()


func cbDialogueClicked(param1 = null):
	g.dialogue = not g.dialogue
	g.dialogueControl.dialogueToggled()
	updateCBDialogue()
	g.saveData.saveCharOptionsData()


func updateCBDialogue():
	if g.dialogue:
		optionsMenu.cbDialogue.setOn()
	else:
		optionsMenu.cbDialogue.setOff()


func cbInvertControlsClicked(param1 = null):
	g.invertControls = not g.invertControls
	updateCBInvertControls()
	g.saveData.saveOptionsData()


func updateCBInvertControls():
	if g.invertControls:
		optionsMenu.cbInvertControls.setOn()
	else:
		optionsMenu.cbInvertControls.setOff()


func cbDoubleSizeScreenshotClicked(param1 = null):
	g.doubleSizeScreenshot = not g.doubleSizeScreenshot
	g.screenShotScale = 2 if g.doubleSizeScreenshot else 1
	updateCBDoubleSizeScreenshot()
	g.saveData.saveOptionsData()


func updateCBDoubleSizeScreenshot():
	if g.doubleSizeScreenshot:
		optionsMenu.cbDoubleSizeScreenshot.setOn()
	else:
		optionsMenu.cbDoubleSizeScreenshot.setOff()


func cbBukkakeModeClicked(param1 = null):
	g.bukkakeMode = not g.bukkakeMode
	setcbBukkakeMode()


func setcbBukkakeMode():
	if g.bukkakeMode:
		optionsMenu.secretOptions.cbBukkakeMode.setOn()
	else:
		optionsMenu.secretOptions.cbBukkakeMode.setOff()


## Math.max(lo, Math.min(hi, Number(v))) keeping AS3's NaN for unparseable input (callers check is_nan).
static func _clampNum(v, lo: float, hi: float) -> float:
	var n := AS3.Number(v)
	if is_nan(n):
		return NAN
	return maxf(lo, minf(hi, n))


## Number(v) || 0
static func _num0(v) -> float:
	var n := AS3.Number(v)
	return 0.0 if is_nan(n) else n


## AS3 String(v) for save-string concatenation.
static func _s(v) -> String:
	return AS3.toString(v)
