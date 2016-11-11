#! /usr/bin/perl
use strict;
use warnings;
use Test::More tests => 10;
BEGIN { use_ok 'stefans_libs::RInterface' }

use FindBin;
my $plugin_path = "$FindBin::Bin";

my ( $value, @values, $exp );

system("rm -Rf $plugin_path/data/outpath/*" ) if ( -d "$plugin_path/data/outpath/");

my $OBJ = stefans_libs::RInterface -> new({'debug' => 1, 'path' => "$plugin_path/data/outpath/" });
is_deeply ( ref($OBJ) , 'stefans_libs::RInterface', 'simple test of function stefans_libs::RInterface -> new() ');

my $port = 6013;
$OBJ -> init_R_server ( $port );

warn "Is the R process running?\n";

system( "ps -Af | grep $OBJ->{'processes'}->{$port}");

ok ( ! -f "$OBJ->{'path'}/output.txt", "R output does not exist" );

$OBJ -> send2R ( 'print ("I got data!")'."\n".'write ("This has really come from the perl process!", file="'.$port.'.output.txt")', $port);

ok ( -f "$OBJ->{'path'}/$port.input.R", "message file sent" );

sleep( 3);

ok ( ! -f "$OBJ->{'path'}/$port.input.R", "message file processed by R" );

ok ( -f "$OBJ->{'path'}/$port.output.txt", "R output created" );

$port = 6017;

$OBJ -> init_R_server ( $port );

system( "ps -Af | grep $OBJ->{'processes'}->{$port}");

ok ( ! -f "$OBJ->{'path'}/output.txt", "R output does not exist" );

$OBJ -> send2R ( 'print ("I got data!")'."\n".'write ("This has really come from the perl process!", file="'.$port.'.output.txt")', $port);

ok ( -f "$OBJ->{'path'}/$port.input.R", "message file sent" );

sleep( 3);

ok ( ! -f "$OBJ->{'path'}/$port.input.R", "message file processed by R" );

ok ( -f "$OBJ->{'path'}/$port.output.txt", "R output created" );

$OBJ ->shut_down_server(6013);
$OBJ ->shut_down_server(6017);


#print "\$exp = ".root->print_perl_var_def($value ).";\n";



