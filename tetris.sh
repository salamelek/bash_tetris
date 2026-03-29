#!/bin/bash


##########
# CONFIG #
##########


###########
# GLOBALS #
###########

curr_game_state=0
prev_game_state=-1
sleep_time=0.033     # ~30 FPS

curr_block_id=-1
curr_block_rotation=0
prev_block_rotation=0   # Needed for selective redrawing of pixels
curr_block_x=0
curr_block_y=0
prev_block_x=0
prev_block_y=0

block_o_id=0
block_i_id=1
block_s_id=2
block_z_id=3
block_l_id=4
block_j_id=5
block_t_id=6

# \x1b[38;2;{r};{g};{b}m
block_o_color='\x1b[38;2;{255};{255};{0}m'  # yellow
block_i_color='\x1b[38;2;{0};{255};{255}m'  # light blue
block_s_color='\x1b[38;2;{255};{0};{0}m'    # red
block_z_color='\x1b[38;2;{0};{255};{0}m'    # green
block_l_color='\x1b[38;2;{255};{128};{0}m'  # orange
block_j_color='\x1b[38;2;{0};{0};{255}m'    # dark blue
block_t_color='\x1b[38;2;{255};{0};{255}m'  # purple

ANSI_RESET='\x1b[0m'


##################
# PRETTY CONSOLE #
##################
#tput smcup                      # Use alternate screen buffer to keep previous stuff in console
tput civis                      # Hide the cursor to not see it
stty -echo -icanon time 0 min 0 # Disable seeing input characters

cleanup() {
    #tput rmcup  # Restore screen
    tput cnorm  # Restore cursor
    stty sane   # Restore print on type
}

# Use a trap so even if the program crashes or Ctrl+C is pressed, it still restores defaults
trap cleanup EXIT


#############
# FUNCTIONS #
#############

print_initial_game_screen() {
    clear

    cat <<EOF
    ╔══════════════════════════════════════════════════════════════╗
    ║  _____      _____      _____      ____       ___      ____   ║
    ║ |_   _|    | ____|    |_   _|    |  _ \     |_ _|    / ___|  ║
    ║   | |      |  _|        | |      | |_) |     | |     \___ \  ║
    ║   | |      | |___       | |      |  _ <      | |      ___) | ║
    ║   |_|      |_____|      |_|      |_| \_\    |___|    |____/  ║
    ║                                                              ║
    ╠══════════════════════════════════════════════════════════════╣
    ║                    ┏━━━━━━━━━━━━━━━━━━━┓                     ║
    ║                    ┃                   ┃                     ║
    ║                    ┃                   ┃                     ║
    ║                    ┃                   ┃                     ║
    ║                    ┃                   ┃                     ║
    ║                    ┃                   ┃                     ║
    ║                    ┃                   ┃                     ║
    ║                    ┃                   ┃                     ║
    ║                    ┃                   ┃                     ║
    ║                    ┃                   ┃                     ║
    ║                    ┃                   ┃                     ║
    ║                    ┃                   ┃                     ║
    ║                    ┃                   ┃                     ║
    ║                    ┃                   ┃                     ║
    ║                    ┃                   ┃                     ║
    ║                    ┃                   ┃                     ║
    ║                    ┃                   ┃                     ║
    ║                    ┃                   ┃                     ║
    ║                    ┃                   ┃                     ║
    ║                    ┃                   ┃                     ║
    ║                    ┃                   ┃                     ║
    ║                    ┗━━━━━━━━━━━━━━━━━━━┛                     ║
    ╚══════════════════════════════════════════════════════════════╝
EOF
}


# Welcome screen
handle_state_0() {
    case "$1" in
        "q") exit 0 ;;  # Quit game
        "s") curr_game_state=1 ;; # Start game
        *) ;;
    esac

    if [ "$prev_game_state" -ne 0 ]; then
        prev_game_state=$curr_game_state

        clear
        cat <<EOF
        ╔══════════════════════════════════════════════════════════════╗
        ║ __        _______ _     ____ ___  __  __ _____   _____ ___   ║
        ║ \ \      / / ____| |   / ___/ _ \|  \/  | ____| |_   _/ _ \  ║
        ║  \ \ /\ / /|  _| | |  | |  | | | | |\/| |  _|     | || | | | ║
        ║   \ V  V / | |___| |__| |__| |_| | |  | | |___    | || |_| | ║
        ║    \_/\_/  |_____|_____\____\___/|_|  |_|_____|   |_| \___/  ║
        ║                                                              ║
        ║  _____      _____      _____      ____       ___      ____   ║
        ║ |_   _|    | ____|    |_   _|    |  _ \     |_ _|    / ___|  ║
        ║   | |      |  _|        | |      | |_) |     | |     \___ \  ║
        ║   | |      | |___       | |      |  _ <      | |      ___) | ║
        ║   |_|      |_____|      |_|      |_| \_\    |___|    |____/  ║
        ║                                                              ║
        ║                                                              ║
        ║                                                              ║
        ║                                                              ║
        ║                                                              ║
        ║                     (S) Start game                           ║
        ║                     (Q) Quit                                 ║
        ╚══════════════════════════════════════════════════════════════╝
EOF
    fi
}


# Play game screen
handle_state_1() {
    case "$1" in
        $'\x1b') curr_game_state=2 ;; # Pause game on ESC
        *) ;;
    esac

    if [ "$prev_game_state" -ne 1 ]; then
        prev_game_state=$curr_game_state

        clear
        print_initial_game_screen
    fi

    # Get user inputs for moving and rotating block
    case "$1" in
        $'\x1b[D') ;;   # Move left (Left arrow)
        $'\x1b[C') ;;   # Move right (Right arrow)
        " ") ;;         # Fast drop (Space)
        $'\x1b[B') ;;   # Slow drop (Down arrow)
        $'\x1b[A') ;;   # Hold block (Up arrow)
        "x") ;;         # Rotate block left
        "c") ;;         # Rotate block right
        *) ;;
    esac

    # spawn block (take next if exists, otherwise generate new one)
    # spawn next block
    # Move block
}


# Pause screen
handle_state_2() {
    case "$1" in
        $'\x1b') curr_game_state=1 ;; # Resume game on ESC
        "q") exit 0 ;;  # Quit game
        "r") curr_game_state=1 ;; # Restart game
        *) ;;
    esac

    if [ "$prev_game_state" -ne 2 ]; then
        prev_game_state=$curr_game_state

        clear
        echo "paused"
        echo "(ESC) Resume, (R) Restart, (Q) Quit"
    fi
}


# Game over screen
handle_state_3() {
    case "$1" in
        "q") exit 0 ;;  # Quit game
        "r") curr_game_state=1 ;; # Restart game
        *) ;;
    esac

    if [ "$prev_game_state" -eq 3 ]; then
        prev_game_state=$curr_game_state

        clear
        echo "game over"
        echo "(R) Restart, (Q) Quit"
    fi

}


#############
# MAIN LOOP #
#############

while true; do
    case "$curr_game_state" in
        0) handle_state_0 "$key" ;; # Welcome screen
        1) handle_state_1 "$key" ;; # Play game screen
        2) handle_state_2 "$key" ;; # Pause screen
        3) handle_state_3 "$key" ;; # Game over screen
        *)                          # Shouldn't happen, but who knows :)
            clear
            curr_game_state=0
            ;;
    esac
	
	# -r:   no backslash escape char
	# -n1:  read 1 char
	# -t:   wait x seconds
	read -rn1 -t $sleep_time key
done
