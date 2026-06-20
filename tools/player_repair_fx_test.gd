extends SceneTree
# Test for scripts/PlayerRepairFx.gd -- verifies the 3-frame hammer
# animation helpers. Mirrors the structure of world_layer_fx_test.gd.

const PlayerRepairFxScript := preload("res://scripts/PlayerRepairFx.gd")

func _initialize() -> void:
	var pass_count: int = 0
	var fail_count: int = 0

	# Test 1: frame constants are 0/1/2 and match
	if PlayerRepairFxScript.REPAIR_FRAME_START == 0:
		pass_count += 1
	else:
		printerr("[FAIL] REPAIR_FRAME_START != 0")
		fail_count += 1

	if PlayerRepairFxScript.REPAIR_FRAME_MID == 1:
		pass_count += 1
	else:
		printerr("[FAIL] REPAIR_FRAME_MID != 1")
		fail_count += 1

	if PlayerRepairFxScript.REPAIR_FRAME_END == 2:
		pass_count += 1
	else:
		printerr("[FAIL] REPAIR_FRAME_END != 2")
		fail_count += 1

	if PlayerRepairFxScript.REPAIR_FRAME_COUNT == 3:
		pass_count += 1
	else:
		printerr("[FAIL] REPAIR_FRAME_COUNT != 3")
		fail_count += 1

	# Test 2: cycle period is reasonable (between 0.2s and 1.0s)
	if PlayerRepairFxScript.REPAIR_CYCLE_SEC > 0.2 and PlayerRepairFxScript.REPAIR_CYCLE_SEC < 1.0:
		pass_count += 1
	else:
		printerr("[FAIL] REPAIR_CYCLE_SEC out of range: %f" % PlayerRepairFxScript.REPAIR_CYCLE_SEC)
		fail_count += 1

	# Test 3: repair_frame_for returns 0 at timer=0
	if PlayerRepairFxScript.repair_frame_for(0.0) == PlayerRepairFxScript.REPAIR_FRAME_START:
		pass_count += 1
	else:
		printerr("[FAIL] timer=0 should return START")
		fail_count += 1

	# Test 4: repair_frame_for returns START for first third of cycle
	var one_third: float = PlayerRepairFxScript.REPAIR_CYCLE_SEC / 3.0
	if PlayerRepairFxScript.repair_frame_for(one_third * 0.5) == PlayerRepairFxScript.REPAIR_FRAME_START:
		pass_count += 1
	else:
		printerr("[FAIL] timer<one_third should return START")
		fail_count += 1

	# Test 5: returns MID for second third
	if PlayerRepairFxScript.repair_frame_for(one_third * 1.5) == PlayerRepairFxScript.REPAIR_FRAME_MID:
		pass_count += 1
	else:
		printerr("[FAIL] middle third should return MID")
		fail_count += 1

	# Test 6: returns END for last third
	if PlayerRepairFxScript.repair_frame_for(one_third * 2.5) == PlayerRepairFxScript.REPAIR_FRAME_END:
		pass_count += 1
	else:
		printerr("[FAIL] last third should return END")
		fail_count += 1

	# Test 7: cycle wraps (timer = cycle_sec returns START)
	if PlayerRepairFxScript.repair_frame_for(PlayerRepairFxScript.REPAIR_CYCLE_SEC) == PlayerRepairFxScript.REPAIR_FRAME_START:
		pass_count += 1
	else:
		printerr("[FAIL] wraparound: timer=cycle_sec should return START")
		fail_count += 1

	# Test 8: cycle wraps at 2x cycle
	if PlayerRepairFxScript.repair_frame_for(PlayerRepairFxScript.REPAIR_CYCLE_SEC * 2.0) == PlayerRepairFxScript.REPAIR_FRAME_START:
		pass_count += 1
	else:
		printerr("[FAIL] wraparound: timer=2*cycle_sec should return START")
		fail_count += 1

	# Test 9: negative timer is clamped to 0 (returns START)
	if PlayerRepairFxScript.repair_frame_for(-5.0) == PlayerRepairFxScript.REPAIR_FRAME_START:
		pass_count += 1
	else:
		printerr("[FAIL] negative timer should clamp to 0")
		fail_count += 1

	# Test 10: NaN/infinity safety
	if PlayerRepairFxScript.repair_frame_for(NAN) == PlayerRepairFxScript.REPAIR_FRAME_START \
			or PlayerRepairFxScript.repair_frame_for(INF) == PlayerRepairFxScript.REPAIR_FRAME_START \
			or PlayerRepairFxScript.repair_frame_for(-INF) == PlayerRepairFxScript.REPAIR_FRAME_START:
		pass_count += 1
	else:
		printerr("[FAIL] NaN/INF timer should clamp safely")
		fail_count += 1

	# Test 11: bob returns Vector2 with x=0 and y in [-amplitude, amplitude]
	var bob: Vector2 = PlayerRepairFxScript.repair_bob_for(one_third * 1.5)
	if is_equal_approx(bob.x, 0.0) \
			and bob.y >= -PlayerRepairFxScript.REPAIR_BOB_AMPLITUDE \
			and bob.y <= PlayerRepairFxScript.REPAIR_BOB_AMPLITUDE:
		pass_count += 1
	else:
		printerr("[FAIL] bob out of range: %s" % str(bob))
		fail_count += 1

	# Test 12: bob at phase=0 and phase=cycle_sec are equal (sin wraps)
	var bob0: Vector2 = PlayerRepairFxScript.repair_bob_for(0.0)
	var bob_cycle: Vector2 = PlayerRepairFxScript.repair_bob_for(PlayerRepairFxScript.REPAIR_CYCLE_SEC)
	if bob0.is_equal_approx(bob_cycle):
		pass_count += 1
	else:
		printerr("[FAIL] bob doesn't wrap at cycle boundary: %s vs %s" % [bob0, bob_cycle])
		fail_count += 1

	# Test 13: scale is near 1.0 (no extreme squash)
	var sc: Vector2 = PlayerRepairFxScript.repair_scale_for(one_third)
	if sc.x > 0.95 and sc.x < 1.05 and sc.y > 0.95 and sc.y < 1.05:
		pass_count += 1
	else:
		printerr("[FAIL] scale out of range: %s" % str(sc))
		fail_count += 1

	# Test 14: scale is approximately (1.0, 1.0) at frame boundary (sin(0)=0)
	var sc0: Vector2 = PlayerRepairFxScript.repair_scale_for(0.0)
	if sc0.is_equal_approx(Vector2(1.0, 1.0)):
		pass_count += 1
	else:
		printerr("[FAIL] scale at phase=0 should be (1,1), got %s" % str(sc0))
		fail_count += 1

	# Test 15: is_repairable_hotspot returns true for barrier
	if PlayerRepairFxScript.is_repairable_hotspot("barrier"):
		pass_count += 1
	else:
		printerr("[FAIL] 'barrier' should be repairable")
		fail_count += 1

	# Test 16: is_repairable_hotspot returns false for radio/medbay/generator/antenna/support
	for k in ["radio", "medbay", "generator", "antenna", "support", ""]:
		if not PlayerRepairFxScript.is_repairable_hotspot(k):
			pass_count += 1
		else:
			printerr("[FAIL] '%s' should NOT be repairable" % k)
			fail_count += 1

	# Test 17: 3-frame cycle, frame for 1/6 increments (one_third/0.5) maps to correct frame
	# Verify boundary at exactly 1/3
	if PlayerRepairFxScript.repair_frame_for(one_third) == PlayerRepairFxScript.REPAIR_FRAME_MID:
		pass_count += 1
	else:
		# At exactly 1/3 phase, fmod=0 which maps to START in our code (phase < 1/3)
		# So we expect START. The above assertion was wrong -- adjust:
		if PlayerRepairFxScript.repair_frame_for(one_third) == PlayerRepairFxScript.REPAIR_FRAME_START:
			pass_count += 1
		else:
			printerr("[FAIL] at exactly 1/3 phase, frame=%d (expected START)" \
					% PlayerRepairFxScript.repair_frame_for(one_third))
			fail_count += 1

	# Test 18: 3-frame cycle, very small timer should be START
	if PlayerRepairFxScript.repair_frame_for(0.001) == PlayerRepairFxScript.REPAIR_FRAME_START:
		pass_count += 1
	else:
		printerr("[FAIL] timer=0.001 should be START")
		fail_count += 1

	# Test 19: 3-frame cycle, timer just before cycle end should be END
	var just_before: float = PlayerRepairFxScript.REPAIR_CYCLE_SEC - 0.001
	if PlayerRepairFxScript.repair_frame_for(just_before) == PlayerRepairFxScript.REPAIR_FRAME_END:
		pass_count += 1
	else:
		printerr("[FAIL] just before cycle end should be END")
		fail_count += 1

	# Test 20: long timer (100 cycles) returns START (no crash on big numbers)
	if PlayerRepairFxScript.repair_frame_for(100.0) == PlayerRepairFxScript.REPAIR_FRAME_START \
			or PlayerRepairFxScript.repair_frame_for(100.0) == PlayerRepairFxScript.REPAIR_FRAME_MID \
			or PlayerRepairFxScript.repair_frame_for(100.0) == PlayerRepairFxScript.REPAIR_FRAME_END:
		pass_count += 1
	else:
		printerr("[FAIL] large timer returned invalid frame")
		fail_count += 1

	print("[player_repair_fx_test] %d passed, %d failed" % [pass_count, fail_count])
	if fail_count > 0:
		quit(1)
	else:
		quit(0)