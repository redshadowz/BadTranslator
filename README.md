# BadTranslator
Addon for badly translating messages in World of Warcraft(3.3.5).
This is something I've been working on for a while. It attempts to translate messages to English. It requires downloading language packs and building a detection database('/bt db') before using.  

https://github.com/redshadowz/Epoch-Language-Packs  

You can type /bt <message> to translate, but it's designed to be used by other addons. 'BT_TranslateString(message) returns 'translation', 'language ID'("de","fr", etc).  

Groupfinder comes with a very limited version of this because Lua databases are limited to something like 2^17(Lua 5.0) or 2^18(Lua 5.1) constants. By loading languages separately, I can reach this limit with every language. GroupFinder comes with multiple languages, but a very restricted database.  

This doesn't attempt to interpret the words based on usage. This is only a 1-to-1 translation of words/phrases stored in the databases. This is why I call it "BadTranslator", because the translation will often be almost unintelligible.  

This can be improved somewhat with better databases. But for proper translation, it would require...  

1) For me to actually speak the languages(the databases are from using frequency lists and automatic translation).  
2) Much greater processing power. This is designed to be as efficient as possible. If I tried to build a complex algorithm it would cause frame drops every time you received a message. This addon processes messages in a fraction of a millisecond.  

PS: Detection databases are based on example sentences from discord logs or from in-game messages. The addon reads the example sentences and looks for commonly-used words. I didn't have many example sentences. So I just scanned Turtle Discord for German/Russian/Spanish/French messages, and imported the Vanilla Quest descriptions. I have a lot more work to do with improving the databases. I'll update later.  

Most of the databases are more-or-less empty. I'll update them when I have more to work with.  
