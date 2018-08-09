# Python 3
# Reads stdin: python preprocess-twitter.py
#
# Script for preprocessing tweets by Romain Paulus
# with small modifications by Jeffrey Pennington
# Converted to python by Sam leeman-Munk

#"tokenize" has been renamed to "normalize" with a helper function that normalizes and calls split

# http://nlp.stanford.edu/projects/glove/preprocess-twitter.rb

import re


def process_hashtag(hashtag):  # Split hashtags on uppercase letters
    #TODO - recognize all caps words and don't split them
    hashtag_body = hashtag.group(0)[1:]
    if re.search('[A-Z]', hashtag_body) and hashtag_body.upper() == hashtag_body:
        return "<hashtag> " + hashtag_body.lower() + " <allcaps>"
    else:
        return "<hashtag>" + re.sub(r"([A-Z])", r" \1", hashtag_body).lower()


def normalize(tweet):
    pieces = dict(
        eyes="[8:=;]",
        nose="['`\-]?",
        prechar="[^a-zA-Z0\d:-]" #the previous character - to avoid stuff like command: becoming comma <smile>
    )

    tweet = re.sub(r"https?:\/\/\S+\b|www\.(\w+\.)+\S*", "<url>", tweet)
    tweet = re.sub(r"({prechar})({eyes}{nose}[\\/|l*]+|[\\/|l*]+{eyes}{nose})".format(**pieces), r"\1<neutralface>", tweet)
    tweet = re.sub(r"/", " / ", tweet)
    tweet = re.sub(r"@\w+", "<user>", tweet)
    tweet = re.sub(r"({prechar})({eyes}{nose}[)dD]+|[(dD]+{nose}{eyes})".format(**pieces), r"\1<smile>", tweet)
    tweet = re.sub(r"({prechar}){eyes}{nose}[pP]+".format(**pieces), " <lolface>", tweet)
    tweet = re.sub(r"({prechar})({eyes}{nose}\(+|\)+{nose}{eyes})".format(**pieces), r"\1<sadface>", tweet)
    tweet = re.sub(r"<3", "<heart>", tweet)

    tweet = re.sub(r"#[a-zA-Z0-9_]+", process_hashtag,
                       tweet
                       )

    tweet = re.sub(r"[-+]?[.\d]*[\d]+[:,.\d]*", "<number>", tweet)

    # Mark punctuation repetitions (eg. "!!!" => "! <REPEAT>")
    tweet = re.sub(r"([!?.]){2,}",
        r"\1 <repeat>",
        tweet)

    # Mark elongated words (eg. "wayyyy" => "way <ELONG>")
    # TODO: determine if the end letter should be repeated once or twice (use lexicon/dict)

    tweet = re.sub(r"\b(\S*?)(.)\2{2,}\b",
           r"\1\2 <elong>",
           tweet)

    tweet = re.sub(r"([A-Z]){2,}", lambda word: word.group(0).lower() + " <allcaps> ", tweet)

    #Not sure why this was missing. Code to add spaces between tokens that normally are given together to make
    #tokenization easier
    tweet = re.sub("([$!?.,'\"\(\)&;])", r" \1 ", tweet)
    tweet = re.sub("(>)", r"\1 ", tweet)
    tweet = re.sub(r"\s+", " ", tweet)



    return tweet

def tokenize(tweet):
    return normalize(tweet).split(" ")

if __name__ == "__main__":
    tweet = "http://rocko.com good/bad @milord :) :-) 8) (: " \
            + ":ppppp :/// ///: :( :| :l l; <3 664.3 " \
            + "13212 #ThisIsAHashtag !!! wahoooooo! YEEEhaw YEEEHAW"\
            + "#ALLCAPS"
    print(normalize(tweet))
    print(tokenize(tweet))

    for token,expected in zip(tokenize(tweet),
                              ['<url>', 'good', '/', 'bad', '<user>', '<smile>', '<smile>', '<smile>', '<smile>',
                               '<lolface>', '<neutralface>', '<neutralface>', '<sadface>', '<neutralface>',
                               '<neutralface>', '<neutralface>', '<heart>', '<number>', '<number>', '<hashtag>',
                               'this', 'is', 'a', 'hashtag', '!', '<repeat>', 'waho', '<elong>', '!', 'yeee',
                               '<allcaps>', 'haw', 'yeeehaw', '<allcaps>', '<hashtag>', 'allcaps', '<allcaps>', '']):
        assert token==expected, token+"!="+expected

    tweet = "!!! overhaul:  2001:death-6 #1hashtag #AHASHTAG. &:) #1201"
    print(normalize(tweet))

    #Known Bug
    tweet = "#MACBaseball"
    print("Known bugs")
    print (tweet)
    print (normalize(tweet))
    print ("should be <hashtag> mac <allcaps> baseball")
    print("Can't fix without breaking #ThisisAHashtag")
