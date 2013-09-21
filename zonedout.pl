#!/usr/bin/perl 
#===============================================================================
# Kismet XML parser to generate wireless signal zone outputs
# Name: zonedout.pl 
# Version: 2.5
#                      
# Feedback: send feedback to rajats@gmail.com (www.rajatswarup.com)
# 
# What's new: 
# 1. Google Earth 7.x support
# 2. The isometric view is enabled by default
# 3. The height of the polygon is a weighted indicator of the signal strength
#===============================================================================

use strict;
use warnings;
use Math::ConvexHull  qw/convex_hull/;
use Math::NumberCruncher;
use XML::Simple;
use XML::Generator;
use Data::Dumper;
use Getopt::Std;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

my $VERSION = "2.5";
my $AUTHOR = "Rajat Swarup";
my $AUTHOREMAIL = "rajats\@gmail.com";
my $DEBUG = 0;
my $transparency = '55';
my $HEIGHT = '45';
my ($minpower,$maxpower)  = undef;

# Older kismet files set signal to 0 if the card does not provide it
# newer files appear to not set the signal at all
my $seensignal  = 0;
my %waps;
my $outputfileprefix = "default";
my $prefix  = ""; #$ARGV[0]  or die "Please specify a prefix for gps and xml files";

my ($gpsin,$xmlin);
our($opt_k,$opt_o,$opt_h);

getopt('koh');
&process_cmd_line();
if (-r "$prefix.gps" && -r "$prefix.xml") {
  $gpsin = XMLin("$prefix.gps") or die "Failed to parse gps input file";
  $xmlin = XMLin("$prefix.xml") or die "Failed to parse xml input file";
  parse_gps();
} elsif (-r "$prefix.gpsxml" && -r "$prefix.netxml") {
  $gpsin = XMLin("$prefix.gpsxml") or die "Failed to parse gps input file";
  $xmlin = XMLin("$prefix.netxml") or die "Failed to parse xml input file";
  parse_gpsxml();
} else {
  die "Either the gps or xml file is unreadable";
}

sub print_usage()
{
  print <<"END";

+============================================+
|    zonedout.pl - Version $VERSION              |
|    Author: $AUTHOR 	             |
|            $AUTHOREMAIL                |
|     Kismet Zone Output - come get some!    |
+============================================+

Usage:	perl $0 {-k kismet prefix for gpsxml/netxml} {-o outputprefix}

        -k  [Kismet netxml & gpsxml prefix - both files are required]
        -o  [Output file prefix: output will add a .kmz extension]
        -h  help! 
Please report bugs / feedback to rajats -a-t- gmail.com
www.rajatswarup.com

8888888888P  .d8888b.            .d8888b.       888  .d8888b.           888    
      d88P  d88P  Y88b          d88P  Y88b      888 d88P  Y88b          888    
     d88P   888    888               .d88P      888 888    888          888    
    d88P    888    888 88888b.      8888"   .d88888 888    888 888  888 888888 
   d88P     888    888 888 "88b      "Y8b. d88" 888 888    888 888  888 888    
  d88P      888    888 888  888 888    888 888  888 888    888 888  888 888    
 d88P       Y88b  d88P 888  888 Y88b  d88P Y88b 888 Y88b  d88P Y88b 888 Y88b.  
d8888888888  "Y8888P"  888  888  "Y8888P"   "Y88888  "Y8888P"   "Y88888  "Y888 
END
}


