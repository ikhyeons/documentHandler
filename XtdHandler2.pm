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

sub target_chemicalFormula{
	my ($self) = @_;
	my $result = $self->{_target_chemicalFormula};
	return $result
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

#모든 set을 가져옴
sub get_all_set{
	my ($self) = @_;
	my $doc = $self->{_doc};
	my $sets = $doc->UnitCell->Sets;

	return @{$sets};
}

#파라미터로 준 문자를 이름에 포함한 set만 가져옴
sub get_filtered_set{
	my ($self, $keyword) = @_;
	my $doc = $self->{_doc};
	my $sets = $doc->UnitCell->Sets;
	my @results = ();

	foreach my $set(@$sets){
		my $setName = $set->Name;
		if (index($setName, $keyword) != -1) {
			push(@results, $set);
		}
	}

	return @results;
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


sub run_trj {
    my ($self, $callback) = @_;
	my $doc = $self->{_doc};
	my $trj = $self->{_trj};

	my $endFrame = $trj->EndFrame;

	foreach my $currentFrame(1..$endFrame){
		$trj -> CurrentFrame = $currentFrame;
		$callback->($currentFrame, $doc, $trj, $self -> {_target_molecules});
	}
}
1;