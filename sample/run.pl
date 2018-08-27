#!/usr/bin/perl
use strict;
use File::Basename;
use feature qw/switch/;
no warnings;
use utf8;

my ($statement, $graph_path, $init_done, $commit_period, $line_cnt_for_commit, $_fin) = (undef, 'UN_GRAPH', 0, 0, 0, 1);
my ($clean_graph, $save_to_path, $show, $use_buffer, $limit_per_csv, $limit_per_household) = (0, undef, 0, 0, 0, 0);
my (@src_types, @purchase_types);
my ($use_consumed_index, $use_expended_index)=(0) x 2;
my $vaccum_analyze=0;
my $config_file="config.ini";
my @files;

sub _slurp {
	my ($filename, $contents) = (shift, undef);
	open my $in, '<:utf8', $filename or die(0);
	local $/; $contents = <$in>;
	close($in);
	return $contents;
}

sub _append_to_file {
	my ($output, $filename) = @_;
	open my $fh, ">>", $filename or die(0);
	print $fh $output;
	close $fh;
}

sub _strip_spc {
	my $msg = shift;
	$msg =~ s/^\s*//;
	$msg =~ s/\s*$//;
	return $msg;
}

sub _out {
	my $msg = shift;
	if ($use_buffer eq 0) {
		print $msg if ($show eq 1);
		_append_to_file($msg, $save_to_path) if ($save_to_path);
	} else {
		$statement .= $msg;
	}
	return $msg;
}

sub _uniq {
	my %seen;
	grep !$seen{$_}++, @_;
}

sub _end_buffer {
	print $statement if ($show eq 1);
	_append_to_file($statement, $save_to_path) if ($save_to_path);
}

sub _DO { $_fin=1; }
sub _BEGIN { _out("BEGIN;\n") if ($init_done eq 1 && $commit_period ne 0); }
sub _END { _out("COMMIT;\n") if ($init_done eq 1 && $commit_period ne 0); }
sub _ADD { _out(($_fin eq 1 ? shift : " " . shift)); $_fin=0; }
sub _FIN {
	$line_cnt_for_commit++ if ($init_done eq 1);
	_out(";\n");
	if ($init_done eq 1 && $line_cnt_for_commit eq $commit_period) {
		_out("COMMIT;\nBEGIN;\n");
		$line_cnt_for_commit=0;
	}
	$_fin=1;
}

sub _create_edge_tree {
	my $data = shift;
	my $result;
	foreach my $line (split /\n/, $data) {
		my ($edge_name, $trailing);
		my ($tr1, $tr2, $tr1_grp, $tr2_grp, $tr1_name, $tr2_name, $lv);
		next unless ($line =~ /,/);
		($edge_name, $trailing) = (split /,/, $line);
		($tr1, $tr2) = (split /:/, $trailing);
		($tr1_grp, $tr1_name) = (split /\|/, $tr1);
		($tr2_grp, $tr2_name) = (split /\|/, $tr2);
		if ($tr1_name =~ /^(lv\d+)/) {
			$lv = $1;
			$tr1_name=~s/^\Q$lv\E//;
		}
		$result .= "MATCH (n:$tr1_grp { FOOD_GROUP_Type_$lv: '$tr1_name' }) ";
		$result .= "MATCH (r:$tr2_grp { name: '$tr2_name' }) ";
		$result .= "CREATE (n)-[:$edge_name]->(r);\n";
	}
	return $result;
}

sub _create_vertex_tree {
	my $data = shift;
	my $result;
	my @lvl_str;
	# process
	foreach my $line (split /\n/, $data) {
		my ($current_lvl, $current_name);
		if ($line !~ /^\s*(\*|vertex_label\d+)/) { next; }
		if ($line =~ /^\s*vertex_label\d+\s*=\s*(.+)$/) {
			my $vertex_label = $1;
			$result .= "CREATE VLABEL $vertex_label;\n";
		}

		if ($line =~ /^\s*(\*+) +(.+)$/) {
			$current_lvl = length($1) - 1;
			$current_name = _strip_spc($2);
			$current_name =~ s/^L //;
		} else {
			next;
		}

		$lvl_str[$current_lvl] = $current_name;

		# LEVEL 0
		if ($current_lvl eq 0) {
			next;
		}

		# LEVEL Non-zero
		$result .= "CREATE (:$lvl_str[0] {";
		$result .= "name: '$current_name', ";
		foreach my $lvl (1 ... $current_lvl) {
			$result .= $lvl_str[0] . "_Type_lv$lvl: '" . $lvl_str[$lvl] . "', ";
		}
		$result =~ s/, $//;
		$result .= "});\n";
	}
	return $result;
}

