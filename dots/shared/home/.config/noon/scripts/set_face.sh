#!/bin/bash


selected_file=$(kdialog --getopenfilename "$HOME" "Image Files (*.png *.jpg *.jpeg *.gif *.bmp *.svg)|All Files (*)")


if [ -z "$selected_file" ]; then
    kdialog --error "No file selected. Exiting."
    exit 1
fi


if [ ! -f "$selected_file" ]; then
    kdialog --error "Selected file does not exist: $selected_file"
    exit 1
fi


face_path="$HOME/.face.icon"


if [ -e "$face_path" ] || [ -L "$face_path" ]; then
    rm "$face_path"
fi


ln -sf "$selected_file" "$HOME/.face.icon"
ln -sf "$selected_file" "$HOME/.face"


if [ -L "$face_path" ]; then
    kdialog --msgbox "Face icon set successfully!\n\nLinked: $selected_file\nTo: $face_path"
else
    kdialog --error "Failed to create symlink."
    exit 1
fi
