# VimXL

![a teaser image of VimXL](teaser.png "LiteXL in action")

Vim plugin for [Lite XL](https://lite-xl.com/), that hopefully doesn't suck this time!

## Installation
Just do `git clone https://github.com/sashabjorkman/vimxl`
inside of your `plugins/` directory.

## Features
Here is a non-exhaustive list of features currently implemented:
* The repeat command
* Insert-mode, visual-mode, normal-mode, command-mode
* Search
* Yank, delete, change, substitute
* Indent, unindent
* `O, o, A, I, p, P, n, N`
* `$, |, ^, _, +, G, gg, w, W, b, B, f, F`
* Classical Vim hjkl navigation.
* Very easily extendable (and build your own plugins on-top of)
* Numerical arguments for motions and operators (try `2d3j4.`)
* Easily toggle vim-mode on and off
* A lot of comments.
* ... and more!

### Missing Features
If you make heavy use of visual block mode (ctrl+V)
then VimXL is not quite ready for you yet.
Although much of what you would do with visual block mode
can easily be done through Lite XL's multi-cursor support.
Still it is understandable if your Vim muscle memory makes this a deal-breaker
for you.

## Philosophy
The aim of VimXL is to be as non-intrusive as possible.
And generally to be a good citizen in the Lite XL world.
For example, the insert-mode of VimXL is almost identical to running
Lite XL without any plugins.
Also where possible,
VimXL tries to avoid reimplementing features already present in Lite XL.
VimXL reuses the bundled autocomplete.lua plugin.
Motions in VimXL are implemented as ordinary Lite XL translations.

Furthermore the goal is also to only implement a subset
of the vast collection of Vim commands and motions.
More specifically, only the ones that I use, or that are requested by others.
However if a command is added to this plugin,
then a lot of care and effort of should be made to make sure that the command
correctly mimics the exact behaviour of its Vim counterpart.
For example,
even though VimXL does not currently support paragraph text objects,
it's implementation of the delete word command is to my knowledge correct.
Try running `2d2w3.` in VimXL and other plugins and see for yourself. 
The correct behaviour (that can be seen by doing the same in Vim) is that
a total of 7 words should be deleted.
