import Foundation

enum WidgetRelativeTimeKind {
    case startsIn
    case remaining
}

struct WidgetRelativeDuration {
    let days: Int
    let hours: Int
    let minutes: Int

    init(interval: Int) {
        let clamped = max(interval, 0)
        days = clamped / 86_400
        hours = (clamped % 86_400) / 3_600
        minutes = (clamped % 3_600) / 60
    }
}

enum WidgetSampleTaskTitle {
    case mockExam
    case projectReview
    case morningRun
    case submitReport
}

private enum WidgetTranslations {
    static let table: [String: [WidgetLanguage: String]] = [
        "All Categories": [
            .japanese: "すべてのカテゴリ",
            .korean: "모든 카테고리",
            .spanishSpain: "Todas las categorías",
            .spanishMexico: "Todas las categorías",
            .french: "Toutes les catégories",
            .german: "Alle Kategorien",
            .thai: "ทุกหมวดหมู่",
            .vietnamese: "Tất cả danh mục",
            .indonesian: "Semua kategori",
        ],
        "End": [
            .japanese: "終了",
            .korean: "종료",
            .spanishSpain: "Fin",
            .spanishMexico: "Fin",
            .french: "Fin",
            .german: "Ende",
            .thai: "สิ้นสุด",
            .vietnamese: "Kết thúc",
            .indonesian: "Akhir",
        ],
        "In Progress": [
            .japanese: "進行中",
            .korean: "진행 중",
            .spanishSpain: "En curso",
            .spanishMexico: "En curso",
            .french: "En cours",
            .german: "In Bearbeitung",
            .thai: "กำลังดำเนินการ",
            .vietnamese: "Đang thực hiện",
            .indonesian: "Sedang berlangsung",
        ],
        "Mock Exam": [
            .japanese: "模擬試験",
            .korean: "모의고사",
            .spanishSpain: "Examen de prueba",
            .spanishMexico: "Examen de práctica",
            .french: "Examen blanc",
            .german: "Probeprüfung",
            .thai: "สอบจำลอง",
            .vietnamese: "Thi thử",
            .indonesian: "Ujian percobaan",
        ],
        "Morning Run": [
            .japanese: "朝のランニング",
            .korean: "아침 달리기",
            .spanishSpain: "Carrera matutina",
            .spanishMexico: "Carrera matutina",
            .french: "Course du matin",
            .german: "Morgenlauf",
            .thai: "วิ่งตอนเช้า",
            .vietnamese: "Chạy bộ buổi sáng",
            .indonesian: "Lari pagi",
        ],
        "No active task": [
            .japanese: "進行中のタスクはありません",
            .korean: "진행 중인 작업이 없습니다",
            .spanishSpain: "No hay tareas activas",
            .spanishMexico: "No hay tareas activas",
            .french: "Aucune tâche active",
            .german: "Keine aktive Aufgabe",
            .thai: "ไม่มีงานที่กำลังดำเนินการ",
            .vietnamese: "Không có tác vụ đang thực hiện",
            .indonesian: "Tidak ada tugas aktif",
        ],
        "No matching tasks": [
            .japanese: "一致するタスクはありません",
            .korean: "일치하는 작업이 없습니다",
            .spanishSpain: "No hay tareas coincidentes",
            .spanishMexico: "No hay tareas coincidentes",
            .french: "Aucune tâche correspondante",
            .german: "Keine passenden Aufgaben",
            .thai: "ไม่มีงานที่ตรงกัน",
            .vietnamese: "Không có tác vụ phù hợp",
            .indonesian: "Tidak ada tugas yang cocok",
        ],
        "No upcoming task": [
            .japanese: "次のタスクはありません",
            .korean: "예정된 작업이 없습니다",
            .spanishSpain: "No hay próximas tareas",
            .spanishMexico: "No hay próximas tareas",
            .french: "Aucune tâche à venir",
            .german: "Keine bevorstehende Aufgabe",
            .thai: "ไม่มีงานที่กำลังจะเริ่ม",
            .vietnamese: "Không có tác vụ sắp tới",
            .indonesian: "Tidak ada tugas mendatang",
        ],
        "Not Started": [
            .japanese: "未開始",
            .korean: "시작 전",
            .spanishSpain: "Sin empezar",
            .spanishMexico: "Sin empezar",
            .french: "Pas commencé",
            .german: "Nicht begonnen",
            .thai: "ยังไม่เริ่ม",
            .vietnamese: "Chưa bắt đầu",
            .indonesian: "Belum dimulai",
        ],
        "Open the app to review.": [
            .japanese: "アプリを開いて確認",
            .korean: "앱을 열어 확인하세요",
            .spanishSpain: "Abre la app para revisarlo.",
            .spanishMexico: "Abre la app para revisarlo.",
            .french: "Ouvrez l'app pour vérifier.",
            .german: "Öffne die App, um nachzusehen.",
            .thai: "เปิดแอปเพื่อตรวจสอบ",
            .vietnamese: "Mở ứng dụng để xem.",
            .indonesian: "Buka aplikasi untuk melihatnya.",
        ],
        "Project Review": [
            .japanese: "プロジェクトレビュー",
            .korean: "프로젝트 검토",
            .spanishSpain: "Revisión del proyecto",
            .spanishMexico: "Revisión del proyecto",
            .french: "Revue du projet",
            .german: "Projektprüfung",
            .thai: "ทบทวนโปรเจกต์",
            .vietnamese: "Rà soát dự án",
            .indonesian: "Tinjauan proyek",
        ],
        "Start": [
            .japanese: "開始",
            .korean: "시작",
            .spanishSpain: "Inicio",
            .spanishMexico: "Inicio",
            .french: "Début",
            .german: "Start",
            .thai: "เริ่ม",
            .vietnamese: "Bắt đầu",
            .indonesian: "Mulai",
        ],
        "Starting Soon": [
            .japanese: "まもなく開始",
            .korean: "곧 시작",
            .spanishSpain: "Empieza pronto",
            .spanishMexico: "Empieza pronto",
            .french: "Commence bientôt",
            .german: "Beginnt bald",
            .thai: "ใกล้เริ่ม",
            .vietnamese: "Sắp bắt đầu",
            .indonesian: "Segera dimulai",
        ],
        "Submit Report": [
            .japanese: "レポート提出",
            .korean: "보고서 제출",
            .spanishSpain: "Entregar informe",
            .spanishMexico: "Entregar reporte",
            .french: "Remettre le rapport",
            .german: "Bericht einreichen",
            .thai: "ส่งรายงาน",
            .vietnamese: "Nộp báo cáo",
            .indonesian: "Kirim laporan",
        ],
        "Try another category or status.": [
            .japanese: "別のカテゴリや状態を試してください。",
            .korean: "다른 카테고리나 상태를 시도해 보세요.",
            .spanishSpain: "Prueba otra categoría o estado.",
            .spanishMexico: "Prueba otra categoría o estado.",
            .french: "Essayez une autre catégorie ou un autre état.",
            .german: "Versuche eine andere Kategorie oder einen anderen Status.",
            .thai: "ลองเปลี่ยนหมวดหมู่หรือสถานะอื่น",
            .vietnamese: "Hãy thử danh mục hoặc trạng thái khác.",
            .indonesian: "Coba kategori atau status lain.",
        ],
    ]

