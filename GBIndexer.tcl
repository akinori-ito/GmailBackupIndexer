package require mime
package require base64
package require sqlite3

set GmailBackupFileDir C:/GmailBackup/backup
set IndexDBFile C:/GmailBackup/Index.sqlite3

proc decodeQ {str} {
    set len [string length $str]
    set res {}
    for {set i 0} {$i < $len} {incr i} {
        set c [string index $str $i]
        if {$c eq "="} {
            incr i
            set j [expr $i+1]
            set x [format %c [scan [string range $str $i $j] {%x}]]
            set res "$res$x"
            set i $j
        } else {
            set res "$res$c"
        }
    }
    return $res
}

            

proc decodeSubject {str} {
    set res {}
    foreach w [split $str] {
        if {[regexp {^=\?(.*)\?B\?(.*)\?=$} $w dummy enc body]} {
              set x [::base64::decode $body]
              if {[catch {set res [concat $res [encoding convertfrom [::mime::reversemapencoding $enc] $x]]}]} {
                  set res [concat $res $w]
              }
        } elseif {[regexp {^=\?(.*)\?Q\?(.*)\?=$} $w dummy enc body]} {
              set x [decodeQ $body]
              if {[catch {set res [concat $res [encoding convertfrom [::mime::reversemapencoding $enc] $x]]}]} {
                  set res [concat $res $w]
              }
        } else {
              set res [concat $res $w]
        }
   }
   return $res
}

proc getSubject {file} {
    set f [open $file r]
    set msg [read $f]
    close $f
    if {[catch {set m [::mime::initialize -string $msg]}]} {
        return {}
    }
    if {[catch {set subj [::mime::getheader $m Subject]}]} {
        ::mime::finalize $m
        return {}
    }
    ::mime::finalize $m
    set subj [regsub -all {[{}]} $subj {}]
    
    return [decodeSubject $subj]
}

sqlite3 subjdb $IndexDBFile
set tables [subjdb eval {select name from sqlite_master where type='table'}]
if {[lsearch $tables subject] == -1} {
  subjdb eval {create table subject(subject text, filename text)}
}

cd $GmailBackupFileDir
set files [glob *]
foreach f $files {
#    set subj [getSubject $f]
    set subj [regsub -all {'} [getSubject $f] {''}]
    if {$subj ne {}} {
        if {[catch {subjdb eval "insert into subject values('$subj','$f')"}]} {
           puts "Error: Subject='$subj$ filename='$f'"
        }
    }
#    if {![subjdb exists "select * from subject where filename='$f'"]} {
#        set subj [regsub -all {'} [getSubject $f] {''}]
#        if {$subj ne {}} {
#            if {[catch {subjdb eval "insert into subject values('$subj','$f')"}]} {
#               puts "Error: Subject='$subj$ filename='$f'"
#            }
#        }
#   }
}
subjdb close
