if exists('g:loaded_json2gostruct') | finish | endif " prevent loading file twice

command! -range Json2GoStruct lua require'json2gostruct'.Json2GoStruct()
command! -range -nargs=1 Json2GoStructExt lua require'json2gostruct'.Json2GoStructExt(<f-args>)

let g:loaded_json2gostruct = 1

