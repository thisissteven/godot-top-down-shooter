class_name PresentationComponent
extends Node

enum Motion {
	IDLE,
	WALK,
	JUMP
}

var motion := Motion.IDLE

var dir := FacingComponent.Dir.SE
var flip_h := false

var armed := false
var aiming := false
var moving := false
var jumping := false
var running := false

var show_arms := false
var use_gun_body := false

var animation_name := ""
