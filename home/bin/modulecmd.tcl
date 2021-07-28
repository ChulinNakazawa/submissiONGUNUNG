
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


	    if {$g_debug} {
		report "DEBUG module-version: $aliasversion  = $module_name"
	    }
	} else {
	    error "module-version: module argument for default must not be\
	      fully version qualified"
	}
    }
    if {[string match [currentMode] "display"]} {
	report "module-version\t$args"
    }
    return {}
}


proc module-alias {args} {
    global g_moduleAlias
    global ModulesCurrentModulefile
    global g_debug

    set alias [lindex $args 0]
    set module_file [lindex $args 1]

    if {$g_debug} {
	report "DEBUG module-alias: $alias  = $module_file"
    }

    set g_moduleAlias($alias) $module_file

    if {[info exists g_aliasHash($module_file)]} {
	set tmplist $g_aliasHash($module_file)
	set tmplist [linsert $tmplist end $alias]
	set g_aliasHash($module_file) $tmplist
    } else {
	set g_aliasHash($module_file) $alias
    }

    if {[string match [currentMode] "display"]} {
	report "module-alias\t$args"
    }


    return {}
}


proc module {command args} {
    set mode [currentMode]
    global g_debug

    # Resolve any module aliases
    if {$g_debug} {
	report "DEBUG module: Resolving $args"
    }
    set args [resolveModuleVersionOrAlias $args]
    if {$g_debug} {
	report "DEBUG module: Resolved to $args"
    }

    switch -- $command {
    add - lo -
    load {
	    if {$mode == "load"} {
		eval cmdModuleLoad $args
	    }\
	    elseif {$mode == "unload"} {
		eval cmdModuleUnload $args
	    }\
	    elseif {$mode == "display"} {
		report "module load\t$args"
	    }
	}
    rm - unlo -
    unload {
	    if {$mode == "load"} {
		eval cmdModuleUnload $args
	    }\
	    elseif {$mode == "unload"} {
		eval cmdModuleUnload $args
	    }\
	    elseif {$mode == "display"} {
		report "module unload\t$args"
	    }
	}
    reload {
	    cmdModuleReload
	}
    use {
	    eval cmdModuleUse $args
	}
    unuse {
	    eval cmdModuleUnuse $args
	}
    source {
	    eval cmdModuleSource $args
	}
    switch -
    swap {
	    eval cmdModuleSwitch $args
	}
    display - dis -
    show {
	    eval cmdModuleDisplay $args
	}
    avail - av {
	    if {$args != ""} {
		foreach arg $args {
		    cmdModuleAvail $arg
		}
	    } else {
		cmdModuleAvail
 	        # Not sure if this should be a part of cmdModuleAvail or not
	        cmdModuleAliases
	    }
	}
    aliases - al {
        cmdModuleAliases
    }
    path {
	    eval cmdModulePath $args
	}
    paths {
	    eval cmdModulePaths $args
	}
    list {
	    cmdModuleList
	}
    whatis {
	    if {$args != ""} {
		foreach arg $args {
		    cmdModuleWhatIs $arg
		}
	    } else {
		cmdModuleWhatIs
	    }
	}
    apropos - search -
    keyword {
	    eval cmdModuleApropos $args
	}
    purge {
	    eval cmdModulePurge
	}
    initadd {
	    eval cmdModuleInit add $args
	}
    initprepend {
	    eval cmdModuleInit prepend $args
	}
    initrm {
	    eval cmdModuleInit rm $args
	}
    initlist {
	    eval cmdModuleInit list $args
	}
    initclear {
	    eval cmdModuleInit clear $args
	}
    default {
	    error "module $command not understood"
	}
    }
    return {}
}

proc setenv {var val} {
    global g_stateEnvVars env g_debug
    set mode [currentMode]

    if {$g_debug} {
	report "DEBUG setenv: ($var,$val) mode = $mode"
    }

    if {$mode == "load"} {
	set env($var) $val
	set g_stateEnvVars($var) "new"
    }\
    elseif {$mode == "unload"} {
	# Don't unset-env here ... it breaks modulefiles
	# that use env(var) is later in the modulefile
	#unset-env $var
	set g_stateEnvVars($var) "del"
    }\
    elseif {$mode == "display"} {
	# Let display set the variable for later use in the display
	# but don't commit it to the env
	set env($var) $val
	set g_stateEnvVars($var) "nop"
	report "setenv\t\t$var\t$val"
    }
    return {}
}

