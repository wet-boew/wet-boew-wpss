#***********************************************************************
#
# Name:   language_map.pm
#
# $Revision: 6267 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/TQA_Check/Tools/language_map.pm $
# $Date: 2013-05-22 09:38:08 -0400 (Wed, 22 May 2013) $
#
# Description:
#
#   This file contains declarations for dealing with language codes.
# The declaractions a placed in a seperate file simply because of the
# amount of code.  No subroutines are defined here, just variable
# declarations.
#
# Public functions:
#     ISO_639_2_Language_Code
#     Language_Valid
#
# Public variables:
#     %iso_639_2T_languages
#     %iso_639_1_iso_639_2T_map
#     %one_char_iso_639_2T_map
#     %language_iso_639_2T_map
#
# Terms and Conditions of Use
# 
# Unless otherwise noted, this computer program source code
# is covered under Crown Copyright, Government of Canada, and is 
# distributed under the MIT License.
# 
# MIT License
# 
# Copyright (c) 2011 Government of Canada
# 
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense, 
# and/or sell copies of the Software, and to permit persons to whom the 
# Software is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR 
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR 
# OTHER DEALINGS IN THE SOFTWARE.
# 
#***********************************************************************

package language_map;

#
# Can't use strict as the export of a variable conflicts with
# the my declaraction
#
#use strict;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(%iso_639_2T_languages
                  %iso_639_1_iso_639_2T_map
                  %one_char_iso_639_2T_map
                  %language_iso_639_2T_map
                  ISO_639_2_Language_Code
                  Language_Valid
                  );
    $VERSION = "1.0";
}

