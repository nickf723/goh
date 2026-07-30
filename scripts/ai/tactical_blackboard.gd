extends RefCounted
class_name TacticalBlackboard


const ReservationScript = preload(
	"res://scripts/ai/tactical_reservation.gd"
)
const IntentScript = preload(
	"res://scripts/ai/tactical_intent_broadcast.gd"
)
const SquadPlanScript = preload(
	"res://scripts/ai/squad_plan.gd"
)

static var reservations: Dictionary = {}
static var broadcasts: Dictionary = {}
static var next_reservation_number: int = 1
static var next_broadcast_number: int = 1
static var release_history: Array[Dictionary] = []


static func reserve_reaction_phase(
	squad_id: String,
	owner_id: int,
	owner_name: String,
	phase: String,
	reaction_id: String,
	target_id: int = 0,
	duration: float = 0.9,
	priority: float = 0.0,
	metadata: Dictionary = {}
) -> Dictionary:
	var normalized_phase: String = phase.strip_edges().to_lower()
	if normalized_phase not in ["setup", "payoff"]:
		return _denied("Reaction phase must be setup or payoff.")
	var normalized_reaction: String = reaction_id.strip_edges().to_lower()
	if normalized_reaction == "":
		return _denied("Reaction reservation requires a reaction_id.")
	var normalized_squad: String = _normalize_squad(squad_id)
	var key: String = normalized_reaction + "@" + str(target_id)
	var plan_id: String = (
		"reaction:"
		+ normalized_squad
		+ ":"
		+ str(target_id)
		+ ":"
		+ normalized_reaction
	)
	return _reserve({
		"squad_id": normalized_squad,
		"owner_id": owner_id,
		"owner_name": owner_name,
		"reservation_kind": normalized_phase,
		"reservation_key": key,
		"plan_id": plan_id,
		"reaction_id": normalized_reaction,
		"target_id": target_id,
		"duration": duration,
		"priority": priority,
		"exclusive": true,
		"metadata": metadata,
	})


static func reserve_engagement_lane(
	squad_id: String,
	owner_id: int,
	owner_name: String,
	lane_id: String,
	target_id: int = 0,
	duration: float = 0.55,
	priority: float = 0.0,
	metadata: Dictionary = {}
) -> Dictionary:
	var normalized_lane: String = lane_id.strip_edges().to_lower()
	if normalized_lane == "":
		return _denied("Engagement lane requires a lane_id.")
	return _reserve({
		"squad_id": _normalize_squad(squad_id),
		"owner_id": owner_id,
		"owner_name": owner_name,
		"reservation_kind": "lane",
		"reservation_key": normalized_lane + "@" + str(target_id),
		"plan_id": "",
		"reaction_id": "",
		"target_id": target_id,
		"duration": duration,
		"priority": priority,
		"exclusive": true,
		"metadata": metadata,
	})


static func reserve_emergency(
	squad_id: String,
	owner_id: int,
	owner_name: String,
	emergency_id: String,
	duration: float = 0.5,
	priority: float = 100.0,
	metadata: Dictionary = {}
) -> Dictionary:
	release_owner_kinds(
		owner_id,
		["setup", "payoff", "lane"],
		"emergency override",
		squad_id
	)
	return _reserve({
		"squad_id": _normalize_squad(squad_id),
		"owner_id": owner_id,
		"owner_name": owner_name,
		"reservation_kind": "emergency",
		"reservation_key": emergency_id.strip_edges().to_lower(),
		"plan_id": "",
		"reaction_id": "",
		"target_id": 0,
		"duration": duration,
		"priority": priority,
		"exclusive": false,
		"metadata": metadata,
	})


static func broadcast_intent(
	squad_id: String,
	owner_id: int,
	owner_name: String,
	intent_type: String,
	tags: Array[String],
	target_id: int = 0,
	duration: float = 0.65,
	metadata: Dictionary = {}
) -> Dictionary:
	prune_expired()
	var normalized_squad: String = _normalize_squad(squad_id)
	var normalized_type: String = intent_type.strip_edges().to_lower()
	var existing: TacticalIntentBroadcast = _find_broadcast(
		normalized_squad,
		owner_id,
		normalized_type
	)
	var now_seconds: float = _now_seconds()
	if existing != null:
		existing.refresh(
			now_seconds,
			duration,
			tags,
			target_id,
			metadata
		)
		return {"broadcast": existing.to_dictionary(), "created": false}
	var broadcast: TacticalIntentBroadcast = IntentScript.new()
	var broadcast_id: String = "intent-" + str(next_broadcast_number)
	next_broadcast_number += 1
	broadcast.configure({
		"broadcast_id": broadcast_id,
		"squad_id": normalized_squad,
		"owner_id": owner_id,
		"owner_name": owner_name,
		"intent_type": normalized_type,
		"tags": tags,
		"target_id": target_id,
		"created_at": now_seconds,
		"expires_at": now_seconds + maxf(duration, 0.01),
		"metadata": metadata,
	})
	broadcasts[broadcast_id] = broadcast
	return {"broadcast": broadcast.to_dictionary(), "created": true}


