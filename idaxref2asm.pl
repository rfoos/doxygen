#!/usr/bin/perl
#
# @file
# idaxref2sub.pl - From an IDA-Pro XREF file (gdl), extract subroutine names,
#	and then extract the source code for those subroutines from the original asm file.
#	Second, remap the names from location based to functional names.
#
#       Copyright (C) 2009 Rick Foos, SolengTech
#               (rick.foos AT solengtech.com)
#           http://www.solengtech.com/downloads
#	 With many ideas from Bogdan 'bogdro' Drozdowski's asm4doxy
#		(bogdandr AT op.pl, bogdro AT rudy.mif.pg.gda.pl)
#		http://rudy.mif.pg.gda.pl/~bogdro/inne/
#
#	License: GNU General Public Licence v3+
#
#	Last modified : 2009-08-15
#
#	Syntax:
#		./idaxref2asm.pl aaa.asm bbb.asm ccc/ddd.asm
#		./idaxref2asm.pl --help|-help|-h
#
#	Documentation comments should start with ';;' or '/**' and
#	 end with ';;' or '*/'.
#
#	Examples:
#
#	;;
#	; This procedure reads data.
#	; @param CX - number of bytes
#	; @return DI - address of data
#	;;
#	procedure01:
#		...
#		ret
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation:
#		Free Software Foundation
#		51 Franklin Street, Fifth Floor
#		Boston, MA 02110-1301
#		USA

use strict;
use warnings;
use Cwd;
use File::Spec::Functions ':ALL';
use Getopt::Long;
use PerlIO::encoding;
use IO::Handle;

if ( @ARGV == 0 ) {
	print_help ();
	exit 1;
}

Getopt::Long::Configure ("ignore_case", "ignore_case_always");

my $help='';
my $lic='';
my $encoding='iso-8859-1';
my $odir='';
my $remove='';
my $unmap='';
if ( !GetOptions (
	'encoding=s'			=> \$encoding,
	'h|help|?'			=> \$help,
	'license|licence|l'	=> \$lic,
	'output-directory|odir|od'		=> \$odir,
	'rm|remove|'	=> \$remove,
	'un|unmap|'	=> \$unmap,
	)
   )
{
	print_help ();
	exit 2;
}

if ( $lic )
{
	print	"IdaXref2asm - a program for converting specially-formatted assembly\n".
		"language files into something Doxygen can understand.\n".
		"See http://www.solengtech.com/downloads\n".
		"Author: Rick Foos, rick.foos # solengtech.com.\n\n".
		"Inspired by Asm4doxy: Bogdan 'bogdro' Drozdowski, bogdro # rudy.mif.pg.gda.pl.\n\n".
		"    This program is free software; you can redistribute it and/or\n".
		"    modify it under the terms of the GNU General Public License\n".
		"    as published by the Free Software Foundation; either version 3\n".
		"    of the License, or (at your option) any later version.\n\n".
		"    This program is distributed in the hope that it will be useful,\n".
		"    but WITHOUT ANY WARRANTY; without even the implied warranty of\n".
		"    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\n".
		"    GNU General Public License for more details.\n\n".
		"    You should have received a copy of the GNU General Public License\n".
		"    along with this program; if not, write to the Free Software Foundation:\n".
		"		Free Software Foundation\n".
		"		51 Franklin Street, Fifth Floor\n".
		"		Boston, MA 02110-1301\n".
		"		USA\n";
	exit 1;
}

# if "HELP" is on the command line or no files are given, print syntax
if ( $help || @ARGV == 0 )
{
	print_help ();
	exit 1;
}

# if TEST file (asm4doxy-xx.pl), modify output file with test xx, and coded options.
my ($testname) = $0;
$testname =~ s/.*(-)(\w+)\.pl*$/$2/;
if ($testname eq $0)
{
	$testname = "";
}
else
{
	$testname .= "-od" if ($odir);
	#$testname .= "-ud" if ($undoc);
	#$testname .= "-ns" if ($nosort);
	#$testname .= "-id" if ($idapro);
}

my ($disk, $directory, undef) = splitpath (cwd (), 1);

