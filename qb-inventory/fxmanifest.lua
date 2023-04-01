fx_version 'cerulean'
game 'gta5'
lua54 'yes'
description 'Ax-Inventory'
shared_scripts {
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua',
}
server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'newqb.lua',
	"server/*.lua",
}
client_scripts {
	"client/*.lua"
}
ui_page {
	'ui/index.html'
}
files {
	'ui/index.html',
	'ui/*.css',
	'ui/*.js',
	'ui/items/*.png',
	'ui/items/*.jpg',
	'ui/cloth/*.png',
	'ui/cloth/*.svg',
	'ui/*ttf'
}

server_script 'convert.lua'