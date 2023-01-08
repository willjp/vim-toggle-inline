
vim-toggle-inline
=================

Toggles inlining of functions/collections under cursor, by parsing quotes/brackets.
Designed to be c-family language agnostic, but here are some sample use-cases.

  * function declarations/calls  -- toggle inline vs one-line-per-param
  * lists/tuples/arrays          -- toggle inline vs one-line-per-item
  * hashes/dicts                 -- toggle inline vs one-line-per-keypair
  * nested collections/functions -- cursor-based inlining (inline/expand only inner, or outer)

.. image:: ./media/demo.gif


Usage
=====

.. code-block:: vim

   " put your cursor on a line that is part of a function-call/declaration, and execute
   :ToggleInline


You may consider setting this to a keybinding for convenience

.. code-block:: vim

   nnoremap ti :ToggleInline<CR>


Contributing
============

.. code-block:: bash

   make build  # build helptags
   make test   # run tests


Bug Reports
===========

Bugs tracking is managed by [git-bug](https://github.com/MichaelMure/git-bug). Please install.

.. code-block:: bash

   git bug user create # create your user
   git bug pull        # fetch latest bugs
   git bug webui       # show bugs


