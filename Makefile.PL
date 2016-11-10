#!/usr/bin/env perl
# IMPORTANT: if you delete this file your app will not work as
# expected.  You have been warned.

use inc::Module::Install;

name 'stefans_libs-RInterface';
version_from 'lib/stefans_libs/RInterface.pm';
author 'Whoever you are <your email>';

#requires	'DBI' => 0;
requires	'IO::Socket::INET' => 0;
opendir( DIR, 'bin/' ) or die "I could not open the bin folder
$!
";
map { install_script "bin/$_" } grep !/^./,  grep '*.pl', readdir(DIR);
close ( DIR );


auto_install();
WriteAll();
