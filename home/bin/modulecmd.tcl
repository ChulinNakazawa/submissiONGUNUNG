
#!/bin/sh
# \
type tclsh 1>/dev/null 2>&1 && exec tclsh "$0" "$@"
# \
[ -x /usr/local/bin/tclsh ] && exec /usr/local/bin/tclsh "$0" "$@"
# \
[ -x /usr/bin/tclsh ] && exec /usr/bin/tclsh "$0" "$@"
# \
[ -x /bin/tclsh ] && exec /bin/tclsh "$0" "$@"
# \
echo "FATAL: module: Could not find tclsh in \$PATH or in standard directories" >&2; exit 1
	
########################################################################
# This is a pure TCL implementation of the module command
# to initialize the module environment, either
# - one of the scripts from the init directory should be sourced, or just
# - eval `/some-path/tclsh modulecmd.tcl MYSHELL autoinit`
# in both cases the path to tclsh is remembered and used furtheron
########################################################################
#
# Some Global Variables.....
#
regsub {\$[^:]+:\s*(\S+)\s*\$} {$Revision: 1.147 $} {\1}\
	 MODULES_CURRENT_VERSION
set g_debug 0 ;# Set to 1 to enable debugging
set error_count 0 ;# Start with 0 errors
set g_autoInit 0
set g_force 1 ;# Path element reference counting if == 0
set CSH_LIMIT 4000 ;# Workaround for commandline limits in csh
set flag_default_dir 1 ;# Report default directories
set flag_default_mf 1 ;# Report default modulefiles and version alias

# Used to tell if a machine is running Windows or not
proc isWin {} {
    global tcl_platform

    if { $tcl_platform(platform) == "windows" } {
        return 1
    } else {
        return 0
    }
}

#
# Set Default Path separator
#
if { [isWin] } {
	set g_def_separator "\;"
} else {
	set g_def_separator ":"
}

# Dynamic columns
set DEF_COLUMNS 80 ;# Default size of columns for formatting
if {[catch {exec stty size} stty_size] == 0 && $stty_size != ""} {
    set DEF_COLUMNS [lindex $stty_size 1]
}

# Change this to your support email address...
set contact "root@localhost"

# Set some directories to ignore when looking for modules.
set ignoreDir(CVS) 1
set ignoreDir(RCS) 1
set ignoreDir(SCCS) 1
set ignoreDir(.svn) 1
set ignoreDir(.git) 1

global g_shellType
global g_shell
set show_oneperline 0 ;# Gets set if you do module list/avail -t
set show_modtimes 0 ;# Gets set if you do module list/avail -l

#
# Info, Warnings and Error message handling.
#
proc reportWarning {message {nonewline ""}} {
    if {$nonewline != ""} {
	puts -nonewline stderr "$message"
    } else {
	puts stderr "$message"
    }
}

proc reportInternalBug {message} {
    global contact

    puts stderr "Module ERROR: $message\nPlease contact: $contact"
}

proc report {message {nonewline ""}} {
    if {$nonewline != ""} {
	puts -nonewline stderr "$message"
    } else {
	puts stderr "$message"
    }
}

########################################################################
# Use a slave TCL interpreter to execute modulefiles
#

proc unset-env {var} {
    global env g_debug

    if {[info exists env($var)]} {
        if {$g_debug} {
    	    report "DEBUG unset-env:  $var"
        }
	unset env($var)
    }
}