    static func localized(_ english: String, for language: WidgetLanguage) -> String? {
        if language == .russian {
            return WidgetRussianTranslations.table[english]
        }
        return table[english]?[language]
    }
}

extension WidgetLanguage {
    static func detectFromSystem() -> WidgetLanguage {
        let preferredLanguage = Locale.preferredLanguages.first?.lowercased() ?? ""
        if preferredLanguage.hasPrefix("zh") {
            return .chinese
        }
        if preferredLanguage.hasPrefix("ja") {
            return .japanese
        }
        if preferredLanguage.hasPrefix("ko") {
            return .korean
        }
        if preferredLanguage.hasPrefix("es-mx") {
            return .spanishMexico
        }
        if preferredLanguage.hasPrefix("es") {
            return .spanishSpain
        }
        if preferredLanguage.hasPrefix("fr") {
            return .french
        }
        if preferredLanguage.hasPrefix("de") {
            return .german
        }
        if preferredLanguage.hasPrefix("th") {
            return .thai
        }
        if preferredLanguage.hasPrefix("vi") {
            return .vietnamese
        }
        if preferredLanguage.hasPrefix("ru") {
            return .russian
        }
        if preferredLanguage.hasPrefix("id") || preferredLanguage.hasPrefix("in") {
            return .indonesian
        }
        return .english
    }

