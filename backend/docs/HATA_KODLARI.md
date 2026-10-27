# HATA KODU SÖZLÜĞÜ (MSSQL 50001+ & REST API EŞLEMESİ)

Bu belge, veritabanı katmanında (Trigger, Stored Procedure ve Kısıtlar) fırlatılan özel iş kuralı hata numaralarını (`50001` ve üzeri) ve bu hataların Flask Backend API katmanında hangi HTTP durum kodlarına ve kullanıcı mesajlarına dönüştürüleceğini tanımlayan resmi sözleşmedir.

---

## 1. Hata Yönetimi Felsefesi ve Tasarım Kararı

1. **Özel Hata Numaraları (50001+):**
   - MSSQL'de `1` ile `50000` arasındaki hata numaraları SQL Server sistem hatalarına (Syntax error, Foreign Key ihlali, Primary Key ihlali vb.) ayrılmıştır.
   - Uygulama ve veritabanı mühendisleri kendi iş kuralı ihlallerini `THROW 50001, N'[50001] ...', 1;` biçiminde **50001 ve üzerindeki** numaralarla fırlatmalıdır.
2. **pyodbc Hata Ayrıştırma Standardı (R6 Önlemi):**
   - Python `pyodbc` sürücüsü MSSQL yerel hata numarasını ayrı bir Python `Exception.code` alanı olarak her zaman temiz bir şekilde dönmeyebilir; bazen mesajın içine gömer.
   - Bu nedenle tüm T-SQL `THROW` mesajlarımız istisnasız `[500XX] Hata Mesajı` formatıyla başlar. Flask `errors.py` katmanı regex ile mesajın başındaki bu kodu yakalar ve harici istemciye sızdırmadan temiz bir JSON çıktısına dönüştürür.
3. **Standart JSON Hata Yanıt Formatı:**
   ```json
   {
     "basarili": false,
     "hata_kodu": 50001,
     "mesaj": "Seçilen tarihlerde oda başka bir rezervasyon ile çakışmaktadır.",
     "alan": "giris_tarihi",
     "detay": "Lütfen farklı bir tarih aralığı veya başka bir oda seçiniz."
   }
   ```

---

## 2. Hata Kodu ve HTTP Eşleme Tablosu

| Hata Kodu | Hata Adı / Anlamı | Fırlatan Nesne (SP / Trigger) | HTTP Kodu | Kullanıcıya Gösterilen Açıklama |
|---|---|---|:---:|---|
| **50001** | `ERR_REZ_CAKISMA` (Tarih Çakışması) | `trg_rez_cakisma`, `sp_rezervasyon_olustur` | **409 Conflict** | Seçilen tarihlerde bu oda için aktif başka bir rezervasyon bulunmaktadır. |
| **50002** | `ERR_KAPASITE_ASIMI` (Kişi Sayısı > Kapasite) | `trg_rez_cakisma`, `sp_rezervasyon_olustur` | **422 Unprocessable** | Seçilen kişi sayısı odanın azami yatak kapasitesini aşmaktadır. |
| **50003** | `ERR_ODA_BAKIMDA_VEYA_PASIF` | `trg_rez_cakisma`, `sp_rezervasyon_olustur` | **409 Conflict** | Seçilen oda şu anda bakımda veya hizmet dışıdır. |
| **50004** | `ERR_YAS_SINIRI` (Rezervasyon Sahibi < 18) | `trg_rez_cakisma`, `sp_rezervasyon_olustur` | **422 Unprocessable** | Rezervasyon yapabilmek için misafirin en az 18 yaşında olması gerekmektedir. |
| **50005** | `ERR_SEZON_CAKISMA` | `trg_sezon_cakisma` | **409 Conflict** | Aynı oda tipi için tanımlanan sezon tarih aralıkları birbiriyle çakışamaz. |
| **50006** | `ERR_GECERSIZ_DURUM_GECISI` | `trg_rez_durum_gecis` | **409 Conflict** | İptal edilmiş veya tamamlanmış rezervasyonun durumu değiştirilemez. |
| **50007** | `ERR_IPTAL_BILGISI_EKSIK` | `trg_rez_durum_gecis` | **422 Unprocessable** | Rezervasyon iptal edilirken iptal nedeni ve tarihi belirtilmelidir. |
| **50008** | `ERR_ODEME_TUTAR_LIMITI` | `trg_odeme_dogrula` | **422 Unprocessable** | Toplam tahsilat tutarı rezervasyon tutarını aşamaz. |
| **50009** | `ERR_IADE_TAHSILATTAN_BUYUK` | `trg_odeme_dogrula` | **422 Unprocessable** | İade tutarı, bu rezervasyona ait başarılı tahsilatların toplamından fazla olamaz. |
| **50010** | `ERR_KAPALI_KONAKLAMA_ISLEM` | `trg_hizmet_kapali_konaklama`, `trg_odeme_dogrula` | **409 Conflict** | Çıkışı yapılmış (kapanmış) konaklamaya yeni ek hizmet veya ödeme eklenemez. |
| **50011** | `ERR_GECERSIZ_ODEME_YONTEMI` | `sp_rezervasyon_olustur`, `sp_checkout` | **400 Bad Request** | Belirtilen ödeme yöntemi kodu sistemde bulunamadı veya pasif durumdadır. |
| **50012** | `ERR_TAKSIT_YALNIZCA_KREDI_KARTI` | `trg_odeme_dogrula`, `sp_rezervasyon_olustur` | **422 Unprocessable** | Taksitli ödeme seçeneği yalnızca kredi kartı ile yapılan işlemlerde geçerlidir. |
| **50013** | `ERR_KONAKLAMA_BULUNAMADI` | `sp_konaklama_tutar`, `sp_checkout` | **404 Not Found** | Belirtilen konaklama kaydı sistemde bulunamadı. |
| **50014** | `ERR_CHECKOUT_TUTAR_UYUMSUZ` | `sp_checkout` | **409 Conflict** | Gönderilen ödeme tutarı konaklamanın kalan açık borcuna eşit değildir. |
| **50015** | `ERR_ESZAMANLI_ISLEM_KILIT` (Applock / Race Condition) | `sp_rezervasyon_olustur`, `sp_checkout` | **409 Conflict** | Bu oda/konaklama üzerinde şu anda başka bir işlem yürütülmektedir, lütfen tekrar deneyiniz. |
| **50016** | `ERR_GIRIS_TARIHI_GECMIS` | `sp_rezervasyon_olustur` | **422 Unprocessable** | Rezervasyon giriş tarihi bugünden daha önceki bir tarih olamaz. |
| **50017** | `ERR_TEMIZLIK_GOREVLISI_DEGIL` | `trg_temizlik_personel_rol` | **422 Unprocessable** | Temizlik görevine yalnızca 'kat_gorevlisi' unvanına sahip personel atanabilir. |
| **50018** | `ERR_OTEL_YETKI_UYUMSUZLUGU` | `sp_checkin`, `sp_checkout`, `sp_hizmet_ekle` | **403 Forbidden** | Personel yalnızca kendi çalıştığı otele ait kayıtlar üzerinde işlem yapabilir. |