sub process_cmd_line()
{
  # Get the Flags and their respective values from the command line.

  if ($opt_h)
  {
    &print_usage();
    exit -1;
  }
  if ( !(defined ($opt_k)) || !(defined($opt_o)))  
  {
     print STDERR "\n\t\tERROR: Insufficient arguments\n";
     &print_usage();
     exit;
  }
  if (defined $opt_o) 
  {
     $outputfileprefix = $opt_o;
     # If the output file name does not end with .csv or .CSV
  }	
  else { print STDERR "\n\tERROR: The output file\: $outputfileprefix must be given\n"; exit; }  
  # open the input file for reading:
  if (defined $opt_k)
  {
     $prefix=$opt_k;
  }
  return;
}
sub create_kmz {
  my $kml_file = shift;
  $kml_file .= ".kml";
  my $openapjpg="iVBORw0KGgoAAAANSUhEUgAAAC4AAAAyCAYAAAAjrenXAAAAAXNSR0IArs4c6QAAAAlwSFlzAAAH".
	"/wAAB/8BXW1oEQAAAAd0SU1FB9oJGwE4CgPxGNQAABNTSURBVGjerZp7tKdVWcc/e+/39rucKzMw".
	"DAg6iIiFQoOCFl1cM5qCKMigptwCocBMKINEvCQKrS6WSTHMpAiYMrMwIjNJNKPMlUCGmUHAiIMy".
	"w8yZOef8Lu9tX57+eN9zZgYhXdVvrb1+57ffy372d3+fZz/Pdx+kFKR0iIwQWUDqIZvfew2X/fxr".
	"kd0DxI0IkiO+JogwJ8JeERaLIUFqrFgqsTjxBPFIEMQLUrXNC0GEUoSxCCMRKhHEe8R5xAu2LpFQ".
	"Ib5ErCClICPhyx+/ibevXIXsegLxu5j3cxTtO5BaECeIDJHxDr76ic2ckPZ4xdSh3Hvr7Ug9wkmO".
	"SI31joEIA5HWyIogFieWsGS4SGN83TYvuNbYom122fBm7PFogEiJc6Nm0raZ9Emzh3JWf4qzprpI".
	"tQuRIWVwlCJoF0NQDqoaVMKHL72cNROzKAynnHUWxBGBgHUVSnlioAMoL1A4lNeYoFFAADwgCjBN".
	"Ew0CaCAC0vYb1XYq6PZ6VLbAGE1QNYPREAy86swzGEogTTq899QNsGdEaj0KYH4JvWKei1/yIt6U".
	"TfJaJpDte5DS42zOqJhDJEdCiYjHW4dYj9Rtcx5pEQ/SUEPa5lqE3VJ/aNvS6vj2txsQyjlEyuX3".
	"SC28/nlHsU4bzl9x8Izs2YNUzXWtgLrM4fHvM//QI8ymXY44/DDIMog0JoroZV2wHsY5YWERrRQA".
	"OA9ag9IgGiUaJQ2Yvm16H/i0TwEg6H0/KgdVQGkFWIbVEN/cxJ3fuI+pgw5BLxbXX/C8YzYwGqLE".
	"ojWQRhlvP+10uoG1i9WIP7v/6zDRpS5tM1xVQ+l41dHH8Mqffjk+H0HtII2XlxtpubLU2i4loEL7".
	"o6WIqOVbQODqd7yLXzjsuWy59npksJeJNGleY4DeJIc9/2iGdnjJdJpsJXhwFbpTWLCe4fYnkeC3".
	"mdWz0DcEW5F042aEccVFxx5Pf1CxuGsXpt9B0gjRUCtwS1AuGS3LNv7QRJZWYrmzFO7/+39klSTc".
	"8pHfQ6UdlK/x3qM0EBn+eMtWJmdXMTfcyzte82qwFh0pw2evvY7JJBGM5pZ7vwwdjXSTZqTawQ+e".
	"ot49TyfAMS84GpQHAx7BLDkbT+PCfojuf9kIRIR9RDGKu++7nzAaM60STj/qBRCEjjHUS8/OzLC7".
	"HlPgefLRR6ByaGrLrTf8Kc77q+o0mmflFIUGb1orvOLUV5xCN4o2Bjyf/bu7GeZjIOBGI4wNMMwb".
	"PkQ03xpqPA5p/i7zdkUC1DXYgAq+QT0GUs1pZ56JDoLeM4IndmLzIUa3TuIs51/+DmwCkXPwgx+g".
	"yXOm4ojKh9+dPPxwMAZLjAPwAsMRfVHM5YuXnHHeOZDE9LuTuLomSzowNwISxuMRw1AirfEiHoOA".
	"DiRZjHMVeA9lgNKCc3hXN14bKc75s49jTUxWBS59/VnESdbg5oFOhzN+7Z10p6aJreUv3v1baJQw".
	"WpwnN4qPbtoMptNyUUB5br7i3WQhzCSHr+Ls910JAZQo4gCMSy487iROX/Vcbr/9MwQdUROoQk2o".
	"KwyB+YU9EEEUawiB9asO4/TnPJ/i+09gjMITsCGHFA474Tim077MPfRdKMeUdY6JgSAw0efJXbuZ".
	"TDry4L1fE/3wpo10EwNZSvcla8GnZCQEayF4vnzXnYS6mt9Zj+HglaASCBpE8aHzzsftmSdzgZcc".
	"9yICHuvGpFrRjxNUnjMzMQlVBeJgOGA2yTDjnNecfArYGk1AdTLopfz+rbcxKgt1cHeSx7/5TfpJ".
	"3DqHAMLqI4/E5yWmqNF/e9fnCHVFlGVQOsgFbWEyTqAuCfkAE8naU059DUQR6BhZLEECX/vyPWRp".
	"hIk1a192IoqSvoqhDNy39a/Y+P4Pw+5FcAHEw0SHK37zXayY6pMVJX779wllTgBKBA49hIn+CvLh".
	"+MpP3XADlEXj3LGGKOHMN70F8WFbIgGtXIG1jtG4gmwSIoMt2tirFb1OIiJh27kXXdR4uQbV7cJo".
	"TKcbs7teZPOWWyAEpolgMefcE07mijefy92bb+HNL34Zt73v2sYxjeOkt5/HYLRIt/Zc9pZzMFFM".
	"EItSCSQdnhoN8eJvevLhR0CkoYkGGxw/9TM/jUGtiQD9X9/+D1k1PflYVdQNBSLo9oGiAOcZ54WK".
	"In39UWtfBlZB3QTif/3i3YxdiV89Se/nTsQPBmCFh+74AuXD2zk2O4iZxXpjvHuOf7j9Lxv0lIUJ".
	"w4CSlZ3u2mL7k+A8mYqoixpqIe72mJpZMf/4dx6CoEACHghJymHHHE2BzOaA9kYzzMdHrZ6ZBWeb".
	"HbgG0g7s2EkW6Y2RMRdja5IobkKehwfu+wYQGJQ5eIuZ6EEIfPpTNxOJJwtCIrKmT2fDaHHQ7v0G".
	"nOWFL3whw8W9D9jFEVQBRhUTWQYEZletZO9ogSwyzSqFgASPoMlWHkK3M7G3p9Jt2nWnbnIqpl6c".
	"AyqwEKVNVsehRxIC9yRagdaIrZe3+KOOfC5dMSSlB5W2G43nzEt/mWqqw956jETp+nkjWwedGLo9".
	"ghNQCU889Cj9XleCAnwMSR+Ug6RmLp9DOhoiA86BQCSGOGhkaMklmt0hbo1OpldeotKUTqRmKEcQ".
	"HBpYLCzECelEf8uTi7li11OoqN3vEnjlaadDUEzHPVjMwQkkhhPeeBrmOStQK2aYjwLFRMavfeBq".
	"RBTaZFAFMpMyqGt1yJFHNCiVZbOMwTIYLTCsxkRTE5Ak4CxSlBgF3/n3b1OFMJ/FE9v06qOP4qnB".
	"YrMRJAYMBA/dXgxGM3BeTXTTtbdt3gR1tS/lW30IRBGh9Pzq+teBREgQSGO23PfP/Paff4xL//Ba".
	"bv/7e/jF8y4Ar8ECcwPGlcV1ulxw+buacUMbdYymk3bJ+lM857ifaEJomqASA8rxn9/5Fh2jN2CL".
	"NfrQI57HqsMOJ1g3T5GDWIyB2gN1TZkkjIJ74I7bPkOTBLf5h1FMHHoocdrje997Aju/gDIJubOQ".
	"JRz9syfzcxeeS3bs8yGJUDoCb1h3womkkzMsKDj+nLdANYJ+1kSPPQtoF6hryxve9FboTDQOZxRS".
	"jvjS5+8kLwZbPR594XuvYTgqcbVtHC8KWNWEILoZ3dWrSGdmkYUh5HWDjreg4davfoW5qqTUms2f".
	"+BRCRBJ1yINDep0mD1GhydeDAp1A1mVXWXLeb1wBiUFmuxB5GI742G9fg4wqUp3x86e9EcRA1gXv".
	"UVrz+Le+Sb/f3eiNAZkb86reDBf1e499dN3PIqOdlFJTiFDmFvnuY6zvdXhT1uOhP7kRGdeIt001".
	"ZEue/Mq/cPN7rkPygqIcUNeDplqyQ8JwHhmOmiqpKJHa85fXfYybr/ogYmuC1CyGMdYOkcE8G6Zm".
	"eD0R5686ChnJvnp4uIiM5nhlAudMdrj++BeDDDy/OHUwF3X7j71Og1RPMZYhlQiuFqTOWX/QLBdE".
	"k1deOr0aeWovUo5xUjM/2oMUFruQt6VYjSzsQcYjbv+dD3Hj5VcgoxIZ5ojzhLJESo9Unt1zOyjF".
	"MhKL+JJtmz/BBcnElRdPH8aDH92EDAQZCovzA6TOGXzhc5zdgTOnI6ov3dkY/ge/dCFvBH555dRa".
	"qXchMmI0LtpasOa291zNeWZy7UXJig2fvuoapCqopGYslkqEWgJWLFKPkYVFzn3eCzi1M8Hr+rOs".
	"7x+EzA8QVyNi8UWBBI8Vz1hqKrFIlfNLnWl+JZ3d+FqVIfNlY3jV1qnjRd62corzJvTaV0+BDLej".
	"iTRX/OEfYLp9nPXbLlt/GlSeXtoWEt7z1quvpu5kDxRGbb3xxhuhdsQoHAELDH1BwENw3Pmha5Ef".
	"7ORwr+WgcbFhpig556UvhVDhsZAZvApYb+lgSBxcsu5UjNLM2+KS371lE0QB0mbHByDSOG9Ba6LJ".
	"CUg0mhiY6uJ7XUon84/f922oAB8IzjaJVV3xF1+9h93K05maAhRKoIPBS0nPJMRtzXbrDR9n0jtJ".
	"6hET4rYcpLXkO3dAXmDwKAKVr0lMjKodeHjie9+n7nY44qSf4ifPfgP0mlpWaVBF4Nbrfp/ROGeh".
	"dg9s+fznmwjkRJCy5OubNrNh+iDeGk3wube/E9kzjwSL1BViLVLUSF6TP/wYMhg3fbZEfN1wW4bI".
	"zu/y1l6XX0HLO0HerSK5DCPn9/sbbr3qcqTci/gRQWrKYtjIGoVHxjX33vxJpBpQ1POMQt7IFkNB".
	"FoRXTRzMGdN9Xj0TI+MnEb8H7QDSmJPf9jZ8p0/XdLlt059DljabgtZURdFU9FlMuuIgSLKGRqKb".
	"HdMFyGtuuPbDTCbJl4TARCejFEdMwDh78af/dGOb3jYFRRpnrVokECtOOefNVDH4uEOk4ibFBq5c".
	"/1pmdIolYtPtd4CJQUdoAargIDLc8Y//zHxVMT05y/pjjwFfgxLSiR65gkKBnp5qkjG1v9agwQqf".
	"v/0O8oXFq1JgUJSIgiiJwFnUuGj0Bg/KBlARwXuINMQR88pTq4wALM7PgYZtX/wij37rW3jryGZX".
	"8pyXvhySHqUNaOdLIh01wf6QQ3jRK17OvC3xruTf/ulenC1w6GXVIfdALwVXgxbQpsk1kpQOhkmT".
	"3t8BSsCkUHpLpPS6lRNTM9vvvgcWBs2FADoxOK1wgFYpNRbwHDwzA+K55OILMf2EuTJn64P/DnGG".
	"iEbHfXTfRBiagpXY8MG77qC3ZjVpJ+P4k08iSmMqHLoG44AYFkLAxrrJa7SHbocHv/h35HsXsK4k".
	"AVZ0FUXV1NuFdbNpnM1fc9V7oT8NovACXjWZrgEmiZglI/Vt7lLkHH38C9kV11yz6Y+bbDHtElTM".
	"qKpQoa4QZdDG7FMtQwW+gCxCTExFTBY0zoFLmtsSHIjDqAhlAxuOPY5sxy6OKGoJkjNSUJtm17cB".
	"qig7cUfggbsX90KcgtHLFNcAThA8KgaqolFrrGvyoyRtRTyoFGA0WpkErZvOZUk1iZsyyKQEDOlS".
	"OI0ga9Vag8YoQ+0KCJbRY9uZqdSXSrGUAJlZHns6S9GuXDfbjeGpnW0KuyzBNP4SKVQUNUakPYhj".
	"6HaaXMUYMBqMJjGa9q6nCU8avNY4FeGI0ejWD1stLQSUBFQTzUmjiPF/PcoRk7NoX6/r6i6RShhV".
	"/uy8RKVAXVR0tL5eqoqPvOdKGA6hrA5QudoXtiZp0FHblgJ6c31Jwdb7HjhQQlPPpKipfU3a/DYs".
	"DrjuA++jKsZrK0pscHjxZIYtvRTRbcQUH+il2cYv3HlXg2Rsnlmy+zE/+pls0/s19QxG768L6qzD".
	"1+6+G4Ws6aseJSU1nm6aohz40NQnCCRw8XSaNZ1aNxXL/9nwp6MtSzqMbgtQjezXArrx0tozayKM".
	"uIutqlEEYkCcxXruUU3NQaKgHIzO7inDX3/sT5q9wJj/P8QPUFjlQLV1f/lbtyLmZ9/3fvoiM8FX".
	"9wxDeZNBE2mNLQN9zbrYNLp9FsVEhOtNUXHbxk1L4et/bbiS4PfjLCj0PpFe9nFH1JKuveQgAcqK".
	"t6w+lOmylEgUoa7omwRrK2qg00ZY65uzn1pFjJPsnh1arf+bJ74LM1MNZZ4Fvx+B+D7lff+DgwNQ".
	"fxo2mtDG/EBau7UUFXVZghYKW+GBvmpOWioPvY5u1F9xqKpaM52k2J07wLsDI8v/hiqBZ3jHUocH".
	"5x0BUIRG7w6BPd+4n6iur+80BweI7AtXXtpTNgPjIpAqRYymo82aqK5nfusdlzWpgjSQSJt8W2tb".
	"KT0s9/1Iji9jr374Lm0Mpc2pq5w0SWGYc9U7f53Eh3X7u5ioA33deUhTjRXBE8iiiKoYzD/6bw+C".
	"iRoeAXVdAxDH8QETeXbDQxM1pA2AfgnopZG9tIYosjgji+Mml0hS5rY/8SNDsTaNeFo1OhniLdNR".
	"Kh1rG52mNTCKIkIIy5MwxqCU+vEQl/0Oz/YtQwAFHo91BUo13GbvAlNRgpLwtNjQBHtpp+Q8jAtP".
	"bKAXGZyvybTBjAvu+OC1y3Q0xiAiWGsxP0aY1Esxen/DZX8bErOMeKQ12Bqc45Pv/wDF3vkDHFfJ".
	"/nhoAgrdRiwdKax4BMHVOR3kys9u/iRoxXg8XjZeKbVs+BLfnx1x+aEjygM+RZ63NWvUerHiM5/8".
	"BDPdiQ3QaD1L/FKiD3B2pRVZashrYei5KUoMGjg46V7fF7WBAJ1OB+8P3EWttct8fxbEn4Uq++Uv".
	"nV6G4PG+aqYqsKIzibZ2i6gmr96H+IE7bOUF6z06gsxwsdLNxPI6x47HW79+111orZf5vMTz/4nf".
	"LCdZTzu6PiBpaevE4AOxSUEbvnLrLVgNufcnOq0bxNsH9DIIzfp14pjatRlzpNlT2qtMkqBVhO51".
	"+fBHPoJzDt1OKIqiH3LWZ9k59x0DN6dtzYZu9p0Z4WuHZKZxOVuirefMFx2PPLWLg2Mjw+GiOiTt".
	"ia1yIgSNwiMo1fDWOY8xEZV3RGmXnVWupmdWbPieK7f+9cOPEGZnSNP0AMSXJvKshgdp/V9Ca3xz".
	"dKGIGlYUAZ02PhwAg2tCxe55SDL+6Iw38MgDD0hkPWIrUqURfPPPNEsFiIJIYsZY0u70tiNf/BNH".
	"Xf7BD8DJLwNjkG53mRoi8iNpAvDf9D724rifa+cAAAAASUVORK5CYII=";
	

  my $wepapjpg="iVBORw0KGgoAAAANSUhEUgAAAFwAAABjCAYAAAAWw2cgAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz".
	"AAAH/wAAB/8BXW1oEQAAAAd0SU1FB9oJGwE5I1hYsfkAABeBSURBVHja7Z15tF1Fne8/v6rae5/h".
	"3kwM2oKEqZExCAGE9iH9aJ88aVCxUVdrdxKIDI9RCTYIDUZbHsMDNETBAAlEePgEFJs02DIoODwC".
	"GIYgAQeCgIi2Dckdzj3n7L2rfv3HPjcDmc6GJNyY1Fpn3ayTPVR961u/+o11RFXZ0jZec91eeOoB".
	"dQ2tIbTSwzd+PiBboIMXn12olx17EJ6Ia37RHSamm4sm7TdOG/1DuLjK35504RakgecXLdR/PvIA".
	"Qu5JKhHz752n6w3w8TvsRL1eo50rEw49YgvawE57TpAD3/8hoiRhqNXgthnTWS+Af3rf0fryM4/z".
	"sbMv4dxbfsb43SdsESedNu4dO5KjGCO8+vwiLjnpGH1TgL/07EKN/RA9lZibLz6XH33n5i0or9A+".
	"Nf1yGfKKiQy9Fcfih+7jrhtmrhV0WZuWctqERI1PUeto2l6uf/y1LexeTTtx/5pGWcpgv2fuCypv".
	"iOGf3jtRpynOQpbn/OXBh29Bdg3t6NO+SBRFbDXKcPLOoifs0aulAZeQkqWQeSCpcs41t29h95oA".
	"P/5z4sXQbgd6q5aaK8nwKQeM1chCzygDkWHHA/56C6rraEO5kgaIk4g8bbDgvtWriasFXNMG7Rxa".
	"3pC5Kuded/dmxe45Xzy7tPk9+8khMdWERruNc4avnfaJ7hh+/AHjNDEBEWhkyoEfnlq6w9OOnKgv".
	"PLNQh/r7NjmwT965ok9+Zw7/NmdmadBTWyEzDhtbnLaYtM9oXTfDm/3EGqhVKwRbZeoFM0qz+7NX".
	"3MDC+7/PnTP+ZZNy1Az19zG2bknyQeZdeX7p+294YqlQqZKGjEoEdZOtneHH7zdWq+IhVXyAEy/9".
	"ZumXfv3kY/Wp+7/Pr++9lQduvobZ08/aZEA//b9tp/0DQzjJGBXB5H3Gle77P355DkFAg5KYnBmn".
	"HLvSM1baTyVtkljIM2hlgYOPOKY0u3/54N28Mv8eWlmKOmHq9Cs3Gfk/e+GgnHOg1eZAoNk/wKQL".
	"ryr9jGefeAgvQmSU0M546kfz1szweqSQAxa23Xnv0i+7d+5MFd9mqNWgL/PMerq5yW22DVNDqjGV".
	"JOLWi6bxzS+X20CnnHO59GyzI72jErwHCdnqLc2TDxqrSWMpJkBIYmY80S4F1tBAH2dOHKejo0CI".
	"K5z+fx9mpz03Xb/LCbtUtVYzZKFJXu/h2kf6ux7L5P3G6DiTkg01IYo57iu3M/FvjpaVGO7TASox".
	"GAPNNJSXf+99pyaJEMUw2Gxt0mADzHj8D6KqRCiaDpS694u3/JjMCxgIIefr0/5hVZESvC/+Anko".
	"D7jPU4wxDLYg+zMIIv3pdy9o6gNiwZUcz457TJA0zzHGICJo7lcFPMKQZwXgUbVW6gWXnPh3KhoI".
	"ISAG6mPHbfKAj99zgqh1aIDEWebNubIU7JlXjIswxiGiqwIeG0vwEBTO/9bPymkm8+8jNiAi2EqV".
	"r81/tWtxMnXvXj1hz54NtiamHbWvzrv2Mp32P95V+h3eOrwHfOC2Kz9f6l4TVQgqqCrWvE5LmfOl".
	"s9WpYAy0ctihZJBB8hbVyCEivDrQLNWxuqRsU3OcuM+YDQL6wO9/w71fP4/2K7/itP3LTezo7XZG".
	"rODbSt3akipmv7TSHO89ooFHOr4VA/Dgt64DVYxAMOUGdPZRE9WFHDRDgX+4oHvddf7dtylpytIl".
	"fcRuw+yxoqC5p9eBaTWYfeFpXYN+xd2PibEJxkMFw6S9ypFCRQoxq4Grp01azvBIPRI8KoZabXSp".
	"AS158Tf01hJaQzkilg/84+ldIbd40eP6rQsnIwK9Y2MywgYBfNbjDTEOWoOQGHjy7ptK3R8QDOC8".
	"p1KSjHGlhjEGqwHXGZ8BqFjBGUsrDTSzcgOXkBMbCHmxUXS90U46nKzZRGN4tZky6/G+DaZG+rgX".
	"tZA2IbQbXHLi33XdUa8GESCkVG05qZeF4npnLBa/HHANKaqKixzBRaUeajUnT1MqFQjGdb/c2k0i".
	"BylgavVS77zipGN10p7j9LeLFnaFwNce7ReJoVqFmrP8ev69JUAzGGswqmStoXIzbV2hGhIwwS/3".
	"pVgJeDxqEw796HHlnimQpp44cTSREisjAwOpwpxHB7u6ceYpx+ozD95NlraYesEMLv34oQxlXt/3".
	"yZOY+oUr1vqM4KqkzSZGUmpRtXvANYARRANkeUnbJBBRGD8SVhApLoI8KDnCcRdcXmpp287u7VUJ".
	"0h3DFy96QmMjeA/BdLeiXnp2of72ycfpTZS6KLdccAZJaDOmahn64wvLtIA1tcE00M4hBNC83f1K".
	"tI40KB6IY1cK8DFv3x4RQVQxHV28sw14QmdXfSPNOCEPMPuJJd2le4lBFIyCkXUD3hjoY/ox+1PJ".
	"/kjaaLHD7rsxepQldjC4pJ+//thkvn3p2Wt9hkvq2AiiyJK1W12Pbe7CpeJNQW4XGR69b17XgnzP".
	"Qw4vRIqC6yBtzj0g0twrasCXxHv+vf+q3nusdah2f/PT8x9E1GNFsKxbv53+qcNVM09joEG9Di/9".
	"8lc0Gp7BZptttq5z+eQPseSFX61dW3nsVfFaiL9arcb8H3yv+x3QRXgg9RkL//8Pu77ttVdeJgTI".
	"c1AfOP+gHjV5yAuFRQqxUqZtu92OhShRwZdQbv7w4nNELinM2rDuifqPl55j27eNop1Csw0qUB8b".
	"Ue9NaDQabP8XoxldS9b5nLwzeGstD363+6SmYARcoYVtu/34ru/b65DDCCGgCs4IWbuJiVwFa0GA".
	"PG2XAvxPv38RYwxBc/LgSziGXmS7Xd9F1gar656p9x0ziaVL+untBa/gO8tzcLCNKjRaTfpa6Tqf".
	"U0siahVD39IBzpnVfdqHBoNxBhAWPfrTrsf5w9tvxDiHc5AkCc7FmIsfaYoJEbRhq1rC/B/c0TXN".
	"3/P+o8WTEkWGStL9zn/udd+VV557hshBJVo34OJiRA2RixhsQa0OaSOj5sBGkEUxc55d+1K5d+5M".
	"HRrI2POQw6nF5URn8A4bqqDl8nP2OOgwvA9YF9EYyvnfC5rS4YojNqDtFrM+N6VUZ5yxpO2c3Gfl".
	"fBwDGfUK5F1sYMefd7mEZBR9LRjzth76hqCZgjeOzFWZNvfH63zGrVf8M6PHxjz1k/soo9w9fN88".
	"tSKEYEDL+VP2es9hiFjAINYt11JCCDgnZJkSu3IPjcRAB+t1JTKuTFvwGRhv6SadYtYTS+SIsy7j".
	"8ocGxEdjmLVYZYeDP8zVTwzJznvtt07WjXrbdmQ4WmJokHTdzR/dNodIAupTtKRp/6ffPQ++cGAN".
	"R9YMFGHM5UpGSZ9G5omjwgD69lVf6Pq2njFjSDOIXMwFHz6kq4k6+vjPCMB1HfXzrOu7X979f3yZ".
	"vsYQIelh90M/2L3r+Wf3kRhQclTKYfOdGV9ACRhjlikkBsBL8YWLQEM5ayrkSmKEoPlKjvZ1tcEM".
	"QhyT2pxG/ysbNJgw7aiJOn6XXXEuohmEc2fd0fVEVULA+gzF4005bBJrsQLOOXzHCi9EirHkoYhn".
	"hpKAi3V4r4RccSUYUH/7TnhrSdM2sVNmf+HMDRaE+M9fP8kff/MLarVakaxTRmT6HM3aqECw5QyV".
	"YYeVR0k79kYBuI3AQO7BlDR+bKVGGiCJgLR7C+6KHzwmuVhiBTvQx4Jbr98gYM++8GTtcZ68laJa".
	"3gUcixK8YhIwlbLqTY4QaOce3AqAf/TMLxYszyEqifhXHlsiqQi1ShVaaSkL7uonBySuuML0xXPD".
	"G0iiXFdbcNfNJE6QCBolnU9Txlc16ihyJk646p4Xy4HTCax7Vb5w60+XA37klNOlnYOJAPVM3q9k".
	"ZKNaZ2ioicvh+Z//tFSfWq5CUyCzEVu/c/x6Z3g7QFMNmtS5fuFQKcD+9vhTwQckMvS12tR6uw/O".
	"nPjuUSoEAkqmyvg9Jqycl2LiGGOEyFgI5XTqs276MVFcITbwyLdnM/vC7vMJv/7zAfnI56/iuK/c".
	"wtHHn77egxCzHx+UI8+8jGseHyz97AfmfA21jkaufPQzl5UTtSFgxRBC4J3vmrB8zxvWD6fuU9cq".
	"Tay19HvLDU+1SnXwM+/u0b/5+PHcd+M1NKI61z+9dJNOBPr0LqN1jIVm1sBtNYoZPy9X33TKXhU1".
	"ZDR94NSr72T/w1+XeTXmHTshYsnzHPMGEoEaac69c2YSOdZacrGptA9OPoHYGUiqjD+ofH1T8B5j".
	"DIrwra9OX26ZL9cafiFn7lfTkOelNRWAzEX0uBzyQGOwb5MG+8R9x+ioVgYettptd866ulx909R9".
	"ttKKCNYaIhPxf+5csOz+lYzVYVeiFeHRe+eV2jhvXDggKYGmD2w1rod5112xwfTqyRN6ddp7ttKp".
	"u1o9/0MT1/t7eh3stN9f4ZzjS3cvKE2/T0ybjjGGLPNgVnaVrAS4qhACVGLHzLOnlF9GUYRE4H3G".
	"XVd9iUtPOHa9gXHO/5yop04Yrdd99hh935GfJGq9xjZxIHvhsfXL7gNGa/O1Pl55/CeoeWPbkAjL".
	"/CevjxOszPCkhgfEWfAtGiVrdK5Z0JbMxfQNZYQQeP/HJ683IPqee5oKLR79/vdY/OPZ+CEwHmLg".
	"f+0t62ViG/1Ld/Z9/YzujWir0ufLA37lScfqHZeeTe5zonqV0TvssmbAr370VXn/1GkMDg1QMxln".
	"/fd3lh7IrCfaMmbXdzN2x92YOW3KegH7gbkzVbQNUQAHr/Z7XE1IQxH1DwG+efGbN5rOeu82z41z".
	"kLUzWrUevvHLJaURf+mn86iElN5RjtfSFlfMe0LWCDjAgUd9iraHXXbfg7wxwLQj9ig9kMv/bYFc".
	"etcCOexjx60XwG+dfgaxA+sUosKz6b3FdzIXrMD9t1z9pt6xeNFC3XX3CaQBBgMcccb00s+YftRE".
	"TQdSahXoH8o57BMnrypuVldrP3X/sVr1/WTtgCYJ1z7Zest06ql/OUprOkRSVTIbaHQAHq2OkOYE".
	"C1kkNEiYs/DNl7hcfcaxOuWi2VLGqlzW192qOtalqAk04ohvPJau0p/VutTPv/kB8gBJDBVRJr17".
	"9FuWYv/J8y6ip6cOBNrtYkOKbaFRiRQeTlSpxAmN/qU7v9n3nXLV7W8I7NnTz9IjJp9KcDF9LTjw".
	"Q6uvb13jaRJnvmechoElhABpUuG6J9+aAqlT9hytNWnjtU1mwSQCHkxDCyPCFf4SrfWw/QEf4Nxr".
	"v/OW9PPEfccqaRtn4NBPncLfn7f6hKo1Bo2WDqXkQCUBbbZ4uKRevj7aI/fM0+BzQghgwVpQr2Sp".
	"ogIuibBAZCFPM157+bdvySqctItoRE47S3nv35/CTgccusZr1wj43KcGReIqvuPrfuTOuRt9IM88".
	"/CBJbLBOMKawEdpt0ADOFfUzUOR8iPcseXnxWwJ4j4NIlB332JePnHGBHPyBD0tpwAF2+6sjCSbC".
	"KCz64fc4bt9RG5XlD9xyLSFLyfOU0IkJRhaqFYc4S6OR4n3BetQTGVi86MmN2sdT9hB1AawVqtv8".
	"BfVRa5f/sq5zC0/ef4yGRh9bj67wH0taZJU6c58a3Chy8oTd61o3GUayopxaloe4bRBsAAlaZOGK".
	"ISQ91N6xK5fdtWCj9O/k/Xu0njYIOTRMxLWL0nW+d52B/288tlRIKgwOthjXa4hDe6PI86n7bKWJ".
	"UczrsghMJwl0uFlbGD5owLdb+LS5UZj9yP3z1LebqBZlOkd/5qKu7usq0+L8Wx9GnWOwEeip1Xnb".
	"9uM3+IASPAmKdAKxw2kcQlG3s+y7jr8jthYjgf/83XPc8C9nb3BC7HXgobtUar00g+Mjn7+Ko0/8".
	"XFerqivP9fjdJ0jb9mg7LCXPlR332LBVxvPv+Z5WI4NkWZF8I6uyxGMIEvCdMhdjhVgsFQ+hZMTq".
	"jbT6qDGL4612YLu9dqD+9h27d2yNxLNn5//gDv3uP03BN/qRuFiyw34k25EwHgtSOFOsAXFFukcz".
	"WFJXYc4TfSMy4mRGYqdmfW4KmreJu8i6sxasA+8Ll6ghJ4lGbnRvRALujBDyjG123HmVDq7oiA2A".
	"2EIlUy3MfmPLJzNt9oDb0EZ94E8vLCawQs5+B2wJAhIwQJoXhQSqhah3IoRWm5suPntEHrEw4mT4".
	"6fuP0yTtR7TQTjIp5LdRELWdv6BmeV2SqK7EnEyEtkkYNX5PLp+3QLYwfC3ND/QTEcjz4hiQ4WoH".
	"1IIaZDU5w8PFYNKZDKtKpJ6lL/5mi0hZW5v2gYlqjMFai/fFhrhqW30KR2DFlOuVZf0WwNfYApU4".
	"IfMdb6BbLreHrcxl8A6ju5Ys+ZEI+ogC/MwZc8nylCzzxDG0V1Q2JBSfMhsUgTlfHlmb54gCfOvt".
	"xkurkWIMVBJHnq11uy+cWWuYBCn0Gx647YaRpfKOHOvyX3XBHTcVhoy1ZD7HuI5KqMPiIaxVkgdZ".
	"mUGGgBU/ogAfMWrhpD3Haa94apoBbQZbgUrv8gPLnC9csh388abD8I6jxa5QtBQAL0IuMZmJOOTY".
	"E5h6wcg4sHLEiJRKpIgWCUTGGEy0mtr/FXbBQpysfWBWAyFL2W6HnbYwfMU2eeIY7c3B5SlR8CA5".
	"rRAKx1XnmtgP69mCArnVjriRDmu0ODBhBXHjxZJLkd/9zWfaWxi+bNbbDZzkWPVI55yoZYGFVc2c".
	"DtNlBbCLbXLFiFAxOE/iwElg3uyv6hbAOy3SgNWAhhxVT1DBOEfQQl53r0/LSgMTQHxOPUl4+mf3".
	"bVELASbv16u1yCA+xWcBUUVEMMasFk6zOsajq9VajELIPSFt89JTD20BHGDrbd9RHDIZwrLODIuV".
	"dZ2X8/qNM6zI7o7kiSy0Wzl2hLiw3nLAX/v9YjTkSOcES4NiENqZR6xZixNg3WJleIDVBHzWZt7s".
	"GbrZAx6pEjpn3lonYASVgOaK7RzVtKLwGHZSmY4oWT6QYRetAZVlrpZ2G0b11Alpym1XXrB5W5on".
	"7D1aKx0LEQOhMGkKNTASNM+XHdAUKAL0w5qIKFiWnyQqCiYUzqziuwBGcTE0Gw0iNfTGbvMWKbWQ".
	"YztEDaz8GdarRZdrKWE1omTYg2hWuA4t+K7A8LmX4gMmT0tXdfyZiZQNc/zp6z2L1hYDNSLM/OwU".
	"3SwBv+fGmZrl6ZsGfRXz/nXeQ5Hio4BFefahH22eDH/t9y90Fv2bbLrylBXnIRb6PAKq4PPibFwN".
	"GZHRzRPw+26aSaUab/D3OFOA7lzhrk2scPZRE3WzAvyR++ephqwoF3mTLF8pjkkReFhRlRw2niox".
	"EDyWnP6Xn9+8GH7NP02mXo1otdvrRaSsirwus38yXzjBjDH4XAlpioScf79ppm42gEc+JUuLUBrr".
	"w+ReAWyjuhLDbXGKHVkWqFYjJM8JzQa3vYHfWtskAZ+0d1F8VKs68vWSkSZrZb/XwmAqzp3NcFbo".
	"rVeIeGvS4Ta66ZWYQE/kyLLWetTCDaKhMH5epzIaUyR6Dk+AEtAsRdHNg+GJCI2+FiFAVGE9DNus".
	"RqCvIGmMkHXSWKKo4FermRNJYPJ+G7/+dKMD7jRADpWqkK/HgLp0PqYTZhtGMs06XFYQY7BGSBzU".
	"q7Vl+Yt/toDPu36GSp6z9biIVksJ602mhDUqMHmAOElQY8kyT54p1STGZyknX3LjRgd8oweRT9lJ".
	"dHRd+MOQMnZrwQ/pG05JUykCxaKBxEPUKS30BtoWcgN5EHqqPbQHGkQYfJ5TrUYMpBmMHcfVJX5V".
	"a5MEHODkvSuaOxCjxJl2PH5hmedPhv+9mpkIK2yLw65aqxB7XfY/XiCzRW5KGoQorpI22vT29tJu".
	"Z4gThtI2cxZt/Ej+W54m8e9zZ+ptF5+DM0KtEuPTNnmrScUZkiQi7RhH0vnlvkDxexO+c8qmk0Ak".
	"y6VKFBlylLZXgo3xYvE2IguW3Q4+nHNn3f6WBttGTObVo/fO0/936Xn0vfJbemILPiMdGqISy7Kj".
	"oIMAYgliMDbCWSGkTSJTnEbXznV5CMM4bK2HSRfN5uAPfnTEJOWPyCq2NbWf3HKV3nnVebTSvIjs".
	"24ivlvgl15HQ/guUrLhHPvR29gAAAABJRU5ErkJggg==";


  my $wpaapjpg="iVBORw0KGgoAAAANSUhEUgAAAFwAAABjCAYAAAAWw2cgAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz".
	"AAAH/wAAB/8BXW1oEQAAAAd0SU1FB9oJGwE6IgRy0qwAACAASURBVHja1L15nGVlde/9fYa995lq".
	"6gGaGaEaGUQB50RRQAjVGjREUBK5MYrx3lerM70Zb6IxmpjkqjHVJjG5xqAxiTOC0gXI1MyTDTQz".
	"XXRDNz3QYw1n2vuZ3j+efU5VNWA08d5+LT7nQ9epc/bZZ+3nWeu3fuu31hbW5CiV0s0LKmkKBlBg".
	"DPgq7GMv0+xm7ZYr+Psv/h0nrFjJ+97+AX72sDMZYQhJgQIUGYQMgiYIMAI8IIHEg/CUT3hQjiDA".
	"AQqFQHJwfnw8JwBRnoMwQEE8O8BVwSUQAAF5CrPs4b5n1/GZr3yKvarNhW+9iMtOfi9LGSLJB+Jb".
	"JaAh6GjS3o/wwSEA5wRKRCs1Zxz1JYrddgaTFPzN9z/NP135+fG5fGZiqVwihvJB1l1+GwM0SBEo".
	"JIIEQgJIAuDE/HdJQmnwUD4hPUhPQB5EY5fnE3pnKUFCwOMxSAwCoFAgq+DBWshrBbPs54IPnc9u".
	"drLL7Q+Jzfif7/598aG3/A/qvgFWgw+gBCHpX7r4KQUOg0MpgTcBPDRGFLmw6ERwzeOTfPHrlzPd".
	"nZvIanVmpmcxuWfT00+RkaKpIkItru6e8QSIuFFQgBeA8vNPIMFrhJfzF+Fg/QhZPuKpRFMndEjI".
	"SQhpQqfVAkBnoJDc/fgPeGrfdrbM7RvLhUfU9epPf/GzXPfI9XRll26Yg0ogSN8zR/8h3fzmQcrS".
	"ZtIy6/ayi5381ec/iat7VK2CQE8N1pcwkA3wsmNPxhgDPoGwwHB9Y3sUFlV+BYvDCo/rfXLPxRxU".
	"Yy9e7cL3lozEkWBROCSVRrX//QSOl574UtJ6g9rw8KSupMzmsxOdrFj78X/8JFvZjskCTdo4FXp7".
	"p7/WZAA8gRDiFkBZZs0+pLL87Tc+y7b2tjDd2h3SWmV1p21GTRs+8N4P4oKlklT75+tkdCPx5D04".
	"B9aBtwgsHrB4DGDFAV/2IP4EMe/OcaAdaECWTjjHI1R0NxRdApalDPPe9/w3XOHGvPcE7Wip5thT".
	"rafH13zn8+xhFgO4ckWJMO++pMejkIQQCK4AYVCJ4I5tt3PVLVdgshxqktb+2YlKqK18z4WXcvGb".
	"fwktsngMGY0dFrhogp9fwV7GF5U7yeGxvcsuD7KxAY+PFz8sNnoWYx4JGu/L12SaBEnhm/zamy/j".
	"bW88fzK0LUmSkAyldLLuxOVXf4X79q+nS0HRM0IvVgSPxHo0EikkRTDkGPYxw5qvTLDX7wtGFRCg".
	"JhuTRzSOmPrwxeMkpKRUKLzDQHk1FwYiWS4dBUGBT5B9NOLxWKywBGnLaMpBQykBR8DOO9m4FdEW".
	"shADvpQyLlMBwXkOkSMMoviLX/5jjqguF4kVGFdgOu2pbEWFT33hM3TImQ7TcY33DR6QA6pKKKK5".
	"VJrSJuc7d3+X+566f23bF0gJysCgr6/6nff/JksZISPDB4GS6QFu2IKwMTKoEB+6FygX+DEcHofD".
	"HeSY6fF4HAZ0DsrG4C4X+PXe1pUCax1apWivWcoAwzT42PhHkE0xWdEpjKjRPbu3hg2bNkxcdf93".
	"qYgq4QALSSyEbrzCLTpM02biy39HV9mxoOI5JG2x+i2nnsnbT11FlQo6pGhRwZWOOAYFi8DR9U2s".
	"yMlVTlcVtIVhNnRwOBQejacHHsNBj5ogMBR06dIlV21M0sIms6BzTHeOBdGSbm4gJEgqiE7CUoZ5".
	"28ox3nDy61bVXSakiW7HKz+25h//hmn2Y+nt4rjrJQaSahWHxeL56i3fYJ9tYhOo1TNEG1ZUD1lz".
	"6VsvoUGVKimq3IEl+i4RX8Bj8NIzR4vbtt/DJ772v7hi/dV0hcFhEQRcq4vyEo0mITnosTNmAoE2".
	"Odc9cSN/dPnH2coeNs89g6hpkA5nLd3cUG80SrcjQaZQaBpU+f33/y5yNqC6gjRJKWxntBtaXL3u".
	"ShyW3HbKDRVQf/J7fwIJdFXONLN87J//jK3NrcGEHBU0g64h3vmGd/Crb/pVqtQQTiFCdM3BxwAj".
	"84ANXZyyTDPLP93yZf5g4qOs37KBa2+9loKcV5/0CmpotKqB0/GkCwFaHjTEIvB0uy2cDvzF1z7D".
	"R/7hkzw6/RR/99UvcPgxRzJ61CjOOyq6gtS6jwNED3kojZKwpDrC7s5eHt/0xL7cF2NaK1zulu7e".
	"tmvywnPfQaYytIjwWZLGJZrT5Y6n7+DJnU/gMg9CELpQc3V++YJLSUhwbdvfYd5CIiC0gESgU02b".
	"LnfvWs9ffenTYzvCc2GX3x2m/X6uuvZbGDoxOHkZI6wHtDjIiY+kVhnEAldedzV+WLB9bvPE7HBr".
	"4qP/+xPctu1ugpSYEhLkeYHz8Sugy5zDx1z7sos/QJIna7QXpInEiNb4k9se5ZZHb44xQngQEomG".
	"nJyCnH+98l9ouemAslSrNTIqk8ccchyjQych0OhKpR/JVQmlRAVwlg6GPczwx5/7OGGpngxJl/pI".
	"tmrpskEOPWQpNbKI9UWMrf1VfTB9SpDgEhIywCMrwFI1bpPmeKfeHf+jz3yU/czRok1uu1SyFFFC".
	"YCfBeYCEBkOskEdw3CHH0dB1YUyOTQtcvVj71Wv+jZycTuiWl1jFN+9mN7dvuHVtyBzO5QgbEN0w".
	"eelFv4IiQaBKaBRAuZiVWgsSXJLTJecfrv5nNk9vY/q558aT4QHmdu2d6O6dGb3gnDEUEiVU5FEq".
	"Ea74g27wuHgyqnzwvZdhO3MbyQvQBup+bPPup8b+9xVfiJBAWiSeBI/A47xD6vh+ETJSqvzKu36F".
	"zlxnHGGxAVwtH7vn8Tt5ungaKRQokF3hyXHc9MA6CtEZSypxm7u8YKQ+sub8M8ZwCBySrrfYkBNk".
	"9AnWdSjMXqzKeWjuEf517Tdo5TOhdvxha3zbsiQbmbjk/F+cetebLiQpAaHFUChHrsAmB59KCR1Q".
	"aC554zt565lvXjkypNfQhu7M9Fh1KJ386ne+zsY9T5HKhG7eRuBQOGzejH4cyLsWhWLVq3+eoYGB".
	"NSFEl9PGMuNmwl0b7sThQMT1Rps2373xSvSAxIu4ehvUV51y1MvQpCSkeAJaKZTSOOcggK5W0DVN".
	"l5zPfeXvmRVNqEvau3YFMRMml7N0zQcu/CADDCHR2BAQMsMjyuTO4fEHZKksyEp7v/bTVmz56P0e".
	"ysfC9/bfEsrtf8Cx518QXaLwoNF8+JIPk7XU6gqQZdAxs6GbNPnM5Z8mJ0dmZUIXBLVqhqcACVlF".
	"k9uCCimvO/m1+CaT1Ub83K403Hr/bXTp0A0dZMAz42e4/4kfjDZtB+shc5qwh8n/cfGHqFEhYJGl".
	"CYw1aFUhFDGTLPBsLrZy68O30fHTgaJDqjNW+OWrfuuS3+e46svo5GBJ8CLy7RUrSR1k1uJdUaYf".
	"0M1d31BNYzF9s3gIDoiZcI4h9M4HQ9t2Sm47vtoW5XEK6IYYMmxevsSBcUXMj33ev6oZDY7lBP7o".
	"fX9GrV1dTQdkGtindoRbnryBZ8KztDEgNHhNQGCEpe0tVkAaEmpk/PK5v8QKtXyVb2qwYFPFugfu".
	"YnvYQSFypKHg0Y2P0A3djWTRRQcjWTF4GC8//mUkaNKgy2QxoGUCQiCUwAEFge/fcSMznZmNaE8y".
	"oNC546WHncg7zvwFEio0siWAxniHkqXfzosy83fM0WSOdmR4FYQAlUQvQhNxdUYCxiPjHgmRi09U".
	"+doQl7AQIsaXFHLhaQM+i1BWKNBKYp2NQbx8q7GeCgOc9fLzOO24V61JbQLC4zLDnJwO37v5KkDF".
	"QCnAI3EEtNYEoJ7USNCcMXo6VVdF2RQQBBFo+fbEw5seIaeLLMj5wYZ7cNLjfYR7wgtWHn8Cgwzi".
	"CSQiQSBxPpS8QgzwFkeXnO99/2rQYVRrjWs7XMus+sULfoEKVUTJoghCpCZLiqUruljRockcz7pn".
	"2GK20qJDjsGGolcwmUcTPgGXUCGhSgI+rjQVElKRxMWtFR6HSjwkBitazDDNk8WTPF1sYWexA0NO".
	"J28jgkToSh9YZ7pCAJaxjAvPv5CEymrb9RGUCceV11yFpSAXZdaHICFBAqZwCCSewKAY5vjjV0YI".
	"IwRISWHt+D333U2INnA8+MQDCBXAxGPVkuqqs372LCQqElvIaDZPXBWAKz3wI3sf54ltTxJUQLhA".
	"JShGqsOT5/3Mz5FT9HM5EQIVlcQU2QdEVbGHfXzmik9x1sVv4m2XvY3f+OvfICfHC4fG9yiYeSTj".
	"Y1ar/byPJo+ZnxA9pxeiu1GGR3c8xAWr38rP/ep5XPaR9/PI7ofZ73aTZQlKJ9iuw7p4fIUsz1Rx".
	"zivPZThdsiYlxXuQqeTJrY/x6L7HQARyE7NmiSYEyFIFARQJEsmqc8fACzQ6Jjwi8OCjD2FwyDZN".
	"prZN4aTvVZlIZTZ51hvORpUJuAiS4KI7EUJhvSMoj8Fw1U1Xk6d2PHcdXGEYSYbFm191JgMMUKMe".
	"bRU8qVAIPEGA14YWXb566zf522+toT3SDvmI4Zp7r+GKW7+Jkh4R/HxBICx4LKyYhNLLhLiger92".
	"XRtHztfX/hvPdp5mJt299t7td419+BMfZmdnOwU5LoDOFLoS46AEKlRIyVjGIbzm5NdQETURAlhh".
	"MGkx8Z3rv42lwCuHQKGQaDF/jhKFxXHWa8+mIrLV0pXgQHi2PLeFggK5jW3sbu0aC8IiNIQCMllh".
	"hT4MVR4UH92MFLrvUj2BOVp8/+7r6ah8IqtnZEozt2OGd41dVNY5I42vhAQvCYXBYLEYHtj3IF+4".
	"8nLcUhHEEthv9gZRAV2JW7Not/tsXVhYrxMLSih6/jnjIxckkaRKY3Fs3v40LrOjDPqxfCBfu1/u".
	"4SOf+WNycpzwfX8MUFiLRJNRQ6K46K3vJnTCqBKCrrWEqh+/5va1zDKDVPG7eRvPr+j6Pi9TocII".
	"SxlpDK8JxhGsIwTHbHeWLWEL8sHN92O0mfBlXqO84oRjXhrdQC9YeRClsaNLETgcG/dMsWV6Ozkd".
	"ZCqp6Mqapekwrz3yNaSkOG8PKGHFJdqmzeXf+Rce3fk4LZnTms5RSpBoyRmnvRIBpNUaxWxrQVJo".
	"ccrgtKFQhq6w5MJjlSNIj9QB2Q8RKYqUN73pbHxhJvFdaHj2iX1h3SO3cMXdV+EJSA2FjXWZRGsI".
	"seBQocrPHvezrBhaMSVlfN6lhq37nxl78rnHcbGEEmNSiKQUAZz1CDQKxegxK0nQyJgmUUg7/vCm".
	"h5EbpjYQMj8qVAyY9bQ++epTX4Um6a/uvh8N4FzEzjldNm2bwmdunIqgM91CBibPef3Z1KmikWQy".
	"nYe8FtAai2VX2M1VN181li6vBe9BDilSn6z+lXe+h2XJciQJWEE6UI9IAUOHLi1azJaYpkmTVvmv".
	"DjmIiBtcx5TqgYx3nHkRJx990spEZoSuwyagliTjX7/uWxQYcm+RicI6i0SSiATXjZlnhSqnnXQG".
	"ysuYFScOURNrN217CovFWt/fHVmlxHAuuhWF5qXHnsBApSFSraMCQ/uxp7Y/jdzd2gOZwNjoG13X".
	"j730+BMjt8ACeqxcrFprTCiQCDY8toGu605QTWKKn5vxU457GbK8yj0PUBR56SglDsc3r/46vubH".
	"c3LQEt+EU1acsOay895HjRqSBO9D6RwdOU1atNjBTr796JX89XV/wye+/idcseGbbA1bmWUWRw7B".
	"oJIMnERRR1Hjz3/9EywxA4IQcXlT5xN3b7xvbEtnC1bmeCxaSVwpF0kQqDJhOuPkMyL8B4yDkHoe".
	"nnqYQEBpOR+4SyyfpGlJ9sIZp55O0S4mTF4gE0kh7dimHZvQ+1p7YyKgIZGCTFVWDlQG4+rulWl8".
	"z/KyX3h1eHbs3hZTVpNDBqKbTI0e9VIqVFGUUE1CmqZlhdnTocPdD91DN3TGUICRNOTg6re/4edZ".
	"xhAaDU4iVYSfjoIObW7bfhd/MvGnPLtvB0g37jo51cn6mpH6cj7w7st43xsuQYkMOqArNbotqNdH".
	"OHngRE4/8mXcuPM2iobFBMi7xdrv3XSVGF/14X76KXoXWJb8iso49rCXIJ2MBU4JnU6Xrbu2YigW".
	"Z65iIeWrSEgYrAxSEXp1FzHu8RhpmLVN5GxzBocrPyshcXpqsDKIQuGDnw9SCw6qkBQYtm5/NpJY".
	"OahUgxesPOalEdkgCT7WL6Ozi2WqaWZ58PH7cdLEPWg1S9Mlay44861UyZBGlVwzBGExGO7ddA+/".
	"+v++j03NZza26s2wL9831ji6tmZOT4fNrWfWfvxv/4zPfWuCgEM3ohtLFSTAEpZw4RvfQc3XJnEQ".
	"bEGoqck77r8NVxpOLtDT9HazImHlsScgrJyS5fNBwNZtT1NQxIq8mM/Leq5TlmB6uDaM9BIVwPuI".
	"6Pa3ppGtbgspIwbFBHwRaNQG5o8gPD6YPhpwwRIQCAT7pveSyhhYvQeC2risuoLgS1yqJKIfdeOC".
	"mO7M0XZdZAqYQOITDhs6jMPliiiLE0n/ow2OHcVzfHziz9DLMppuZjR3HeRSxrZt273RZAYajIkh".
	"yb9899+4d/M9BGFiYhpJTdKQ8eYzzsK1/cpetbsI+dju2V1lVTW6kiDLkp+gfxGWp4eSispqbFzN".
	"aSrYPztdMtSlsKn3HhE/M3pgyWBtgFB4tJCTQXhQgZnuDLLVakXk4QVKJEivGaoOlclNTG/iG4gB".
	"zEWm0OHodruoEvwGG6jXh9YkVBE+XXgefSmCJbDtuW0ktQxZCm+SIDj+qGPiwipMfzc5awkE1t13".
	"G5v3b2NWdgN1IGbM1A7RoyKVdDtNkqGUXWY319x7PXPM4DDodF6mMVQdIVXVlagENLgiZ+/sHgyu".
	"XySWQmJC+fkxPyNBM1IfmVRegonxq9vtlnYJZZmyrFmKeRpCIhjOhpBOoKVaLYSAVDKTN5Gzs7PB".
	"mYDwgkymaxKV0mAgMnEiZpNChj6N1Ms0DQZrckThSYQALxgaHI6+QM4H2VJmFLEynme2b8EFOxa8".
	"J5WQBjF55GGH47DoNO1fJVGKRJ7etRUGEszcXL/6Lx20d1sK66guHeC5Z5+lm5iJ9ZvWY7EEFQ3g".
	"TGlMqTn2qGPBeCigXqkxPTfLHrs78i4LF0Z5rqHkIUcGR0hFFgGF8XSLfLSXS8wLJkvmUfUcgWSQ".
	"QRKt8c6NWRsgOGZaM2uls2VI9gKFmhAeElQ0UnkSoZ/meYRWZWA2CB+QPiBdlMImyQJ9oYw7ok+f".
	"iuj9W3mXPO+QKhm54WBIElEKJwJeRKZPpppA4Nm9O5kuOqP62EMEM1BPEnwLGkMZtaxOZ6ZJ7fCh".
	"jXpJZXzL9DYsBZacZm5RWSS0MqpUGw0oHFioSL0KKZjttFAkfa2OEAIv592f6Kd+MQW31hMCU/O7".
	"35ei29DjzcpYGmLoCwLv/VgokZ4rumMySZIpqSUmWApvNjqb912BQhPQuFJJApAIUa6+WEQVUk95".
	"DziHtQWWYh7QhDIjKwkgh6Var+IFo1mWrjYGQnArO91WX/zpfBHJEunJMbziZa9AOD9mt+8KjChs".
	"7tAK2ian1W4hqinG2NHuXJdTT3w5Ah35oEpM1JyOYtVde3YhKgmVhmZ6dnptkiQ0agNRdWZCubAc".
	"tiR+FZAg6XZiHTOTCh0UidIlaSVZKAheqA42ODySPDhQEqkgTRJkkMhqvbHSy+gbfWoIsqDNfjIy".
	"ZNAEEgwpgQQIiOAJFNSogU7oCkZ9mpA1Bti5YzuOdhTVlPhUkuGQZeEg59hjj0V4MVk4N+FUhBPP".
	"PvssVTTKOBIpaedNCiSejNee8mqWusqaLCiqHvJ9fo0aqOI1UIPgcmpJXTTaA2LVaT9PnUFSUqSL".
	"RIwVjlnm2DP33GgoDF1loQbVrMJStQRvLCIReAwFjhadaC4fF9a+5ix5cEgRSJFURI+iing79/l8".
	"4HTRjSkqbGcGU0nJJWNag58zrNB1IQcbQ6WIG7qug9DQas/1qMRyawk8Mm4UEcocVFKpVAiJwpkC".
	"Zyy4KPShJx0LcRuq0vl6YPngMurp4FRzxpDUoKOK0S27t+EAkSR478iyBgFJSo2VjRO5dNWlLDED".
	"Qs9Ili5fOtlp2qivCyB1nZmts7zzrIsZO22MKlWEiXJM73M6tNkb9mFMvjEbyfpa++XDh5CRxgQm".
	"9Px3hIM9px7w5L7ASY/zHhmYrCbVRZp2JfUikWQSARrtUJAHh5cxRqTAssYwcml9COEEQgqsjZKH".
	"mXYT52xf+SkX+KZe8ipRjAwOE3SZZvmAsIHZ0I5knozIJmjfr1ZrUo6oHEktRPlv4aHQlgd2PBG2".
	"sIcWHi8zgpGkPmr7Mhr81sV/yHvOv4x0tiFmtzQnG76xZqCxdJVoVxjuDotffOOFvO+d76dOHWEl".
	"vh2dslRR03jbnbdRdM0aaRTkoNvp5HGHjJJQFlV9j/1LSEkiey8sz7V2kocOQgdsWQBZOriEpGT4".
	"e1Io530/2xQCLDmd9izWmzHrY0E5eBgaGkE3kgaJlxQ+Gsi4wHRnBr8slEB+PgbaAKkQgEaRc8Qh".
	"K/jBlvugAqobF/WTUxtZOrqMmkiQIm48iyAKxGosRXD8spfQKvas2W9mx0mgU3S49t7rec+rLyWh".
	"FveDjTp5T0DphN+96Pc57w1vYXLdJHc9eM/qffkcL3/l6eJ1L3sdv/jadzJErcxsE2StbA/xOYU0".
	"XHntlaiKHm9PN2lkA1R8uvpVJ7+y3HkOgiAhxSFIy92YY3l466MY2Q0kDp/HZX/koUeVbTKqn5ZG".
	"RQOLNORz7RmE9GOOgJQC7wON+jB6JB1AO0VhDCJTdPNi4+6ZvSvlUVFZrxfS0V6A0v04fNzRxxE2".
	"G6iDbxq0VGx4/FF+ZuWZJbYpIZOP6yEDhKxy4dlv56Er7t2YVAWhoxmujYhvXPENzn/VeQyJAZTW".
	"dDuGrJaQYLG+zYBMeO2Kl3PahS+l8e4B2ng0tTI8aQrbokE12sB4SANOeu7aeQ8PPPPgWLIsWSOa".
	"alzles2SZNnUma89s1xMHrRGoSOctnH/5+Q8vO0RrO7EPCRA8GrlyqNPKAsNPTepkT0M7mL01Ah2".
	"7dqO0GFUKNBJAh3PYG0EefQhR5H4ZAoLKtHkwY4+9syTfVQiF2T2QqjyCkoyEl6+8mV9gYkt7JRQ".
	"gkc3P04R+TQsBkcgkWmvnwNt4B1nvx3REmsSl0b7YCYefGYD37rhOxQYjO9SqYky3huqskZKykAY".
	"ZFm6jAoVloSlDFJngAGUDwzpAVKdxipxVWK1p0vO33z5s7TT5tq2a43XKlWKmXz1CUefwEuGji1p".
	"Bw8yIAL4Yp6IatPmsW2PYLXtM6YSPXnScSeXEUy+iNDFETBMbX4cr/xYEJ4QBCFIDl1+OPKUY06i".
	"4pOVlOUzn8D6hx/AUvS5hp7+QghBr4kiI+GUl5zIgKqBgUQzakSHh7c8whazDVcSAKofMsuTtnBo".
	"upS3vvFtKCsxiWGG/eOdJd1w+XX/wtTsJpo2L0+/p8XLyNsCqAKC3OTkwdLpWnSAGhUk0LFtjDA4".
	"Ydhr9/Kv6/6VdQ/cQBjwGFPgnOOwpSt427lvLUFFDwTGFZz0aq7CsoOdPLDpfnxaoi2tqcj66pNe".
	"cmLp5+crTN70cHQkYgIFDz/xEDbkMeEzjpQKJxzzUuTxhx1P6hOU1wQXK9uPb3kSg8OKIu6xEMn9".
	"/tYJ0ZBHDh3JkBwU2kqq1XSq41vhyeeeHH1s+xNRx1EG2CIvYZOOD43mw+9dzZAYFjqIaMeKZNP2".
	"Z7j3gfXUszrW+rL8rDEWKmkGQeK8QCQZQqakFd0njAQyii6lpMBR1TXuf/QBssEs6FIwGlp+6rTR".
	"07jw9RciyiIweIwtYWzJF82ZJs9Ob+GxrU+GUPrUiqhQU3WOWn7081a37WXVOiaEXdps3vYU1luQ".
	"EuEEdV0XK486ETnaOJ7BbIgUhTcWh2Nfa//ELHPYHpgWoU8aEsAYj7OeBjV+4cxfoJZXsa4YDVVP".
	"O2tv/N6t36NNXsoZJFrKqJ8p/atCckx2DH/wa/+TRre+JpmBLE8YTgdYMbKiRDQaTMAUBRW94AvK".
	"lNwtEPKXhJRwsedTiRRvY6Nke66NsnrKzQUavsEytWzlR3/9Y2hSKmR9P5wk6aJWM5VIvvDVf6Sy".
	"JGpLRAKuGbjg7Ato0AAvscU8ikuSUjrhOlgsc8yxZ2bPqEpjeA0GarLBceJ4ZEaN4w4/jtQnUypE".
	"FWxIwuh375ykW4o8vS8Izve6LsgSiVKxheTic9+FaiZCCz3VDg5f81x54xVrQZBj+qUsJ8r2wUxS".
	"5AUVqrzjtLfzOxf91upj/VFiZG5AXPC6Czj71DPRQUDuQAgaaYkbBBRFdDOZqtFqdyPrq3vkU0J7".
	"ugsO6qrOXKvJZ393giMaR6/MmpVVx1aOFZ/+g89wjD6GOnU6zZyENMrvyipDbmORYZt5loc3PUS3".
	"HY0a2pDkyap3nv/OuLqNJ011XIAlS0iI1f05Zrnmjmtx2q32MuA9DFWHVh5zyDGxzVKiOfWEU1n3".
	"1C2rZSLWChnwKqy86vqruOT1F0c/pUSfowkhkjRCRCx+fON4Xnn8K7lr57rRbFjQMQWiWl357zd9".
	"lQ+e9WsYPFoocp9HMKU0qaoCjoyE3z7vN7nkNRdTHR5BklIPGXRCvznLdXJUtYoLoLKe39QMVzQi".
	"gCs8Ko0S6HqtQXtHQe3QlBX1FTzndnP9Z69nD7smlZUcqY8itARpVZNWl4AFrwuEUAQBqgptOlz/".
	"g+/zzJ6tGxkB2jCSDq05+ehXTJ5Qj1w/Zf0TUXbYaAghlgIlmqtvniQPZtwFTygCaZpMvWLlqWSk".
	"SEfgNae9Dm3FZCYU3joMZvTxrVO0ySmwZfAsSZ0yfQ1ASoUhBrnwrHfgc9Z0ZgMqEYQ0jH7n2m/T".
	"pk2TJoaCREoSKbDG4IyP4k4TSKlzVO1YlnEIS1iCz0UUnutY11RpFecMVnva0rCXGVp0aMmcGdnE".
	"1Qx5aBMc+BbUlkZqWAUYVsNUqXIkR3Ocfohu8AAAGqlJREFUPo46DYaqDej2IBxIUnITFeBNcuZo".
	"8sUr/pnGsB5VCpQWyE4y8YtnX1imO6r026bvYgVRQVaU1NljzzxBVxq8ilUL27K8/uWvJSNBVqhz".
	"2klnsGxghJpMBKVCth063PjkLXTJyYOJcMvHqykUsXcFSMk469XnUBWNyWo9w+eB5vTs5NP7t/Av".
	"6/61bFkqKEI7Kh1kgjEOESRpkkZuP80IZXekT2PRFlNG6QBWwixtrnx8Lav//nc55w/GOPcj5/GX".
	"k5/kMfsIedLFVzyyEQONacWCuHKCaqgyyAChJVCmrENq6LRsmb4LVKLp+IKA5Uu3fJlN+zeNd73F".
	"daEuGqRFbeq8V/8cgwyACeAdSSIIlJJlASbEpXnNo9czbVobvQYhJZmuUVd1Tj/xjGhw0AwwwCmj".
	"J0FhCc4htMRIxzfXfjtuYFEW+sqlLSWY4PGxqsCR9SMZO+fnJ6VNCB2oDVXHmq45/oVv/BNPh6cx".
	"5Cjhac3OIoSkUsmwfegXw3sooOgEvIRcRi1gdJddrMj57JWf4rf/+jf59j1XsmH/Q+Mb2w+Pf+pr".
	"fz7xjtVv5dH8Ybp0YrFeQzIETni0khGBOUk1rcwnJwlURzRznSaFt1HaICVb2lv44re/iB/wY0UH".
	"Eg1zezti7My3cezAMbGC7wXBxxKQL+1hjUGISNB97cqvI6rJBFoSrEGhJk894RRW6OUkpMhQZo3n".
	"nX0OWIf3kGSaHDPx4GMPMc105LMl0M0XdPDGbEDLqL34wHs+SOhKammG9x5fCSt3tHeM/c0/f5bn".
	"2EFCQj1t9NPfIDyCQEKCtrH+WE0FFsM+dtNM5siTWVw6xzfvvJzPX/GZ8VZ1Txg8OsV09tFm34Qa".
	"ZnyX2hnGP/khdrCdDjld5WmHAqcNlgIhwbWKPtlldJe2aNElJ60nKKkxweBw/O0X/45d+a7x6XZr".
	"LBmM53TMYcfxnot+hYxKlNVJiUiT+UTHe3QiCTim2c/DU49BIqaijwsEF1auOncVCh07VaO4K+Gs".
	"V55PIusIHzNOG7rjbT/HXQ/dQZPZiLuSeXjmgu9DswTFcRzDf3/nZWJELRGmaaeaeWechppce9v3".
	"ue6O62nTpOzsiMUKHaWywS2WbDsMFTIUgTmmuX///XzyS3/OXDI30VZz7HtuW8iOqEx0i6jntBW4".
	"f+vD4Y8/91FatJgxe9E6svA+WKwxqHoa6boEEA4N5HT6SZzxlm/f8nW+d8d3mDb7JpIhEDmoOcW7".
	"zr2YUxonR8+t4/tjYaVUEjtACDq0uHXDOprMrp21M2sxkFQGSYvKynNecW6s7TqN1Ba0U4ywglec".
	"/AYa2ciavGugAR05Ey7/2j+gEDFwViVIj3UWLaLaFGFJvGeIlN97y69zRHI4DTEyplR1Tcu5MVeR".
	"rLn883To4kQHRDsyU04SChnFlAqcsITEU6FCnRrKx/iw5sp/YlejNWEUJImCTJPP5VQSRdGOhJqv".
	"KG54ZB0Pdx+jmiQkeFTXUw0NVJpgVWycC8KTyIyUlCp1RE9doOArN3yJucbuIEfANGHED4iT66eK".
	"1ed9iCEqOBxW5VhtKSgQ6HhQIcnzHIvlc//2WfxQZyxUYytO2klXnnv6+YywnCp1KELs06yoFE2F".
	"d//8pbiOmvBdS5rK2Eqy9RG2sYN9Zrbfpq2Vpt1tl1K4AEJSLWnNv/jD/4WfYWpADa0WhZxsz3Q4".
	"7LDD8AQMhhAKQlH0a4C6lKw4bfE4NIIETSYztrV2cuej97C/HVlFF3w5MCFmKErHtDoowbSbDd+6".
	"7tsUUU6L0tXoAkq3bXsa0DCfKStk7ErD8eQzj1MbqAjfhsRA1qrzl7/zGZaxFGUlzpuyAc/H7+1l".
	"v7IVMsnmYjPPzm5l1hiCjegnbeupd77lQgao42zs2pOkHlPk1NCcdfyZHH/EiVMiVJEWXHB0GoRP".
	"fOHTVJJ6RBFF5B2WVhqxquJjcVWRUmeAU0ZO5i9+/88YMlWW2gYr1BJeu/KVpKSxEVZXEZVaLE+V".
	"51wYixaqJMqi3NjguenOW9j+3M7xHtXofYg0g5C44EvenTjrRQQmr7+GGeYoet2/3iIWq53LyT+y".
	"pANAyUg2//p7f5PZp5ocIZaJY7IjxR/82h+y8rCVSATWWrRMkWWSJLzoUwFBewo6/O2XP8++dnNC".
	"KNBS0HAVRg95CWed9MaYbYYACjTSYIuClBoD1Ljk/Et49O8fWSUG7FoUtHXB9etv49F9T3L6kjNI".
	"U112bkEidVnaVMy0Z8hqKZBz3qvO4axXncMX/v0LnP36N/CqY09jiHqM8iXjONcxJNWEVFFmrS76".
	"ueBxwWCk45rbrierZqt9zeMoCEV8bSI1ucv7yUdwlqxSn9yxdwePbnmcw45eFjOSLLKUKoKpkmaW".
	"/cbWXj6XkXLRmy/i6MOP5IlNj/HKl7+a1x7+OqrUIm2bxHc5AjpolMxiENbQoskPdt3HdXd9n+pw".
	"Y6xwc2AUfsaJ9/3qpVTLkrwuOzqkKZpUqxV8EahQ5aLXX8DxQ8dOuhyoKLwp6KbF+Mf/4VO0cBRl".
	"Q1Uv6jsHDkmjNsT0bJMGgxzKoRzOcj5yye9x5rGvZykDaJ/EcUYmrspKI4kFDw9KCkLw86kslt3s".
	"Y8Pmx3AyKpdCSZ0mIrqxIAJkomzSDVjhxsjE+LW330COo5PPlcfzCypWUbTfp/oCWGdpddoMM8zP".
	"nTDG+Pm/yRsPfxPSlP2bIZ6fd4HgAqmslDSApRlatJjh7761hmnmQjvYUXxC5utTpxx+Mm951dmI".
	"4MoOPsidRaokjhpIREZKwqEs5UPv/jVsy03iBTQ0zdl9q+/ZvJ5vrr8Sn9g+60fhSslvTLiXDx4a".
	"RfRBEgpHnSppoUtjC9BVKFuoOx7aZr6kFJyPsl8sQTrWP/Ugs7To2nzUOxflLglI73BFTqkxRoi4".
	"aYzrEtKw8qZ71mGwqGrsk+9PhFjQCxcW9GgmSjJcHaJGg4qrUPMN6jRITFpq3Ms4YHx/RxvvUFWJ".
	"l4bvPvFdrrzjqlFfA9PuUBH1SdWUYx+69MMslUM0RKXspgs455BSVum0TRyIlceWkV/62Ys4+/Q3".
	"rZK5QjkBCaN22PHxL3yCZ8M2CtGhcC3I4pVLtcCZgLeeiqxSo8pwOoQOCZlqxHlYsrpIDJpKqCbz".
	"RKfSOq5uGeUU37vtWkw1irAlAq0FSkLwPop3tAJnozZfA8HiUti6dxsP7NlQKqOeP+ep/0yvGOUc".
	"rrAoL0lsinYKLNSqlUV6zUTEQosxjoJYnN5onuRTX/kUJmNjWk9I0hpZN1n16tHXTJ3/ilXUGSiH".
	"EkhwFiUCMoT4wlgBFyg0FRJ+/ZL/h2HTWKVzgaxK9s9sC9NyL3/9759lmlnIZMwWQ4+iFCglS1G6".
	"wOchzlrqTQQKRIQhevJf068ktdqdeT46ts5yy/pb6KpilETgvceagCmihjHNdORETcDZ6NbiSYTR".
	"QpqJux66lw5FWRiNcUH8kGkSaZLOX4mS23Z+sdYwuJ6KSyKloM0c//itf2Rq3+YglkGr1SI03eql".
	"eikf++0/LRsaErxx5TwxRZakSGtBS9kvLblg0Ehet/zlfPit75tsuMYqn3vS4ZQ5tyd86ftfXvtv".
	"936dFl1UohaJa4UApSP3LVNVztAqX5AKyFQ5Y8pTV6r/p2o1I1hbahYN659ZTzu0sK69MYiAFCIG".
	"OQlKReIIE3dlVHzFpMZ6M6YbauLaW6+jQxeLKwsoiyc+LeqPlQvaE3WpZ1AQVFTueizdrkUm9PWW".
	"hpwv3fBFvnHD1yZcJbbpqEJwWOWQNeeefhYnNU6kRh0fBDLN5kd+ODlfxOn1y1hr8LZgGYO855x3".
	"cUR62GRd1CnmCgZGquRJZ+wv//6v2NndFTuChV808GrRJpbzPTlBRH7Dl69QZd+69w4tJCLR5XAm".
	"z/X33MyMmR4nC30KQYT5oWBe9DBlJLpcr0pmOrRNe+POfTvZnu8sDR7PUf0obf3luTphY/MUUVBa".
	"qUY6NpioCN7r9vKlb1zOXNHc2KvQyaYQh1YO4WMf/AhpifI7hVncBe2jF4kaERcIwpKlSYmhMo5r".
	"HM+f/vc/ZkkxJKpB053r0KhXJ6WEqac3RfKqHJ6F8L2sPT5KyOVKSGaYh2aS3pwEjwqLhhPRxXLD".
	"vTeR052IZX5fKr6izHzR9LjYxRIvcHnQIAN7m/u4/8kNdHtQqtT6qYV4vK959yycdReELSc5ulIV".
	"6efHAybQcR2efnoT3W6boVp9ShnB8my5OFQfwsd/46PUqFIho5V3qGa1UkfuF+jHSyxrRW8ClaeS".
	"1cEneKM498Rz+b33/jbVTnW1aumpMONXjlSHOfnEUxbO9ywvon+xgaP9nnp/wBVXUpWTQWPZeXOx".
	"g2f2bCsFRnn/2HLBuD4ve5yMxJdIUgvQWqES6JKHm+6+pW+2Hgx83vQ+2dNUz/vq+Zamed5odnY2".
	"UrCFI1MpJx1/MoPZMLKpJrNmtlruDqz+5dWc/pLTqZZdcI1sgK5t9+cB9DxAxGgKtJYUdNCociis".
	"JlF1bDHDpW/4bwyvWL7mq9/7+prMaN5/0ftZzlK6pkum6wvtFxWlC1aTWvC3+S69xXP38jwnSRQW".
	"uP7um+nofK0XeT+ABVF6rtKdhNJWRNFU31BaeGzwqERO3vqDu5i5rMMgdZSIGbFiwe54kRF+sRV4".
	"/gUSiUpiXEpqcbZARoVP/PYn+OY132Tf3L415581xi/9zHuoUqfbNDTqCU44KjplvjRU/i8Usd/c".
	"CFNWccDZ+C9VKvwL0WGaFh3aDFJHkxC8ZkA2St8aJ266BUZWYf6zguhJ+mLZNqUU3JTIxDmLTCSz".
	"tLnkU7/MuqdvDm09Oz9Z1UNSVmiKpGxgKmLDrssKfAhIE4OqcYqaHl6V78wnv/W5r3HO8tdRpw4u".
	"Bi9b0gmq78RKrOIXTxftzaHNi5wszeJKn5ulPlDHYZlx01RUSpP9DDBExiC+gIqOn2NKtXBMWeIg".
	"nOhSlMebDirEaWuWyCh5G3AG5uZyFHWWsoQjOIIBhklcxqBozEt0hcQhSx3JfCdG7xGLz/JF50Iq".
	"HZHC1tntPLFlE91gIgOwQD4mw+Lg1kNHUsbIL3tSahFwzqxN69nYDTffVC6C+YGNfaUHflFT8wId".
	"Tz/oCC9JVIrH0zFt6gN1BAJbOJarQ6n6GoexghoV8pk8GhsoikAItj/MZmH/kER4pNZIFN57cpMT".
	"gCSLbFxjsIoEXCuUGaOkIqssdsgLoOFCs4oX+juLG5h8XMI5BVPbn2A634v3eTlxqDc7UPRdycIC".
	"iBceYxzOlTmTjKrtrmmRDFcnb7hvXan+cn1/LRc4i/9wNGjoxZhAmqQIwBSGetqIF4MqImSoUGVg".
	"YBCXz/cCJSJWQBc1bEnQvcnClC3aNbm4o6tnoLQWgahO1UKHN39iggUKKzn/XYQvPYvvtyJ6Ip4m".
	"QMh7JNAcV9/9HXI1HdAe5+JoEmwUtDgRW2D6A2zKqURClApfCcY6hASZwYybDkWrEFPtKU6oHMuA".
	"TGKXR1Do2M+FkHI+fRfM5wwHLIooSIo/lTRZvJjE/LdWlfnnY+KTvsCx+ldalnnXi+DVA/9wwO/i".
	"ABRQDs7pD3Drja0T5fbukUhCRY55lhk2PHU/7aITc4JyJo0o59Z6IUv8XV4oQXkB5k/C95CGdKAs".
	"hTYT199+I0qmOGxf7hFCVEuJF/p+8gBB5YLphs/bvWLBTnk+BDrg8UNj9Y85EvqHTEuWL/rffMJl".
	"8Ty9dwubnnk6ShNKFbHQ//EEst6F7ZcYxbw/kAFuuOWmctyp7QHhmBGrgzW47//yqO4Dr48TkGO4".
	"9c5bMdixpJb0d4TqW0W++LBxEZ4/nrofbP3Y5u3PsI/pcu6o6xV8SNTz+n1/mgzuf+jCFwsEMwtn".
	"n8ThqfG/G++8GV1NproulqjQYAtLEPI/tPOi2WJ9g3sEYbRpO9z6wF3lSDPT19OIALb4qVzhnhdg".
	"URZbI7wQaxRfbfBsy7ezefvTeB3GQjcGL1VRi+5WEV7MdS1oyw4L/t7LDwppRm+8e13sWSo/1XjX".
	"D/Q/dQYPJaadH2e3cEj5CzwW/Lhyhd983zq6sqDj83HSUvbrIsUnAi98tfpX4YX9gij5HaPc6vVP".
	"bmA/e/pD+GTpS6Ti//rgRPlfX93+x3fkfRM6CgpuvPtmQiVEwWetbAOb88hFk91+PIfbX+HKj23Z".
	"u5VnntuKoYvFIPpqpJ/SoOlf7MwXPN3riuvn6sJjsEwzzfrH7iMX+XjQHmdcZKJS8IXrT199oasn".
	"XqySE+KwvSACVphRWddce+v3yxFNvPBgyZ8Gg4cfNkT3gD8qpfqGDiVQCwQeeOYBmmEOI80EqqwU".
	"mFAmXer5p9gngVhw64MF3mVhDVN4RE0xU8yF2x+4kwIX5W8HcQDrTwilLMgYwvMN5H3ZwNjnMMq+".
	"eiw33XE9Hd/aaEUxj9PMvHJE/oi26Rm8vCcTXgS89AQd8Elgw6ZH2Bmew/bjTeBHq0r8/8rg/wEf".
	"0eeYXVmgcP1Js4FAly73PHgPVplRJ8z8dXMgRTR2r/DwfP8vF221Hr7u3XoibjQPto2sSkwaJm6/".
	"/67yMJFRCz+9K/z5KezzDUR5PxFXjvi1TD33FM8+twWVyjjFYQHLJUpp8AHzjZ4fGMNiX6PKYZKh".
	"p/bxHm87pEOV1VffcM08NAwuqjJ+mgwu+BFAhAChZB/L9GCkJ3DXPbdTuHxMpQdARxVbGJV4EZcS".
	"XsDoPQKu15HQu1ZVBYWhUJ71j21gjtn5cHsQ7kwmfxKHkAsEMy/4CiHLnshoHYunwHDz7esQOkx4".
	"sWB8kOvJEhxKSH74Ta2e/7kixFW+KLRk0DHd0MxbPLjhfsAjhfrpdCniwIRSvPBilF6Vk/Y1Fs8c".
	"s9y/aT0+caMu2AMUlzHQBh0ZwV7lfmHyFDNLv2i5h/7zYn7ltx2iXsX5DmRi7LYN99AhjtB27r9w".
	"W5twUH24LyvdZnEiJMo7sAWLDgplJdpHWfP3HrqK6ca+jXmS43rTuUojCQ8iFXRDF6Pi+AzxvIzV".
	"E6RblM4HIcmVpJAy3v/IxWwytDogA74aRr950/folHfvSZV83oJ5fmL8Ipnzf9Lo/3WDh/l5UVHH".
	"sfBupR4TbJw96+YLFR7PtXdeQ1EtRq1yi/DzvP4kCja9LIWbC1+zgL0KB+woJySud8fDnpJKRCLB".
	"Cjux37V4cM8jQMAE89Powxez3uIA5NJvyCrRhxWBOea4f8ODcRb5T+InPB+PLzq7Mn8SCnJfcNPt".
	"N0a0JNyLspvzG+fFCgwHy+CBF9Z8LEjArXd9oU3bt3ho00PxZnHu/8ytwRYWJYLo51xxNqFyY3ev".
	"vxtT3jnL/7i3JxP8l26JI39yW+XFsk2BkgrjDFZ4hBR8/5br8MovmoT2nw7a4QUItTLIejF/a088".
	"FN5AAk89O8Uz7U2xBWZx3f5H31DioLqUnlsRz+NUfBkPuy7HYsjJueOBO5jtzIWk8pP5eMFi9LKQ".
	"pe+fkioz3iSMtl2TOx+4HUv+Y63wA+NlOJgGn583Lhf5VVVWbGRFUWB4dO/D7JzZjsH0RZ4/sRVe".
	"Buuw4EnV40syAIuTbrXLPDfedQOG2H3MD+PxXwCQ9KR7/5l7DP9kisj9M5IvsCTmR0UXFNx8380U".
	"2pDVM4rO//nbO/qeXbQCF+j4zqjTbuwHj62nSTNqVn4Mw/kD/h0OnktZnGL3fkxhkSLB4sjpsO4H".
	"63CpG201u1OVevIT2VsiLBDQvBAp5YnjQAbirWJm85m1Ld8cu/eZe0s6LVDYPDKZ3lCYeN80Zy0/".
	"AtV/kFb4oqA1/3ySaKy3FOTsZhfrH//BWCe0NyZ1NWqM+ckGTRGehySCY77oXxjQgspABZPYtbfd".
	"e0v/PqK+fK9UiiRJ6HY6fQneQolcj/wSB83gL2b0fiYS+/E9jnsevof/r7nz942jiOL4583u7O75".
	"fI7wAZHBsmQwooACSAOhQTTIFIECiZ7eRf4RCqz8EWkoIgwNTRoSpYiEREQuOWRLYBLDxeGw725n".
	"f8xQzPp8uTuBlDsMK522uGb27czse/O+P4jdVlgP2tZ6dNV8l9fkWMJwfFil9362huvfXR/qxIaB".
	"9kAKWyIiQxHg/13h88QZikz5epfD5JCdb3ewid3sHh1vOBGiIPLbwcx59/RCQDkvLj9kAkRep7ow".
	"BtGOg8PfaD28y8AOsJVDXOG88FRcS8bAjOPgLIt6ipk+c4vNDp3UTibR2Nc79PyDnIy9/V1KKbx6".
	"T71OlhXzLTNHt5OTNlt+mnmIhEN98HgxaRdSbH1/5wdEBQzK1DMRA411VY0gzP38duauvWM6NW90".
	"+udFzq3WLX55uL+ROUOwLGRZNjSr+7euqv9AVCnCuSyDwhIkEaYwGwPT39755isUijiIMC71Q3bO".
	"E7fG3+k/VNVntIePZwWTU0KHmkePO9QWa+08dZS5wwwMtaQ+5whPL8d0EHnZiQoQ7pwj7RWcW36G".
	"o36P49L7BUXi0a6iAt/0dn+flsh/E3CZKPHV6F+lP0/56O2PufzZZdabaxJ2hfP6vAR/SjvOY8JC".
	"E5YBqgy8jLSTCSjb6W8EZuXE00DHp9wJqNYJYgVrLKRCopa2Q1snGcTEueaNly9w5fMrLAUNCryB".
	"XVqlhGoMtj09dOopVt0MBxpuZAORaUVPdT/KjgkSwWD4sXOHq19e5caNmzw2f9Bb6NEtu18rrTb1".
	"QrSdFoOtQZaiYtA1jTH56fNJVcmeQGSVp4pPkEUdqFxQuaIWJJAFbZfJ/bDQH9Z1nfXVdS59cIlP".
	"L35CkyYJGp5gaEzpYLn5nBbOFHA/jrGAu8kF4CqTDjtkYjoeZR12H+xy7eY1bt+7zd2fWhynR5Dw".
	"RbAgG7kqNnuZIWmE5K6ktCOteSuI0qjAY0/AItZTz8n8GCKlSSQhPTSy9twab716gffeeZ9337zI".
	"SvgCYeWFG6O9KOUZXXMJuK1M52RKV9Y6ixOLKQx5mRMlumpYOFL6gCOrfMc7/M79/Ratn++xd7DH".
	"g8NfOeh2GGQD+qZPmhmMyV1ZeF/PKIxfWQjj9rl4kaVGg0Z9iWajyYvPr/LS6joryyu89uzrLNHw".
	"Al+V8pRGo6zXXVTq7IIN8BfzVOB/JYrRQwAAAABJRU5ErkJggg==";
  open(OPENICON, ">open_ap.png") or die ("Unable to open file\n");
  binmode(OPENICON);
  print OPENICON &decode_base64($openapjpg);
  close(OPENICON);
  
  open(WEPICON, ">wep_ap.png") or die ("Unable to open file\n");
  binmode(WEPICON);
  print WEPICON &decode_base64($wepapjpg);
  close(WEPICON);

  open(WPAICON, ">wpa_ap.png") or die ("Unable to open file\n");
  binmode(WPAICON);
  print WPAICON &decode_base64($wpaapjpg);
  close(WPAICON);
  
  my $zip = Archive::Zip->new();
   
  # Add a file from disk
  my $file_member = $zip->addFile( "open_ap.png");
  $file_member = $zip->addFile("wep_ap.png");
  $file_member = $zip->addFile("wpa_ap.png");
  $file_member = $zip->addFile("$kml_file");
     # Save the Zip file
  unless ( $zip->writeToFileNamed("$outputfileprefix".".kmz") == AZ_OK ) {
       die 'write error';
  }
  unlink($kml_file);
  #cleanup - delete all created files
  unlink("open_ap.png");
  unlink("wep_ap.png");
  unlink("wpa_ap.png");
  
}
#From MIME::Base64
sub decode_base64 ($)
{
    local($^W) = 0; # unpack("u",...) gives bogus warning in 5.00[123]
    my $str = shift;
    $str =~ tr|A-Za-z0-9+=/||cd;            # remove non-base64 chars
    if (length($str) % 4) {
      print STDERR "Error in jpg file data\n!";
    }
    $str =~ s/=+$//;                        # remove padding
    $str =~ tr|A-Za-z0-9+/| -_|;            # convert to uuencoded format
    return "" unless length $str;

    ## I guess this could be written as
    #return unpack("u", join('', map( chr(32 + length($_)*3/4) . $_,
    #			$str =~ /(.{1,60})/gs) ) );
    ## but I do not like that...
    my $uustr = '';
    my ($i, $l);
    $l = length($str) - 60;
    for ($i = 0; $i <= $l; $i += 60) {
	$uustr .= "M" . substr($str, $i, 60);
    }
    $str = substr($str, $i);
    # and any leftover chars
    if ($str ne "") {
	$uustr .= chr(32 + length($str)*3/4) . $str;
    }
    return unpack ("u", $uustr);
}

