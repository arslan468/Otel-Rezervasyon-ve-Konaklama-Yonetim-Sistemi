# 🏨 Otel Rezervasyon ve Konaklama Yönetim Sistemi

Veritabanı Yönetim Sistemleri dersi (2026-2027) dönem projesi. Bir otelin oda, rezervasyon, konaklama, ödeme ve personel süreçlerini yöneten; iş kurallarının büyük bölümünü **veritabanı seviyesinde** (constraint, trigger, stored procedure, transaction) uygulayan tam yığın bir sistemdir.


👥 **Geliştiriciler:** [Mehmet Alp ARSLAN](https://github.com/arslan468) · [Efe Burak TİRYAKİ](https://github.com/EfeBurak-Tiryaki)

---

## ✨ Öne Çıkan Özellikler

- **Çakışan rezervasyon engeli iki katmanda:** PostgreSQL `EXCLUDE USING gist` kısıtı + `BEFORE INSERT/UPDATE` trigger'ı
- **Gece bazlı sezon fiyatlandırma:** Her gecenin fiyatı rezervasyon anında `rezervasyon_gece` tablosuna kaydedilir; sonradan fiyat değişse de eski tutarlar bozulmaz
- **Atomik check-out:** Konaklama kapatma, ödeme ve oda durumu tek transaction'da; hata olursa `ROLLBACK`
- **JWT + rol bazlı yetkilendirme:** misafir / resepsiyon / yönetici
- **Denetim kaydı:** Trigger'larla `islem_log` tablosuna JSONB eski/yeni değer yazılır

## 🧰 Teknolojiler

| Katman | Teknoloji |
|---|---|
| Veritabanı | PostgreSQL 16 |
| Backend | Python, Flask, SQLAlchemy, Flask-JWT-Extended |
| Frontend | HTML/CSS/JS, Chart.js  |
| Test / Dokümantasyon | Swagger UI, Postman |

## 📁 Proje Yapısı

```
.
├── sql/
│   ├── 01_schema.sql        # tablolar ve kısıtlar
│   ├── 02_triggers.sql
│   ├── 03_procedures.sql
│   ├── 04_views.sql
│   ├── 05_indexes.sql
│   └── 06_seed.sql          # örnek veri (20+ oda, 50+ misafir, 200+ rezervasyon)
├── backend/
│   └── app/
│       ├── entities/        # model sınıfları
│       ├── repositories/    # SQL / stored procedure çağrıları
│       ├── services/        # iş mantığı
│       ├── controllers/     # REST uç noktaları
│       └── security/        # JWT ve rol kontrolü
├── frontend/
├── postman/                 # Postman koleksiyonu
├── docs/                    # ER diyagramı, rapor, ekran görüntüleri
└── README.md
```


### Trigger'lar
| Trigger | Görev |
|---|---|
| `trg_rez_cakisma` | Çakışan tarihli rezervasyonu engeller, kapasite ve oda uygunluğunu kontrol eder |
| `trg_konaklama_oda_durum` | Check-in → oda `dolu`, check-out → `temizlikte` + temizlik kaydı |
| `trg_log_rezervasyon` / `trg_log_odeme` | Değişiklikleri `islem_log`'a yazar |
| `trg_rez_gece_olustur` | Gece bazlı fiyatları ve toplam tutarı hesaplar |
| `trg_temizlik_tamam` | Temizlik bitince oda `bos` olur |
| `trg_hizmet_kapali_konaklama` | Kapanmış konaklamaya hizmet eklemeyi engeller |
| `trg_rez_durum_gecis` | Geçersiz durum geçişlerini engeller |
| `trg_bildirim_olustur` | Onay/iptalde e-posta kuyruğuna kayıt atar |

### Stored Procedure / Function'lar
`sp_bos_odalar` · `sp_konaklama_tutar` · `sp_aylik_rapor` · `sp_rezervasyon_olustur` · `sp_rezervasyon_iptal` · `sp_checkout`

### View'lar
`v_bugun_giris_cikis` · `v_oda_durum` · `v_misafir_gecmis` · `v_aylik_gelir` · `v_kritik_odalar`


## 🔌 API Özeti

| Metot | Uç nokta | Rol | Açıklama |
|---|---|---|---|
| POST | `/auth/register`, `/auth/login`, `/auth/refresh` | herkes | Kimlik doğrulama |
| GET | `/odalar/bos` | misafir | Boş oda arama (`sp_bos_odalar`) |
| POST / DELETE | `/rezervasyonlar` | misafir | Rezervasyon yap / iptal et |
| GET | `/misafir/gecmis` | misafir | Geçmiş konaklamalar |
| GET | `/resepsiyon/bugun` | resepsiyon | Bugünkü giriş/çıkışlar |
| POST | `/konaklamalar/{id}/checkin` · `/hizmet` · `/checkout` | resepsiyon | Konaklama işlemleri |
| GET | `/konaklamalar/{id}/hesap` | resepsiyon | Toplam tutar (`sp_konaklama_tutar`) |
| GET | `/yonetici/rapor/aylik` | yönetici | Doluluk ve gelir raporu |
| CRUD | `/yonetici/odalar`, `/oda-tipleri`, `/sezon-fiyatlari`, `/ek-hizmetler`, `/personel` | yönetici | Yönetim | 

## 🧪 Test Senaryoları

1. Çakışan tarihli rezervasyon denemesi → `409 Conflict`
2. Check-in sonrası oda durumunun `dolu` olması
3. Başarısız check-out'ta `ROLLBACK` (konaklama açık kalır, ödeme oluşmaz)
4. Rezervasyon/ödeme değişikliklerinin `islem_log`'a düşmesi
5. Yetkisiz rol erişiminin `403` ile engellenmesi

## ✅ Gereksinim Durumu

- [x] 3+ Trigger · [x] 3+ Stored Procedure · [x] 2+ View · [x] Transaction · [x] İndeksleme
- [x] JWT + rol bazlı yetkilendirme · [x] Katmanlı mimari
- [x] 20+ oda, 50+ misafir, 200+ rezervasyon örnek verisi

## 📄 Lisans
Bu proje eğitim amaçlıdır.