" vim: fdm=marker
"" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""" Figlet -w 90 -c -f block
 "                                                                                    "
 "                        _|      _|  _|_|_|_|  _|  _|      _|                        "
 "                        _|      _|  _|              _|  _|                          "
 "                        _|      _|  _|_|_|    _|      _|                            "
 "                          _|  _|    _|        _|    _|  _|                          "
 "                            _|      _|        _|  _|      _|                        "
 "                                                                                    "
 " """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" D s:Vfix {  }                                             The  Vfix  DICT {{{1
"
let s:keepcpo = &cpo
set cpo&vim

" If sourcing THIS script multiple times, backup and restore settings.
"
" Globals does not override on re-sourcing unless
" 	s:Vfix.cnf.re_source_globals ||
" 	g:Vfix_resource_globals
" is set to a value evaluating to true. Look at s:Vfix.boot() for more.
if exists('s:Vfix.cnf')
	let s:cnf_bak = copy(s:Vfix.cnf)
endif

let s:Vfix = #{
	\ strapped: 0,
	\ cnf: { }
\}

" }}}
" D s:cnf_default                                       Default config DICT {{{1
" All values can be overridden globally by:
" 	g:Vfix_{config name} = {config setting}
"
let s:cnf_default = #{
	\ re_source_globals: 0,
	\ append: 0,
	\ copen: 0,
	\ silent: 0,
	\ reverse: 1,
	\ clr_once: 0,
	\ ignore_lost: 0,
	\ clr_always: 0,
	\ auto_run: 0
\}
" }}}

" F s:Vfix.set_messagelist()                              Read all messages {{{1
" Out: self.messages    list
fun! s:Vfix.set_messagelist()
	let messages = execute('messages')
	let self.messages = split(messages, "\n")
	return self
endfun " }}}
" F s:Vfix.file2buf(fn, line)                                     Read file {{{1
" fn:   File to read
" line: Read at least line + 2 lines from file
fun! s:Vfix.file2buf(fn, line)
	let buf = []
	let head = executable('head')
	try

		let buf = readfile(a:fn, '', a:line + 2)
	catch
		let buf = []
	endtry
	return buf
endfun " }}}

" F s:Vfix.ctx_from_buf(buf, line)                  Get context from buffer {{{1
" buf   : Buffer with code     list
" line  : Offset in code to focus on
" return: 5 lines of code. 2 before + the line + 2 after
fun! s:Vfix.ctx_from_buf(buf, line)
	return a:buf[(a:line < 2 ? 0 : a:line - 2) : (a:line + 2)]
endfun " }}}
" F s:Vfix.resolve_ref(ref, type) abort               Resolve function name {{{1
" Use :verbose function XXX to get file and line where function was included,
" read file and return function as declared in source.
"
" ref:  Function number, name or <SID>NR_name
" type: edict = dictionary function, typically number
"       elfun = other
"
" TODO: Consider matching type by checking if it is all numbers
"       instead of passing as argument.
fun! s:Vfix.resolve_ref(ref, type) abort
	let pat = a:type == 'edict' ? '{'.a:ref.'}' : a:ref

	try
		let fun = execute('verbose function' . pat)
	catch /^Vim\%((\a\+)\)\=:E123:/
		let fun = 'N/A'
	endtry
	if fun == '' | let fun = 'N/A' | endif

	if fun != 'N/A'
		let fun = split(fun, "\n")
		let m = matchlist(fun[1], 'Last set from \(\f\+\) line \([0-9]\+\)')
		if len(m)
			let fn = expand(m[1])
			let buf = self.file2buf(fn, m[2] + 1)
			if len(buf)
				let fun = buf[m[2] - 1]
			endif
		endif
	endif
	return fun
