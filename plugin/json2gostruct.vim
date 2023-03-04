if exists('g:loaded_json2gostruct') | finish | endif " prevent loading file twice

command! -range Json2GoStruct lua require'json2gostruct'.Json2GoStruct()

let g:loaded_json2gostruct = 1

