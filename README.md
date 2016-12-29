# Wordlearner

I spend most of my time inside the command line, but also need to learn other languages for school. So I made this command-line tool which teaches keywords by speaking them aloud and quizzing you on them.

    $ bash learninputfile.bash example-keyword-files/dailyroutineverbs.txt

![http://i.cubeupload.com/YA1k6b.gif](http://i.cubeupload.com/YA1k6b.gif)

The tool goes through a list of foreign-language words that you define, and it translates each one to your language and asks you to submit what you think the original foregin-language word was.

# Installation

From your favourite directory:

    $ git clone https://github.com/theonlygusti/wordlearner.git

Or use the green download button above this section.

# Configuration

It's super easy to configure this tool to use your own languages and keyword lists!

First, you probably want to specify the language you want to practice. That's fine, just change the values inside of `languages.cfg`:

    native="en"
    learning="fr"

The above two lines would specify that you are english (EN - see [ISO country codes](http://www.nationsonline.org/oneworld/country_code_list.htm)) and that youa re learning french (FR).

Now, to make your own list of keywords to practice is as simple as creating a text document with one word per line. Have a look at the examples.

