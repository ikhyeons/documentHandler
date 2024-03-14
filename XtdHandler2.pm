package XtdHandler2;

use strict;
use Getopt::Long;
use warnings;
use MaterialsScript qw(:all);

use StdHandler;

# 생성자 함수
sub new {
	my $class = shift;
	my $docName = shift;
	my $targetForcefieldType = shift;

	my $doc = $Documents{"$docName"};
	my $trj = $doc -> Trajectory;
	my $target_chemicalFormula;
	
	my $self = {
		_doc => $doc,
		_trj => $trj,
		_targetForcefieldType => $targetForcefieldType,
		_target_molecules => undef,
		_target_chemicalFormula => undef,
	};

	my @molecule_arr = _get_target_molecule_array($self);

	$self -> {_target_molecules} = \@molecule_arr ;
	$self -> {_target_chemicalFormula} = $self->{_target_molecules} -> [0] -> ChemicalFormula;

	bless $self, $class;
	return $self;
}

# 타겟 분자를 배열로 받는 함수
sub _get_target_molecule_array{
	my ($self) = @_;
	my $forcefieldType = $self->{_targetForcefieldType};
	my $doc = $self->{_doc};

	#1. 타겟 분자의 정보를 받기
	
	my $atoms = $doc -> UnitCell -> Atoms;


	my @array;

	my $num = 0;
	foreach my $atom(@$atoms){
		if($atom -> ForcefieldType eq $forcefieldType){
			my $atomNum = $atom -> Ancestors -> Molecule -> NumAtoms;

			if($num % $atomNum == 0){
				my $target_molecule = $atom -> Ancestors ->Molecule;
				push(@array, $target_molecule);
			}
			$num++;
		}
	}
	return @array;
}

sub target_molecules{
	my ($self) = @_;
	my @result = @{$self->{_target_molecules}};
	return @result
}

sub doc{
	my ($self) = @_;
	my $doc = $self->{_doc};
	
	return $doc;
}

sub trj{
	my ($self) = @_;
	my $doc = $self->{_doc};
	
	return $doc -> Trajectory;
}

# 모델 안의 원자 개수를 가져오는 함수
sub number_of_atoms {
	my ($self) = @_;
	my $doc = $self ->{_doc};

	my $atoms = $doc -> UnitCell -> Atoms;
	my $size = @$atoms;
	return $size + 0;
}

#MSD 분석 및 Total_MSD 출력
sub get_MSD_of_target_molecule {
	my ($self) = @_;
	my $doc = $self->{_doc};

	my @target_molecule_list = @{$self->{_target_molecules}};
	my $number_Of_Target_Molecule = scalar @target_molecule_list;
	my $chemicalFormula = $self -> {_target_chemicalFormula};
	my $iterTime = 0;
	foreach my $target_molecule(@target_molecule_list){
		#타겟 분자 배열을 순회하며 MSD Forcite를 수행 함
		my $setname = "$chemicalFormula"."_";
		# MSD를 수행하기 위해 각 분자에 Set을 부여
	    $doc ->CreateSet("$setname$iterTime", $target_molecule);
		# MSD 수행
		Modules -> Forcite->ChangeSettings([MSDComputeAnisotropicComponents => "yes", MSDMaxFrameLength => "100"]);
		my $results = Modules ->Forcite->Analysis->Run($doc, [Calculation => "Mean square displacement", MSDSetA => "$setname$iterTime"]);
		my $outMSDChart = $results->MSDChart;
		my $outMSDChartAsStudyTable = $results->MSDChartAsStudyTable;
		my $outMSDDiffusionCoefficient = $results->MSDDiffusionCoefficient;
		my $outMSDDiffusionCoefficientRsq = $results->MSDDiffusionCoefficientRsq;
		my $outMSDDiffusionCoefficientxx = $results->MSDDiffusionCoefficientxx;
		my $outMSDDiffusionCoefficientyy = $results->MSDDiffusionCoefficientyy;
		my $outMSDDiffusionCoefficientzz = $results->MSDDiffusionCoefficientzz;

	   	$iterTime++;
	}
	
	#스터디 테이블을 생성함
	my $newtable = Documents->New("Total_MSD.std");
	my $TotalTable = $Documents{"Total_MSD.std"};
	
	my $table = StdHandler -> new($TotalTable);
	
	#Total_MSD의 4개 시트를 생성 함(msd, x, y, z)
	my @nameArr = ("Total_MSD", "x", "Y", "Z");
	
	#컬럼명의 배열을 생성함.
	my @columnNameArr;
	foreach my $col(0..$number_Of_Target_Molecule){
		if ($col == 0){
	 		push(@columnNameArr, "Time")
	 	} else {
	 		my $Headname = "$chemicalFormula"."_"."$col"."_"."MSD";	
	 		push(@columnNameArr, "$Headname");
	 	}
	}
	
	#Total_Table의 타겟 분자별 컬럼 수
	my $COL_COUNT = $number_Of_Target_Molecule;
	#최대 프레임 길이만큼 열이 생김 2001개
	my $ROW_COUNT = 2000;

	#데이터 액션
	
	#create sheet	
	$table -> setSheet(@nameArr);
	#set columnName at each sheet
	my $sheetNum_forCol = 0;
	foreach my $sheetName(@nameArr){
		$table -> selectSheet($sheetNum_forCol);
		$table -> setColumnHead(@columnNameArr);
		$sheetNum_forCol++;
	}
	#insert Data
	my $sheetNum = 0;

	my $docName = $doc -> Name;
	foreach my $sheetName(@nameArr){
		$table -> selectSheet($sheetNum);
		my $colNum = 0;
		#Total_Table에 실제 데이터를 삽입하는 로직
		
		foreach my $row(0..$ROW_COUNT){
			foreach my $col(0..$COL_COUNT){
				if($col>=2){
					my $data = $Documents{"$docName"." Forcite MSD ("."$col".").std"} -> Sheets($sheetNum + 1) -> cell($row, 1);
					$table -> insertData($row, $col, $data);
				} else {
					my $data = $Documents{"$docName"." Forcite MSD.std"} -> Sheets($sheetNum + 1) -> cell($row, $col);
					$table -> insertData($row, $col, $data);
				}
			}
		}
		$sheetNum++;
	}	
}