proc getenv {var} {
     global g_debug
     set mode [currentMode]

     if {$g_debug} {
         report "DEBUG getenv: ($var) mode = $mode"
     }

     if {$mode == "load" || $mode == "unload"} {
	 if {[info exists env($var)]} {
             return $::env($var)
         } else {
             return "_UNDEFINED_"
         }
     }\
     elseif {$mode == "display"} {
         return "\$$var"
     }
     return {}
}

proc unsetenv {var {val {}}} {
    global g_stateEnvVars env g_debug
    set mode [currentMode]

    if {$g_debug} {
	report "DEBUG unsetenv: ($var,$val) mode = $mode"
    }

    if {$mode == "load"} {
	if {[info exists env($var)]} {
	    unset-env $var
	}
	set g_stateEnvVars($var) "del"
    }\
    elseif {$mode == "unload"} {
	if {$val != ""} {
	    set env($var) $val
	    set g_stateEnvVars($var) "new"
	}
    }\
    elseif {$mode == "display"} {
	report "unsetenv\t\t$var"
    }
    return {}
}

########################################################################
# path fiddling

proc getReferenceCountArray {var separator} {
    global env g_force g_def_separator g_debug

    if {$g_debug} {
       report "DEBUG getReferenceCountArray: ($var, $separator)"
    }

    set sharevar "${var}_modshare"
    set modshareok 1
    if {[info exists env($sharevar)]} {
	if {[info exists env($var)]} {
	    set modsharelist [split $env($sharevar) $g_def_separator]
	    set temp [expr {[llength $modsharelist] % 2}]
	    if {$temp == 0} {
		array set countarr $modsharelist

		# sanity check the modshare list
		array set fixers {}
		array set usagearr {}
		foreach dir [split $env($var) $separator] {
		    set usagearr($dir) 1
		}
		foreach path [array names countarr] {
		    if {! [info exists usagearr($path)]} {
			unset countarr($path)
			set fixers($path) 1
		    }
		}

		foreach path [array names usagearr] {
		    if {! [info exists countarr($path)]} {
			set countarr($path) 999999999
		    }
		}

		if {! $g_force} {
		    if {[array size fixers]} {
			reportWarning "WARNING: \$$var does not agree with\
			  \$${var}_modshare counter. The following\
			  directories' usage counters were adjusted to match.\
			  Note that this may mean that module unloading may\
			  not work correctly."
			foreach dir [array names fixers] {
			    reportWarning " $dir" -nonewline
			}
			reportWarning ""
		    }
		}

	    } else {
		#		sharevar was corrupted, odd number of elements.
		set modshareok 0
	    }
	} else {
	    if {$g_debug} {	    
		reportWarning "WARNING: module: $sharevar exists (\
	          $env($sharevar) ), but $var doesn't. Environment is corrupted."
            }
	    set modshareok 0
	}
    } else {
	set modshareok 0
    }

    if {$modshareok == 0 && [info exists env($var)]} {
	array set countarr {}
	foreach dir [split $env($var) $separator] {
	    set countarr($dir) 1
	}
    }
    return [array get countarr]
}


proc unload-path {var path separator} {
    global g_stateEnvVars env g_force g_def_separator g_debug

    array set countarr [getReferenceCountArray $var $separator]

    if {$g_debug} {
	report "DEBUG unload-path: ($var, $path, $separator)"
    }

    # Don't worry about dealing with this variable if it is already scheduled\
      for deletion
    if {[info exists g_stateEnvVars($var)] && $g_stateEnvVars($var) == "del"} {
	return {}
    }

    foreach dir [split $path $separator] {
        set doit 0

	if {[info exists countarr($dir)]} {
	    incr countarr($dir) -1
	    if {$countarr($dir) <= 0} {
		set doit 1
		unset countarr($dir)
	    }
	} else {
	    set doit 1
	}

	if {$doit || $g_force} {
	    if {[info exists env($var)]} {
		set dirs [split $env($var) $separator]
		set newpath ""
		foreach elem $dirs {
		    if {$elem != $dir} {
			lappend newpath $elem
		    }
		}
		if {$newpath == ""} {
		    unset-env $var
		    set g_stateEnvVars($var) "del"
		} else {
		    set env($var) [join $newpath $separator]
		    set g_stateEnvVars($var) "new"
		}
	    }
	}
    }

    set sharevar "${var}_modshare"
    if {[array size countarr] > 0} {
	set env($sharevar) [join [array get countarr] $g_def_separator]
	set g_stateEnvVars($sharevar) "new"
    } else {
	unset-env $sharevar
	set g_stateEnvVars($sharevar) "del"
    }
    return {}
}

