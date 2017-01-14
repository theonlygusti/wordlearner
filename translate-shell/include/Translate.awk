####################################################################
# Translate.awk                                                    #
####################################################################

function provides(engineName) {
    Translator[tolower(engineName)] = TRUE
}

function engineMethod(methodName,    engine, translator) {
    if (!Translator[Option["engine"]]) {
        # case-insensitive match engine name
        engine = tolower(Option["engine"])
        if (!Translator[engine]) # fuzzy match engine name
            for (translator in Translator)
                if (Translator[translator] && # there IS such a translator
                    translator ~ "^"engine) {
                    engine = translator
                    break
                }
        if (!Translator[engine]) {
            e("[ERROR] Translator not found: " Option["engine"] "\n"    \
              "        Run '-list-engines / -S' to see a list of available engines.")
            exit 1
        }
        Option["engine"] = engine
    }
    return Option["engine"] methodName
}

# Detect external audio player (mplayer, mpv, mpg123).
function initAudioPlayer() {
    AudioPlayer = !system("mplayer" SUPOUT SUPERR) ?
        "mplayer" :
        (!system("mpv" SUPOUT SUPERR) ?
         "mpv" :
         (!system("mpg123 --version" SUPOUT SUPERR) ?
          "mpg123" :
          ""))
}

# Detect external speech synthesizer (say, espeak).
function initSpeechSynthesizer() {
    SpeechSynthesizer = !system("say ''" SUPOUT SUPERR) ?
        "say" :
        (!system("espeak ''" SUPOUT SUPERR) ?
         "espeak" :
         "")
}

# Detect external terminal pager (less, more, most).
function initPager() {
    Pager = !system("less -V" SUPOUT SUPERR) ?
        "less" :
        (!system("more -V" SUPOUT SUPERR) ?
         "more" :
         (!system("most" SUPOUT SUPERR) ?
          "most" :
          ""))
}

