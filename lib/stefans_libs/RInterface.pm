package stefans_libs::RInterface;

#use FindBin;
#use lib "$FindBin::Bin/../lib/";
use strict;
use warnings;

use Cwd;
use IO::Socket::INET;

=head1 LICENCE

  Copyright (C) 2016-11-10 Stefan Lang

  This program is free software; you can redistribute it 
  and/or modify it under the terms of the GNU General Public License 
  as published by the Free Software Foundation; 
  either version 3 of the License, or (at your option) any later version.

  This program is distributed in the hope that it will be useful, 
  but WITHOUT ANY WARRANTY; without even the implied warranty of 
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License 
  along with this program; if not, see <http://www.gnu.org/licenses/>.


=for comment

This document is in Pod format.  To read this, use a Pod formatter,
like 'perldoc perlpod'.

=head1 NAME

stefans_libs::RInterface

=head1 DESCRIPTION

A new lib names stefans_libs::RInterface.

=head2 depends on


=cut

=head1 METHODS

=head2 new ( $hash )

new returns a new object reference of the class stefans_libs::RInterface.
All entries of the hash will be copied into the objects hash - be careful t use that right!

=cut

sub new {

	my ( $class, $hash ) = @_;

	my ($self);

	$self = {};
	foreach ( keys %{$hash} ) {
		$self->{$_} = $hash->{$_};
	}
	unless ( -d $self->{'path'} ) {
		$self->{'path'} = Cwd::getcwd();
		Carp::confess ( ref($self)
		  . "::new I need to set the path to $self->{'path'}\n$!\n");

	}
	$self->{'processes'} = {};
	bless $self, $class if ( $class eq "stefans_libs::RInterface" );

	return $self;

}

sub port_4_user {
	my ( $self, $user, $project, $server_funct ) = @_;
	Carp::confess("Need a project name to register an R object!")
	  unless ( defined $project );
	$self->{'users'} ||= {};
	$self->{'users'}->{$user} ||= {};
	unless ( $self->{'users'}->{$user}->{$project} ) {
		$self->{'users'}->{$user}->{$project} =
		  scalar( keys %{ $self->{'processes'} } );
		$self->init_R_server( $self->{'users'}->{$user}->{$project},
			$server_funct );
	}
	return $self->{'users'}->{$user}->{$project};
}

sub init_R_server {
	my ( $self, $port, $server_funct ) = @_;
	$port = 6011 unless ( defined $port );
	if ( defined $server_funct ) {
		$server_funct =~ s/##PATH##/$self->{'path'}/g;
		$server_funct =~ s/##PORT##/$port/g;
	}
	else {
		$server_funct ||=
		    "server <- function(){\n"
		  . "  while(TRUE){\n"
		  . "        if ( file.exists( '$self->{'path'}/$port.input.R') ) {\n"
		  . "                while ( file.exists('$self->{'path'}/$port.input.lock') ) {\n"
		  . "                        sleep( 2 )\n"
		  . "                }\n"
		  . "                source( '$self->{'path'}/$port.input.R' )\n"
		  . "                file.remove('$self->{'path'}/$port.input.R' )\n"
		  . "        }\n"
		  . "        Sys.sleep(2)\n" . "  }\n" . "}\n"
		  . "setwd('$self->{'path'}')\n"
		  . "server()\n";
	}

	unless ( $self->{'processes'}->{$port} ) {
		my $file = "$self->{'path'}/server_$port.R";

		foreach ( map { "$self->{'path'}/$port$_" } '.input.R', '.input.lock' )
		{
			unlink($_) if ( -f $_ );
		}

		open( RS, ">$file" )
		  or die "Could not create the server R script ($file)\n$!\n";

		print RS $server_funct;

		close(RS);
		
		$self->spawn_R( $port );
	}

}

sub spawn_R {
	my ( $self, $port ) = @_;
	$port = 6011 unless ( defined $port );
	my $file = "$self->{'path'}/server_$port.R";
	return $self if ( $self->is_running($port) );
	$self->{'processes'}->{$port} = undef;
	if ( $self->{'processes'}->{$port} = fork ) {    # first fork  we are parent
		return $self;
	}
	elsif ( defined $self->{'processes'}->{$port} ) {    # so we are a child
		warn
"I am starting the R interface $self->{'processes'}->{$port} using file $file\n";
		exec(
'/bin/bash -c "DISPLAY=:7 R CMD BATCH --no-save --no-restore --no-readline -- '
			  . $file
			  . '"' );
		exit(0);    # we should never reach this
	}

	else {
		die "Error in spawning a new R instance: $!\n";
	}
	return $self;
}

sub DESTROY {
	my $self = shift;
	foreach ( keys %{ $self->{'processes'} } ) {
		$self->shut_down_server($_);
	}
}

sub shut_down_server {
	my ( $self, $port ) = @_;
	$port = 6011 unless ( defined $port );
	if ( defined $self->{'processes'}->{$port} ) {
		$self->send_2_R( "q('yes')", $port );
		sleep(4);
		unlink("$self->{'path'}/$port.input.R")
		  ;    ## this command does not allow the R process to clean up

		#warn "kill -15 ". getpgrp ($self->{'processes'}->{$port})."\n";
		#kill -15 => getpgrp($self->{'processes'}->{$port});
		$self->{'processes'}->{$port} = undef;
	}
}

sub send_2_R {
	my ( $self, $message, $port ) = @_;
	$port = 6011 unless ( defined $port );
	if ( defined $message ) {
		while ( -f "$self->{'path'}/$port.input.lock" ) {
			warn "R process $port is not finished\n";
			sleep(2);
		}
		open( LOCK, ">$self->{'path'}/$port.input.lock" ) or die $!;
		print LOCK "PERL";
		close(LOCK);

		open( OUT, ">$self->{'path'}/$port.input.R" ) or die $!;
		print OUT $message . "\n";
		close(OUT);

		unlink("$self->{'path'}/$port.input.lock");
	}
	return $self;
}

sub is_running {
	my ( $self, $port ) = @_;
	$port = 6011 unless ( defined $port );
	open( IN, "ps -Af | grep server_$port.R |" )
	  or die "could not start pipe\n$!\n";
	my @in = <IN>;
	warn join("",@in)."\n";
	if ( scalar( @in ) <= 2 ) {
		#warn "server has crashed?!\n";
		map {
			unlink( $self->{'path'} . "/$_" )
			  if ( -f $self->{'path'} . "/$_" )
		} "$port.input.lock", "$port.input.R";
		return 0;
	}
	if ( scalar(@in) > 5 ) {
		Carp::confess ( "Multiple server instances spawned - should absolutely not happen!\n".join('', @in) );
	}
	return 1;
}

sub get_socket {
	my ( $self, $port ) = @_;
	$port = 6011 unless ( defined $port );

	my $socket = IO::Socket::INET->new(

		#	Listen    => 5,
		LocalAddr => 'localhost',
		LocalPort => $port,
		Type      => SOCK_STREAM(),
		Blocking  => 1,
	);
	unless ( defined $socket ) {
		Carp::confess("I can not connect to loclhost:$port\n$!\n");
	}
	Carp::confess($socket);

	#$socket ->bind($port, 'localhost');
	$socket->autoflush(1);
	return $socket;
}

1;