sub _init {
	my $data = _slurp($config_file);
	my ($vertex_tree, $create_vertex_statement);
	my ($edge_tree, $create_edge_statement);
	foreach my $line (split /\n/, $data) {
		if ($line =~ /^\s*csv\d+\s*=\s*(.+)/i) {
			my $file = _strip_spc($1);
			unless ( -f $file ) {
				print "File not found: $file\n";
				exit 1;
			}
			push @files, $file;
		}
		if ($line =~ /^\s*clean_graph\s*=\s*(.+)/i) {
			$clean_graph = _strip_spc($1);
			$clean_graph = ($clean_graph =~ /^true$/i ? 1 : 0 );
			next;
		}
		if ($line =~ /^\s*graph_path\s*=\s*(.+)/i) {
			$graph_path = _strip_spc($1);
			next;
		}
		if ($line =~ /^\s*commit_period\s*=\s*(.+)/i) {
			$commit_period = _strip_spc($1);
			unless ($commit_period =~ /^\d+$/) {
				print "commit_period must be set to a number\n";
				exit 1;
			}
			next;
		}
		if ($line =~ /^\s*save_to_path\s*=\s*(.+)/i) {
			$save_to_path = _strip_spc($1);
			$save_to_path =~ s/\s*$//;
			next;
		}
		if ($line =~ /^\s*show\s*=\s*(.+)/i) {
			$show = _strip_spc($1);
			$show = ($show =~ /^true$/i ? 1 : 0 );
			next;
		}
		if ($line =~ /^\s*use_buffer\s*=\s*(.+)/i) {
			$use_buffer = _strip_spc($1);
			$use_buffer = ($use_buffer =~ /^true$/i ? 1 : 0 );
			next;
		}
		if ($line =~ /^\s*(\*|vertex_label\d+)/) {
			$vertex_tree .= $line . "\n";
			next;
		}
		if ($line =~ /^\s*edge_label\d+\s*=\s*(.+)$/) {
			$edge_tree .= $1 . "\n";
			next;
		}
		if ($line =~ /^\s*limit_per_csv\s*=\s*(.+)$/) {
			$limit_per_csv = _strip_spc($1);
			next;
		}
		if ($line =~ /^\s*limit_per_household\s*=\s*(.+)$/) {
			$limit_per_household = _strip_spc($1);
			next;
		}
		if ($line =~ /^\s*vaccum_analyze\s*=\s*true\s*$/) {
			$vaccum_analyze = 1;
			next;
		}
		if ($line =~ /^\s*type_source_type\d+\s*=\s*(.+)$/) {
			push @src_types, _strip_spc($1);
			next;
		}
		if ($line =~ /^\s*type_purchase_type\d+\s*=\s*(.+)$/) {
			push @purchase_types, _strip_spc($1);
			next;
		}
	}
	$create_vertex_statement = _create_vertex_tree($vertex_tree);
	$create_edge_statement = _create_edge_tree($edge_tree);
	if ($clean_graph eq 1) {
		_DO;
		_ADD("DROP GRAPH $graph_path CASCADE");
		_FIN;
		_DO;
		_ADD("CREATE GRAPH $graph_path");
		_FIN;
	}
	_DO;
	_ADD("SET GRAPH_PATH=$graph_path");
	_FIN;

	_DO;
	_ADD($create_vertex_statement);
	$_fin=1;
	_ADD($create_edge_statement);
	$_fin=1;

	$init_done=1;
	unlink($save_to_path);
}

sub _rename_household_def {
	my $household_def = shift;
	$household_def =~ s/Food.*//;
	$household_def =~ s/SSudan/SouthSudan/i;
	return $household_def;
}

sub _rename_food {
	my $food = shift;
	$food =~ s/^Sugar$/Sugars/i;
	$food =~ s/^Veg$/Vegetables/i;
	return $food;
}

sub _rename_purchase {
	my $type = shift;
	$type =~ s/^nonpurchase$/NonPurchased/i;
	$type =~ s/^purchase$/Purchased/i;
	return $type;
}

sub _rename_source {
	my $type = shift;
	$type =~ s/^nonpurchase$/NonPurchased/i;
	$type =~ s/^purchase$/Purchased/i;
	return $type;
}