endfun " }}}
" F s:Vfix.resolve_ref_verbose(entry, type) abort      Resolve and get info {{{1
" also modify passed dict entry:
" +entry.file:  file name
" +entry.fline: function start line
" +entry.fun:   function declaration
" +entry.ctx:   context (5 lines targeting reported error line)
"
" entry:    dict entry. See .create_entry
" type:     edict = dictionary function
"
" TODO: Consider matching type by checking if it is all numbers
"       instead of passing as argument.
fun! s:Vfix.resolve_ref_verbose(entry, type) abort
	let pat = a:type == 'edict' ? '{'.a:entry.ref.'}' : a:entry.ref

	try
		let fun = execute('verbose function ' . pat)
	catch /^Vim\%((\a\+)\)\=:E123:/
		let fun = 'N/A'
	catch /^Vim\%((\a\+)\)\=:E129:/
		" E129: function name required
		let fun = 'N/A'
	endtry

	if fun == '' | let fun = 'N/A' | endif

	if fun != 'N/A'
		let fun = split(fun, "\n")
		let m = matchlist(fun[1], 'Last set from \(\f\+\) line \([0-9]\+\)')
		if len(m)
			let fn = expand(m[1])
			let a:entry.file = fn
			let a:entry.fline = m[2]
			let ce = a:entry.offs + m[2]
			let buf = self.file2buf(fn, ce + 10)
			if len(buf)
				let a:entry.fun = buf[m[2] - 1]
				let a:entry.ctx = self.ctx_from_buf(buf, ce - 1)
			endif
		endif
	endif
	return a:entry.file != ''
endfun " }}}
" D s:Vfix.ml_trace                 Regex patterns used to matchlist trace. {{{1
" 'messages' line typically is:
" Some error fun[3]...fun[8]...fun:
" where numbers in brackets are offset within funciton.
let s:Vfix.ml_trace = #{
	\ edict: '^\([0-9]\+\)\[\([0-9]\+\)\]$',
	\ elfun: '^\([^[]\+\)\[\([0-9]\+\)\]$'
\} " }}}
" F s:Vfix.create_entry(type, ref, ln)                 Create a stack entry {{{1
" Processing single entry from a trace: EEE[offs]...EEE[offs]...EEE
"
" type: edict = dictionary ref. as in NNNN
"       elfun = others as in SomeFun, or <SID>NN_SomeFun, ...
" ref:  the function reference. If NNN[offset] or FunName[offset]
"       the NNN or FunName part is extracted
" ln:   Line. If entry does not have a offset, typically [offset]
"       it is the 'main error' and this parameter is used instad
"       of the one matched in 'm' ... or not matched as it does
"       not exist :P
fun! s:Vfix.create_entry(type, ref, ln)
	let m = matchlist(a:ref, self.ml_trace[a:type])
	let entry = #{
		\ file  : '',
		\ ref   : get(m, 1, a:ref),
		\ fun   : 'N/A',
		\ fline : 0,
		\ offs  : a:ln + get(m, 2, ''),
		\ ctx   : ''
	\}
	call self.resolve_ref_verbose(entry, a:type)
	return entry
endfun " }}}
" F s:Vfix.push_err_local(type, fr) abort                  Push local error {{{1
"
" Entry, local to a function scope, dictionary or function reference error stack.
"
" type: edict or elfun
" fr:   Function Referrence(s). Typically:
"   edict:
"       623[5]..612[3]..622
"   elfun:
"       SomeFun[5]..AnotherFun[3]..FunWithError
"   Extracted from 'messages'
" XXX: Can be mix of Fun...<SID>N_Fun...NNN:
"
" TODO: Better name for this
fun! s:Vfix.detect_etype(ref)
	if a:ref =~ '^[0-9]\+\[\?'
		return 'edict'
	else
		return 'elfun'
	endif
endfun
fun! s:Vfix.push_err_local(fr) abort
	let reflist = reverse(split(a:fr, '\.\.'))
	let type = self.detect_etype(reflist[0])
	let errors = self.get_errors(type)
	let linen = errors.last_eline

	for ref in reflist
		let type = self.detect_etype(ref)
		let errors.stack += [self.create_entry(type, ref, linen)]
		let linen = 0
	endfor

	let self.reflist += [errors]

	let self.ix += errors.log_len ? errors.log_len : 1
	return 0
