--- Color management module

local colorUtils = require("utils.color")

local colors = {}

-- UI colors (named)
-- Catppuccin Mocha: https://catppuccin.com/palette/
colors.ui = {
	foreground = colorUtils.hexToLove("#cdd6f4"), -- Text
	subtext = colorUtils.hexToLove("#a6adc8"), -- Subtext 0
	background = colorUtils.hexToLove("#1e1e2e"), -- Base
	background_dim = colorUtils.hexToLove("#181825"), -- Mantle
	surface = colorUtils.hexToLove("#313244"), -- Surface 0
	overlay = colorUtils.hexToLove("#6c7086"), -- Overlay 0
	surface_dim = colorUtils.hexToLove("#585b70"), -- Surface 2
	accent = colorUtils.hexToLove("#89b4fa"), -- Blue
	green = colorUtils.hexToLove("#a6e3a1"), -- Green
	red = colorUtils.hexToLove("#f38ba8"), -- Red
	teal = colorUtils.hexToLove("#94e2d5"), -- Teal
	lavender = colorUtils.hexToLove("#b4befe"), -- Lavender
}

-- Palette colors (ordered array)
-- Most colors are adapted from Tailwind colors: https://tailwindcss.com/docs/colors
colors.palette = {

	colorUtils.hexToLove("#ffffff"), -- white
	colorUtils.hexToLove("#cad5e2"), -- gray300
	colorUtils.hexToLove("#90a1b8"), -- gray400
	colorUtils.hexToLove("#61738d"), -- gray500
	colorUtils.hexToLove("#45556c"), -- gray600
	colorUtils.hexToLove("#314157"), -- gray700
	colorUtils.hexToLove("#1c283c"), -- gray800
	colorUtils.hexToLove("#000000"), -- black

	colorUtils.hexToLove("#ffc9c9"), -- red200
	colorUtils.hexToLove("#ffa1a2"), -- red300
	colorUtils.hexToLove("#ff6366"), -- red400
	colorUtils.hexToLove("#fa2b36"), -- red500
	colorUtils.hexToLove("#e7000a"), -- red600
	colorUtils.hexToLove("#c10007"), -- red700
	colorUtils.hexToLove("#9e0711"), -- red800
	colorUtils.hexToLove("#811719"), -- red900

	colorUtils.hexToLove("#ffd6a7"), -- orange200
	colorUtils.hexToLove("#ffb869"), -- orange300
	colorUtils.hexToLove("#ff8803"), -- orange400
	colorUtils.hexToLove("#ff6800"), -- orange500
	colorUtils.hexToLove("#f54900"), -- orange600
	colorUtils.hexToLove("#c93400"), -- orange700
	colorUtils.hexToLove("#9f2d00"), -- orange800
	colorUtils.hexToLove("#7e2a0b"), -- orange900

	colorUtils.hexToLove("#fde585"), -- amber200
	colorUtils.hexToLove("#ffd22f"), -- amber300
	colorUtils.hexToLove("#ffb900"), -- amber400
	colorUtils.hexToLove("#fd9900"), -- amber500
	colorUtils.hexToLove("#e17100"), -- amber600
	colorUtils.hexToLove("#ba4c00"), -- amber700
	colorUtils.hexToLove("#963b00"), -- amber800
	colorUtils.hexToLove("#7a3206"), -- amber900

	colorUtils.hexToLove("#feef85"), -- yellow200
	colorUtils.hexToLove("#ffdf1f"), -- yellow300
	colorUtils.hexToLove("#fdc700"), -- yellow400
	colorUtils.hexToLove("#f0b000"), -- yellow500
	colorUtils.hexToLove("#d08700"), -- yellow600
	colorUtils.hexToLove("#a65f00"), -- yellow700
	colorUtils.hexToLove("#884a00"), -- yellow800
	colorUtils.hexToLove("#723d0a"), -- yellow900

	colorUtils.hexToLove("#d8f998"), -- lime200
	colorUtils.hexToLove("#baf350"), -- lime300
	colorUtils.hexToLove("#99e500"), -- lime400
	colorUtils.hexToLove("#7cce00"), -- lime500
	colorUtils.hexToLove("#5ea500"), -- lime600
	colorUtils.hexToLove("#487d00"), -- lime700
	colorUtils.hexToLove("#3c6200"), -- lime800
	colorUtils.hexToLove("#34530e"), -- lime900

	colorUtils.hexToLove("#b8f7ce"), -- green200
	colorUtils.hexToLove("#7af1a7"), -- green300
	colorUtils.hexToLove("#05df72"), -- green400
	colorUtils.hexToLove("#00c850"), -- green500
	colorUtils.hexToLove("#00a63d"), -- green600
	colorUtils.hexToLove("#008235"), -- green700
	colorUtils.hexToLove("#016630"), -- green800
	colorUtils.hexToLove("#0d532b"), -- green900

	colorUtils.hexToLove("#a4f3cf"), -- emerald200
	colorUtils.hexToLove("#5ee9b4"), -- emerald300
	colorUtils.hexToLove("#00d491"), -- emerald400
	colorUtils.hexToLove("#00bc7c"), -- emerald500
	colorUtils.hexToLove("#009865"), -- emerald600
	colorUtils.hexToLove("#007955"), -- emerald700
	colorUtils.hexToLove("#006044"), -- emerald800
	colorUtils.hexToLove("#004e3a"), -- emerald900

	colorUtils.hexToLove("#95f6e4"), -- teal200
	colorUtils.hexToLove("#46ecd4"), -- teal300
	colorUtils.hexToLove("#00d4bd"), -- teal400
	colorUtils.hexToLove("#00bba6"), -- teal500
	colorUtils.hexToLove("#009688"), -- teal600
	colorUtils.hexToLove("#00776e"), -- teal700
	colorUtils.hexToLove("#005f59"), -- teal800
	colorUtils.hexToLove("#0a4e4a"), -- teal900

	colorUtils.hexToLove("#a2f3fc"), -- cyan200
	colorUtils.hexToLove("#53e9fc"), -- cyan300
	colorUtils.hexToLove("#00d2f2"), -- cyan400
	colorUtils.hexToLove("#00b8da"), -- cyan500
	colorUtils.hexToLove("#0092b8"), -- cyan600
	colorUtils.hexToLove("#007594"), -- cyan700
	colorUtils.hexToLove("#005e78"), -- cyan800
	colorUtils.hexToLove("#104e64"), -- cyan900

	colorUtils.hexToLove("#b8e6fe"), -- sky200
	colorUtils.hexToLove("#73d4ff"), -- sky300
	colorUtils.hexToLove("#00bbff"), -- sky400
	colorUtils.hexToLove("#00a5f4"), -- sky500
	colorUtils.hexToLove("#0084d0"), -- sky600
	colorUtils.hexToLove("#0068a8"), -- sky700
	colorUtils.hexToLove("#005989"), -- sky800
	colorUtils.hexToLove("#014a70"), -- sky900

	colorUtils.hexToLove("#bedaff"), -- blue200
	colorUtils.hexToLove("#8dc5ff"), -- blue300
	colorUtils.hexToLove("#50a2ff"), -- blue400
	colorUtils.hexToLove("#2b7fff"), -- blue500
	colorUtils.hexToLove("#155cfb"), -- blue600
	colorUtils.hexToLove("#1347e5"), -- blue700
	colorUtils.hexToLove("#193bb8"), -- blue800
	colorUtils.hexToLove("#1b388e"), -- blue900

	colorUtils.hexToLove("#c6d1ff"), -- indigo200
	colorUtils.hexToLove("#a3b3ff"), -- indigo300
	colorUtils.hexToLove("#7c86ff"), -- indigo400
	colorUtils.hexToLove("#615eff"), -- indigo500
	colorUtils.hexToLove("#4f39f6"), -- indigo600
	colorUtils.hexToLove("#432dd7"), -- indigo700
	colorUtils.hexToLove("#3629ab"), -- indigo800
	colorUtils.hexToLove("#302c85"), -- indigo900

	colorUtils.hexToLove("#ddd5ff"), -- violet200
	colorUtils.hexToLove("#c4b3ff"), -- violet300
	colorUtils.hexToLove("#a683ff"), -- violet400
	colorUtils.hexToLove("#8d51ff"), -- violet500
	colorUtils.hexToLove("#7f22fd"), -- violet600
	colorUtils.hexToLove("#7008e7"), -- violet700
	colorUtils.hexToLove("#5d0ec0"), -- violet800
	colorUtils.hexToLove("#4d1699"), -- violet900

	colorUtils.hexToLove("#e9d4ff"), -- purple200
	colorUtils.hexToLove("#d9b1ff"), -- purple300
	colorUtils.hexToLove("#c17aff"), -- purple400
	colorUtils.hexToLove("#ac46ff"), -- purple500
	colorUtils.hexToLove("#980ffa"), -- purple600
	colorUtils.hexToLove("#8200da"), -- purple700
	colorUtils.hexToLove("#6d11b0"), -- purple800
	colorUtils.hexToLove("#59168a"), -- purple900

	colorUtils.hexToLove("#f5cfff"), -- fuchsia200
	colorUtils.hexToLove("#f3a7ff"), -- fuchsia300
	colorUtils.hexToLove("#ed6aff"), -- fuchsia400
	colorUtils.hexToLove("#e12afa"), -- fuchsia500
	colorUtils.hexToLove("#c700de"), -- fuchsia600
	colorUtils.hexToLove("#a700b7"), -- fuchsia700
	colorUtils.hexToLove("#8a0194"), -- fuchsia800
	colorUtils.hexToLove("#721377"), -- fuchsia900

	colorUtils.hexToLove("#fbcee8"), -- pink200
	colorUtils.hexToLove("#fda4d5"), -- pink300
	colorUtils.hexToLove("#fb63b5"), -- pink400
	colorUtils.hexToLove("#f6329a"), -- pink500
	colorUtils.hexToLove("#e50076"), -- pink600
	colorUtils.hexToLove("#c6005b"), -- pink700
	colorUtils.hexToLove("#a2004b"), -- pink800
	colorUtils.hexToLove("#851042"), -- pink900

	colorUtils.hexToLove("#ffccd2"), -- rose200
	colorUtils.hexToLove("#ffa0ad"), -- rose300
	colorUtils.hexToLove("#ff637d"), -- rose400
	colorUtils.hexToLove("#ff1f56"), -- rose500
	colorUtils.hexToLove("#ec003f"), -- rose600
	colorUtils.hexToLove("#c60035"), -- rose700
	colorUtils.hexToLove("#a40035"), -- rose800
	colorUtils.hexToLove("#8a0735"), -- rose900

	colorUtils.hexToLove("#e5e7eb"), -- gray200
	colorUtils.hexToLove("#d0d5db"), -- gray300
	colorUtils.hexToLove("#99a1ae"), -- gray400
	colorUtils.hexToLove("#697282"), -- gray500
	colorUtils.hexToLove("#495564"), -- gray600
	colorUtils.hexToLove("#354152"), -- gray700
	colorUtils.hexToLove("#1d2838"), -- gray800
	colorUtils.hexToLove("#101727"), -- gray900

	colorUtils.hexToLove("#e4e4e6"), -- zinc200
	colorUtils.hexToLove("#d3d3d8"), -- zinc300
	colorUtils.hexToLove("#9e9ea9"), -- zinc400
	colorUtils.hexToLove("#70707b"), -- zinc500
	colorUtils.hexToLove("#51515c"), -- zinc600
	colorUtils.hexToLove("#3e3e46"), -- zinc700
	colorUtils.hexToLove("#26262a"), -- zinc800
	colorUtils.hexToLove("#17171a"), -- zinc900

	colorUtils.hexToLove("#e7e4e3"), -- stone200
	colorUtils.hexToLove("#d6d3d0"), -- stone300
	colorUtils.hexToLove("#a69f9b"), -- stone400
	colorUtils.hexToLove("#78706b"), -- stone500
	colorUtils.hexToLove("#57524d"), -- stone600
	colorUtils.hexToLove("#443f3b"), -- stone700
	colorUtils.hexToLove("#292423"), -- stone800
	colorUtils.hexToLove("#1b1817"), -- stone900
}
return colors
