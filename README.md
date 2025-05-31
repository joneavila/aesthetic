<picture>
  <source media="(prefers-color-scheme: dark)" srcset=".github/banner_dark.webp">
  <source media="(prefers-color-scheme: light)" srcset=".github/banner_light.webp">
  <img alt="Project banner" src=".github/banner_light.webp">
</picture>

<div align="center">
  <p>
    A <a href="https://muos.dev">muOS</a> application for creating minimalistic duo-tone themes directly on your handheld.
  </p>
  <p>
    <img src="/.github/preview_animated.webp" width="50%" height="50%" alt="Preview of Aesthetic">
  </p>
  <p>
    <img src="/.github/screenshot_main_menu_screen.png" width="30%" alt="Aesthetic main menu screen">
    <img src="/.github/screenshot_palette_screen.png" width="30%" alt="Aesthetic color palette screen">
    <img src="/.github/screenshot_font_family_screen.png" width="30%" alt="Aesthetic font family screen">
  </p>
</div>

## ✨ Features

- **Theme Customization**
  - **Home Screen Layout**: Choose between grid and list view
  - **Colors**: Customize background and foreground colors using a palette, HSV picker, or hex code
    - **Background**: Set a solid color or two-color gradient
  - **RGB Lighting**: Configure mode (solid, breathing, rainbow, off), with adjustable color, speed, and brightness
  - **Font**: Choose from *Inter*, *Montserrat*, *Nunito*, *JetBrains Mono*, *Cascadia Code*, *Retro Pixel*, or *Bitter* — supporting clean, rounded, monospaced, serif, and pixelated styles
  - **Icons**: Enable or disable list glyphs
  - **Header, Navigation, Status, Time**: Independently adjust alignment and transparency (alpha) for each section
- **Theme Management**
  - **Name and Export**: Save your theme directly to your theme collection
  - **Apply**: Automatically apply your theme before exiting to instantly see your creation
  - **Auto-Restore**: Remembers your last theme configuration for easy adjustments when you return
  - **Presets**: Save and load theme presets with 8 built-in presets – *Win95*, *Purple Noir*, *Terminal*, *Vaporwave*, *Orange Cream*, *DMG*, *Fami*, *Bumblebee*
  - **Manage Installed Themes**: Delete themes you no longer need
- **OTA Updates**: Download the latest version directly within the app

## 📦 Installation

> [!IMPORTANT]
> **Aesthethic** is designed for muOS version 2502.0 PIXIE. You can check your muOS version via **_Information_** > **_System Details_**.

1. Download the latest `Aesthetic-x.x.x.muxupd` from [Releases](https://github.com/joneavila/aesthetic/releases).
2. Transfer `Aesthetic-x.x.x.muxupd` to your handheld's `SD1 (mmc)/ARCHIVE` directory.
3. Open **_Applications_** > **_Archive Manager_**.
4. Select **[SD1] Aesthetic-x.x.x.muxupd** to install.
5. Launch the application via **_Applications_** > **_Aesthetic_**.

## ⚙️ Usage

1. From the main menu, select the theme options to customize. Each screen includes helpful control hints at the bottom.
2. Select "Create theme" to save your theme to your device's collection.
3. Apply your theme automatically, or apply it manually later via **_Configuration_** > **_Customisation_** > **_muOS Themes_**.

## 🛠️ Contributing

Want to improve **Aesthetic**?

- If you've found a bug or have a suggestion or question, [open an issue](https://github.com/joneavila/aesthetic/issues/new) or join the discussion on the [dedicated thread in the muOS community forum](https://community.muos.dev/t/aesthetic-create-themes-directly-on-your-handheld).
- To contribute directly, fork the repo and [submit a pull request](https://github.com/joneavila/aesthetic/compare).
- Check out the [wiki for the development guide](https://github.com/joneavila/aesthetic/wiki).

## 🚀 Local Development (macOS, Linux)

To run Aesthetic on your development machine:

1. Install [LÖVE](https://love2d.org/)
1. Clone this repository: `git clone https://github.com/joneavila/aesthetic.git`
1. Make the development launch script executable: `chmod +x dev_launch.sh`
1. Run the script to launch Aesthetic: `./dev_launch.sh`

The launch script automatically sets up the necessary environment variables that would normally be provided by muOS. Output is logged to console and to a new `.dev/logs` directory.

## ❤️ Support

You can support this project by starring the repo, sharing it with others, showcasing it in a video, or donating via Ko-fi. Any support is greatly appreciated – thank you for supporting open source software!

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/F1F51COHHT)

Looking for more muOS community apps? Check out: [**RomM**](https://github.com/rommapp/muos-app) (connect to self-hosted ROM manager), [**Scrappy**](https://github.com/gabrielfvale/scrappy) (art scraper), [**Bluetooth App**](https://github.com/nvcuong1312/bltMuos) (Bluetooth settings), [**RGB Controller**](https://github.com/JanTrueno) (RGB lighting settings).

## 🗺️ Roadmap

- [x] Remember most recent theme settings
- [x] Customize theme font size
- [x] Limit theme content width in content screens
- [ ] Save, load presets

## ⭐ Credits

- [**Bitter**](https://fonts.google.com/specimen/Bitter) • Font • [OFL-1.1](assets/fonts/bitter/OFL.txt)
- [**Cascadia Code**](https://github.com/microsoft/cascadia-code/) • Font • [OFL-1.1](assets/fonts/cascadia_code/LICENSE)
- [**Catppuccin Palettes**](https://github.com/catppuccin/palette) • Color palette • [MIT](https://github.com/catppuccin/palette/blob/main/LICENSE)
- [**Inter**](https://github.com/rsms/inter) • Font • [OFL-1.1](assets/fonts/inter/OFL.txt)
- [**LÖVE**](https://github.com/love2d/love) • Game framework • [ZLIB](bin/LICENSE.txt)
- [**Lucide Icons**](https://github.com/lucide-icons/lucide) • Icons • [ISC](https://github.com/lucide-icons/lucide/blob/main/LICENSE)
- [**Material Icons**](https://github.com/google/material-design-icons) • Icons • [Apache 2.0](https://github.com/google/material-design-icons/blob/master/LICENSE)
- [**MinUI**](https://github.com/shauninman/MinUI) • Inspiration (design) • No license provided
- [**MinUIfied Theme Generator**](https://github.com/hmcneill46/muOS-MinUIfied-Theme-Generator) • Inspiration (application), reference for default theme • [MIT](https://github.com/hmcneill46/muOS-MinUIfied-Theme-Generator/blob/master/LICENSE)
- [**Montserrat**](https://github.com/googlefonts/montserrat) • Font • [OFL-1.1](assets/fonts/montserrat/OFL.txt)
- [**Nunito**](https://github.com/googlefonts/nunito) • Font • [OFL-1.1](assets/fonts/nunito/OFL.txt)
- [**Retro Pixel Font**](https://github.com/TakWolf/retro-pixel-font) • Font • [OFL-1.1](assets/fonts/retro_pixel/LICENSE)
- [**TÖVE**](https://github.com/poke1024/tove2d) • LÖVE library • [MIT](src/tove/LICENSE)
- [**tween.lua**](https://github.com/kikito/tween.lua) • Tweening library • [MIT](https://github.com/kikito/tween.lua/blob/master/LICENSE.txt)

## ⚖️ License

This project is licensed under the MIT License. You are free to use, modify, and distribute this software, provided that you include the original copyright notice and a disclaimer of liability. For more details, see [LICENSE](LICENSE).
