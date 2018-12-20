#
# mkBspArch.tcl  The tcl file called by mkBspArch
#
# This auto-generates the BSP_ARCH.TXT file
#
# Modification History
# --------------------
# 01g,01Oct02,nwd  Added TDK-14860 to pick up the wrPpmc824x BSP.
# 01f,18sep02,sfp  update for wind vobs
# 01e,04sep02,sfp  update path again
# 01d,04sep02,sfp  fix typos
# 01c,04sep02,sfp  update for wind vobs
# 01b,21may02,sfp  fixed to run standalone
# 01a,31Jan02,sfp  written


proc addFamilyList {bspCpu archs} {

# for a given CPU, scans the cpuFamilyList file and returns all
# the cpu families that supply the CPU library, appended to archs

	set cpuFam "/wind/river/.resources/cpuFamilyList"
	if [catch {open $cpuFam r} fH] {
		puts "Error can not open file: $cpuFam"
		exit 1
	}

	while {[gets $fH line] >= 0} {

		# ignore comments
		if { [string index $line 0] == "#"} {
			continue
		}

		# skip the first 3 entries on the line
		set cpus [lrange [split $line] 3 end]

		# pick up the cpu family for use later
		set arch [string trim [lindex [split $line] 0]]

		foreach cpu $cpus {
			# trim of the trailing tool type
			set trimCpu [string trimright $cpu "diabgnusfbele"]

			# trim off whitespace
			set trimCPu [string trim $trimCpu]

			# skip if null
			if { "$trimCpu" == "" } {
				continue
			}

			# if the CPU matches the one we want
			if { "$trimCpu" == "$bspCpu"} {

				# and it's not in the list already
				if { ! [string match *$arch* $archs] } {

					# then we'll have it
					append archs "$arch:"
				}
			}
		}
	}
	close $fH

	return $archs
}


proc addArch {cpuVar archs} {

# append cpuVar onto archs, if it isn't there already

	set arch [string trimleft $cpuVar "_"]

	# if it's not in the list already
	if { ! [string match *$arch* $archs] } {

		# then we'll have it
		append archs "$arch:"
	}

	return $archs
}

#########################################################
# Entry point
#########################################################

global env

puts ""
puts "Generating BSP_ARCH.TXT"

set outFileName "/.wind_setup/river/tools/resource/mfg/setup/RESOURCE/BSP_ARCH.TXT"
if { [file exists $outFileName] } {
    puts "removing old BSP_ARCH.TXT file"
    exec chmod 777 $outFileName
    exec rm $outFileName
}

if {[catch {open $outFileName "w"} file]} {
    puts "cannot open file $outFileName for writing"
    exit 1
}

# output header
puts $file "# Tornado 2.2 BSP/toolchain mapping table" 
puts $file "#"
puts $file "# This file is auto-generated.  Do not edit."
puts $file "#"
puts $file [format "%s%-18s%s" # BSP PROC_FAMILIY]
puts $file ""

# get list of BSP directories
set bspList [exec ls /wind/river/target/config]

foreach bsp $bspList {

# we're not using this method any more, so break out of this loop
break
	#get BSP makefile full path
	set bspMakefile "/wind/river/target/config/$bsp/Makefile"

	#if no Makefile, skip this BSP
	if { ![file exists $bspMakefile]} {
	  continue
	}

        set mipsPl [string first _mips $bsp ]
        if { $mipsPl != -1 } {
        # it's a mips bsp, skip it, we deal differently
          continue
        }

	# look in the Makefile for the CPU definition
	set cpu [exec grep CPU $bspMakefile \| grep -v #]

	# get the CPU value
	set cpu [string trim [lindex $cpu 2]]

	# get the cpu family list
	set archList [addFamilyList $cpu ""]

	#output the result line to the file
	puts "writing for BSP: $bsp"
        puts $file [format "%-20s%s" $bsp $archList]
}

#now we got through all the pools getting the bsp names
foreach pool "TDK-14630 TDK-14631 TDK-14632 TDK-14633 TDK-14634 TDK-14635 TDK-14636 TDK-14637 TDK-14860 TDK-14860" {

	# get the list of BSPs in the pool
	set bspList [exec /.wind_setup/river/tools/resource/mfg/setup/RESOURCE/poolBspList $pool]

	foreach bsp $bspList {

		# clear the archlist for this BSP
		set allArchList ""

		set bspResourceFile "/wind/river/.resources/bsp-$bsp"
		if { ![file exists $bspResourceFile]} {
			  continue
		}

		# get the list of BSPs that this resource expands to
		set subBspList [exec /.wind_setup/river/tools/resource/mfg/setup/RESOURCE/resBspList $bsp]

		foreach subBsp $subBspList {

			#get BSP makefile full path
			set bspMakefile "/wind/river/target/config/$subBsp/Makefile"
			#if no Makefile, skip this BSP
			if { ![file exists $bspMakefile]} {
	  			continue
			}

			# first, look for CPU_VARIANT (used my MIPS)
			if { [catch { exec grep CPU_VARIANT $bspMakefile | \
				grep = } cpuVar ] } {

				# grep got an error, so there it is not defined
				set cpuVar ""

			} else {
				# get the value
				set cpuVar [lindex $cpuVar 2]
			}

			if {$cpuVar == "" } {

				# look in the Makefile for the CPU definition
				set cpu [exec grep CPU $bspMakefile \| grep -v # \| grep -v CPU_VARIANT]
				# get the CPU value
				set cpu [string trim [lindex $cpu 2]]
	
				# append the cpu family list
				set allArchList [addFamilyList $cpu $allArchList]
			} else {

				# add the cpu variant onto the list
			        set allArchList [addArch $cpuVar $allArchList]

			}
		}
	
		# trim off the final colon
		set allArchList [string trimright $allArchList ":"]

		#output the result line to the file
#		puts "writing for BSP: $bsp"
      		puts [format "%-20s%s" $bsp $allArchList]
      		puts $file [format "%-20s%s" $bsp $allArchList]
	}
}

close $file

puts "done"

