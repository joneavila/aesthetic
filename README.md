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
    <img src="/.github/screenshot_font_screen.png" width="30%" alt="Aesthetic font screen">
  </p>
</div>

## ✨ Features

- **Customize** your theme to match your style
  - **Colors**: Select background and foreground colors from palette or create your own using HSV picker or hex input
  - **RGB Lighting**: Configure mode (solid, breathing, rainbow, off), with adjustable color, speed, and brightness where supported
  - **Font**: Select from Inter (clean), Nunito (rounded), Cascadia Code (monospaced), or Retro Pixel (pixelated) with three size options
  - **Icons**: Toggle system glyphs for a minimal or informative interface
- **Export** your theme directly to your theme collection
- **Apply** your theme automatically upon exiting to instantly see your creation
- **Remember** last theme configuration for easy adjustments when you return

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
- Check out the wiki for the development guide.

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

- [**Cascadia Code**](https://github.com/microsoft/cascadia-code/) • Font • [OFL-1.1](assets/fonts/cascadia_code/LICENSE)
- [**Catppuccin Palettes**](https://github.com/catppuccin/palette) • Color palette • [MIT](https://github.com/catppuccin/palette/blob/main/LICENSE)
- [**Inter**](https://github.com/rsms/inter) • Font • [OFL-1.1](assets/fonts/inter/OFL.txt)
- [**LÖVE**](https://github.com/love2d/love) • Game framework • [ZLIB](bin/LICENSE.txt)
- [**Lucide Icons**](https://github.com/lucide-icons/lucide) • Icons • [ISC](https://github.com/lucide-icons/lucide/blob/main/LICENSE)
- [**Material Icons**](https://github.com/google/material-design-icons) • Icons • [Apache 2.0](https://github.com/google/material-design-icons/blob/master/LICENSE)
- [**MinUI**](https://github.com/shauninman/MinUI) • Inspiration (design) • No license provided
- [**MinUIfied Theme Generator**](https://github.com/hmcneill46/muOS-MinUIfied-Theme-Generator) • Inspiration (application), reference for default theme • [MIT](https://github.com/hmcneill46/muOS-MinUIfied-Theme-Generator/blob/master/LICENSE)
- [**Nunito**](https://github.com/googlefonts/nunito) • Font • [OFL-1.1](assets/fonts/nunito/OFL.txt)
- [**Retro Pixel Font**](https://github.com/TakWolf/retro-pixel-font) • Font • [OFL-1.1](assets/fonts/retro_pixel/LICENSE)
- [**TÖVE**](https://github.com/poke1024/tove2d) • LÖVE library • [MIT](src/tove/LICENSE)
- [**tween.lua**](https://github.com/kikito/tween.lua) • Tweening library • [MIT](https://github.com/kikito/tween.lua/blob/master/LICENSE.txt)

## ⚖️ License

This project is licensed under the MIT License. You are free to use, modify, and distribute this software, provided that you include the original copyright notice and a disclaimer of liability. For more details, see [LICENSE](LICENSE).
