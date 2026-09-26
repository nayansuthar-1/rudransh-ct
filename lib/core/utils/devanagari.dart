/// Writes Hinglish (Hindi typed in English letters, e.g. `Shadi`) in
/// Devanagari (`शादी`), for the Hindi certificate. Text already in Devanagari,
/// digits and punctuation are left as they are.
///
/// Words the trust uses are looked up in [_known], spelled as Hindi writes
/// them. Any other word is spelled out by sound, which is close but not
/// always exact: Hinglish does not show long vowels (`shadi` is शादी, not
/// शदी), so the office can type the Hindi itself where it matters.
String toDevanagari(String text) => text.replaceAllMapped(
      RegExp('[A-Za-z]+'),
      (m) {
        final word = m[0]!.toLowerCase();
        return _known[word] ?? _bySound(word);
      },
    );

/// Hinglish spellings of words that name the trust's schemes.
const _known = {
  'shadi': 'शादी',
  'shaadi': 'शादी',
  'sadi': 'शादी',
  'saadi': 'शादी',
  'shadee': 'शादी',
  'mayra': 'मायरा',
  'mayara': 'मायरा',
  'maayra': 'मायरा',
  'maayara': 'मायरा',
  'mahyra': 'मायरा',
  'maira': 'मायरा',
  'mayro': 'मायरा',
  'mayaro': 'मायरा',
  'mamera': 'मामेरा',
  'mameraa': 'मामेरा',
  'mamero': 'मामेरा',
  'mameru': 'मामेरा',
  'mamaera': 'मामेरा',
  'suraksha': 'सुरक्षा',
  'surakshaa': 'सुरक्षा',
  'suraksa': 'सुरक्षा',
  'surksha': 'सुरक्षा',
  'parivar': 'परिवार',
  'pariwar': 'परिवार',
  'parivaar': 'परिवार',
  'pariwaar': 'परिवार',
  'parivarik': 'पारिवारिक',
  'sarv': 'सर्व',
  'sarva': 'सर्व',
  'samaj': 'समाज',
  'samaaj': 'समाज',
  'vivah': 'विवाह',
  'vivaah': 'विवाह',
  'viwah': 'विवाह',
  'kanya': 'कन्या',
  'kanyadan': 'कन्यादान',
  'kanyadaan': 'कन्यादान',
  'beti': 'बेटी',
  'mrityu': 'मृत्यु',
  'mrutyu': 'मृत्यु',
  'mratyu': 'मृत्यु',
  'jivan': 'जीवन',
  'jeevan': 'जीवन',
  'bima': 'बीमा',
  'beema': 'बीमा',
  'shiksha': 'शिक्षा',
  'siksha': 'शिक्षा',
  'seva': 'सेवा',
  'sewa': 'सेवा',
  'kalyan': 'कल्याण',
  'kalyaan': 'कल्याण',
  'mahila': 'महिला',
  'swasthya': 'स्वास्थ्य',
  'nidhi': 'निधि',
  'sammelan': 'सम्मेलन',
  'samuhik': 'सामूहिक',
  'samoohik': 'सामूहिक',
  'sanskar': 'संस्कार',
  'sanskaar': 'संस्कार',
  'antim': 'अंतिम',
  'vidhva': 'विधवा',
  'vidhwa': 'विधवा',
  'sahayata': 'सहायता',
  'rudransh': 'रुद्रांश',
  'mandal': 'मंडल',
  'ekta': 'एकता',
  'lagna': 'लग्न',
};

/// Vowels as (on their own, after a consonant), longest spelling first.
const _vowels = [
  ('aa', ('आ', 'ा')),
  ('ai', ('ऐ', 'ै')),
  ('au', ('औ', 'ौ')),
  ('ee', ('ई', 'ी')),
  ('ii', ('ई', 'ी')),
  ('oo', ('ऊ', 'ू')),
  ('uu', ('ऊ', 'ू')),
  ('a', ('अ', '')),
  ('i', ('इ', 'ि')),
  ('u', ('उ', 'ु')),
  ('e', ('ए', 'े')),
  ('o', ('ओ', 'ो')),
];

/// Consonants, longest spelling first.
const _consonants = [
  ('ksh', 'क्ष'),
  ('chh', 'छ'),
  ('kh', 'ख'),
  ('gh', 'घ'),
  ('ch', 'च'),
  ('jh', 'झ'),
  ('th', 'थ'),
  ('dh', 'ध'),
  ('ph', 'फ'),
  ('bh', 'भ'),
  ('sh', 'श'),
  ('k', 'क'),
  ('g', 'ग'),
  ('c', 'क'),
  ('j', 'ज'),
  ('t', 'त'),
  ('d', 'द'),
  ('n', 'न'),
  ('p', 'प'),
  ('f', 'फ'),
  ('b', 'ब'),
  ('m', 'म'),
  ('y', 'य'),
  ('r', 'र'),
  ('l', 'ल'),
  ('v', 'व'),
  ('w', 'व'),
  ('s', 'स'),
  ('h', 'ह'),
  ('z', 'ज'),
  ('q', 'क'),
  ('x', 'क्स'),
];

/// Before these an `n` or `m` is a nasal (anusvara): `mandal` → मंडल.
const _stops = {
  'k', 'kh', 'g', 'gh', 'c', 'ch', 'chh', 'j', 'jh',
  't', 'th', 'd', 'dh', 'p', 'ph', 'b', 'bh',
};

(String, T)? _at<T>(String w, int i, List<(String, T)> table) {
  for (final entry in table) {
    if (w.startsWith(entry.$1, i)) return entry;
  }
  return null;
}

/// Spells a lowercase Latin word by sound. A consonant followed by another
/// joins it (`dharm` → धर्म); a final `a` or `i` is long, as Hinglish usually
/// means it (`raksha` → रक्षा).
String _bySound(String w) {
  final out = <String>[];
  String? prevConsonant;
  var i = 0;
  while (i < w.length) {
    final vowel = _at(w, i, _vowels);
    if (vowel != null) {
      final (key, (alone, sign)) = vowel;
      final last = i + key.length == w.length;
      if (prevConsonant == null) {
        out.add(alone);
      } else if (last && key == 'a') {
        out.add('ा');
      } else if (last && key == 'i') {
        out.add('ी');
      } else {
        out.add(sign);
      }
      prevConsonant = null;
      i += key.length;
      continue;
    }
    final consonant = _at(w, i, _consonants);
    if (consonant == null) {
      out.add(w[i]);
      prevConsonant = null;
      i++;
      continue;
    }
    final (key, letter) = consonant;
    if (prevConsonant != null) {
      if ((prevConsonant == 'n' || prevConsonant == 'm') && _stops.contains(key)) {
        out[out.length - 1] = 'ं';
      } else {
        out.add('्');
      }
    }
    out.add(letter);
    prevConsonant = key;
    i += key.length;
  }
  return out.join();
}
