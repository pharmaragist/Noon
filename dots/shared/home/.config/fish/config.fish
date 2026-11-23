if status is-interactive
    set fish_greeting
    starship init fish | source
end

if test -f ~/.config/fish/alias.fish
    source ~/.config/fish/alias.fish
end

if test -f ~/.env
    source ~/.env
end

# if test -f ~/.local/state/noon/user/generated/terminal/sequences.txt
#     printf "%b" (cat ~/.local/state/noon/user/generated/terminal/sequences.txt)
# end

if test "$USE_POKEMON" = true
    pokemon-colorscripts --no-title -r
end

# if test -n "$KITTY_WINDOW_ID"; and test -n "$TERMINAL_OPACITY"
#     kitten @ set-background-opacity $TERMINAL_OPACITY
# end

fish_add_path /home/pharmaracist/.spicetify

# opencode
fish_add_path /home/pharmaracist/.opencode/bin

# Hermes Agent command
fish_add_path "$HOME/.local/bin"
