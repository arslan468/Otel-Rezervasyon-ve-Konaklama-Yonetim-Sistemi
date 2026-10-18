-- PostgreSQL için Otel Rezervasyon ve Konaklama Yönetim Sistemi Veritabanı Şeması

-- 1. Tabloların Oluşturulması

CREATE TABLE Otel (
    OtelID SERIAL PRIMARY KEY,
    Ad VARCHAR(100) NOT NULL,
    Adres TEXT NOT NULL,
    Sehir VARCHAR(50) NOT NULL,
    Telefon VARCHAR(20),
    Eposta VARCHAR(100),
    YildizSayisi INT CHECK (YildizSayisi BETWEEN 1 AND 5)
);

CREATE TABLE OdaTipi (
    OdaTipiID SERIAL PRIMARY KEY,
    OtelID INT REFERENCES Otel(OtelID) ON DELETE CASCADE,
    TipAdi VARCHAR(50) NOT NULL,
    Kapasite INT NOT NULL CHECK (Kapasite > 0),
    Aciklama TEXT,
    TemelFiyat DECIMAL(10, 2) NOT NULL CHECK (TemelFiyat >= 0)
);

CREATE TABLE Oda (
    OdaID SERIAL PRIMARY KEY,
    OtelID INT REFERENCES Otel(OtelID) ON DELETE CASCADE,
    OdaTipiID INT REFERENCES OdaTipi(OdaTipiID) ON DELETE CASCADE,
    OdaNumarasi VARCHAR(10) NOT NULL,
    Kat INT NOT NULL,
    Durum VARCHAR(20) NOT NULL CHECK (Durum IN ('Boş', 'Dolu', 'Temizlikte', 'Bakımda')),
    UNIQUE (OtelID, OdaNumarasi)
);

CREATE TABLE SezonFiyati (
    SezonFiyatiID SERIAL PRIMARY KEY,
    OdaTipiID INT REFERENCES OdaTipi(OdaTipiID) ON DELETE CASCADE,
    BaslangicTarihi DATE NOT NULL,
    BitisTarihi DATE NOT NULL,
    GecelikFiyat DECIMAL(10, 2) NOT NULL,
    CHECK (BitisTarihi >= BaslangicTarihi)
);

CREATE TABLE Misafir (
    MisafirID SERIAL PRIMARY KEY,
    Ad VARCHAR(50) NOT NULL,
    Soyad VARCHAR(50) NOT NULL,
    TCKimlikPasaportNo VARCHAR(20) UNIQUE,
    Telefon VARCHAR(20),
    Eposta VARCHAR(100) UNIQUE,
    DogumTarihi DATE
);

CREATE TABLE Personel (
    PersonelID SERIAL PRIMARY KEY,
    OtelID INT REFERENCES Otel(OtelID) ON DELETE CASCADE,
    Ad VARCHAR(50) NOT NULL,
    Soyad VARCHAR(50) NOT NULL,
    Gorev VARCHAR(50) NOT NULL CHECK (Gorev IN ('Resepsiyon', 'Kat Görevlisi', 'Yönetici', 'Sistem')),
    IseGirisTarihi DATE NOT NULL
);

CREATE TABLE Kullanici (
    KullaniciID SERIAL PRIMARY KEY,
    KullaniciAdi VARCHAR(50) UNIQUE NOT NULL,
    SifreHash VARCHAR(255) NOT NULL,
    Rol VARCHAR(20) NOT NULL CHECK (Rol IN ('Misafir', 'Resepsiyon', 'Yönetici', 'Sistem')),
    MisafirID INT REFERENCES Misafir(MisafirID) ON DELETE CASCADE,
    PersonelID INT REFERENCES Personel(PersonelID) ON DELETE CASCADE,
    CHECK (
        (MisafirID IS NOT NULL AND PersonelID IS NULL) OR 
        (MisafirID IS NULL AND PersonelID IS NOT NULL) OR
        (Rol = 'Sistem')
    )
);

