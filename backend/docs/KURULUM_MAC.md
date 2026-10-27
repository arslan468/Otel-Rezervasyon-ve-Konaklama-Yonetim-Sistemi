# MACBOOK AIR (APPLE SILICON) ORTAM KURULUM KILAVUZU

Bu rehber, projenin veritabanı (MSSQL 2022) ve araçlarının Apple Silicon (M1/M2/M3/M4) mimarili Mac bilgisayarlarda adım adım ve sıfır hata ile nasıl kurulacağını açıklar.

---

## 1. Adım: Mevcut Container'ı Durdurma ve Temizleme

Daha önce port 1433 üzerinde elle başlatılmış olan eski `sql_server_container`'ı durdurup kaldırıyoruz:

```zsh
# 1. Eski container'ı durdur
docker stop sql_server_container

# 2. Eski container'ı sil (compose yeni ve temiz bir container ayağa kaldıracak)
docker rm sql_server_container
```

---

## 2. Adım: Docker Compose ile Ortamı Ayağa Kaldırma

Proje kök dizininde (`prototip_otel`) terminalden şu komutu çalıştırın:

```zsh
docker compose up -d
```

### Durumu Doğrulama:
```zsh
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

**Beklenen Çıktı:**
```text
NAMES               STATUS                   PORTS
otel_mssql_2022     Up (healthy)             0.0.0.0:1433->1433/tcp
otel_mailpit        Up                       0.0.0.0:1025->1025/tcp, 0.0.0.0:8025->8025/tcp
```
> **Not:** Tarayıcınızdan `http://localhost:8025` adresine girdiğinizde **Mailpit** e-posta test arayüzünün açıldığını göreceksiniz.

---

## 3. Adım: macOS Terminalinde Microsoft ODBC 18 Sürücüsünü Kurma

Python Flask uygulamasının SQL Server'a bağlanabilmesi için resmi Microsoft ODBC sürücüsünü Homebrew ile kuruyoruz:

```zsh
# 1. Microsoft resmi reposunu Homebrew'a ekleyin
brew tap microsoft/mssql-release https://github.com/Microsoft/homebrew-mssql-release

# 2. Homebrew 6+ sürümleri için tap güvenini onaylayın
brew trust microsoft/mssql-release 2>/dev/null || true

# 3. Paket listesini güncelleyin
brew update

# 4. EULA lisansını onaylayarak ODBC Driver 18 ve araçları kurun
HOMEBREW_ACCEPT_EULA=Y brew install msodbcsql18 mssql-tools18
```

### Kurulumu Doğrulama:
```zsh
odbcinst -q -d
```
**Beklenen Çıktı:**
```text
[ODBC Driver 18 for SQL Server]
```

---

## 4. Adım: VS Code + MSSQL Eklentisi ile Bağlantı Kurma

1. **VS Code**'u açın.
2. Sol kenar çubuğundaki **Extensions (Eklentiler)** simgesine tıklayın (veya `Cmd + Shift + X`).
3. Arama çubuğuna **`MSSQL`** (Microsoft tarafından geliştirilen resmi eklenti) yazın ve **Install** deyin.
4. Sol çubukta beliren **SQL Server** ikonuna tıklayın, üst kısımdaki **`+` (Add Connection)** butonuna basın:
   - **Server name / Host:** `localhost,1433` (veya `127.0.0.1,1433`)
   - **Database name:** `<default>` (veya `master`)
   - **Authentication type:** `SQL Login`
   - **User name:** `sa`
   - **Password:** `OtelProje2026!GucluSifre`
   - **Save Password:** `Yes`
   - **Profile Name:** `OtelDB_Yerel_SA`
   - **Trust server certificate:** `True` (Docker kendinden imzalı SSL sertifikası kullandığı için bu ayar mutlaka True olmalıdır).

---

## 5. Adım: Sırayla Çalıştırılacak SQL Betikleri

VS Code içinde `File -> Open File` diyerek veya sol dosya gezgininden şu dosyaları **sırayla açıp** `Ctrl + Shift + E` (veya sağ tıklayıp *Execute Query*) ile çalıştırın:

1. **`sql/00_kurulum/000_veritabani_olustur.sql`**
   - *Görevi:* `OtelDB`'yi `Turkish_CI_AS` collation, uyumluluk 160 ve RCSI ile oluşturur.
2. **`sql/00_kurulum/001_yardimci_nesneler.sql`**
   - *Görevi:* `dbo.fn_bugun()`, `dbo.fn_simdi_tr()` ve `dbo.usp_aciklama_yaz` nesnelerini oluşturur.
3. **`sql/00_kurulum/002_otel_app_login.sql`**
   - *Görevi:* En az yetkili `otel_app` kullanıcısını ve temel izinlerini tanımlar.