endfun " }}}
" F s:Vfix.push_err_global(fn) abort                      Push global error {{{1
"
" Add a global scope (inline / outside of function) error stack
fun! s:Vfix.push_err_global(fn) abort
	let fn = expand(a:fn)
	let errors = self.get_errors('efile')
	let buf = self.file2buf(fn, errors.last_eline)
	if len(buf)
		let errors.stack += [#{
			\ file  : fn,
			\ ref   : '',
			\ fun   : '<inline>',
			\ fline : ''
		\}]
		for err in errors.err_list
			let err.ctx = self.ctx_from_buf(buf, err.line - 1)
		endfor
		let self.reflist += [errors]
	endif
	let self.ix += errors.log_len ? errors.log_len : 1
	return 0
endfun " }}}
" F s:Vfix.push_err_unscoped(type) abort                Push unscoped error {{{1
"
" TODO: Better name for unscoped, it is kind of global scoped, but really
" script/file scoped. s: ... but not in a function. Thought of "wildling"
" but likely a better choice :P
"
" type: eref
fun! s:Vfix.push_err_unscoped(type) abort
	let errors = self.get_errors(a:type, self.ix)
	let errors.stack += [#{
		\ file  : '',
		\ ref   : 'N/A',
		\ fun   : '<unscoped>',
		\ fline : 1
	\}]
	let self.reflist += [errors]
	let self.ix += errors.log_len ? errors.log_len : 1
	return 0
endfun " }}}
" F s:Vfix.resolve_msg(t) abort                      Resolve in-message ref {{{1
"
" Some messages can be:
" E123: blah blah function: 1234
"
" This function resolves 1324 to actual function name and return
" error line with 1234 substituted with function declaration.
fun! s:Vfix.resolve_msg(t) abort
	let m = matchstr(a:t, 'function:\? \zs[0-9]\+$')
	if m != ''
		let m = substitute(a:t, m .'$', self.resolve_ref(m, 'edict'), '')
	else
		let m = a:t
	endif
	" Fix tabs
	let m = substitute(m, '\^I', ' ', 'g')
	return m