sub _proc {
	my @hh_def_list;
	my ($src_max_lv, $purchase_max_lv) = (0) x 2;
	_BEGIN;
	# Create household properties
	foreach my $file (@files) {
		my $cnt=0;
		my $def_dup=0;
		my $household_def = $file;
		my $household_rid = undef;
		$household_def = _rename_household_def($household_def);
		foreach my $def (@hh_def_list) {
			if ($def eq $household_def) {
				$def_dup=1;
				last;
			}
		}
		if ($def_dup eq 1) { next; }
		push @hh_def_list, $household_def;
		open my $dat, '<', $file or die "Cannot open $file for read :$!";

		# Load line by line from the beginning
		while (<$dat>) {
			my $line = $_;
			my @cols = undef;
			next if ($line =~ /^\s*$/);
			$cnt++;
			next if ($cnt eq 1); # skip header
			if ($limit_per_household ne 0) {
				if ($limit_per_household eq ($cnt - 2)) {
					last;
				}
			}
			@cols = split /,/, $line;
			$household_rid = $cols[0];
			$household_rid =~ s/"//g;
			_ADD("CREATE (hh:HOUSEHOLD { location: '$household_def', rid: $household_rid })");
			_FIN;
		}
	}

	foreach my $file (@files) {
		my @header_cols;
		my $household_def = $file;
		my $household_rid = undef;
		my $cnt=0;
		$household_def = _rename_household_def($household_def);
		open my $dat, '<', $file or die "Cannot open $file for read :$!";

		# Load line by line from the beginning
		while (<$dat>) {
			my $line = $_;
			my @cols = undef;
			my $household = undef;
			my $col_cnt=0;
			if ($line =~ /^\s*$/) { next; }
			$cnt++;
			if ($limit_per_csv ne 0) {
				if (($limit_per_csv + 2) eq $cnt) {
					last;
				}
			}
			$line =~ s/"//g;
			@cols = split /,/, $line;
			$household_rid = $cols[0];
			$household_rid =~ s/"//g;
			if ($cnt eq 1) { # header
				_ADD("\n-- $file\n");
				@header_cols = @cols;
				next;
			}
			if ($limit_per_household ne 0) {
				if ($limit_per_household eq ($household_rid - 1)) {
					last;
				}
			}
			foreach my $header_col (@header_cols) {
				my $val = undef;
				$col_cnt++;
				$val = $cols[$col_cnt-1]; $val =~ s/(\n|\r)//;
				if ($val !~ /\S/) {
				#	$val = 0;
					next;
				}

				# foodCns = food consumption
				if ($header_col =~ /foodCns_(\d+)day_(\S+)/) {
					my $recall_period = $1;
					my $info = $2;
					my $vertex = "FOOD_GROUP";
					my $consumed = "consumed";
					$use_consumed_index=1;
					unless ($info =~ /_/) {
						# no source type
						my $food = $info;
						$food = _rename_food($food);
						_DO;
						_ADD("MATCH (hh:HOUSEHOLD { location: '$household_def', rid: $household_rid })");
						_ADD("MATCH (food:$vertex { name: '$food' })");
						_ADD("CREATE (hh)-[:$consumed { recall_period: $recall_period,");
						_ADD(" no_of_consumption: $val }]->(food)");
						_FIN;
					} else {
						# has source type
						my ($food, $source) = (split /_/, $info);
						my $create_tmp;
						my $test_validity=0;
						$food = _rename_food($food);

						_DO;
						_ADD("MATCH (hh:HOUSEHOLD { location: '$household_def', rid: $household_rid })");
						_ADD("MATCH (food:$vertex { name: '$food' } )");
						#_ADD("MATCH (source:SOURCE_TYPE { name: '$source' })");
						$create_tmp = "CREATE (hh)-[:$consumed { recall_period: $recall_period, no_of_consumption: $val, src_name: '$source',";
						foreach my $item (@src_types) {
							my ($key, $vals) = (split /:/, $item);
							my ($cnt, @vals_c);
							if ($source ne $key) { next; }
							$test_validity=1;
							$cnt=0;
							@vals_c = (split /,/, $vals);
							foreach my $item_c (@vals_c) {
								$cnt++;
								$create_tmp .= " src_lv$cnt: '$item_c',";
								if ($src_max_lv < $cnt) { $src_max_lv = $cnt; }
							}
						}
						if ($test_validity eq 0) { print "Error[1]: $create_tmp\n"; exit; }
						$create_tmp =~ s/,\s*$//;
						$create_tmp .= "}]->(food)";
						#if ($source =~ /^purchase/i) {
						#	$create_tmp .= "-[:purchased { unit_of_measure: 0, total_amount: $val }]->(source)";
						#} else {
						#	$create_tmp .= "-[:non_purchased { unit_of_measure: 0, total_amount: $val }]->(source)";
						#}
						_ADD($create_tmp);
						_FIN;
					}
				}

				# foodExp = food expenditure
				# e.g,
				# "foodExp_Cereals_Cash_Purchase"
				# "foodExp_Cereals_Credit_Purchase"
				# "foodExp_Cereals_NonPurchase_Farming"
				if ($header_col =~ /foodExp_(\S+)/) {
					my $info = $1;
					my $vertex = "FOOD_GROUP";
					my $expended = "expended";
					my $create_tmp;
					my $test_validity=0;
					my ($food, $purchase, $source) = (split /_/, $info);
					$use_expended_index=1;
					$food = _rename_food($food);
					$purchase = _rename_purchase($purchase);
					$source = _rename_source($source);

					_DO;
					_ADD("MATCH (hh:HOUSEHOLD { location: '$household_def', rid: $household_rid })");
					_ADD("MATCH (food:$vertex { name: '$food' })");
					#_ADD("MATCH (source:SOURCE_TYPE { name: '$source' })");
					#_ADD("MATCH (purchase:PURCHASE_TYPE { name: '$purchase' })"); # cash or credit
					$create_tmp = "CREATE (hh)-[:$expended { total_amount: $val, currency: 0, src_name: '$source',";
					foreach my $item (@src_types) {
						my ($key, $vals) = (split /:/, $item);
						my ($cnt, @vals_c);
						if ($source ne $key) { next; }
						$test_validity=1;
						$cnt=0;
						@vals_c = (split /,/, $vals);
						foreach my $item_c (@vals_c) {
							$cnt++;
							$create_tmp .= " src_lv$cnt: '$item_c',";
							if ($src_max_lv < $cnt) { $src_max_lv = $cnt; }
						}
					}
					if ($test_validity eq 0) { print "Error[2]: $create_tmp\n"; exit; }
					$test_validity=0;
					foreach my $item (@purchase_types) {
						my ($key, $vals) = (split /:/, $item);
						my ($cnt, @vals_c);
						if ($purchase ne $key) { next; }
						$test_validity=1;
						$cnt=0;
						@vals_c = (split /,/, $vals);
						foreach my $item_c (@vals_c) {
							$cnt++;
							$create_tmp .= " purchase_lv$cnt: '$item_c',";
							if ($purchase_max_lv < $cnt) { $purchase_max_lv = $cnt; }
						}
					}
					if ($test_validity eq 0) { print "Error[3]: $create_tmp\n"; exit; }
					$create_tmp =~ s/,\s*$//;
					$create_tmp .= "}]->(food)";

					#if ($source =~ /^purchase/i) {
					#	_ADD("CREATE (hh)-[:$expended]->(food)-[:purchased { unit_of_measure: 0, total_amount: $val }]->(source)" .
					#	"-[:_with { currency: 0, total_amount: $val }]->(purchase)");
					#} else {
					#	_ADD("CREATE (hh)-[:$expended]->(food)-[:non_purchased { unit_of_measure: 0, total_amount: $val }]->(source)" .
					#	"-[:_with { currency: 0, total_amount: $val }]->(purchase)");
					#}
					_ADD($create_tmp);
					_FIN;
				}
			}			
		}
	}
	my @c_indexes =
	(
	#"FOOD_GROUP(food_group_type_lv1)",
	#"FOOD_GROUP(food_group_type_lv2)",
	#"FOOD_GROUP(food_group_type_lv3)",
	#"FOOD_GROUP(food_group_type_lv4)",
	#"FOOD_GROUP(name)",
	#"NUTRITION_GROUP(name)",
	#"NUTRITION_GROUP(nutrition_group_type_lv1)",
	"HOUSEHOLD(location)",
	"HOUSEHOLD(rid)",
	);
	if ($use_consumed_index eq 1) {
		push @c_indexes, "CONSUMED(no_of_consumption)";
		push @c_indexes, "CONSUMED(recall_period)";
		push @c_indexes, "CONSUMED(src_name)";
		foreach my $num (1 ... $src_max_lv) {
			push @c_indexes, "CONSUMED(src_lv$num)";
		}
	}
	if ($use_expended_index eq 1) {
		push @c_indexes, "EXPENDED(src_name)";
		push @c_indexes, "EXPENDED(total_amount)";
		push @c_indexes, "EXPENDED(currency)";
		foreach my $num (1 ... $purchase_max_lv) {
			push @c_indexes, "CONSUMED(purchase_lv$num)";
		}
	}

	foreach my $c_index (@c_indexes) {
		_DO;
		_ADD("CREATE PROPERTY INDEX ON $c_index");
		_FIN;
	}
	if ($vaccum_analyze eq 1) {
		_DO;
		_ADD("vacuum analyze");
		_FIN;
	}
	_END;
}

sub _main {
	print "-- Started processing...\n";
	_init();
	_proc();
	_end_buffer();
}
_main();

