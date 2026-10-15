class_name NetHitbox
extends StaticBody3D
## Milestone 19: the body of a guest's puppet on a co-op host, so monster bolts
## (ray/shape casts on the PLAYER layer) can hit guests. Hits are passed to the
## RemotePlayer, which sends them to the guest.


func receive_hit(info: DamageInfo) -> float:
	var rp := get_parent() as RemotePlayer
	return rp.receive_hit(info) if rp else 0.0
