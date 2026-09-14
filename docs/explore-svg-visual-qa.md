# Keşfet SVG görsel QA

Değerlendirme, SVG’lerin mevcut fotoğrafik WebP kapaklarla aynı feed içinde yan yana durduğu senaryoya göre yapıldı.

| Asset | Karar | QA bulgusu |
|---|---|---|
| `ozempic-klinik-veri.svg` | REPLACE WITH WEBP | Grafik, kalem ve yuvarlatılmış kutular fazla geometrik; startup/vector pack hissi veriyor. Fotoğrafik klinik still-life ile değiştirilmesi gerekiyor. |
| `sporcu-beslenmesi-dengeli-tabak.svg` | REPLACE WITH WEBP | Tabak ve üç renkli bölme clipart gibi; gerçek yiyecek dokusu yok. Mevcut food WebP daha doğal. |
| `sporun-gune-etkisi-acik-hava.svg` | REPLACE WITH WEBP | Güneş, tepe ve figür tek stroke/flat shape diliyle ikon setine yaklaşıyor; hareket hissi crop’ta zayıf. |
| `bagirsak-diyetleri-lifli-gidalar.svg` | REPLACE WITH WEBP | Gıda şekilleri ve mikrobiyom çizgisi düz, dijital ve tıbbi semantiği belirsiz. Fotoğrafik lifli gıda kompozisyonu daha anlaşılır. |
| `sporcu-icecegi-hidrasyon-still-life.svg` | REPLACE WITH WEBP | Matara ve bardak doğru objeler olsa da tek renkli vektör blokları fotoğrafik kartların yanında yapay duruyor. |

Beş asset aynı stroke, düz dolgu ve basit geometrik form dilini paylaşıyor; birlikte kullanıldıklarında ayrı bir illustration pack gibi görünüyor. Bu nedenle minimum SVG rötuşu yapmak yerine beşinin de mevcut fotoğrafik WebP karşılığına dönülmesi daha tutarlı bulundu.
