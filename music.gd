extends Node2D

func playglobalsound(filename):
	$AudioStreamPlayer.stream = load(filename)
	$AudioStreamPlayer.playing = true

func stopsound():
	$AudioStreamPlayer.playing = false