sub norm_power {
  my $in  = shift;

  return 6 unless ($seensignal);

  $in     += abs($minpower);
  $in     /= ($maxpower+abs($minpower))/5;
  $in     += 1;

  return $in;
}

sub parse_gps {
  for my $network (@{$xmlin->{'wireless-network'}}) {
    next unless ($network->{type} eq 'infrastructure');
    my $wap = {};
    $wap->{ESSID}   = $network->{SSID};
    $wap->{BSSID}   = $network->{BSSID};
    $wap->{Channel} = $network->{channel};
    if (ref($network->{encryption})  ne 'ARRAY') {
      $wap->{Encryption}  = $network->{encryption};
    } else {
      $wap->{Encryption}  = join(', ',@{$network->{encryption}});
    }
    if ($network->{'wireless-client'}) {
      if (ref($network->{'wireless-client'})  eq 'HASH') {
        $wap->{Clients} = 1;
      } else {
        $wap->{Clients} = scalar @{$network->{'wireless-client'}};
      }
    }
    $wap->{Clients} /= 0;
    $waps{$network->{BSSID}}  = {desc => $wap};
  }
}

sub parse_gpsxml {
  foreach my $network (@{$xmlin->{'wireless-network'}}) {
    next unless (defined($network->{SSID}));
    next unless ($network->{type} eq 'infrastructure');
    my $wap = {};
    
    if ($DEBUG == 1)
    {
      #print STDERR ref($network->{SSID})." . ".Dumper($network);
      #print STDERR Dumper($network);
    }
    if (ref($network->{SSID}) ne 'ARRAY')
    {
      #print STDERR Dumper ($network->{SSID}->{essid})."***********\n";
      if (defined($network->{SSID}->{essid}->{content} ))
      {
        $wap->{ESSID}  = $network->{SSID}->{essid}->{content} ;

      }
      else
      {
        $wap->{ESSID} = '(none)';
      }
    }
    else
    {
      foreach ($network->{SSID})
      {
        #print STDERR ref($_)."\n";
        if (ref($_) ne 'ARRAY') {
		  if (defined($_->{SSID}->{essid}->{content} ))
      	  {
            $wap->{ESSID}  = $_->{SSID}->{essid}->{content} ;
          }
          else
          {
            $wap->{ESSID} = '(none)';
          }
          if (ref($_->{encryption}) ne 'ARRAY') {
            $wap->{Encryption}  = $_->{encryption};
          } else {
            $wap->{Encryption}  = join(', ',@{$_->{encryption}});
          }
        }
        else {
          foreach my $test (@{$_}) {
            #print STDERR ",,,,".Dumper ($_);
            #print STDERR "----".Dumper ($test);
            if (ref($test->{encryption}) ne 'ARRAY') {
              $wap->{Encryption}  = $test->{encryption};
            } else {
              $wap->{Encryption}  = join(', ',@{$test->{encryption}});
            }
          }
        }
      }
    }
    $wap->{BSSID}   = $network->{BSSID};
    $wap->{Channel} = $network->{channel};
    if (ref($network->{SSID}) ne 'ARRAY')
    {
      if (ref($network->{SSID}->{encryption}) ne 'ARRAY') {
        $wap->{Encryption}  = $network->{SSID}->{encryption};
      } else {
        $wap->{Encryption}  = join(', ',@{$network->{SSID}->{encryption}});
      }
    }
    else
    {
      foreach ($network->{SSID})
      {
        #print STDERR "***".Dumper($_);
        if (ref($_) ne 'ARRAY') {
          if (ref($_->{encryption}) ne 'ARRAY') {
            $wap->{Encryption}  = $_->{encryption};
          } else {
            $wap->{Encryption}  = join(', ',@{$_->{encryption}});
          }
        }
        else {
          foreach my $test (@{$_}) {
            if (ref($test->{encryption}) ne 'ARRAY') {
              $wap->{Encryption}  = $test->{encryption};
            } else {
              $wap->{Encryption}  = join(', ',@{$test->{encryption}});
            }
          }
        }
      }
    }
    if ($network->{'wireless-client'}) {
      if (ref($network->{'wireless-client'})  eq 'HASH') {
        $wap->{Clients} = 1;
      } else {
        $wap->{Clients} = scalar @{$network->{'wireless-client'}};
      }
    }
    #$wap->{Clients} //= 0;
	
    $waps{$network->{BSSID}}  = {desc => $wap};
	
  }
}

