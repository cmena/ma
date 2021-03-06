#!/usr/bin/env wish
#### ma - a minimalistic variant of acme(1)
#
# (c)MMXV-MMXVIII Felix L. Winkelmann
#
# Version: 11

# customize these variables to your taste:
set rcfile "$env(HOME)/.ma"
set plumber "plumb"
set exec_path [split $env(PATH) ":"]
set include_path {"/usr/include"}
set fixed_font {Courier 12 normal}
set variable_font {Helvetica 12 normal}
set current_font $variable_font
set tag_font $variable_font
set tag_clean_font $tag_font
set tag_dirty_font {Helvetica 12 bold}
set password_char "∎"
set current_foreground black
set current_background "#FFFFEA"
set sbar_color $current_background
set sbar_background "#99994c"
set valid_match_background "#448844"
set invalid_match_background "#884444"
set tag_foreground black
set tag_background "#EAFFFF"
set selection_foreground black
set selection_background "#eeee9e"
set inactive_selection_background $selection_background
set pseudo_selection_foreground $selection_foreground
set pseudo_selection_background $selection_background
set b2sweep_foreground white
set b2sweep_background "#aa0000"
set b3sweep_foreground white
set b3sweep_background "#006600"
set focus_color white
set nonfocus_color black
set sbar_width 10
set tabwidth 4
set file_encoding utf-8
set file_translation lf
set indent_mode 0
set current_translation lf
set eot_symbol "␄"
set directory_commands {Dotfiles}
set unnamed_name UNNAMED
set initial_tag "$unnamed_name New Del Cut Paste Snarf Get Look Font | "
set interactive_shell_args {}
set scroll_repeat 100
set rc_style_quoting 0
set cursor left_ptr
set wrap_mode char

# global variables
set current_filename ""
set executing_pids {}
set search_string ""
set dest_address ""
set command_arguments {}
set command_input_file ""
set any_output 0
set b1_down 0
set b2_down 0
set b2_start ""
set b2_with_arg ""
set b2_abort 0
set b3_down 0
set b3_start ""
set b3_abort 0
set shell sh
set win_mode 0
set win_file ""
set flashed_range_id ""
set output_window_rx {/[-+][^/]+$}
set last_opened ""
set last_mouse_index "1.0"
set history_file ""
set withdrawn 0
set last_del_attempt 0
set exec_prefix ""
set scroll 0
set focus_window ""
set has_focus 0
set password_input ""
set cut_unmodified ""
set position_stack {}
set editable 1
set dotfiles 1
set override_attempt 0
set unnamed 0
set replace_dir 0
set pseudosel_on(.t) 0
set pseudosel_on(.tag) 0
set last_scroll_bottom 1.0
set scroll_task ""
set sbar_height 0
set remote ""

# hooks
set file_hook {}
set directory_hook {}
set name_hook {}
set configuration_hook {}
set termination_hook {}
set save_hook {}
set write_hook {}
set read_hook {}
set register_hook {}
set unregister_hook {}
set pre_save_hook {}
set revert_hook {}
set execute_hook {}

if {[info exists env(MA_INCLUDE_PATH)]} {
    set include_path [concat $include_path [split $env(MA_INCLUDE_PATH) ":"]]
}
if {[info exists env(MA_HISTORY)]} {
    set history_file $env(MA_HISTORY)
}
if {[info exists env(HERE)]} {
    set exec_prefix $env(HERE)/exec/
}
if {[info exists env(SHELL)]} {
    set shell $env(SHELL)
}
if {![regexp $output_window_rx [tk appname]]} { 
    tk appname "MA-[pid]" 
}
set env(MA) [tk appname]
fconfigure stdout -translation lf
fconfigure stderr -translation lf

set command_table {
    {{^New$} {Ma -cd [pwd]}}
    {{^New\s+(.+)$} { Ma [CanonicalFilename [GetArg]] }}
    {{^Delete$} { Terminate 1 }}
    {{^Del$} Terminate}
    {{^Get$} RevertFile}
    {{^Get\s+(.+)$} {OpenNewFile [GetArg]}}
    {{^Cut$} { tk_textCut .t }}
    {{^Paste$} { PasteSelection .t }}
    {{^Snarf$} { tk_textCopy .t }}
    {{^Put$} SaveChanges}
    {{^Put\s+(.+)$} { SaveFile [GetArg] 1}}
    {{^Look$} {Search [GetSelection .t] "" 1 0}}
    {{^Look\s+(.+)$} {Search [GetArg] "" 1 0}}
    {{^Indent$} { 
        global indent_mode
        set indent_mode [expr !$indent_mode]
        Flash blue 
    }}
    {{^Kill$} { KillExecuting SIGKILL 1}}
    {{^Send$} SendToProcess}
    {{^Send\s+(\S.*)$} {SendToProcess [GetArg]}}
    {{^Tab$} { global tabwidth; LogInWindow "Tab width is $tabwidth\n" }}
    {{^Tab\s+(\d+)$} { global tabwidth; set tabwidth [GetArg]; Flash blue }}
    {{^Font$} {ToggleFont}}
    {{^Font\s+(fix|var)$} {ToggleFont [GetArg]}}
    {{^Tcl$} { Evaluate [GetSelection .t] }}
    {{^Tcl\s+(.+)$} { Evaluate [GetArg] }}
    {{^Abort$} {Terminate 0 1}}
    {{^Undo$} { .t edit undo }}
    {{^Redo$} { .t edit redo }}
    {{^Scroll$} {ToggleScroll; Flash blue}}
    {{^Anchor$} InsertAnchor}
    {{^Withdraw$} WithdrawWindow}
    {{^Dotfiles$} {global dotfiles; set dotfiles [expr !$dotfiles]; RevertFile}}
    {{^Putall$} {SaveAllModified 0}}
    {{^Back$} PopMoveInsert}
    {{^Wrap$} {ToggleWrap}}
    {{^Local$} {
        global replace_dir
        set replace_dir [expr !$replace_dir]
        Flash blue
    }}
    {{^Crnl$} {
        global current_translation
        set current_translation "crnl"
        Flash blue
    }}
}