#out target molecules position
sub get_position_of_target_molecule_in_trajectory {
	my ($self) = @_;
	my $doc = $self->{_doc};
	my $trj = $self->{_trj};
	my @target_molecule_list = @{$self -> {_target_molecules}};
	my $number_Of_Target_Molecule = scalar @target_molecule_list;
	
	my $chemicalFormula = $self -> {_target_chemicalFormula};

	#run trajectory
	#2001
	my $numFrames = $doc->Trajectory->NumFrames;
	
    my $startFrame = 1;	# Starting frame
	my $everyXFrames = 1;	# Defines how often you want to sample the trajectory
	my $startFrametime = 0;	# starting frame time
	my $endFrametime = 200;	
     	my $rowcount = 0;
     	my $frametime = $startFrametime;
	
	my @result;
	
	
     	foreach my $frameCounter(1..$numFrames) {
	     	$trj -> CurrentFrame = $frameCounter;
	     	my $currentAtoms = $doc -> UnitCell -> Atoms;
		my @newData;
		#create molecule
		foreach my $target_molecule(@target_molecule_list){
		    	my $p_x = $target_molecule->Center->X;
		    	my $p_y = $target_molecule->Center->Y;
		    	my $p_z = $target_molecule->Center->Z;
		    	push(@newData, {'x' => $p_x, 'y' => $p_y, 'z' => $p_z});
		}
		push(@result, \@newData);
     	}
     	
     	my $frameNumber = 1;
     	foreach my $innerListArray(@result){
     		my $hnum = 1;
     		my @inner_array = @{$innerListArray};
		foreach my $inner_data(@inner_array){
			my $x = $inner_data->{'x'};
			my $y = $inner_data->{'z'};
			my $z = $inner_data->{'y'};
			$hnum++;	
		}
		$frameNumber++;
     	}
     	
     	#create study table
     	#스터디 테이블을 생성함
	my $newtable = Documents->New("xyz_Analysis.std");
	my $xyzTable = $Documents{"xyz_Analysis.std"};
	my $table = StdHandler -> new($xyzTable);
	#create sheets about molecules and set column name
	foreach my $innerListArray(@result){
     		my $hnum = 1;
     		my @inner_array = @{$innerListArray};
		foreach my $inner_data(@inner_array){
			my $x = $inner_data->{'x'};
			my $y = $inner_data->{'z'};
			my $z = $inner_data->{'y'};
			$hnum++;	
		}
		$frameNumber++;
     	}
     	
     	my @sheetNameArr = ();
     	foreach my $sheetNum(0..4){
     		my $atomNumber = $sheetNum + 1;
     		push(@sheetNameArr, "$chemicalFormula"."_"."$atomNumber");
     	}
     	
     	$table -> setSheet(@sheetNameArr);
     	
     	foreach my $sheetNum(0..4){
		my $atomNumber = $sheetNum + 1;
		
		#현재 수정할 시트를 지정 함
		$table->selectSheet($sheetNum);
		#컬럼의 헤드명을 지정 함
		my @columnName = ("time", "x", "y", "z");
		$table->setColumnHead(@columnName);
		
		#최대 프레임 길이만큼 열이 생김 2001개
		my $rowcounter = 2000;
		
		#xyz_Table에 실제 데이터를 삽입하는 로직
		foreach my $col(0..3){
		 	# 0 x y z iter in 2000
		 	foreach my $row(0..$rowcounter){
			 	#insert time and data
			 	if ($col == 1){
			 		#insert x
			 		my $data = $result[$row] -> [$sheetNum] -> {'x'};
			 		$table -> insertData($row,$col, $data);		 		
			 	} elsif ($col == 2){
			 		#insert y
			 		my $data = $result[$row] -> [$sheetNum] -> {'y'};
			 		$table -> insertData($row,$col, $data);	
			 		
			 	} elsif ($col == 3){
			 		#insert z
			 		my $data = $result[$row] -> [$sheetNum] -> {'z'};
			 		$table -> insertData($row,$col, $data);	
			 	} else {
			 		#insert time
			 		my $data = $row * 50;
			 		$table -> insertData($row,$col, $data);
			 	}
			}
		}
	}
}