proc add-path {var path pos separator} {
    global env g_stateEnvVars g_def_separator g_debug

    if {$g_debug} {
	report "DEBUG add-path: ($var, $path, $separator)"
    }

    set sharevar "${var}_modshare"
    array set countarr [getReferenceCountArray $var $separator]

    if {$pos == "prepend"} {
	set pathelems [reverseList [split $path $separator]]
    } else {
	set pathelems [split $path $separator]
    }
    foreach dir $pathelems {
	if {[info exists countarr($dir)]} {
	    #	    already see $dir in $var"
	    incr countarr($dir)
	} else {
	    if {[info exists env($var)]} {
		if {$pos == "prepend"} {
		    set env($var) "$dir$separator$env($var)"
		}\
		elseif {$pos == "append"} {
		    set env($var) "$env($var)$separator$dir"
		} else {
		    error "add-path doesn't support $pos"
		}
	    } else {
		set env($var) "$dir"
	    }
	    set countarr($dir) 1
	}
        if {$g_debug} {
    	   report "DEBUG add-path: env($var) = $env($var)"
        }
    }


    set env($sharevar) [join [array get countarr] $g_def_separator]
    set g_stateEnvVars($var) "new"
    set g_stateEnvVars($sharevar) "new"
    return {}
}

proc prepend-path {var path args} {
    global g_def_separator g_debug

    set mode [currentMode]

    if {$g_debug} {
	report "DEBUG prepend-path: ($var, $path, $args) mode=$mode"
    }

    if {[string match $var "-delim"]} {
        set separator $path
        set var [lindex $args 0]
        set path [lindex $args 1]
    } else {
        set separator $g_def_separator
    }

    if {$mode == "load"} {
	add-path $var $path "prepend" $separator
    }\
    elseif {$mode == "unload"} {
	unload-path $var $path $separator
    }\
    elseif {$mode == "display"} {
	report "prepend-path\t$var\t$path"
    }
    return {}
}


proc append-path {var path args} {
    global g_def_separator g_debug

    set mode [currentMode]

    if {$g_debug} {
	report "DEBUG append-path: ($var, $path, $args) mode=$mode"
    }

    if {[string match $var "-delim"]} {
        set separator $path
        set var [lindex $args 0]
        set path [lindex $args 1]
    } else {
        set separator $g_def_separator
    }

    if {$mode == "load"} {
	add-path $var $path "append" $separator
    }\
    elseif {$mode == "unload"} {
	unload-path $var $path $separator
    }\
    elseif {$mode == "display"} {
	report "append-path\t$var\t$path"
    }
    return {}
}

proc remove-path {var path args} {
    global g_def_separator g_debug

    set mode [currentMode]

    if {$g_debug} {
	report "DEBUG remove-path: ($var, $path, $args) mode=$mode"
    }

    if {[string match $var "-delim"]} {
        set separator $path
        set var [lindex $args 0]
        set path [lindex $args 1]
    } else {
        set separator $g_def_separator
    }

    if {$mode == "load"} {
	unload-path $var $path $separator
    }\
    elseif {$mode == "display"} {
	report "remove-path\t$var\t$path"
    }
    return {}
}

proc set-alias {alias what} {
    global g_Aliases g_stateAliases g_debug
    set mode [currentMode]

    if {$g_debug} {
	report "DEBUG set-alias: ($alias, $what) mode=$mode"
    }
    if {$mode == "load"} {
	set g_Aliases($alias) $what
	set g_stateAliases($alias) "new"
    }\
    elseif {$mode == "unload"} {
	set g_Aliases($alias) {}
	set g_stateAliases($alias) "del"
    }\
    elseif {$mode == "display"} {
	report "set-alias\t$alias\t$what"
    }
    return {}
}


proc unset-alias {alias} {
    global g_Aliases g_stateAliases g_debug
    set mode [currentMode]

    if {$g_debug} {
	report "DEBUG unset-alias: ($alias) mode=$mode"
    }
    if {$mode == "load"} {
	set g_Aliases($alias) {}
	set g_stateAliases($alias) "del"
    }\
    elseif {$mode == "display"} {
	report "unset-alias\t$alias"
    }
    return {}
}

