=head1 NAME - Bio::EnsEMBL::DBSQL::StatementHandle

=head1 SYNOPSIS

  Do not use this class directly.  It will automatically be used by
  the Bio::EnsEMBL::DBSQL::DBConnection class.

=head1 DESCRIPTION

  This class extends DBD::mysql::st so that the DESTROY method may be
  overridden.  If the DBConnection::disconnect_when_inactive flag is set
  this statement handle will cause the database connection to be closed
  when it goes out of scope and there are no other open statement handles.

=head1 CONTACT

  This module is part of the Ensembl project: www.ensembl.org

  Ensembl development mailing list: <ensembl-dev@ebi.ac.uk>

=head1 METHODS

=cut

package Bio::EnsEMBL::DBSQL::StatementHandle;

use vars qw(@ISA);
use strict;

use DBD::mysql;

@ISA = qw(DBI::st);

# As DBD::mysql::st is a tied hash can't store things in it,
# so have to have parallel hash
my %dbchash;
sub dbc { 
  my $self = shift;

  if (@_) {
    $dbchash{$self} = shift;
  }

  return $dbchash{$self};
}


sub DESTROY {
  my ($obj) = @_;
  my $dbc = $obj->dbc;
  $obj->dbc(undef);

  # rebless into DBI::st so that superclass destroy method is called
  # if it exists (it does not exist in all DBI versions)
  bless($obj, 'DBI::st');

  # The count for the number of kids is decremented only after this
  # function is complete. Disconnect if there is 1 kid (this one) remaining.
  if(
    $dbc  && $dbc->disconnect_when_inactive()
    && $dbc->db_handle->{Kids} == 1
    && !$dbc->db_handle()->{'InactiveDestroy'}
  ){
    # print STDERR "disconnecting statement handle ".scalar($dbc->db_handle)." \n";
    $dbc->db_handle->disconnect();
  }
}
1;
