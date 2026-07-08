/// Model çıktısından ilk `{` ile son `}` arasındaki JSON nesnesini ayıklar.
///
/// Claude 4.6+ modellerinde assistant-prefill (yanıtı `{` ile başlatma hilesi)
/// API tarafından 400 ile reddedildiği için JSON isteyen çağrılar artık düz
/// metin yanıt alır; model buna markdown çiti veya kısa bir açıklama
/// ekleyebilir. Bu yardımcı, JSON bekleyen her AI çağrısının tek ayıklama
/// noktasıdır.
///
/// JSON nesnesi bulunamazsa `null` döner — çağıran taraf fallback'ine düşer.
String? extractJsonObject(String text) {
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start == -1 || end <= start) return null;
  return text.substring(start, end + 1);
}