#out target molecules position
sub get_z_of_set {
	my ($self,
	   @setNames) = @_;
	my $doc = $self->{_doc};
	
	my $min_z;
	my $max_z;
	
	foreach my $setName(@setNames){
		my $target_set = $doc -> UnitCell -> Sets("$setName");
		my $atoms = $target_set -> Atoms;
		
		foreach my $atom (@$atoms){
			my $atom_name = $atom -> Name;
			my $atom_z = $atom -> XYZ -> Z;
			if (!defined($min_z)){
				$min_z = $atom_z;
				$max_z = $atom_z;
			} else {
				if($atom_z <= $min_z){
					$min_z = $atom_z;
				}
				if($atom_z >= $max_z){
					$max_z = $atom_z;
				}
			}
		}
	}
	my $minMax = {'max' => $max_z, 'min' => $min_z};
	return $minMax;
}


sub get_xyz_displacement_from_trajection {
	#get xyz of target molecule in frame
	my ($self) = @_;
	my $doc = $self->{_doc};
	my $trj = $self->{_trj};
	my $target_ForcefieldType = $self->{_target_molecule_forcefield_type};
	my $chemicalFormula = $self->{_target_chemicalFormula};
	my @target_molecule_list = _get_target_molecule_array($self);
	
	
	#run trajectory
	#2001
	my $numFrames = $trj->NumFrames;
	
    	my $startFrame = 1;	# Starting frame
	my $everyXFrames = 1;	# Defines how often you want to sample the trajectory
	my $startFrametime = 0;	# starting frame time
	my $endFrametime = 200;	
     	my $rowcount = 0;
     	my $frametime = $startFrametime;
	
	
	#push xyz displacement to arr
	my @xyz_Displacement;
	
	my @initPosition;
	
	foreach my $frameCounter(1..$numFrames) {
	     	my @newData;
	     	$trj->CurrentFrame = $frameCounter;
	     	#get init position;
	     	if($frameCounter==1){
		     	foreach my $target_molecule(@target_molecule_list){
		     		my $targetCenter = $target_molecule->Center;
			    	push(@initPosition, {
			    		'x' => $targetCenter -> X, 
			    		'y' => $targetCenter -> Y, 
			    		'z' => $targetCenter -> Z
			    	});
			    		
			}
	     	}
	     	
		# push abs data
		my $moleculeIndex = 0;
		# x(t) - x(0)
		foreach my $target_molecule(@target_molecule_list){
		    	my $d_x = $target_molecule->Center->X - $initPosition[$moleculeIndex] ->{'x'};
		    	my $d_y = $target_molecule->Center->Y - $initPosition[$moleculeIndex] ->{'y'};
		    	my $d_z = $target_molecule->Center->Z - $initPosition[$moleculeIndex] ->{'z'};
		    	my $d_a = sqrt($d_x**2 + $d_y**2 + $d_z**2);
		    	push(@newData, {'a' => $d_a, 'x' => $d_x, 'y' => $d_y, 'z' => $d_z});
		    	$moleculeIndex++;
		}
		push(@xyz_Displacement, \@newData);
     	}
	
	#create sheet
	my $newtable = Documents->New("xyz_Displacement.std");
	my $xyzTable = $Documents{"xyz_Displacement.std"};
	my $table = StdHandler -> new($xyzTable);
	
	#set sheetName and column
	my @sheetArr;
	my $moleculeIndex1 = 1;
	foreach my $target_molecule(@target_molecule_list){
	    	push(@sheetArr, "$chemicalFormula"."_"."$moleculeIndex1");
	    	$moleculeIndex1++;
	}
	$table -> setSheet(@sheetArr);
	
	#set column head name
	my $moleculeIndex2 = 0;
	my @columnHeadArr = ('time', 'all', 'x', 'y', 'z');
	foreach my $target_molecule(@target_molecule_list){
		$table -> selectSheet($moleculeIndex2);
		$table -> setColumnHead(@columnHeadArr);
	    	$moleculeIndex2++;
	}
	
	
	#insert data sheet -> column
	my $sheetNum = 0;
	my $rowNum = 2000;
	foreach my $target_molecule(@target_molecule_list){
		#select sheet index;
		$table -> selectSheet($sheetNum);
		#insert data from arr
		foreach my $col(0..4){
		foreach my $row(0..$rowNum){
			if($col == 1){
				my $data = $xyz_Displacement[$row] -> [$sheetNum] -> {'a'};
				$table -> insertData($row, $col, $data);
			} elsif ($col == 2){
				my $data = $xyz_Displacement[$row] -> [$sheetNum] -> {'x'};
				$table -> insertData($row, $col, $data);
			} elsif ($col == 3){
				my $data = $xyz_Displacement[$row] -> [$sheetNum] -> {'y'};
				$table -> insertData($row, $col, $data);
			} elsif ($col == 4){
				my $data = $xyz_Displacement[$row] -> [$sheetNum] -> {'z'};
				$table -> insertData($row, $col, $data);
			} else {
				my $data = $row * 50;
				$table -> insertData($row, $col, $data);
			}
		}
		}
	    	$sheetNum++;
	}
}

