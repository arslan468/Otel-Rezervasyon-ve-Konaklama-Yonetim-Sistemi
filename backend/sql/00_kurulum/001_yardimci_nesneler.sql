-- ==============================================================================
-- DOSYA ADI: sql/00_kurulum/001_yardimci_nesneler.sql
-- PROJE    : Otel Rezervasyon ve Konaklama Yönetim Sistemi
-- ADIM     : Adım 2 - Ortam ve Boş Veritabanı Kurulumu
-- AMAC     : Türkiye saat dilimine duyarlı zaman fonksiyonları (fn_bugun, fn_simdi_tr)
--            ve metadata açıklamalarını (MS_Description) hatasız güncelleyen yardımcı
--            prosedürü (usp_aciklama_yaz) oluşturmak.
-- CALISTIRMA: OtelDB veritabanında çalıştırılır.
-- GEREKCE  : Docker container'ları standart olarak UTC (Londra) saatinde çalışır.
--            Türkiye saat dilimi ise UTC+3'tür. Eğer GETDATE() kullanılırsa, gece
--            00:00 ile 03:00 saatleri arasında sunucu dünün tarihini verir; bu da
--            bugünkü giriş/çıkışların, 48 saatlik iptal cezasının ve gün sonu
--            raporlarının yanlış hesaplanmasına sebep olur. Bu nedenle tüm sistemde
--            GETDATE() yerine fn_bugun() ve fn_simdi_tr() kullanılmalıdır.
-- ==============================================================================

-- OtelDB veritabanı bağlamına geçilir
USE OtelDB;
GO

-- ------------------------------------------------------------------------------
-- 1. FONKSIYON: dbo.fn_bugun()
-- AMAC        : UTC zaman damgasını Türkiye saatine (UTC+3) çevirip sadece 'DATE'
--               (Yıl-Ay-Gün) olarak döndürür.
-- GIRDILER    : Yok.
-- CIKTILAR    : DATE (Örn: '2026-10-27')
-- KULLANIM    : SELECT dbo.fn_bugun();
-- ------------------------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_bugun()
-- Fonksiyonun döndüreceği veri tipi; saat bilgisi içermeyen saf tarih tipi
RETURNS DATE
-- Güvenlik ve performans için şema bağlama ve optimizasyon seçenekleri
WITH SCHEMABINDING
AS
BEGIN
    -- Fonksiyonun gövde başlangıcı
    RETURN CAST(
        -- SYSUTCDATETIME(): Sunucu saatinden bağımsız olarak dünyanın sıfır meridyeni (UTC) anlık hassas zamanını alır
        -- AT TIME ZONE 'UTC': Alınan zaman damgasının UTC olduğunu bildirir
        -- AT TIME ZONE 'Turkey Standard Time': Değeri Türkiye saat dilimine (+03:00) öteler
        SYSUTCDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'Turkey Standard Time'
        -- Elde edilen datetimeoffset değerinin saat/dakika/saniye kısmı atılarak sadece tarih (DATE) tipine çevrilir
        AS DATE
    );
-- Fonksiyon gövdesi biter
END;
GO

-- fn_bugun fonksiyonu üzerine açıklama eklenir
EXEC sys.sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Turkiye saat dilimine (UTC+3) gore bugunun tarihini (DATE) donduren temel fonksiyon. Tum view, SP ve triggerlarda GETDATE yerine bu kullanilir.', 
    @level0type = N'SCHEMA', @level0name = N'dbo', 
    @level1type = N'FUNCTION', @level1name = N'fn_bugun';
GO

-- ------------------------------------------------------------------------------
-- 2. FONKSIYON: dbo.fn_simdi_tr()
-- AMAC        : Türkiye saatine (UTC+3) göre anlık tarih ve saat bilgisini
--               DATETIME2(0) (saniye hassasiyetli) olarak döndürür.
-- GIRDILER    : Yok.
-- CIKTILAR    : DATETIME2(0) (Örn: '2026-10-27 11:30:00')
-- KULLANIM    : SELECT dbo.fn_simdi_tr();
-- ------------------------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_simdi_tr()
-- Fonksiyonun döndüreceği veri tipi; saniye hassasiyetli tarih-saat
RETURNS DATETIME2(0)
-- Şema bağlama seçeneği
WITH SCHEMABINDING
AS
BEGIN
    -- Fonksiyonun gövde başlangıcı
    RETURN CAST(
        -- UTC zaman damgası alınır ve Türkiye saat dilimine dönüştürülür
        SYSUTCDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'Turkey Standard Time'
        -- Ofset bilgisi (+03:00) atılarak yerel Türkiye tarih-saat tipine çevrilir
        AS DATETIME2(0)
    );
-- Fonksiyon gövdesi biter
END;
GO

-- fn_simdi_tr fonksiyonu üzerine açıklama eklenir
EXEC sys.sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Turkiye saat dilimine (UTC+3) gore su anki anlik tarih ve saat bilgisini (DATETIME2) donduren fonksiyon. 48 saat iptal politikasi kiyaslamasinda kullanilir.', 
    @level0type = N'SCHEMA', @level0name = N'dbo', 
    @level1type = N'FUNCTION', @level1name = N'fn_simdi_tr';
