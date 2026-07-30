extends RefCounted
class_name SquadPlan


var plan_id: String = ""
var squad_id: String = ""
var reaction_id: String = ""
var target_id: int = 0
var setup_owner_id: int = 0
var payoff_owner_id: int = 0
var setup_reservation_id: String = ""
var payoff_reservation_id: String = ""
var expires_at: float = 0.0


func absorb_reservation(reservation: TacticalReservation) -> void:
	if reservation == null:
		return
	plan_id = reservation.plan_id
	squad_id = reservation.squad_id
	reaction_id = reservation.reaction_id
	target_id = reservation.target_id
	expires_at = maxf(expires_at, reservation.expires_at)
	match reservation.reservation_kind:
		"setup":
			setup_owner_id = reservation.owner_id
			setup_reservation_id = reservation.reservation_id
		"payoff":
			payoff_owner_id = reservation.owner_id
			payoff_reservation_id = reservation.reservation_id


func is_complete() -> bool:
	return setup_owner_id != 0 and payoff_owner_id != 0


func to_dictionary() -> Dictionary:
	return {
		"plan_id": plan_id,
		"squad_id": squad_id,
		"reaction_id": reaction_id,
		"target_id": target_id,
		"setup_owner_id": setup_owner_id,
		"payoff_owner_id": payoff_owner_id,
		"setup_reservation_id": setup_reservation_id,
		"payoff_reservation_id": payoff_reservation_id,
		"complete": is_complete(),
		"expires_at": expires_at,
	}
