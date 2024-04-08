package LabAction;

use strict;
use Getopt::Long;
use warnings;
use MaterialsScript qw(:all);

use StdHandler;
use XtdHandler2;
use XsdHandler;

# 생성자 함수
sub new {
	my $class = shift;
	
	my $self = {
		_something => ''
	};

	bless $self, $class;
	return $self;
}

#MSD 분석 및 Total_MSD 출력
sub get_MSD_of_target_molecule {
	my ($self, $xtdHandler) = @_;
    
	my $doc = $xtdHandler->doc;
	my @target_molecule_list = $xtdHandler -> target_molecules;
	my $number_Of_Target_Molecule = scalar @target_molecule_list;
	my $chemicalFormula = $xtdHandler -> target_chemicalFormula;

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
sub get_position_of_target_molecule_in_trj {
	my ($self, $xtdHandler, $frameStep) = @_;
	my $fs = $frameStep? $frameStep : 1;

	my $doc = $xtdHandler->doc;
	my $trj = $xtdHandler->trj;
	my $sne = $trj -> FrameTime;

	my @target_molecule_list = $xtdHandler -> target_molecules;
	my $number_Of_Target_Molecule = scalar @target_molecule_list;
	my $chemicalFormula = $xtdHandler -> target_chemicalFormula;
	

	#run trajectory
	#2001
	my $numFrames = $doc->Trajectory->NumFrames;

	my $stepTime = $sne / ($numFrames -1);
	
    my $startFrame = 1;	# Starting frame
	my $everyXFrames = 1;	# Defines how often you want to sample the trajectory
	my $startFrametime = 0;	# starting frame time
   	my $rowcount = 0;
   	my $frametime = $startFrametime;
	
	my @result;
	
	
     	foreach my $frameCounter(1..$numFrames) {
			if (!($frameCounter % $fs == 1 || $frameCounter == 1 || $frameCounter == $numFrames || $fs == 1)){
				next;
			}
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
		my $rowcounter = scalar @result - 1;
		
		#xyz_Table에 실제 데이터를 삽입하는 로직
		foreach my $col(0..3){
		 	# 0 x y z iter in rows
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
			 		my $data = $row * $fs * $stepTime;
					if($row == $rowcounter){
						$data = ($numFrames -1) * $stepTime;
					}
			 		$table -> insertData($row,$col, $data);
			 	}
			}
		}
	}
}

# #out target molecules position
# sub get_z_of_set {
# 	my ($self,
#         $xtdHandler,
# 	   @setNames) = @_;

# 	my $doc = $xtdHandler->doc;
	
# 	my $min_z;
# 	my $max_z;
	
# 	foreach my $setName(@setNames){
# 		my $target_set = $doc -> UnitCell -> Sets("$setName");
# 		my $atoms = $target_set -> Atoms;
		
# 		foreach my $atom (@$atoms){
# 			my $atom_name = $atom -> Name;
# 			my $atom_z = $atom -> XYZ -> Z;
# 			if (!defined($min_z)){
# 				$min_z = $atom_z;
# 				$max_z = $atom_z;
# 			} else {
# 				if($atom_z <= $min_z){
# 					$min_z = $atom_z;
# 				}
# 				if($atom_z >= $max_z){
# 					$max_z = $atom_z;
# 				}
# 			}
# 		}
# 	}
# 	my $minMax = {'max' => $max_z, 'min' => $min_z};
# 	return $minMax;
# }


sub get_xyz_displacement_in_trj {
	#get xyz of target molecule in frame
	my ($self, $xtdHandler, $frameStep) = @_;
	my $doc = $xtdHandler->doc;
	my $trj = $xtdHandler->trj;

	my $chemicalFormula = $xtdHandler->target_chemicalFormula;
	my @target_molecule_list = $xtdHandler -> target_molecules;
	
	my $fs = $frameStep? $frameStep : 1;
	
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
			if (!($frameCounter % $fs == 1 || $frameCounter == 1 || $frameCounter == $numFrames || $fs == 1)){
				next;
			}

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

	my $sne = $trj -> FrameTime;
	my $stepTime = $sne / ($numFrames -1);



	my $rowNum = scalar @xyz_Displacement;
	foreach my $target_molecule(@target_molecule_list){
		#select sheet index;
		$table -> selectSheet($sheetNum);
		#insert data from arr
		foreach my $col(0..4){
		foreach my $row(0..$rowNum-1){
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
				my $data = $row * $stepTime * $fs;
				if($row == $rowNum-1){
					$data = ($numFrames -1) * $stepTime;
				}
				
				$table -> insertData($row, $col, $data);
			}
		}
		}
	    	$sheetNum++;
	}
}