    func localizedText(_ english: String, chinese: String) -> String {
        switch self {
        case .english:
            return english
        case .chinese:
            return chinese
        default:
            return WidgetTranslations.localized(english, for: self) ?? english
        }
    }

    func durationText(_ duration: WidgetRelativeDuration) -> String {
        if duration.days > 0 {
            switch self {
            case .english:
                return "\(duration.days)d \(duration.hours)h"
            case .chinese:
                return "\(duration.days)天\(duration.hours)时"
            case .japanese:
                return "\(duration.days)日\(duration.hours)時間"
            case .korean:
                return "\(duration.days)일 \(duration.hours)시간"
            case .spanishSpain, .spanishMexico:
                return "\(duration.days) d \(duration.hours) h"
            case .french:
                return "\(duration.days) j \(duration.hours) h"
            case .german:
                return "\(duration.days) T \(duration.hours) Std."
            case .thai:
                return "\(duration.days) วัน \(duration.hours) ชม."
            case .vietnamese:
                return "\(duration.days) ngày \(duration.hours) giờ"
            case .indonesian:
                return "\(duration.days) hari \(duration.hours) jam"
            case .russian:
                return "\(duration.days) д \(duration.hours) ч"
            }
        }

        if duration.hours > 0 {
            switch self {
            case .english:
                return "\(duration.hours)h \(duration.minutes)m"
            case .chinese:
                return "\(duration.hours)时\(duration.minutes)分"
            case .japanese:
                return "\(duration.hours)時間\(duration.minutes)分"
            case .korean:
                return "\(duration.hours)시간 \(duration.minutes)분"
            case .spanishSpain, .spanishMexico:
                return "\(duration.hours) h \(duration.minutes) min"
            case .french:
                return "\(duration.hours) h \(duration.minutes) min"
            case .german:
                return "\(duration.hours) Std. \(duration.minutes) Min."
            case .thai:
                return "\(duration.hours) ชม. \(duration.minutes) นาที"
            case .vietnamese:
                return "\(duration.hours) giờ \(duration.minutes) phút"
            case .indonesian:
                return "\(duration.hours) jam \(duration.minutes) mnt"
            case .russian:
                return "\(duration.hours) ч \(duration.minutes) мин"
            }
        }

        let minutes = max(duration.minutes, 1)
        switch self {
        case .english:
            return "\(minutes)m"
        case .chinese:
            return "\(minutes)分"
        case .japanese:
            return "\(minutes)分"
        case .korean:
            return "\(minutes)분"
        case .spanishSpain, .spanishMexico:
            return "\(minutes) min"
        case .french:
            return "\(minutes) min"
        case .german:
            return "\(minutes) Min."
        case .thai:
            return "\(minutes) นาที"
        case .vietnamese:
            return "\(minutes) phút"
        case .indonesian:
            return "\(minutes) mnt"
        case .russian:
            return "\(minutes) мин"
        }
    }

