extends RefCounted
class_name LastBeaconState

const INITIAL_SCRAP := 12
const INITIAL_WORKERS := 1
const INITIAL_LEVEL := 1
const INITIAL_GATHER := 3
const INITIAL_POWER_CELLS := 0
const INITIAL_CORE_CHARGE := 0.0

var scrap: int = INITIAL_SCRAP
var workers: int = INITIAL_WORKERS
var level: int = INITIAL_LEVEL
var manual_gather_amount: int = INITIAL_GATHER
var power_cells: int = INITIAL_POWER_CELLS
var core_charge: float = INITIAL_CORE_CHARGE
var total_ticks: int = 0


func tick(delta_seconds: float) -> void:
	var safe_delta: float = max(delta_seconds, 0.0)
	core_charge = min(core_charge + safe_delta * _charge_rate_per_second(), 100.0)
	scrap += int(floor(_passive_scrap_per_second() * safe_delta))
	total_ticks += int(floor(safe_delta))
	if core_charge >= 100.0:
		core_charge = 0.0
		power_cells += 1
		scrap += level * 4


func gather() -> void:
	scrap += manual_gather_amount


func hire_worker() -> bool:
	var cost: int = worker_cost()
	if scrap < cost:
		return false

	scrap -= cost
	workers += 1
	return true


func upgrade_core() -> bool:
	var cost: int = core_upgrade_cost()
	if scrap < cost:
		return false

	scrap -= cost
	level += 1
	manual_gather_amount += 2
	return true


func worker_cost() -> int:
	return 10 + ((workers - INITIAL_WORKERS) * 6)


func core_upgrade_cost() -> int:
	return 18 + ((level - INITIAL_LEVEL) * 12)


func passive_scrap_per_second() -> float:
	return _passive_scrap_per_second()


func charge_rate_per_second() -> float:
	return _charge_rate_per_second()


func to_save_state() -> Dictionary:
	return {
		"scrap": scrap,
		"workers": workers,
		"level": level,
		"manualGatherAmount": manual_gather_amount,
		"powerCells": power_cells,
		"coreCharge": core_charge,
		"totalTicks": total_ticks,
	}


func from_save_state(payload: Dictionary) -> bool:
	if typeof(payload.get("scrap", null)) != TYPE_INT:
		return false
	if typeof(payload.get("workers", null)) != TYPE_INT:
		return false
	if typeof(payload.get("level", null)) != TYPE_INT:
		return false
	if typeof(payload.get("manualGatherAmount", null)) != TYPE_INT:
		return false
	if not payload.has("coreCharge"):
		return false

	scrap = max(int(payload["scrap"]), 0)
	workers = max(int(payload["workers"]), 1)
	level = max(int(payload["level"]), 1)
	manual_gather_amount = max(int(payload["manualGatherAmount"]), 1)
	power_cells = max(int(payload.get("powerCells", 0)), 0)
	core_charge = clamp(float(payload["coreCharge"]), 0.0, 100.0)
	total_ticks = max(int(payload.get("totalTicks", 0)), 0)
	return true


func _passive_scrap_per_second() -> float:
	return float(workers) * (1.0 + float(level - 1) * 0.35)


func _charge_rate_per_second() -> float:
	return 4.0 + float(workers) * 0.35 + float(level - 1) * 0.55
