package SAL::DBI;

# This module is licensed under the FDL (Free Document License)
# The complete license text can be found at http://www.gnu.org/copyleft/fdl.html
# Contains excerpts from various man pages, tutorials and books on perl
# DBI ABSTRACTION

use strict;
use DBI;
use Carp;

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

our %DBI = (
######################################
 'connection' => {
   # Shared
	'type'		=> '',
	'dbh'		=> '',
	'sth'		=> '',
	'user'		=> '',
	'passwd'	=> '',
    # For MySQL
	'server'	=> '',
	'database'	=> '',
    # For ODBC
	'dsn'		=> '',
    # For SQLite
	'dbfile'	=> ''
  },
######################################
  'fields' => (
    {
	'name'		=> '',
	'label'		=> '',
	'type'		=> '',
	'visible'	=>  0,
	'header'	=>  0,
	'writeable'	=>  0,
	'css'		=> '',
	'precision'	=> '',
	'commify'	=> '',
	'align'		=> '',
	'prefix'	=> '',
	'postfix'	=> '',
    }
  ),
######################################
  'data'		=> [],
######################################
 'internal' => {
	'width'		=> '',
	'height'	=> '',
  },
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

	return $self;
}

sub spawn_mysql {
	my $obclass = shift || __PACKAGE__;
	my $class = ref($obclass) || $obclass;

	my $db_type = 'mysql';
	my $db_server = shift || '(undefined)';
	my $db_user = shift || '(undefined)';
	my $db_passwd = shift || '(undefined)';
	my $db_database = shift || '(undefined)';

	my $self = {};
	$self->{connection}{type} = $db_type;
	$self->{connection}{server} = $db_server;
	$self->{connection}{user} = $db_user;
	$self->{connection}{passwd} = $db_passwd;
	$self->{connection}{database} = $db_database;

	bless($self, $class);

	# make the connection
	$self->{connection}{dbh} = DBI->connect("DBI:mysql:$db_database:$db_server",$db_user,$db_passwd) || confess($DBI::errstr);

	return $self;
}

sub spawn_odbc {
	my $obclass = shift || __PACKAGE__;
	my $class = ref($obclass) || $obclass;

	my $db_type = 'odbc';
	my $db_dsn = shift || '';
	my $db_user = shift || '';
	my $db_passwd = shift || '';


	my $self = {};
	$self->{connection}{type} = $db_type;
	$self->{connection}{dsn} = $db_dsn;
	$self->{connection}{user} = $db_user;
	$self->{connection}{passwd} = $db_passwd;

	bless($self, $class);

	# make the connection
	$self->{connection}{dbh} = DBI->connect("DBI:ODBC:$db_dsn",$db_user,$db_passwd) || confess($DBI::errstr);

	return $self;
}

sub spawn_sqlite {
	my $obclass = shift || __PACKAGE__;
	my $class = ref($obclass) || $obclass;

	my $db_type = 'sqlite';
	my $db_server = '';
	my $db_user = '';
	my $db_passwd = '';
	my $db_database = shift || '(undefined)';

	my $self = {};
	$self->{connection}{type} = $db_type;
	$self->{connection}{server} = $db_server;
	$self->{connection}{user} = $db_user;
	$self->{connection}{passwd} = $db_passwd;
	$self->{connection}{database} = $db_database;

	bless($self, $class);

	# make the connection
	$self->{connection}{dbh} = DBI->connect("DBI:SQLite:dbname=$db_database",$db_user,$db_passwd) || confess($DBI::errstr);

	return $self;
}

##########################################################################################################################
# Destructor (Public)
sub destruct {
	my $self = shift;

	if(defined($self->{connection}{dbh})) {
		$self->{connection}{dbh}->disconnect();
	}
}

##########################################################################################################################
# Public Methods
sub do {
	my ($self, $statement) = @_;
	my $rv = $self->{connection}{dbh}->do($statement);
	return $rv;
}

