extends Node
class_name ManualBrowser

const MANUAL_URL := "https://www.lexaloffle.com/dl/docs/pico-8_manual.html"

var _android_runtime
var _activity
var _overlay
var _web_view
var _search_input
var _search_status
var _listener_refs: Array = []
var _is_open := false
var _last_query := ""

class ClickHandler:
	var callback: Callable

	func _init(p_callback: Callable) -> void:
		callback = p_callback

	func onClick(_view) -> void:
		callback.call_deferred()

class FindHandler:
	var callback: Callable

	func _init(p_callback: Callable) -> void:
		callback = p_callback

	func onFindResultReceived(active_match_ordinal: int, number_of_matches: int, is_done_counting: bool) -> void:
		callback.call_deferred(active_match_ordinal, number_of_matches, is_done_counting)

class EditorActionHandler:
	var callback: Callable

	func _init(p_callback: Callable) -> void:
		callback = p_callback

	func onEditorAction(_view, _action_id: int, _event) -> bool:
		callback.call_deferred()
		return true

func open() -> void:
	if _is_open:
		return
	if not OS.has_feature("android"):
		OS.shell_open(MANUAL_URL)
		return

	_android_runtime = Engine.get_singleton("AndroidRuntime")
	if not _android_runtime:
		push_error("AndroidRuntime is unavailable; cannot open the in-app manual")
		return
	_activity = _android_runtime.getActivity()
	if not _activity:
		push_error("Android Activity is unavailable; cannot open the in-app manual")
		return

	_is_open = true
	if PicoVideoStreamer.instance:
		PicoVideoStreamer.instance.set_input_blocked(true)
	_run_on_ui(Callable(self, "_build_native_overlay"))

func close() -> void:
	if not _is_open:
		return
	_is_open = false
	if PicoVideoStreamer.instance:
		PicoVideoStreamer.instance.set_input_blocked(false)
	if _activity:
		_run_on_ui(Callable(self, "_destroy_native_overlay"))

func is_open() -> bool:
	return _is_open

func _exit_tree() -> void:
	if _is_open:
		close()

func _run_on_ui(callback: Callable) -> void:
	_activity.runOnUiThread(_android_runtime.createRunnableFromGodotCallable(callback))

func _build_native_overlay() -> void:
	if not _is_open or _overlay:
		return

	var FrameLayout = JavaClassWrapper.wrap("android.widget.FrameLayout")
	var LinearLayout = JavaClassWrapper.wrap("android.widget.LinearLayout")
	var LayoutFactory = JavaClassWrapper.wrap("io.wip.pico8.manual.ManualLayoutFactory")
	var TextView = JavaClassWrapper.wrap("android.widget.TextView")
	var EditText = JavaClassWrapper.wrap("android.widget.EditText")
	var Button = JavaClassWrapper.wrap("android.widget.Button")
	var WebView = JavaClassWrapper.wrap("android.webkit.WebView")
	var AndroidColor = JavaClassWrapper.wrap("android.graphics.Color")
	var Gravity = JavaClassWrapper.wrap("android.view.Gravity")
	var TypedValue = JavaClassWrapper.wrap("android.util.TypedValue")
	var EditorInfo = JavaClassWrapper.wrap("android.view.inputmethod.EditorInfo")

	var metrics = _activity.getResources().getDisplayMetrics()
	var density: float = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 1.0, metrics)
	var padding := int(8.0 * density)
	var toolbar_height := int(48.0 * density)
	var panel_width := int(_activity.getWindow().getDecorView().getWidth() * 0.94)

	_overlay = FrameLayout.FrameLayout(_activity)
	_overlay.setBackgroundColor(AndroidColor.argb(170, 0, 0, 0))
	_overlay.setClickable(true)
	_overlay.setFocusable(true)
	_overlay.setOnClickListener(_make_click_listener(Callable(self, "close")))

	var panel = LinearLayout.LinearLayout(_activity)
	panel.setOrientation(LinearLayout.VERTICAL)
	panel.setPadding(padding, padding, padding, padding)
	panel.setBackgroundColor(AndroidColor.rgb(24, 24, 28))

	var header = LinearLayout.LinearLayout(_activity)
	header.setOrientation(LinearLayout.HORIZONTAL)
	header.setGravity(Gravity.CENTER_VERTICAL)
	var title = TextView.TextView(_activity)
	title.setText("PICO-8 MANUAL")
	title.setTextColor(AndroidColor.WHITE)
	title.setTextSize(18.0)
	header.addView(title, LayoutFactory.weighted(0, toolbar_height, 1.0))
	var reload_button = Button.Button(_activity)
	reload_button.setText("↻")
	reload_button.setContentDescription("Reload manual")
	reload_button.setOnClickListener(_make_click_listener(Callable(self, "_reload")))
	header.addView(reload_button, LayoutFactory.linear(-2, toolbar_height))
	var close_button = Button.Button(_activity)
	close_button.setText("✕")
	close_button.setContentDescription("Close manual")
	close_button.setOnClickListener(_make_click_listener(Callable(self, "close")))
	header.addView(close_button, LayoutFactory.linear(-2, toolbar_height))
	panel.addView(header, LayoutFactory.linear(-1, toolbar_height))

	var search_bar = LinearLayout.LinearLayout(_activity)
	search_bar.setOrientation(LinearLayout.HORIZONTAL)
	search_bar.setGravity(Gravity.CENTER_VERTICAL)
	_search_input = EditText.EditText(_activity)
	_search_input.setSingleLine(true)
	_search_input.setHint("Search manual")
	_search_input.setTextColor(AndroidColor.WHITE)
	_search_input.setHintTextColor(AndroidColor.rgb(170, 170, 170))
	_search_input.setImeOptions(EditorInfo.IME_ACTION_SEARCH)
	_search_input.setOnEditorActionListener(_make_editor_action_listener())
	search_bar.addView(_search_input, LayoutFactory.weighted(0, toolbar_height, 1.0))

	var search_button = Button.Button(_activity)
	search_button.setText("FIND")
	search_button.setContentDescription("Find in manual")
	search_button.setOnClickListener(_make_click_listener(Callable(self, "_find_all")))
	search_bar.addView(search_button, LayoutFactory.linear(-2, toolbar_height))

	var previous_button = Button.Button(_activity)
	previous_button.setText("◀")
	previous_button.setContentDescription("Previous search result")
	previous_button.setOnClickListener(_make_click_listener(_find_next.bind(false)))
	search_bar.addView(previous_button, LayoutFactory.linear(-2, toolbar_height))

	var next_button = Button.Button(_activity)
	next_button.setText("▶")
	next_button.setContentDescription("Next search result")
	next_button.setOnClickListener(_make_click_listener(_find_next.bind(true)))
	search_bar.addView(next_button, LayoutFactory.linear(-2, toolbar_height))

	_search_status = TextView.TextView(_activity)
	_search_status.setText("0/0")
	_search_status.setTextColor(AndroidColor.WHITE)
	_search_status.setGravity(Gravity.CENTER)
	search_bar.addView(_search_status, LayoutFactory.linear(int(64.0 * density), toolbar_height))
	panel.addView(search_bar, LayoutFactory.linear(-1, toolbar_height))

	_web_view = WebView.WebView(_activity)
	_web_view.setBackgroundColor(AndroidColor.WHITE)
	LayoutFactory.configureWebView(_web_view)
	_web_view.setFindListener(_make_find_listener())
	panel.addView(_web_view, LayoutFactory.weighted(-1, 0, 1.0))
	_overlay.addView(panel, LayoutFactory.frame(panel_width, -1, Gravity.LEFT))

	_activity.addContentView(_overlay, LayoutFactory.root(-1, -1))
	_web_view.loadUrl(MANUAL_URL)
	_search_input.requestFocus()

