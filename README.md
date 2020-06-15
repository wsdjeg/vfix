<h1 align="center">:Vfix</h1>

<p align="center">
  <img width="600"
       alt=":Vfix in action preview"
       src="https://raw.githubusercontent.com/Termplexed/res/master/gif/Vfix.gif">
</p>

A crude and simple script for Vim to resolve some of the error `:messages` yielded when vim-scrips fail.

Can be a help to find where errors originate etc.

---

## :information_source:&nbsp;&nbsp;&nbsp;About

Parses `:messages` and resolves numeric and other references to errors before adding them to QuickFix list.

##  :heavy_dollar_sign:&nbsp;&nbsp;&nbsp;Example

As in gif above.

<pre>
Error detected while processing function 346[5]..345[31]..340:
line   3:
E492: Not and editor command: ^I^I^Iautocmdx
</pre>
Pushed by ***Vfix*** to QuickFix as:
<pre>
1  <b>.vim/some/dir/script.vim</b>|460 error 492|<i> fun! s:MyScript.set_au(): Not an editor command:   autocmdx</i>
2  <b>.vim/some/dir/script.vim</b>|564 info|<i> Called by: fun! s:MyScript.go_active(a, b)</i>
3  <b>.vim/some/dir/script.vim</b>|594 info|<i> Called by: fun! s:MyScript.interpret_cmd(...)</i>
</pre>
Here we have on line 1. in QuickFix the offending line `460` by function `340` resolved to `s:MyScript.set_au()`.

Line 2. and 3. are the trace from *345* to *346*. The entries in the QuickFix list are direct links to the scripts and their error lines - as long as they can be found.

<h2>:floppy_disk:&nbsp;&nbsp;&nbsp;Install</h2>

Put script in a autoload folder or source it manually.

## :pager::&nbsp;&nbsp;&nbsp;Commands

Adds one command: `:Vfix`

## :books:&nbsp;&nbsp;&nbsp;Usage

The script comes with a few options. When Vfix has been sourced you can run:

```vim
:Vfix help
```

to get a list:
```wasm
Options:
  a  : append  - Append to QuickFix List. Default OFF:replace
  r  : reverse - Reverse messages.        Default ON :LIFO
  o  : copen   - Open using copen.        Default OFF:cw
  s  : silent  - Do not open window.      Default OFF
 ig  : nolost  - Ignore lost functions.   Default OFF
 au  : autorun - Vfix on sourcing a file. Default OFF
 ac  : clear   - Alway clear ":messages". Default OFF
 cc  : clear   - Clear messages once.
 sf  : Print Status for flags.
  h  : This help
```

Beware that `cc` and `ac` erase `:messages`. To view status of flags use `:Vfix sf`

**:Vfix** alone runs the script and open QuickFix if it managed to dechipher any errors - optionally with `cc`, `a`, `s`, `o` or `r` option(s).

###  :mag:&nbsp;&nbsp;&nbsp;Lost functions

Note that every time a script get sourced it get a new reference. If this is anumeric ref. it can not be resolved later and one will get `N/A` + a noop address in the errors list. Activate `ig` to silence these.

##  :earth_americas:&nbsp;&nbsp;&nbsp;Global options

Override on options can be set in .vimrc (or elsewhere). All takes `1` for on and `0` for off.
```vim
" Option        Default
g:Vfix_append         0 " Append to QuickFix error list. Else replace.
g:Vfix_copen          0 " Use copen. Else cwindow.
g:Vfix_silent         0 " Never open window.
g:Vfix_reverse        1 " Reverse messages / errors LIFO. Main reson for this is
                        " when one have a lot of `:messages`. Would perhaps be
                        " better to jump to end of error list.
g:Vfix_ignore_lost    0 " Ignore errors where functions can not be resolved. See
                        " note below.
g:Vfix_clr_always     0 " Clear :messages each time Vfix is executed
g:Vfix_auto_run       0 " Auto run on sourcing. Can be buggy.

g:Vfix_re_source_globals  0
" Mainly for hacking this script.
" If set and true global options will be reset when re-sourcing script.
```
##  :mega:&nbsp;&nbsp;&nbsp;Notes

As it read the files where errors originated each file with errors will be added to the hidden buflist. (`ls!`).

Have a solution using `head` at least on OS with this program. Patch later.

- [ ] Add option to use shell command to read script files.
- [ ] Consider jumping to end of error list instead of reversing.
- [ ] Sorting is a mess when one have mixed messages: One can typically have an
error reference in `:messages` followed by one *or more*  error messages. This script is
greedy when reading errors after an error with reported location - resulting in
a skewed reporting when it comes to *called by* references. So - work on this.
- [ ] Better autocommand handling.
- [ ] It is possible to cache references to *all* objects and functions each
time a script is sourced by looping `s:`, `g:` etc. Could have it as an option,
but likely best suited as an addon. Is a bit complex and usually not worth it.
- [ ] Find a way to set a a *mark* in `:messages` if user reloads a script they
are working on. Could likely use autocommand in combination with `:silent echom`
This way one could ignore lost messages better.
- [ ] As we read the files where errors originated and also get context - a few
lines before / after - one could try to implement a way to show this. Popup?
For example a popup while navigating QuickFix list.


##  :curly_loop:&nbsp;&nbsp;&nbsp;History

Is a snip that has been in my .vim directory for years, adding a little now and then. Likely a lot of bugs, ironically enough. Did some cleanup on the code and have likley introduced a few more. But put it out there in case anyone find it helpful.