#out target molecules position
sub get_set_molecule_xyz_in_trj {
	my ($self, $params) = @_;
	my $xtdHandler = $params -> {'xtdHandler'};
	my $startf = $params -> {'startFrame'};
	my $endf = $params -> {'endFrame'};
	my $fq = $params -> {'frequency'};
	my $fs = $params ->{'frameStep'}? $params ->{'frameStep'} : 1;
	my @setNames = @{$params -> {'setNames'}};

	my $doc = $xtdHandler->doc;
	my $trj = $xtdHandler->trj;
	
	my @columnNames = ('t', 'x', 'y', 'z');
	my $endFrame = $endf;
	print("SF $startf EF $endFrame / start make std \n");
	
	my @set_molecules;

	foreach my $setName(@setNames){
		my $atoms = $doc -> UnitCell -> Sets($setName) -> Atoms;
		foreach my $atom(@$atoms){
			push(@set_molecules, $atom -> Ancestors -> Molecule);
			last;
		}
	}

	my $newtable = Documents->New("xyz_position"."_$startf"."-$endf".".std");
	my $table = StdHandler -> new($newtable);

	#setSheet
	$table -> setSheet(@setNames);
	#set columnHead
	my $sn = 0;
	foreach my $setName(@setNames){
		$table->selectSheet($sn);
		$table->setColumnHead(@columnNames);
		$sn++;
	}
	
	my $rowNum = 0;
	my $fc = 0;
	
	foreach my $frame($startf..$endFrame){
		if (!($fc % $fs == $fs-1 || $frame == $startf || $frame == $endFrame || $fs == 1)){
				$fc++;
				next;
		}
		$fc=0;
		print("get xyz in trj f:$frame \n");
		$trj -> CurrentFrame = $frame;
		my $setNum=0;
		foreach my $molecule(@set_molecules){
			$table->selectSheet($setNum);
			my $tmc = $molecule -> Center;
			my $tmx = $tmc -> X;
			my $tmy = $tmc -> Y;
			my $tmz = $tmc -> Z;

			foreach my $col(0..3){
				if($col == 0){
					if($frame == $endFrame){
						$table->insertData($rowNum, $col, ($endFrame -1) * $fq);
					} else {
						$table->insertData($rowNum, $col, ($rowNum * $fs + $startf - 1)  * $fq);
					}
				}
					
				elsif($col == 1){$table->insertData($rowNum, $col, $tmx);}
				elsif($col == 2){$table->insertData($rowNum, $col, $tmy);}
				elsif($col == 3){$table->insertData($rowNum, $col, $tmz);}
			}
			$setNum++;
		}
		$rowNum++;
	}
}

sub count_out_molecule_num_by_time{
	my ($self, $params) = @_;
	my $xtdHandler = $params -> {'xtdHandler'};
	my $startf = $params -> {'startFrame'};
	my $endf = $params -> {'endFrame'};
	my $fq = $params -> {'frequency'};
	my $fs = $params -> {'frameStep'}? $params -> {'frameStep'} : 1;
	my @thresoldSetNames = @{$params -> {'thresoldSetNames'}};
	print("SF $startf EF $endf / start make std \n");
	my $thresholdAdd = 13;

	my $doc = $xtdHandler -> doc();
	my $trj = $xtdHandler -> trj();

	#이탈을 확인할 Threshold Value를 담을 변수
	my $z_max_boundary;
	my $z_min_boundary;

	#이탈지점 Thresold 값 추출
	my $z_boundary = $xtdHandler -> get_z_of_set(@thresoldSetNames);
	$z_max_boundary = $z_boundary -> {'max'} + $thresholdAdd;
	$z_min_boundary = $z_boundary -> {'min'} - $thresholdAdd;

	#각 프레임 마다 타겟분자가 나갔는지 검사
	my $num = $startf;

	#std파일 생성
	my $newtable = Documents->New("out_molecule_count_"."$startf"."-$endf".".std");
	my $table = StdHandler -> new($newtable);
	my @columns = ("time", "count");
	$table -> setColumnHead(@columns);

	my $row = 0;
	my $fc = 0;

	foreach my $frame($startf..$endf){
		if (!($fc % $fs == $fs-1 || $frame == $startf || $frame == $endf || $fs == 1)){
			$fc++;
			next;
		}
		$fc = 0;
		#프레임 별 이탈갯수
		my $mn = 0;
		print("\n check $frame Frame \n");
		$trj-> CurrentFrame = $frame;

		#타겟 분자가 이탈지점을 넘어갔는지 확인
		my @targetMolecules = $xtdHandler -> target_molecules;
		foreach my $target_molecule(@targetMolecules){
			my $target_z = $target_molecule -> Center -> Z;
			#std 생성 및 기록
			if($target_z <= $z_min_boundary || $target_z >= $z_max_boundary){
				$mn++;
			}
		}
		
		foreach my $col(0..1){
			if($col ==0){
				if($frame == $endf){
					$table->insertData($row, $col, ($endf -1) * $fq);
				} else {
					$table->insertData($row, $col, ($row * $fs + $startf - 1)  * $fq);
				}
			}
			elsif($col == 1){$table->insertData($row, $col, $mn);}
		}
		$row++;
	}
}

