import os
import re


def read_scss(file_path):
    """Reads an SCSS file and returns a dictionary of color variables."""
    colors = {}
    with open(file_path, "r") as file:
        for line in file:
            match = re.match(r"\$(\w+):\s*(#[0-9A-Fa-f]{6});", line.strip())
            if match:
                variable_name, color = match.groups()
                colors[variable_name] = color
    return colors


def update_svg_colors(svg_path, old_to_new_colors, output_path):
    """
    Updates the colors in an SVG file based on the provided color map.

    :param svg_path: Path to the SVG file.
    :param old_to_new_colors: Dictionary mapping old colors to new colors.
    :param output_path: Path to save the updated SVG file.
    """
    
    with open(svg_path, "r") as file:
        svg_content = file.read()

    
    for old_color, new_color in old_to_new_colors.items():
        svg_content = re.sub(old_color, new_color, svg_content, flags=re.IGNORECASE)

    
    with open(output_path, "w") as file:
        file.write(svg_content)

    print(f"SVG colors have been updated and saved to {output_path}!")


def main():
    xdg_config_home = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
    xdg_state_home = os.environ.get(
        "XDG_STATE_HOME", os.path.expanduser("~/.local/state")
    )

    scss_file = os.path.join(
        xdg_state_home, "noon", "user", "generated", "material_colors.scss"
    )
    svg_path = os.path.join(xdg_config_home, "Kvantum", "Colloid", "ColloidDark.svg")
    output_path = os.path.join(
        xdg_config_home, "Kvantum", "MaterialAdw", "MaterialAdw.svg"
    )

    
    color_data = read_scss(scss_file)

    
    old_to_new_colors = {
        
        
        "#31363b": color_data["background"],
        
        "#000000": color_data["shadow"],
        "#5b9bf8": color_data["primary"],
        "#93cee9": color_data["onSecondaryContainer"],
        "#3daee9": color_data["secondary"],
        
        
        
        "#ffffff": color_data["term11"],
        "#5a616e": color_data["surfaceVariant"],
        "#f04a50": color_data["error"],
        "#4285f4": color_data["secondary"],
        "#242424": color_data["background"],
        "#2c2c2c": color_data["background"],
        
        
        
        
        "#1e1e1e": color_data["background"],
        "#3c3c3c": color_data["background"],
        "#26272a": color_data["surfaceBright"],
        "#000000": color_data["shadow"],
        "#b74aff": color_data["tertiary"],
        
        "#1a1a1a": color_data["background"],
        "#333": color_data["term0"],
        "#212121": color_data["background"],
    }

    
    update_svg_colors(svg_path, old_to_new_colors, output_path)


if __name__ == "__main__":
    main()
