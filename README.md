# MicroDefenders 🦠🔫

เกมยิงเชื้อโรค 2 ผู้เล่น สำหรับเด็กอายุ 6–12 ปี — เลือกยาให้ตรงกับชนิดของเชื้อโรค แล้วยิงปกป้องร่างกาย!
สร้างด้วย Godot 4.7

## ▶️ เล่นบนเว็บ

**https://jetsada2524.github.io/MicroDefenders/**

> เบราว์เซอร์จะเริ่มเล่นเสียงหลังจากคลิกหรือกดปุ่มครั้งแรก

## 🎮 ปุ่มควบคุม

| | เล็งเป้า | ยิง / เลือกยา |
|---|---|---|
| **Player 1** | เมาส์ | คลิกซ้าย |
| **Player 2** | W / A / S / D | Space |

รองรับปืน Light Gun (เช่น Sinden) ในโหมดจอย — เล็งที่จอแล้วเหนี่ยวไกได้เลย

## 🛠 พัฒนา

- เปิดโปรเจกต์ด้วย **Godot 4.7**
- ทุกครั้งที่ push ขึ้น `main` — GitHub Actions จะ build เวอร์ชัน Web แล้ว deploy ขึ้น GitHub Pages อัตโนมัติ (ดู `.github/workflows/deploy-web.yml`)

Export ในเครื่อง:

```bash
godot --headless --import
mkdir -p build/macos build/windows build/web
godot --headless --export-release "macOS" build/macos/MicroDefenders.zip
godot --headless --export-release "Windows Desktop" build/windows/MicroDefenders.exe
godot --headless --export-release "Web" build/web/index.html
```

## 📄 เครดิต

- ฟอนต์ Noto Sans, Noto Sans Thai, Noto Color Emoji — © The Noto Project Authors, SIL Open Font License 1.1 (`assets/fonts/OFL.txt`)
