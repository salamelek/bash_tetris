#!/bin/bash


##########
# CONFIG #
##########


###########
# GLOBALS #
###########

block_o_id=0
block_i_id=1
block_s_id=2
block_z_id=3
block_l_id=4
block_j_id=5
block_t_id=6

# ESC[38;2;{r};{g};{b}m
block_o_color="\x1b[38;2;{r};{g};{b}m"    # yellow
block_i_color="\x1b[m"    # light blue
block_s_color="\x1b[31m"    # red
block_z_color="\x1b[32m"    # green
block_l_color="\x1b[m"    # orange
block_j_color="\x1b[m"    # dark blue
block_t_color="\x1b[m"    # purple

ANSI_RESET="\x1b[0m"


##################
# PRETTY CONSOLE #
##################
tput smcup                      # Use alternate screen buffer to keep previous stuff in console
tput civis                      # Hide the cursor to not see it
stty -echo -icanon time 0 min 0 # Disable seeing input characters

cleanup() {
    tput rmcup  # Restore screen
    tput cnorm  # Restore cursor
    stty sane   # Restore print on type
}

# Use a trap so even if the program crashes or Ctrl+C is pressed, it still restores defaults
trap cleanup EXIT


#############
# FUNCTIONS #
#############


#############
# MAIN LOOP #
#############
while true; do
    case "$state" in
        0) handle_state_0 "$key" ;; # Welcome screen
        1) handle_state_1 "$key" ;; # Play game screen
        2) handle_state_2 "$key" ;; # Game over screen
        *)                          # Shouldn't happen, but who knows :)
            clear
            echo "Invalid state!"
            exit 1
            ;;
    esac
	
	# -r:   no backslash escape char
	# -n1:  read 1 char
	# -t:   wait x seconds
	read -rn1 -t $sleep_time key
done
