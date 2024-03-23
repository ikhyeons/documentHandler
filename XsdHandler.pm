package XsdHandler;

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
	my $target_chemicalFormula;
	
	my $self = {
		_doc => $doc,
		_targetForcefieldType => $targetForcefieldType,
		_target_molecules => undef,
		_target_chemicalFormula => undef,
	};

	my @molecule_arr = _get_target_molecule_array($self);

	$self -> {_target_molecules} = \@molecule_arr;
	$self -> {_target_chemicalFormula} = $self -> {_target_molecules} -> [0] -> ChemicalFormula;

	bless $self, $class;
	return $self;
}

sub doc{
	my ($self) = @_;
	my $doc = $self->{_doc};

	return $doc;
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
			
			my $target_molecule = $atom -> Ancestors ->Molecule;
			my $atomNum = $target_molecule -> NumAtoms;

			if($num % $atomNum == 0){
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

sub target_chemicalFormula{
	my ($self) = @_;
	my $result = $self -> {_target_chemicalFormula};
	return $result
}


sub set_new_target_molecule{
	my ($self) = @_;
	my @molecule_arr = _get_target_molecule_array($self);

	$self -> {_target_molecules} = \@molecule_arr;
}

# 모델 안의 원자 개수를 가져오는 함수
sub number_of_atoms {
	my ($self) = @_;
	my $doc = $self ->{_doc};

	my $atoms = $doc -> UnitCell -> Atoms;
	my $size = @$atoms;
	return $size + 0;
}

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

sub get_empty_position {
	my ($self, $xs, $xe, $ys, $ye, $zs, $ze, $cellSize, $number) = @_;
	my $doc = $self ->{_doc};

	my @rea;
	my @result;
	#cellSize ^ 3로 cell 분할
	my $xcn = int(($xe - $xs) / $cellSize);
	my $ycn = int(($ye - $ys) / $cellSize);
	my $zcn = int(($ze - $zs) / $cellSize);

	my @arr;
	foreach my $xx(1..$xcn){
		my @yarr;
		foreach my $yy(1..$ycn){
			my @zarr;
			foreach my $zz(1..$zcn){
				push(@zarr, 0);
			}
			push(@yarr, \@zarr);
		}
		push(@arr, \@yarr);
	}

	#각 아톰을 순회해서 셀에 각각 할당
	foreach my $tm(@{$self -> {_target_molecules}}){
		my $tc = $tm -> Center; 
		my $tx;
		my $incx = ($tc->X) % ($xe - $xs);
		my $quotientx = int(($tc->X) / ($xe - $xs));
		$incx = ($tc->X) - ($quotientx * ($xe - $xs));

		if($incx < 0){
			$tx = $incx + ($xe - $xs);
		} else {
			$tx = $incx;
		}
		my $ty;
		my $incy = ($tc->Y) % ($ye - $ys);
		my $quotienty = int(($tc->Y) / ($ye - $ys));
		$incy = ($tc->Y) - ($quotienty * ($ye - $ys));
		if($incy < 0){
			$ty = $incy + ($ye - $ys);
		} else {
			$ty = $incy;
		} 
		my $tz = $tc -> Z; 

		my $xci = int(($tx - $xs) / $cellSize);
		my $yci = int(($ty - $ys) / $cellSize);
		my $zci = int(($tz - $zs) / $cellSize);

		if($xci ==$xcn ){$xci = $xcn -1;}
		if($yci ==$ycn ){$yci = $ycn -1;}
		if($zci ==$zcn ){$zci = $zcn -1;}

		if(($tz >= $zs && $tz <= $ze)){
			$arr[$xci] -> [$yci] -> [$zci] = 1;
		}
	}

	foreach my $xx(0..($xcn-1)){
		foreach my $yy(0..($ycn-1)){
			foreach my $zz(0..($zcn-1)){
				my $data = $arr[$xx] -> [$yy] -> [$zz];
				if($data == 0){
					my $posx = $xs + $xx * $cellSize + $cellSize/2;
					my $posy = $ys + $yy * $cellSize + $cellSize/2;
					my $posz = $zs + $zz * $cellSize + $cellSize/2;
					push(@rea, {'x' => $posx, 'y' => $posy, 'z' => $posz  });
				}
			}
		}
	}

	#가운데에서 가장 가가운 셀을 필요 갯수만큼 가져옴
	my $midx = ($xe + $xs) / 2;
	my $midy = ($ye + $ys) / 2;
	my $midz = ($ze + $zs) / 2;

	#가운데에서 가장 가까운 순서로 정렬
	my $temp;

	my @rea_sort = sort {
		my $onex = $a -> {'x'} - $midx;
		my $oney = $a -> {'y'} - $midy;
		my $onez = $a -> {'z'} - $midz;

		my $twox = $b -> {'x'} - $midx;
		my $twoy = $b -> {'y'} - $midy;
		my $twoz = $b -> {'z'} - $midz;

		my $dist_a = sqrt($onex**2 + $oney**2 + $onez**2);
		my $dist_b = sqrt($twox**2 + $twoy**2 + $twoz**2);

		$dist_a <=> $dist_b;
	} @rea;

	foreach my $n(0..$number - 1){
		push(@result, $rea_sort[$n]);
	}
	return @result;
}


1;