proc execute-modulefile {modfile {help ""}} {
    global g_debug
    global ModulesCurrentModulefile
    set ModulesCurrentModulefile $modfile

    if {$g_debug} {
	report "DEBUG execute-modulefile:  Starting $modfile"
    }
    set slave __[currentModuleName]
    if {![interp exists $slave]} {
	interp create $slave
	interp alias $slave setenv {} setenv
	interp alias $slave unsetenv {} unsetenv
	interp alias $slave getenv {} getenv
	interp alias $slave system {} system
	interp alias $slave append-path {} append-path
	interp alias $slave prepend-path {} prepend-path
	interp alias $slave remove-path {} remove-path
	interp alias $slave prereq {} prereq
	interp alias $slave conflict {} conflict
	interp alias $slave is-loaded {} is-loaded
	interp alias $slave module {} module
	interp alias $slave module-info {} module-info
	interp alias $slave module-whatis {} module-whatis
	interp alias $slave set-alias {} set-alias
	interp alias $slave unset-alias {} unset-alias
	interp alias $slave uname {} uname
	interp alias $slave x-resource {} x-resource
	interp alias $slave module-version {} module-version
	interp alias $slave module-alias {} module-alias
	interp alias $slave reportInternalBug {} reportInternalBug
	interp alias $slave reportWarning {} reportWarning
	interp alias $slave report {} report
	interp alias $slave isWin {} isWin

	interp eval $slave {global ModulesCurrentModulefile g_debug}
	interp eval $slave [list "set" "ModulesCurrentModulefile" $modfile]
	interp eval $slave [list "set" "g_debug" $g_debug]
	interp eval $slave [list "set" "help" $help]

    }
    set errorVal [interp eval $slave {
	if {$g_debug} {
	    report "Sourcing $ModulesCurrentModulefile"
        }
	set sourceFailed [catch {source $ModulesCurrentModulefile} errorMsg]
	if {$help != ""} {
	    if {[info procs "ModulesHelp"] == "ModulesHelp"} {
		ModulesHelp
	    } else {
		reportWarning "Unable to find ModulesHelp in\
		  $ModulesCurrentModulefile."
	    }
	    set sourceFailed 0
	}
	if {$sourceFailed} {
	    if {$errorMsg == "" && $errorInfo == ""} {
		unset errorMsg
		return 1
	    }\
	    elseif [regexp "^WARNING" $errorMsg] {
		reportWarning $errorMsg
		return 1
	    } else {
		global errorInfo
		reportInternalBug "ERROR occurred in file\
		  $ModulesCurrentModulefile:$errorInfo"
		exit 1
	    }
	} else {
	    unset errorMsg
	    return 0
	}
    }]
    interp delete $slave
    if {$g_debug} {
	report "DEBUG Exiting $modfile"
    }
    return $errorVal
}

# Smaller subset than main module load... This function runs modulerc and\
  .version files
proc execute-modulerc {modfile} {
    global g_rcfilesSourced
    global g_debug g_moduleDefault
    global ModulesCurrentModulefile


    if {$g_debug} {
       report "DEBUG execute-modulerc: $modfile"
    }

    set ModulesCurrentModulefile $modfile

    if {![checkValidModule $modfile]} {
	reportInternalBug "+(0):ERROR:0: Magic cookie '#%Module' missing in\
	  '$modfile'"
	return ""
    }

    set modparent [file dirname $modfile]

    if {![info exists g_rcfilesSourced($modfile)]} {
	if {$g_debug} {
	    report "DEBUG execute-modulerc: sourcing rc $modfile"
	}
	set slave __.modulerc
	if {![interp exists $slave]} {
	    interp create $slave
	    interp alias $slave uname {} uname
	    interp alias $slave system {} system
	    interp alias $slave module-version {} module-version
	    interp alias $slave module-alias {} module-alias
	    interp alias $slave module {} module
	    interp alias $slave reportInternalBug {} reportInternalBug

	    interp eval $slave {global ModulesCurrentModulefile g_debug}
	    interp eval $slave [list "global" "ModulesVersion"]
	    interp eval $slave [list "set" "ModulesCurrentModulefile" $modfile]
	    interp eval $slave [list "set" "g_debug" $g_debug]
	    interp eval $slave {set ModulesVersion {}}
	}
	set ModulesVersion [interp eval $slave {
	    if [catch {source $ModulesCurrentModulefile} errorMsg] {
		global errorInfo
		reportInternalBug "occurred in file\
		  $ModulesCurrentModulefile:$errorInfo"
		exit 1
	    }\
	    elseif [info exists ModulesVersion] {
		return $ModulesVersion
	    } else {
		return {}
	    }
	}]
	interp delete $slave

	if {[file tail $modfile] == ".version"} {
	    # only set g_moduleDefault if .version file,
	    # otherwise any modulerc settings ala "module-version /xxx default"
	    #  would get overwritten
	    set g_moduleDefault($modparent) $ModulesVersion
	}

	if {$g_debug} {
	    report "DEBUG execute-version: Setting g_moduleDefault($modparent)\
	      $ModulesVersion"
	}

	# Keep track of rc files we already sourced so we don't run them again
	set g_rcfilesSourced($modfile) $ModulesVersion
    }
    return $g_rcfilesSourced($modfile)
}


