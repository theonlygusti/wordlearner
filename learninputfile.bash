cat $1 | perl -MList::Util=shuffle -wne 'print shuffle <>;' | head -10 | bash wordlearner.bash