sub average {
  my $points  = shift;

  my ($lat,$lon);
  for my $point (@{$points}) {
    $lat  += $point->{lat};
    $lon  += $point->{lon};
  }

  $lat  /= scalar @{$points};
  $lon  /= scalar @{$points};
  return $lon .",". $lat;
}

print STDERR "Beginning GPS point scan\n";
my $route;
for my $point (@{$gpsin->{'gps-point'}}) 
{
  # Ignore any points without a full 3d GPS fix
  next unless ($point->{'fix'}  >= 2);
  # Special case for the path taken
  if ($point->{'bssid'} eq 'GP:SD:TR:AC:KL:OG') 
  {  
    $route  .= $point->{'lon'} .",". $point->{'lat'} .",1 ";
    next;
  }
  # Ignore points that aren't APs
  next unless ($waps{$point->{'bssid'}});

  my $bssid = $point->{'bssid'};

  $seensignal = 0;
  if ($point->{'signal_dbm'} && $point->{'signal_dbm'}  != 0)
  {
	$seensignal = 1;
  }

  if ($seensignal) {
    $minpower = $point->{'signal_dbm'} unless ($point->{'signal_dbm'} == 0 || defined($minpower) && $minpower <= $point->{'signal_dbm'});
    $maxpower = $point->{'signal_dbm'} unless ($point->{'signal_dbm'} == 0 || defined($maxpower) && $maxpower >= $point->{'signal_dbm'});
  }

  if (!defined $waps{$bssid})
  {
    #print "Not found: $bssid\n"; 
	$waps{$bssid} = {
		points  => [],
		ssid    => $bssid }; 
  }
  
  
  
  if (!$waps{$bssid}->{time})
  {
	if ($DEBUG) { print "$bssid == $point->{'time-sec'}\n"; }
	$waps{$bssid}->{time} = $point->{'time-sec'};
  }
  elsif ($waps{$bssid}->{time} > $point->{'time-sec'})
  {
	if ($DEBUG) { print "$bssid ==>> $point->{'time-sec'}\n"; }
	$waps{$bssid}->{time} = $point->{'time-sec'};
  }
  
  #unless (defined($waps{$bssid}->{time}) && $waps{$bssid}->{time} >= $point->{'time-sec'});
  
  push @{$waps{$bssid}->{points}}, $point;
}
print STDERR "Finished GPS point scan\n";

