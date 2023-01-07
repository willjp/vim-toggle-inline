
vim-toggle-inline
=================

Toggles inlining of items under cursor:

  * function declarations -- one line per param
  * function calls        -- one line per param
  * TODO: python-style lists    -- one line per item
  * TODO: python-style tuples   -- one line per item
  * TODO: ruby-style hashes   -- one line per item
  * TODO: would be nice to support visual-selection for inlining small parts of deeply nested hashes
  * TODO: ruby-blocks
  * TODO: recursive inlining
  * TODO: sorbet 'params()' calls

I've tried to make this language agnostic, at least within the C family of languages.


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