# Initialize `HttpService`.
function initHttpService() {
    _Init()

    if (Option["proxy"]) {
        match(Option["proxy"], /^(http:\/*)?([^\/]*):([^\/:]*)/, HttpProxySpec)
        HttpService = "/inet/tcp/0/" HttpProxySpec[2] "/" HttpProxySpec[3]
        HttpPathPrefix = HttpProtocol HttpHost
    } else {
        HttpService = "/inet/tcp/0/" HttpHost "/" HttpPort
        HttpPathPrefix = ""
    }
}

# Pre-process string (URL-encode before send).
function preprocess(text) {
    return quote(text)
}

# Post-process string (remove any redundant whitespace).
function postprocess(text) {
    text = gensub(/ ([.,;:?!"])/, "\\1", "g", text)
    text = gensub(/(["]) /, "\\1", "g", text)
    return text
}

# Send an HTTP GET request and get response from an online translator.
function getResponse(text, sl, tl, hl,    content, header, isBody, url) {
    url = _RequestUrl(text, sl, tl, hl)

    header = "GET " url " HTTP/1.1\n"           \
        "Host: " HttpHost "\n"                  \
        "Connection: close\n"
    if (Option["user-agent"])
        header = header "User-Agent: " Option["user-agent"] "\n"
    if (Cookie)
        header = header "Cookie: " Cookie "\n"

    content = NULLSTR; isBody = 0
    print header |& HttpService
    while ((HttpService |& getline) > 0) {
        if (isBody)
            content = content ? content "\n" $0 : $0
        else if (length($0) <= 1)
            isBody = 1
        l(sprintf("%4s bytes > %s", length($0), $0))
    }
    close(HttpService)

    return assert(content, "[ERROR] Null response.")
}

# Print a string (to output file or terminal pager).
function p(string) {
    if (Option["view"])
        print string | Option["pager"]
    else
        print string > Option["output"]
}

# Play using a Text-to-Speech engine.
function play(text, tl,    url) {
    url = _TTSUrl(text, tl)

    # Don't use getline from pipe here - the same pipe will be run only once for each AWK script!
    system(Option["player"] " " parameterize(url) SUPOUT SUPERR)
}

# Get the translation of a string.
function getTranslation(text, sl, tl, hl,
                        isVerbose, toSpeech, returnPlaylist, returnIl) {
    return _Translate(text, sl, tl, hl,
                      isVerbose, toSpeech, returnPlaylist, returnIl)
}

# Translate a file.
function fileTranslation(uri,    group, temp1, temp2) {
    temp1 = Option["input"]
    temp2 = Option["verbose"]

    match(uri, /^file:\/\/(.*)/, group)
    Option["input"] = group[1]
    Option["verbose"] = 0

    translateMain()

    Option["input"] = temp1
    Option["verbose"] = temp2
}

# Start a browser session and translate a web page.
function webTranslation(uri, sl, tl, hl) {
    system(Option["browser"] " "                                \
           parameterize(_WebTranslateUrl(uri, sl, tl, hl)) "&")
}

# Translate the source text (into all target languages).
function translate(text, inline,
                   ####
                   i, j, playlist, il, saveSortedIn) {

    if (!getCode(Option["hl"])) {
        # Check if home language is supported
        w("[WARNING] Unknown language code: " Option["hl"] ", fallback to English: en")
        Option["hl"] = "en" # fallback to English
    } else if (isRTL(Option["hl"])) {
        # Check if home language is R-to-L
        if (!FriBidi)
            w("[WARNING] " getName(Option["hl"]) " is a right-to-left language, but FriBidi is not found.")
    }

    if (!getCode(Option["sl"])) {
        # Check if source language is supported
        w("[WARNING] Unknown source language code: " Option["sl"])
    } else if (isRTL(Option["sl"])) {
        # Check if source language is R-to-L
        if (!FriBidi)
            w("[WARNING] " getName(Option["sl"]) " is a right-to-left language, but FriBidi is not found.")
    }

    saveSortedIn = PROCINFO["sorted_in"]
    PROCINFO["sorted_in"] = "@ind_num_asc"
    for (i in Option["tl"]) {
        # Non-interactive verbose mode: separator between targets
        if (!Option["interactive"])
            if (Option["verbose"] && i > 1)
                p(prettify("target-seperator", replicate(Option["chr-target-seperator"], Option["width"])))

        if (inline &&
            startsWithAny(text, UriSchemes) == "file://") {
            # translate URL only from command-line parameters (inline)
            fileTranslation(text)
        } else if (inline &&
                   startsWithAny(text, UriSchemes) == "http://" ||
                   startsWithAny(text, UriSchemes) == "https://") {
            # translate URL only from command-line parameters (inline)
            webTranslation(text, Option["sl"], Option["tl"][i], Option["hl"])
        } else {
            p(getTranslation(text, Option["sl"], Option["tl"][i], Option["hl"], Option["verbose"], Option["play"], playlist, il))

            if (Option["play"] == 1) {
                if (Option["player"])
                    for (j in playlist)
                        play(playlist[j]["text"], playlist[j]["tl"])
                else if (SpeechSynthesizer)
                    for (j in playlist)
                        print playlist[j]["text"] | SpeechSynthesizer
            } else if (Option["play"] == 2) {
                if (Option["player"])
                    play(text, il[0])
                else if (SpeechSynthesizer)
                    print text | SpeechSynthesizer
            }
        }
    }
    PROCINFO["sorted_in"] = saveSortedIn
}

# Read from input and translate each line.
function translateMain(    i, line) {
    if (Option["interactive"])
        prompt()

    if (Option["input"] == STDIN || fileExists(Option["input"])) {
        i = 0
        while (getline line < Option["input"])
            if (line) {
                # Non-interactive verbose mode: separator between sources
                if (!Option["interactive"])
                    if (Option["verbose"] && i++ > 0)
                        p(prettify("source-seperator",
                                   replicate(Option["chr-source-seperator"],
                                             Option["width"])))

                if (Option["interactive"])
                    repl(line)
                else
                    translate(line)
            }
    } else
        e("[ERROR] File not found: " Option["input"])
}
