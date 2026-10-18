import random
from datetime import datetime, timedelta

def generate_seed_data():
    sql = "-- Örnek Veri Seti\n\n"

    # 1. Otel
    sql += "INSERT INTO Otel (Ad, Adres, Sehir, Telefon, Eposta, YildizSayisi) VALUES "
    sql += "('Grand Antigravity Hotel', 'Teknoloji Bulvarı No:1', 'İstanbul', '+905551234567', 'info@grandantigravity.com', 5);\n\n"

    # 2. Oda Tipleri
    sql += "INSERT INTO OdaTipi (OtelID, TipAdi, Kapasite, Aciklama, TemelFiyat) VALUES\n"
    sql += "(1, 'Standart', 2, 'Standart iki kişilik oda', 1000.00),\n"
    sql += "(1, 'Deluxe', 3, 'Geniş ve deniz manzaralı oda', 2000.00),\n"
    sql += "(1, 'Suit', 4, 'Lüks aile odası', 4000.00);\n\n"

    # 3. Odalar (20 adet)
    sql += "INSERT INTO Oda (OtelID, OdaTipiID, OdaNumarasi, Kat, Durum) VALUES\n"
    rooms = []
    for i in range(1, 21):
        oda_tipi = random.choice([1, 1, 1, 2, 2, 3]) # Mostly standard
        kat = (i // 5) + 1
        oda_no = f"{kat}{i % 5 if i % 5 != 0 else 5}0"
        rooms.append(f"(1, {oda_tipi}, '{oda_no}', {kat}, 'Boş')")
    
    sql += ",\n".join(rooms) + ";\n\n"

    # 4. Misafirler (50 adet)
    names = ["Ahmet", "Mehmet", "Ayşe", "Fatma", "Ali", "Veli", "Can", "Cem", "Canan", "Zeynep", "Burak", "Ece", "Kaan", "Buse", "Oğuz", "Selin", "Murat", "Merve", "Emre", "Elif"]
    surnames = ["Yılmaz", "Kaya", "Demir", "Çelik", "Şahin", "Yıldız", "Öztürk", "Aydın", "Özdemir", "Arslan", "Doğan", "Kılıç", "Aslan", "Çetin", "Kara", "Koç", "Kurt", "Özkan", "Şimşek", "Polat"]
    
    sql += "INSERT INTO Misafir (Ad, Soyad, TCKimlikPasaportNo, Telefon, Eposta, DogumTarihi) VALUES\n"
    guests = []
    for i in range(1, 51):
        ad = random.choice(names)
        soyad = random.choice(surnames)
        tc = f"123456789{i:02d}"
        tel = f"+9055500011{i:02d}"
        email = f"guest{i}@example.com"
        guests.append(f"('{ad}', '{soyad}', '{tc}', '{tel}', '{email}', '1980-01-01')")
    
    sql += ",\n".join(guests) + ";\n\n"

    # 5. Personel (5 adet)
    sql += "INSERT INTO Personel (OtelID, Ad, Soyad, Gorev, IseGirisTarihi) VALUES\n"
    sql += "(1, 'Hasan', 'Müdür', 'Yönetici', '2020-01-01'),\n"
    sql += "(1, 'Ayşe', 'Güler', 'Resepsiyon', '2021-05-15'),\n"
    sql += "(1, 'Fatma', 'Temiz', 'Kat Görevlisi', '2022-03-10'),\n"
    sql += "(1, 'Ali', 'Çalışkan', 'Kat Görevlisi', '2023-01-20'),\n"
    sql += "(1, 'Mehmet', 'Sistemci', 'Sistem', '2020-01-01');\n\n"

    # 6. Rezervasyonlar (200 adet)
    # 20 room, each room gets 10 non-overlapping reservations
    sql += "INSERT INTO Rezervasyon (MisafirID, OdaID, GirisTarihi, CikisTarihi, KisiSayisi, Durum) VALUES\n"
    reservations = []
    start_date = datetime(2026, 1, 1)
    
    for room_id in range(1, 21):
        current_date = start_date
        for res in range(10):
            misafir_id = random.randint(1, 50)
            gap = random.randint(1, 5) # gap between reservations
            duration = random.randint(1, 4) # stay duration
            
            checkin = current_date + timedelta(days=gap)
            checkout = checkin + timedelta(days=duration)
            
            kisi = random.randint(1, 2)
            durum = random.choice(['Tamamlandı', 'Tamamlandı', 'Tamamlandı', 'Onaylı'])
            
            reservations.append(f"({misafir_id}, {room_id}, '{checkin.strftime('%Y-%m-%d')}', '{checkout.strftime('%Y-%m-%d')}', {kisi}, '{durum}')")
            
            current_date = checkout
            
    sql += ",\n".join(reservations) + ";\n\n"
    
    # 7. Ek Hizmetler
    sql += "INSERT INTO EkHizmet (OtelID, HizmetAdi, BirimFiyat) VALUES\n"
    sql += "(1, 'Kahvaltı Tabağı', 250.00),\n"
    sql += "(1, 'Açık Büfe Akşam Yemeği', 750.00),\n"
    sql += "(1, 'Spa & Masaj (45 Dk)', 1500.00),\n"
    sql += "(1, 'Mini Bar Tüketimi', 500.00);\n\n"

    with open('seed.sql', 'w', encoding='utf-8') as f:
        f.write(sql)
        
    print("seed.sql generated successfully.")

if __name__ == "__main__":
    generate_seed_data()