#out target molecules position
sub get_set_molecule_xyz_in_trajectory {
	my ($self,
	   @setNames) = @_;
	my $doc = $self->{_doc};
	my $trj = $self->{_trj};
	
	my @columnNames = ('t', 'x', 'y', 'z');
	my $endFrame = $trj->EndFrame;
	my @aa;
	foreach my $frame(1..$endFrame){
		my @ma;
		$trj -> CurrentFrame = $frame;
		foreach my $setName(@setNames){
			my $target_set = $doc -> UnitCell -> Sets("$setName");

			my $atoms = $target_set -> Atoms;
			my $molecule;
			foreach my $atom(@$atoms){
				$molecule = $atom -> Ancestors -> Molecule;
				last;
			}			

			my $tmc = $molecule -> Center;
			my $tmx = $tmc -> X;
			my $tmy = $tmc -> Y;
			my $tmz = $tmc -> Z;

			my $data = {'x' => $tmx, 'y' => $tmy, 'z' => $tmz};
			push(@ma, $data);
		}
		push(@aa, \@ma);
	}

	my $frameNum = scalar @aa;

	#create std
	my $newtable = Documents->New("xyz_position.std");
	my $xyzTable = $Documents{"xyz_position.std"};
	my $table = StdHandler -> new($xyzTable);

	#setSheet
	$table -> setSheet(@setNames);
	#set columnHead
	my $sn = 0;
	foreach my $setName(@setNames){
		$table->selectSheet($sn);
		$table->setColumnHead(@columnNames);
		$sn++;
	}
	
	#insert Data;
	my $setNum=0;
	foreach my $setName(@setNames){
		$table->selectSheet($setNum);
		foreach my $row(0.. $frameNum-1){
			foreach my $col(0..3){
				if($col == 0){$table->insertData($row, $col, $row * 25000);}
				elsif($col == 1){$table->insertData($row, $col, $aa[$row] -> [$setNum] -> {'x'});}
				elsif($col == 2){$table->insertData($row, $col, $aa[$row] -> [$setNum] -> {'y'});}
				elsif($col == 3){$table->insertData($row, $col, $aa[$row] -> [$setNum] -> {'z'});}
			}
		}
		$setNum++;
	}

}

1;