func _destroy_native_overlay() -> void:
	if _web_view:
		_web_view.stopLoading()
		_web_view.clearMatches()
		_web_view.destroy()
	if _overlay:
		var parent = _overlay.getParent()
		if parent:
			parent.removeView(_overlay)
	_overlay = null
	_web_view = null
	_search_input = null
	_search_status = null
	_listener_refs.clear()
	_last_query = ""

func _make_click_listener(callback: Callable):
	var handler = ClickHandler.new(callback)
	var proxy = JavaClassWrapper.create_proxy(handler, ["android.view.View$OnClickListener"])
	_listener_refs.append(handler)
	_listener_refs.append(proxy)
	return proxy

func _make_find_listener():
	var handler = FindHandler.new(Callable(self, "_update_find_result"))
	var proxy = JavaClassWrapper.create_proxy(handler, ["android.webkit.WebView$FindListener"])
	_listener_refs.append(handler)
	_listener_refs.append(proxy)
	return proxy

func _make_editor_action_listener():
	var handler = EditorActionHandler.new(Callable(self, "_find_all"))
	var proxy = JavaClassWrapper.create_proxy(handler, ["android.widget.TextView$OnEditorActionListener"])
	_listener_refs.append(handler)
	_listener_refs.append(proxy)
	return proxy

func _reload() -> void:
	if _web_view:
		_run_on_ui(func(): _web_view.reload())

func _find_all() -> void:
	if _web_view and _search_input:
		_run_on_ui(Callable(self, "_find_all_on_ui"))

func _find_all_on_ui() -> void:
	var query := str(_search_input.getText().toString()).strip_edges()
	_last_query = query
	if query.is_empty():
		_web_view.clearMatches()
		_search_status.setText("0/0")
		return
	_web_view.findAllAsync(query)

func _find_next(forward: bool) -> void:
	if _web_view:
		_run_on_ui(_find_next_on_ui.bind(forward))

func _find_next_on_ui(forward: bool) -> void:
	if _last_query.is_empty():
		_find_all_on_ui()
		return
	_web_view.findNext(forward)

func _update_find_result(active_match_ordinal: int, number_of_matches: int, is_done_counting: bool) -> void:
	if not _search_status or not is_done_counting:
		return
	var label := "0/0" if number_of_matches == 0 else "%d/%d" % [active_match_ordinal + 1, number_of_matches]
	_run_on_ui(func():
		if _search_status:
			_search_status.setText(label)
	)
