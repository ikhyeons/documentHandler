package StdHandler;

use strict;
use Getopt::Long;
use warnings;
use MaterialsScript qw(:all);

# 생성자 함수
sub new {
	my $class = shift;
	my $stdDoc = shift;
	#parameter get std document
	
	
	my $self = {
		_stdDoc => $stdDoc,
	};
	bless $self, $class;
	return $self;
}
	

#add sheets by arr
sub setSheet {
	my ($self, @sheetNameArr) = @_;
	my $stdDoc = $self ->{_stdDoc};
	
	my $sheetNum = 0;
	foreach my $sheetName(@sheetNameArr){
		$stdDoc -> InsertSheet($sheetNum, $sheetName);
		$sheetNum++;
	}
}

#select sheet
sub selectSheet{
	my ($self, $sheetIndex) = @_;
	my $stdDoc = $self ->{_stdDoc};
	$stdDoc -> ActiveSheetIndex = $sheetIndex;
}

sub setColumnHead{
	my ($self, @columnHeadArr) = @_;
	my $stdDoc = $self ->{_stdDoc};
	
	my $col = 0;
	foreach my $columnName(@columnHeadArr){
		$stdDoc -> ActiveSheet -> ColumnHeading($col) = "$columnName";
		$col++;
	}

}

#set column head by arr


#insert data
sub insertData {
	my ($self, $row, $col, $data) = @_;
	my $stdDoc = $self ->{_stdDoc};
	$stdDoc -> ActiveSheet -> Cell($row, $col) = $data;
}

  
1;