#
# 639-2/T language map (comment out those languages unlikely to be
# used to avoid a false errors).
#
%iso_639_2T_languages = (
#    "aar", "Afar",
#    "abk", "Abkhazian",
#    "ace", "Achinese",
#    "ach", "Acoli",
#    "ada", "Adangme",
#    "afa", "Afro-Asiatic",
#    "afh", "Afrihili",
#    "afr", "Afrikaans",
#    "ajm", "Aljamia",
#    "aka", "Akan",
#    "akk", "Akkadian",
#    "alb", "Albanian",
#    "ale", "Aleut",
#    "alg", "Algonquian languages",
#    "amh", "Amharic",
#    "ang", "English, Old",
#    "apa", "Apache languages",
    "ara", "Arabic",
    "arc", "Aramaic",
#    "arm", "Armenian",
#    "arn", "Araucanian",
#    "arp", "Arapaho",
#    "art", "Artificial",
#    "arw", "Arawak",
#    "asm", "Assamese",
#    "ath", "Athapascan languages",
#    "aus", "Australian languages",
#    "ava", "Avaric",
#    "ave", "Avestan",
#    "awa", "Awadhi",
#    "aym", "Aymara",
    "aze", "Azerbaijani",
#    "bad", "Banda",
#    "bai", "Bamileke languages",
#    "bak", "Bashkir",
#    "bal", "Baluchi",
#    "bam", "Bambara",
#    "ban", "Balinese",
#    "baq", "Basque",
#    "bas", "Basa",
#    "bat", "Baltic",
#    "bej", "Beja",
#    "bel", "Belarussian",
#    "bem", "Bemba",
#    "ben", "Bengali",
#    "ber", "Berber",
#    "bho", "Bhojpuri",
#    "bih", "Bihari",
#    "bik", "Bikol",
#    "bin", "Bini",
#    "bis", "Bislama",
#    "bla", "Siksika",
#    "bnt", "Bantu",
#    "bod", "Tibetan",
#    "bra", "Braj",
#    "bre", "Breton",
#    "btk", "Batak",
#    "bua", "Buriat",
#    "bug", "Buginese",
#    "bul", "Bulgarian",
#    "bur", "Burmese",
#    "cad", "Caddo",
#    "cai", "Central American Indian",
#    "car", "Carib",
#    "cat", "Catalan",
#    "cau", "Caucasian",
#    "ceb", "Cebuano",
#    "cel", "Celtic",
#    "ces", "Czech",
#    "cha", "Chamorro",
#    "chb", "Chibcha",
#    "che", "Chechen",
#    "chg", "Chagatai",
#    "chi", "Chinese",
#    "chk", "Chuukese",
#    "chm", "Mari",
#    "chn", "Chinook jargon",
#    "cho", "Choctaw",
#    "chp", "Chipewyan",
#    "chr", "Cherokee",
#    "chu", "Church Slavic",
#    "chv", "Chuvash",
#    "chy", "Cheyenne",
#    "cmc", "Chamic languages",
#    "cop", "Coptic",
#    "cor", "Cornish",
#    "cos", "Corsican",
#    "cpe", "Creoles and pidgins, English-based",
#    "cpf", "Creoles and pidgins, French-based",
#    "cpp", "Creoles and pidgins, Portuguese-based",
#    "cre", "Cree",
#    "crp", "Creoles and pidgins",
#    "cus", "Cushitic",
#    "cym", "Welsh",
#    "cze", "Czech",
#    "dak", "Dakota",
#    "dan", "Danish",
#    "day", "Dayak",
#    "del", "Delaware",
#    "den", "Slave",
#    "deu", "German",
#    "dgr", "Dogrib",
#    "din", "Dinka",
    "div", "Divehi",
#    "doi", "Dogri",
#    "dra", "Dravidian",
#    "dua", "Duala",
#    "dum", "Dutch, Middle",
    "dut", "Dutch",
#    "dyu", "Dyula",
#    "dzo", "Dzongkha",
#    "efi", "Efik",
#    "egy", "Egyptian",
#    "eka", "Ekajuk",
#    "ell", "Greek, Modern",
#    "elx", "Elamite",
    "eng", "English",
#    "enm", "English, Middle",
#    "epo", "Esperanto",
#    "est", "Estonian",
#    "eth", "Ethiopic",
#    "eus", "Basque",
#    "ewe", "Ewe",
#    "ewo", "Ewondo",
#    "fan", "Fang",
#    "fao", "Faroese",
    "fas", "Persian",
#    "fat", "Fanti",
#    "fij", "Fijian",
#    "fin", "Finnish",
#    "fiu", "Finno-Ugrian",
#    "fon", "Fon",
    "fra", "French",
#    "fre", "French",
#    "frm", "French, Middle",
#    "fro", "French, Old",
#    "fry", "Frisian",
#    "ful", "Fulah",
#    "fur", "Friulian",
#    "gaa", "Ga",
#    "gae", "Gaelic",
#    "gai", "Irish",
#    "gay", "Gayo",
#    "gba", "Gbaya",
#    "gdh", "Gaelic",
#    "gem", "Germanic",
#    "geo", "Georgian",
    "ger", "German",
#    "gez", "Geez",
#    "gil", "Gilbertese",
    "glg", "Gallegan",
#    "gmh", "German, Middle High",
#    "goh", "German, Old High",
#    "gon", "Gondi",
#    "gor", "Gorontalo",
#    "got", "Gothic",
#    "grb", "Grebo",
#    "grc", "Greek, Ancient",
#    "gre", "Greek, Modern",
#    "grn", "Guarani",
#    "guj", "Gujarati",
#    "gwi", "Gwich'in",
#    "hai", "Haida",
#    "hau", "Hausa",
#    "haw", "Hawaiian",
    "heb", "Hebrew",
#    "her", "Herero",
#    "hil", "Hiligaynon",
#    "him", "Himachali",
#    "hin", "Hindi",
#    "hit", "Hittite",
#    "hmn", "Hmong",
#    "hmo", "Hiri Motu",
#    "hrv", "Croatian",
#    "hun", "Hungarian",
#    "hup", "Hupa",
#    "hye", "Armenian",
#    "iba", "Iban",
#    "ibo", "Igbo",
#    "ice", "Icelandic",
#    "ijo", "Ijo",
#    "iku", "Inuktitut",
#    "ile", "Interlingue",
#    "ilo", "Iloko",
#    "ina", "Interlingua",
#    "inc", "Indic",
#    "ind", "Indonesian",
#    "ine", "Indo-European",
#    "ipk", "Inupiak",
#    "ira", "Iranian",
#    "iri", "Irish",
#    "iro", "Iroquoian languages",
#    "isl", "Icelandic",
    "ita", "Italian",
#    "jav", "Javanese",
#    "jaw", "Javanese",
#    "jpn", "Japanese",
#    "jpr", "Judeo-Persian",
#    "jrb", "Judeo-Arabic",
#    "kaa", "Kara-Kalpak",
#    "kab", "Kabyle",
#    "kac", "Kachin",
#    "kal", "Kalaallisut",
#    "kam", "Kamba",
#    "kan", "Kannada",
#    "kar", "Karen",
#    "kas", "Kashmiri",
#    "kat", "Georgian",
#    "kau", "Kanuri",
#    "kaw", "Kawi",
#    "kaz", "Kazakh",
#    "kha", "Khasi",
#    "khi", "Khoisan",
#    "khm", "Khmer",
#    "kho", "Khotanese",
#    "kik", "Kikuyu",
#    "kin", "Kinyarwanda",
#    "kir", "Kirghiz",
#    "kmb", "Kimbundu",
#    "kok", "Konkani",
#    "kom", "Komi",
#    "kon", "Kongo",
#    "kor", "Korean",
#    "kos", "Kosraean",
#    "kpe", "Kpelle",
#    "kro", "Kru",
#    "kru", "Kurukh",
#    "kua", "Kuanyama",
#    "kum", "Kumyk",
    "kur", "Kurdish",
#    "kut", "Kutenai",
#    "lad", "Ladino",
#    "lah", "Lahnda",
#    "lam", "Lamba",
#    "lao", "Lao",
#    "lat", "Latin",
#    "lav", "Latvian",
#    "lez", "Lezghian",
#    "lin", "Lingala",
#    "lit", "Lithuanian",
#    "lol", "Mongo",
#    "loz", "Lozi",
#    "ltz", "Ltzeburgesch",
#    "lua", "Luba-Lulua",
#    "lub", "Luba-Katanga",
#    "lug", "Ganda",
#    "lui", "Luiseno",
#    "lun", "Lunda",
#    "luo", "Luo",
#    "lus", "Lushai",
#    "mac", "Macedonian",
#    "mad", "Madurese",
#    "mag", "Magahi",
#    "mah", "Marshall",
#    "mai", "Maithili",
#    "mak", "Makasar",
#    "mal", "Malayalam",
#    "man", "Mandingo",
#    "mao", "Maori",
#    "map", "Austronesian",
#    "mar", "Marathi",
#    "mas", "Masai",
#    "max", "Manx",
#    "may", "Malay",
#    "mdr", "Mandar",
#    "men", "Mende",
#    "mga", "Irish, Middle",
#    "mic", "Micmac",
#    "min", "Minangkabau",
#    "mis", "Miscellaneous languages",
#    "mkd", "Macedonian",
#    "mkh", "Mon-Khmer",
#    "mlg", "Malagasy",
#    "mlt", "Maltese",
#    "mni", "Manipuri",
#    "mno", "Manobo languages",
#    "moh", "Mohawk",
#    "mol", "Moldavian",
#    "mon", "Mongolian",
#    "mos", "Mossi",
#    "mri", "Maori",
#    "msa", "Malay",
#    "mul", "Multiple languages",
#    "mun", "Munda languages",
#    "mus", "Creek",
#    "mwr", "Marwari",
#    "mya", "Burmese",
#    "myn", "Mayan languages",
#    "nah", "Aztec",
#    "nai", "North American Indian",
#    "nau", "Nauru",
#    "nav", "Navajo",
#    "nbl", "Ndebele, South",
#    "nde", "Ndebele, North",
#    "ndo", "Ndonga",
#    "nep", "Nepali",
#    "new", "Newari",
#    "nia", "Nias",
#    "nic", "Niger-Kordofanian",
#    "niu", "Niuean",
    "nld", "Dutch",
#    "non", "Norse, Old",
#    "nor", "Norwegian",
#    "nso", "Sohto, Northern",
#    "nub", "Nubian languages",
#    "nya", "Nyanja",
#    "nym", "Nyamwezi",
#    "nyn", "Nyankole",
#    "nyo", "Nyoro",
#    "nzi", "Nzima",
#    "oci", "Occitan",
#    "oji", "Ojibwa",
#    "ori", "Oriya",
#    "orm", "Oromo",
#    "osa", "Osage",
#    "oss", "Ossetic",
#    "ota", "Turkish, Ottoman",
#    "oto", "Otomian languages",
#    "paa", "Papuan",
#    "pag", "Pangasinan",
#    "pal", "Pahlavi",
#    "pam", "Pampanga",
#    "pan", "Panjabi",
#    "pap", "Papiamento",
#    "pau", "Palauan",
#    "peo", "Persian, Old",
    "per", "Persian",
#    "phi", "Philippine",
#    "phn", "Phoenician",
#    "pli", "Pali",
#    "pol", "Polish",
#    "pon", "Pohnpeian",
    "por", "Portuguese",
#    "pra", "Prakrit languages",
#    "pro", "Provenal, Old",
#    "pus", "Pushto",
#    "qaa-qtz", "reserved for local use",
#    "que", "Quechua",
#    "raj", "Rajasthani",
#    "rap", "Rapanui",
#    "rar", "Rarotongan",
#    "roa", "Romance",
#    "roh", "Rhaeto-Romance",
#    "rom", "Romany",
#    "ron", "Romanian",
#    "rum", "Romanian",
#    "run", "Rundi",
#    "rus", "Russian",
#    "sad", "Sandawe",
#    "sag", "Sango",
#    "sai", "South American Indian",
#    "sal", "Salishan languages",
#    "sam", "Samaritan Aramaic",
#    "san", "Sanskrit",
#    "sas", "Sasak",
#    "sat", "Santali",
#    "scc", "Serbian",
#    "sco", "Scots",
#    "scr", "Croatian",
#    "sel", "Selkup",
#    "sem", "Semitic",
#    "sga", "Irish, Old",
#    "shn", "Shan",
#    "sid", "Sidamo",
#    "sin", "Sinhalese",
#    "sio", "Siouan languages",
#    "sit", "Sino-Tibetan",
#    "sla", "Slavic",
#    "slk", "Slovak",
#    "slo", "Slovak",
#    "slv", "Slovenian",
#    "smi", "Smi languages",
#    "smo", "Samoan",
#    "sna", "Shona",
#    "snd", "Sindhi",
#    "snk", "Soninke",
#    "sog", "Sogdian",
#    "som", "Somali",
#    "son", "Songhai",
#    "sot", "Sotho, Southern",
    "spa", "Spanish",
#    "sqi", "Albanian",
#    "srd", "Sardinian",
#    "srp", "Serbian",
#    "srr", "Serer",
#    "ssa", "Nilo-Saharan",
#    "ssw", "Swati",
#    "suk", "Sukuma",
#    "sun", "Sundanese",
#    "sus", "Susu",
#    "sux", "Sumerian",
#    "swa", "Swahili",
#    "swe", "Swedish",
#    "syr", "Syriac",
#    "tah", "Tahitian",
#    "tai", "Tai",
#    "tam", "Tamil",
#    "tat", "Tatar",
#    "tel", "Telugu",
#    "tem", "Timne",
#    "ter", "Tereno",
#    "tet", "Tetum",
#    "tgk", "Tajik",
#    "tgl", "Tagalog",
#    "tha", "Thai",
#    "tib", "Tibetan",
#    "tig", "Tigre",
#    "tir", "Tigrinya",
#    "tiv", "Tiv",
#    "tkl", "Tokelau",
#    "tli", "Tlingit",
#    "tmh", "Tamashek",
#    "tog", "Tonga",
#    "ton", "Tonga",
#    "tpi", "Tok Pisin",
#    "tsi", "Tsimshian",
#    "tsn", "Tswana",
#    "tso", "Tsonga",
#    "tuk", "Trkmen",
#    "tum", "Tumbuka",
#    "tur", "Turkish",
#    "tut", "Altaic",
#    "tvl", "Tuvalu",
#    "twi", "Twi",
#    "tyv", "Tuvinian",
#    "uga", "Ugaritic",
#    "uig", "Uighur",
#    "ukr", "Ukrainian",
#    "umb", "Umbundu",
#    "und", "Undetermined",
    "urd", "Urdu",
#    "uzb", "Uzbek",
#    "vai", "Vai",
#    "ven", "Venda",
#    "vie", "Vietnamese",
#    "vol", "Volapk",
#    "vot", "Votic",
#    "wak", "Wakashan languages",
#    "wal", "Walamo",
#    "war", "Waray",
#    "was", "Washo",
#    "wel", "Welsh",
#    "wen", "Sorbian languages",
#    "wol", "Wolof",
#    "xho", "Xhosa",
#    "yao", "Yao",
#    "yap", "Yapese",
#    "yid", "Yiddish",
#    "yor", "Yoruba",
#    "ypk", "Yupik languages",
#    "zap", "Zapotec",
#    "zen", "Zenaga",
#    "zha", "Zhuang",
#    "zho", "Chinese",
#    "znd", "Zande",
#    "zul", "Zulu",
#    "zun", "Zui",
);