########################################################################
# commands run from inside a module file
#
set ModulesCurrentModulefile {}

proc module-info {what {more {}}} {
    global g_shellType g_shell g_debug tcl_platform
    global g_moduleAlias g_symbolHash g_versionHash

    set mode [currentMode]

    if {$g_debug} {
        report "DEBUG module-info: $what $more  mode=$mode"
    }

    switch -- $what {
    "mode" {
	    if {$more != ""} {
		if {$mode == $more} {
		    return 1
		} else {
		    return 0
		}
	    } else {
		return $mode
	    }
	}
    "name" -
    "specified" {
	    return [currentModuleName]
	}
    "shell" {
	    return $g_shell
	}
    "flags" {
	    return 0
	}
    "shelltype" {
	    return $g_shellType
	}
    "user" {
    	        return $tcl_platform(user)
        }
    "alias" {
	    if {[info exists g_moduleAlias($more)]} {
	        return $g_moduleAlias($more)
	    } else {
		return {}
	    }
	}
    "trace" {
		return {}
        }
    "tracepat" {
		return {}
        }
    "symbols" {
	    if {[regexp {^\/} $more]} {
		set tmp [currentModuleName]
		set tmp [file dirname $tmp]
		set more "${tmp}$more"
	    }
	    if {[info exists g_symbolHash($more)]} {
		return $g_symbolHash($more)
	    } else {
		return {}
	    }
	}
    "version" {
	    if {[regexp {^\/} $more]} {
		set tmp [currentModuleName]
		set tmp [file dirname $tmp]
		set more "${tmp}$more"
	    }
	    if {[info exists g_versionHash($more)]} {
		return $g_versionHash($more)
	    } else {
		return {}
	    }
	}
    default {
	    error "module-info $what not supported"
	    return {}
	}
    }
}

proc module-whatis {message} {
    global g_whatis g_debug

    set mode [currentMode]

    if {$g_debug} {
        report "DEBUG module-whatis: $message  mode=$mode"
    }

    if {$mode == "display"} {
	report "module-whatis\t$message"
    }\
    elseif {$mode == "whatis"} {
	set g_whatis $message
    }
    return {}
}

# Specifies a default or alias version for a module that points to an 
# existing module version Note that the C version stores aliases and 
# defaults by the short module name (not the full path) so aliases and 
# defaults from one directory will apply to modules of the same name found 
# in other directories.
proc module-version {args} {
    global g_moduleVersion g_versionHash
    global g_moduleDefault
    global g_debug
    global ModulesCurrentModulefile

    if {$g_debug} {
	report "DEBUG module-version: executing module-version $args"
    }
    set module_name [lindex $args 0]

    # Check for shorthand notation of just a version "/version".  Base is 
    # implied by current dir prepend the current directory to module_name
    if {[regexp {^\/} $module_name]} {
	set base [file dirname $ModulesCurrentModulefile]
	set module_name "${base}$module_name"
    }

    foreach version [lrange $args 1 end] {

	set base [file dirname $module_name]
	set aliasversion [file tail $module_name]

	if {$base != ""} {
	    if {[string match $version "default"]} {
		# If we see more than one default for the same module, just\
		  keep the first
		if {![info exists g_moduleDefault($base)]} {
		    set g_moduleDefault($base) $aliasversion
		    if {$g_debug} {
			report "DEBUG module-version: default $base\
			  =$aliasversion"
		    }
		}
	    } else {
		set aliasversion "$base/$version"
		if {$g_debug} {
		    report "DEBUG module-version: alias $aliasversion =\
		      $module_name"
		}
		set g_moduleVersion($aliasversion) $module_name

		if {[info exists g_versionHash($module_name)]} {
		    # don't add duplicates
		    if {[lsearch -exact $g_versionHash($module_name)\
		      $aliasversion] < 0} {
			set tmplist $g_versionHash($module_name)
			set tmplist [linsert $tmplist end $aliasversion]
			set g_versionHash($module_name) $tmplist
		    }
		} else {
		    set g_versionHash($module_name) $aliasversion
		}
	    }