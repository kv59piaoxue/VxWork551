# diabLibFind.tcl
#
# modification history
# --------------------
# 01b,26feb03,s_l  merged from tor2_2-cp1-diab
# 01b,18feb03,sn   added support for Diab 5.1 standard vs abridged library
# 01a,24oct01,sn   wrote
# 
# DESCRIPTION
# dplus -## dummy.o | wtxtcl diabLibFind.tcl <lib> <alt-lib> ... <alt-lib>
# Parse the output of dplus -## dummy.o to determine
# the library search path. Then search for library
# <lib> and output found library path to stdout. If
# can't find <lib> then search for each <alt-lib> in
# turn.

set libs $argv
gets stdin line
regexp {^.* P,([^ ]*) .*} $line dummy link_path
regsub -all ":" $link_path " " link_dirs

set found 0

foreach libname $libs {
    puts stderr "Searching for $libname in"
    foreach dir $link_dirs {
	set lib $dir/$libname
	puts stderr "  $dir ..."
	if [file exists $lib] {
	    puts stderr "-> Found $lib"
	    puts $lib
	    set found 1
	    break
	}
    }
    if $found {
	break
    }
}

if { ! $found } {
    puts stderr "Could not find $lib"
    exit 1
}