CREATE TABLE Rezervasyon (
    RezervasyonID SERIAL PRIMARY KEY,
    MisafirID INT REFERENCES Misafir(MisafirID) ON DELETE CASCADE,
    OdaID INT REFERENCES Oda(OdaID) ON DELETE CASCADE,
    GirisTarihi DATE NOT NULL,
    CikisTarihi DATE NOT NULL,
    KisiSayisi INT NOT NULL CHECK (KisiSayisi > 0),
    Durum VARCHAR(20) NOT NULL CHECK (Durum IN ('Beklemede', 'Onaylı', 'İptal', 'Tamamlandı')),
    OlusturmaTarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (CikisTarihi > GirisTarihi)
);

CREATE TABLE Konaklama (
    KonaklamaID SERIAL PRIMARY KEY,
    RezervasyonID INT UNIQUE REFERENCES Rezervasyon(RezervasyonID) ON DELETE CASCADE,
    GercekGirisZamani TIMESTAMP NOT NULL,
    GercekCikisZamani TIMESTAMP NULL,
    GirisIsleminiYapanPersonelID INT REFERENCES Personel(PersonelID),
    CikisIsleminiYapanPersonelID INT REFERENCES Personel(PersonelID)
);

CREATE TABLE EkHizmet (
    EkHizmetID SERIAL PRIMARY KEY,
    OtelID INT REFERENCES Otel(OtelID) ON DELETE CASCADE,
    HizmetAdi VARCHAR(100) NOT NULL,
    BirimFiyat DECIMAL(10, 2) NOT NULL CHECK (BirimFiyat >= 0)
);

