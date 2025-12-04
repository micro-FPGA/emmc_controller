# =============================================================================
# Clean Up Script
# eMMC Controller IP - Remove Simulation Artifacts
# =============================================================================
#
# Usage:
#   cd sim/
#   do clean.do
#
# =============================================================================

# -----------------------------------------------------------------------------
# Remove work library
# -----------------------------------------------------------------------------
if {[file exists work]} {
   file delete -force work
   puts "Removed: work/"
}

# -----------------------------------------------------------------------------
# Remove log files
# -----------------------------------------------------------------------------
foreach logfile [glob -nocomplain *.log] {
   file delete -force $logfile
   puts "Removed: $logfile"
}

# -----------------------------------------------------------------------------
# Remove waveform files
# -----------------------------------------------------------------------------
foreach wlffile [glob -nocomplain *.wlf] {
   file delete -force $wlffile
   puts "Removed: $wlffile"
}

foreach wlftfile [glob -nocomplain wlft*] {
   file delete -force $wlftfile
   puts "Removed: $wlftfile"
}

# -----------------------------------------------------------------------------
# Remove transcript
# -----------------------------------------------------------------------------
if {[file exists transcript]} {
   file delete -force transcript
   puts "Removed: transcript"
}

# -----------------------------------------------------------------------------
# Remove QuestaSim output directory
# -----------------------------------------------------------------------------
if {[file exists qrun.out]} {
   file delete -force qrun.out
   puts "Removed: qrun.out/"
}

# -----------------------------------------------------------------------------
# Remove modelsim.ini (local copy)
# -----------------------------------------------------------------------------
if {[file exists modelsim.ini]} {
   file delete -force modelsim.ini
   puts "Removed: modelsim.ini"
}

# -----------------------------------------------------------------------------
# Remove coverage database
# -----------------------------------------------------------------------------
if {[file exists covhtmlreport]} {
   file delete -force covhtmlreport
   puts "Removed: covhtmlreport/"
}

foreach ucdbfile [glob -nocomplain *.ucdb] {
   file delete -force $ucdbfile
   puts "Removed: $ucdbfile"
}

puts ""
puts "Clean up complete."

