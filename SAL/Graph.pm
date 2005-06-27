package SAL::Graph;

# This module is licensed under the FDL (Free Document License)
# The complete license text can be found at http://www.gnu.org/copyleft/fdl.html
# Contains excerpts from various man pages, tutorials and books on perl
# GRAPHING MODULE

use strict;
use DBI;
use Carp;
use Data::Dumper;
use GD;
use GD::Graph::lines;
use GD::Graph::bars;
use GD::Graph::linespoints;
use GD::Graph::lines3d;
use GD::Graph::bars3d;
use GD::Graph::Data;
use GD::Graph::colour qw(:colours :lists :files :convert);


BEGIN {
	use Exporter ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
	$VERSION = '3.01';
	@ISA = qw(Exporter);
	@EXPORT = qw();
	%EXPORT_TAGS = ();
	@EXPORT_OK = qw();
}
our @EXPORT_OK;

END { }

our %Graph = (
######################################
 'datasource'	=> '',
######################################
 'type'		=> '',
######################################
 'legend'	=> [],
######################################
 'image'	=> {},
######################################
 'formatting'	=> {},
######################################
 'out'		=> '',
######################################
 'dump'		=> '',
######################################
);

# Setup accessors via closure (from perltooc manpage)
sub _classobj {
	my $obclass = shift || __PACKAGE__;
	my $class = ref($obclass) || $obclass;
	no strict "refs";
	return \%$class;
}

for my $datum (keys %{ _classobj() }) {
	no strict "refs";
	*$datum = sub {
		my $self = shift->_classobj();
		$self->{$datum} = shift if @_;
		return $self->{$datum};
	}
}

##########################################################################################################################
# Constructors (Public)
sub new {
	my $obclass = shift || __PACKAGE__;
	my $class = ref($obclass) || $obclass;
	my $self = {};

	bless($self, $class);

	$self->{'type'} = 'lines';
	$self->{'out'} = 'png';

	$self->{legend}->[0] = 'Legend not defined.';
	$self->{legend}->[1] = 'Legend not defined.';

	$self->{'image'}{'width'}			= 400;
	$self->{'image'}{'height'}			= 400;
	$self->{'formatting'}{'x_label'}		= 'X Label';
	$self->{'formatting'}{'x_label_skip'}		= 1;
	$self->{'formatting'}{'x_labels_vertical'}	= 1;
	$self->{'formatting'}{'y_label'}		= 'Y Label';
	$self->{'formatting'}{'title'}			= 'Graph Title';
	$self->{'formatting'}{'box_axis'}		= 1;
	$self->{'formatting'}{'long_ticks'}		= 0;
	$self->{'formatting'}{'show_values'}		= 0;
	$self->{'formatting'}{'values_vertical'}	= 0;
	$self->{'formatting'}{'text_space'}		= 8;
	$self->{'formatting'}{'axis_space'}		= 10;
	$self->{'formatting'}{'fgclr'}			= '#AAAAAA';
	$self->{'formatting'}{'boxclr'}			= '#FFFFFF';
	$self->{'formatting'}{'labelclr'}		= 'black';
	$self->{'formatting'}{'axislabelclr'}		= 'black';
	$self->{'formatting'}{'textclr'}		= 'black';
	$self->{'formatting'}{'valuesclr'}		= 'black';
	$self->{'formatting'}{'shadowclr'}		= 'dgray';
	$self->{'formatting'}{'shadow_depth'}		= '4';
	$self->{'formatting'}{'transparent'}		= 1;

	my @plot_colors = ('#598F94','#980D36','#4848FF','#DDDD00');
	$self->{formatting}{'dclrs'} = \@plot_colors;

	$self->{dump} = Dumper($self);

	return $self;
}

##########################################################################################################################
# Destructor (Public)
sub destruct {
	my $self = shift;

}

##########################################################################################################################
# Public Methods

sub build_graph {
	my ($self, $send_mime, $datasource, $query, @params) = @_;

	GD::Graph::colour::add_colour('#AAAAAA');
	GD::Graph::colour::add_colour('#1F9DC2');

	my $data = new GD::Graph::Data;

	if ($datasource) {
		# do dbi
		my ($w, $h) = $datasource->execute($query, @params);

		$datasource->clean_times(0);
		$datasource->short_dates(0);

		for (my $record = 0; $record < $h; $record++) {
			my @row = $datasource->get_row($record);
			$data->add_point(@row);
		}
	} else {
		croak("No datasource set\n");
	}

	my $graph;
	my $gtype = $self->{'type'};
	my $gpkg = "GD::Graph::$gtype"; 

	$graph = $gpkg->new($self->{image}{width}, $self->{image}{height});

	my @colour_names = GD::Graph::colour::colour_list(8);

	$graph->set( %{$self->{formatting}} )        or die $graph->error;

	my @legend  = @{$self->{legend}};
	$graph->set_legend(@legend);

	$graph->plot($data) or die $graph->error;

	my $result;

	# If the caller requested the mime type, add it to the results...
	if ($send_mime) {
		if ($self->{out} eq 'png') {
			$result = "Content-type: image/png\n\n";
		}
	}

	# Put the graph in the results...
	if ($self->{out} eq 'png') {
		$result .= $graph->gd->png;
	}

	# And return them
	return $result;
}

sub set_legend {
	my ($self, @legend) = @_;

	my $index = 0;
	foreach my $entry (@legend) {
		$self->{legend}[$index] = $entry;
		$index++;
	}
}

1;
