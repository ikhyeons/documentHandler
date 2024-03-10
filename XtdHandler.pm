package XtdHandler;

use strict;
use Getopt::Long;
use warnings;
use MaterialsScript qw(:all);

#use lib 'E:\ik\test_Files\Documents\readxsd';
#require 'StdHandler.pl';

use StdHandler;

# 생성자 함수
sub new {
	my $class = shift;
	my $xtdDoc_name = shift;
	my $target_atom_name = shift;
	my $number_Of_Atom_In_Target_Molecule = shift;
	my $target_molecule_forcefield_type = shift;
	my $doc = $Documents{"$xtdDoc_name.xtd"};
	
	
	my $self = {
		_xtdDoc_Name => $xtdDoc_name,
		_doc => $doc,
		_target_atom_name => $target_atom_name,
		_number_Of_Atom_In_Target_Molecule => $number_Of_Atom_In_Target_Molecule,
		_target_molecule_forcefield_type => $target_molecule_forcefield_type
	};
	bless $self, $class;
	return $self;
}

sub get_Doc{
	my ($self) = @_;
	my $xtd_Document = $self->{_doc};
	
	return $xtd_Document;
}

# 모델 안의 원자 개수를 가져오는 함수
sub number_of_atoms {
	my ($self) = @_;

	my $atoms = $self ->{_doc}-> UnitCell -> Atoms;
	my $size = @$atoms;
	return $size + 0;
}


sub get_position_of_atom{
	my ($self) = @_;
	my $xtd_Document = $self->{_doc};
	my $target_Atom_name = $self->{_target_atom_name};
	
	my $atoms = $xtd_Document -> UnitCell -> Atoms;
	my $target_Atom;
	my $num = 0;
	

	foreach my $atom(@$atoms){
		;
		if($atom -> Name eq $target_Atom_name){
			$target_Atom = $atom;
			my $position = $target_Atom->XYZ;
			return $position;
		}
	}	
}

#타겟 분자의 수를 가져오는 함수
sub number_of_target_molecule{
	my ($self) = @_;
	my $xtd_Document = $self->{_doc};
	my $molcule_Name = $self->{_target_molecule_forcefield_type};
	
	my $number_of_atom_in_molecule = $self -> {_number_Of_Atom_In_Target_Molecule};
	my $atoms = $xtd_Document -> UnitCell -> Atoms;
	my $number = 0;

	foreach my $atom(@$atoms){
		if($atom -> ForcefieldType eq $molcule_Name){
			$number++;
		}
	}
	return $number / $number_of_atom_in_molecule
}

# 타겟 분자를 배열로 받는 함수
sub get_target_molecule_array{
	my ($self) = @_;
	my $number_of_atom_in_molecule = $self -> {_number_Of_Atom_In_Target_Molecule};
	my $forcefieldType = $self->{_target_molecule_forcefield_type};
	my $xtd_Document = $self->{_doc};
	my $atoms = $xtd_Document -> UnitCell -> Atoms;
	my @array;
	my $num = 0;
	
	foreach my $atom(@$atoms){
		if($atom -> ForcefieldType eq $forcefieldType){
			if($num % $number_of_atom_in_molecule == 0){
				my $target_molecule = $atom -> Ancestors ->Molecule;
				push(@array, $target_molecule);
			}
			$num++;
		}
	}
	return @array;
}

sub initialize_trajectory {
	my ($self) = @_;
	my $xtd_Document = $self->{_doc};
	
	$xtd_Document->Trajectory->CurrentFrame = 1;
}


#타겟 원자의 수를 가져오는 함수 don't use
#sub number_of_target_atom{
#	my ($self, $molecule_Name) = @_;
#
#	my $xtd_Document = $self->{_doc};
#	my $atoms = $xtd_Document -> UnitCell -> Atoms;
#	my $number = 0;
#
#	foreach my $atom(@$atoms){
#		if($atom -> ForcefieldType eq $molecule_Name){
#			$number++;
#		}
#	}
#	return $number
#}


sub get_Trj{
	my ($self) = @_;
	my $xtd_Document = $self->{_doc};
	
	return $xtd_Document -> Trajectory;
}

