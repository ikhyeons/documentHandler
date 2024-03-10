package XsdHandler;

use strict;
use Getopt::Long;
use warnings;
use MaterialsScript qw(:all);

#use lib 'E:\ik\test_Files\Documents\readxsd';
#require 'StdHandler.pl';

use StdHandler2;

# 생성자 함수
sub new {
	my $class = shift;
	my $docName = shift;
	my $targetForcefieldType = shift;

	my $doc = $Documents{"$docName"};
	my $target_chemicalFormula;
	
	print("create molecule set \n");
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

sub set_new_target_molecule{
	my ($self) = @_;
	my @molecule_arr = _get_target_molecule_array($self);

	$self -> {_target_molecules} = \@molecule_arr;
}

sub doc{
	my ($self) = @_;
	my $doc = $self->{_doc};
	
	return $doc;
}

# 모델 안의 원자 개수를 가져오는 함수
sub number_of_atoms {
	my ($self) = @_;
	my $doc = $self ->{_doc};

	my $atoms = $doc -> UnitCell -> Atoms;
	my $size = @$atoms;
	return $size + 0;
}

sub get_empty_position {
	my ($self, $xs, $xe, $ys, $ye, $zs, $ze, $cellSize, $number) = @_;
	my $doc = $self ->{_doc};

	print("devide area by $cellSize size cells in x: $xs ~ $xe, y: $ys ~ $ye z: $zs ~ $ze Area, get $number positions");
}

1;