sub run_dynamics_with_reposition {
	my ($self, $params) = @_;
	my $xsdHandler = $params->{'xsdHandler'};
	my $temperature = $params->{'temperature'};
	my $frequency = $params->{'frequency'};
	my $init_dynamics_time = $params->{'init_dynamics_time'};
	my $total_dynamics_time = $params->{'total_dynamics_time'};
	my $pxs = $params->{'x_start'};
	my $pxe = $params->{'x_end'};
	my $pys = $params->{'y_start'};
	my $pye = $params->{'y_end'};
	my $pzs = $params->{'z_start'};
	my $pze = $params->{'z_end'};
	my $pCellSize = $params->{'cellSize'};
	my @setNames = @{$params->{'thresoldSetNames'}};


	my $pdoc = $xsdHandler->doc;

	my $fileName = $pdoc -> Name;
	my $xsdDoc_Name = $fileName;

	my $endFrame = $total_dynamics_time / $frequency;

	#초기 trj를 생산
	print("create initial trj \n");
	my $sdoc = $Documents{"$xsdDoc_Name.xsd"};
	my $copyDoc = Documents -> New("$xsdDoc_Name"."_set.xsd");
	$copyDoc-> CopyFrom($sdoc);

	Modules -> Forcite -> Dynamics -> Run($copyDoc, Settings(
		'3DPeriodicElectrostaticSummationMethod' => 'PPPM',
		CurrentForcefield => 'COMPASSIII',
		Ensemble3D => 'NVT',
		Temperature => $temperature,
		NumberOfSteps => $init_dynamics_time * 1000,
		TrajectoryFrequency => $frequency * 1000,
		Thermostat => 'Andersen',
		EnergyDeviation => 1e+023,
		StressXX => -0.000101325,
		StressYY => -0.000101325,
		StressZZ => -0.000101325));

	my $trj;

	#초기 dynamics로 생성된 xtd파일에서 작업 시작
	my $baseDoc = $Documents{"$xsdDoc_Name"."_set".".xtd"};
	#최종 결과파일
	my $copyDoc2 = Documents -> New("$xsdDoc_Name"."_set"."_result".".xtd");
	my $copyDoc_Name = "$xsdDoc_Name"."_set"."_result".".xtd";
	$copyDoc2->CopyFrom($baseDoc);

	my $xtdHandler = XtdHandler2 -> new($copyDoc_Name, "h1h");

	#시작 프레임
	my $currentFrame = 1;
	#최종적으로 나간 분자들의 집합
	my @out_moleculeList;

	#이탈을 확인할 Threshold Value를 담을 변수
	my $z_max_boundary;
	my $z_min_boundary;

	my $doc = $xtdHandler -> doc();
	$trj = $xtdHandler -> trj();

	#이탈지점 Thresold 값 추출
	my $z_boundary = $xtdHandler -> get_z_of_set(@setNames);
	$z_max_boundary = $z_boundary -> {'max'} + 13;
	$z_min_boundary = $z_boundary -> {'min'} - 13;

	#총 이탈한 분자 개수
	my $total_out_num = 0;
	while($currentFrame <= $endFrame){
		print("\n \n Main loot $currentFrame \n");
		$trj-> CurrentFrame = $currentFrame;
		
		my $isOut = 0;
		my $outNum = 0;

		#타겟 분자가 이탈지점을 넘어갔는지 확인
		my @targetMolecules = $xtdHandler -> target_molecules;
		foreach my $target_molecule(@targetMolecules){
			my $target_z = $target_molecule -> Center -> Z;
			#만약 넘어갔을 경우 이탈 분자 저장
			if($target_z <= $z_min_boundary || $target_z >= $z_max_boundary){
				print("detect break away1 \n");
				print("t : $target_z, m : $z_min_boundary , max : $z_max_boundary \n");
				push(@out_moleculeList, {'f' => $currentFrame, 'm' => $target_molecule});
				
				$isOut = 1;
				$outNum++;
				$total_out_num++;
			}
		}
		
		#만약 분자가 이탈지점을 넘어갔을 경우의 3d 문서 작업
		if($isOut == 1){
			print("go here \n");
			
			#넘어간 순간의 스냅샷을 생성
			print("make snapShot \n");
			my $snapDoc = $doc;
			$snapDoc -> CurrentFrame = $trj -> CurrentFrame;
			
			$snapDoc -> Export("snapShot.xsd");
			$snapDoc -> Export("snapShot$currentFrame".".xsd");
			my $xsdHandler2 = XsdHandler -> new("snapShot.xsd", "h1h");

			#xsd파일에서 넘어간 분자의 위치를 빈 공간으로 이동 조정
			my @empty_area_list = $xsdHandler2 -> get_empty_position({
				'x_start' => $pxs, 'x_end' => $pxe,
				'y_start' => $pys, 'y_end' => $pye,
				'z_start' => $pzs, 'z_end' => $pze,
				'cellSize' => $pCellSize, 'getPosNum' => $outNum});
		

			foreach my $qq(@empty_area_list){
				my $qx = $qq->{'x'};
				my $qy = $qq->{'y'};
				my $qz = $qq->{'z'};
				print("$qx $qy $qz \n");

			}
			my $xsdDoc = $xsdHandler2 -> doc;
		
			#check1
			my @array = $xsdHandler2 -> target_molecules;
			my $tmNum = 0;
			
			foreach my $tm(@array){
				my $tmz = $tm -> Center -> Z;
				if($tmz <= $z_min_boundary || $tmz >= $z_max_boundary){
					#over molecule
					my $tox = $empty_area_list[$tmNum] -> {'x'};
					my $toy = $empty_area_list[$tmNum] -> {'y'};
					my $toz = $empty_area_list[$tmNum] -> {'z'};
					print("object position / to : $tox $toy $toz \n");
					my $tc = $tm -> Center;
					my $tx = $tc -> X;
					my $ty = $tc -> Y;
					my $tz = $tc -> Z;
					print("target position / tg : $tx $ty $tz \n");
					my $dx = $tox - $tx;
					my $dy = $toy - $ty;
					my $dz = $toz - $tz;
					print("to - tg position / d : $dx $dy $dz \n");
					foreach my $atom (@{$tm -> Atoms}){
						my $movedx = $atom->X + $dx;
						my $movedy = $atom->Y + $dy;
						my $movedz = $atom->Z + $dz;
						print("     moved p : $movedx $movedy $movedz \n");
						$atom -> X = $atom->X + $dx;
						$atom -> Y = $atom->Y + $dy;
						$atom -> Z = $atom->Z + $dz;
					}
					$tmNum++;
				}
			}
			
			
			#xtd파일에서 넘어간 프레임 삭제
			my $endFrame = $trj -> EndFrame;
			$trj -> removeFrames(Frames(Start => $currentFrame, End => $endFrame));
			
			#위치가 조정된 xsd파일을 xtd파일과 통합
			print("integrate snapShot \n");
			$trj->AppendFramesFrom($xsdDoc);
			#스냅샷 삭제
			print("Delete snapShot \n");
			$xsdDoc -> Delete;
			
			#최종 위치에서 dynamics 재게산
			print("recalc trj \n");
			Modules -> Forcite -> Dynamics -> Run($copyDoc2, Settings(
				'3DPeriodicElectrostaticSummationMethod' => 'PPPM',
				CurrentForcefield => 'COMPASSIII',
				Ensemble3D => 'NVT',
				TrajectoryRestart =>'Yes',
				AppendTrajectory => 'Yes',
				Temperature => $temperature,
				NumberOfSteps => $frequency * 1000,
				TrajectoryFrequency => $frequency * 1000,
				Thermostat => 'Andersen',
				EnergyDeviation => 1e+023,
				StressXX => -0.000101325,
				StressYY => -0.000101325,
				StressZZ => -0.000101325));
		} elsif ($currentFrame == $trj -> EndFrame) {
			#끝 프레임일 경우 dynamics 재계산
			print("recalc trj \n");
			Modules -> Forcite -> Dynamics -> Run($copyDoc2, Settings(
				'3DPeriodicElectrostaticSummationMethod' => 'PPPM',
				CurrentForcefield => 'COMPASSIII',
				Ensemble3D => 'NVT',
				TrajectoryRestart =>'Yes',
				AppendTrajectory => 'Yes',
				Temperature => $temperature,
				NumberOfSteps => $frequency * 1000,
				TrajectoryFrequency => $frequency * 1000,
				Thermostat => 'Andersen',
				EnergyDeviation => 1e+023,
				StressXX => -0.000101325,
				StressYY => -0.000101325,
				StressZZ => -0.000101325));
		}

		$currentFrame++;
	}

	#이탈한 분자의 set생성
	#set이름 규칙 => 넘어간프레임 (몇번째로 넘어간 분자인지);
	#만약 7번 프레임에 하나, 14번 프레임에 하나 넘어갔다면
	#7 (0), 14 (1) 이렇게 두개가 생성됨.
	my $mn = 0;
	foreach my $moleculeData(@out_moleculeList){
		my $f = $moleculeData -> {'f'};
		my $m = $moleculeData -> {'m'};
		$doc ->CreateSet("$f ($mn)", $m);
		$mn++;
	}

	#이탈한 분자들의 각 프레임당 xyz 좌표를 std테이블로 생성.
	my $copyDOc_Name = "$xsdDoc_Name"."_set"."_result".".xtd";
	my $xtdHandler2 = XtdHandler2 -> new($copyDOc_Name, "h1h");

	my @target_sets;

	my $rsets = $doc -> UnitCell -> Sets;
	foreach my $set(@$rsets) {
		my $str = $set->Name;
		#정규식에 맞는 setName만 가져옴
		#이 정규식은 '7 (0)' 이 형식을 가져옴.
		if ($str =~ /^\d+(\s+\(\d+\))$/) {
			push(@target_sets, $str);
		}
	}

	my $target_count = scalar @target_sets;

	if($target_count > 0){
		get_set_molecule_xyz_in_trj($self, 
		{
			'xtdHandler' => $xtdHandler2,
			'startFrame' => 1,
			'endFrame' => $endFrame,
			'frequency' => $frequency,
			'setNames' => \@target_sets
		});
	} else {
		print("0 output\n");
	}
}

