#!/usr/bin/perl
##
# With the demoversion of idapro you can create graphs in various forms.
# The output from the program
# handling the graph generation could be better, the graphs are abit
# cubic. The graphviz package
# on other hand can do quite nice graphs so I wrote a converter. I also
# made a filter function capable
# of filtering out regular functions (printf etc) that would otherwise
# pollute the graph. Syntax to use it:
#
# perl gdl2dot.pl -f test.gdl with filter activated or
# perl gdl2dot.pl -p test.gdl without

# the output will be a test.gdl.dot file and a test.gdl.ps postscriptfile.

# MvH
# Benjamin Larsson
# http://www.nabble.com/-codec-devel--wingraph-to-graphviz-converter-td1495495.html 
#
# rlf - usage in project.
# 1. Generate XREF in IDA and save as GDL file.
# 2. gdl2dot.pl -p xref.gdl
#    dot -Tjpg -Oxref.dot.jpg xref.gdl.dot
#


#Argument parser

if (@ARGV){
  print "@ARGV\n";
  if ($ARGV[0] eq "-f"){
    $FILE1 = $ARGV[1];
    $filter = 1;
  }
  if ($ARGV[0] eq "-p"){
    $FILE1 = $ARGV[1];
    $filter = 0;
  }
}
else{
  print "Usage:\n";
  print "./gdl2dot.pl [command] binary\n";
  print "-f input datafile use filter\n";
  print "-p input datafile don't use filter\n";
  exit;
}

# File IO

open(OUTFILE, ">".$FILE1.".dot") or die "File doesn't exist\n";
@indata = `cat $FILE1`;
$nods = 0;
$links= 0;
foreach $rad (@indata)
{
    if ($rad =~ m/node:/) {
        #print STDOUT "$rad";
        @tmpsplit=split / /,$rad;
        #print "$tmpsplit[5]\n";
        $nodnames[$nods]=$tmpsplit[5];
        $nods++;
    }
    if ($rad =~ m/edge:/) {
        @tmpsplit=split / /,$rad;

        $tmpsplit[3] =~ s/"//g;
        #print "$tmpsplit[3]\n";
        $linkfrom[$links] = $tmpsplit[3];
        $tmpsplit[5] =~ s/"//g;
        $linkto[$links] =$tmpsplit[5];
        $links++;
    }
}

print OUTFILE "digraph prof {\n";
for ($i=0 ; $i < $links ; $i++){
    if ($filter==1) {
        if (namecheck($nodnames[$linkto[$i]])) {
            print OUTFILE "\t$nodnames[$linkfrom[$i]] -> $nodnames[$linkto[$i]]\n";
        }
    } else {
        print OUTFILE "\t$nodnames[$linkfrom[$i]] -> $nodnames[$linkto[$i]]\n";
    }
}
print OUTFILE "}\n";
close OUTFILE;
print "$nods nods found and $links links.\n";
print "Generateing postscriptfile...\n";
$doit = `dot -Tps $FILE1.dot \> $FILE1.ps`;
print "Done!\n";

sub namecheck
{
    my $k;
    $result=1;
    #This might match on names that are not intended
    if ($_[0] =~ m/fprintf/) {$result = 0;}
    if ($_[0] =~ m/printf/) {$result = 0;}
    if ($_[0] =~ m/malloc/) {$result = 0;}
    if ($_[0] =~ m/calloc/) {$result = 0;}
    if ($_[0] =~ m/free/) {$result = 0;}
    if ($_[0] =~ m/memset/) {$result = 0;}
    if ($_[0] =~ m/memcpy/) {$result = 0;}
    if ($_[0] =~ m/memmove/) {$result = 0;}
    if ($_[0] =~ m/ceil/) {$result = 0;}
    if ($_[0] =~ m/floor/) {$result = 0;}
    if ($_[0] =~ m/sin/) {$result = 0;}
    if ($_[0] =~ m/cos/) {$result = 0;}
    if ($_[0] =~ m/pow/) {$result = 0;}
    if ($_[0] =~ m/exp/) {$result = 0;}
    if ($_[0] =~ m/log/) {$result = 0;}
    if ($_[0] =~ m/sqrt/) {$result = 0;}
    if ($_[0] =~ m/atan/) {$result = 0;}
    if ($_[0] =~ m/asin/) {$result = 0;}
    if ($_[0] =~ m/fopen/) {$result = 0;}
    if ($_[0] =~ m/fseek/) {$result = 0;}
    if ($_[0] =~ m/fread/) {$result = 0;}
    if ($_[0] =~ m/fclose/) {$result = 0;}
    if ($_[0] =~ m/fflush/) {$result = 0;}
    if ($_[0] =~ m/fwrite/) {$result = 0;}
    if ($_[0] =~ m/ferror/) {$result = 0;}
    if ($_[0] =~ m/__assert_fail/) {$result = 0;}
    $result;
}

