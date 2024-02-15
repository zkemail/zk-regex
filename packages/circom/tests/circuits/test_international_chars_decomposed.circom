pragma circom 2.1.5;

include "./international_chars_decomposed.circom";
// Latin-Extension=[¡-ƿ]+ Greek=[Ͱ-Ͽ]+ Cyrillic=[Ѐ-ӿ]+ Arabic=[؀-ۿ]+ Devanagari=[ऀ-ॿ]+ Hiragana&Katakana=[ぁ-ヿ]+
component main = InternationalCharsDecomposed(128);