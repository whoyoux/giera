class_name Downloader
extends Node
## Pobieranie z GitHuba przez przekierowania. Limit czasu pilnuje braku postepu,
## a nie calego pobierania, bo wolne lacze tez ma prawo skonczyc.

signal progress(done: int, total: int)

const MAX_REDIRECTS := 6
const STALL_SECONDS := 20.0
const CHUNK_SIZE := 1 << 18
const MANIFEST_LIMIT := 1 << 20


## Zwraca tresc albo pusty tekst. Brak pliku, sieci i odpowiedzi znacza to samo: nie aktualizuj.
func fetch_text(url: String, timeout: float) -> String:
	var request := _new_request()
	request.timeout = timeout
	request.body_size_limit = MANIFEST_LIMIT
	if request.request(url) != OK:
		request.queue_free()
		return ""
	var result: Array = await request.request_completed
	request.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS or result[1] != 200:
		return ""
	return (result[3] as PackedByteArray).get_string_from_utf8()


func fetch_file(url: String, path: String, expected_size: int) -> bool:
	var request := _new_request()
	request.download_file = path
	request.download_chunk_size = CHUNK_SIZE
	# Lambda dostaje kopie zmiennych, wiec wynik trafia do wspolnej tablicy, a nie do nowej.
	var outcome: Array = []
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		outcome.append_array([result, code]))
	if request.request(url) != OK:
		request.queue_free()
		return false
	var last_done := -1
	var stalled := 0.0
	while outcome.is_empty():
		await get_tree().process_frame
		var done := request.get_downloaded_bytes()
		if done != last_done:
			last_done = done
			stalled = 0.0
			progress.emit(done, expected_size)
		else:
			stalled += get_process_delta_time()
			if stalled > STALL_SECONDS:
				request.cancel_request()
				request.queue_free()
				return false
	request.queue_free()
	if outcome[0] != HTTPRequest.RESULT_SUCCESS or outcome[1] != 200:
		print("[launcher] blad pobierania: wynik %d, kod %d" % outcome)
		return false
	return true


func _new_request() -> HTTPRequest:
	var request := HTTPRequest.new()
	request.max_redirects = MAX_REDIRECTS
	request.use_threads = true
	add_child(request)
	return request
