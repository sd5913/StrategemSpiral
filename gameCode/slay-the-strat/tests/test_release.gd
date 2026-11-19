extends GutTest


func test_linux_export_starts_and_exits_without_script_errors() -> void:
	if OS.get_environment("STRATEGEM_LINUX_EXPORT").is_empty():
		pending("Set STRATEGEM_LINUX_EXPORT to the absolute Linux export path")
		return

	var output := _run_linux_export()
	var entry_path: String = ProjectSettings.get_setting("application/run/main_scene")
	if entry_path.begins_with("uid://"):
		entry_path = ResourceUID.get_id_path(ResourceUID.text_to_id(entry_path))
	assert_string_contains(output, "Completed load for: '%s'" % entry_path)
	assert_false(output.contains("SCRIPT ERROR"), "Script error in exported game:\n" + output)
	assert_false(output.contains("Error: Couldn't load project data"), "Embedded game data loads")


func test_linux_export_releases_game_music_on_exit() -> void:
	if OS.get_environment("STRATEGEM_LINUX_EXPORT").is_empty():
		pending("Set STRATEGEM_LINUX_EXPORT to the absolute Linux export path")
		return

	var output := _run_linux_export()
	var failures: Array[String] = []
	for line in output.split("\n"):
		if ("ObjectDB instances" in line and "leaked at exit" in line
				or "still in use at exit" in line or "Resource still in use:" in line):
			failures.append(line)
	assert_true(failures.is_empty(), "The Linux export releases all resources on quit.\n"
		+ "\n".join(failures))


func test_published_linux_download_exists_as_release_asset() -> void:
	var metadata_path := OS.get_environment("STRATEGEM_RELEASE_METADATA")
	if metadata_path.is_empty():
		pending("Set STRATEGEM_RELEASE_METADATA to the gh release view JSON path")
		return

	var metadata = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	assert_typeof(metadata, TYPE_DICTIONARY, "GitHub release metadata is readable")
	if not metadata is Dictionary:
		return
	assert_true(metadata.has_all(["tagName", "body", "assets"]), "Release metadata is complete")
	if not metadata.has_all(["tagName", "body", "assets"]):
		return

	var linux_line := RegEx.create_from_string("(?im)^[^\r\n]*\\bLinux:\\*{0,2}[^\r\n]*")
	var download := linux_line.search(metadata.body)
	assert_not_null(download, "Release notes have a Linux download entry")
	if download == null:
		return
	var asset_names: Array[String] = []
	for asset in metadata.assets:
		asset_names.append(asset.name)
	# The first filename is the download. An archive can contain the executable named later.
	var filename := RegEx.create_from_string("[\\x60\\[]([^\\x60\\]]+\\.(?:zip|x86_64|AppImage|tar\\.gz))[\\x60\\]]")
	var artifact := filename.search(download.get_string())
	assert_not_null(artifact, "The Linux download entry names an artifact")
	if artifact != null:
		var name := artifact.get_string(1)
		assert_has(asset_names, name, "%s names %s as a Linux download" % [metadata.tagName, name])


func _run_linux_export() -> String:
	var executable := OS.get_environment("STRATEGEM_LINUX_EXPORT")
	var output: Array = []
	var status := OS.execute("timeout", ["15s", executable, "--headless", "--verbose",
		"--quit-after", "10"], output, true)
	var log_text := "".join(output)
	assert_eq(status, 0, "The Linux export exits successfully:\n" + log_text)
	return log_text
