extends Node2D

func playglobalsound(filename, volume = -20):
	print(load(filename))
	print($AudioStreamPlayer.stream)
	print($AudioStreamPlayer.playing)
	if load(filename) == $AudioStreamPlayer.stream and $AudioStreamPlayer.playing == true:
		return
	else:
		$AudioStreamPlayer.stream = load(filename)
		$AudioStreamPlayer.playing = true
	$AudioStreamPlayer.volume_db = volume

func stopsound():
	$AudioStreamPlayer.playing = false
