####################################################################
# BingTranslator.awk                                               #
####################################################################
#
# Last Updated: 18 May 2016
BEGIN { provides("bing") }

function bingInit() {
    HttpProtocol = "http://"
    HttpHost = "www.bing.com"
    HttpPort = 80
}

# Retrieve the Cookie needed.
function bingSetCookie(    cookie, group, header, url) {
    url = HttpPathPrefix "/translator"

    header = "GET " url " HTTP/1.1\n"                                   \
        "Host: " HttpHost "\n"                                          \
        "Connection: close\n"
    if (Option["user-agent"])
        header = header "User-Agent: " Option["user-agent"] "\n"

    cookie = NULLSTR
    print header |& HttpService
    while ((HttpService |& getline) > 0 && length($0) > 1) {
        match($0, /Set-Cookie: ([^;]*);/, group)
        if (group[1]) {
            cookie = cookie (cookie ?  "; " : NULLSTR) group[1]
        }
        l(sprintf("%4s bytes > %s", length($0), length($0) < 1024 ? $0 : "..."))
    }
    close(HttpService)
    Cookie = cookie
}

# TTS -- FIXME!
function bingTTSUrl(text, tl,    narrator) {
    narrator = Option["narrator"] ~ /^[AFaf]/ ? "female" : "male"
    # FIXME:
    # 1. use digraphia code (en-US) as Alpha-2 code alone doen't work
    # 2. how to pass cookies to an external player?
    return HttpProtocol HttpHost "/translator/api/language/Speak?"      \
        "locale=" tl "&text=" preprocess(text)                          \
        "&gender=" narrator "&media=audio/mp3"
}

function bingWebTranslateUrl(uri, sl, tl, hl) {
    return "http://www.microsofttranslator.com/bv.aspx?"        \
        "from=" sl "&to=" tl "&a=" uri
}

# Send an HTTP POST request and get response from Bing Translator.
function bingPost(text, sl, tl, hl,
                  ####
                  content, contentLength, group,
                  header, isBody, reqBody, url) {
    reqBody = "[{" parameterize("text") ":" parameterize(text, "\"") "}]"
    contentLength = dump(reqBody, group)

    url = HttpPathPrefix "/translator/api/Translate/TranslateArray?"    \
        "from=" sl "&to=" tl

    header = "POST " url " HTTP/1.1\n"                  \
        "Host: " HttpHost "\n"                          \
        "Connection: close\n"                           \
        "Content-Length: " contentLength "\n"           \
        "Content-Type: application/json\n"     # must!
    if (Option["user-agent"])
        header = header "User-Agent: " Option["user-agent"] "\n"
    if (Cookie)
        header = header "Cookie: " Cookie "\n" # must!

    content = NULLSTR; isBody = 0
    print (header "\n" reqBody) |& HttpService
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

# Dictionary API (via HTTP GET).
function bingRequestUrl(text, sl, tl, hl) {
    return HttpPathPrefix "/translator/api/Dictionary/Lookup?"  \
        "from=" sl "&to=" tl "&text=" preprocess(text)
}

# Get the translation of a string.
function bingTranslate(text, sl, tl, hl,
                       isVerbose, toSpeech, returnPlaylist, returnIl,
                       ####
                       r,
                       content, tokens, ast,
                       _sl, _tl, _hl, il,
                       translation,
                       wShowOriginal, wShowTranslation, wShowLanguages,
                       group, temp) {
    if (!getCode(tl)) {
        # Check if target language is supported
        w("[WARNING] Unknown target language code: " tl)
    } else if (isRTL(tl)) {
        # Check if target language is R-to-L
        if (!FriBidi)
            w("[WARNING] " getName(tl) " is a right-to-left language, but FriBidi is not found.")
    }
    _sl = getCode(sl); if (!_sl) _sl = sl
    _tl = getCode(tl); if (!_tl) _tl = tl
    _hl = getCode(hl); if (!_hl) _hl = hl

    # Hot-patches for Bing's own translator language codes
    # See: <https://msdn.microsoft.com/en-us/library/hh456380.aspx>
    if (_sl == "auto")  _sl = "-"
    if (_sl == "bs")    _sl = "bs-Latn" # 'bs' is not recognized as valid code
    if (_sl == "zh-CN") _sl = "zh-CHS"
    if (_sl == "zh-TW") _sl = "zh-CHT"
    if (_tl == "bs")    _tl = "bs-Latn"
    if (_tl == "zh-CN") _tl = "zh-CHS"
    if (_tl == "zh-TW") _tl = "zh-CHT"

    bingSetCookie() # must!

    content = bingPost(text, _sl, _tl, _hl)
    tokenize(tokens, content)
    parseJson(ast, tokens)

    l(content, "content", 1, 1)
    l(tokens, "tokens", 1, 0, 1)
    l(ast, "ast")
    if (!isarray(ast) || !anything(ast)) {
        e("[ERROR] Oops! Something went wrong and I can't translate it for you :(")
        ExitCode = 1
        return
    } else if (ast[0 SUBSEP "Message"]) {
        e("[ERROR] " unparameterize(ast[0 SUBSEP "Message"]))
        e("[ERROR] " unparameterize(ast[0 SUBSEP "Details" SUBSEP 0]))
        ExitCode = 1
        return
    }

    translation = unparameterize(ast[0 SUBSEP "items" SUBSEP 0 SUBSEP "text"])

    returnIl[0] = il = unparameterize(ast[0 SUBSEP "from"])
    if (Option["verbose"] < 0)
        return getList(il)

    # Generate output
    if (!isVerbose) {
        # Brief mode
        r = translation

    } else {
        # Verbose mode

        wShowOriginal = Option["show-original"]
        wShowTranslation = Option["show-translation"]
        wShowLanguages = Option["show-languages"]
        wShowDictionary = Option["show-dictionary"]

        if (wShowOriginal) {
            # Display: original text
            if (r) r = r RS RS
            r = r m("-- display original text")
            r = r prettify("original", s(text, il))
        }

        if (wShowTranslation) {
            # Display: major translation
            if (r) r = r RS RS
            r = r m("-- display major translation")
            r = r prettify("translation", s(translation, tl))
        }

        if (wShowLanguages) {
            # Display: source language -> target language
            if (r) r = r RS RS
            r = r m("-- display source language -> target language")
            temp = Option["fmt-languages"]
            if (!temp) temp = "[ %s -> %t ]"
            split(temp, group, /(%s|%S|%t|%T)/)
            r = r prettify("languages", group[1])
            if (temp ~ /%s/)
                r = r prettify("languages-sl", getDisplay(il))
            if (temp ~ /%S/)
                r = r prettify("languages-sl", getName(il))
            r = r prettify("languages", group[2])
            if (temp ~ /%t/)
                r = r prettify("languages-tl", getDisplay(tl))
            if (temp ~ /%T/)
                r = r prettify("languages-tl", getName(tl))
            r = r prettify("languages", group[3])
        }

        if (wShowDictionary && false) { # FIXME!
            # Dictionary API
            # Note: source language must be identified
            dicContent = getResponse(text, il, _tl, _hl)
            tokenize(dicTokens, dicContent)
            parseJson(dicAst, dicTokens) # FIXME: inefficient parser

            if (anything(dicAst)) {
                # Display: dictionary entries
                if (r) r = r RS
                r = r m("-- display dictionary entries")

                # TODO
            }
        }
    }

    if (toSpeech) {
        returnPlaylist[0]["text"] = translation
        returnPlaylist[0]["tl"] = tl
    }

    return r
}
