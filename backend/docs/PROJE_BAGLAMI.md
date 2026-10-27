# PROJE BAĞLAMI — Otel Rezervasyon ve Konaklama Yönetim Sistemi

> Bu dosya, projeyi yeni bir sohbette kaldığımız yerden sürdürmek için tek kaynaktır.
> Her adımın sonunda güncellenir. Sürüm: **v0 (Adım 1 — Plan, onay bekliyor)**

## 1. Özet
- **Veritabanı:** MSSQL 2022 (Docker, Apple Silicon'da `linux/amd64` + Rosetta), `OtelDB`, `Turkish_CI_AS`, uyumluluk 160
- **Backend:** Flask + pyodbc (SP ve view'lar doğrudan çağrılır), katmanlar: entities / repositories / services / controllers / security / errors
- **Frontend:** HTML + CSS + Vanilla JS, Flask static üzerinden sunulur; grafikler Chart.js (cdnjs, sabit sürüm)
- **Ek puan:** e-posta (bildirim kuyruğu + Mailpit), çoklu otel, grafikli raporlar
- **Ödeme:** tamamen SİMÜLE (`simule=1`); tam kart numarası, CVV ve son kullanma tarihi hiçbir yerde tutulmaz

## 2. Tamamlanan adımlar
| Adım | Durum | Tarih |
|---|---|---|
| 1 — Plan | Tamamlandı ve onaylandı | 27.10.2026 |
| 2 — Ortam ve Boş Veritabanı | Tamamlandı, onay bekliyor | 27.10.2026 |
| 3–15 | Başlanmadı | — |

## 3. Doğrulanan ortam bilgileri ve kullanıcı yanıtları
- **İşlemci / Makine:** MacBook Air (Apple Silicon `arm64`)
- **Docker & Emülasyon:** Docker 29.1.3 `linux/arm64`, Rosetta açık, `mcr.microsoft.com/mssql/server:2022-latest` (`amd64` x86 imajı emülasyonla çalışıyor)
- **Mevcut Durum:** `sql_server_container` 1433'te çalışıyordu. **Seçim:** 1. Seçenek (Mevcut container durdurulup Docker Compose ile `MSSQL_COLLATION=Turkish_CI_AS` atanarak 1433 portunda kalıcı volume ile sıfırdan ve temiz başlatılacak).
- **SQL Server Sürümü & Uyumluluk:** MSSQL 2022 (16.0.4295.3 - CU27), `compatibility_level = 160` (GENERATE_SERIES ve modern T-SQL tam destekli)
- **Saat Dilimi:** `Turkey Standard Time` sorgulandı (+03:00, DST: 0) — Linux container içinde Windows timezone adı kusursuz çalışıyor!
- **Geliştirme / Sorgu Aracı:** **VS Code + MSSQL Eklentisi** (`ms-mssql.mssql`) seçildi. (Azure Data Studio 28.02.2026'da emekli olduğu için en modern ve resmi desteklenen yoldur).
- **Python Ortamı:** Python 3.13.9 (`/opt/anaconda3/bin/python3`, native `arm64`)
- **ODBC Sürücüsü:** Henüz yok (`msodbcsql18` Adım 2'de Homebrew ile kurulacak).
- **Grup Üyeleri / GitHub:**
  - `arslan468` (Kişi A - Veritabanı Sorumlusu & Lider)
  - `EfeBurak-Tiryaki` (Kişi B - Uygulama & API Sorumlusu)

## 4. Tasarım kararları (Genişletilmiş Profesyonel Mimari)
| # | Karar | Gerekçe |
|---|---|---|
| K1 | oda ↔ oda_tipi aynı otel: bileşik FK `(oda_tipi_id, otel_id)` | Bildirimsel kısıt atlanamaz, trigger'dan çok daha performanslıdır. |
| K2 | `odeme(odeme_yontemi_id, odeme_turu)` → `odeme_yontemi(id, odeme_turu_grubu)` bileşik FK | Denormalize `odeme_turu` bozulamaz. |
| K3 | `konaklama_hizmeti.kdv_orani_anlik` eklenir | KDV oranı sonradan değişirse eski faturalar bozulmaz (3NF koruması). |
| K4 | KDV formülü `× (1 + kdv/100)`; oda fiyatı KDV dahil | `kdv_orani=10` "%10" anlamına gelir. |
| K5 | Hafta sonu = Cuma ve Cumartesi geceleri; `DATEDIFF(DAY,'19000101',gece) % 7` | `DATEFIRST`/dil ayarından bağımsız deterministik hesaplama. |
| K6 | 18 yaş: `DATEADD(YEAR,18,dogum_tarihi) <= giris_tarihi` | `DATEDIFF(YEAR)` takvim yılı saydığı için hatalıdır; tam doğum günü kontrol edilir. |
| K7 | Ek SP'ler: `sp_misafir_kayit`, `sp_checkin`, `sp_hizmet_ekle`, `sp_fatura_olustur` (toplam 10 SP) | Kurumsal ve atomik iş akışları doğrudan DB katmanında yönetilir. |
| K8 | `rezervasyon_kodu` SEQUENCE ile (`RZV-000123`) | Tekil, thread-safe, eşzamanlılığa dayanıklı. |
| K9 | `sp_settriggerorder`: `trg_rez_cakisma`=First, `trg_log_rezervasyon`=Last; `UPDATE()` ve `TRIGGER_NESTLEVEL` korumaları | Trigger kaskad ve döngülerini engeller. |
| K10 | Rezervasyon kontrolleri yalnızca INSERT'te veya oda/tarih/kişi sütunu değişince çalışır | Bakımdaki odanın eski rezervasyonu sorunsuz `tamamlandi` yapılabilsin. |
| K11 | "Giriş ≥ bugün" kuralı SP'de; trigger geçmiş tarihe izin verir | Seed, trigger'lar açıkken yüklenebilsin. |
| K12 | Grup eşlemesi: **kart** = kredi_karti, banka_karti, google_pay, apple_pay, iyzico, paypal; **nakit** = havale_eft, bitcoin, ethereum, usdt, papara, otelde_odeme. Taksit>1 yalnızca kredi_karti (trigger) | PDF nakit/kart uyumu. |
| K13 | **Genişletilmiş Tablo Mimarisi (Maksimum Profesyonellik — Toplam 26 Tablo):** 8 yeni kurumsal tablo eklendi. | 30 puanlık veritabanı tasarımını ve ER modelini üniversite seviyesinin ötesine taşır. |
| K14 | Ek tablo `yenileme_tokeni` (Refresh Token Revocation List) | JWT replay saldırılarını engeller, oturum iptalini yönetir. |
| K15 | Kütüphaneler: Flask, pyodbc, flask-jwt-extended, argon2-cffi, flask-cors, flasgger, python-dotenv, pytest | Endüstri standardı güvenlik ve asgari bağımlılık. |
| K16 | Access token bellekte, refresh token HttpOnly + SameSite=Strict çerezde | XSS ve CSRF risklerini minimize eder. |

## 5. Tablo listesi (Toplam 26 Tablo — Kurumsal ERP Düzeyi)

### A. Çekirdek & Tesis Envanteri (8 Tablo)
1. `otel` (Çoklu otel, yıldız, giriş/çıkış saatleri)
2. `otel_departman` *(Yeni - Ek)* (Ön büro, Kat Hizmetleri, İdari, Teknik, Muhasebe)
3. `oda_tipi` (Kapasite, m2, temel fiyat, yatak tipi)
4. `ozellik` *(Yeni - Ek)* (Minibar, Deniz Manzarası, Balkon, Jakuzi, Wi-Fi vb. katalog)
5. `oda_tipi_ozellik` *(Yeni - Ek)* (N-N ara tablo: Oda tipinin sunduğu olanaklar — 3NF)
6. `oda` (Kat, oda no, anlık operasyon durumu, son temizlik)
7. `bakim_kaydi` *(Yeni - Ek)* (Oda arıza/onarım/periyodik bakım takibi, `v_kritik_odalar` view'ının dayanağı)
8. `sezon_fiyati` (Oda tipine göre tarih aralıklı dinamik fiyatlandırma ve hafta sonu çarpanı)

### B. Kimlik, İnsan Kaynakları & Güvenlik (4 Tablo)
9. `misafir` (TC/Pasaport kontrolü, VIP, uyruk, doğum tarihi)
10. `personel` (Departman, otel, görev, işe giriş/çıkış)
11. `kullanici` (Roller, argon2 hash, kilit mekanizması, misafir/personel 1-1 ilişkisi)
12. `yenileme_tokeni` *(Yeni - Ek)* (JWT Refresh token whitelist/revocation tablosu)

### C. Rezervasyon & Konaklama Operasyonları (6 Tablo)
13. `rezervasyon` (Rezervasyon kodu, misafir, oda, tarihler, kişi, toplam tutar, durum)
14. `rezervasyon_gece` (Her gecenin anlık dondurulmuş fiyatı — snapshot pattern, 3NF savunması)
15. `rezervasyon_misafir` (N-N: Bir rezervasyonda odada konaklayan ek aile bireyleri/misafirler)
16. `konaklama` (1-1: Check-in/check-out saatleri, sorumlu personeller, operasyonel durum)
17. `temizlik_kaydi` (Kat görevlisi atamaları, oda temizlik takip çizelgesi)
18. `sistem_ayar` *(Yeni - Ek)* (İptal süresi [48h], ön ödeme oranı [%30] gibi dinamik kurumsal parametreler)

### D. Ek Hizmetler & Finans / Ödeme / Muhasebe (6 Tablo)
19. `hizmet_kategori` *(Yeni - Ek)* (Yiyecek-İçecek, SPA, Ulaşım, Çamaşırhane katalog tablosu — 3NF)
20. `ek_hizmet` (Hizmet adı, kategori_id FK, birim fiyat, KDV oranı)
21. `konaklama_hizmeti` (Odaya yazılan ek harcamalar, anlık birim fiyat ve KDV kopyası)
22. `odeme_yontemi` (12 farklı yöntem: Kredi kartı, kripto, havale, otelde ödeme vb. ve ikon kodları)
23. `odeme` (Ön ödeme ve hesap kapatma tahsilat/iade kayıtları, simüle referans no, taksit)
24. `fatura` *(Yeni - Ek)* (Check-out sonrası kesilen mali e-arşiv fatura başlığı: vergi no/tc, unvan, matrah, kdv)
25. `fatura_kalem` *(Yeni - Ek)* (Fatura dökümü: oda konaklama bedeli + ek hizmetlerin KDV detaylı kalemleri)

### E. Denetim & İletişim (2 Tablo)
26. `islem_log` (Kim, ne zaman, hangi tabloda, hangi JSON verisini değiştirdi — Append-only denetim izi)
27. `bildirim` (Rezervasyon onay/iptal e-posta kuyruğu — Mailpit / SMTP arka plan işçisi)

*(Not: Tablo sayısı 27'ye ulaşmış olup tam bir kurumsal PMS/ERP veritabanı seviyesine yükseltilmiştir. PDF'in 'rezervasyon' ve 'oda' durum listeleri harfiyen korunmuştur).*

## 6. Programlanabilir nesneler (Planlanan)
- **Trigger'lar (10 Adet Set-Based):**
  1. `trg_rez_cakisma` (Tarih aralığı çakışması, kapasite, bakım, 18 yaş kontrolü + applock)
  2. `trg_sezon_cakisma` (Aynı oda tipinde çakışan sezon engeli)
  3. `trg_rez_durum_gecis` (Geçersiz durum geçişi kısıtı)
  4. `trg_odeme_dogrula` (Tutar limitleri, iade kontrolleri, kapanan konaklama kısıtı)
  5. `trg_hizmet_kapali_konaklama` (Kapanmış konaklamaya harcama eklenmesini engelleme)
  6. `trg_rez_gece_olustur` (Rezervasyon girilince takvim gecelerini hesaplayıp snapshot alma)
  7. `trg_konaklama_oda_durum` (Check-in'de odayı 'dolu', check-out'ta 'temizlikte' yapma ve temizlik kaydı açma)
  8. `trg_temizlik_tamam` (Temizlik bitince odayı 'bos' yapma ve son temizlik tarihini güncelleme)
  9. `trg_log_rezervasyon` & `trg_log_odeme` (JSON formatında denetim günlüğü yazma)
  10. `trg_bildirim_olustur` (Onay/iptal durumlarında e-posta bildirim kuyruğuna kayıt atma)

- **Stored Procedure'ler (10 Adet Parametreli & Güvenli):**
  1. `sp_bos_odalar` (Müsaitlik ve dinamik fiyat hesaplama)
  2. `sp_konaklama_tutar` (Kalan bakiye ve harcama dökümü)
  3. `sp_aylik_rapor` (Doluluk, ADR, RevPAR, gelir ve ödeme yöntemi dağılımı)
  4. `sp_rezervasyon_olustur` (Applock + çakışma + gece + simüle ödeme tek transaction)
  5. `sp_rezervasyon_iptal` (48 saat kuralı + iade ödemesi)
  6. `sp_checkout` (UPDLOCK ile kilitleme + hesap kapatma + fatura oluşturma tek transaction)
  7. `sp_misafir_kayit` (Misafir ve kullanıcı hesabı atomik oluşturma)
  8. `sp_checkin` (Rezervasyon doğrulama + konaklama kaydı başlatma + oda durum senkronizasyonu)
  9. `sp_hizmet_ekle` (Konaklamaya anlık fiyat kopyasıyla ek hizmet yansıtma)
  10. `sp_fatura_kes` (Check-out yapılan konaklamanın tüm kalemlerini mali faturaya dökme)

- **View'lar (6 Adet):**
  1. `v_bugun_giris_cikis` (Resepsiyon operasyon ekranı)
  2. `v_oda_durum` (Kat bazlı anlık oda panosu)
  3. `v_misafir_gecmis` (Misafir sadakat ve harcama özeti)
  4. `v_aylik_gelir` (Yönetici grafikleri için Chart.js veri kaynağı)
  5. `v_kritik_odalar` (24 saatten uzun temizlikte veya bakımda kalan odalar)
  6. `v_rezervasyon_odeme_ozet` (Finansal durum ve açık bakiyeler)

- **Yardımcı Fonksiyonlar (iTVF & Scalar):**
  1. `dbo.fn_bugun()` (Türkiye tarihini DATE olarak döner)
  2. `dbo.fn_simdi_tr()` (Türkiye saatini DATETIME2 olarak döner)
  3. `dbo.fn_cakisan_rezervasyonlar()` (Tek doğruluk kaynağı inline TVF)
  4. `dbo.fn_gece_fiyatlari()` (Sezon ve hafta sonu çarpanı hesaplayan inline TVF)

## 7. DEĞİŞİKLİK GÜNLÜĞÜ
| Tarih | Ne değişti | Dosyalar |
|---|---|---|
| 27.10.2026 | v0: Adım 1 planı, öneri kararlar, açık sorular | docs/PROJE_BAGLAMI.md |
| 27.10.2026 | v1: Kullanıcı ortam çıktıları işlendi, tablo sayısı 27'ye genişletildi, tam onay aşamasına getirildi. | docs/PROJE_BAGLAMI.md |
| 27.10.2026 | v2: Adım 2 tamamlandı: docker-compose.yml, .env.example, sql/00_kurulum/ (000, 001, 002), HATA_KODLARI.md, KURULUM_MAC.md, VERITABANI_DOKUMANTASYONU.md oluşturuldu. | docker-compose.yml, .env.example, sql/00_kurulum/*, docs/* |