CREATE TABLE KonaklamaHizmeti (
    KonaklamaHizmetiID SERIAL PRIMARY KEY,
    KonaklamaID INT REFERENCES Konaklama(KonaklamaID) ON DELETE CASCADE,
    EkHizmetID INT REFERENCES EkHizmet(EkHizmetID) ON DELETE CASCADE,
    Adet INT NOT NULL CHECK (Adet > 0),
    Tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Odeme (
    OdemeID SERIAL PRIMARY KEY,
    KonaklamaID INT REFERENCES Konaklama(KonaklamaID) ON DELETE CASCADE,
    Tutar DECIMAL(10, 2) NOT NULL CHECK (Tutar > 0),
    OdemeTuru VARCHAR(20) NOT NULL CHECK (OdemeTuru IN ('Nakit', 'Kredi Kartı', 'Banka Transferi')),
    Tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE TemizlikKaydi (
    TemizlikKaydiID SERIAL PRIMARY KEY,
    OdaID INT REFERENCES Oda(OdaID) ON DELETE CASCADE,
    PersonelID INT REFERENCES Personel(PersonelID) ON DELETE SET NULL,
    Tarih TIMESTAMP NOT NULL,
    Durum VARCHAR(20) CHECK (Durum IN ('Yapıldı', 'Planlandı'))
);

CREATE TABLE IslemLog (
    LogID SERIAL PRIMARY KEY,
    TabloAdi VARCHAR(50) NOT NULL,
    IslemTipi VARCHAR(10) NOT NULL CHECK (IslemTipi IN ('INSERT', 'UPDATE', 'DELETE')),
    KayitID INT NOT NULL,
    EskiVeri JSONB,
    YeniVeri JSONB,
    Tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. İndeksler (Indexing)
CREATE INDEX idx_rezervasyon_tarihleri ON Rezervasyon(GirisTarihi, CikisTarihi);
CREATE INDEX idx_oda_numarasi ON Oda(OdaNumarasi);
CREATE INDEX idx_misafir_eposta ON Misafir(Eposta);
CREATE INDEX idx_misafir_tc ON Misafir(TCKimlikPasaportNo);

-- 3. Tetikleyiciler (Triggers) ve Fonksiyonlar

-- 3.1 Çakışan Rezervasyon Engelleme
CREATE OR REPLACE FUNCTION fn_CakisanRezervasyonEngelle()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM Rezervasyon
        WHERE OdaID = NEW.OdaID
          AND Durum IN ('Beklemede', 'Onaylı')
          AND RezervasyonID != COALESCE(NEW.RezervasyonID, -1)
          AND (
              (NEW.GirisTarihi < CikisTarihi AND NEW.CikisTarihi > GirisTarihi)
          )
    ) THEN
        RAISE EXCEPTION 'Bu oda için belirtilen tarihlerde çakışan başka bir rezervasyon bulunmaktadır.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_CakisanRezervasyonEngelle
BEFORE INSERT OR UPDATE ON Rezervasyon
FOR EACH ROW EXECUTE FUNCTION fn_CakisanRezervasyonEngelle();

-- 3.2 Oda Durum Güncelleme (Check-in ve Check-out)
CREATE OR REPLACE FUNCTION fn_OdaDurumuGuncelle()
RETURNS TRIGGER AS $$
DECLARE
    v_OdaID INT;
BEGIN
    SELECT OdaID INTO v_OdaID FROM Rezervasyon WHERE RezervasyonID = NEW.RezervasyonID;

    IF TG_OP = 'INSERT' THEN
        -- Check-in yapıldı, oda dolu
        UPDATE Oda SET Durum = 'Dolu' WHERE OdaID = v_OdaID;
    ELSIF TG_OP = 'UPDATE' THEN
        -- Check-out yapıldı, oda temizlikte
        IF OLD.GercekCikisZamani IS NULL AND NEW.GercekCikisZamani IS NOT NULL THEN
            UPDATE Oda SET Durum = 'Temizlikte' WHERE OdaID = v_OdaID;
            -- Rezervasyon durumunu da tamamlandı yap
            UPDATE Rezervasyon SET Durum = 'Tamamlandı' WHERE RezervasyonID = NEW.RezervasyonID;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_OdaDurumuGuncelle
AFTER INSERT OR UPDATE ON Konaklama
FOR EACH ROW EXECUTE FUNCTION fn_OdaDurumuGuncelle();

-- 3.3 Loglama İşlemi
CREATE OR REPLACE FUNCTION fn_IslemLogYaz()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO IslemLog (TabloAdi, IslemTipi, KayitID, YeniVeri)
        VALUES (TG_TABLE_NAME, TG_OP, 
                CASE WHEN TG_TABLE_NAME = 'rezervasyon' THEN NEW.RezervasyonID ELSE NEW.OdemeID END, 
                row_to_json(NEW)::jsonb);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        IF TG_TABLE_NAME = 'rezervasyon' THEN
            INSERT INTO IslemLog (TabloAdi, IslemTipi, KayitID, EskiVeri, YeniVeri)
            VALUES (TG_TABLE_NAME, TG_OP, NEW.RezervasyonID, row_to_json(OLD)::jsonb, row_to_json(NEW)::jsonb);
        ELSIF TG_TABLE_NAME = 'odeme' THEN
            INSERT INTO IslemLog (TabloAdi, IslemTipi, KayitID, EskiVeri, YeniVeri)
            VALUES (TG_TABLE_NAME, TG_OP, NEW.OdemeID, row_to_json(OLD)::jsonb, row_to_json(NEW)::jsonb);
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        IF TG_TABLE_NAME = 'rezervasyon' THEN
            INSERT INTO IslemLog (TabloAdi, IslemTipi, KayitID, EskiVeri)
            VALUES (TG_TABLE_NAME, TG_OP, OLD.RezervasyonID, row_to_json(OLD)::jsonb);
        ELSIF TG_TABLE_NAME = 'odeme' THEN
            INSERT INTO IslemLog (TabloAdi, IslemTipi, KayitID, EskiVeri)
            VALUES (TG_TABLE_NAME, TG_OP, OLD.OdemeID, row_to_json(OLD)::jsonb);
        END IF;
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_Log_Rezervasyon
AFTER INSERT OR UPDATE OR DELETE ON Rezervasyon
FOR EACH ROW EXECUTE FUNCTION fn_IslemLogYaz();

CREATE TRIGGER trg_Log_Odeme
AFTER INSERT OR UPDATE OR DELETE ON Odeme
FOR EACH ROW EXECUTE FUNCTION fn_IslemLogYaz();

-- 4. Saklı Yordamlar (Stored Procedures / Functions in PG)

-- 4.1 Boş Odaları Listele
CREATE OR REPLACE FUNCTION sp_BosOdalariListele(
    p_GirisTarihi DATE,
    p_CikisTarihi DATE,
    p_OdaTipiID INT
)
RETURNS TABLE (
    OdaID INT,
    OdaNumarasi VARCHAR,
    Kat INT,
    TemelFiyat DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT o.OdaID, o.OdaNumarasi, o.Kat, ot.TemelFiyat
    FROM Oda o
    JOIN OdaTipi ot ON o.OdaTipiID = ot.OdaTipiID
    WHERE o.OdaTipiID = p_OdaTipiID
      AND o.OdaID NOT IN (
          SELECT r.OdaID
          FROM Rezervasyon r
          WHERE r.Durum IN ('Beklemede', 'Onaylı')
            AND (p_GirisTarihi < r.CikisTarihi AND p_CikisTarihi > r.GirisTarihi)
      );
END;
$$ LANGUAGE plpgsql;

-- 4.2 Toplam Tutar Hesapla
CREATE OR REPLACE FUNCTION sp_ToplamTutarHesapla(p_KonaklamaID INT)
RETURNS DECIMAL(10,2) AS $$
DECLARE
    v_ToplamTutar DECIMAL(10,2) := 0;
    v_OdaTipiID INT;
    v_GirisTarihi DATE;
    v_CikisTarihi DATE;
    v_MevcutTarih DATE;
    v_GecelikFiyat DECIMAL(10,2);
    v_TemelFiyat DECIMAL(10,2);
    v_EkHizmetTutar DECIMAL(10,2) := 0;
BEGIN
    -- Rezervasyon bilgilerini al
    SELECT r.GirisTarihi, r.CikisTarihi, o.OdaTipiID, ot.TemelFiyat
    INTO v_GirisTarihi, v_CikisTarihi, v_OdaTipiID, v_TemelFiyat
    FROM Konaklama k
    JOIN Rezervasyon r ON k.RezervasyonID = r.RezervasyonID
    JOIN Oda o ON r.OdaID = o.OdaID
    JOIN OdaTipi ot ON o.OdaTipiID = ot.OdaTipiID
    WHERE k.KonaklamaID = p_KonaklamaID;

    -- Her gece için sezon fiyatı veya temel fiyat hesapla
    v_MevcutTarih := v_GirisTarihi;
    WHILE v_MevcutTarih < v_CikisTarihi LOOP
        -- O güne ait sezon fiyatı var mı kontrol et
        SELECT GecelikFiyat INTO v_GecelikFiyat
        FROM SezonFiyati
        WHERE OdaTipiID = v_OdaTipiID 
          AND v_MevcutTarih BETWEEN BaslangicTarihi AND (BitisTarihi - INTERVAL '1 day')
        LIMIT 1;

        IF FOUND THEN
            v_ToplamTutar := v_ToplamTutar + v_GecelikFiyat;
        ELSE
            v_ToplamTutar := v_ToplamTutar + v_TemelFiyat;
        END IF;

        v_MevcutTarih := v_MevcutTarih + INTERVAL '1 day';
    END LOOP;

    -- Ek Hizmetleri Topla
    SELECT COALESCE(SUM(eh.BirimFiyat * kh.Adet), 0)
    INTO v_EkHizmetTutar
    FROM KonaklamaHizmeti kh
    JOIN EkHizmet eh ON kh.EkHizmetID = eh.EkHizmetID
    WHERE kh.KonaklamaID = p_KonaklamaID;

    RETURN v_ToplamTutar + v_EkHizmetTutar;
END;
$$ LANGUAGE plpgsql;

-- 4.3 Aylık Doluluk ve Gelir Raporu
CREATE OR REPLACE FUNCTION sp_AylikDolulukVeGelirRaporu(
    p_Yil INT,
    p_Ay INT,
    p_OtelID INT
)
RETURNS TABLE (
    OtelAdi VARCHAR,
    ToplamGelir DECIMAL,
    DoluOdaSayisi INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        otl.Ad::VARCHAR,
        (SELECT COALESCE(SUM(Tutar), 0) FROM Odeme od 
         JOIN Konaklama k ON od.KonaklamaID = k.KonaklamaID
         JOIN Rezervasyon r ON k.RezervasyonID = r.RezervasyonID
         JOIN Oda o ON r.OdaID = o.OdaID
         WHERE o.OtelID = p_OtelID 
           AND EXTRACT(YEAR FROM od.Tarih) = p_Yil 
           AND EXTRACT(MONTH FROM od.Tarih) = p_Ay
        ) AS ToplamGelir,
        (SELECT COUNT(DISTINCT r.OdaID)::INT FROM Rezervasyon r
         JOIN Oda o ON r.OdaID = o.OdaID
         WHERE o.OtelID = p_OtelID
           AND EXTRACT(YEAR FROM r.GirisTarihi) = p_Yil 
           AND EXTRACT(MONTH FROM r.GirisTarihi) = p_Ay
           AND r.Durum IN ('Onaylı', 'Tamamlandı')
        ) AS DoluOdaSayisi
    FROM Otel otl
    WHERE otl.OtelID = p_OtelID;
END;
$$ LANGUAGE plpgsql;

-- 4.4 Check-Out İşlemi (Transaction barındıran Prosedür)
CREATE OR REPLACE PROCEDURE sp_CheckOutIslemi(
    p_KonaklamaID INT,
    p_PersonelID INT,
    p_OdemeTuru VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_ToplamTutar DECIMAL(10,2);
BEGIN
    -- Toplam borcu hesapla
    v_ToplamTutar := sp_ToplamTutarHesapla(p_KonaklamaID);
    
    -- Konaklama tablosunu güncelle
    UPDATE Konaklama 
    SET GercekCikisZamani = CURRENT_TIMESTAMP, 
        CikisIsleminiYapanPersonelID = p_PersonelID
    WHERE KonaklamaID = p_KonaklamaID;
    
    -- Ödemeyi al
    INSERT INTO Odeme (KonaklamaID, Tutar, OdemeTuru)
    VALUES (p_KonaklamaID, v_ToplamTutar, p_OdemeTuru);
    
    -- Oda durumu güncellemesi TRIGGER (trg_OdaDurumuGuncelle) tarafından otomatik yapılıyor
    -- İşlem tamamlandı. Transaction kontrolü otomatik yapılır
    COMMIT;
END;
$$;

-- 5. Görünümler (Views)

-- 5.1 Bugün giriş çıkış yapacaklar
CREATE OR REPLACE VIEW vw_BugunGirisCikisYapanlar AS
SELECT 
    r.RezervasyonID,
    m.Ad,
    m.Soyad,
    m.Telefon,
    o.OdaNumarasi,
    r.GirisTarihi,
    r.CikisTarihi,
    CASE 
        WHEN r.GirisTarihi = CURRENT_DATE THEN 'Giriş (Check-in)'
        WHEN r.CikisTarihi = CURRENT_DATE THEN 'Çıkış (Check-out)'
    END AS IslemTipi
FROM Rezervasyon r
JOIN Misafir m ON r.MisafirID = m.MisafirID
JOIN Oda o ON r.OdaID = o.OdaID
WHERE r.GirisTarihi = CURRENT_DATE OR r.CikisTarihi = CURRENT_DATE;

-- 5.2 Oda Güncel Durum ve Son Temizlik Tarihi
CREATE OR REPLACE VIEW vw_OdaGuncelDurum AS
SELECT 
    o.OdaNumarasi,
    ot.TipAdi,
    o.Kat,
    o.Durum,
    (SELECT MAX(Tarih) FROM TemizlikKaydi tk WHERE tk.OdaID = o.OdaID AND tk.Durum = 'Yapıldı') AS SonTemizlikTarihi
FROM Oda o
JOIN OdaTipi ot ON o.OdaTipiID = ot.OdaTipiID;
