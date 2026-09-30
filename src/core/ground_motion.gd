class_name GroundMotion
## Movement helpers shared by all walking characters (player, enemies, NPCs).


## Lets a CharacterBody3D climb one terrain block (stairs-step) instead of being
## blocked by it. Call before move_and_slide() with this frame's horizontal
## motion. Returns true if the body was lifted onto the step.
static func try_step_up(body: CharacterBody3D, horizontal_motion: Vector3, max_step: float) -> bool:
	horizontal_motion.y = 0.0
	if horizontal_motion.length_squared() < 0.000001:
		return false
	# Look ahead a little so fast bodies don't skip the check.
	var probe := horizontal_motion
	if probe.length() < 0.12:
		probe = probe.normalized() * 0.12
	var xf := body.global_transform
	if not body.test_move(xf, probe):
		return false  # path is clear
	var up := Vector3(0.0, max_step, 0.0)
	if body.test_move(xf, up):
		return false  # ceiling in the way
	var raised := xf.translated(up)
	if body.test_move(raised, probe):
		return false  # a real wall, taller than a step
	var moved := raised.translated(probe)
	var col := KinematicCollision3D.new()
	if not body.test_move(moved, -up, col):
		return false  # no ground on the other side (edge) - let gravity handle it
	if col.get_normal().y < 0.7:
		return false  # landed on a slope/wall, not a step top
	var target := moved.origin + col.get_travel()
	# Only keep the vertical lift; horizontal motion is applied by move_and_slide.
	body.global_position.y = target.y + 0.01
	return true