set plumbing_rules {
    {{^:(.+)} { GotoBodyAddress [GetArg 1] }}
    {{^([^:]+):((\d+|/[^/]+/|\?[^?]+\?|\$|#\d+|\.)(,(\d+|/[^/]+/|\?[^?]+\?|\$|#\d+|\.))?)} {
        GotoFileAddress [file normalize [GetArg 1]] [GetArg 2]
    }}
    {{^([^:]+):} { GotoFileAddress [file normalize [GetArg 1]] }}
}

tk_focusFollowsMouse
. configure -highlightthickness 2

proc Register {id fname} {
    global app_registry fname_registry 
    set app_registry($fname) $id
    set fname [CanonicalFilename $fname]
    set fname_registry($id) $fname
    RunHook register_hook $fname
    .t insert end "register: $id -> $fname\n"
    Bottom
}

proc Unregister {id} {
    global fname_registry focus_window
    if {[info exists fname_registry($id)]} {
        set fname $fname_registry($id)
        RunHook unregister_hook  $fname
    }
    set fname_registry($id) ""
    if {$focus_window == $id} {
        .t insert end "unregister: $id\n"
        Bottom
        set focus_window ""
    }
}

proc StartRegistry {} {
    global withdrawn editable
    set editable 0
    if {![catch {send MA-registry #}]} {
        puts stderr "registry already active"
        exit 1
    }
    tk appname MA-registry
    set withdrawn 1
}

proc SetFocusWindow {id} {
    global focus_window
    if {$focus_window != ""} {
        .t insert end "drop focus: $focus_window\n"
        catch [list send -async $focus_window DropFocus]
    }
    set focus_window $id
}

proc TakeFocus {} {
    global has_focus focus_color
    if {!$has_focus} {
        set has_focus 1
        if {![catch [list send -async MA-registry SetFocusWindow [tk appname]]]} {
            . configure -highlightcolor $focus_color -highlightbackground \
                $focus_color
        }
    }
}

proc DropFocus {} {
    global has_focus nonfocus_color
    set has_focus 0
    . configure -highlightcolor $nonfocus_color -highlightbackground \
        $nonfocus_color
}

proc Locate {fname {addr ""}} {
    global app_registry fname_registry
    set fname [CanonicalFilename [FollowLink $fname]]
    if {[info exists app_registry($fname)]} {
        set id $app_registry($fname)
        if {$id != "" && $fname_registry($id) == $fname} {
            if {$addr == ""} {
                if {![catch [list send $id ActivateWindow]]} {
                    return $id
                }
            } else {
                if {![catch [list send $id GotoBodyAddress "{$addr}"]]} {
                    return $id
                }
            }
        }
    }
    return ""
}

proc Broadcast {code} {
    global app_registry fname_registry
    .t insert end "broadcast: $code\n"
    foreach fname [array names app_registry] {
        set id $app_registry($fname)
        if {$id != "" && $fname_registry($id) == $fname} {
            catch [list send -async $id $code]
        }
    }
}

proc SaveAllModified {regmode} {
    global app_registry fname_registry
    if {$regmode} {
        Broadcast SaveIfModified
    } else {       
        if {[catch {send -async MA-registry SaveAllModified 1}]} {
            SaveIfModified
        }
    }
}

proc SaveChanges {} {
    SaveFile [GetFilename]
}

proc ActivateWindow {} {
    .t see insert
    WarpToIndex .t insert
    RefreshDirectory
}

proc FindFile {fname {addr ""}} {
    set id [Locate $fname $addr]
    if {$id == ""} {
        Ma $fname -address $addr
    }
}

proc ListWindows {} {
    global fname_registry app_registry
    set wins {}
    foreach fname [array names app_registry] {
        if {$fname_registry($app_registry($fname)) == $fname} {
            lappend wins $app_registry($fname)
        }
    }
    return $wins
}

proc ToggleScroll {{m ""}} {
    global scroll
    if {$m == ""} {set m [expr !$scroll]}
    set scroll $m
    if {$scroll} Bottom
}

proc ToggleWrap {{mode ""}} {
    global wrap_mode
    if {$mode != ""} {
        set wrap_mode $mode
    } elseif {$wrap_mode == "char"} {
         set wrap_mode word
    } else {set wrap_mode char}
    .t configure -wrap $wrap_mode
}

proc Ma {args} {
    global exec_prefix
    eval exec ${exec_prefix}ma $args &
}

proc GotoFileAddress {fname {addr ""}} {
    global replace_dir
    set addr [string trim $addr]
    if {![regexp {^/} $fname]} {
        set dir [GetFileDir]
        set fname "$dir/$fname"
    } 
    if {[file exists $fname]} {
        set addr [regsub -all {[{}"]} $addr {\\&}]
        if {[catch [list send MA-registry Locate "{$fname}" "{$addr}"] result] || $result == ""} {
            if {$replace_dir && [file type $fname] == "directory"} {
                OpenDirectory $fname
            } else {
                 Ma $fname -address $addr
            }
        }
        return 1
    }
    return 0
}

proc SimpleRegex {str} {
    return [regsub -all -- {\(|\)|\||\+|\*|\.|\?|\[|\]} $str {\\\0}]
}

proc ParseAddr {addr} {
    # returns index + whole-line flag
    # this is silly - addresses should enclose ranges as in sam, and
    # explicit ranges as in "," should combine these.
    if {$addr == "0"} { return {1.0 0} }
    if {$addr == "\$"} { return {end 0} }
    if {$addr == "."} { return {insert 0} }
    if {[regexp {^/(/?[^/]+)/?$} $addr _ rx]} {
        # hack for ctags: we need "simple" regexes, apparently...
        if {[regexp {^/} $rx]} {
            set rx [SimpleRegex [string range $rx 1 end]]
        }
        return [list [.t search -regexp $rx 1.0] 0]
    }
    if {[regexp {^\?([^?]+)\??$} $addr _ rx]} { 
        return [list [.t search -regexp -backwards $rx end] 0] 
    }
    if {[regexp {^#(\d+)$} $addr _ pos]} { 
        return [list "1.0 + $pos chars" 0] 
    }
    if {[regexp {^\d+$} $addr]} { return [list "$addr.0" 1] }
    return ""
}

proc AddrIndices {addr} {
    # validate by parsing the whole addr instead of doing this
    if {![regexp {^(\d+|//?[^/]+/?|\?[^?]+\??|\$|#\d+|\.)(,(\d+|/[^/]+/?|\?[^?]+\??|\$|#\d+|\.))?$} $addr _ from rng to]} {
        return ""
    }
    set p1 [ParseAddr $from]
    set p2 ""
    if {$rng != ""} {
        set p2 [ParseAddr $to]
        set p2i [lindex $p2 0]
        # if range of lines: select the latter fully
        if {[lindex $p2 1]} {
            set p2 "$p2i lineend + 1 chars"
        } else {
            set p2 $p2i
        }
    } elseif {[lindex $p1 1]} {
        # if only a line is given, select it fully
        set p2 "[lindex $p1 0] lineend + 1 chars"
    }
    return [list [lindex $p1 0] $p2]
}

proc GotoBodyAddress {addr {flash 0}} {
    RemoveSelection .t
    lassign [AddrIndices $addr] p1 p2
    if {$p1 == ""} {return 0}
    if {$p2 != ""} {
        set seltag sel
        if {[focus -displayof .] != ".t"} {
            set seltag pseudosel
        }
        .t tag add $seltag $p1 $p2
    }
    MoveInsert $p1
    WarpToIndex .t insert
    return 1
}

proc MoveInsert {pos {see 1}} {
    global position_stack
    if {$position_stack == ""} {
        UpdateCommand Back
    }
    lappend position_stack [.t index insert]
    .t mark set insert $pos
    if {$see} {.t see insert}
}

proc PopMoveInsert {{see 1}} {
    global position_stack
    if {$position_stack != ""} {
        RemoveSelection .t
        .t mark set insert [lindex $position_stack end]
        set position_stack [lrange $position_stack 0 end-1]
        if {$position_stack == ""} {
            UpdateCommand "" "Back"
        }
        if {$see} {.t see insert}
    }
}

proc PasteSelection {w} {
    set rng [$w tag ranges sel]
    if {$rng != ""} {
        set sel ""
        eval $w delete $rng
    } elseif {[catch {selection get -type UTF8_STRING} sel]} {
        set sel ""
    }
    if {$sel == ""} {
        tk_textPaste $w
    } else {
        $w insert insert $sel
    }
}

proc FindInPath {fname path} {
    set found {}
    foreach x $path {
        set fn [file join $x $fname]
        if {[file exists $fn]} {
            lappend found $fn
        }
    }
    return $found
}

proc FindExecutable {cmd} {
    global exec_path
    if {![regexp {^\s*"([^"]+)"\s*(.*)$} $cmd _ prg rest]} {
        if {![regexp {^\s*'([^']+)'\s*(.*)$} $cmd _ prg rest]} {
            if {![regexp {^\s*(\S+)\s*(.*)$} $cmd _ prg rest]} {
                set cmd $prg
                set rest ""
            }
        }
    }
    set found [FindInPath $prg $exec_path]
    foreach x $found {
        if {[file type $x] != "directory" && [file executable $x]} {
            set x [file normalize $x]
            if {$rest != ""} {
                return "$x $rest"
            } else {
                return $x
            }
        }
    }
    return ""
}

proc GotoIncludeFile {fname} {
    global include_path
    set found [FindInPath $fname $include_path]
    if {$found != ""} {
        GotoFileAddress [lindex $found 0]
        return 1
    }
    return 0
}

proc InsertAnchor {} {
    set sel [.t tag ranges sel]
    if {$sel == ""} {
        set a "#[.t count -chars 1.0 insert]"
    } else {
        set p1 [.t count -chars 1.0 [lindex $sel 0]]
        set p2 [.t count -chars 1.0 [lindex $sel 1]]
        set a "#$p1,#$p2"
    }
    .tag insert "1.0 lineend" " :$a"
}

proc ToggleFont {{mode ""}} {
    global current_font fixed_font variable_font
    switch $mode {
        fix { set current_font $fixed_font }
        var { set current_font $variable_font }
        default {
            if {$current_font == $fixed_font} {
                set current_font $variable_font
            } else {
                set current_font $fixed_font
            }
        }
    }
    # just for reconfiguration
    ResizeFont
}

proc SetFontStyle {style} {
    global current_font
    lassign $current_font x y z
    set current_font [list $x $y $style]
    ResizeFont
}

proc DefineCommand {pat code} {
    global command_table
    lappend command_table [list $pat $code]
}

proc DefinePlumbing {pat code {prepend 0}} {
    global plumbing_rules
    if {$prepend} {
        set plumbing_rules [concat [list [list $pat $code]] \
            $plumbing_rules]
    } else {
        lappend plumbing_rules [list $pat $code]
    }
}

proc GetArg {{i 1}} {
    global command_arguments
    return [lindex $command_arguments $i]
}

proc ReadFile {fname} {
    global file_translation file_encoding
    if {[catch [list open $fname r] in]} {
        LogInWindow "$in\n" 1
        return {"" ""}
    }
    fconfigure $in -translation $file_translation -encoding \
        $file_encoding
    set text [read $in]
    RunHook read_hook $text
    close $in
    set tr lf
    if {[regexp "\r\n" $text] && \
        ![regexp "\[^\r]\n" $text]} {
        set tr crnl
    }
    set result [list $text $tr]
    return $result
}

proc Top {} {.t see 1.0}
proc Bottom {} {.t see end}

proc Unmodified {} {
    # hack, somehow just setting modified to 0 is sometimes not enough
    after 100 {
        .t edit modified 0
        MarkDirty 0
        UpdateCommand "" Put
    }
}

proc MarkDirty {on} {
    global tag_clean_font tag_dirty_font
    if {$on} {
        set tag_font $tag_dirty_font
    } else {
        set tag_font $tag_clean_font
    }
    .tag configure -font $tag_font
}

proc AddToHook {hook cmd} {
    global $hook
    lappend $hook $cmd
}

proc RunHook {hook args} {
    global $hook
    set ret ""
    set qargs {}
    foreach a $args {
        lappend qargs "{$a}"
    }
    foreach h [set $hook] {
        set ret2 [eval $h {*}$qargs]
        if {$ret == ""} {set ret $ret2}
    }
    return $ret
}

proc DeconsTag {} {
    set text [.tag get 1.0 end]
    if {[regexp {^\s*'([^']*)'\s*([^|]*)\|(.*)$} $text _ fname cmds rest]} {
        return [list $fname $cmds $rest]
    }
    if {[regexp {^\s*"([^"]*)"\s*([^|]*)\|(.*)$} $text _ fname cmds rest]} {
        return [list $fname $cmds $rest]
    }
    if {[regexp {^([^ ]+)\s+([^|]*)\|(.*)$} $text _ fname cmds rest]} {
        return [list $fname $cmds $rest]
    } 
    if {[regexp {^([^|]*)\|(.*)$} $text _ cmds rest]} {
        return [list "" $cmds $rest]
    }
    return [list "" text ""]
}

proc MakeTag {fname {c ""} {r ""}} {
    lassign [DeconsTag] old cmds rest
    .tag delete 1.0 end
    if {[regexp {\s} $fname]} {
        if {[string first "'" $fname] != -1} {
            set fname2 "\"$fname\""
        } else {
            set fname2 "'$fname'"
        }
    } else {
        set fname2 $fname
    }
    if {$c != ""} {set cmds $c}
    if {$r != ""} {set rest $r}
    set cmds [string trimright $cmds]
    .tag insert 1.0 "$fname2 $cmds |[string trimright $rest] "
    if {$old != $fname} {
        RunHook name_hook
    }
}

proc UpdateCommand {new {old ""}} {
    lassign [DeconsTag] fname cmds rest
    set cmds2 ""
    if {$new == "" || [string first $new $cmds] == -1} {
        if {$old == "" || [regsub -- $old $cmds $new cmds2] == 0} {
            set cmds "[string trim $cmds] $new"
        }
    } 
    if {$cmds2 == ""} {set cmds2 $cmds}
    MakeTag $fname $cmds2 $rest
}

proc GetTag {} {return [.tag get 1.0 end]}
proc GetBody {} {return [.t get 1.0 end]}
 
proc SetTag {text} {
    .tag delete 1.0 end
    .tag insert 1.0 $text
}

proc SetLabel {str} {MakeTag $str}

proc GetLabel {} {
    lassign [DeconsTag] label
    return $label
}

proc UpdateTag {{fname ""}} {
    global current_filename output_window_rx editable
    if {$fname != ""} {
        set fname [CanonicalFilename $fname]
        if {![regexp $output_window_rx $fname]} {
            set current_filename $fname
            set env(MA_LABEL) $current_filename
        }
        if {[regexp {/$} $fname]} {
            set dir $fname
        } else {
            set dir [file dirname $fname]
        }
        if {[file exists $dir]} {cd $dir}
    } else {
        set fname $current_filename
    }
    wm title . $fname
    MakeTag $fname
    .tag mark set insert "1.0 lineend"
    set aname [tk appname]

    # if this was an output window, reregister under a new name
    if {[regexp $output_window_rx $aname]} {
        catch [list send MA-registry Unregister "$aname"]
        tk appname MA-[pid]
        set editable 1
    }
    catch [list send -async MA-registry Register $aname "{$fname}"]
}

proc GetFilename {} {
    global current_filename output_window_rx unnamed
    global unnamed_name
    lassign [DeconsTag] name
    if {$name == $unnamed_name} {
        set unnamed 1
        return ""
    }
    if {![regexp $output_window_rx $name] && !$unnamed} {
        set current_filename $name
    }
    set unnamed 0
    return $current_filename
}

proc GetFileDir {} {
    lassign [DeconsTag] name
    set name2 [FollowLink $name]
    if {[file exists $name2] && [file type $name2] == "directory"} {
        return [file normalize $name]
    } else {
        return [file normalize [file dirname $name]] 
    }
    return [pwd]
}

proc OpenNewFile {fname} {
    if {[CheckIfModified]} {
        if {[ConfirmModified]} return
    }
    OpenFile $fname
}

proc OpenFile {name {replace 1}} {
    global current_filename last_opened current_translation
    global position_stack
    if {[file exists $name]} {
        set t [file type [FollowLink $name]]
        if {[file type $name] == "file"} {
            set last_opened [list $name [file mtime $name]]
            lassign [ReadFile $name] text tr
            UpdateTag $name
            if {$replace} {
                SetBody $text
                .t mark set insert 1.0
                .t see insert
            } else {
                Insert $text
            }
            set position_stack {}
            set current_translation $tr
            Unmodified
            RunHook file_hook
            return
        }
        LogInWindow "$name is not a regular file" 1
        return
    }
    LogInWindow "no such file: $name" 1
}

proc ReplaceFile {fname} {
    global current_translation position_stack
    lassign [ReadFile $fname] text tr
    SetBody $text
    .t mark set insert 1.0
    .t see insert
    Unmodified
}

proc SetBody {text} {
    global position_stack
    .t delete 1.0 end
    .t insert 1.0 $text
    set position_stack {}
    set ip "end - 1 chars"
    if {$text == ""} {set ip end}
    .t mark set win_insert_point $ip
}

proc SetDot {addr} {
    lassign [AddrIndices $addr] from to
    RemoveSelection
    .t tag add sel $from $to
}

proc GetDot {} {
    set range [.t tag ranges sel]
    if {$range == ""} {
        return "#[.t count -chars 1.0 insert]"
    }
    set p1 [.t count -chars 1.0 [lindex $range 0]]
    set p2 [.t count -chars 1.0 [lindex $range 1]]
    return "#$p1,#$p2"
}

proc AppendFile {fname} {
    global scroll eot_symbol last_scroll_bottom
    set f [open $fname]
    set p [.t index end]
    Append [read $f]
    close $f
    Append "$eot_symbol\n"
    if {!$scroll} {
        .t yview [expr max(0.0, $p - 1)]
        set last_scroll_bottom [.t index end]
    }
}

proc InsertFile {fname} {
    set f [open $fname]
    Insert [read $f]
    close $f
}

proc FollowLink {fname} {
    if {![file exists $fname]} {return $fname}
    if {[catch [list file type $fname] result]} {return $fname}
    if {$result == "link"} {
        if {[catch [list file readlink $fname] fn2]} {
            return $fname
        }
        if {![regexp {^/} $fn2]} {
            set fn2 "[file dirname $fname]/$fn2"
        }
        return [FollowLink $fn2]
    }
    return $fname
}

proc NeedsQuoting {fname} {
    global rc_style_quoting
    if {![string match {*[ '()]*} $fname]} {return 0}
    set len [string length $fname]
    if {$rc_style_quoting} {
        set flen 2
        for {set i 0} {$i < $len} {incr i} {
            if {[string index $fname $i] == "\'"} {incr flen}
        }
        return $flen
    }
    return [expr $len + 2]
}

proc QuoteString {fname} {
    global rc_style_quoting
    set len [string length $fname]
    if {$rc_style_quoting} {
        set str "\'"
        append str [regsub -all {'} $fname "''"] "\'"
        return $str
    }
    if {[string first "\'" $fname] != -1} {
        return "\"$fname\""
    }
    return "\'$fname\'"
}

proc FormatColumnar {list} {
    global current_font rc_style_quoting
    set zw [font measure $current_font 0]
    set w [expr [winfo width .t] / $zw]
    set n [llength $list]
    set maxlen 0
    # compute maximal item length
    foreach x $list {
        set len [string length $x]
        incr len [NeedsQuoting $x]
        if {$len > $maxlen} {set maxlen $len}
    }
    incr maxlen 2
    set cols [expr max(1, round($w / $maxlen))]
    set rows [expr ceil(double($n) / $cols)]
    set text ""
    for {set i 0} {$i < $rows} {incr i} {
        for {set j 0} {$j < $cols} {incr j} {
            set f [lindex $list [expr $i * $cols + $j]]
            set flen [string length $f]
            set leni [NeedsQuoting $f]
            if {$leni} {
                if {[string index $f end] == "/"} {
                    set f [QuoteString [string range $f 0 "end-1"]]/
                } else {
                    set f [QuoteString $f]
                }
                incr flen $leni
            }
            if {$cols > 1} {
                set pad [string repeat " " [expr $maxlen - $flen]]
            } else {
                set pad ""
            }
            append text $f $pad
        }
        append text "\n"
    }
    return $text
}

proc OpenDirectory {name} { 
    global current_translation position_stack editable dotfiles
    global directory_commands directory_hook
    set name [file normalize $name]
    if {[catch [list glob -tails -directory $name *] files]} {
        set files {}
    }
    if {$dotfiles} {
        set files [concat $files [glob -nocomplain -tails -types hidden -directory $name *]]
    }
    set files [lsort -dictionary $files]
    set nfiles {}
    # add "/", if directory
    foreach f $files {
        if {$f != "." && $f != ".."} {
            if {[file type [FollowLink "$name/$f"]] == "directory"} {
                append f "/"
            }
            lappend nfiles $f
        }
    }
    update
    set text [FormatColumnar $nfiles]
    UpdateTag "$name/"
    SetBody $text
    .t mark set insert 1.0
    set position_stack {}
    Top
    ToggleFont fix
    set current_translation lf
    Unmodified
    foreach cmd $directory_commands {
        UpdateCommand $cmd
    }
    set editable 0
    RunHook directory_hook $name
}

proc SaveFile {{name ""} {force 0}} {
    global current_filename last_opened editable override_attempt
    global unnamed
    GetFilename
    if {$name == ""} {
        set name $current_filename
    }
    if {$force} {set editable 1}
    if {[RunHook pre_save_hook $name] != ""} {
        return 1
    }
    if {$name == ""} {
        LogInWindow "file has no name\n" 1
        return 0
    }
    if {![CheckIfModified] && !$force && [file exists $name]} {
        return 1
    }
    set x [file exists $name]
    if {$last_opened != ""} {
        if {[lindex $last_opened 0] == $name && $x && \
            [lindex $last_opened 1] != [file mtime $name]} {
            LogInWindow "$name has been modified externally\n" 1
            set last_opened ""
            set override_attempt 1
            return 0
        }
    } elseif {$x} {
        if {!$override_attempt} {
            LogInWindow "$name already exists\n" 1
            set override_attempt 1
            return 0
        }
    }
    set override_attempt 0
    set name [CanonicalFilename $name]
    set dir [file dirname $name]
    if {![file exists $dir]} {
        file mkdir $dir
    }
    cd $dir
    WriteFile $name
    set last_opened [list $name [file mtime $name]]
    Unmodified
    UpdateTag $name
    RunHook save_hook
    return 1
}

proc WriteFile {name} {
    set out [open $name w]
    set text [.t get 1.0 "end - 1 chars"]
    RunHook write_hook $text
    puts -nonewline $out $text
    close $out
    if {[string equal -length 3 $text "#!/"]} {
        file attribute $name -permissions a+x
    }
}

proc Flash {{color red}} {
    global current_background
    .t configure -background $color
    update
    after 100 {.t configure -background $current_background}
}

proc CheckIfModified {} {
    global editable unnamed
    GetFilename
    if {[.t edit modified] && $editable && !$unnamed} {
        return 1 
    }
    return 0
}

proc SaveIfModified {} {
    if {[CheckIfModified]} SaveChanges
}

proc WithdrawWindow {} {
    global withdrawn
    if {!$withdrawn} {
        wm withdraw .
        set withdrawn 1
    }
}

proc DeiconifyWindow {} {
    global withdrawn
    if {$withdrawn} {
        wm deiconify .
        set withdrawn 0
    }
}

proc Insert {text {tags ""}} {
    DeiconifyWindow
    .t insert insert $text $tags
    .t see insert
}

proc Append {text {sel 0}} {
    DeiconifyWindow
    set p1 [.t index "end - 1 chars"]
    .t insert end $text
    ScrollToBottom
    if {$sel} { 
        RemoveSelection .t
        .t tag add sel $p1 "end - 1 chars"
    }
}

proc ScrollToBottom {} {
    global win_mode scroll
    if {!$scroll} return
    if {$win_mode} {
        if {[catch {.t dlineinfo win_insert_point} result] || \
            $result != ""} {  
            Bottom
        }
    } else Bottom
}

proc AppendLine {text {sel 0}} {
    Append "$text\n" $sel
}

proc ConfirmModified {} {
    global current_filename last_del_attempt
    set cnt [.t count -chars 1.0 end]
    if {$last_del_attempt == 0 || $cnt != $last_del_attempt} {
        LogInWindow "$current_filename is modified\n" 1
        Flash 
        set last_del_attempt $cnt
        return 1
    }
    return 0
}

proc Terminate {{force 0} {status 0}} {
    global current_filename last_del_attempt win_mode
    if {!$force && [CheckIfModified]} { 
        if {[ConfirmModified]} return
    }
    catch [list send -async MA-registry Unregister [tk appname]]
    RunHook termination_hook
    exit $status
}

proc ResizeFont {{val ""}} {
    global current_font fixed_font variable_font
    lassign $current_font name size style
    if {$val == ""} {set val $size}
    set font [list $name $val $style]
    if {$current_font == $fixed_font} {
        set fixed_font $font
    } else {
        set variable_font $font
    }
    set current_font $font
    .t configure -font $font
    RunHook configuration_hook
}

proc ConfigureWindow {{runhook 1}} {
    global current_background current_foreground current_font 
    global tag_foreground tag_background selection_foreground 
    global selection_background tag_font sbar_width
    global sbar_color sbar sbar_background b2sweep_foreground 
    global b2sweep_background 
    global b3sweep_foreground b3sweep_background pseudo_selection_foreground 
    global pseudo_selection_background 
    global win_mode wrap_mode
    global inactive_selection_background 
    global has_focus focus_color nonfocus_color cursor
    if {$has_focus} {
        . configure -highlightcolor $focus_color -highlightbackground \
            $focus_color
    } else {
        . configure -highlightcolor $nonfocus_color -highlightbackground \
            $nonfocus_color
    }
    .tag configure -background $tag_background -foreground $tag_foreground \
	-selectbackground $selection_background -selectforeground $selection_foreground \
	-inactiveselectbackground $inactive_selection_background \
	-insertbackground $tag_foreground -font $tag_font \
        -insertofftime 0 -relief solid -highlightthickness 0 -wrap char \
        -borderwidth 1 -cursor $cursor
    .t configure -background $current_background -foreground $current_foreground  \
	-selectbackground $selection_background -selectforeground $selection_foreground \
	-inactiveselectbackground $inactive_selection_background \
	-insertbackground $current_foreground -font $current_font \
        -relief flat -borderwidth 1 -highlightthickness 0 \
        -insertofftime 0 -insertwidth 3 -wrap $wrap_mode -cursor $cursor
    .s configure -background $sbar_color -relief solid -borderwidth 1 \
        -highlightthickness 0 -width $sbar_width -cursor $cursor
    .s itemconfigure $sbar -fill $sbar_background -width 0 -stipple ""
    .t tag configure pseudosel -foreground $pseudo_selection_foreground -background $pseudo_selection_background
    .tag tag configure pseudosel -foreground $pseudo_selection_foreground -background $pseudo_selection_background
    .t tag configure b2sweep -foreground $b2sweep_foreground -background $b2sweep_background
    .tag tag configure b2sweep -foreground $b2sweep_foreground -background $b2sweep_background
    .t tag configure b3sweep -foreground $b3sweep_foreground -background $b3sweep_background
    .tag tag configure b3sweep -foreground $b3sweep_foreground -background $b3sweep_background
    .t tag lower pseudosel
    .tag tag lower pseudosel
    if {$win_mode} {.t configure -insertofftime 300}
    if {$runhook} {
        RunHook configuration_hook
    }
}

proc DefineKey {event cmd} {
    bind .tag $event $cmd
    bind .t $event $cmd
}

proc DoRunCommand {cmd {inputfile ""}} {
    global command_input_file shell
    if {$inputfile != ""} {
        set command_input_file $inputfile
        return [open "| $shell -c {$cmd} < $inputfile 2>@1" r]
    } else {
        return [open "| $shell -c {$cmd} << {} 2>@1" r]
    }
}

proc RunExternalCommand {cmd {inputfile ""} {sender ""} {sender_label ""}} {
    global executing_pids command_input_file env scroll 
    global last_scroll_bottom
    if {!$scroll} {
        set last_scroll_bottom [.t index end]
    }
    if {$sender != ""} {
        set env(MA) $sender 
        set env(MA_LABEL) $sender_label
    }
    if {[catch [list DoRunCommand $cmd $inputfile] input]} {
        Append "\nCommand failed: $input\n"
        Bottom
        if {$command_input_file != ""} {
            file delete -force $command_input_file
        }
        return
    }
    lappend executing_pids [pid $input]
    fconfigure $input -blocking 0
    fileevent $input readable [list LogOutput $input]
}

proc RecordPosition {} {
    global last_mouse_index
    set last_mouse_index [.t index insert]
}

proc LogOutput {input} {
    global current_background command_input_file eot_symbol executing_pids 
    global any_output win_mode scroll last_scroll_bottom
    set data [read $input]
    set blocked [fblocked $input]
    if {$data != ""} {
        DeiconifyWindow
        set any_output 1
        Append "$data"
        if {$win_mode} {
            .t mark set win_insert_point "end - 1 chars"
            .t mark gravity win_insert_point left
        }
        if {!$scroll} {
            .t yview [expr max(1.0, $last_scroll_bottom - 1.0)]
        }
    } elseif {!$blocked} {
        set pid [pid $input]
        if {[catch [list close $input] result]} {
            Append "\nCommand failed: $result"
            Bottom
            set any_output 1
        } else {
            Append "$eot_symbol\n"
        }
        DropExecutingPid $pid
        if {$command_input_file != ""} {
           file delete -force $command_input_file
        }
        if {!$any_output} {Terminate 1}
        if {$executing_pids == ""} {
            set win_mode 0
        }
    }
    update idletasks
}

proc Evaluate {cmd} {
    if {[catch [list uplevel #0 $cmd] result]} {
        Flash red
    } else {
        Flash blue
    }
}

proc CanonicalFilename {str} {
    if {![regexp {^\s*[~/]} $str]} {
        set fname "[pwd]/$str"
    } else {
        set fname $str
    }
    if {[file exists $fname]} {
        set fname [file normalize $fname]
        if {[file type $fname] == "directory"} {
            append fname "/"
        }
    }
    return $fname
}

proc Plumb {str args} {
    global plumbing_rules command_arguments exec_prefix plumber
    foreach r $plumbing_rules {
        set command_arguments [regexp -inline -- [lindex $r 0] $str]
        if {$command_arguments != ""} {
            set r [eval [lindex $r 1]]
            if {$r != 0} {return 1}
        }
    }
    if {[catch [list exec sh -c "${exec_prefix}$plumber \"$str\" $args"]]} {
        return 0
    }
    return 1
}

proc Acquire {} {
    global search_string ma hash_dict 
    set fw [GetFocusWidget]
    # range: either what is swept with B3, or the selection (if the mouse is inside it)
    # or the word under the cursor:
    set range [$fw tag ranges b3sweep]
    if {$range == ""} {
        set range [$fw tag ranges sel]
        if {$range == "" || [lsearch -exact [$fw tag names current] sel] == -1} {
            set range ""
        }
    }
    if {$range == ""} {
        set dest [GetWordUnderCursor $fw]
        set start [$fw index "current + [string length $dest] chars"]
    } else {
        set start "[lindex $range 0] + 1 chars"
        set dest [$fw get [lindex $range 0] [lindex $range 1]]        
    }
    RemoveTaggedRange $fw b3sweep
    set dest [string trim $dest]
    if {$dest == ""} return
    if {[Plumb $dest]} return
    lassign [DeconsTag] name
    if {"$name" == $dest} {
        RemoveSelection .t
        .t tag add sel 1.0 end
        return
    }
    set fname $dest
    set fname [CanonicalFilename $fname]
    if {[file exists $fname]} {
        RemoveSelection
        set fname [FollowLink $fname]
        GotoFileAddress $fname
        return
    }
    # force search in body
    if {$range == "" && $fw != ".t"} {set start [.t index insert]}
    Search $dest $start
}

proc Search {{str ""} {start ""} {case 0} {warp 1}} {
    global search_string
    if {$str != ""} {
        set search_string $str
    } else {
        return
    }
    set range [.t tag ranges sel]
    if {$start == ""} {
        if {$range != ""} {
            set p1 [lindex $range 0]
            set start "$p1 + 1 chars"
        } else {
            set start "insert + 1 chars"
        }
    }
    if {$case} {
        set found [.t search -- $search_string $start]
    } else {
        set found [.t search -nocase -- $search_string $start]
    }
    if {$found != ""} {
        # keep selection in case it was in tag
        if {[GetFocusWidget] == ".tag"} {
            SaveSelection .tag
        }
        RemoveSelection .t
        set len [string length $search_string]
        set end "$found + $len chars"
        .t tag add sel $found $end
        MoveInsert $end
        if {$warp} {WarpToIndex .t $found}
    }
}

proc WarpToIndex {fw index} {
    set info [.t bbox $index]
    if {$info != ""} {
        set x [expr [lindex $info 0] + [lindex $info 2] / 2]
        set y [expr [lindex $info 1] + [lindex $info 3] / 2]
        event generate .t <Motion> -x $x -y $y -warp 1
    }
}

proc GetFocusWidget {} {
    set fw [focus -displayof .]
    if {$fw == ""} {
        return .t
    }
    return $fw
}

proc GetWordUnderCursor {{fw ""}} {
    set ixs [GetWordUnderIndex $fw current]
    if {$ixs == ""} {
        return ""
    }
    return [eval $fw get $ixs]
}

proc GetWordUnderIndex {fw idx} {
    set startx [$fw index "$idx linestart"]
    regexp {^(\d+)\.} $startx _ lnum
    set endx [$fw index "$idx lineend"]
    set posx [$fw index $idx]
    set start [$fw get $startx $posx]
    set end [$fw get $posx $endx]
    regexp {\.(\d+)$} $posx _ col
    if {[regexp -indices "(\[^ \t\r\"'()\\\[\\\]{}\]+)\$" $start _ pos]} {
        set w0 [lindex $pos 0]
        if {[regexp -indices "^(\[^ \t\r\"'()\\\[\\\]{}\]+)" $end _ pos]} {
            return [list "$lnum.$w0" "$lnum.[expr $col + [lindex $pos 1] + 1]"]
        }
        return [list "$lnum.$w0" "$lnum.[expr [lindex $pos 1] + 1]"]
    }
    if {[regexp -indices "^(\[^ \t\r\"'()\\\[\\\]{}\]+)" $end _ pos]} {
        return [list $posx "$lnum.[expr $col + [lindex $pos 1] + 1]"]
    }
    return ""
}

proc DropExecutingPid {pid} {
    global executing_pids
    set i [lsearch -exact $pid $executing_pids]
    if {$i != -1} {
        set executing_pids [lreplace $executing_pids $i $i] 
    }
}

proc KillExecuting {{signal SIGKILL} {parent 0}} {
    global executing_pids win_mode
    if {$executing_pids != ""} {
        if {!$win_mode} {
            foreach pid $executing_pids {
                # shell may have exec'd or may have forked subprocesses
                set cpids [ChildPids $pid]
                catch [list exec kill -$signal {*}$cpids]
                if {[catch [list exec kill -$signal $pid]]} {
                    DropExecutingPid $pid
                }
            }
        } else {
            if {$parent} {
                set win_mode 0
            }
            foreach pid $executing_pids {
                if {[catch [list exec kill -$signal $pid]]} {
                    DropExecutingPid $pid
                }
            }
        }
    }
}

proc InvokeExternalCommandInWindow {cmd {input ""}} {
    global current_filename
    set myname [tk appname]
    ExecuteInWindow [list RunExternalCommand $cmd $input $myname $current_filename]
    return 1
}

proc ExecuteInWindow {cmd {tag ""}} {
    global ma 
    set dir [GetFileDir]
    set name "$dir/+Errors"
    if {[catch [list send $name #]]} {
        if {$tag == ""} {
            set tag "$dir/+Errors New Kill Del Cut Paste Snarf Look Font Scroll | "
        }
        Ma -name $name -temporary -cd $dir -tag $tag -withdrawn -post-eval $cmd
    } else {
        catch [list send $name $cmd]
    }
}

proc SendToProcess {{cmd ""}} {
    global win_file win_mode
    set range [GetEffectiveSelection .t]
    if {$cmd == ""} {
        if {$range != ""} {
            set cmd [.t get [lindex $range 0] [lindex $range 1]]
        } else return
    }
    RemoveSelection .t
    Append "$cmd\n"
    .t mark set insert end
    if {$win_mode} {
        puts $win_file $cmd
        flush $win_file
        AddToHistory $cmd
    }
}

proc LogInWindow {msg {sel 0}} {
    ExecuteInWindow [list Append $msg $sel]
}

proc SmartIndent {} {
    global tabwidth indent_mode
    if {[GetFocusWidget] != ".t"} return
    set pos [.t index insert]
    regexp {(\d+)\.(\d+)} $pos all row col
    if {$row > 1 && $indent_mode} {
        set rowup [expr $row - 1]
        set above [.t get $rowup.0 "$rowup.0 lineend"]
        set uplen [string length $above]
        if {$uplen > $col} {
            set i $col
            # first skip non-ws chars
            while {$i < $uplen && [string index $above $i] != " "} {
                incr i
            }
            while {$i < $uplen} {
                if {[string index $above $i] != " "} {
                    Insert [string repeat " " [expr $i - $col]]
                    return
                }
                incr i
            }
        }
    }
    set tcol [expr (($col / $tabwidth) + 1) * $tabwidth]
    Insert [string repeat " " [expr $tcol - $col]]
}

proc EnterRemoteMode {win host} {
    global remote
    set remote $win
    SetFontStyle italic
    ResizeFont
}

proc RemoteSend {cmd} {
    global remote
    if {[catch [list send $remote SendToProcess "{$cmd}"]]} {
        set remote ""
        SetFontStyle normal
        return 0
    }
    return 1
}

proc TempFile {} {
    global env
    set tmpdir "/tmp"
    if {[info exists env(TMPDIR)]} {
        set tmpdir $env(TMPDIR)
    }
    return "$tmpdir/0.[pid].[expr rand()]"
}

proc RemoveTempFile {fname} {
    after 1000 [list file delete $fname]
}

proc RefreshDirectory {} {
    global current_filename
    if {[GetFilename] != ""} {
        if {[file type $current_filename] == "directory"} {
            OpenDirectory $current_filename
            cd $current_filename
        }
    }
}

proc RevertFile {{force 0}} {
    global current_filename
    if {[RunHook revert_hook $force] != ""} return
    if {[GetFilename] != ""} {
        if {!$force && [CheckIfModified]} {
            if {[ConfirmModified]} return
        }
        set current_filename [FollowLink $current_filename]
        if {[file type $current_filename] == "directory"} {
            OpenDirectory $current_filename
            cd $current_filename
        } else {
            OpenFile $current_filename
        }
    }
}

proc Execute {fw {arg ""}} {
    global has_focus 
    # range: either what is swept with B2, or the selection (if the mouse is inside it)
    # or the word under the cursor:
    set range [$fw tag ranges b2sweep]
    if {$range == ""} {
        set range [$fw tag ranges sel]
        if {$range == "" || [lsearch -exact [$fw tag names current] sel] == -1} {
            set range ""
        }
    }
    if {$range == ""} {
        set cmd [GetWordUnderCursor $fw]
    } else {
        set cmd [$fw get [lindex $range 0] [lindex $range 1]]
    }
    RemoveTaggedRange $fw b2sweep
    set cmd [string trim $cmd]
    if {$cmd == ""} return
    if {$arg != ""} {
        append cmd " $arg"
    }
    if {$fw == ".tag" || $has_focus || \
        [catch [list send MA-registry FocusExecute "{$cmd}" "{[pwd]}"] result] \
        || !$result} {
        DoExecute $cmd
    }
}

proc FocusExecute {cmd ctxt} {
    global focus_window
    if {$focus_window != ""} {
        .t insert end "focus execute: $focus_window : $cmd (context: $ctxt)\n"
        Bottom
        if {![catch [list send $focus_window DoExecute "{$cmd}" "{$ctxt}"]]} {
            return 1
        }
    }
    return 0
}

proc DoExecute {cmd {ctxt ""}} {
    global command_table command_arguments shell win_mode
    global remote
    set sel [GetEffectiveSelection .t]
    set ptop [lindex [.t yview] 0]
    switch -regexp -- $cmd {
        {^$} return
        {^\|} {
            if {$sel == ""} {
                set start 1.0
                set end end
            } else {
                set start [lindex $sel 0]
                set end [lindex $sel 1]
            }
            set input [.t get $start $end]                
            set cmd [string range $cmd 1 end]
            set outf [TempFile]
            set output ""
            if {[catch [list exec $shell -c $cmd << $input > $outf] result]} {
                LogInWindow $result 1
                return
            } else {
                .t delete $start $end
                .t mark set insert $start

                if {[file exists $outf]} {
                    lassign [ReadFile $outf] output
                    file delete -force $outf
                }
            }
            Insert $output sel
            .t yview moveto $ptop
            return
        }
        {^<} {
            set outf [TempFile]
            set cmd [string range $cmd 1 end]
            set output ""
            if {[catch [list exec $shell -c $cmd < /dev/null > $outf] result]} {
                LogInWindow $result 1
            } else {
                if {[file exists $outf]} {
                    lassign [ReadFile $outf] output
                    file delete -force $outf
                }
            }
            if {$sel != ""} {eval .t delete $sel}
            Insert $output sel
            .t yview moveto $ptop
            return
        }
        {^>} {
            if {$sel == ""} {
                set input [.t get 1.0 end]
            } else {
                set input [.t get [lindex $sel 0] [lindex $sel 1]]
            }
            set cmd [string range $cmd 1 [string length $cmd]]
            set inf [TempFile]
            set f [open $inf w]
            puts -nonewline $f $input
            close $f
            InvokeExternalCommandInWindow $cmd $inf
            return
        }
    }
    foreach opr $command_table {
        set command_arguments [regexp -inline -- [lindex $opr 0] $cmd]
        if {$command_arguments != ""} {
            eval [lindex $opr 1]
            return
        }
    }
    if {$remote != ""} {
        if {[RemoteSend $cmd]} return
    }
    if {[RunHook execute_hook $cmd $ctxt] != ""} return
    if {$win_mode} {
        SendToProcess $cmd
        return
    }
    set cmd1 [FindExecutable $cmd]
    if {$cmd1 == ""} return
    InvokeExternalCommandInWindow $cmd1
    AddToHistory $cmd
}

proc AddToHistory {cmd} {
    global history_file
    if {$history_file != ""} {
        set f [open $history_file a]
        puts $f $cmd
        close $f
        file attributes $history_file -permissions go-rw
    }
}

proc Scrolling {start end} {
    global sbar sbar_height
    set w [winfo width .s]
    set h [winfo height .s]
    set y1 [expr $h * $start]
    set y2 [expr $h * $end]
    if {($y2 - $y1) < 3} {set y2 [expr $y1 + 3]}
    .s coords $sbar 0 $y1 $w $y2
    set sbar_height [expr $y2 - $y1]
}

proc ScrollUp {p {cont 0}} {
    global scroll_repeat scroll_task
    .t yview scroll [expr -$p] pixels
    if {$cont} {
        if {$scroll_task != ""} {after cancel $scroll_task}
        set p [expr [winfo pointery .s] - [winfo rooty .s]]
        set scroll_task [after $scroll_repeat [list ScrollUp $p 1]]
    }
}

proc EndScrolling {} {
    global scroll_task
    after cancel $scroll_task
    set scroll_task ""
}

proc ScrollDown {p {cont 0}} {
    global scroll_repeat scroll_task
    .t yview scroll $p pixels
    if {$cont} {
        if {$scroll_task != ""} {after cancel $scroll_task}
        set p [expr [winfo pointery .s] - [winfo rooty .s]]
        set scroll_task [after $scroll_repeat [list ScrollDown $p 1]]
    }
}

proc ScrollTo {p} {
    global sbar_height
     set h [winfo height .s]
     set f [expr double($p - $sbar_height / 2) / $h]
     .t yview moveto $f
}

proc GetSelection {{fw ""}} {
    if {$fw == ""} {
        set fw [GetFocusWidget]
    }
    set range [GetEffectiveSelection $fw]
    if {$range == ""} {
        return [$fw get {insert linestart} {insert lineend}]
    }
    return [$fw get [lindex $range 0] [lindex $range 1]]
}

proc GetEffectiveSelection {w} {
    set sel [$w tag ranges sel]
    if {$sel == ""} {
        return [$w tag ranges pseudosel]
    }
    return $sel
}

proc GetSelectedLines {} {
    set range [GetEffectiveSelection .t]
    if {$range == ""} {
        return [.t get {insert linestart} {insert lineend}]
    }
    return [.t get "[lindex $range 0] linestart" "[lindex $range 1] lineend"]
}

proc RemoveSelection {{fw ""}} {
    global pseudosel_on
    set rfw [focus -displayof .]
    if {$fw == ""} {
        set fw $rfw
    }
    foreach tag {sel pseudosel b2sweep b3sweep} {
        set old [$fw tag ranges $tag]
        if {$old != ""} {
            eval $fw tag remove $tag $old
        }   
    }
    set pseudosel_on($fw) 0
    return $fw
}

proc RemovePseudoSelection {fw} {
    global pseudosel_on
    foreach tag {pseudosel b2sweep b3sweep} {
        set old [$fw tag ranges $tag]
        if {$old != ""} {
            eval $fw tag remove $tag $old
        }
    }
    set pseudosel_on($fw) 0
}

proc RestoreSelection {fw} {
    global pseudosel_on 
    set old [$fw tag ranges sel]
    if {$old == ""} {
        set old [$fw tag ranges pseudosel]
        if {$old != ""} {
            eval $fw tag add sel $old
            eval $fw tag remove pseudosel $old
            set pseudosel_on($fw) 0
        }
    }
}

proc SaveSelection {fw} {
    global pseudosel_on
    set old [$fw tag ranges sel]
    if {$old != ""} {
        eval $fw tag add pseudosel $old
        set pseudosel_on($fw) 1
    }
}

proc SetTaggedRange {fw tag from to} {
    set old [$fw tag ranges $tag]
    if {$old != ""} {
        eval $fw tag remove $tag $old
    }
    if {[$fw compare $from > $to]} {
        set tmp $from
        set from $to
        set to $tmp
    }
    $fw tag add $tag $from $to
}

proc RemoveTaggedRange {fw tag} {
    set old [$fw tag ranges $tag]
    if {$old != ""} {
        eval $fw tag remove $tag $old
    }
}

proc ChildPids {ppid} {
    if {[catch [list open "| pgrep -P $ppid"] f]} {return {}}
    set cpids {}
    while {[gets $f line] > 0} {
        lappend cpids $line
    }
    catch [list close $f]
    return $cpids
}

proc EnterWinMode {{cmd ""}} {
    global win_mode executing_pids win_file exec_prefix env shell scroll
    if {$cmd == ""} {set cmd $shell}
    if {[catch [list open "| ${exec_prefix}pty $cmd 2>@1" \
        r+] win_file]} {
        Append "\nCommand failed: $win_file\n"
        return
    }
    set win_mode 1
    ToggleScroll 1
    eval lappend executing_pids [pid $win_file]
    fconfigure $win_file -blocking 0
    fileevent $win_file readable [list LogOutput $win_file]
    .t configure -insertofftime 300
    bind .t <Return> {
        global win_file win_mode password_input password_char
        # win-mode may be off, when process was killed
        if {$win_mode} {
            if {[catch {.t index win_insert_point} ip]} {
                set ip 1.0
            }
            if {[.t compare [.t index insert] > $ip]} {
                set text [.t get $ip "insert lineend"]
            } else {
                set text [.t get "insert linestart" "insert lineend"]
            }
            .t mark set insert "end - 1 chars"
            if {$password_input != ""} {
                regsub "$password_char+" $text $password_input rtext
                set password_input ""
            } else {
                set rtext $text
            }
            puts $win_file $rtext
            flush $win_file
            AddToHistory $text
            Insert "\n"
            .t mark set win_insert_point insert
            break
        }
    }
    DefineCommand {^Interrupt$} {
        global win_file
        puts $win_file "\x03"
        flush $win_file
    }
    bind .t <KeyPress> {
        global password_input password_char
        set char %A
        TakeFocus
        if {[string is print -strict $char]} {
            set txt [.t get "insert linestart" insert]
            if {[regexp -nocase {pass(word|phrase).*:} $txt]} {
                Insert $password_char
                append password_input $char
                break
            }
        }
    }
    bind .t <BackSpace> {
        global password_input password_char
        TakeFocus
        set txt [.t get "insert linestart" insert]
        if {[regexp -nocase "pass(word|phrase).*:\\s*(${password_char}*)\$" \
            $txt _ _ pw]} {
            if {[string length $pw] >= 1} {
                .t delete "insert - 1 chars"
                set password_input [string range $password_input 0 end-1]
                break
            } else break
        }
    }
}

proc PolishCompletion {file {qp ""}} {
    set slash ""
    if {[file exists $file]} {
        if {[file type $file] == "directory" && [string index $file end] != "/"} {
            set slash "/"
        }
    }
    if {$qp == "" && [string first " " $file] != -1 && [string index $file 0] != "'"} {
        set file "'$file'"
    } else {
        set file "$file$slash"
    }

    return $file
}

proc FilenameCompletion {} {
    set fw [GetFocusWidget]
    set qp1 [$fw search -backwards "'" insert "insert linestart"]
    set qp2 [$fw search "'" insert "insert lineend"]
    if {$qp1 != "" && $qp2 != ""} {
        set ixs [list [$fw index "$qp1 + 1 chars"] [$fw index "$qp2"]]
    } else {
        set ixs [GetWordUnderIndex $fw insert]
    }
    if {$ixs == ""} return
    set name [eval $fw get $ixs]
    set prefix ""
    if {[regexp {^([`"'\(\[\{<>|;:,=]+)(.+)$} $name _ prefix name2]} {
        set name $name2
    }
    set files [glob -nocomplain -- "$name*"]
    set flen [llength $files]
    set nlen [string length "$name"]
    if {$flen == 0} return
    if {$flen > 1} {
        set i [string length $name]
        set scan 1
        set f0 [lindex $files 0]
        while {$scan} {
            set c [string index $f0 $i]
            foreach f $files {
                # includes f0, but will succeed
                if {[string index $f $i] != $c} {
                    set scan 0
                    incr i -1
                    break
                }
            } 
            if {$scan} { incr i }
        }
        if {$i > $nlen} {
            set name2 [PolishCompletion [string range $f0 0 $i] $qp1]
            $fw mark set insert [lindex $ixs 1]
            $fw replace [lindex $ixs 0] [lindex $ixs 1] "$prefix$name2"
            return
        }
        LogInWindow "Completions:\n[FormatColumnar $files]" 1
        return
    }
    set file [PolishCompletion [lindex $files 0] $qp1]
    $fw mark set insert [lindex $ixs 1]
    $fw replace [lindex $ixs 0] [lindex $ixs 1] "$prefix$file"
}

proc MatchDelimitedForward {start {fw ""}} {
    if {$fw == ""} {
        set fw [GetFocusWidget]
    }
    set i 0
    set p $start
    set done 0
    set ok 0
    set quotes ""
    set c1 [$fw get $start]
    if {$c1 == "\"" || $c1 == "'"} {
        set quotes $c1
    }
    while {!$done} {
        set p [$fw search -regexp {\[|\]|\(|\)|\{|\}|"|'} $p end]
        if {$p == ""} {
            set p end
            break
        }
        set c [$fw get $p]
        switch -glob -- $c {
            "(" { set stack($i) ")"; incr i }
            "\\[" { set stack($i) "\]"; incr i }
            "\{" { set stack($i) "\}"; incr i }
            "[\"']" {
                while 1 {
                    set p2 [$fw search $c "$p + 1 chars" end]
                    if {$p2 == ""} {
                        set done 1
                        break                    
                    }
                    set p $p2
                    if {[$fw get "$p - 1 chars"] != "\\"} {
                        if {$quotes != ""} {
                            set done 1
                            set ok 1
                        }
                        break
                    }
                }
            }
            default {
                if {$c == $stack([expr $i - 1])} {
                    incr i -1
                    if {$i == 0} { 
                        set done 1 
                        set ok 1
                    }
                } else break
            }
        }
        set p [$fw index "$p + 1 chars"]
    }
    if {$done} {
        return [list 1 $start $p]
    }
    return [list 0 $start $p]
}

proc MatchDelimitedBackwards {start {fw ""}} {
    if {$fw == ""} {
        set fw [GetFocusWidget]
    }
    set i 0
    set p $start
    set done 0
    set ok 0
    while {!$done} {
        set p [$fw search -regexp -backwards {\[|\]|\(|\)|\{|\}|"} $p 1.0]
        if {$p == ""} {
            set p 1.0
            break
        }
        set c [$fw get $p]
        switch -- $c {
            ")" { set stack($i) "("; incr i }
            "\]" { set stack($i) "\["; incr i }
            "\}" { set stack($i) "\{"; incr i }
            "\"" {
                while 1 {
                    set p2 [$fw search -backwards "\"" $p 1.0]
                    if {$p2 == ""} {
                        set done 1
                        break                    
                    }
                    set p $p2
                    if {[$fw get "$p - 1 chars"] != "\\"} break
                }
            }
            default {
                # this is to catch a strange situation where fast typing can
                # lead to "insert" being _before_ the currently added closing delimiter
                # (a bug in Tcl/Tk, perhaps, or a race condition)
                if {$i == 0} break
                if {$c == $stack([expr $i - 1])} {
                    incr i -1
                    if {$i == 0} {
                        set done 1
                        set ok 1
                        break
                    }
                } else break
            }
        }
    }
    if {$done} {
        return [list 1 $p $start]
    }
    return [list 0 $p $start]
}

proc FlashParenRange {fw ok start end} {
    global flashed_range_id valid_match_background invalid_match_background
    if {$ok} {
        set bg $valid_match_background
    } else {
        set bg $invalid_match_background
    }
    RemoveTaggedRange $fw flashed_range
    $fw tag configure flashed_range -background $bg
    $fw tag add flashed_range $start "$start + 1 chars" "$end - 1 chars" $end
    after cancel $flashed_range_id
    set flashed_range_id [after 1000 [list RemoveTaggedRange $fw flashed_range]]
}

proc ExecButtonRelease {} {
    global b1_down b2_abort b2_with_arg cut_unmodified
    set fw [GetFocusWidget]
    if {$b2_abort} {
        set b2_abort 0
        return
    }
    if {$b1_down} {
        if {$fw == ".t" && [.t edit modified] == 0} {
            lassign [.t tag ranges sel] cut_unmodified
        }
        tk_textCut $fw
        return
    }
    Execute $fw $b2_with_arg
    set b2_with_arg ""
    RecordPosition
}

proc ExecButtonPress {fw x y} {
    global b2_down b2_abort b2_start
    set b2_down 1
    set b2_abort 0
    set b2_start ""
    if {![catch [list $fw index "@$x,$y"] result]} {
        set b2_start $result
    }
}

proc UpdateSelectionOnClick {fw} {
    # drop selection, unless click is inside it
    if {[lsearch -exact [$fw tag names current] sel] == -1} {
        RemoveSelection $fw
    }
}

proc MangleFilename {fname} {
    set new ""
    set len [string length $fname]
    for {set i 0} {$i < $len} {incr i} {
        set c [string index $fname $i]
        if {![string is alnum -strict $c] && [string first $c "_-."] == -1} {
            scan $c %c u
            append new "%[format %02x $u]"
        } else {
            append new $c
        }
    }
    return $new
}
 
text .tag -wrap char -undo 1 -height 1
canvas .s -width $sbar_width
text .t -wrap $wrap_mode -undo 1 -yscrollcommand Scrolling
pack .tag -side top -fill x
pack .s -fill y -side left
pack .t -fill both -expand 1
set sbar [.s create rectangle 0 0 0 0]
wm protocol . WM_DELETE_WINDOW Terminate

# key events
DefineKey <KeyPress> {TakeFocus; set cut_unmodified ""}
DefineKey <Control-plus> { 
    global current_font
    lassign $current_font _ size
    ResizeFont [expr $size + 1]
}
DefineKey <Control-minus> { 
    global current_font
    lassign $current_font _ size
    ResizeFont [expr $size - 1]
}
DefineKey <Control-c> { tk_textCopy [GetFocusWidget]; break }
DefineKey <Control-x> { tk_textCut [GetFocusWidget]; break }
DefineKey <Control-v> { PasteSelection [GetFocusWidget]; break }
DefineKey <Delete> { KillExecuting SIGINT; break }
DefineKey <Control-f> { FilenameCompletion; break }
DefineKey <Insert> { FilenameCompletion; break }
DefineKey <Return> {
    TakeFocus
    set fw [GetFocusWidget]
    if {$fw == ".t" && $current_translation == "crnl"} {
        if {[.t get "insert - 1 chars"] == "\r"} {
            Insert "\n"
        } else {
            Insert "\r\n"
        }
        break
    }
}
DefineKey <Control-s> SaveChanges
DefineKey <Home> { Top; break }
DefineKey <End> { Bottom; break }
DefineKey <Control-u> {
    set fw [GetFocusWidget]
    RemoveSelection $fw
    $fw tag add sel "insert linestart" insert
    tk_textCut $fw
    break
}
DefineKey <Control-k> {
    set fw [GetFocusWidget]
    RemoveSelection $fw
    if {[.t get insert] == "\n"} {
        $fw delete insert "insert + 1 lines linestart"
    } else {
        $fw tag add sel insert "insert lineend"
        tk_textCut $fw
    }
    break
}
DefineKey <Control-w> {
    set fw [GetFocusWidget]
    set i [$fw search -regexp -backwards {\m\w*} insert 1.0]
    if {$i != ""} {
        RemoveSelection $fw
        $fw tag add sel $i insert
        tk_textCut $fw
    }
    break
}
DefineKey <Tab> { SmartIndent; break }
DefineKey <Control-Tab> { Insert "\t"; break }
DefineKey <Control-KeyPress-1> {
    if {[GetFocusWidget] == ".t"} {
        focus .tag
    } else {focus .t}
}
DefineKey <Control-KeyPress-2> {
    set fw [GetFocusWidget]
    set rng [GetEffectiveSelection $fw]
    if {$rng != ""} {
        RemoveSelection $fw
        eval SetTaggedRange $fw b2sweep $rng
        Execute $fw
    } else {
        set ixs [GetWordUnderIndex $fw insert]
        if {$ixs != ""} {
            eval SetTaggedRange $fw b2sweep $ixs
            Execute $fw
        }
    }
}
DefineKey <Control-KeyPress-3> {
    set fw [GetFocusWidget]
    set rng [GetEffectiveSelection $fw]
    if {$rng != ""} {
        RemoveSelection $fw
        eval SetTaggedRange [GetFocusWidget] b3sweep $rng
        Acquire
    } else {
        set ixs [GetWordUnderIndex $fw insert]
        if {$ixs != ""} {
            eval SetTaggedRange $fw b3sweep $ixs
            Acquire
        }
    }
}
DefineKey <KeyRelease> {
    if {[lsearch {parenright bracketright braceright} "%K"] != -1} {
        set fw [GetFocusWidget]
        set result [MatchDelimitedBackwards [$fw index insert] $fw]
        eval FlashParenRange $fw $result
    }
}
bind .t <Prior> {
    ScrollUp [expr int([winfo height .t] * 0.8)]
    break
}
bind .t <Next> {
    ScrollDown [expr int([winfo height .t] * 0.8)]
    break
}
bind .tag <KeyRelease> { 
    set old [.tag cget -height]
    set new [.tag count -displaylines 1.0 end]
    if {$old != $new} {
        .tag configure -height $new
    }
    .tag see 1.0
    set last_del_attempt 0
}
DefineKey <Escape> {
    set fw [GetFocusWidget]
    set sel [$fw tag ranges sel]
    if {$sel != ""} {
        tk_textCut $fw
    } else {
        $fw tag add sel $last_mouse_index insert
    }
}

# mouse events
DefineKey <Double-ButtonPress-1> {
    set b1_down 1
    set fw [GetFocusWidget]
    TakeFocus
    if {![catch [list $fw index "@%x,%y"] ind]} {
        set c [$fw get $ind]
        if {[string first $c "\{(\[\"'"] != -1} {
            set result [MatchDelimitedForward $ind $fw]
            if {[lindex $result 0]} {
                RemoveSelection $fw
                $fw tag add sel "[lindex $result 1] + 1 chars" "[lindex $result 2] - 1 chars"
                $fw mark set insert "[lindex $result 1] + 1 chars"
                break
            }
        } elseif {[string first $c "\})\]"] != -1} {
            set result [MatchDelimitedBackwards "$ind + 1 chars" $fw]
        
            if {[lindex $result 0]} {
                RemoveSelection $fw
                $fw tag add sel "[lindex $result 1] + 1 chars" "[lindex $result 2] - 1 chars"
                $fw mark set insert "[lindex $result 2] - 1 chars"
                break
            }
        }
        if {[regexp {\.0$} $ind]} {
            RemoveSelection $fw
            lassign [$fw dlineinfo $ind] _ _ w
            if {$w == "" || $w == 0} break
            $fw tag add sel $ind "$ind lineend + 1 chars"
            break
        } else {
            lassign [$fw dlineinfo "@%x,%y"] px _ pw
            if {$pw == "" || $pw == 0} break
            if {%x > [expr $px + $pw]} {
                set p [$fw index "@%x,%y"]
                $fw tag add sel "$p linestart" "$p lineend + 1 chars"
                break
            }
        }
    }
}
DefineKey <ButtonPress-1> {
    set b1_down 1
    set fw [GetFocusWidget]
    TakeFocus
    if {$b2_down} {
        set fw .t
        set range [GetEffectiveSelection .t]
        if {$range == ""} {     
            set fw .tag
            set range [GetEffectiveSelection .tag]
        }
        if {$range != ""} {
            set txt [$fw get [lindex $range 0] [lindex $range 1]]
            set b2_with_arg [regsub -all {\s+} $txt " "]
            break
        }
    } else {
        RemovePseudoSelection %W
    }
}
DefineKey <ButtonRelease-1> {
    set b1_down 0
    RecordPosition
}
DefineKey <ButtonPress-2> {
    ExecButtonPress %W %x %y
}
DefineKey <ButtonRelease-2> {
    set b2_down 0
    if {$b3_down} {
        set b3_abort 1
        RemoveTaggedRange %W b3sweep
    } else {
        ExecButtonRelease
    }
    break
}
DefineKey <Shift-ButtonPress-3> {
    UpdateSelectionOnClick %W
    ExecButtonPress %W %x %y
}
DefineKey <Shift-ButtonRelease-3> {
    set b2_down 0
    ExecButtonRelease
    break
}
DefineKey <ButtonPress-3> {
    UpdateSelectionOnClick %W
    set b3_down 1
    set b3_start ""
    if {![catch {%W index "@%x,%y"} result]} {
        set b3_start $result
    }
}
DefineKey <ButtonRelease-3> {
    set b3_down 0
    RecordPosition
    if {$b1_down} {
        set fw [GetFocusWidget]
        set p [$fw index insert]
        PasteSelection $fw
        RemoveTaggedRange %W b3sweep
        if {$fw == ".t" && $p == $cut_unmodified} {
            Unmodified
        }
        break
    }
    if {$b2_down} {
        set b2_abort 1
        set b2_start ""
        RemoveTaggedRange %W b2sweep
        RemoveTaggedRange %W b3sweep
        break
    }
    if {!$b3_abort} {
        Acquire
    } else {
        set b3_abort 0
    }
    break
}
bind .s <ButtonPress-1> { ScrollUp %y 1 }
bind .s <ButtonRelease-1> EndScrolling
bind .s <ButtonPress-2> { set b2_down 1; ScrollTo %y }
bind .s <ButtonRelease-2> { set b2_down 0 }
bind .s <Shift-ButtonPress-3> { set b2_down 1; ScrollTo %y }
bind .s <Shift-ButtonRelease-3> { set b2_down 0 }
bind .s <ButtonPress-3> { ScrollDown %y 1 }
bind .s <ButtonRelease-3> EndScrolling
bind .s <Motion> {
    if {$b2_down} {
        ScrollTo %y
    }
}
DefineKey <Motion> {
    if {$b2_down} {
        set p "@%x,%y"
        if {![catch [list %W index $p] result]} {
            if {$b2_start != "" && $b2_start != $result} {
                SetTaggedRange %W b2sweep $b2_start $result
            }
        }
        break
    } elseif {$b3_down} {
        set p "@%x,%y"
        if {![catch [list %W index $p] result]} {
            if {$b3_start != "" && $b3_start != $result} {
                SetTaggedRange %W b3sweep $b3_start $result
            }
        }
        break
    }
}
DefineKey <<Selection>> { 
    global pseudosel_on
    set fw %W
    if {$pseudosel_on($fw)} {
        set sel [$fw tag ranges sel]
        if {$sel != ""} { 
            RemovePseudoSelection $fw
        }
    }
}
DefineKey <Enter> { RestoreSelection %W }
DefineKey <Leave> { SaveSelection %W }
bind .t <<Modified>> { 
    set f [.t edit modified]
    set last_del_attempt 0
    if {$editable} {
        MarkDirty $f
        UpdateCommand Put
    }
}

proc RelayoutTag {} {
    set lines [.tag count -displaylines 1.0 end]
    set p [.t index insert]
    .tag configure -height $lines
    .t see $p
}

bind .tag <Configure> {
    RelayoutTag
    ScrollToBottom
}
set mapped 0
# not sure about this one
bind .t <Map> {
    if {!$withdrawn && !$mapped} {
        WarpToIndex .t 1.0
    }
    set mapped 1
}

# initialization
if {[file exists $rcfile]} { source $rcfile }
set post_eval ""
for {set i 0} {$i < $argc} {incr i} {
    set arg [lindex $argv $i]
    switch -- $arg {
        "-cd" {
            incr i
            cd [lindex $argv $i]
        }
        "-eval" { 
            incr i
            eval [lindex $argv $i]
        }
        "-execute" {
            incr i
            source [lindex $argv $i]
        }
        "-post-eval" {
            incr i
            lappend post_eval [lindex $argv $i]
        }
        "-stdin" {
            .t insert 1.0 [read stdin]
        }
        "-directory" {
            incr i
            lappend post_eval [list OpenDirectory [lindex $argv $i]]
        }
        "-address" {
            incr i
            set dest_address [lindex $argv $i]
        }
        "-fixed" {
            ToggleFont fix
        }
        "-tag" {
            incr i
            set initial_tag [lindex $argv $i]
        }
        "-withdrawn" {set withdrawn 1}
        "-registry" StartRegistry
        "-scroll" ToggleScroll
        "-temporary" {set editable 0}
        "-win" {
            incr i

            if {$i >= $argc} {
                set cmd "$shell $interactive_shell_args"
            } else {              
                set cmd [lrange $argv $i [llength $argv]]
            }

            set name [file rootname [file tail [lindex $cmd 0]]]
            set dir [pwd]
            set initial_tag "$dir/-$name New Kill Del Cut Paste Snarf Send Look Font Scroll | "
            lappend post_eval [list EnterWinMode $cmd]
            set i $argc
            set editable 0
        }
        "--" {}
        default { 
            set current_filename [CanonicalFilename [lindex $argv $i]]
        }
    }
}
ConfigureWindow 0
if {$initial_tag != ""} {
    SetTag $initial_tag
}
if {$current_filename != ""} { 
    set current_filename [FollowLink $current_filename]
    if {[file exists $current_filename]} {
        if {[file type $current_filename] == "directory"} {
            OpenDirectory $current_filename
        } else {
            OpenFile $current_filename
        }
    }
} else {
    set unnamed 1
}
if {$dest_address != ""} {
    GotoBodyAddress $dest_address
} else {
    .t mark set insert 1.0
}
if {$withdrawn} {
    wm withdraw .
}
RelayoutTag
if {$post_eval != ""} {
    foreach cmd $post_eval {
        eval $cmd
    }
}

if {[file exists ".tag"]} {
    set fp [open ".tag" r]
    .tag insert end "\n[read $fp]"
    close $fp
}

set env(MA_LABEL) $current_filename
TakeFocus
