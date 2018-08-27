"use strict";

//const fs = require("fs");

$(document).ready(function() {
	var hh_patterns = [
		"hh.location",
		"hh.rid"
	];
	var food_patterns = [
		"food.name",
		"food.food_group_type_lv"
	];
	var nutri_patterns = [
		"nutri.name"
	];
	var exp_patterns = [
		"purtype.name",
		"pur.purchase_type_type_lv",
		"exp.total_amount"
	];
	var src_patterns = [
		"src.name",
		"src.source_type_type_lv"
	];
	var cns_patterns = [
		"cns.no_of_consumption"
	];
	var filepath = './preset.dat';

	$('#copy').click(function() {
		$("#statement").select();
		document.execCommand('copy');
	});
	$('#load_as_preset').click(function() {
		fs.readFile(filepath, 'utf-8', (err, data) => {
			if(err){ alert("An error ocurred reading the file :" + err.message); return; }
			load_button(data);
		});
	});
	$('#delete_preset').click(function() {
		var sel_text = $('#preset :selected').text();
		var content;
		var new_content = "";
		var res;
		if (!sel_text) { return false; }
		sel_text=sel_text.trim();
		$("#preset option[value='PRESET_" + sel_text + "']").remove();
		content = fs.readFileSync(filepath, 'utf-8');
		res = content.replace(/\r\n/g, "\n").split("\n");
		res.forEach(function(entry) {
			if (entry.trim()!="") {
				var array = entry.split('\t');
				if (array[0].trim() != sel_text.trim()) {
					new_content += entry + "\n";
				}
			}
		});
		fs.writeFileSync(filepath, new_content);
		changestatement();
	});
	$('#save_as_preset').click(function() {
		var content;
		var is_duplicated=false;
		var preset_name = $('#preset_name').val();
		if (!preset_name) {
			return;
		}
		preset_name = preset_name.trim();
		content =
		preset_name + "\t" +
		$('#household').val() + "\t" +
		$('#household_rid').val() + "\t" +
		($("#radio_food").is(":checked")?"true":"false") + "\t" +
		$('#foodgroup').val() + "\t" +
		$('#nutritiongroup').val() + "\t" +
		$('#type').val() + "\t" +
		$('#source').val() + "\t" +
		$('#purchase').val() + "\t" +
		$('#column').val() + "\t" +
		$('#hhord').val() + "\t" +
		$('#conexpord').val() + "\n";
		//$('#statement').val() + "\n";
		$('#preset > option').each(function(i, sel){
			var sel_text = $(sel).text().trim();
			if (sel_text == preset_name) {
				is_duplicated=true;
				alert('Preset duplicate: ' + sel_text);
				return false;
			}
		});
		if (is_duplicated) {
			return false;
		}
		fs.appendFile(filepath, content, function (err) {
			if (err) {
				//response.send("failed to save");
			} else {
				var newOption = $('<option value="' + "PRESET_" + preset_name + '">' + preset_name + '</option>');
				if (preset_name) {
					$('#preset').append(newOption);
					$('#preset').val("PRESET_" + preset_name);
				}
			}
		});
	});

	fs.readFile(filepath, 'utf-8', (err, data) => {
		if(err){ alert("An error ocurred reading the file :" + err.message); return; }
		load_preset_list_from_file(data);
	});

	$('#reset').click(function() {
		$('#household').val('HH_All');
		$('#household_rid').val('');
		$('#radio_food').prop("checked", true);
		$('#foodgroup').val('Food_All');
		$('#nutritiongroup').val('Nutrition_All');
		$('#type').val('Type_Expended');
		$('#source').val('Source_All');
		$('#purchase').val('Purchase_All');
		$('#column').val('');
		$('#hhord').val('Ord_HHID_NOORD');
		$('#conexpord').val('Ord_CONEXP_NOORD');
		changestatement();
	});

	function set_id(id, objValue) {
		var re = new RegExp(/,/);
		if (id != "#statement" && re.exec(objValue)) {
			var array = objValue.split (/,/);
			$(id).val('');
			array.forEach(function(entry) {
				$(id + ' option[value=' + entry + ']').prop('selected', true);
			});
		} else {
			$(id).val(objValue);
		}
	}

	function load_button(data) {
		var sel_val = $('#preset').val();
		var res = data.replace(/\r\n/g, "\n").split("\n");
		if (sel_val == null ) { return false; }
		sel_val=sel_val.trim();
		res.forEach(function(entry) {
			if (entry.trim()!="") {
				var array = entry.split (/\t/);
				if ("PRESET_" + array[0] == sel_val) {
					set_id('#household',array[1]);
					set_id('#household_rid',array[2]);
					$('#radio_food').prop("checked", (array[3]=='true'?true:false));
					$('#radio_nutri').prop("checked", (array[3]=='true'?false:true));
					set_id('#foodgroup',array[4]);
					set_id('#nutritiongroup',array[5]);
					set_id('#type',array[6]);
					set_id('#source',array[7]);
					set_id('#purchase',array[8]);
					set_id('#column',array[9]);
					set_id('#hhord',array[10]);
					set_id('#conexpord',array[11]);
					set_id('#statement',array[12]);
					return false;
				}
			}
		});
		changestatement();
	}
	function load_preset_list_from_file(data) {
		var res = data.replace(/\r\n/g, "\n").split("\n");
		res.forEach(function(entry) {
			if (entry.trim()!="") {
				if (entry.trim().match(new RegExp("\t",""))) {
					var array = entry.split (/\t/);
					var preset_name = array[0];
					var newOption = $('<option value="' + "PRESET_" + preset_name + '">' + preset_name + '</option>');
					if (preset_name) {
						$('#preset').append(newOption);
					}
				}
			}
		});
	}

	function make_where(id, bef_val, sel_all) {
		var cnt=0;
		var ret_where;
		$(id + ' :selected').each(function(i, sel){
			var sel_val = $(sel).val().trim();
			var sel_text = $(sel).text().trim().replace(/(.+)_/g, "");
			bef_val += "=";
			if (sel_val == sel_all) {
				return false;
			}
			cnt++;

			if (id == "#foodgroup") {
				var lvl = (sel_val.match(new RegExp("_","g")) || []).length;
				bef_val = "food.food_group_type_lv" + lvl + "=";
			}
			if (id == "#source") {
				var lvl = (sel_val.match(new RegExp("_","g")) || []).length;
				if ($('#type').val().trim() == 'Type_Expended') {
					bef_val = "exp.src_lv" + lvl + "=";
				} else {
					bef_val = "cns.src_lv" + lvl + "=";
				}
			}
			if (id == "#purchase") {
				var lvl = (sel_val.match(new RegExp("_","g")) || []).length;
				bef_val = "exp.purchase_lv" + lvl + "=";
			}

			ret_where = (cnt == 1 ? bef_val : ret_where + " OR " + bef_val);
			ret_where += "'" + sel_text + "'";
		});
		if (ret_where) {
			ret_where = "(" + ret_where + ")";
			return ret_where;
		}
		return;
	}

	function return_where_st(where_st, added) {
		if (!added) {
			return where_st;
		}
		if (where_st == "WHERE ") {
			where_st += added;
		} else {
			where_st += " AND " + added;
		}
		return where_st;
	}

	function changestatement() {
		/* Statements */
		var statement;
		var match_st = 'MATCH ';
		var where_st = "WHERE ";
		var return_st = "RETURN ";
		var order_by_st = "ORDER BY ";
		// Statements: NODE
		var hh_st = "(hh:HOUSEHOLD {";
		var food_st = "(food:FOOD_GROUP)";
		var nutri_st = "(nutri:NUTRITION_GROUP {";
		// Statements: EDGE
		var cns_st = "-[cns:consumed]->"; // no_of_consumption
		var exp_st = "-[exp:expended]->";
		// Statements: WHERE
		var where_hh, where_food, where_nutri, where_src, where_purchase;
		// HTML elements
		var hh_rid = $('#household_rid').val().trim();
		// Etc
		var consumed_recall = 0;
		var return_started = false;
		var order_by_started = false;
		var hh_detected=false;
		var food_detected=false;
		var nutri_detected=false;
		var exp_detected=false;
		var src_detected=false;
		var cns_detected=false;
		var is_nonpurchased=false;

		// Verification
		if ($('#type').val().trim() == 'Type_Expended') {
			$('#purchase').prop('disabled',false);
		} else {
			$('#purchase').prop('disabled',true);
		}
		if ($("#radio_food").is(":checked")) {
			$('#foodgroup, #foodgroup_txt').show();
			$('#nutritiongroup, #nutritiongroup_txt').hide();
		} else {
			$('#foodgroup, #foodgroup_txt').hide();
			$('#nutritiongroup, #nutritiongroup_txt').show();
		}

		// HOUSEHOLD
		if (hh_rid != "") {
			hh_st += "rid: " + hh_rid;
		}
		hh_st += "})";
		where_hh = make_where('#household', "hh.location", "HH_All");
		where_st = return_where_st(where_st, where_hh);

		// FOOD_GROUP
		if ($("#radio_food").is(":checked")) {
			where_food = make_where('#foodgroup', null, "Food_All");
			where_st = return_where_st(where_st, where_food);
		// NUTRITION_GROUP
		} else {
			where_nutri = make_where('#nutritiongroup', "nutri.name", "Nutrition_All");
			where_st = return_where_st(where_st, where_nutri);
		}

		// TYPE
		if ($('#type').val().trim() == 'Type_Expended') {
			consumed_recall=0;
		} else if ($('#type').val().trim() == 'Type_Consumed_1d') {
			consumed_recall=1;
		} else if ($('#type').val().trim() == 'Type_Consumed_7d') {
			consumed_recall=7;
		}

		// SOURCE_TYPE
		where_src = make_where('#source', null, "Source_All");
		where_st = return_where_st(where_st, where_src);

		// PURCHASE_TYPE
		if (consumed_recall == 0) {
			where_purchase = make_where('#purchase', null, "Purchase_All");
			where_st = return_where_st(where_st, where_purchase);
		} else {
			where_st = return_where_st(where_st, "(cns.recall_period=" + consumed_recall + ")");
		}
		
		/* Preprocessing */


		// RETURN (COLUMNS)
		$("#column :selected").each(function(i, sel){
			var itm = $(sel).val().trim();
			if (itm == 'Col_Household') {
				return_st += "hh.location as HHLOC, hh.rid as HHRID"
				return_started = true;
			}
			if (itm == 'Col_ExpCon') {
				if (return_started) { return_st += ", "; }
				if (consumed_recall == 0) {
					return_st += "SUM(exp.total_amount) AS Expenditure";
				} else {
					return_st += "SUM(cns.no_of_consumption) AS Consumption";
				}
				return_started = true;
			}
			if (itm == 'Col_FoodNutrition') {
				if (return_started) { return_st += ", "; }
				if ($("#radio_food").is(":checked")) {
					return_st += "food.name as Food";
				} else {
					return_st += "nutri.name as Nutrition";
				}
				return_started = true;
			}
			if (itm == 'Col_SourceType') {
				if (return_started) { return_st += ", "; }
				return_st += "src.name as Source";
				return_started = true;
			}
			if (itm == 'Col_PurchaseType') {
				if (return_started) { return_st += ", "; }
				return_st += "purtype.name as Purchase";
				return_started = true;
			}
		});

		// ORDER BY
		if ($('#hhord').val().trim() == 'Ord_HHID_ASC') {
			if (order_by_started) { order_by_st += ", "; }
			order_by_st += "HHLOC ASC, HHRID ASC";
			order_by_started = true;
		}
		if ($('#hhord').val().trim() == 'Ord_HHID_DESC') {
			if (order_by_started) { order_by_st += ", "; }
			order_by_st += "HHLOC DESC, HHRID DESC";
			order_by_started = true;
		}
		if ($('#conexpord').val().trim() == 'Ord_CONEXP_ASC') {
			if (order_by_started) { order_by_st += ", "; }
			if (consumed_recall == 0) {
				order_by_st += "Expenditure ASC";
			} else {
				order_by_st += "Consumption ASC";
			}
			order_by_started = true;
		}
		if ($('#conexpord').val().trim() == 'Ord_CONEXP_DESC') {
			if (order_by_started) { order_by_st += ", "; }
			if (consumed_recall == 0) {
				order_by_st += "Expenditure DESC";
			} else {
				order_by_st += "Consumption DESC";
			}
			order_by_started = true;
		}
		// MATCH
		$(hh_patterns).each(function(i, item){
			if (where_st.includes(item) || return_st.includes(item)) {
				hh_detected=true;
				return false;
			}
		});
		$(food_patterns).each(function(i, item){
			if (where_st.includes(item) || return_st.includes(item)) {
				food_detected=true;
				return false;
			}
		});
		$(nutri_patterns).each(function(i, item){
			if (where_st.includes(item) || return_st.includes(item)) {
				nutri_detected=true;
				return false;
			}
		});
		$(exp_patterns).each(function(i, item){
			if (where_st.includes(item) || return_st.includes(item)) {
				exp_detected=true;
				return false;
			}
		});
		$(src_patterns).each(function(i, item){
			if (where_st.includes(item) || return_st.includes(item)) {
				src_detected=true;
				return false;
			}
		});
		$(cns_patterns).each(function(i, item){
			if (where_st.includes(item) || return_st.includes(item)) {
				cns_detected=true;
				return false;
			}
		});
		$('#source :selected').each(function(i, sel){
			var sel_text = $(sel).text().trim().replace(/^Source_/, "").replace(/_.+/,"");
			if (sel_text == "NonPurchased") {
				is_nonpurchased=true;
				return false;
			}
		});

		if ($('#type').val().trim() == 'Type_Expended') {
			match_st += hh_st + "-[exp:expended]->(food:FOOD_GROUP)";
		} else {
			match_st += hh_st + "-[cns:consumed]->(food:FOOD_GROUP)";
		}
		if (!$("#radio_food").is(":checked")) {
			var tmp = "-[:_has]->(nutri:NUTRITION_GROUP)";
			match_st += tmp;
		}

		// WHERE
		if (where_st == "WHERE ") {
			statement = match_st;
		} else {
			statement = match_st + " " + where_st;
		}

		statement += " " + return_st;
		if (order_by_st !== "ORDER BY ") {
			statement += " " + order_by_st;
		}
		statement += ";";

		$("#statement").val(statement);
		return;
	}
	
	$( ".abox, #radio_food, #radio_nutri" ).change(function() {
		changestatement();
	});
	changestatement();

});
