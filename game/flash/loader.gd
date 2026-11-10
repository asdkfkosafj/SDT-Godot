class_name FlashLoader
extends FlashSprite
## flash.display.Loader: loads external content (images; mod packages via registered handlers) and exposes it
## as `content`. Events go through `contentLoaderInfo` (init, complete, ioError), dispatched on a later frame like
## Flash. Relative paths resolve against Flash.content_root() (the folder the game runs from).

class LoaderInfo:
	extends FlashEventDispatcher
	var content: FlashDisplayObject = null
	var loader: FlashLoader = null
	var url: String = ""
	var bytes: PackedByteArray

var content: FlashDisplayObject = null
var contentLoaderInfo: LoaderInfo = LoaderInfo.new()

## Handlers tried in order: func(path: String, bytes: PackedByteArray) -> FlashDisplayObject (null = not mine).
static var handlers: Array[Callable] = []
## Port: work a handler needs done first, without blocking the game: func(path, bytes) -> Callable that returns
## true while it is still busy (or an invalid Callable when there is nothing to wait for). The content and its
## events then come on the frame after it is done (FlashSwfMod: converting a new mod on a worker thread).
static var preparers: Array[Callable] = []


func _init() -> void:
	contentLoaderInfo.loader = self


func load(request) -> void:
	var url: String = request if request is String else str(request.get("url"))
	contentLoaderInfo.url = url
	var path := Flash.resolve_content_path(url)
	if path == "" or not FileAccess.file_exists(path):
		_fail.call_deferred("File not found: " + url)
		return
	var bytes := FileAccess.get_file_as_bytes(path)
	_finish.call_deferred(path, bytes)


func loadBytes(bytes: PackedByteArray) -> void:
	_finish.call_deferred("", bytes)


func unload() -> void:
	if content != null and content.parent == self:
		removeChild(content)
	content = null
	contentLoaderInfo.content = null


func _fail(msg: String) -> void:
	var e := FlashEvent.new(FlashEvent.IO_ERROR)
	e.text = msg
	contentLoaderInfo.dispatchEvent(e)


func _finish(path: String, bytes: PackedByteArray) -> void:
	for p in preparers:
		var busy: Callable = p.call(path, bytes)
		if busy.is_valid() and busy.call():
			while busy.call():
				await Flash.get_tree().process_frame
			if not is_instance_valid(self):
				return
	contentLoaderInfo.bytes = bytes
	var c: FlashDisplayObject = null
	for h in handlers:
		c = h.call(path, bytes)
		if c != null:
			break
	if c == null:
		c = _decode_image(bytes)
	if c == null:
		_fail("Unsupported content: " + (path if path else "<bytes>"))
		return
	content = c
	contentLoaderInfo.content = c
	addChild(c)
	contentLoaderInfo.dispatchEvent(FlashEvent.new(FlashEvent.INIT))
	contentLoaderInfo.dispatchEvent(FlashEvent.new(FlashEvent.COMPLETE))


static func _decode_image(bytes: PackedByteArray) -> FlashDisplayObject:
	if bytes.size() < 4:
		return null
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if bytes[0] == 0x89 and bytes[1] == 0x50:
		err = img.load_png_from_buffer(bytes)
	elif bytes[0] == 0xFF and bytes[1] == 0xD8:
		err = img.load_jpg_from_buffer(bytes)
	elif bytes[0] == 0x47 and bytes[1] == 0x49 and bytes[2] == 0x46:
		img = FlashGif.decode_first_frame(bytes)
		err = OK if img != null else ERR_FILE_CORRUPT
	elif bytes[0] == 0x42 and bytes[1] == 0x4D:
		err = img.load_bmp_from_buffer(bytes)
	elif bytes[0] == 0x52 and bytes[1] == 0x49:
		err = img.load_webp_from_buffer(bytes)
	if err != OK or img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	var bd := FlashBitmapData.from_image(img)
	return FlashBitmap.new(bd, "auto", true)