endfun " }}}
" F s:Vfix.get_errors(type, ...) abort  Read errors from self.messages list {{{1
" Starting from current index, read all messages starting with E123
" or line  : 124
" or Interrupted
"
" ARG:  None or line number in self.messages to start with
"       Most errors have a ref. to a line number and caller.
"       In this case self.ix is used.
"       But some can be 'stand alone' errors where one typically
"       have passed wrong number of arguments etc.
"
" Returns a error dict that typically is pushed to reflist stack from
" caller function.
fun! s:Vfix.get_errors(type, ...) abort
	let err = []
	let i = a:0 > 1 ? a:2 : self.ix + 1
	let n = len(self.messages)
	let line = 0
	while i < n
		let m = self.messages[i]
		if m == self.messages[i - 1]
			" Ignore dupe
		else
			let e = matchlist(m, '^\%(' .
				\ '\%(line\s\+\([0-9]\+\):\)\|' .
				\ '\(Interrupted\)\|' .
				\ '\%(E\([0-9]\+\): \(.*\)\)' .
			\ '\)$')
			if ! len(e)
				break
			elseif e[1] != ''
				let line = e[1]
			elseif e[2] != ''
				let err += [#{line: line, nr: 0, txt: "Interrupted", ctx: 'N/A'}] ", xx: e}]
			elseif e[3] != ''
				" TODO: Add entry for resolved function in message
				" Trigger by for example: call Some_fun() where Some_fun()
				" require arguments.
				" XXX: Partially done, but should likely be refactored.
				let txt = self.resolve_msg(e[4])
				let err += [#{line: line, nr: e[3], txt: txt, ctx: 'N/A'}] ", xx: e}]
			endif
		endif
		let i += 1
	endwhile
	return #{
		\ type      : a:type,
		\ trigger   : self.messages[self.ix],
		\ err_list  : err,
		\ last_eline: line,
		\ log_start : self.ix,
		\ log_end   : i,
		\ log_len   : i - self.ix,
		\ stack     : []
	\}
endfun " }}}

" F s:Vfix.check_eref()                      Check for 'stand alone' errors {{{1
" Typically
" E000: *Something wrong with call to* function: 123
" If this error is not part of a call stack and does not have a
" reference as in ^Error detected while ..., we try to catch it
" here and at least resolve numeric references.
fun! s:Vfix.check_eref()
	let r = 1
	let xm = matchlist(self.messages[self.ix],
		\ '^E' .
		\ '\([0-9]\+\): .*arguments for function:\? \([0-9]\+\)' .
	\ '$')
	if len(xm)
		call self.push_err_unscoped('eref')
	else
		let r = 0
	endif
	return r
endfun " }}}
" F s:Vfix.check_detected()                         Check for scoped errors {{{1
"
" Check if current line from 'messages' is a *normal* Error detected
" message. If so try to find if it is a dict error or other and call
" appropriate functions to push it onto reflist.
fun! s:Vfix.check_detected()
	let r = 1
	let xm = matchlist(self.messages[self.ix],
		\ "^Error detected while processing " .
		\ '\%(' .
		\ '\%(function \([0-9.\]\[]\+\)\)\|' .
		\ '\%(function \([][.<>#A-Za-z0-9_]\+\)\)\|' .
		\ '\%(function \(<SNR>[][.<>#A-Za-z0-9_]\+\)\)\|' .
		\ '\%(function \(<lambda>[][.<>#A-Za-z0-9_]\+\)\)\|' .
		\ '\(\f\+\.vim\)\|' .
	\ '\):$')
	if len(xm)
		" Could merge 1, 2 and 3
		if xm[1] != ''
			" NNN type function references
			call self.push_err_local(xm[1])
		elseif xm[2] != ''
			" FunName type function references
			call self.push_err_local(xm[2])
		elseif xm[3] != ''
			" XXX REMOVE
			" <SNR>NN_FunNAme type function references
			call self.push_err_local(xm[3])
		elseif xm[4] != ''
			" <lambda>NNN type function references
			" TODO: This rarely works
			call self.push_err_local(xm[4])
		elseif xm[5] != ''
			call self.push_err_global(xm[5])
		else
			let r = 0
		endif
	else
		let r = 0
	endif
	return r
endfun " }}}
" F s:Vfix.parse_messages() abort                            Parse messages {{{1
"
" Loop messages and try to detect and resolve errors.
" Detections are pushed onto self.reflist.
fun! s:Vfix.parse_messages() abort
	let n = len(self.messages)
	let self.ix = 0
	while self.ix < n
		let r = self.check_eref()
		if r == 0 | let r = self.check_detected() | endif
		if r == 0 | let self.ix += 1 | endif
	endwhile
endfun " }}}

" F s:Vfix.update_quickfix()                                Update QuickFix {{{1
"
" Update QuickFix with results from parsed 'messages'
fun! s:Vfix.update_quickfix()
	let ignore_lost = self.cnf.ignore_lost
	let e = []

	for entry in self.reflist
		let main = entry.stack[0]
		if ignore_lost && main.fun == 'N/A'
			continue
		endif
		" Add reported errors for this entry
		for err in entry.err_list
			"main.fline + main.eline + main.offs,
			let e += [#{
				\ filename  : main.file,
				\ lnum      : err.line + main.fline,
				\ nr        : err.nr,
				\ col       : 0,
				\ vcol      : 0,
				\ text      : main.fun . ': ' . err.txt,
				\ type      : 'E',
				\ valid     : main.fun != 'N/A'
			\}]
		endfor
		" Add stack trace as Info entries
		for se in entry.stack[1:]
			let e += [#{
				\ filename  : se.file,
				\ lnum      : se.fline + se.offs,
				\ nr        : 0,
				\ col       : 0,
				\ vcol      : 0,
				\ text      : 'Called by: ' . se.fun,
				\ type      : 'I',
				\ valid     : 0
			\}]
		endfor
	endfor
	call setqflist(e, self.cnf.append ? 'a' : 'r')
