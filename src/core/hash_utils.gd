class_name HashUtils
## Deterministic integer hashing used by procedural generation.
##
## We deliberately avoid the engine's hash() for world generation so results are
## stable across engine versions and platforms: same seed => same world.

const MASK_31 := 0x7FFFFFFF


## Mixes integers into a non-negative 31-bit hash.
static func hash3(a: int, b: int, c: int) -> int:
	var h: int = (a * 73856093) ^ (b * 19349663) ^ (c * 83492791)
	h = _mix(h)
	return h & MASK_31


static func hash4(a: int, b: int, c: int, d: int) -> int:
	return hash3(hash3(a, b, c), d, 0x5bd1e995)


## Uniform float in [0, 1) from a hash plus a salt (for multiple values per hash).
static func to_unit(h: int, salt: int = 0) -> float:
	var v := hash3(h, salt, 0x27d4eb2d)
	return float(v % 1000003) / 1000003.0


static func _mix(x: int) -> int:
	# 32-bit finalizer (murmur3 fmix32), kept within 32 bits on 64-bit ints.
	x &= 0xFFFFFFFF
	x ^= x >> 16
	x = (x * 0x85ebca6b) & 0xFFFFFFFF
	x ^= x >> 13
	x = (x * 0xc2b2ae35) & 0xFFFFFFFF
	x ^= x >> 16
	return x