my @files = sort @ARGV;
my (%files_gdl,$gdl_todo,%files_remap,%files_unmap,$remap_todo,$asm_todo);
$gdl_todo = $remap_todo = $asm_todo = 0;
foreach my $p (@files)
{
	if ( $p =~ /\.gdl/io )
	{
		$gdl_todo++;
		open(my $gdl, "<:encoding($encoding)", catpath($disk, $directory, $p)) or
			die "$0: ".catpath($disk, $directory, $p).": $!\n";
		while (<$gdl>)
		{
			if ( /^.*(label\:)\s*['"]?(\w*)['"]?/io )
			{
				$files_gdl{$2} = $2;
			}
		}
		close $gdl;
	}
	if ( $p =~ /\.remap/io )
	{
		$remap_todo++;
		open(my $remap, "<:encoding($encoding)", catpath($disk, $directory, $p)) or
			die "$0: ".catpath($disk, $directory, $p).": $!\n";
		while (<$remap>)
		{
			if ( /^\s*((sub_|loc_|off_|byte_|word_|dword_)\w+)\s*(\w+)/io )
			{
				die "Duplicate sub/loc key:\n".$_."\n Original value: ".$1." ".$files_remap{$1}."\n in file ".$p."\n"
					if (defined ($files_remap{$1}));
				die "Duplicate unmap key: ".$_."\n Original value: ".$1." ".$files_unmap{$3}."\n in file ".$p."\n"
					if (defined ($files_unmap{$3}));
				$files_remap{$1} = $3;
				$files_unmap{$3} = $1;
			}
		}
		close $remap;
	}
	elsif ( $p =~ /\.asm/io )
	{
		$asm_todo++;
	}
}

$encoding     =~ tr/A-Z/a-z/;



my ($rmap0,$rmap1,$rmap_line,$umap0,$umap1,$umap_line);

$gdl_todo = 0 if ( ! (%files_gdl));
$remap_todo = 0 if ( ! (%files_remap));
die "No ASM files, nothing todo...\n" if ($asm_todo == 0);
print "No GDL files, no extractions todo...\n" if ($gdl_todo == 0);
print "No REMAP files, no remapping todo...\n" if ($remap_todo == 0);

my (%files_descr);

# =================== Reading input files, output on the fly =================
foreach my $p (@files)
{
	next if ( $p !~ /.asm/io );
	# Hash array key is the filename with dashes instead of dots.
	my $key;
	$key = (splitpath $p)[2];
	$key =~ s/\./-/g;

	my ($inside_func, $func_name, $pre_func );
	$inside_func = 0;
	$func_name = "";
	$pre_func = 0;


	open(my $asm, "<:encoding($encoding)", catpath($disk, $directory, $p)) or
		die "$0: ".catpath($disk, $directory, $p).": $!\n";

	my $keypath='.';
	if ($odir)
	{
         $keypath = (splitpath $p)[1] or $keypath=".";
	}
	$p = (splitpath $p)[2];

	open(my $dox, ">:encoding($encoding)", catfile($keypath,$key.".asm")) or die "$0: catfile($keypath,$key): $!\n";


	# find subroutines (do while)
	PROCGL: while ( <$asm> )
	{
		# Keep it simple...
		if (!$gdl_todo)
		{}
		# MASM PROC
		elsif ( ! $inside_func && /^\s*(\w+):?\s+(proc)/io )
		{
			$pre_func = 0;
			# Controls subroutines in or out of output.
			if ( ! defined ($files_gdl{$1}) )# && $remove)
			{
			$inside_func = 1;
			$func_name = $1;
			}
			# Dump the header comments we have been collecting.
			else
			{
				$inside_func = 0;
				print $dox $files_descr{$key};
			}
		}
		# IDA-Pro Subroutine comment start (MASM PROC)
		elsif (! $inside_func && ((/^;.*(S\s+U\s+B)/o)) )
		{
			$pre_func = 1;
			$inside_func = 0;
			$files_descr{$key} = "";
		}
		# MASM Proc End, we know we are discarding.
		elsif ( $inside_func && /^\s*(\w+):?\s+(endp)/io )
		{
			$inside_func = 0;
			$_ = <$asm>;
		}

		# Inside Function
		if ( $gdl_todo && $inside_func )
		{
			# strip lines for now
		}
		# Header Coomments
		elsif ( $gdl_todo && $pre_func)
		{
			# lines for now
			$files_descr{$key} .= $_;
		}
		# Keep original file contents and order.
		else
		{
			if ($remap_todo)
			{
				while ( ($rmap0,$rmap1) = each %files_remap)
				{
					( $rmap0, $rmap1 ) = ($rmap1, $rmap0) if ($unmap);
					$rmap_line = $_;
					$rmap_line =~ s/$rmap0/$rmap1/g;
					$umap_line = $rmap_line;
					$umap_line =~ s/$rmap1/$rmap0/g;
					if (  (!$unmap && ($umap_line ne $_)) &&
						($unmap && ($rmap_line ne $_)) )
					{
						die "Remap failed:\n orig: $_ umap: $umap_line rmap: $rmap_line key $rmap0, $rmap1\n". \
						    " Unmap Mode $unmap\n";
					}
					$_ = $rmap_line;
				}
			}
			print $dox $_;
		}

	}

	if ( ! defined $_ )
	{
		close $asm;
		close $dox;
		next;
	}
}

END { close(STDOUT) || die "$0: Can't close stdout: $!"; }