sub create_set_of_out_molecule {
	my ($self, $params) = @_;

	my $thresholdAdd = 13;
	my $xtdHandler = $params -> {'xtdHandler'};
	my $startf = $params -> {'startFrame'};
	my $endf = $params -> {'endFrame'};
	my $fq = $params -> {'frequency'};
	my @setNames = @{$params -> {'thresoldSetNames'}};

	my $doc = $xtdHandler -> doc();
	my $trj = $xtdHandler -> trj();

	my $endFrame = $endf;

	print("EndFrame : $endFrame \n");
	#나간 분자 목록

	my $currentFrame = $startf;

	#이탈을 확인할 Threshold Value를 담을 변수
	my $z_max_boundary;
	my $z_min_boundary;

	#이탈지점 Thresold 값 추출
	my $z_boundary = $xtdHandler -> get_z_of_set(@setNames);
	$z_max_boundary = $z_boundary -> {'max'} + $thresholdAdd;
	$z_min_boundary = $z_boundary -> {'min'} - $thresholdAdd;

	#각 프레임 마다 타겟분자가 나갔는지 검사

	my $num = $startf;
	my $mn = 0;
	while($currentFrame <= $endFrame){
		print("\n check $currentFrame Frame \n");
		$trj-> CurrentFrame = $currentFrame;

		#타겟 분자가 이탈지점을 넘어갔는지 확인
		my @targetMolecules = $xtdHandler -> target_molecules;
		foreach my $target_molecule(@targetMolecules){
			my $target_z = $target_molecule -> Center -> Z;
			#만약 넘어갔을 경우 분자 이름을 1로 바꾸고 이탈 분자 저장
			#이미 한번 넘어간 분자는 다시 저장하지 않음
			if(($target_z <= $z_min_boundary || $target_z >= $z_max_boundary) && $target_molecule->Name ne "1"){
				print("detect break away1 \n");
				print("target : $target_z , min : $z_min_boundary , max : $z_max_boundary \n");
				$target_molecule->Name = "1";
				$doc ->CreateSet("$currentFrame ($mn)-$num", $target_molecule);
				$mn++;
			}
		}
		$currentFrame++;
	}

	my $zmin = $z_boundary->{'min'};
	my $zmax = $z_boundary->{'max'};
	print("set 끝점 → min : $zmin , max : $zmax / 각 set에서 더해진 숫자 : $thresholdAdd \n 경계값 → min : $z_min_boundary , max : $z_max_boundary \n");

	
}

1;