#
# ISO 639-1 (2 character) to 639-2/T (3 character) language map
# (comment out those languages unlikely to be used to avoid a false errors).
#
%iso_639_1_iso_639_2T_map = (
#    "aa", "aar",
#    "ab", "abk",
#    "ae", "ave",
#    "af", "afr",
#    "ak", "aka",
#    "am", "amh",
#    "an", "arg",
    "ar", "ara",
#    "as", "asm",
#    "av", "ava",
#    "ay", "aym",
    "az", "aze",
#    "ba", "bak",
#    "be", "bel",
#    "bg", "bul",
#    "bh", "bih",
#    "bi", "bis",
#    "bm", "bam",
#    "bn", "ben",
#    "bo", "tib",
#    "br", "bre",
#    "bs", "bos",
#    "ca", "cat",
#    "ce", "che",
#    "ch", "cha",
#    "co", "cos",
#    "cr", "cre",
#    "cs", "cze",
#    "cu", "chu",
#    "cv", "chv",
#    "cy", "wel",
#    "da", "dan",
    "de", "ger",
    "dv", "div",
#    "dz", "dzo",
#    "ee", "ewe",
#    "el", "gre",
    "en", "eng",
#    "eo", "epo",
    "es", "spa",
#    "et", "est",
#    "eu", "baq",
#    "eu", "eus",
    "fa", "per",
#    "ff", "ful",
#    "fi", "fin",
#    "fj", "fij",
#    "fo", "fao",
    "fr", "fra",
#    "fy", "fry",
#    "ga", "gle",
#    "gd", "gla",
#    "gl", "glg",
#    "gn", "grn",
#    "gu", "guj",
#    "gv", "glv",
#    "ha", "hau",
    "he", "heb",
#    "hi", "hin",
#    "ho", "hmo",
#    "hr", "hrv",
#    "ht", "hat",
#    "hu", "hun",
#    "hy", "arm",
#    "hz", "her",
#    "ia", "ina",
#    "id", "ind",
#    "ie", "ile",
#    "ig", "ibo",
#    "ii", "iii",
#    "ik", "ipk",
#    "io", "ido",
#    "is", "ice",
    "it", "ita",
#    "iu", "iku",
#    "ja", "jpn",
#    "jv", "jav",
#    "ka", "geo",
#    "kg", "kon",
#    "ki", "kik",
#    "kj", "kua",
#    "kk", "kaz",
#    "kl", "kal",
#    "km", "khm",
#    "kn", "kan",
#    "ko", "kor",
#    "kr", "kau",
#    "ks", "kas",
    "ku", "kur",
#    "kv", "kom",
#    "kw", "cor",
#    "ky", "kir",
#    "la", "lat",
#    "lb", "ltz",
#    "lg", "lug",
#    "li", "lim",
#    "ln", "lin",
#    "lo", "lao",
#    "lt", "lit",
#    "lu", "lub",
#    "lv", "lav",
#    "mg", "mlg",
#    "mh", "mah",
#    "mi", "mao",
#    "mk", "mac",
#    "ml", "mal",
#    "mn", "mon",
#    "mr", "mar",
#    "ms", "may",
#    "mt", "mlt",
#    "my", "bur",
#    "na", "nau",
#    "nb", "nob",
#    "nd", "nde",
#    "ne", "nep",
#    "ng", "ndo",
    "nl", "dut",
#    "nn", "nno",
#    "no", "nor",
#    "nr", "nbl",
#    "nv", "nav",
#    "ny", "nya",
#    "oc", "oci",
#    "oj", "oji",
#    "om", "orm",
#    "or", "ori",
#    "os", "oss",
#    "pa", "pan",
#    "pi", "pli",
#    "pl", "pol",
#    "ps", "pus",
    "pt", "por",
#    "qu", "que",
#    "rm", "roh",
#    "rn", "run",
#    "ro", "rum",
#    "ru", "rus",
#    "rw", "kin",
#    "sa", "san",
#    "sc", "srd",
#    "sd", "snd",
#    "se", "sme",
#    "sg", "sag",
#    "si", "sin",
#    "sk", "slo",
#    "sl", "slv",
#    "sm", "smo",
#    "sn", "sna",
#    "so", "som",
#    "sq", "sqi",
#    "sr", "srp",
#    "ss", "ssw",
#    "st", "sot",
#    "su", "sun",
#    "sv", "swe",
#    "sw", "swa",
#    "ta", "tam",
#    "te", "tel",
#    "tg", "tgk",
#    "th", "tha",
#    "ti", "tir",
#    "tk", "tuk",
#    "tl", "tgl",
#    "tn", "tsn",
#    "to", "ton",
#    "tr", "tur",
#    "ts", "tso",
#    "tt", "tat",
#    "tw", "twi",
#    "ty", "tah",
#    "ug", "uig",
#    "uk", "ukr",
    "ur", "urd",
#    "uz", "uzb",
#    "ve", "ven",
#    "vi", "vie",
#    "vo", "vol",
#    "wa", "wln",
#    "wo", "wol",
#    "xh", "xho",
#    "yi", "yid",
#    "yo", "yor",
#    "za", "zha",
#    "zh", "chi",
#    "zu", "zul",
);

