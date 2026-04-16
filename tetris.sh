#!/bin/bash


##########
# CONFIG #
##########

GRID_WIDTH=10
GRID_HEIGHT=20
GRID_LENGTH=$((GRID_WIDTH * GRID_HEIGHT ))
GRID_OFFSET_X=26
GRID_OFFSET_Y=9


###########
# GLOBALS #
###########

curr_game_state=0
prev_game_state=-1
sleep_time=0.03     # ~30 FPS
fall_every_n_frames=10
fall_block_counter=0

curr_block_id=-1
next_block_id=-1
curr_block_rotation=0
curr_block_x=$((GRID_WIDTH / 2))
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
block_o_color='\x1b[38;2;255;255;0m'  # yellow
block_i_color='\x1b[38;2;0;255;255m'  # light blue
block_s_color='\x1b[38;2;255;0;0m'    # red
block_z_color='\x1b[38;2;0;255;0m'    # green
block_l_color='\x1b[38;2;255;128;0m'  # orange
block_j_color='\x1b[38;2;0;0;255m'    # dark blue
block_t_color='\x1b[38;2;255;0;255m'  # purple

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

delete_grid_cell_color() {
    if [ "$#" -ne 2 ]; then
        echo "Expected x and y!"
        return 1
    fi
    
    local x=$1 y=$2
    
    tput cup "$y" "$x"
    
    echo -en "  "
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

print_color_code() {
    if [ "$#" -ne 1 ]; then
        echo "Expected block ID!"
        return 1
    fi
    
    case "$1" in
        "1") echo -en "$block_o_color" ;;
        "2") echo -en "$block_i_color" ;;
        "3") echo -en "$block_s_color" ;;
        "4") echo -en "$block_z_color" ;;
        "5") echo -en "$block_l_color" ;;
        "6") echo -en "$block_j_color" ;;
        "7") echo -en "$block_t_color" ;;
        *) ;;
    esac
}

# Directly works with the global curr and prev grid
print_grid_differences() {
    for i in "${!curr_grid[@]}"; do
        # If element is not the same as in the prev_grid, print it
        if [ "${curr_grid[$i]}" != "${prev_grid[$i]}" ]; then
            # get x and y
            read x y <<< "$(get_x_y_from_value "$i")"

            # move cursor: tput cup expects row (y), col (x)
            tput cup "$y" "$x"

            print_color_code "${curr_grid[$i]}"
            echo -en "██"
            echo -en "$ANSI_RESET"
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
    ║                      (S)tart game                            ║
    ║                      (Q)uit                                  ║
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

    # If coming from another screen, redraw the whole screen
    if [ "$prev_game_state" -ne 1 ]; then
        prev_game_state=$curr_game_state
        prev_grid=()

        clear
        print_initial_game_screen
    fi

    # Get user inputs for moving and rotating block
    case "$1" in
        $'\x1b[D')   # Move left (Left arrow)
            if (( curr_block_x <= 0 )); then
                return 0
            fi
        
            (( curr_block_x-- ))
            ;;
        $'\x1b[C')   # Move right (Right arrow)
            if (( curr_block_x >= GRID_WIDTH-1 )); then
                return 0
            fi
        
            (( curr_block_x++ ))
            ;;
        " ") ;;         # Fast drop (Space)
        $'\x1b[B')
            if (( curr_block_y >= GRID_HEIGHT-1 )); then
                return 0
            fi
            
            (( curr_block_y++ ))
            ;;
        $'\x1b[A') ;;  # Hold block (Up arrow)
        "x") ;;         # Rotate block left
        "c") ;;         # Rotate block right
        *) ;;
    esac
    
    # Update block fall frame counter
    fall_block_counter=$(( fall_block_counter + 1 ))
    
    if (( fall_block_counter % fall_every_n_frames == 0 )); then
        curr_block_y=$(( curr_block_y + 1 ))
        fall_block_counter=0
        
        if (( curr_block_y >= GRID_HEIGHT )); then
            curr_block_x=$((GRID_WIDTH / 2))
            curr_block_y=0
            prev_block_x=$curr_block_x
            prev_block_y=$curr_block_y
            
            # new block
            curr_block_id=$next_block_id
            next_block_id=$(get_random_int_in_range)
        fi
    fi
    
    # Unset prev position if it's different from the current one
    if (( prev_block_x != curr_block_x || prev_block_y != curr_block_y )); then
        local coords=$(( prev_block_y * GRID_WIDTH + prev_block_x ))
        unset curr_grid[coords]
        unset prev_grid[coords]
        delete_grid_cell_color $( get_x_y_from_value "$coords" )
    fi

    # Write block to correct grid cell
    set_grid_cell "$curr_block_id" "$curr_block_x" "$curr_block_y"
    
    # Update grid
    print_grid_differences
    
    # Update block history
    prev_block_x="$curr_block_x"
    prev_block_y="$curr_block_y"
}


# Pause screen
handle_state_2() {
    case "$1" in
        $'\x1b') curr_game_state=1 ;; # Resume game on ESC
        "q") exit 0 ;;  # Quit game
        "r") # Restart game
            curr_game_state=1
            curr_grid=()
            ;;
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
        "r") # Restart game
            curr_game_state=1
            curr_grid=()
            ;;
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
    # echo "${curr_grid[*]}"

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

    # Arrow keys are made from more than one byte
    if [[ $key == $'\x1b' ]]; then
        read -rn1 -t 0.001 k1
        read -rn1 -t 0.001 k2
        key+="$k1$k2"
    fi
done