    func relativeTimeText(_ kind: WidgetRelativeTimeKind, duration: WidgetRelativeDuration) -> String {
        let value = durationText(duration)
        switch self {
        case .english:
            return kind == .startsIn ? "Starts in \(value)" : "Remaining \(value)"
        case .chinese:
            return kind == .startsIn ? "距开始 \(value)" : "剩余 \(value)"
        case .japanese:
            return kind == .startsIn ? "開始まで \(value)" : "残り \(value)"
        case .korean:
            return kind == .startsIn ? "시작까지 \(value)" : "남은 시간 \(value)"
        case .spanishSpain, .spanishMexico:
            return kind == .startsIn ? "Empieza en \(value)" : "Quedan \(value)"
        case .french:
            return kind == .startsIn ? "Débute dans \(value)" : "Reste \(value)"
        case .german:
            return kind == .startsIn ? "Beginnt in \(value)" : "Verbleibend \(value)"
        case .thai:
            return kind == .startsIn ? "เริ่มในอีก \(value)" : "เหลืออีก \(value)"
        case .vietnamese:
            return kind == .startsIn ? "Bắt đầu sau \(value)" : "Còn lại \(value)"
        case .indonesian:
            return kind == .startsIn ? "Mulai dalam \(value)" : "Sisa \(value)"
        case .russian:
            return kind == .startsIn ? "Начнётся через \(value)" : "Осталось \(value)"
        }
    }

    func builtInCategoryName(for identifier: String) -> String? {
        switch identifier {
        case "study":
            switch self {
            case .english: return "Study"
            case .chinese: return "学习"
            case .japanese: return "勉強"
            case .korean: return "공부"
            case .spanishSpain, .spanishMexico: return "Estudio"
            case .french: return "Études"
            case .german: return "Lernen"
            case .thai: return "การเรียน"
            case .vietnamese: return "Học tập"
            case .indonesian: return "Belajar"
            case .russian: return "Учёба"
            }
        case "work":
            switch self {
            case .english: return "Work"
            case .chinese: return "工作"
            case .japanese: return "仕事"
            case .korean: return "업무"
            case .spanishSpain, .spanishMexico: return "Trabajo"
            case .french: return "Travail"
            case .german: return "Arbeit"
            case .thai: return "งาน"
            case .vietnamese: return "Công việc"
            case .indonesian: return "Kerja"
            case .russian: return "Работа"
            }
        case "life":
            switch self {
            case .english: return "Life"
            case .chinese: return "生活"
            case .japanese: return "生活"
            case .korean: return "생활"
            case .spanishSpain, .spanishMexico: return "Vida"
            case .french: return "Vie"
            case .german: return "Leben"
            case .thai: return "ชีวิต"
            case .vietnamese: return "Cuộc sống"
            case .indonesian: return "Hidup"
            case .russian: return "Жизнь"
            }
        case "health":
            switch self {
            case .english: return "Health"
            case .chinese: return "健康"
            case .japanese: return "健康"
            case .korean: return "건강"
            case .spanishSpain, .spanishMexico: return "Salud"
            case .french: return "Santé"
            case .german: return "Gesundheit"
            case .thai: return "สุขภาพ"
            case .vietnamese: return "Sức khỏe"
            case .indonesian: return "Kesehatan"
            case .russian: return "Здоровье"
            }
        case "finance":
            switch self {
            case .english: return "Finance"
            case .chinese: return "财务"
            case .japanese: return "家計"
            case .korean: return "재정"
            case .spanishSpain, .spanishMexico: return "Finanzas"
            case .french: return "Finances"
            case .german: return "Finanzen"
            case .thai: return "การเงิน"
            case .vietnamese: return "Tài chính"
            case .indonesian: return "Keuangan"
            case .russian: return "Финансы"
            }
        default:
            return nil
        }
    }

    func sampleTaskTitle(_ title: WidgetSampleTaskTitle) -> String {
        switch title {
        case .mockExam:
            return localizedText("Mock Exam", chinese: "模拟考试")
        case .projectReview:
            return localizedText("Project Review", chinese: "项目评审")
        case .morningRun:
            return localizedText("Morning Run", chinese: "晨跑")
        case .submitReport:
            return localizedText("Submit Report", chinese: "提交报告")
        }
    }
}