GO

-- ------------------------------------------------------------------------------
-- 3. PROSEDUR: dbo.usp_aciklama_yaz
-- AMAC       : Tablo ve kolonlar için genişletilmiş özellikleri (MS_Description)
--              idempotent (varsa güncelle, yoksa ekle) şekilde yazan yardımcı prosedür.
-- GIRDILER   : @tablo_adi (NVARCHAR), @kolon_adi (NVARCHAR - opsiyonel), @aciklama (NVARCHAR)
-- CIKTILAR   : Yok.
-- HATALAR    : Geçersiz parametrelerde standart T-SQL hatası döner.
-- KULLANIM   : EXEC dbo.usp_aciklama_yaz @tablo_adi = N'otel', @kolon_adi = N'ad', @aciklama = N'Otel ticari unvani';
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_aciklama_yaz
    -- Açıklama eklenecek tablonun adı (Zorunlu)
    @tablo_adi SYSNAME,
    -- Açıklama eklenecek kolonun adı (Opsiyonel; NULL ise tablo düzeyinde açıklama yazılır)
    @kolon_adi SYSNAME = NULL,
    -- Yazılacak Türkçe detaylı açıklama metni
    @aciklama NVARCHAR(1000)
AS
BEGIN
    -- Etkilenen satır sayısı mesajını kapatır (performans ve temiz çıktı için standart)
    SET NOCOUNT ON;

    -- Kolon adı belirtilmiş mi kontrol edilir (Kolon seviyesinde açıklama)
    IF @kolon_adi IS NOT NULL
    BEGIN
        -- İlgili tabloda ve kolonda daha önce bir MS_Description tanımlanmış mı sorgulanır
        IF EXISTS (
            -- Genişletilmiş özellikler sistem tablosundan kontrol
            SELECT 1 
            -- fn_listextendedproperty sistem fonksiyonu
            FROM fn_listextendedproperty(
                N'MS_Description', 
                N'SCHEMA', N'dbo', 
                N'TABLE', @tablo_adi, 
                N'COLUMN', @kolon_adi
            )
        )
        BEGIN
            -- Özellik zaten varsa güncelleme (sp_updateextendedproperty) yapılır
            EXEC sys.sp_updateextendedproperty
                @name = N'MS_Description',
                @value = @aciklama,
                @level0type = N'SCHEMA', @level0name = N'dbo',
                @level1type = N'TABLE',  @level1name = @tablo_adi,
                @level2type = N'COLUMN', @level2name = @kolon_adi;
        END
        ELSE
        BEGIN
            -- Özellik henüz yoksa sıfırdan ekleme (sp_addextendedproperty) yapılır
            EXEC sys.sp_addextendedproperty
                @name = N'MS_Description',
                @value = @aciklama,
                @level0type = N'SCHEMA', @level0name = N'dbo',
                @level1type = N'TABLE',  @level1name = @tablo_adi,
                @level2type = N'COLUMN', @level2name = @kolon_adi;
        END
    END
    -- Kolon adı belirtilmemişse tablo seviyesinde işlem yapılır
    ELSE
    BEGIN
        -- Tablo seviyesinde MS_Description kontrolü
        IF EXISTS (
            SELECT 1 
            FROM fn_listextendedproperty(
                N'MS_Description', 
                N'SCHEMA', N'dbo', 
                N'TABLE', @tablo_adi, 
                default, default
            )
        )
        BEGIN
            -- Tablo açıklaması güncelleme
            EXEC sys.sp_updateextendedproperty
                @name = N'MS_Description',
                @value = @aciklama,
                @level0type = N'SCHEMA', @level0name = N'dbo',
                @level1type = N'TABLE',  @level1name = @tablo_adi;
        END
        ELSE
        BEGIN
            -- Tablo açıklaması ilk kez ekleme
            EXEC sys.sp_addextendedproperty
                @name = N'MS_Description',
                @value = @aciklama,
                @level0type = N'SCHEMA', @level0name = N'dbo',
                @level1type = N'TABLE',  @level1name = @tablo_adi;
        END
    END
-- Prosedür gövdesi biter
END;
GO

-- Doğrulama: Fonksiyonların anlık Türkiye tarih ve saatini doğru verdiğini test edelim
SELECT 
    -- SYSUTCDATETIME çıktısı (Container'ın UTC anı)
    SYSUTCDATETIME() AS container_utc_ani,
    -- Bizim fn_bugun() fonksiyonumuzun çıktısı (Türkiye Tarihi)
    dbo.fn_bugun() AS turkiye_tarihi_fn_bugun,
    -- Bizim fn_simdi_tr() fonksiyonumuzun çıktısı (Türkiye Saati)
    dbo.fn_simdi_tr() AS turkiye_saati_fn_simdi_tr;
GO
