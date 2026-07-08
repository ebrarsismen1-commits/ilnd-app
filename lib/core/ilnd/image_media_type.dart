import 'dart:typed_data';

/// Görselin gerçek MIME türünü dosya imzasından (magic bytes) tespit eder.
///
/// AI'a giden her görselde media_type bildirilmek zorunda ve YANLIŞ bildirmek
/// Anthropic'ten 400 döndürür ("media type mismatch"). Uzantıya veya picker'ın
/// söylediğine güvenilmez — web'de galeriden PNG/WebP gelebilir; tek güvenilir
/// kaynak baytların kendisidir.
///
/// Anthropic'in desteklediği dört türü tanır; tanınmayan biçimde `null` döner
/// (çağıran taraf kullanıcıya "desteklenmeyen biçim" göstermeli).
String? detectImageMediaType(Uint8List bytes) {
  if (bytes.length < 12) return null;
  // JPEG: FF D8 FF
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  // PNG: 89 50 4E 47
  if (bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  // GIF: "GIF8"
  if (bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38) {
    return 'image/gif';
  }
  // WebP: "RIFF"...."WEBP"
  if (bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return null;
}