static func get_coordination_context(
	squad_id: String,
	exclude_owner_id: int = 0,
	target_id: int = 0
) -> Dictionary:
	prune_expired()
	var normalized_squad: String = _normalize_squad(squad_id)
	var setup_reactions: Array[String] = []
	var payoff_reactions: Array[String] = []
	var lanes: Array[String] = []
	var reservation_rows: Array[Dictionary] = []
	for reservation_value: Variant in reservations.values():
		if not reservation_value is TacticalReservation:
			continue
		var reservation: TacticalReservation = (
			reservation_value as TacticalReservation
		)
		if reservation.squad_id != normalized_squad:
			continue
		if exclude_owner_id != 0 and reservation.owner_id == exclude_owner_id:
			continue
		if target_id != 0 and reservation.target_id not in [0, target_id]:
			continue
		reservation_rows.append(reservation.to_dictionary())
		match reservation.reservation_kind:
			"setup":
				_append_unique(setup_reactions, reservation.reaction_id)
			"payoff":
				_append_unique(payoff_reactions, reservation.reaction_id)
			"lane":
				_append_unique(lanes, reservation.reservation_key)
	var intent_tags: Array[String] = []
	var intent_rows: Array[Dictionary] = []
	for broadcast_value: Variant in broadcasts.values():
		if not broadcast_value is TacticalIntentBroadcast:
			continue
		var broadcast: TacticalIntentBroadcast = (
			broadcast_value as TacticalIntentBroadcast
		)
		if broadcast.squad_id != normalized_squad:
			continue
		if exclude_owner_id != 0 and broadcast.owner_id == exclude_owner_id:
			continue
		if target_id != 0 and broadcast.target_id not in [0, target_id]:
			continue
		intent_rows.append(broadcast.to_dictionary())
		for tag: String in broadcast.tags:
			_append_unique(intent_tags, tag)
	return {
		"claimed_reactions": payoff_reactions.duplicate(),
		"claimed_setup_reactions": setup_reactions,
		"claimed_payoff_reactions": payoff_reactions,
		"occupied_engagement_lanes": lanes,
		"squad_intent_tags": intent_tags,
		"coordination_reservations": reservation_rows,
		"coordination_intents": intent_rows,
		"coordination_plans": build_squad_plans(
			normalized_squad,
			target_id
		),
	}


static func build_squad_plans(
	squad_id: String,
	target_id: int = 0
) -> Array[Dictionary]:
	prune_expired()
	var normalized_squad: String = _normalize_squad(squad_id)
	var plans: Dictionary = {}
	for reservation_value: Variant in reservations.values():
		if not reservation_value is TacticalReservation:
			continue
		var reservation: TacticalReservation = (
			reservation_value as TacticalReservation
		)
		if reservation.squad_id != normalized_squad:
			continue
		if reservation.reservation_kind not in ["setup", "payoff"]:
			continue
		if target_id != 0 and reservation.target_id not in [0, target_id]:
			continue
		if not plans.has(reservation.plan_id):
			var plan: SquadPlan = SquadPlanScript.new()
			plans[reservation.plan_id] = plan
		var stored_plan: SquadPlan = plans[reservation.plan_id] as SquadPlan
		stored_plan.absorb_reservation(reservation)
	var rows: Array[Dictionary] = []
	for plan_value: Variant in plans.values():
		if plan_value is SquadPlan:
			rows.append((plan_value as SquadPlan).to_dictionary())
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("plan_id", "")) < str(b.get("plan_id", ""))
	)
	return rows


static func release_owner(
	owner_id: int,
	reason: String = "owner released",
	squad_id: String = ""
) -> int:
	return release_owner_kinds(
		owner_id,
		["setup", "payoff", "lane", "emergency"],
		reason,
		squad_id
	)


static func release_owner_kinds(
	owner_id: int,
	kinds: Array[String],
	reason: String,
	squad_id: String = ""
) -> int:
	var released: int = 0
	var normalized_squad: String = (
		_normalize_squad(squad_id) if squad_id.strip_edges() != "" else ""
	)
	var normalized_kinds: Array[String] = _string_array(kinds)
	for reservation_id: Variant in reservations.keys():
		var value: Variant = reservations.get(reservation_id)
		if not value is TacticalReservation:
			continue
		var reservation: TacticalReservation = value as TacticalReservation
		if reservation.owner_id != owner_id:
			continue
		if normalized_squad != "" and reservation.squad_id != normalized_squad:
			continue
		if not normalized_kinds.has(reservation.reservation_kind):
			continue
		_release_reservation(str(reservation_id), reason)
		released += 1
	for broadcast_id: Variant in broadcasts.keys():
		var broadcast_value: Variant = broadcasts.get(broadcast_id)
		if not broadcast_value is TacticalIntentBroadcast:
			continue
		var broadcast: TacticalIntentBroadcast = (
			broadcast_value as TacticalIntentBroadcast
		)
		if broadcast.owner_id != owner_id:
			continue
		if normalized_squad != "" and broadcast.squad_id != normalized_squad:
			continue
		broadcasts.erase(broadcast_id)
	return released


