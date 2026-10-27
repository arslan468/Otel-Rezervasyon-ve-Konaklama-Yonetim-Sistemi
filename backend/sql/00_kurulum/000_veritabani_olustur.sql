-- ==============================================================================
-- DOSYA ADI: sql/00_kurulum/000_veritabani_olustur.sql
-- PROJE    : Otel Rezervasyon ve Konaklama Yönetim Sistemi
-- ADIM     : Adım 2 - Ortam ve Boş Veritabanı Kurulumu
-- AMAC     : OtelDB veritabanını Turkish_CI_AS collation ve 160 (SQL 2022) uyumluluk
--            seviyesinde idempotent (tekrar çalıştırılabilir) olarak oluşturmak.
-- CALISTIRMA: VS Code veya ADS üzerinden 'sa' yetkisiyle 'master' veritabanında çalıştırılır.
-- GEREKCE  : Turkish_CI_AS collation, Türk alfabesindeki İ-i, I-ı, Ş-ş gibi karakterlerin
--            doğru sıralanmasını ve harf büyüklüğüne duyarsız (Case-Insensitive) aranmasını sağlar.
-- ==============================================================================

-- master sistem veritabanı bağlamına geçilir (veritabanı oluşturma işlemi master içinde yürütülür)
USE master;
GO

-- OtelDB adında bir veritabanının sunucuda daha önce oluşturulup oluşturulmadığı kontrol edilir
IF NOT EXISTS (
    -- sys.databases katalog görünümünden OtelDB kaydı taranır
    SELECT 1 
    -- Sistem veritabanı kataloğu tablosu
    FROM sys.databases 
    -- Veritabanı ismi karşılaştırması (N harfi Unicode literal olduğunu garanti eder)
    WHERE name = N'OtelDB'
)
BEGIN
    -- Veritabanı yoksa oluşturulur; Collation açıkça Turkish_CI_AS (Türkçe, Case-Insensitive, Accent-Sensitive) atanır
    CREATE DATABASE OtelDB 
    -- Türkçe karakter sıralama ve arama kuralları tanımlanır
    COLLATE Turkish_CI_AS;
    -- Veritabanının başarıyla oluşturulduğu bilgisi mesaj penceresine yazdırılır
    PRINT N'>> OtelDB veritabani Turkish_CI_AS collation ile basariyla olusturuldu.';
END
ELSE
BEGIN
    -- Veritabanı zaten mevcutsa silinmez veya bozulmaz; idempotentliği korumak için mesaj verilir
    PRINT N'>> OtelDB veritabani zaten mevcut, olusturma adimi atlandi.';
END
GO

-- Veritabanı seviyesindeki modern optimizasyon ve uyumluluk ayarları uygulanır
ALTER DATABASE OtelDB 
-- SQL Server 2022 sürümünün getirdiği tüm yenilikleri (GENERATE_SERIES, WINDOW fonksiyonları vb.) aktif etmek için uyumluluk seviyesi 160 yapılır
SET COMPATIBILITY_LEVEL = 160;
GO

-- Okuyucuların yazarları, yazarların okuyucuları kilitlemesini önlemek için Read Committed Snapshot Isolation (RCSI) açılır
-- Bu ayar, web uygulamalarındaki eşzamanlı SELECT ve UPDATE sorgularının kilitlenmeden (deadlock olmadan) çalışmasını sağlar
ALTER DATABASE OtelDB 
-- Okuma işlemlerinin satırın en son commit edilmiş versiyonunu tempdb üzerinden okumasını sağlar
SET READ_COMMITTED_SNAPSHOT ON 
-- Diğer bağlantıların kilitlenmesini beklemeden işlemi hemen uygular (ROLLBACK IMMEDIATE ile bekleyen kilitleri temizler)
WITH ROLLBACK IMMEDIATE;
GO

-- OtelDB veritabanı bağlamına geçilir
USE OtelDB;
GO

-- Veritabanı nesnesi üzerine açıklama (MS_Description extended property) eklenir
-- Bu açıklama VS Code ve Azure Data Studio gibi araçlarda veritabanı detaylarında görünür
IF NOT EXISTS (
    -- Veritabanı düzeyindeki genişletilmiş özellikleri kontrol eder
    SELECT 1 
    -- Genişletilmiş özellikler sistem fonksiyonu
    FROM fn_listextendedproperty(N'MS_Description', default, default, default, default, default, default)
)
BEGIN
    -- Veritabanı seviyesine kurumsal açıklama ekleme prosedürü çağrılır
    EXEC sys.sp_addextendedproperty 
        -- Özellik adı
        @name = N'MS_Description', 
        -- Özellik değeri (Veritabanının amacı ve projenin detayları)
        @value = N'Otel Rezervasyon ve Konaklama Yonetim Sistemi - Donem Projesi Veritabani (MSSQL 2022 / Turkish_CI_AS)';
    -- Açıklamanın eklendiği bilgisi verilir
    PRINT N'>> OtelDB veritabani aciklamasi (MS_Description) eklendi.';
END
GO

-- Kurulumun başarılı olduğunu ve veritabanı parametrelerini özetleyen doğrulama sorgusu
SELECT 
    -- Veritabanının adı
    name AS veritabani_adi,
    -- Tanımlı olan collation kuralı
    collation_name AS siralama_kurali,
    -- Uyumluluk seviyesi (160 = SQL 2022)
    compatibility_level AS uyumluluk_seviyesi,
    -- Snapshot izolasyonunun açık olup olmadığı (1 olmalıdır)
    is_read_committed_snapshot_on AS rcsi_durumu
-- Sistem veritabanları tablosundan okunur
FROM sys.databases
-- Yalnızca yeni oluşturduğumuz veritabanı filtrelenir
WHERE name = N'OtelDB';
GO