proc is-loaded {modulelist} {
    global env g_def_separator g_debug

    if {$g_debug} {
	report "DEBUG is-loaded: $modulelist"
    }

    if {[llength $modulelist] > 0} {
	if {[info exists env(LOADEDMODULES)]} {
	    foreach arg $modulelist {
		set arg "$arg/"
		foreach mod [split $env(LOADEDMODULES) $g_def_separator] {
		    set mod "$mod/"
		    if {[string first $arg $mod] == 0} {
			return 1
		    }
		}
	    }
	    return 0
	} else {
	    return 0
	}
    }
    return 1
}


proc conflict {args} {
    global ModulesCurrentModulefile g_debug
    set mode [currentMode]
    set currentModule [currentModuleName]

    if {$g_debug} {
	report "DEBUG conflict: ($args) mode = $mode"
    }

    if {$mode == "load"} {
	foreach mod $args {
	    # If the current module is already loaded, we can proceed
	    if {![is-loaded $currentModule]} {
		# otherwise if the conflict module is loaded, we cannot
		if {[is-loaded $mod]} {
		    set errMsg "WARNING: $currentModule cannot be loaded due\
		      to a conflict."
		    set errMsg "$errMsg\nHINT: Might try \"module unload\
		      $mod\" first."
		    error $errMsg
		}
	    }
	}
    }\
    elseif {$mode == "display"} {
	report "conflict\t$args"
    }
    return {}
}

proc prereq {args} {
    global g_debug
    set mode [currentMode]
    set currentModule [currentModuleName]

    if {$g_debug} {
	report "DEBUG prereq: ($args) mode = $mode"
    }

    if {$mode == "load"} {
	if {![is-loaded $args]} {
	    set errMsg "WARNING: $currentModule cannot be loaded due to\
	      missing prereq."
	    set errMsg "$errMsg\nHINT: the following modules must be loaded\
	      first: $args"
	    error $errMsg
	}
    }\
    elseif {$mode == "display"} {
	report "prereq\t\t$args"
    }
    return {}
}

proc x-resource {resource {value {}}} {
    global g_newXResources g_delXResources g_debug
    set mode [currentMode]

    if {$g_debug} {
       report "DEBUG x-resource: ($resource, $value)"
    }

    if {$mode == "load"} {
	set g_newXResources($resource) $value
    }\
    elseif {$mode =="unload"} {
	set g_delXResources($resource) 1
    }\
    elseif {$mode == "display"} {
	report "x-resource\t$resource\t$value"
    }
    return {}
}

proc uname {what} {
    global unameCache tcl_platform g_debug
    set result {}

    if {$g_debug} {
       report "DEBUG uname: called: $what"
    }

    if {! [info exists unameCache($what)]} {
	switch -- $what {
	    sysname {
    	        set result $tcl_platform(os)
	    }
	    machine {
	        set result $tcl_platform(machine)
	    }
	    nodename -
	    node {
	        set result [info hostname]
	    }
	    release {
		# on ubuntu get the CODENAME of the Distribution
		if { [file isfile /etc/lsb-release]} {
                        set fd [open "/etc/lsb-release" "r"]
                        set a [read $fd]
                        regexp -nocase {DISTRIB_CODENAME=(\S+)(.*)} $a matched res end
                        set result $res
                } else {
			set result $tcl_platform(osVersion)
		}
	    }
	    domain {
		set result [exec /bin/domainname]
	    }
	    version {
		set result [exec /bin/uname -v]
	    }
	    default {
		error "uname $what not supported"
	    }
	}
	set unameCache($what) $result
    }

    return $unameCache($what)
}

########################################################################
# internal module procedures

set g_modeStack {}

proc currentMode {} {
    global g_modeStack

    set mode [lindex $g_modeStack end]
    return $mode
}

proc pushMode {mode} {
    global g_modeStack

    lappend g_modeStack $mode
}

proc popMode {} {
    global g_modeStack

    set len [llength $g_modeStack]
    set len [expr {$len - 2}]
    set g_modeStack [lrange $g_modeStack 0 $len]
}


set g_moduleNameStack {}

proc currentModuleName {} {
    global g_moduleNameStack

    set moduleName [lindex $g_moduleNameStack end]
    return $moduleName
}

proc pushModuleName {moduleName} {