static func release_reservation(
	reservation_id: String,
	reason: String = "released"
) -> bool:
	if not reservations.has(reservation_id):
		return false
	_release_reservation(reservation_id, reason)
	return true


static func prune_expired(now_seconds: float = -1.0) -> int:
	var now_value: float = now_seconds if now_seconds >= 0.0 else _now_seconds()
	var expired_ids: Array[String] = []
	for reservation_id: Variant in reservations.keys():
		var value: Variant = reservations.get(reservation_id)
		if value is TacticalReservation and (
			value as TacticalReservation
		).is_expired(now_value):
			expired_ids.append(str(reservation_id))
	for reservation_id: String in expired_ids:
		_release_reservation(reservation_id, "expired")
	var expired_broadcasts: Array[String] = []
	for broadcast_id: Variant in broadcasts.keys():
		var broadcast_value: Variant = broadcasts.get(broadcast_id)
		if broadcast_value is TacticalIntentBroadcast and (
			broadcast_value as TacticalIntentBroadcast
		).is_expired(now_value):
			expired_broadcasts.append(str(broadcast_id))
	for broadcast_id: String in expired_broadcasts:
		broadcasts.erase(broadcast_id)
	return expired_ids.size() + expired_broadcasts.size()


static func clear_all() -> void:
	reservations.clear()
	broadcasts.clear()
	release_history.clear()
	next_reservation_number = 1
	next_broadcast_number = 1


static func get_debug_data() -> Dictionary:
	prune_expired()
	var rows: Array[Dictionary] = []
	for value: Variant in reservations.values():
		if value is TacticalReservation:
			rows.append((value as TacticalReservation).to_dictionary())
	return {
		"reservation_count": rows.size(),
		"broadcast_count": broadcasts.size(),
		"reservations": rows,
		"release_history": release_history.duplicate(true),
	}


static func _reserve(data: Dictionary) -> Dictionary:
	prune_expired()
	var squad_id: String = _normalize_squad(str(data.get("squad_id", "squad")))
	var owner_id: int = int(data.get("owner_id", 0))
	var kind: String = str(data.get("reservation_kind", "payoff"))
	var key: String = str(data.get("reservation_key", ""))
	var exclusive: bool = bool(data.get("exclusive", true))
	var now_seconds: float = _now_seconds()
	var duration: float = maxf(float(data.get("duration", 0.8)), 0.01)
	var priority: float = float(data.get("priority", 0.0))
	for reservation_value: Variant in reservations.values():
		if not reservation_value is TacticalReservation:
			continue
		var reservation: TacticalReservation = (
			reservation_value as TacticalReservation
		)
		if not reservation.matches_slot(squad_id, kind, key):
			continue
		if reservation.owner_id == owner_id:
			reservation.refresh(now_seconds, duration, priority)
			return {
				"granted": true,
				"refreshed": true,
				"reservation": reservation.to_dictionary(),
			}
		if exclusive or reservation.exclusive:
			return {
				"granted": false,
				"refreshed": false,
				"reason": "Reservation slot is held by " + reservation.owner_name,
				"conflict": reservation.to_dictionary(),
			}
	var reservation: TacticalReservation = ReservationScript.new()
	var reservation_id: String = "reservation-" + str(next_reservation_number)
	next_reservation_number += 1
	data["reservation_id"] = reservation_id
	data["squad_id"] = squad_id
	data["created_at"] = now_seconds
	data["expires_at"] = now_seconds + duration
	reservation.configure(data)
	reservations[reservation_id] = reservation
	return {
		"granted": true,
		"refreshed": false,
		"reservation": reservation.to_dictionary(),
	}


static func _find_broadcast(
	squad_id: String,
	owner_id: int,
	intent_type: String
) -> TacticalIntentBroadcast:
	for value: Variant in broadcasts.values():
		if not value is TacticalIntentBroadcast:
			continue
		var broadcast: TacticalIntentBroadcast = value as TacticalIntentBroadcast
		if (
			broadcast.squad_id == squad_id
			and broadcast.owner_id == owner_id
			and broadcast.intent_type == intent_type
		):
			return broadcast
	return null


static func _release_reservation(reservation_id: String, reason: String) -> void:
	var value: Variant = reservations.get(reservation_id)
	if value is TacticalReservation:
		var reservation: TacticalReservation = value as TacticalReservation
		reservation.release(reason)
		release_history.append(reservation.to_dictionary())
		if release_history.size() > 24:
			release_history.pop_front()
	reservations.erase(reservation_id)


static func _denied(reason: String) -> Dictionary:
	return {
		"granted": false,
		"refreshed": false,
		"reason": reason,
	}


static func _normalize_squad(value: String) -> String:
	var normalized: String = value.strip_edges().to_lower()
	return normalized if normalized != "" else "default_squad"


static func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			_append_unique(result, str(raw))
	return result


static func _append_unique(target: Array[String], value: String) -> void:
	var normalized: String = value.strip_edges().to_lower()
	if normalized == "" or target.has(normalized):
		return
	target.append(normalized)
