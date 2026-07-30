extends SceneTree


const Manifest = preload(
	"res://scripts/abilities/spell_capability_manifest.gd"
)
const Audit = preload(
	"res://scripts/abilities/spell_capability_audit.gd"
)

const DEFAULT_OUTPUT_ROOT: String = "user://spell_reports"


func _initialize() -> void:
	var output_root: String = _resolve_output_root()
	var bundle: Dictionary = Manifest.build_bundle()
	var audit: Dictionary = Audit.audit_bundle(bundle)
	var absolute_output: String = ProjectSettings.globalize_path(output_root)
	var mkdir_error: Error = DirAccess.make_dir_recursive_absolute(absolute_output)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		push_error(
			"SPELL_MANIFEST_EXPORT: Could not create " + output_root
			+ " (error " + str(mkdir_error) + ")"
		)
		quit(1)
		return

	var write_failures: Array[String] = []
	_write_text(
		output_root.path_join("spell_manifest.json"),
		Manifest.to_json(bundle),
		write_failures
	)
	_write_text(
		output_root.path_join("spell_manifest.md"),
		Manifest.to_markdown(bundle),
		write_failures
	)
	_write_text(
		output_root.path_join("spell_audit.json"),
		JSON.stringify(audit, "  ", false),
		write_failures
	)

	if not write_failures.is_empty():
		for failure: String in write_failures:
			push_error("SPELL_MANIFEST_EXPORT: " + failure)
		quit(1)
		return

	print("SPELL_MANIFEST_EXPORT: " + Audit.format_summary(audit))
	print("SPELL_MANIFEST_EXPORT: wrote reports to " + absolute_output)
	quit(0 if bool(audit.get("valid", false)) else 1)


func _resolve_output_root() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			var requested: String = argument.trim_prefix("--output=").strip_edges()
			if requested != "":
				return requested
	return DEFAULT_OUTPUT_ROOT


func _write_text(
	path: String,
	content: String,
	failures: Array[String]
) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append(
			"Could not write " + path + " (error "
			+ str(FileAccess.get_open_error()) + ")"
		)
		return
	file.store_string(content)
	file.close()