#
# ISO 639-2/T (3 character) terminology to 639-2/B (3 character) bibliographic
# language map (comment out those languages unlikely to be used to avoid
# a false errors).
#
%iso_639_2T_iso_639_2B_map = (
    "bod", "tib",
    "ces", "cze",
    "cym", "wel",
    "deu", "ger",
    "eus", "baq",
    "ell", "gre",
    "fas", "per",
    "hye", "arm",
#    "fra", "fre", # Leave fra as the code for French
    "isl", "ice",
    "kat", "geo",
    "mkd", "mac",
    "mri", "mao",
    "msa", "may",
    "mya", "bur",
    "nld", "dut",
    "ron", "rum",
    "slk", "slo",
    "sqi", "alb",
    "zho", "chi",
);

#
# 1 character to 639-2/T (3 character) language map (used in PWGSC file names
# to defined content language).
#
%one_char_iso_639_2T_map = (
    "e", "eng",
    "f", "fra",
);

#
# Language to 639-2/T (3 character) language map (only a few languages
# are handled here).
#
%language_iso_639_2T_map = (
    "english", "eng",
    "francais", "fra",
);

#***********************************************************************
#
# Name: ISO_639_2_Language_Code
#
# Parameters: lang - language code
#
# Description:
#
#   This function converts the supplied language code (1, 2 or 3 characters)
# into an ISO 639.2 3 letter language code.  If no matching code is found,
# the supplied language is returned.  Any dialect suffix is stripped of
# the language provided.
#
#***********************************************************************
sub ISO_639_2_Language_Code {
    my ($lang) = @_;

    #
    # Strip off any possible dialect from the language code
    # e.g. en-US becomes en.
    #
    $lang =~ s/-.*//g;

    #
    # Convert language to lower case
    #
    $lang = lc($lang);

    #
    # Convert possible 2 character language code into a 3 character code.
    #
    if ( defined($iso_639_1_iso_639_2T_map{$lang}) ) {
        $lang = $iso_639_1_iso_639_2T_map{$lang};
    }

    #
    # Convert any terminology language code to a bibliographic code.
    #
    if ( defined($iso_639_2T_iso_639_2B_map{$lang}) ) {
        $lang = $iso_639_2T_iso_639_2B_map{$lang};
    }

    #
    # Return language code
    #
    return($lang);
}

