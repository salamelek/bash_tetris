#!/bin/bash


##########
# CONFIG #
##########

GRID_WIDTH=10
GRID_HEIGHT=20
GRID_LENGTH=$((GRID_WIDTH * GRID_HEIGHT))
GRID_OFFSET_X=26
GRID_OFFSET_Y=9


###########
# GLOBALS #
###########

curr_game_state=0
prev_game_state=-1
sleep_time=0.033     # ~30 FPS

curr_block_id=-1
next_block_id=-1
curr_block_rotation=0
curr_block_x=0
curr_block_y=0

# id: 0 is empty air
block_o_id=1
block_i_id=2
block_s_id=3
block_z_id=4
block_l_id=5
block_j_id=6
block_t_id=7

# \x1b[38;2;{r};{g};{b}m
block_o_color='\x1b[38;2;{255};{255};{0}m'  # yellow
block_i_color='\x1b[38;2;{0};{255};{255}m'  # light blue
block_s_color='\x1b[38;2;{255};{0};{0}m'    # red
block_z_color='\x1b[38;2;{0};{255};{0}m'    # green
block_l_color='\x1b[38;2;{255};{128};{0}m'  # orange
block_j_color='\x1b[38;2;{0};{0};{255}m'    # dark blue
block_t_color='\x1b[38;2;{255};{0};{255}m'  # purple

ANSI_RESET='\x1b[0m'

# 1D array, gets accessed only by helper functions to avoid fucking things up (It will happen anyways)
# Need also previous grid state so I can know where and what to print (draw)
curr_grid=()
prev_grid=()


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

get_random_int_in_range() {
    if [ "$#" -ne 2 ]; then
        local min=1 max=7
    else
        local min=$1 max=$2
    fi
    
    echo $(( RANDOM % (max - min + 1) + min ))
}

check_bounds() {
    if [ "$#" -ne 2 ]; then
        echo "Expected x and y!"
        return 1
    fi
    
    if (( $1 < 0 || $1 >= GRID_WIDTH || $2 < 0 || $2 >= GRID_HEIGHT )); then
        echo "Coordinates out of bounds!"
        return 1
    fi
    
    return 0
}

# Args: ID, x, y
set_grid_cell() {
    if [ "$#" -ne 3 ]; then
        echo "Expected block ID, x and y!"
        return 1
    fi
    
    local id=$1 x=$2 y=$3
    
    check_bounds x y
    
    local coords=$(( y * GRID_WIDTH + x ))
    
    curr_grid[$coords]="$id"
}

color_grid_cell() {
    if [ "$#" -ne 3 ]; then
        echo "Expected color, x and y!"
        return 1
    fi
    
    local color=$1 x=$2 y=$3
    
    check_bounds x y
    
    
}

get_x_y_from_value() {
    if [ "$#" -ne 1 ]; then
        echo "Expected value to decode!"
        return 1
    fi
    
    local value=$1
    
    x=$(( (value % GRID_WIDTH) * 2 + GRID_OFFSET_X ))
    y=$(( value / GRID_WIDTH + GRID_OFFSET_Y ))
    
    echo "$x $y"
}

# Directly works with the global curr and prev grid
print_grid_differences() {
    # TODO also delete stuff that is not up to date
    
    for i in "${!curr_grid[@]}"; do
        # If element is not the same as in the prev_grid, print it
        if [ "${curr_grid[$i]}" != "${prev_grid[$i]}" ]; then
            # get x and y
            read x y <<< "$(get_x_y_from_value "$i")"

            # move cursor: tput cup expects row (y), col (x)
            tput cup "$y" "$x"

            # -n disables newline
            echo -n "${curr_grid[$i]}${curr_grid[$i]}"
        fi
    done
    
    # Update prev arr
    prev_grid=("${curr_grid[@]}")
}

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
    ║                    ┏━━━━━━━━━━━━━━━━━━━━┓                    ║
    ║    ┏━━━━━━━━━━┓    ┃                    ┃    ┏━━━━━━━━━━┓    ║
    ║    ┃   Hold:  ┃    ┃                    ┃    ┃   Next:  ┃    ║
    ║    ┣━━━━━━━━━━┫    ┃                    ┃    ┣━━━━━━━━━━┫    ║
    ║    ┃          ┃    ┃                    ┃    ┃          ┃    ║
    ║    ┃          ┃    ┃                    ┃    ┃          ┃    ║
    ║    ┃          ┃    ┃                    ┃    ┃          ┃    ║
    ║    ┃          ┃    ┃                    ┃    ┃          ┃    ║
    ║    ┃          ┃    ┃                    ┃    ┃          ┃    ║
    ║    ┃          ┃    ┃                    ┃    ┃          ┃    ║
    ║    ┗━━━━━━━━━━┛    ┃                    ┃    ┗━━━━━━━━━━┛    ║
    ║                    ┃                    ┃                    ║
    ║                    ┃                    ┃                    ║
    ║                    ┃                    ┃                    ║
    ║                    ┃                    ┃                    ║
    ║                    ┃                    ┃                    ║
    ║                    ┃                    ┃                    ║
    ║                    ┃                    ┃                    ║
    ║                    ┃                    ┃                    ║
    ║                    ┃                    ┃                    ║
    ║                    ┃                    ┃                    ║
    ║                    ┗━━━━━━━━━━━━━━━━━━━━┛                    ║
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
    ║                     (S) Start game                           ║
    ║                     (Q) Quit                                 ║
    ║                                                              ║
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
        $'\x1b[D') (( curr_block_x-- )) ;;   # Move left (Left arrow)
        $'\x1b[C') (( curr_block_x++ )) ;;   # Move right (Right arrow)
        " ") ;;         # Fast drop (Space)
        $'\x1b[B') (( curr_block_y++ )) ;;   # Slow drop (Down arrow)
        $'\x1b[A') (( curr_block_y-- )) ;;   # Hold block (Up arrow)
        "x") ;;         # Rotate block left
        "c") ;;         # Rotate block right
        *) ;;
    esac

    # Write block to correct grid cell
    set_grid_cell "$curr_block_id" "$curr_block_x" "$curr_block_y"
    
    # Unset prev position
    # FIXME not working (?)
    local coords=$(( y * GRID_WIDTH + x ))
    unset curr_grid[coords]
    
    # Update grid
    print_grid_differences
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


# Initialise the current and next block
curr_block_id=$(get_random_int_in_range)
next_block_id=$(get_random_int_in_range)

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
	# No s for silent since we already mute console input
	read -rn1 -t "$sleep_time" key

    if [[ $key == $'\x1b' ]]; then
        read -rn1 -t 0.001 k1
        read -rn1 -t 0.001 k2
        key+="$k1$k2"
    fi
done
