class_name ScoreEngine
extends RefCounted

static func score(values: Array, bonuses: Dictionary = {}) -> Dictionary:
	var wild_indices:Array=bonuses.get("wild_indices",[])
	if not wild_indices.is_empty():
		var original:Array=[]
		for raw in values:original.append(clampi(int(raw),1,6))
		var variants:Array=[original.duplicate()]
		for raw_index in wild_indices:
			var index:=int(raw_index)
			if index<0 or index>=original.size():continue
			var expanded:Array=[]
			for variant in variants:
				for face in range(1,7):var copy:Array=variant.duplicate();copy[index]=face;expanded.append(copy)
			variants=expanded
		var plain_bonuses:=bonuses.duplicate(true);plain_bonuses.erase("wild_indices")
		var best:Dictionary={}
		for variant in variants:
			var candidate:=_score_plain(variant,plain_bonuses)
			if best.is_empty() or int(candidate.multiplier)>int(best.multiplier) or (int(candidate.multiplier)==int(best.multiplier) and int(candidate.used_dice)>int(best.used_dice)):best=candidate
		var original_base:=0
		for value in original:original_base+=value
		original_base+=int(bonuses.get("chips",0))
		var face_chips:Dictionary=bonuses.get("face_chips",{})
		for value in original:original_base+=int(face_chips.get(value,0))
		best.base=original_base;best.score=original_base*int(best.multiplier)*int(best.final_factor);best.wild_indices=wild_indices.duplicate()
		return best
	return _score_plain(values,bonuses)

static func _score_plain(values:Array,bonuses:Dictionary)->Dictionary:
	var clean: Array[int] = []
	for raw in values: clean.append(clampi(int(raw),1,6))
	var base:=0
	for value in clean:base+=value
	base+=int(bonuses.get("chips",0))
	var face_chips:Dictionary=bonuses.get("face_chips",{})
	for value in clean:base+=int(face_chips.get(value,0))
	var counts:Array[int]=[0,0,0,0,0,0]
	for value in clean:counts[value-1]+=1
	var memo:Dictionary={}
	var best:=_solve(counts,0,bonuses,memo)
	var multiplier:=1+int(bonuses.get("mult",0))+int(best.gain)
	var required:=int(bonuses.get("variety_required",99))
	var distinct:=0
	for count in counts:if count>0:distinct+=1
	if distinct>=required:multiplier+=int(bonuses.get("variety_bonus",0))
	var final_factor:=maxi(1,int(bonuses.get("final_mult",1)))
	return {"base":base,"multiplier":maxi(1,multiplier),"final_factor":final_factor,"score":base*maxi(1,multiplier)*final_factor,"patterns":best.patterns,"used_dice":best.used}

static func _solve(counts:Array[int],type_mask:int,bonuses:Dictionary,memo:Dictionary)->Dictionary:
	var key:="%s|%d"%[counts,type_mask]
	if memo.has(key):return (memo[key] as Dictionary).duplicate(true)
	var face:=-1
	for i in range(6):
		if counts[i]>0:face=i;break
	if face<0:return {"gain":0,"used":0,"patterns":[]}
	# A die may remain outside every pattern.
	var skipped:=counts.duplicate();skipped[face]-=1
	var best:Dictionary=_solve(skipped,type_mask,bonuses,memo)
	# Same-face groups. Trying every size permits four-of-a-kind versus two pairs.
	for size in range(2,counts[face]+1):
		var next:=counts.duplicate();next[face]-=size
		var gain:=size*(size-1)/2
		if size==2:gain+=int(bonuses.get("pair_bonus",0))
		if size==3:gain+=int(bonuses.get("triple_bonus",0))
		var type_extra:=int(bonuses.get("type_bonus",0)) if (type_mask&1)==0 else 0
		var tail:=_solve(next,type_mask|1,bonuses,memo)
		var candidate:={"gain":gain+type_extra+int(tail.gain),"used":size+int(tail.used),"patterns":[{"type":"same","name":_same_name(size),"face":face+1,"length":size,"mult":gain}]+tail.patterns}
		best=_better(best,candidate)
	# Every straight containing the first remaining face is a legal use of that die.
	for start in range(6):
		for length in range(3,7-start):
			if face<start or face>=start+length:continue
			var legal:=true
			for p in range(start,start+length):if counts[p]<=0:legal=false
			if not legal:continue
			var next:=counts.duplicate();var faces:Array[int]=[]
			for p in range(start,start+length):next[p]-=1;faces.append(p+1)
			var gain:=1+(length-2)*(length-1)/2
			if length==3:gain+=int(bonuses.get("straight3_bonus",0))+int(bonuses.get("triple_bonus",0))
			var type_extra:=int(bonuses.get("type_bonus",0)) if (type_mask&2)==0 else 0
			var tail:=_solve(next,type_mask|2,bonuses,memo)
			var candidate:={"gain":gain+type_extra+int(tail.gain),"used":length+int(tail.used),"patterns":[{"type":"straight","name":"%d连顺"%length,"faces":faces,"length":length,"mult":gain}]+tail.patterns}
			best=_better(best,candidate)
	memo[key]=best.duplicate(true)
	return best

static func _better(left:Dictionary,right:Dictionary)->Dictionary:
	if int(right.gain)>int(left.gain):return right
	if int(right.gain)==int(left.gain) and int(right.used)>int(left.used):return right
	return left

static func _same_name(count:int)->String:
	return {2:"对子",3:"三条",4:"四条",5:"五条",6:"六条"}.get(count,"%d条"%count)