#***********************************************************************
#
# Name: Language_Valid
#
# Parameters: lang - language string
#
# Description:
#
#   This function checks to see if the language string follows the
# syntax of BCP 47 (https://tools.ietf.org/html/bcp47).  It does not
# verify the actual language code values.
#
#***********************************************************************
sub Language_Valid {
    my ($lang) = @_;
    
    my ($valid) = 0;

    #
    # Check for grandfathered irregular language codes
    #   "en-GB-oed"
    #   "i-<3 to 8 characters>
    #   "sgn-<2 characters>-<2 characters>
    #
    if ( $lang =~ /^(en\-GB\-oed)|(i\-[a-z]{3,8})|(sgn\-[A-Z]{2}\-[A-Z]{2})$/ ) {
        $valid = 1;
    }
    #
    # Check for grandfathered regular language codes
    #   <2 or 3 characters>-<3 or more characters>
    #   <2 characters>-<3 characters>-<3 characters>
    #
    elsif ( $lang =~ /^([a-z]{2,3}\-[a-z]{3,})|([a-z]{2}\-[a-z]{3}\-[a-z]{3})$/ ) {
        $valid = 1;
    }
    #
    # Check for private use language
    #    leading x-
    #
    elsif ( $lang =~ /^x\-[a-z0-9]+$/i ) {
        $valid = 1;
    }
    #
    # Regular language
    #   <2 or 3 characters>
    #
    elsif ( $lang =~ /^([a-z]{2,3})$/ ) {
        $valid = 1;
    }
    #
    # Regular language
    #   <2 or 3 characters>-<2 or 3 characters>
    #
    elsif ( $lang =~ /^([a-z]{2,3}\-[a-z]{2,3})$/ ) {
        $valid = 1;
    }
    #
    # Regular language
    #   <2 or 3 characters>-<3 or more characters>
    #
    elsif ( $lang =~ /^([a-z]{2,3}\-[a-z]{3,}(\-[a-z]+)*)$/ ) {
        $valid = 1;
    }

    #
    # Return validity
    #
    #print "Language_Valid lang = \"$lang\", valid = $valid\n";
    return($valid);
}

#***********************************************************************
#
# Mainline
#
#***********************************************************************

#
# Return true to indicate we loaded successfully
#
return 1;


