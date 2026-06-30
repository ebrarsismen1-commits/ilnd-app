# Release imzalama (Play Store yüklemesi için zorunlu)

`build.gradle.kts` artık `android/key.properties` varsa otomatik olarak onu
kullanır; yoksa debug key'ine düşer (Play Console bunu kabul etmez).

Bu makinede JDK/`keytool` kurulu olmadığı için keystore'u burada
oluşturamadım — ayrıca bu, **kaybedilirse geri dönüşü olmayan** bir
kimlik bilgisi (keystore'unu kaybedersen Play Store'da uygulamanı bir daha
güncelleyemezsin, yeni bir paket adıyla sıfırdan yayınlaman gerekir). Bu
yüzden kendi makinende, Android Studio kurulu bir ortamda oluşturup
güvenli bir yere (parola yöneticisi + ayrı bir bulut yedek) koyman gerekiyor.

## 1. Keystore oluştur

```bash
keytool -genkey -v -keystore ~/ilnd-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias ilnd-upload
```

Sorulan parolaları ve `ilnd-upload-keystore.jks` dosyasını **kaybetmeyecek
şekilde** sakla.

## 2. `android/key.properties` oluştur

`android/key.properties` dosyasını (zaten `.gitignore`'da, asla commit
edilmez) şu içerikle oluştur:

```
storePassword=<keystore parolası>
keyPassword=<key parolası>
keyAlias=ilnd-upload
storeFile=/mutlak/yol/ilnd-upload-keystore.jks
```

## 3. Doğrula

```bash
flutter build appbundle --release
```

Build loglarında "Signing with the debug keys" uyarısı görünmemeli.

## iOS

iOS tarafında imzalama Xcode/App Store Connect üzerinden yönetiliyor
(provisioning profile + distribution certificate) — bu Android keystore'una
karşılık gelen ayrı bir adım, App Store Connect hesabı gerektirir ve kod
değişikliği değildir.