endfun " }}}

" Vfix Help and Options                                                HELP {{{1

" L s:VfixHelp                                       Help and flags handler {{{2
let s:VfixHelp = [
	\ ['append',        'a', 'append  - Append to QuickFix List. Default OFF:replace'],
	\ ['reverse',       'r', 'reverse - Reverse messages.        Default ON :LIFO'],
	\ ['copen',         'o', 'copen   - Open using copen.        Default OFF:cw'],
	\ ['silent',        's', 'silent  - Do not open window.      Default OFF'],
	\ ['ignore_lost',  'ig', 'nolost  - Ignore lost functions.   Default OFF'],
	\ ['auto_run',     'au', 'autorun - Vfix on sourcing a file. Default OFF'],
	\ ['clr_always',   'ac', 'clear   - Alway clear ":messages". Default OFF'],
	\ [v:null,         'cc', 'clear   - Clear messages once.'],
	\ [v:null,         'sf', 'Print Status for flags.'],
	\ [v:null,          'h', 'This help']
\ ] " }}}

" F s:Vfix.echo_flag(h)                      Helper for - Echo flags status {{{2
fun! s:Vfix.echo_flag(h)
	let f = self.cnf[a:h[0]]
	exe 'echohl ' .  (f ? 'Statement' : 'Comment')
	echo printf("%3s= %s,  %s", a:h[1], f, a:h[2])
	echohl None
endfun " }}}

" F s:Vfix.show_flags_state()                             Echo flags status {{{2
fun! s:Vfix.show_flags_state()
	echo
	for h in s:VfixHelp
		if h[0] != v:null
			call self.echo_flag(h)
		endif
	endfor
endfun " }}}

" F s:Vfix.flip_option(k)                               Flip settings flags {{{2
fun! s:Vfix.flip_option(k)
	let self.cnf[a:k] = !self.cnf[a:k]
	echo "State " . a:k . ": " . self.cnf[a:k]
endfun " }}}

" F s:Vfix.str2bool(s)                                    String to boolean {{{2
fun! s:Vfix.str2bool(v)
	let v = tolower(a:v)
	if ['+', 'y', 'true']->index(v) > -1
		return 1
	elseif ['-', 'n', 'false']->index(v) > -1
		return 0
	else
		return a:v ? 1 : 0
	endif
endfun " }}}

" F s:Vfix.set_option(k, v)                                       Set flags {{{2
fun! s:Vfix.set_option(k, v)
	if a:v == v:null
		call self.flip_option(a:k)
	else
		let self.cnf[a:k] = self.str2bool(a:v)
		echo "State " . a:k . ": " . self.cnf[a:k]
	endif
endfun " }}}

" F s:Vfix.help()                                         Command line Help {{{2
" :Vfix h | help
fun! s:Vfix.help()
	echohl Constant
	echo "Options:"
	for op in s:VfixHelp
		echo printf("%3s  : %s", op[1], op[2])
	endfor
	echohl None
	return 1
endfun " }}}

" F s:Vfix_ccomp(A, L, P)                     Commandline Complete function {{{2
fun! s:Vfix_ccomp(A, L, P)
	let base = ['a ', 'r ', 'o ', 's ', 'cc ',
		\ 'ig', 'au', 'ac', 'h ', 'sf', 'help ']
	let pri = filter(base, 'v:val =~# "^".a:A')
	return pri
endfun " }}}