my $gen = XML::Generator->new(
  pretty    => 2,
  escape    => 'even-entities'
  #escape	=> 'always'
);

my @elements;
if ( $DEBUG )
{
	#print STDERR %waps;
	print Dumper(%waps);
}
#Remove APs with no points in the Kismet outputs
foreach my $test (keys %waps) {
	if (!defined $waps{$test}->{points} )
	{
		delete $waps{$test};
	}
}


# if ($DEBUG)
# {
	# foreach my $test (keys %waps) {
		# print STDERR "$test : $waps{$test}->{time}, $waps{$test}->{points}\n";
	# }
# }


print STDERR "Beginning WAP calculations\n";
my @points = ();
for my $wap (sort { ($waps{$a}->{time} || 0) <=> ($waps{$b}->{time} || 0) } keys %waps) {
  my @sorted  = sort {$b->{lon} <=> $a->{lon} ||$a->{lat} <=> $a->{lat}
                     } @{$waps{$wap}->{points}};
  if ($DEBUG) { print STDERR Dumper(@sorted); } 

  
  my @convex_arr;
  foreach my $point (@sorted) {
    #if ($DEBUG) { print STDERR Dumper($waps{$wap}->{points}); }
	if ($DEBUG) { print STDERR "\nPoint : ".Dumper($point); }
    if (@points && $points[$#points] &&  $points[$#points]->{lat} == $point->{lat} &&
                              $points[$#points]->{lon} == $point->{lon}) 
    {
      next unless ($point->{signal_dbm} && $point->{signal_dbm} != 0);
      # Multiple points at the same location may have different power levels
      push @{$points[$#points]->{signals}}, $point->{signal_dbm};
      $points[$#points]->{signal_dbm} = Math::NumberCruncher::Median($points[$#points]->{signals});
	  next;
    };
    $point->{signals} = [$point->{signal_dbm}];
    push @points,$point;
  }
  
  
  my @signals;
  foreach my $point (@points) 
  {
    next unless ($point);
    #if ($DEBUG) { print STDERR $point->{lon}." ".$point->{lat}." ".norm_power($point->{signal_dbm})."\n";} 
	push @convex_arr,[$point->{lon},$point->{lat},norm_power($point->{signal_dbm})*50];
	#push @convex_arr,[$point->{lon},$point->{lat},180];
	#if ($DEBUG) { print STDERR "Lon: ".$point->{lon}," Lat: ".$point->{lat}," Pwr: ".norm_power($point->{signal_dbm})."\n"; }
  }
  if ($DEBUG) { for (my $i=0; $i < @convex_arr; $i++) { print STDERR $waps{$wap}->{desc}->{ESSID}." : ".$convex_arr[$i][0]." ".$convex_arr[$i][1]." ".norm_power($convex_arr[$i][2])."\n"; } }  
  my $arr_convex_ref;
  if (@convex_arr >= 3)
  {
	$arr_convex_ref = convex_hull(\@convex_arr);
  }
  else 
  {
	print STDERR "You need 3 GPS points at least for mapping\n";
  }
  
  my @convexhullcoords =  ();
  @convexhullcoords = @$arr_convex_ref;
  my $coords = "";
  for (my $i = 0 ; $i < @convexhullcoords; $i++)
  {
    if ($convexhullcoords[$i])
    {
      $coords .= $convexhullcoords[$i]->[0].",".$convexhullcoords[$i]->[1].",".$convexhullcoords[$i]->[2]."\n";
    }
  }
  if ($convexhullcoords[0])
  {
    $coords .= $convexhullcoords[0]->[0].",".$convexhullcoords[0]->[1].",".$convexhullcoords[0]->[2]."\n";
  }
  if ($DEBUG) { print STDERR @convexhullcoords; }
  my $color = $transparency."0000ff"; #Default red (alpha=00 for xparent,blue,green,red)
  my $icon = "";
  if ($waps{$wap}->{desc}->{Encryption} =~ 'WEP')
  {
    $color=$transparency."00a5ff";
    $icon="#wepicon";
  }
  elsif (($waps{$wap}->{desc}->{Encryption}) =~ 'WPA')
  {
    $color=$transparency."00ff00";
    $icon="#wpaicon"
  }
  else
  {  #open
    $color=$transparency."0000ff";
    $icon="#openicon";
  }
  push @signals, $gen->Placemark(
    $gen->visible(0),
    $gen->open(0),
    $gen->Style(
    $gen->LineStyle(
      $gen->width(1.5)
    ),
     $gen->PolyStyle(
      $gen->color($color)
     )
    ),
    $gen->Polygon(
      $gen->extrude('1'),
      $gen->altitudeMode('relativeToGround'),
      $gen->outerBoundaryIs(
        $gen->LinearRing(
          $gen->coordinates($coords),
        ),
      ),
    ),
  );

  my $id;
  if ($waps{$wap}->{desc}->{ESSID}) {
    $id = $waps{$wap}->{desc}->{ESSID};
  } else {
    $id = $wap;
  }

  my @description = map {"$_: " . $waps{$wap}->{desc}->{$_} ."<br>\n"} grep {defined($waps{$wap}->{desc}->{$_})} keys %{$waps{$wap}->{desc}};
  my $pointcoords = average(\@points);
  

  my $xml   = $gen->Folder(
    $gen->name($id),
    $gen->Placemark(
      $gen->name($id),
      $gen->styleUrl($icon),
      $gen->description(
        $gen->xmlcdata(@description),
      ),
      $gen->Point(
	$gen->tessellate(1),
        $gen->extrude(1),
        $gen->altitudeMode('relativeToGround'),
        $gen->coordinates($pointcoords . ",1"),
      ),
    ),
    $gen->Folder(
      $gen->name('Signal Strength Map'),
      @signals,
    ),
  );
  push @elements, $xml;
} #end of foreach $wap
print STDERR "Finished WAP calculations\n";

print STDERR "Printing KML\n";
open (OUTPUT, ">$outputfileprefix.kml") or die "Unable to open output file\n";
print OUTPUT '<?xml version="1.0" encoding="UTF-8"?>' . "\n";
my @pointemp = split(',',$route);
print OUTPUT $gen->kml({'xmlns'=>"http://www.opengis.net/kml/2.2"},
  $gen->Document(
	$gen->name('Kismet - ' . $xmlin->{'start-time'}),
    $gen->Style( {'id'=>'openicon'},
      $gen->IconStyle(
        $gen->Icon(
          $gen->href('open_ap.png')
        )
      )
    ),
    $gen->Style( {'id'=>'wepicon'},
      $gen->IconStyle(
        $gen->Icon(
          $gen->href('wep_ap.png')
        )
      )
    ),
    $gen->Style( {'id'=>'wpaicon'},
      $gen->IconStyle(
        $gen->Icon(
          $gen->href('wpa_ap.png')
        )
      )
    ),
	$gen->LookAt(
	  $gen->longitude($pointemp[0]),
	  $gen->latitude($pointemp[1]),
	  $gen->altitude('0'),
	  $gen->heading(),
	  $gen->tilt('60'),
	  $gen->range('1500'),
	  $gen->altitudeMode('clampToGround')
	),
	$gen->Folder(
	  $gen->name('Kismet - ' . $xmlin->{'start-time'}),
      $gen->Folder(
      $gen->name("Route Taken"),
      $gen->Placemark(
        $gen->name("Start"),
        $gen->Point(
          $gen->extrude(1),
          $gen->altitudeMode('relativeToGround'),
          $gen->coordinates(($route =~ m/^(\S+),\d /)[0] . ",0"),
        ),
      ),
      $gen->Placemark(
        $gen->name("End"),
        $gen->Point(
          $gen->extrude(1),
          $gen->altitudeMode('relativeToGround'),
          $gen->coordinates(($route =~ m/(\S+),\d $/)[0] . ",0"),
        ),
      ),
      $gen->Placemark(
        $gen->name("Route"),
        $gen->LineString(
          $gen->extrude(1),
          $gen->altitudeMode('relativeToGround'),
          $gen->coordinates($route),
        ),
      ),
    ),
    @elements,
  )));

close(OUTPUT);
print STDERR "Generating archive\n";
create_kmz($outputfileprefix);
print STDERR "Done\n";