sub execute {
	my ($self, $statement, @params) = @_;

	my $table = $self->_extract_table($statement);

	# From the section "Outline Usage" of the DBI pod (http://search.cpan.org/~timb/DBI-1.43/DBI.pm)
	# This should probably be it's own function...  Note also the way placeholders are used...
	$self->{connection}{sth} = $self->{connection}{dbh}->prepare($statement) || confess("Can't Prepare SQL Statement: " . $self->{connection}{dbh}->errstr);
	#

	$self->{connection}{sth}->execute(@params) || confess("Can't Execute SQL Statement: " . $self->{connection}{sth}->errstr . "\n\nSQL Statement:\n$statement\nParams:\n@params\n\n");
	$self->{data} = $self->{connection}{sth}->fetchall_arrayref();

	# get the width and height (aka metrics) of the returned data set...
	my $width = $#{$self->{data}[0]};
	my $height = $self->{connection}{sth}->rows();
	$self->{internal}{width} = $width;
	$self->{internal}{height} = $height;

	foreach my $column (0..$width) {
		$self->{fields}[$column]{visible} = 1;
		$self->{fields}[$column]{header} = 1;
		$self->{fields}[$column]{writeable} = 0;
	}

	$self->_get_labels($table);
	return ($width, $height);
}

sub get_column {
	my $self = shift;
	my $column = shift;
	my @data;

	for (my $i=0; $i <= $self->{internal}{height}; $i++) {
		push (@data, $self->{data}->[$i][$column]);
	}

	return @data;
}

sub get_row {
	my $self = shift;
	my $row = shift;
	my @data;

	for (my $i=0; $i <= $self->{internal}{width}; $i++) {
		push (@data, $self->{data}->[$row][$i]);
	}

	return @data;
}

sub get_labels {
	my $self = shift;
	my @data;

	for (my $i=0; $i <= $self->{internal}{width}; $i++) {
		push (@data, $self->{fields}->[$i]->{label});
	}

	return @data;
}

sub clean_times {
	my $self = shift;
	my $col = shift || '0';

	for (my $i=0; $i < $self->{internal}{height}; $i++) {
		$self->{data}->[$i][$col] =~ s/\s+\d\d:\d\d:\d\d.*$//;
	}
}

sub short_dates {
	my $self = shift;
	my $col = shift || '0';

	for (my $i=0; $i < $self->{internal}{height}; $i++) {
		$self->{data}->[$i][$col] =~ s/\d\d(\d\d)-(\d\d)-(\d\d)/$2-$3-$1/;
	}
}

##########################################################################################################################
# Private Methods
sub _get_labels {
	my $self = shift;
	my $table = shift;
	my $tmp;
	my $query;
	my @labels = ();

	if ($self->{connection}{type} eq 'mysql') {
		$query = "SHOW COLUMNS FROM $table";	# cant use ? placeholder (embeds in single quotes)
		$self->{connection}{sth} = $self->{connection}{dbh}->prepare($query) || confess($self->{connection}{dbh}->errstr);
		$self->{connection}{sth}->execute() || confess($self->{connection}{sth}->errstr);
	} elsif ($self->{connection}{type} eq 'odbc') {
		$query = 'SELECT column_name, data_type FROM information_schema.columns WHERE table_name=?';
		$self->{connection}{sth} = $self->{connection}{dbh}->prepare($query) || confess($self->{connection}{dbh}->errstr);
		$self->{connection}{sth}->execute($table) || confess($self->{connection}{sth}->errstr);
	} elsif ($self->{connection}{type} eq 'sqlite') {
		$query = "PRAGMA table_info($table)";
		$self->{connection}{sth} = $self->{connection}{dbh}->prepare($query) || confess($self->{connection}{dbh}->errstr);
		$self->{connection}{sth}->execute() || confess($self->{connection}{sth}->errstr);
	}

	$tmp = $self->{connection}{sth}->fetchall_arrayref();

	if (defined($tmp)) {
		my $num_rows = $#{$tmp};
		my $column = 0;

		for my $row (0..$num_rows) {
			if ($self->{connection}{type} ne 'sqlite') {
				my $name = $tmp->[$row][0];
				my $type = $tmp->[$row][1];
				$self->{fields}[$column]{label} = $name;
				$self->{fields}[$column]{name} = $name;
				$self->{fields}[$column]{type} = $type;
				$column++;
			} else {
				my $name = $tmp->[$row][1];
				my $type = $tmp->[$row][3];
				$self->{fields}[$column]{label} = $name;
				$self->{fields}[$column]{name} = $name;
				$self->{fields}[$column]{type} = $type;
				$column++;
			}
		}
	}
}

sub _extract_table {
	my $self = shift;
	my $statement = shift;
	my $table;

	# Add a space so that the regex below does not fail on statements like:
	# "SELECT * FROM some_table"

	$statement .= ' ';

	if ($statement =~ /^SELECT\s+(.*)\s+FROM\s+(\w+)\s+(.*)/) {
		$table = $2;
	} else {
		$table = 'undefined_tablename';
	}

	return $table;
}

1;