" F s:Vfix.set_opts(n, opts)                                  Parse options {{{2
" Parse command options. If r = 1 at end, execution is aborted.
fun! s:Vfix.set_opts(n, opts)
	let r = 0
	for opt in a:opts
		if opt =~ '[:=]'
			let v = split(opt, '[:=]')
			let opt = v[0]
			let val = v[1]
		else
			let val = v:null
		endif

		if     opt == 'cc'
			call self.set_option('clr_once', val)
		elseif opt == 'a'
			call self.set_option('append', val)
		elseif opt == 's'
			call self.set_option('silent', val)
		elseif opt == 'o'
			call self.set_option('copen', val)
		elseif opt == 'r'
			call self.set_option('reverse', val)
		elseif opt == 'ig'
			call self.set_option('ignore_lost', val)
			let r = 1
		elseif opt == 'ac'
			call self.set_option('clr_always', val)
			call self.autocmd_set()
			let r = 1
		elseif opt == 'au'
			call self.set_option('auto_run', val)
			call self.autocmd_set()
			let r = 1
		elseif opt == 'sf'
			call self.show_flags_state()
			let r = 1
		elseif opt == 'h' || opt == 'help'
			call self.help()
			let r = 1
		endif
	endfor
	return r
endfun " }}}
" }}}

" F s:Vfix.run(...)                                                    Main {{{1
"
fun! s:Vfix.run(...)
	" Parse options
	if self.set_opts(a:0, a:000)
		return 1
	endif

	" Reset
	let self.reflist = []
	" Build
	call self.set_messagelist()
	call self.parse_messages()

	" Post build
	if self.cnf.reverse
		" LIFO or FIFO
		call reverse(self.reflist)
	endif

	" Populate
	call self.update_quickfix()

	" Display
	if ! self.cnf.silent
		if self.cnf.copen
			keepalt copen
			"wincmd p
		else
			cw
			"keepalt cw
			"wincmd p
		endif
	endif

	" Clear messages
	if self.cnf.clr_once || self.cnf.clr_always
		messages clear
		let self.cnf.clr_once = 0
	endif
endfun " }}}
" F s:Vfix.autocmd_set()                           Set / Remove autocommand {{{1
fun! s:Vfix.autocmd_set(clear = 0)
	if self.cnf.auto_run && !a:clear
		augroup VfixAurunAfterSourcing
			autocmd!
			autocmd SourcePost *.vim call s:Vfix.run()
		augroup END
	else
		@silent autocmd! VfixAurunAfterSourcing
		@silent augroup! VfixAurunAfterSourcing
	endif
endfun " }}}
" F s:Vfix.def_commands()                                   Define commands {{{1
fun! s:Vfix.def_commands()
	command! -nargs=* -complete=customlist,s:Vfix_ccomp -bar Vfix
		\ :call s:Vfix.run(<f-args>)
endfun " }}}
" F s:Vfix.boot()                                                 Bootstrap {{{1
fun! s:Vfix.boot()
	call extend(s:Vfix.cnf, s:cnf_default)

	if exists('s:cnf_bak')
		call extend(s:Vfix.cnf, s:cnf_bak)
		let self.strapped =
			\ self.cnf.re_source_globals ? v:false : v:true
		call self.autocmd_set(1)
	endif

	call self.def_commands()

	call self.autocmd_set()

	" XXX Abort bootload here if this is a re-sourcing and
	"     re_source_globals != true
	if self.strapped
		return
	endif

	let self.strapped = v:true
	" Set options from optional global configurations
	for k in keys(s:cnf_default)
		let self.cnf[k] = get(g:, 'Vfix_' . k, s:cnf_default[k])
	endfor
endfun

call s:Vfix.boot()

let &cpo= s:keepcpo
unlet s:keepcpo
" }}}


" EOF and Suggestions                                                 OTHER " {{{1
" XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX
" XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX
				finish
" XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX
" XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX

" Suggested mappings:

"  is CTRL-O (i: Ctrl-V Ctrl-S-O; to prevent cursor movement
" when calling in input mode

" Suggested maps for sourcing scripts:

" Save + Source:
inoremap    <silent>    <C-S-F12>  :w<CR>:so %<CR>
nnoremap    <silent>    <C-S-F12>  :w<CR>:so %<CR>
" Source
inoremap    <silent>    <C-F12>  :so %<CR>
nnoremap    <silent>    <C-F12>    :so %<CR>
" EOF }}}
