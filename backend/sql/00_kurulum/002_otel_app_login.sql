-- ==============================================================================
-- DOSYA ADI: sql/00_kurulum/002_otel_app_login.sql
-- PROJE    : Otel Rezervasyon ve Konaklama Yönetim Sistemi
-- ADIM     : Adım 2 - Ortam ve Boş Veritabanı Kurulumu
-- AMAC     : Uygulama (Flask API) için en az yetkili (Least Privilege) 'otel_app'
--            login ve veritabanı kullanıcısını (user) oluşturmak.
-- CALISTIRMA: VS Code üzerinden 'sa' yetkisiyle çalıştırılır.
-- GEREKCE  : 'sa' (System Administrator) hesabı tam yetkilidir; uygulama kodunun
--            'sa' ile bağlanması ciddi bir güvenlik açığıdır (SQL Injection olursa
--            saldırgan tüm sunucuyu ele geçirebilir veya veritabanını silebilir).
--            Bu yüzden sadece Stored Procedure çalıştırma ve View okuma yetkisi olan
--            özel bir servis hesabı oluşturulmalıdır.
-- ==============================================================================

-- Sunucu seviyesinde login oluşturmak için master veritabanına geçilir
USE master;
GO

-- 'otel_app' adında bir SQL Server Login (Giriş) hesabı var mı kontrol edilir
IF NOT EXISTS (
    -- Sunucu düzeyindeki güvenlik aktörlerini (principals) sorgular
    SELECT 1 
    -- Sunucu aktörleri sistem kataloğu
    FROM sys.server_principals 
    -- Login adı karşılaştırması
    WHERE name = N'otel_app'
)
BEGIN
    -- Login oluşturulur; şifre güçlü bir parola olarak atanır (varsayılan: OtelApp2026!GuvenliSifre)
    -- CHECK_POLICY = ON: Windows/Linux parola karmaşıklığı kurallarını zorunlu tutar
    -- CHECK_EXPIRATION = OFF: Servis hesabının şifresinin beklenmedik şekilde zaman aşımına uğramasını engeller
    CREATE LOGIN otel_app 
    WITH PASSWORD = N'OtelApp2026!GuvenliSifre',
         DEFAULT_DATABASE = OtelDB,
         CHECK_POLICY = ON,
         CHECK_EXPIRATION = OFF;
    -- Başarılı mesajı
    PRINT N'>> otel_app sunucu login hesabi basariyla olusturuldu.';
END
ELSE
BEGIN
    -- Hesap zaten varsa şifresi teyit edilir / güncellenir
    ALTER LOGIN otel_app WITH PASSWORD = N'OtelApp2026!GuvenliSifre';
    PRINT N'>> otel_app login hesabi zaten mevcut, parolasi guncellendi.';
END
GO

-- OtelDB veritabanı bağlamına geçilir
USE OtelDB;
GO

-- OtelDB içinde bu login'e karşılık gelen bir Veritabanı Kullanıcısı (Database User) var mı kontrol edilir
IF NOT EXISTS (
    -- Veritabanı düzeyindeki kullanıcıları sorgular
    SELECT 1 
    -- Veritabanı kullanıcıları kataloğu
    FROM sys.database_principals 
    -- Kullanıcı adı karşılaştırması
    WHERE name = N'otel_app'
)
BEGIN
    -- Veritabanı kullanıcısı oluşturulur ve sunucu login'ine bağlanır
    CREATE USER otel_app FOR LOGIN otel_app;
    PRINT N'>> OtelDB icinde otel_app veritabani kullanicisi olusturuldu.';
END
ELSE
BEGIN
    PRINT N'>> OtelDB icinde otel_app kullanicisi zaten mevcut.';
END
GO

-- ------------------------------------------------------------------------------
-- EN AZ YETKİ (LEAST PRIVILEGE) İZİN MİMARİSİ
-- ------------------------------------------------------------------------------
-- 1. Uygulama kullanıcısına dbo şemasındaki tüm STORED PROCEDURE'leri çalıştırma izni verilir
-- Neden: Tüm iş kuralları ve veri yazma operasyonları SP'ler üzerinden yapılmalıdır
GRANT EXECUTE ON SCHEMA::dbo TO otel_app;
GO

-- 2. Uygulama kullanıcısına dbo şemasındaki tüm VIEW ve FONKSIYONLARI okuma izni verilir
-- Neden: Raporlama ve arama ekranları doğrudan optimize edilmiş View'ları sorgular
GRANT SELECT ON SCHEMA::dbo TO otel_app;
GO

-- 3. Uygulama kullanıcısına doğrudan tablolardan DELETE yapma izni KESİNLİKLE VERİLMEZ!
-- Neden: Sistemde kayıt silme işlemleri mantıksal silme (aktif=0) olarak SP içinden yönetilir
-- Doğrudan fiziksel silme veri bütünlüğünü ve mali kayıtları bozar.

-- Doğrulama: Kullanıcının ve izinlerinin başarıyla tanımlandığını listeleyen sorgu
SELECT 
    -- Kullanıcının veritabanındaki adı
    dp.name AS kullanici_adi,
    -- Aktör tipi (SQL_USER)
    dp.type_desc AS kullanici_tipi,
    -- İzin türü (EXECUTE, SELECT vb.)
    p.permission_name AS verilen_izin,
    -- İzin durumu (GRANT / DENY)
    p.state_desc AS izin_durumu,
    -- İznin geçerli olduğu şema
    s.name AS sema_adi
FROM sys.database_permissions p
-- İznin verildiği kullanıcı tablosu ile birleştirme
JOIN sys.database_principals dp ON p.grantee_principal_id = dp.principal_id
-- İznin tanımlandığı şema ile birleştirme
LEFT JOIN sys.schemas s ON p.major_id = s.schema_id
-- Sadece otel_app kullanıcısı filtrelenir
WHERE dp.name = N'otel_app';
GO
