
#
# BioPerl module for Contig
#
# Cared for by Ewan Birney <birney@sanger.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::DB::Contig - Handle onto a database stored contig

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Describe the object here

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::DBSQL::Contig;
use vars qw(@ISA);
use strict;

# Object preamble - inheriets from Bio::Root::Object

use Bio::Root::Object;
use Bio::SeqFeature::Generic;
use Bio::EnsEMBL::DBSQL::Obj;
use Bio::EnsEMBL::DB::ContigI;

use Bio::SeqIO::Fasta;


@ISA = qw(Bio::Root::Object Bio::EnsEMBL::DB::ContigI);
# new() is inherited from Bio::Root::Object

# _initialize is where the heavy stuff will happen when new is called

sub _initialize {
  my($self,@args) = @_;

  my $make = $self->SUPER::_initialize;

  my ($dbobj,$id) = $self->_rearrange([qw(DBOBJ
					  ID
					  )],@args);

  $id || $self->throw("Cannot make contig db object without id");
  $dbobj || $self->throw("Cannot make contig db object without db object");
  $dbobj->isa('Bio::EnsEMBL::DBSQL::Obj') || $self->throw("Cannot make contig db object with a $dbobj object");

  $self->id($id);
  $self->_dbobj($dbobj);

# set stuff in self from @args
  return $make; # success - we hope!
}

=head2 get_all_Genes

 Title   : get_all_Genes
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_all_Genes{
   my ($self,@args) = @_;
   my @out;
   my $contig_id = $self->id();
   # prepare the SQL statement
   my %got;

   my $sth = $self->_dbobj->prepare("select p3.gene from transcript as p3, exon_transcript as p1, exon as p2 where p2.contig = '$contig_id' and p1.exon = p2.id and p3.id = p1.transcript");

   my $res = $sth->execute();
   while( my $rowhash = $sth->fetchrow_hashref) {
       if( $got{$rowhash->{'gene'}} != 1 ) {
          my $gene = $self->_dbobj->get_Gene($rowhash->{'gene'});
	  push(@out,$gene);
	  $got{$rowhash->{'gene'}} = 1;
       }
       
   }
   

   return @out;

}


=head2 seq

 Title   : seq
 Usage   : $seq = $contig->seq();
 Function: Gets a Bio::Seq object out from the contig
 Example :
 Returns : Bio::Seq object
 Args    :


=cut

sub seq{
   my ($self) = @_;
   my $id = $self->id();

   if( $self->_seq_cache() ) {
       return $self->_seq_cache();
   }

   my $sth = $self->_dbobj->prepare("select filename,byteposition from dnafindex where contigid = \"$id\"");
   my $res = $sth->execute();
   my $rowhash = $sth->fetchrow_hashref();
   my $filename = $rowhash->{'filename'};
   my $byteposition = $rowhash->{'byteposition'};

   if( ! defined $filename ) {
       $self->throw("Contig $id does not have an entry in dnafindex table!");
   }

   my $fh = $self->_dbobj->_dna_filehandle($rowhash->{'filename'});
   $fh->seek($byteposition,0);
   
   my $seqio = Bio::SeqIO::Fasta->new( -fh => $fh );
   my $ret = $seqio->next_seq();
   if( !defined $ret ) {
       $self->throw("Unable to read sequence $id from $filename at $byteposition");
   }

   $self->_seq_cache($ret);
   
   return $ret;

  # Old, direct table access.

#     my $sth = $self->_dbobj->prepare("select sequence from dna where contig = \"$id\"");
#     my $res = $sth->execute();

#     # should be a better way of doing this
#     while(my $rowhash = $sth->fetchrow_hashref) {
#       my $str = $rowhash->{sequence};

#       if( ! $str) {
#         $self->throw("No DNA sequence in contig $id");
#       } 
#       $str =~ /[^ATGCNRY]/ && $self->warn("Got some non standard DNA characters here! Yuk!");
#       $str =~ s/\s//g;
#       $str =~ s/[^ATGCNRY]/N/g;

#       my $ret =Bio::Seq->new ( -seq => $str, -id => $id, -type => 'Dna' );
#       $self->_seq_cache($ret);
     
#       return $ret;
#     }

#     $self->throw("No dna sequence associated with $id!");
   
}

=head2 _seq_cache

 Title   : _seq_cache
 Usage   : $obj->_seq_cache($newval)
 Function: 
 Returns : value of _seq_cache
 Args    : newvalue (optional)


=cut

sub _seq_cache{
   my $obj = shift;
   if( @_ ) {
       my $value = shift;
       $obj->{'_seq_cache'} = $value;
   }
   return $obj->{'_seq_cache'};

}

=head2 get_all_SeqFeatures

 Title   : get_all_SeqFeatures
 Usage   : foreach my $sf ( $contig->get_all_SeqFeatures ) 
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_all_SeqFeatures{
   my ($self,@args) = @_;
   my @array;

   my $id = $self->id();

   # make the SQL query

   my $sth = $self->_dbobj->prepare("select start,end,strand,score,analysis from feature where contig = \"$id\"");
   my $res = $sth->execute();

   while( my $rowhash = $sth->fetchrow_hashref) {
      my $out = new Bio::SeqFeature::Generic;
      $out->start($rowhash->{start});
      $out->end($rowhash->{end});
      $out->strand($rowhash->{strand});
      if( defined $rowhash->{score} ) {
	  $out->score($rowhash->{score});
      }
      $out->primary_tag($rowhash->{analysis});
      $out->source_tag('EnsEMBL');
      push(@array,$out);
  }
 
   return @array;
}

=head2 length

 Title   : length
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub length{
   my ($self,@args) = @_;
   my $id= $self->id();

   my $sth = $self->_dbobj->prepare("select length from contig where id = \"$id\" ");
   $sth->execute();
   my $rowhash = $sth->fetchrow_hashref();
   return $rowhash->{'length'};
}


=head2 order

 Title   : order
 Usage   : $obj->order($newval)
 Function: 
 Returns : value of order
 Args    : newvalue (optional)


=cut

sub order{
   my $self = shift;
   my $id = $self->id();
   my $sth = $self->_dbobj->prepare("select corder from contig where id = \"$id\" ");
   $sth->execute();
   my $rowhash = $sth->fetchrow_hashref();
   return $rowhash->{'corder'};
   
}

=head2 offset

 Title   : offset
 Usage   : 
 Returns : 
 Args    :


=cut

sub offset{
   my $self = shift;
   my $id = $self->id();

   my $sth = $self->_dbobj->prepare("select offset from contig where id = \"$id\" ");
   $sth->execute();
   my $rowhash = $sth->fetchrow_hashref();
   return $rowhash->{'offset'};

}


=head2 orientation

 Title   : orientation
 Usage   : 
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub orientation{
   my ($self) = @_;
   my $id = $self->id();

   my $sth = $self->_dbobj->prepare("select orientation from contig where id = \"$id\" ");
   $sth->execute();
   my $rowhash = $sth->fetchrow_hashref();
   return $rowhash->{'orientation'};
}


=head2 id

 Title   : id
 Usage   : $obj->id($newval)
 Function: 
 Example : 
 Returns : value of id
 Args    : newvalue (optional)


=cut

sub id{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'id'} = $value;
    }
    return $self->{'id'};

}

=head2 _dbobj

 Title   : _dbobj
 Usage   : $obj->_dbobj($newval)
 Function: 
 Example : 
 Returns : value of _dbobj
 Args    : newvalue (optional)


=cut

sub _dbobj{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'_dbobj'} = $value;
    }
    return $self->{'_dbobj'};

}

