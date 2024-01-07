
func execute(api: Dictionary, _args):
	print("[Godot VIM] Reloading...")
	api.status_bar.display_text("Reloading plugin...", Control.TEXT_DIRECTION_LTR)
	api.vim_plugin.initialize(true)