#MSD 분석 및 Total_MSD 출력
sub get_MSD_of_target_molecule {
	my ($self) = @_;
	my $target_Atom_Name = $self->{_target_atom_name};
	my $forcefieldType = $self->{_target_molecule_forcefield_type};
	my $number_Of_Atom_In_Target_Molecule = $self -> {_number_Of_Atom_In_Target_Molecule};
	my $xtd_Document = $self->{_doc};
	my @target_molecule_list = get_target_molecule_array($self, $forcefieldType, $number_Of_Atom_In_Target_Molecule);
	my $number_Of_Target_Molecule = scalar @target_molecule_list;
	my $iterTime = 0;
	foreach my $target_molecule(@target_molecule_list){
		#타겟 분자 배열을 순회하며 MSD Forcite를 수행 함
		my $setname = "$target_Atom_Name$number_Of_Atom_In_Target_Molecule"."_";
	    	$xtd_Document ->CreateSet("$setname$iterTime", $target_molecule);
		Modules -> Forcite->ChangeSettings([MSDComputeAnisotropicComponents => "yes", MSDMaxFrameLength => "100"]);
		my $results = Modules ->Forcite->Analysis->Run($xtd_Document, [Calculation => "Mean square displacement", MSDSetA => "$setname$iterTime"]);
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
	
	#set column of sheet
	my @columnNameArr;
	#create array of column_head_name
	foreach my $col(0..$number_Of_Target_Molecule){
		if ($col == 0){
	 		push(@columnNameArr, "Time")
	 	} else {
	 		my $Headname = "$target_Atom_Name$number_Of_Atom_In_Target_Molecule"."_"."$col"."_"."MSD";	
	 		push(@columnNameArr, "$Headname");
	 	}
	}
	
	#Total_Table의 타겟 분자별 컬럼 수
	my $COL_COUNTER = $number_Of_Target_Molecule;
	#최대 프레임 길이만큼 열이 생김 2001개
	my $rowcounter = 2000;

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
	foreach my $sheetName(@nameArr){
		$table -> selectSheet($sheetNum);
		my $colNum = 0;
		#Total_Table에 실제 데이터를 삽입하는 로직
		
		foreach my $row(0..2000){
			foreach my $col(0..$COL_COUNTER){
				if($col>=2){
					my $data = $Documents{"$self->{_xtdDoc_Name}"."_set Forcite MSD ("."$col".").std"} -> Sheets($sheetNum + 1) -> cell($row, 1);
					$table -> insertData($row, $col, $data);
				} else {
					my $data = $Documents{"$self->{_xtdDoc_Name}"."_set Forcite MSD.std"} -> Sheets($sheetNum + 1) -> cell($row, $col);
					$table -> insertData($row, $col, $data);
				}
			}
		}
		$sheetNum++;
	}	
}

#out target molecules position
sub get_position_of_target_molecule_in_trajection {
	my ($self) = @_;
	   
	my $target_ForcefieldType = $self->{_target_molecule_forcefield_type};
	my $number_Of_Atom_In_Target_Molecule = $self -> {_number_Of_Atom_In_Target_Molecule};
	my $target_Atom_Name = $self->{_target_atom_name};
	my $xtd_Document = $self->{_doc};
	my @target_molecule_list = get_target_molecule_array($self, $target_ForcefieldType, $number_Of_Atom_In_Target_Molecule);
	my $number_Of_Target_Molecule = scalar @target_molecule_list;
	
	#run trajectory
	#2001
	my $numFrames = $xtd_Document->Trajectory->NumFrames;
	
    	my $startFrame = 1;	# Starting frame
	my $everyXFrames = 1;	# Defines how often you want to sample the trajectory
	my $startFrametime = 0;	# starting frame time
	my $endFrametime = 200;	
     	my $rowcount = 0;
     	my $frametime = $startFrametime;
	
	my @result;
	
	
     	foreach my $frameCounter(1..$numFrames) {
	     	$xtd_Document->Trajectory->CurrentFrame = $frameCounter;
	     	my $currentAtoms = $xtd_Document->UnitCell->Atoms;
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
     		push(@sheetNameArr, "$target_Atom_Name"."$number_Of_Atom_In_Target_Molecule"."_"."$atomNumber");
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
sub get_z_of_set_in_trajection {
	my ($self,
	   @setNames) = @_;
	my $xtd_Document = $self->{_doc};
	
	
	
	
	my $min_z;
	my $max_z;
	
	foreach my $setName(@setNames){
		my $target_set = $xtd_Document -> UnitCell -> Sets("$setName");
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
	my $number_Of_Atom_In_Target_Molecule = $self -> {_number_Of_Atom_In_Target_Molecule};
	my $target_Atom_Name = $self->{_target_atom_name};
	my $xtd_Document = $self->{_doc};
	my $target_ForcefieldType = $self->{_target_molecule_forcefield_type};
	
	my @target_molecule_list = get_target_molecule_array($self, $target_ForcefieldType, $number_Of_Atom_In_Target_Molecule);
	
	
	#run trajectory
	#2001
	my $numFrames = $xtd_Document->Trajectory->NumFrames;
	
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
	     	$xtd_Document->Trajectory->CurrentFrame = $frameCounter;
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
	    	push(@sheetArr, "$target_Atom_Name$number_Of_Atom_In_Target_Molecule"."_"."$moleculeIndex1");
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




1;