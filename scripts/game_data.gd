## Global game constants and medicine/germ data — Autoload singleton
extends Node

# Medicine types matching germ colors
enum MedicineType {
	ANTIBIOTIC,     # Green  - kills Bacteria
	VACCINE,        # Purple - kills Virus
	ANTIFUNGAL,     # Orange - kills Fungus
	ANTIPARASITIC,  # Blue   - kills Parasite
	SPECIFIC        # Red    - kills Superbug
}

# Germ types
enum GermType {
	BACTERIA,   # Green
	VIRUS,      # Purple
	FUNGUS,     # Orange
	PARASITE,   # Blue
	SUPERBUG    # Red (Boss)
}

# Color for each medicine/germ type
const COLORS := {
	MedicineType.ANTIBIOTIC:    Color(0.2, 0.8, 0.3),    # Green
	MedicineType.VACCINE:       Color(0.6, 0.2, 0.8),    # Purple
	MedicineType.ANTIFUNGAL:    Color(1.0, 0.5, 0.1),    # Orange
	MedicineType.ANTIPARASITIC: Color(0.2, 0.6, 1.0),    # Blue
	MedicineType.SPECIFIC:      Color(0.9, 0.15, 0.15),  # Red
}

# Medicine-to-Germ matching
const MEDICINE_TO_GERM := {
	MedicineType.ANTIBIOTIC:    GermType.BACTERIA,
	MedicineType.VACCINE:       GermType.VIRUS,
	MedicineType.ANTIFUNGAL:    GermType.FUNGUS,
	MedicineType.ANTIPARASITIC: GermType.PARASITE,
	MedicineType.SPECIFIC:      GermType.SUPERBUG,
}

# Germ names (Thai)
const GERM_NAMES := {
	GermType.BACTERIA: "แบคทีเรีย",
	GermType.VIRUS:    "ไวรัส",
	GermType.FUNGUS:   "เชื้อรา",
	GermType.PARASITE: "พยาธิ",
	GermType.SUPERBUG: "ซูเปอร์บั๊ก",
}

# Medicine names (Thai)
const MEDICINE_NAMES := {
	MedicineType.ANTIBIOTIC:    "ยาปฏิชีวนะ",
	MedicineType.VACCINE:       "วัคซีน/ภูมิคุ้มกัน",
	MedicineType.ANTIFUNGAL:    "ยาต้านเชื้อรา",
	MedicineType.ANTIPARASITIC: "ยาถ่ายพยาธิ",
	MedicineType.SPECIFIC:      "ยาเฉพาะทาง",
}

# Knowledge text shown when selecting each medicine
const MEDICINE_KNOWLEDGE := {
	MedicineType.ANTIBIOTIC:    "ยาปฏิชีวนะฆ่าแบคทีเรียได้\nแต่ใช้กับไวรัสไม่ได้ผลนะ!",
	MedicineType.VACCINE:       "วัคซีนช่วยสร้างภูมิคุ้มกัน\nให้ร่างกายจัดการไวรัสเอง!",
	MedicineType.ANTIFUNGAL:    "เชื้อราต้องใช้ยาต้านเชื้อราเท่านั้น\nยาอื่นไม่ได้ผล!",
	MedicineType.ANTIPARASITIC: "พยาธิเป็นสิ่งมีชีวิตตัวใหญ่\nต้องใช้ยาถ่ายพยาธิโดยเฉพาะ!",
	MedicineType.SPECIFIC:      "ซูเปอร์บั๊กดื้อยาทั่วไป!\nต้องใช้ยาเฉพาะทางเท่านั้น!",
}

# Scoring
const SCORE_HIT := 100
const SCORE_BONUS_CORRECT := 50
const SCORE_SUPERBUG := 300
const SCORE_WRONG_MEDICINE_PENALTY := -50
const SCORE_GERM_REACHED_ORGAN := -25

# Germ speeds (units/sec)
const GERM_SPEED := {
	GermType.BACTERIA: 0.72,
	GermType.VIRUS:    0.9,
	GermType.FUNGUS:   0.54,
	GermType.PARASITE: 1.08,
	GermType.SUPERBUG: 0.42,
}

# Germ sizes (scale multiplier)
const GERM_SCALE := {
	GermType.BACTERIA: 0.4,
	GermType.VIRUS:    0.35,
	GermType.FUNGUS:   0.45,
	GermType.PARASITE: 0.5,
	GermType.SUPERBUG: 0.8,
}

# Points per germ type
const GERM_POINTS := {
	GermType.BACTERIA: 100,
	GermType.VIRUS:    120,
	GermType.FUNGUS:   110,
	GermType.PARASITE: 130,
	GermType.SUPERBUG: 300,
}

# Game settings
const ROUND_TIME := 30.0  # 30 seconds
const SUDDEN_DEATH_TIME := 15.0
const SPAWN_INTERVAL_START := 2.0
const SPAWN_INTERVAL_END := 0.6
const LAST_SECONDS_WARNING := 10

# Organ data
const ORGAN_NAMES := {
	"brain":    "สมอง: ศูนย์บัญชาการของร่างกาย!",
	"heart":    "หัวใจ: สูบฉีดเลือดไปทั่วร่างกาย!",
	"lungs":    "ปอด: ช่วยเราหายใจ อย่าให้เชื้อเข้า!",
	"liver":    "ตับ: กรองสารพิษออกจากเลือด!",
	"stomach":  "กระเพาะ: ย่อยอาหารให้ร่างกาย!",
	"intestine":"ลำไส้: ดูดซึมสารอาหารที่ร่างกายต้องการ!",
	"kidney":   "ไต: กรองของเสียออกจากเลือด!",
}

func germ_to_medicine(germ_type: GermType) -> MedicineType:
	for med in MEDICINE_TO_GERM:
		if MEDICINE_TO_GERM[med] == germ_type:
			return med
	return MedicineType.ANTIBIOTIC

func get_color_for_germ(germ_type: GermType) -> Color:
	var med = germ_to_medicine(germ_type)
	return COLORS[med]
