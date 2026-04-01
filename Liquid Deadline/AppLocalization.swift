import Foundation

struct PrivacyPolicySection {
    let title: String
    let body: String
}

struct PrivacyPolicyContent {
    let title: String
    let effectiveDate: String
    let sections: [PrivacyPolicySection]
}

enum RelativeTimePhrase {
    case startsIn
    case remaining
}

private enum AppTranslations {
    static let table: [String: [AppLanguage: String]] = [
        "0m": [
            .japanese: "0分",
            .korean: "0분",
            .spanishSpain: "0 min",
            .spanishMexico: "0 min",
            .french: "0 min",
            .german: "0 Min.",
            .thai: "0 นาที",
            .vietnamese: "0 phút",
            .indonesian: "0 mnt",
        ],
        "A different iCloud account is now available. Choose whether to merge your local data into the current account, clear local synced data and download from iCloud again, or keep data local with automatic sync turned off.": [
            .japanese: "現在、別のiCloudアカウントが利用可能です。ローカルデータを現在のアカウントに統合するか、ローカルの同期データを消去してiCloudから再取得するか、または自動同期をオフにしてローカルデータのみを保持するかを選択してください。",
            .korean: "현재 다른 iCloud 계정을 사용할 수 있습니다. 로컬 데이터를 현재 계정과 병합할지, 로컬 동기화 데이터를 지우고 iCloud에서 다시 내려받을지, 또는 자동 동기화를 끄고 데이터를 로컬에만 유지할지 선택하세요.",
            .spanishSpain: "Ahora hay disponible una cuenta de iCloud diferente. Elige si quieres combinar tus datos locales con la cuenta actual, borrar los datos locales sincronizados y volver a descargar desde iCloud, o mantener los datos solo en local con la sincronización automática desactivada.",
            .spanishMexico: "Ahora hay disponible una cuenta de iCloud diferente. Elige si quieres combinar tus datos locales con la cuenta actual, borrar los datos locales sincronizados y volver a descargar desde iCloud, o mantener los datos solo de forma local con la sincronización automática desactivada.",
            .french: "Un autre compte iCloud est maintenant disponible. Choisissez si vous voulez fusionner vos données locales avec le compte actuel, effacer les données locales synchronisées et les retélécharger depuis iCloud, ou conserver les données uniquement en local avec la synchronisation automatique désactivée.",
            .german: "Es ist jetzt ein anderes iCloud-Konto verfügbar. Wähle, ob du deine lokalen Daten mit dem aktuellen Konto zusammenführen, lokal synchronisierte Daten löschen und erneut aus iCloud laden oder die Daten nur lokal behalten und die automatische Synchronisierung deaktivieren möchtest.",
            .thai: "ขณะนี้มีบัญชี iCloud อื่นพร้อมใช้งาน เลือกว่าจะรวมข้อมูลในเครื่องเข้ากับบัญชีปัจจุบัน ลบข้อมูลที่ซิงค์ไว้ในเครื่องแล้วดาวน์โหลดจาก iCloud ใหม่อีกครั้ง หรือเก็บข้อมูลไว้เฉพาะในเครื่องโดยปิดการซิงค์อัตโนมัติ",
            .vietnamese: "Hiện có một tài khoản iCloud khác khả dụng. Hãy chọn giữa việc gộp dữ liệu cục bộ vào tài khoản hiện tại, xóa dữ liệu cục bộ đã đồng bộ và tải lại từ iCloud, hoặc chỉ giữ dữ liệu trên thiết bị và tắt đồng bộ tự động.",
            .indonesian: "Sekarang tersedia akun iCloud yang berbeda. Pilih apakah ingin menggabungkan data lokal ke akun saat ini, menghapus data lokal yang tersinkron lalu mengunduh ulang dari iCloud, atau menyimpan data hanya secara lokal dengan sinkronisasi otomatis dimatikan.",
        ],
        "Add": [
            .japanese: "追加",
            .korean: "추가",
            .spanishSpain: "Añadir",
            .spanishMexico: "Agregar",
            .french: "Ajouter",
            .german: "Hinzufügen",
            .thai: "เพิ่ม",
            .vietnamese: "Thêm",
            .indonesian: "Tambah",
        ],
        "Added Date Ascending": [
            .japanese: "追加日 昇順",
            .korean: "추가 날짜 오름차순",
            .spanishSpain: "Fecha de adición ascendente",
            .spanishMexico: "Fecha de agregado ascendente",
            .french: "Date d'ajout croissante",
            .german: "Hinzugefügt am aufsteigend",
            .thai: "วันที่เพิ่มจากเก่าไปใหม่",
            .vietnamese: "Ngày thêm tăng dần",
            .indonesian: "Tanggal ditambahkan menaik",
        ],
        "Added Date Descending": [
            .japanese: "追加日 降順",
            .korean: "추가 날짜 내림차순",
            .spanishSpain: "Fecha de adición descendente",
            .spanishMexico: "Fecha de agregado descendente",
            .french: "Date d'ajout décroissante",
            .german: "Hinzugefügt am absteigend",
            .thai: "วันที่เพิ่มจากใหม่ไปเก่า",
            .vietnamese: "Ngày thêm giảm dần",
            .indonesian: "Tanggal ditambahkan menurun",
        ],
        "All": [
            .japanese: "すべて",
            .korean: "전체",
            .spanishSpain: "Todo",
            .spanishMexico: "Todo",
            .french: "Tout",
            .german: "Alle",
            .thai: "ทั้งหมด",
            .vietnamese: "Tất cả",
            .indonesian: "Semua",
        ],
        "Automatic Sync": [
            .japanese: "自動同期",
            .korean: "자동 동기화",
            .spanishSpain: "Sincronización automática",
            .spanishMexico: "Sincronización automática",
            .french: "Synchronisation automatique",
            .german: "Automatische Synchronisierung",
            .thai: "ซิงค์อัตโนมัติ",
            .vietnamese: "Đồng bộ tự động",
            .indonesian: "Sinkronisasi otomatis",
        ],
        "Background": [
            .japanese: "背景",
            .korean: "배경",
            .spanishSpain: "Fondo",
            .spanishMexico: "Fondo",
            .french: "Arrière-plan",
            .german: "Hintergrund",
            .thai: "พื้นหลัง",
            .vietnamese: "Nền",
            .indonesian: "Latar belakang",
        ],
        "Background Style": [
            .japanese: "背景スタイル",
            .korean: "배경 스타일",
            .spanishSpain: "Estilo de fondo",
            .spanishMexico: "Estilo de fondo",
            .french: "Style d'arrière-plan",
            .german: "Hintergrundstil",
            .thai: "สไตล์พื้นหลัง",
            .vietnamese: "Kiểu nền",
            .indonesian: "Gaya latar belakang",
        ],
        "Blue-White Gradient": [
            .japanese: "ブルー・ホワイト グラデーション",
            .korean: "블루-화이트 그라데이션",
            .spanishSpain: "Degradado blanco-azul",
            .spanishMexico: "Degradado blanco-azul",
            .french: "Dégradé bleu-blanc",
            .german: "Blau-Weiß-Verlauf",
            .thai: "ไล่เฉดน้ำเงิน-ขาว",
            .vietnamese: "Chuyển sắc xanh-trắng",
            .indonesian: "Gradasi biru-putih",
        ],
        "Calendar Import": [
            .japanese: "カレンダー取り込み",
            .korean: "캘린더 가져오기",
            .spanishSpain: "Importación de calendario",
            .spanishMexico: "Importación de calendario",
            .french: "Importation de calendrier",
            .german: "Kalenderimport",
            .thai: "นำเข้าปฏิทิน",
            .vietnamese: "Nhập lịch",
            .indonesian: "Impor kalender",
        ],
        "Cancel": [
            .japanese: "キャンセル",
            .korean: "취소",
            .spanishSpain: "Cancelar",
            .spanishMexico: "Cancelar",
            .french: "Annuler",
            .german: "Abbrechen",
            .thai: "ยกเลิก",
            .vietnamese: "Hủy",
            .indonesian: "Batal",
        ],
        "Category": [
            .japanese: "カテゴリ",
            .korean: "카테고리",
            .spanishSpain: "Categoría",
            .spanishMexico: "Categoría",
            .french: "Catégorie",
            .german: "Kategorie",
            .thai: "หมวดหมู่",
            .vietnamese: "Danh mục",
            .indonesian: "Kategori",
        ],
        "Choose File": [
            .japanese: "ファイルを選択",
            .korean: "파일 선택",
            .spanishSpain: "Elegir archivo",
            .spanishMexico: "Elegir archivo",
            .french: "Choisir un fichier",
            .german: "Datei auswählen",
            .thai: "เลือกไฟล์",
            .vietnamese: "Chọn tệp",
            .indonesian: "Pilih file",
        ],
        "Choose whether to delete only this event or this event and all following events in the series.": [
            .japanese: "この予定のみを削除するか、この予定以降のすべての予定を削除するかを選択してください。",
            .korean: "이 일정만 삭제할지, 이 일정과 이후의 모든 일정을 삭제할지 선택하세요.",
            .spanishSpain: "Elige si quieres eliminar solo este evento o este evento y todos los siguientes de la serie.",
            .spanishMexico: "Elige si quieres eliminar solo este evento o este evento y todos los siguientes de la serie.",
            .french: "Choisissez si vous voulez supprimer uniquement cet événement ou cet événement et tous les suivants de la série.",
            .german: "Wähle, ob nur dieses Ereignis oder dieses und alle folgenden Ereignisse der Serie gelöscht werden sollen.",
            .thai: "เลือกว่าจะลบเฉพาะกิจกรรมนี้ หรือจะลบกิจกรรมนี้และกิจกรรมถัดไปทั้งหมดในชุด",
            .vietnamese: "Chọn xóa chỉ sự kiện này hoặc xóa sự kiện này cùng tất cả các sự kiện tiếp theo trong chuỗi.",
            .indonesian: "Pilih apakah hanya acara ini yang dihapus, atau acara ini beserta semua acara berikutnya dalam seri.",
        ],
        "Choose whether the changes apply only to this event or to this event and all following events in the series.": [
            .japanese: "変更をこの予定のみに適用するか、この予定以降のすべての予定に適用するかを選択してください。",
            .korean: "변경 사항을 이 일정에만 적용할지, 이 일정과 이후의 모든 일정에 적용할지 선택하세요.",
            .spanishSpain: "Elige si los cambios se aplican solo a este evento o a este evento y todos los siguientes de la serie.",
            .spanishMexico: "Elige si los cambios se aplican solo a este evento o a este evento y todos los siguientes de la serie.",
            .french: "Choisissez si les modifications s'appliquent uniquement à cet événement ou à cet événement et à tous les suivants de la série.",
            .german: "Wähle, ob die Änderungen nur für dieses Ereignis oder für dieses und alle folgenden Ereignisse der Serie gelten sollen.",
            .thai: "เลือกว่าการเปลี่ยนแปลงนี้จะใช้กับเฉพาะกิจกรรมนี้ หรือกับกิจกรรมนี้และกิจกรรมถัดไปทั้งหมดในชุด",
            .vietnamese: "Chọn áp dụng thay đổi chỉ cho sự kiện này hoặc cho sự kiện này cùng tất cả các sự kiện tiếp theo trong chuỗi.",
            .indonesian: "Pilih apakah perubahan hanya berlaku untuk acara ini, atau untuk acara ini beserta semua acara berikutnya dalam seri.",
        ],
        "Closed tasks keep their original time. You can still update the description, create a new task, or delete them.": [
            .japanese: "終了済みタスクは元の時刻を保持します。説明の更新、新しいタスクの作成、削除は引き続き行えます。",
            .korean: "종료된 작업은 원래 시간을 유지합니다. 설명 수정, 새 작업 생성, 삭제는 계속할 수 있습니다.",
            .spanishSpain: "Las tareas cerradas conservan su horario original. Aun así puedes actualizar la descripción, crear una nueva tarea o eliminarlas.",
            .spanishMexico: "Las tareas cerradas conservan su horario original. Aun así puedes actualizar la descripción, crear una nueva tarea o eliminarlas.",
            .french: "Les tâches closes conservent leur horaire d'origine. Vous pouvez toujours modifier la description, créer une nouvelle tâche ou les supprimer.",
            .german: "Geschlossene Aufgaben behalten ihre ursprüngliche Zeit. Du kannst die Beschreibung weiterhin bearbeiten, eine neue Aufgabe erstellen oder sie löschen.",
            .thai: "งานที่ปิดแล้วจะเก็บเวลาต้นฉบับไว้ คุณยังแก้ไขคำอธิบาย สร้างงานใหม่ หรือลบงานได้",
            .vietnamese: "Các tác vụ đã đóng vẫn giữ thời gian gốc. Bạn vẫn có thể cập nhật mô tả, tạo tác vụ mới hoặc xóa chúng.",
            .indonesian: "Tugas yang sudah ditutup mempertahankan waktu aslinya. Anda tetap dapat memperbarui deskripsi, membuat tugas baru, atau menghapusnya.",
        ],
        "Complete": [
            .japanese: "完了",
            .korean: "완료",
            .spanishSpain: "Completar",
            .spanishMexico: "Completar",
            .french: "Terminer",
            .german: "Abschließen",
            .thai: "เสร็จสิ้น",
            .vietnamese: "Hoàn thành",
            .indonesian: "Selesaikan",
        ],
        "Completed": [
            .japanese: "完了",
            .korean: "완료됨",
            .spanishSpain: "Completado",
            .spanishMexico: "Completado",
            .french: "Terminé",
            .german: "Abgeschlossen",
            .thai: "เสร็จแล้ว",
            .vietnamese: "Đã hoàn thành",
            .indonesian: "Selesai",
        ],
        "Completed At": [
            .japanese: "完了時刻",
            .korean: "완료 시각",
            .spanishSpain: "Completado el",
            .spanishMexico: "Completado el",
            .french: "Terminé le",
            .german: "Abgeschlossen am",
            .thai: "เวลาที่เสร็จสิ้น",
            .vietnamese: "Hoàn thành lúc",
            .indonesian: "Selesai pada",
        ],
        "Create New Task": [
            .japanese: "新しいタスクを作成",
            .korean: "새 작업 만들기",
            .spanishSpain: "Crear nueva tarea",
            .spanishMexico: "Crear nueva tarea",
            .french: "Créer une nouvelle tâche",
            .german: "Neue Aufgabe erstellen",
            .thai: "สร้างงานใหม่",
            .vietnamese: "Tạo tác vụ mới",
            .indonesian: "Buat tugas baru",
        ],
        "Custom": [
            .japanese: "カスタム",
            .korean: "사용자 지정",
            .spanishSpain: "Personalizado",
            .spanishMexico: "Personalizado",
            .french: "Personnalisé",
            .german: "Benutzerdefiniert",
            .thai: "กำหนดเอง",
            .vietnamese: "Tùy chỉnh",
            .indonesian: "Kustom",
        ],
        "Day": [
            .japanese: "日",
            .korean: "일",
            .spanishSpain: "Día",
            .spanishMexico: "Día",
            .french: "Jour",
            .german: "Tag",
            .thai: "วัน",
            .vietnamese: "Ngày",
            .indonesian: "Hari",
        ],
        "Delete": [
            .japanese: "削除",
            .korean: "삭제",
            .spanishSpain: "Eliminar",
            .spanishMexico: "Eliminar",
            .french: "Supprimer",
            .german: "Löschen",
            .thai: "ลบ",
            .vietnamese: "Xóa",
            .indonesian: "Hapus",
        ],
        "Delete Local Data and Resync": [
            .japanese: "ローカルデータを削除して再同期",
            .korean: "로컬 데이터를 삭제하고 다시 동기화",
            .spanishSpain: "Eliminar datos locales y resincronizar",
            .spanishMexico: "Eliminar datos locales y resincronizar",
            .french: "Supprimer les données locales et resynchroniser",
            .german: "Lokale Daten löschen und erneut synchronisieren",
            .thai: "ลบข้อมูลในเครื่องแล้วซิงค์ใหม่",
            .vietnamese: "Xóa dữ liệu cục bộ và đồng bộ lại",
            .indonesian: "Hapus data lokal lalu sinkronkan ulang",
        ],
        "Delete Task": [
            .japanese: "タスクを削除",
            .korean: "작업 삭제",
            .spanishSpain: "Eliminar tarea",
            .spanishMexico: "Eliminar tarea",
            .french: "Supprimer la tâche",
            .german: "Aufgabe löschen",
            .thai: "ลบงาน",
            .vietnamese: "Xóa tác vụ",
            .indonesian: "Hapus tugas",
        ],
        "Delete recurring task": [
            .japanese: "繰り返しタスクを削除",
            .korean: "반복 작업 삭제",
            .spanishSpain: "Eliminar tarea recurrente",
            .spanishMexico: "Eliminar tarea recurrente",
            .french: "Supprimer la tâche récurrente",
            .german: "Wiederkehrende Aufgabe löschen",
            .thai: "ลบงานที่เกิดซ้ำ",
            .vietnamese: "Xóa tác vụ lặp",
            .indonesian: "Hapus tugas berulang",
        ],
        "Delete this task?": [
            .japanese: "このタスクを削除しますか？",
            .korean: "이 작업을 삭제할까요?",
            .spanishSpain: "¿Eliminar esta tarea?",
            .spanishMexico: "¿Eliminar esta tarea?",
            .french: "Supprimer cette tâche ?",
            .german: "Diese Aufgabe löschen?",
            .thai: "ลบงานนี้หรือไม่",
            .vietnamese: "Xóa tác vụ này?",
            .indonesian: "Hapus tugas ini?",
        ],
        "Deleting a subscription also removes the tasks imported from that URL.": [
            .japanese: "サブスクリプションを削除すると、そのURLから取り込んだタスクも削除されます。",
            .korean: "구독을 삭제하면 해당 URL에서 가져온 작업도 함께 삭제됩니다.",
            .spanishSpain: "Al eliminar una suscripción también se eliminan las tareas importadas desde esa URL.",
            .spanishMexico: "Al eliminar una suscripción también se eliminan las tareas importadas desde esa URL.",
            .french: "Supprimer un abonnement supprime aussi les tâches importées depuis cette URL.",
            .german: "Beim Löschen eines Abonnements werden auch die über diese URL importierten Aufgaben entfernt.",
            .thai: "เมื่อลบการสมัครรับข้อมูล งานที่นำเข้าจาก URL นั้นจะถูกลบไปด้วย",
            .vietnamese: "Khi xóa một đăng ký, các tác vụ được nhập từ URL đó cũng sẽ bị xóa.",
            .indonesian: "Menghapus langganan juga akan menghapus tugas yang diimpor dari URL tersebut.",
        ],
        "Description": [
            .japanese: "説明",
            .korean: "설명",
            .spanishSpain: "Descripción",
            .spanishMexico: "Descripción",
            .french: "Description",
            .german: "Beschreibung",
            .thai: "คำอธิบาย",
            .vietnamese: "Mô tả",
            .indonesian: "Deskripsi",
        ],
        "Detected a data conflict": [
            .japanese: "データの競合を検出しました",
            .korean: "데이터 충돌이 감지되었습니다",
            .spanishSpain: "Se detectó un conflicto de datos",
            .spanishMexico: "Se detectó un conflicto de datos",
            .french: "Un conflit de données a été détecté",
            .german: "Ein Datenkonflikt wurde erkannt",
            .thai: "ตรวจพบความขัดแย้งของข้อมูล",
            .vietnamese: "Đã phát hiện xung đột dữ liệu",
            .indonesian: "Konflik data terdeteksi",
        ],
        "Detected an iCloud account change": [
            .japanese: "iCloudアカウントの変更を検出しました",
            .korean: "iCloud 계정 변경이 감지되었습니다",
            .spanishSpain: "Se detectó un cambio en la cuenta de iCloud",
            .spanishMexico: "Se detectó un cambio en la cuenta de iCloud",
            .french: "Un changement de compte iCloud a été détecté",
            .german: "Eine Änderung des iCloud-Kontos wurde erkannt",
            .thai: "ตรวจพบการเปลี่ยนบัญชี iCloud",
            .vietnamese: "Đã phát hiện thay đổi tài khoản iCloud",
            .indonesian: "Perubahan akun iCloud terdeteksi",
        ],
        "Display Options": [
            .japanese: "表示オプション",
            .korean: "표시 옵션",
            .spanishSpain: "Opciones de visualización",
            .spanishMexico: "Opciones de visualización",
            .french: "Options d'affichage",
            .german: "Anzeigeoptionen",
            .thai: "ตัวเลือกการแสดงผล",
            .vietnamese: "Tùy chọn hiển thị",
            .indonesian: "Opsi tampilan",
        ],
        "Done": [
            .japanese: "完了",
            .korean: "완료",
            .spanishSpain: "Hecho",
            .spanishMexico: "Listo",
            .french: "Terminé",
            .german: "Fertig",
            .thai: "เสร็จสิ้น",
            .vietnamese: "Xong",
            .indonesian: "Selesai",
        ],
        "Edit Task": [
            .japanese: "タスクを編集",
            .korean: "작업 편집",
            .spanishSpain: "Editar tarea",
            .spanishMexico: "Editar tarea",
            .french: "Modifier la tâche",
            .german: "Aufgabe bearbeiten",
            .thai: "แก้ไขงาน",
            .vietnamese: "Chỉnh sửa tác vụ",
            .indonesian: "Edit tugas",
        ],
        "Edit recurring task": [
            .japanese: "繰り返しタスクを編集",
            .korean: "반복 작업 편집",
            .spanishSpain: "Editar tarea recurrente",
            .spanishMexico: "Editar tarea recurrente",
            .french: "Modifier la tâche récurrente",
            .german: "Wiederkehrende Aufgabe bearbeiten",
            .thai: "แก้ไขงานที่เกิดซ้ำ",
            .vietnamese: "Chỉnh sửa tác vụ lặp",
            .indonesian: "Edit tugas berulang",
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
        "End Date": [
            .japanese: "終了日",
            .korean: "종료 날짜",
            .spanishSpain: "Fecha de finalización",
            .spanishMexico: "Fecha de finalización",
            .french: "Date de fin",
            .german: "Enddatum",
            .thai: "วันที่สิ้นสุด",
            .vietnamese: "Ngày kết thúc",
            .indonesian: "Tanggal berakhir",
        ],
        "End Repeat": [
            .japanese: "繰り返し終了",
            .korean: "반복 종료",
            .spanishSpain: "Finalizar repetición",
            .spanishMexico: "Finalizar repetición",
            .french: "Fin de répétition",
            .german: "Wiederholung beenden",
            .thai: "สิ้นสุดการทำซ้ำ",
            .vietnamese: "Kết thúc lặp",
            .indonesian: "Akhiri pengulangan",
        ],
        "End Time": [
            .japanese: "終了時刻",
            .korean: "종료 시간",
            .spanishSpain: "Hora de finalización",
            .spanishMexico: "Hora de finalización",
            .french: "Heure de fin",
            .german: "Endzeit",
            .thai: "เวลาสิ้นสุด",
            .vietnamese: "Thời gian kết thúc",
            .indonesian: "Waktu selesai",
        ],
        "Ended": [
            .japanese: "終了",
            .korean: "종료됨",
            .spanishSpain: "Finalizado",
            .spanishMexico: "Finalizado",
            .french: "Expiré",
            .german: "Beendet",
            .thai: "สิ้นสุดแล้ว",
            .vietnamese: "Đã kết thúc",
            .indonesian: "Berakhir",
        ],
        "Every": [
            .japanese: "間隔",
            .korean: "매",
            .spanishSpain: "Cada",
            .spanishMexico: "Cada",
            .french: "Toutes les",
            .german: "Alle",
            .thai: "ทุก",
            .vietnamese: "Mỗi",
            .indonesian: "Setiap",
        ],
        "Every 2 Weeks": [
            .japanese: "2週間ごと",
            .korean: "2주마다",
            .spanishSpain: "Cada 2 semanas",
            .spanishMexico: "Cada 2 semanas",
            .french: "Toutes les 2 semaines",
            .german: "Alle 2 Wochen",
            .thai: "ทุก 2 สัปดาห์",
            .vietnamese: "Mỗi 2 tuần",
            .indonesian: "Setiap 2 minggu",
        ],
        "Every 2 weeks": [
            .japanese: "2週間ごと",
            .korean: "2주마다",
            .spanishSpain: "Cada 2 semanas",
            .spanishMexico: "Cada 2 semanas",
            .french: "Toutes les 2 semaines",
            .german: "Alle 2 Wochen",
            .thai: "ทุก 2 สัปดาห์",
            .vietnamese: "Mỗi 2 tuần",
            .indonesian: "Setiap 2 minggu",
        ],
        "Every Day": [
            .japanese: "毎日",
            .korean: "매일",
            .spanishSpain: "Cada día",
            .spanishMexico: "Cada día",
            .french: "Chaque jour",
            .german: "Jeden Tag",
            .thai: "ทุกวัน",
            .vietnamese: "Mỗi ngày",
            .indonesian: "Setiap hari",
        ],
        "Every Month": [
            .japanese: "毎月",
            .korean: "매월",
            .spanishSpain: "Cada mes",
            .spanishMexico: "Cada mes",
            .french: "Chaque mois",
            .german: "Jeden Monat",
            .thai: "ทุกเดือน",
            .vietnamese: "Mỗi tháng",
            .indonesian: "Setiap bulan",
        ],
        "Every Week": [
            .japanese: "毎週",
            .korean: "매주",
            .spanishSpain: "Cada semana",
            .spanishMexico: "Cada semana",
            .french: "Chaque semaine",
            .german: "Jede Woche",
            .thai: "ทุกสัปดาห์",
            .vietnamese: "Mỗi tuần",
            .indonesian: "Setiap minggu",
        ],
        "Every Year": [
            .japanese: "毎年",
            .korean: "매년",
            .spanishSpain: "Cada año",
            .spanishMexico: "Cada año",
            .french: "Chaque année",
            .german: "Jedes Jahr",
            .thai: "ทุกปี",
            .vietnamese: "Mỗi năm",
            .indonesian: "Setiap tahun",
        ],
        "Every day": [
            .japanese: "毎日",
            .korean: "매일",
            .spanishSpain: "Cada día",
            .spanishMexico: "Cada día",
            .french: "Chaque jour",
            .german: "Jeden Tag",
            .thai: "ทุกวัน",
            .vietnamese: "Mỗi ngày",
            .indonesian: "Setiap hari",
        ],
        "Every month": [
            .japanese: "毎月",
            .korean: "매월",
            .spanishSpain: "Cada mes",
            .spanishMexico: "Cada mes",
            .french: "Chaque mois",
            .german: "Jeden Monat",
            .thai: "ทุกเดือน",
            .vietnamese: "Mỗi tháng",
            .indonesian: "Setiap bulan",
        ],
        "Every week": [
            .japanese: "毎週",
            .korean: "매주",
            .spanishSpain: "Cada semana",
            .spanishMexico: "Cada semana",
            .french: "Chaque semaine",
            .german: "Jede Woche",
            .thai: "ทุกสัปดาห์",
            .vietnamese: "Mỗi tuần",
            .indonesian: "Setiap minggu",
        ],
        "Every year": [
            .japanese: "毎年",
            .korean: "매년",
            .spanishSpain: "Cada año",
            .spanishMexico: "Cada año",
            .french: "Chaque année",
            .german: "Jedes Jahr",
            .thai: "ทุกปี",
            .vietnamese: "Mỗi năm",
            .indonesian: "Setiap tahun",
        ],
        "Filter": [
            .japanese: "フィルタ",
            .korean: "필터",
            .spanishSpain: "Filtro",
            .spanishMexico: "Filtro",
            .french: "Filtre",
            .german: "Filter",
            .thai: "ตัวกรอง",
            .vietnamese: "Bộ lọc",
            .indonesian: "Filter",
        ],
        "Frequency Unit": [
            .japanese: "頻度単位",
            .korean: "반복 단위",
            .spanishSpain: "Unidad de frecuencia",
            .spanishMexico: "Unidad de frecuencia",
            .french: "Unité de fréquence",
            .german: "Frequenzeinheit",
            .thai: "หน่วยความถี่",
            .vietnamese: "Đơn vị tần suất",
            .indonesian: "Satuan frekuensi",
        ],
        "Grid": [
            .japanese: "グリッド",
            .korean: "그리드",
            .spanishSpain: "Cuadrícula",
            .spanishMexico: "Cuadrícula",
            .french: "Grille",
            .german: "Raster",
            .thai: "ตาราง",
            .vietnamese: "Lưới",
            .indonesian: "Grid",
        ],
        "Grid View": [
            .japanese: "グリッド表示",
            .korean: "그리드 보기",
            .spanishSpain: "Vista de cuadrícula",
            .spanishMexico: "Vista de cuadrícula",
            .french: "Vue en grille",
            .german: "Rasteransicht",
            .thai: "มุมมองตาราง",
            .vietnamese: "Chế độ lưới",
            .indonesian: "Tampilan grid",
        ],
        "Group List": [
            .japanese: "グループ一覧",
            .korean: "그룹 목록",
            .spanishSpain: "Lista de grupos",
            .spanishMexico: "Lista de grupos",
            .french: "Liste des groupes",
            .german: "Gruppenliste",
            .thai: "รายการกลุ่ม",
            .vietnamese: "Danh sách nhóm",
            .indonesian: "Daftar grup",
        ],
        "Group Name": [
            .japanese: "グループ名",
            .korean: "그룹 이름",
            .spanishSpain: "Nombre del grupo",
            .spanishMexico: "Nombre del grupo",
            .french: "Nom du groupe",
            .german: "Gruppenname",
            .thai: "ชื่อกลุ่ม",
            .vietnamese: "Tên nhóm",
            .indonesian: "Nama grup",
        ],
        "Groups": [
            .japanese: "グループ",
            .korean: "그룹",
            .spanishSpain: "Grupos",
            .spanishMexico: "Grupos",
            .french: "Groupes",
            .german: "Gruppen",
            .thai: "กลุ่ม",
            .vietnamese: "Nhóm",
            .indonesian: "Grup",
        ],
        "If an event in the feed has no start time, the import time is used as the start time. Future refreshes keep the first seen start time.": [
            .japanese: "フィード内の予定に開始時刻がない場合、取り込み時刻を開始時刻として使用します。今後の更新でも最初に見つかった開始時刻が維持されます。",
            .korean: "피드의 이벤트에 시작 시간이 없으면 가져온 시각을 시작 시각으로 사용합니다. 이후 새로고침에서도 처음 감지된 시작 시각을 유지합니다.",
            .spanishSpain: "Si un evento del feed no tiene hora de inicio, se usará la hora de importación como hora de inicio. Las actualizaciones futuras conservarán la primera hora de inicio detectada.",
            .spanishMexico: "Si un evento del feed no tiene hora de inicio, se usará la hora de importación como hora de inicio. Las actualizaciones futuras conservarán la primera hora de inicio detectada.",
            .french: "Si un événement du flux n'a pas d'heure de début, l'heure d'importation est utilisée comme heure de début. Les prochaines actualisations conservent la première heure de début détectée.",
            .german: "Wenn ein Ereignis im Feed keine Startzeit hat, wird die Importzeit als Startzeit verwendet. Spätere Aktualisierungen behalten die zuerst erkannte Startzeit bei.",
            .thai: "หากเหตุการณ์ในฟีดไม่มีเวลาเริ่ม ระบบจะใช้เวลานำเข้าเป็นเวลาเริ่ม และการรีเฟรชครั้งต่อไปจะคงเวลาเริ่มที่พบครั้งแรกไว้",
            .vietnamese: "Nếu một sự kiện trong nguồn cấp không có thời gian bắt đầu, thời điểm nhập sẽ được dùng làm thời gian bắt đầu. Các lần làm mới sau sẽ giữ lại thời gian bắt đầu được thấy lần đầu.",
            .indonesian: "Jika suatu acara di feed tidak memiliki waktu mulai, waktu impor akan digunakan sebagai waktu mulai. Penyegaran berikutnya akan mempertahankan waktu mulai yang pertama kali ditemukan.",
        ],
        "If an imported event has no start time, the import time is used as the start time.": [
            .japanese: "取り込んだ予定に開始時刻がない場合、取り込み時刻を開始時刻として使用します。",
            .korean: "가져온 이벤트에 시작 시간이 없으면 가져온 시각을 시작 시각으로 사용합니다.",
            .spanishSpain: "Si un evento importado no tiene hora de inicio, se usará la hora de importación como hora de inicio.",
            .spanishMexico: "Si un evento importado no tiene hora de inicio, se usará la hora de importación como hora de inicio.",
            .french: "Si un événement importé n'a pas d'heure de début, l'heure d'importation est utilisée comme heure de début.",
            .german: "Wenn ein importiertes Ereignis keine Startzeit hat, wird die Importzeit als Startzeit verwendet.",
            .thai: "หากเหตุการณ์ที่นำเข้าไม่มีเวลาเริ่ม ระบบจะใช้เวลานำเข้าเป็นเวลาเริ่ม",
            .vietnamese: "Nếu một sự kiện được nhập không có thời gian bắt đầu, thời điểm nhập sẽ được dùng làm thời gian bắt đầu.",
            .indonesian: "Jika acara yang diimpor tidak memiliki waktu mulai, waktu impor akan digunakan sebagai waktu mulai.",
        ],
        "Import Failed": [
            .japanese: "インポートに失敗しました",
            .korean: "가져오기에 실패했습니다",
            .spanishSpain: "La importación falló",
            .spanishMexico: "La importación falló",
            .french: "Échec de l'importation",
            .german: "Import fehlgeschlagen",
            .thai: "นำเข้าไม่สำเร็จ",
            .vietnamese: "Nhập thất bại",
            .indonesian: "Impor gagal",
        ],
        "Import Options": [
            .japanese: "インポートオプション",
            .korean: "가져오기 옵션",
            .spanishSpain: "Opciones de importación",
            .spanishMexico: "Opciones de importación",
            .french: "Options d'importation",
            .german: "Importoptionen",
            .thai: "ตัวเลือกการนำเข้า",
            .vietnamese: "Tùy chọn nhập",
            .indonesian: "Opsi impor",
        ],
        "Import tasks from a standard .ics file.": [
            .japanese: "標準の .ics ファイルからタスクを取り込みます。",
            .korean: "표준 .ics 파일에서 작업을 가져옵니다.",
            .spanishSpain: "Importa tareas desde un archivo .ics estándar.",
            .spanishMexico: "Importa tareas desde un archivo .ics estándar.",
            .french: "Importez des tâches depuis un fichier .ics standard.",
            .german: "Importiere Aufgaben aus einer standardmäßigen .ics-Datei.",
            .thai: "นำเข้างานจากไฟล์ .ics มาตรฐาน",
            .vietnamese: "Nhập tác vụ từ tệp .ics tiêu chuẩn.",
            .indonesian: "Impor tugas dari file .ics standar.",
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
        "Keep Cloud Data": [
            .japanese: "iCloudデータを保持",
            .korean: "iCloud 데이터 유지",
            .spanishSpain: "Mantener datos de iCloud",
            .spanishMexico: "Mantener datos de iCloud",
            .french: "Conserver les données iCloud",
            .german: "iCloud-Daten behalten",
            .thai: "เก็บข้อมูลบน iCloud",
            .vietnamese: "Giữ dữ liệu iCloud",
            .indonesian: "Pertahankan data iCloud",
        ],
        "Keep Local Data": [
            .japanese: "ローカルデータを保持",
            .korean: "로컬 데이터 유지",
            .spanishSpain: "Mantener datos locales",
            .spanishMexico: "Mantener datos locales",
            .french: "Conserver les données locales",
            .german: "Lokale Daten behalten",
            .thai: "เก็บข้อมูลในเครื่อง",
            .vietnamese: "Giữ dữ liệu cục bộ",
            .indonesian: "Pertahankan data lokal",
        ],
        "Language": [
            .japanese: "言語",
            .korean: "언어",
            .spanishSpain: "Idioma",
            .spanishMexico: "Idioma",
            .french: "Langue",
            .german: "Sprache",
            .thai: "ภาษา",
            .vietnamese: "Ngôn ngữ",
            .indonesian: "Bahasa",
        ],
        "Last attempted": [
            .japanese: "前回試行",
            .korean: "마지막 시도",
            .spanishSpain: "Último intento",
            .spanishMexico: "Último intento",
            .french: "Dernière tentative",
            .german: "Letzter Versuch",
            .thai: "พยายามครั้งล่าสุด",
            .vietnamese: "Lần thử gần nhất",
            .indonesian: "Percobaan terakhir",
        ],
        "Last synced": [
            .japanese: "前回同期",
            .korean: "마지막 동기화",
            .spanishSpain: "Última sincronización",
            .spanishMexico: "Última sincronización",
            .french: "Dernière synchronisation",
            .german: "Zuletzt synchronisiert",
            .thai: "ซิงค์ล่าสุด",
            .vietnamese: "Lần đồng bộ gần nhất",
            .indonesian: "Terakhir disinkronkan",
        ],
        "Legal": [
            .japanese: "法的情報",
            .korean: "법률",
            .spanishSpain: "Información legal",
            .spanishMexico: "Información legal",
            .french: "Mentions légales",
            .german: "Rechtliches",
            .thai: "กฎหมาย",
            .vietnamese: "Pháp lý",
            .indonesian: "Hukum",
        ],
        "Liquid Motion": [
            .japanese: "液体モーション",
            .korean: "리퀴드 모션",
            .spanishSpain: "Movimiento líquido",
            .spanishMexico: "Movimiento líquido",
            .french: "Mouvement liquide",
            .german: "Flüssige Bewegung",
            .thai: "เอฟเฟ็กต์ของเหลว",
            .vietnamese: "Chuyển động chất lỏng",
            .indonesian: "Gerakan cair",
        ],
        "Mark as Completed": [
            .japanese: "完了としてマーク",
            .korean: "완료로 표시",
            .spanishSpain: "Marcar como completada",
            .spanishMexico: "Marcar como completada",
            .french: "Marquer comme terminée",
            .german: "Als erledigt markieren",
            .thai: "ทำเครื่องหมายว่าเสร็จแล้ว",
            .vietnamese: "Đánh dấu là hoàn thành",
            .indonesian: "Tandai sebagai selesai",
        ],
        "Mark as Incomplete": [
            .japanese: "未完了に戻す",
            .korean: "미완료로 표시",
            .spanishSpain: "Marcar como incompleta",
            .spanishMexico: "Marcar como incompleta",
            .french: "Marquer comme incomplète",
            .german: "Als unvollständig markieren",
            .thai: "ทำเครื่องหมายว่ายังไม่เสร็จ",
            .vietnamese: "Đánh dấu là chưa hoàn thành",
            .indonesian: "Tandai sebagai belum selesai",
        ],
        "Mark this task as completed?": [
            .japanese: "このタスクを完了としてマークしますか？",
            .korean: "이 작업을 완료로 표시할까요?",
            .spanishSpain: "¿Marcar esta tarea como completada?",
            .spanishMexico: "¿Marcar esta tarea como completada?",
            .french: "Marquer cette tâche comme terminée ?",
            .german: "Diese Aufgabe als erledigt markieren?",
            .thai: "ทำเครื่องหมายงานนี้ว่าเสร็จแล้วหรือไม่",
            .vietnamese: "Đánh dấu tác vụ này là hoàn thành?",
            .indonesian: "Tandai tugas ini sebagai selesai?",
        ],
        "Merge Local Data and Sync": [
            .japanese: "ローカルデータを統合して同期",
            .korean: "로컬 데이터를 병합하고 동기화",
            .spanishSpain: "Combinar datos locales y sincronizar",
            .spanishMexico: "Combinar datos locales y sincronizar",
            .french: "Fusionner les données locales et synchroniser",
            .german: "Lokale Daten zusammenführen und synchronisieren",
            .thai: "รวมข้อมูลในเครื่องแล้วซิงค์",
            .vietnamese: "Gộp dữ liệu cục bộ và đồng bộ",
            .indonesian: "Gabungkan data lokal lalu sinkronkan",
        ],
        "Month": [
            .japanese: "か月",
            .korean: "개월",
            .spanishSpain: "Mes",
            .spanishMexico: "Mes",
            .french: "Mois",
            .german: "Monat",
            .thai: "เดือน",
            .vietnamese: "Tháng",
            .indonesian: "Bulan",
        ],
        "Motion": [
            .japanese: "モーション",
            .korean: "모션",
            .spanishSpain: "Movimiento",
            .spanishMexico: "Movimiento",
            .french: "Mouvement",
            .german: "Bewegung",
            .thai: "การเคลื่อนไหว",
            .vietnamese: "Chuyển động",
            .indonesian: "Gerakan",
        ],
        "Never": [
            .japanese: "しない",
            .korean: "없음",
            .spanishSpain: "Nunca",
            .spanishMexico: "Nunca",
            .french: "Jamais",
            .german: "Nie",
            .thai: "ไม่สิ้นสุด",
            .vietnamese: "Không bao giờ",
            .indonesian: "Tidak pernah",
        ],
        "New Group": [
            .japanese: "新しいグループ",
            .korean: "새 그룹",
            .spanishSpain: "Nuevo grupo",
            .spanishMexico: "Nuevo grupo",
            .french: "Nouveau groupe",
            .german: "Neue Gruppe",
            .thai: "กลุ่มใหม่",
            .vietnamese: "Nhóm mới",
            .indonesian: "Grup baru",
        ],
        "New Task": [
            .japanese: "新しいタスク",
            .korean: "새 작업",
            .spanishSpain: "Nueva tarea",
            .spanishMexico: "Nueva tarea",
            .french: "Nouvelle tâche",
            .german: "Neue Aufgabe",
            .thai: "งานใหม่",
            .vietnamese: "Tác vụ mới",
            .indonesian: "Tugas baru",
        ],
        "No URL subscriptions yet.": [
            .japanese: "URLサブスクリプションはまだありません。",
            .korean: "아직 URL 구독이 없습니다.",
            .spanishSpain: "Todavía no hay suscripciones URL.",
            .spanishMexico: "Todavía no hay suscripciones URL.",
            .french: "Aucun abonnement URL pour l'instant.",
            .german: "Noch keine URL-Abonnements.",
            .thai: "ยังไม่มีการสมัครรับข้อมูล URL",
            .vietnamese: "Chưa có đăng ký URL nào.",
            .indonesian: "Belum ada langganan URL.",
        ],
        "No description": [
            .japanese: "説明はありません",
            .korean: "설명 없음",
            .spanishSpain: "Sin descripción",
            .spanishMexico: "Sin descripción",
            .french: "Aucune description",
            .german: "Keine Beschreibung",
            .thai: "ไม่มีคำอธิบาย",
            .vietnamese: "Không có mô tả",
            .indonesian: "Tidak ada deskripsi",
        ],
        "No importable calendar events were found.": [
            .japanese: "インポートできるカレンダーイベントが見つかりませんでした。",
            .korean: "가져올 수 있는 캘린더 이벤트를 찾을 수 없습니다.",
            .spanishSpain: "No se encontraron eventos de calendario importables.",
            .spanishMexico: "No se encontraron eventos de calendario importables.",
            .french: "Aucun événement de calendrier importable n'a été trouvé.",
            .german: "Es wurden keine importierbaren Kalenderereignisse gefunden.",
            .thai: "ไม่พบกิจกรรมปฏิทินที่นำเข้าได้",
            .vietnamese: "Không tìm thấy sự kiện lịch nào có thể nhập được.",
            .indonesian: "Tidak ditemukan acara kalender yang dapat diimpor.",
        ],
        "No items yet": [
            .japanese: "項目はまだありません",
            .korean: "아직 항목이 없습니다",
            .spanishSpain: "Todavía no hay elementos",
            .spanishMexico: "Todavía no hay elementos",
            .french: "Aucun élément pour l'instant",
            .german: "Noch keine Einträge",
            .thai: "ยังไม่มีรายการ",
            .vietnamese: "Chưa có mục nào",
            .indonesian: "Belum ada item",
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
        "Not synced yet": [
            .japanese: "まだ同期されていません",
            .korean: "아직 동기화되지 않음",
            .spanishSpain: "Aún no sincronizado",
            .spanishMexico: "Aún no sincronizado",
            .french: "Pas encore synchronisé",
            .german: "Noch nicht synchronisiert",
            .thai: "ยังไม่ได้ซิงค์",
            .vietnamese: "Chưa đồng bộ",
            .indonesian: "Belum disinkronkan",
        ],
        "OK": [
            .japanese: "OK",
            .korean: "확인",
            .spanishSpain: "Aceptar",
            .spanishMexico: "Aceptar",
            .french: "OK",
            .german: "OK",
            .thai: "ตกลง",
            .vietnamese: "OK",
            .indonesian: "OK",
        ],
        "Off": [
            .japanese: "オフ",
            .korean: "끔",
            .spanishSpain: "Desactivado",
            .spanishMexico: "Desactivado",
            .french: "Désactivé",
            .german: "Aus",
            .thai: "ปิด",
            .vietnamese: "Tắt",
            .indonesian: "Mati",
        ],
        "On": [
            .japanese: "オン",
            .korean: "켬",
            .spanishSpain: "Activado",
            .spanishMexico: "Activado",
            .french: "Activé",
            .german: "Ein",
            .thai: "เปิด",
            .vietnamese: "Bật",
            .indonesian: "Nyala",
        ],
        "On Date": [
            .japanese: "日付を指定",
            .korean: "날짜 지정",
            .spanishSpain: "En fecha",
            .spanishMexico: "En fecha",
            .french: "À la date",
            .german: "Am Datum",
            .thai: "ตามวันที่",
            .vietnamese: "Vào ngày",
            .indonesian: "Pada tanggal",
        ],
        "Pink-White Gradient": [
            .japanese: "ピンク・ホワイト グラデーション",
            .korean: "핑크-화이트 그라데이션",
            .spanishSpain: "Degradado blanco-rosa",
            .spanishMexico: "Degradado blanco-rosa",
            .french: "Dégradé rose-blanc",
            .german: "Pink-Weiß-Verlauf",
            .thai: "ไล่เฉดชมพู-ขาว",
            .vietnamese: "Chuyển sắc hồng-trắng",
            .indonesian: "Gradasi merah muda-putih",
        ],
        "Please enter a valid URL.": [
            .japanese: "有効なURLを入力してください。",
            .korean: "유효한 URL을 입력하세요.",
            .spanishSpain: "Introduce una URL válida.",
            .spanishMexico: "Ingresa una URL válida.",
            .french: "Veuillez saisir une URL valide.",
            .german: "Bitte gib eine gültige URL ein.",
            .thai: "โปรดป้อน URL ที่ถูกต้อง",
            .vietnamese: "Vui lòng nhập URL hợp lệ.",
            .indonesian: "Masukkan URL yang valid.",
        ],
        "Please keep at least one group.": [
            .japanese: "少なくとも1つのグループを残してください。",
            .korean: "그룹을 최소 1개 이상 유지하세요.",
            .spanishSpain: "Mantén al menos un grupo.",
            .spanishMexico: "Mantén al menos un grupo.",
            .french: "Conservez au moins un groupe.",
            .german: "Bitte behalte mindestens eine Gruppe.",
            .thai: "โปรดเก็บไว้อย่างน้อยหนึ่งกลุ่ม",
            .vietnamese: "Vui lòng giữ lại ít nhất một nhóm.",
            .indonesian: "Harap pertahankan setidaknya satu grup.",
        ],
        "Privacy Policy": [
            .japanese: "プライバシーポリシー",
            .korean: "개인정보 처리방침",
            .spanishSpain: "Política de privacidad",
            .spanishMexico: "Política de privacidad",
            .french: "Politique de confidentialité",
            .german: "Datenschutzerklärung",
            .thai: "นโยบายความเป็นส่วนตัว",
            .vietnamese: "Chính sách quyền riêng tư",
            .indonesian: "Kebijakan Privasi",
        ],
        "Progress Bar": [
            .japanese: "進行バー",
            .korean: "진행 막대",
            .spanishSpain: "Barra de progreso",
            .spanishMexico: "Barra de progreso",
            .french: "Barre de progression",
            .german: "Fortschrittsbalken",
            .thai: "แถบความคืบหน้า",
            .vietnamese: "Thanh tiến độ",
            .indonesian: "Bilah progres",
        ],
        "Progress Bar View": [
            .japanese: "進行バー表示",
            .korean: "진행 막대 보기",
            .spanishSpain: "Vista de barra de progreso",
            .spanishMexico: "Vista de barra de progreso",
            .french: "Vue en barre de progression",
            .german: "Fortschrittsleistenansicht",
            .thai: "มุมมองแถบความคืบหน้า",
            .vietnamese: "Chế độ thanh tiến độ",
            .indonesian: "Tampilan bilah progres",
        ],
        "Pure White": [
            .japanese: "ピュアホワイト",
            .korean: "순백색",
            .spanishSpain: "Blanco puro",
            .spanishMexico: "Blanco puro",
            .french: "Blanc pur",
            .german: "Reinweiß",
            .thai: "สีขาวล้วน",
            .vietnamese: "Trắng tinh",
            .indonesian: "Putih murni",
        ],
        "Refresh All Subscriptions": [
            .japanese: "すべてのサブスクリプションを更新",
            .korean: "모든 구독 새로고침",
            .spanishSpain: "Actualizar todas las suscripciones",
            .spanishMexico: "Actualizar todas las suscripciones",
            .french: "Actualiser tous les abonnements",
            .german: "Alle Abonnements aktualisieren",
            .thai: "รีเฟรชการสมัครรับข้อมูลทั้งหมด",
            .vietnamese: "Làm mới tất cả đăng ký",
            .indonesian: "Segarkan semua langganan",
        ],
        "Refresh Subscriptions": [
            .japanese: "サブスクリプションを更新",
            .korean: "구독 새로고침",
            .spanishSpain: "Actualizar suscripciones",
            .spanishMexico: "Actualizar suscripciones",
            .french: "Actualiser les abonnements",
            .german: "Abonnements aktualisieren",
            .thai: "รีเฟรชการสมัครรับข้อมูล",
            .vietnamese: "Làm mới đăng ký",
            .indonesian: "Segarkan langganan",
        ],
        "Remaining Time Ascending": [
            .japanese: "残り時間 昇順",
            .korean: "남은 시간 오름차순",
            .spanishSpain: "Tiempo restante ascendente",
            .spanishMexico: "Tiempo restante ascendente",
            .french: "Temps restant croissant",
            .german: "Verbleibende Zeit aufsteigend",
            .thai: "เวลาที่เหลือจากน้อยไปมาก",
            .vietnamese: "Thời gian còn lại tăng dần",
            .indonesian: "Sisa waktu menaik",
        ],
        "Remaining Time Descending": [
            .japanese: "残り時間 降順",
            .korean: "남은 시간 내림차순",
            .spanishSpain: "Tiempo restante descendente",
            .spanishMexico: "Tiempo restante descendente",
            .french: "Temps restant décroissant",
            .german: "Verbleibende Zeit absteigend",
            .thai: "เวลาที่เหลือจากมากไปน้อย",
            .vietnamese: "Thời gian còn lại giảm dần",
            .indonesian: "Sisa waktu menurun",
        ],
        "Repeat": [
            .japanese: "繰り返し",
            .korean: "반복",
            .spanishSpain: "Repetir",
            .spanishMexico: "Repetir",
            .french: "Répéter",
            .german: "Wiederholen",
            .thai: "ทำซ้ำ",
            .vietnamese: "Lặp lại",
            .indonesian: "Ulangi",
        ],
        "Repeat Rule": [
            .japanese: "繰り返しルール",
            .korean: "반복 규칙",
            .spanishSpain: "Regla de repetición",
            .spanishMexico: "Regla de repetición",
            .french: "Règle de répétition",
            .german: "Wiederholungsregel",
            .thai: "กฎการทำซ้ำ",
            .vietnamese: "Quy tắc lặp",
            .indonesian: "Aturan pengulangan",
        ],
        "Save": [
            .japanese: "保存",
            .korean: "저장",
            .spanishSpain: "Guardar",
            .spanishMexico: "Guardar",
            .french: "Enregistrer",
            .german: "Speichern",
            .thai: "บันทึก",
            .vietnamese: "Lưu",
            .indonesian: "Simpan",
        ],
        "Select File to Import": [
            .japanese: "インポートするファイルを選択",
            .korean: "가져올 파일 선택",
            .spanishSpain: "Seleccionar archivo para importar",
            .spanishMexico: "Seleccionar archivo para importar",
            .french: "Sélectionner un fichier à importer",
            .german: "Datei zum Importieren auswählen",
            .thai: "เลือกไฟล์เพื่อนำเข้า",
            .vietnamese: "Chọn tệp để nhập",
            .indonesian: "Pilih file untuk diimpor",
        ],
        "Settings": [
            .japanese: "設定",
            .korean: "설정",
            .spanishSpain: "Ajustes",
            .spanishMexico: "Configuración",
            .french: "Réglages",
            .german: "Einstellungen",
            .thai: "การตั้งค่า",
            .vietnamese: "Cài đặt",
            .indonesian: "Pengaturan",
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
        "Start Time": [
            .japanese: "開始時刻",
            .korean: "시작 시간",
            .spanishSpain: "Hora de inicio",
            .spanishMexico: "Hora de inicio",
            .french: "Heure de début",
            .german: "Startzeit",
            .thai: "เวลาเริ่ม",
            .vietnamese: "Thời gian bắt đầu",
            .indonesian: "Waktu mulai",
        ],
        "Subscription": [
            .japanese: "サブスクリプション",
            .korean: "구독",
            .spanishSpain: "Suscripción",
            .spanishMexico: "Suscripción",
            .french: "Abonnement",
            .german: "Abonnement",
            .thai: "การสมัครรับข้อมูล",
            .vietnamese: "Đăng ký",
            .indonesian: "Langganan",
        ],
        "Subscribe": [
            .japanese: "購読",
            .korean: "구독",
            .spanishSpain: "Suscribirse",
            .spanishMexico: "Suscribirse",
            .french: "S'abonner",
            .german: "Abonnieren",
            .thai: "สมัครรับข้อมูล",
            .vietnamese: "Đăng ký",
            .indonesian: "Berlangganan",
        ],
        "Subscribe to an external calendar feed.": [
            .japanese: "外部カレンダーフィードを購読してタスクを取り込みます。",
            .korean: "외부 캘린더 피드를 구독해 작업을 가져옵니다.",
            .spanishSpain: "Suscríbete a un calendario externo.",
            .spanishMexico: "Suscríbete a un calendario externo.",
            .french: "Abonnez-vous à un calendrier externe.",
            .german: "Abonniere einen externen Kalender-Feed.",
            .thai: "สมัครรับฟีดปฏิทินภายนอก",
            .vietnamese: "Đăng ký nguồn cấp lịch bên ngoài.",
            .indonesian: "Berlangganan feed kalender eksternal.",
        ],
        "Subscriptions": [
            .japanese: "サブスクリプション",
            .korean: "구독",
            .spanishSpain: "Suscripciones",
            .spanishMexico: "Suscripciones",
            .french: "Abonnements",
            .german: "Abonnements",
            .thai: "การสมัครรับข้อมูล",
            .vietnamese: "Đăng ký",
            .indonesian: "Langganan",
        ],
        "Sync": [
            .japanese: "同期",
            .korean: "동기화",
            .spanishSpain: "Sincronización",
            .spanishMexico: "Sincronización",
            .french: "Synchronisation",
            .german: "Synchronisierung",
            .thai: "ซิงค์",
            .vietnamese: "Đồng bộ",
            .indonesian: "Sinkronisasi",
        ],
        "Sync Content": [
            .japanese: "同期内容",
            .korean: "동기화할 내용",
            .spanishSpain: "Contenido sincronizado",
            .spanishMexico: "Contenido sincronizado",
            .french: "Contenu synchronisé",
            .german: "Synchronisierter Inhalt",
            .thai: "เนื้อหาที่ซิงค์",
            .vietnamese: "Nội dung đồng bộ",
            .indonesian: "Konten sinkronisasi",
        ],
        "Sync Failed": [
            .japanese: "同期に失敗しました",
            .korean: "동기화에 실패했습니다",
            .spanishSpain: "La sincronización falló",
            .spanishMexico: "La sincronización falló",
            .french: "Échec de la synchronisation",
            .german: "Synchronisierung fehlgeschlagen",
            .thai: "ซิงค์ไม่สำเร็จ",
            .vietnamese: "Đồng bộ thất bại",
            .indonesian: "Sinkronisasi gagal",
        ],
        "Sync Options": [
            .japanese: "同期オプション",
            .korean: "동기화 옵션",
            .spanishSpain: "Opciones de sincronización",
            .spanishMexico: "Opciones de sincronización",
            .french: "Options de synchronisation",
            .german: "Synchronisierungsoptionen",
            .thai: "ตัวเลือกการซิงค์",
            .vietnamese: "Tùy chọn đồng bộ",
            .indonesian: "Opsi sinkronisasi",
        ],
        "Task Info": [
            .japanese: "タスク情報",
            .korean: "작업 정보",
            .spanishSpain: "Información de la tarea",
            .spanishMexico: "Información de la tarea",
            .french: "Informations sur la tâche",
            .german: "Aufgabeninfo",
            .thai: "ข้อมูลงาน",
            .vietnamese: "Thông tin tác vụ",
            .indonesian: "Info tugas",
        ],
        "Tasks": [
            .japanese: "タスク",
            .korean: "작업",
            .spanishSpain: "Tareas",
            .spanishMexico: "Tareas",
            .french: "Tâches",
            .german: "Aufgaben",
            .thai: "งาน",
            .vietnamese: "Tác vụ",
            .indonesian: "Tugas",
        ],
        "Tasks from URL subscriptions are refreshed by the feed. Change the source calendar or manage the subscription in Settings.": [
            .japanese: "URLサブスクリプションから取り込まれたタスクはフィードの更新に従います。元のカレンダーで変更するか、設定でサブスクリプションを管理してください。",
            .korean: "URL 구독으로 가져온 작업은 피드에 따라 새로고침됩니다. 원본 캘린더에서 수정하거나 설정에서 구독을 관리하세요.",
            .spanishSpain: "Las tareas importadas desde suscripciones URL se actualizan con el feed. Cambia el calendario de origen o gestiona la suscripción en Ajustes.",
            .spanishMexico: "Las tareas importadas desde suscripciones URL se actualizan con el feed. Cambia el calendario de origen o administra la suscripción en Configuración.",
            .french: "Les tâches importées via une URL d'abonnement sont actualisées par le flux. Modifiez le calendrier source ou gérez l'abonnement dans Réglages.",
            .german: "Aufgaben aus URL-Abonnements werden über den Feed aktualisiert. Ändere den Quellkalender oder verwalte das Abonnement in den Einstellungen.",
            .thai: "งานที่นำเข้าผ่านการสมัครรับข้อมูล URL จะรีเฟรชตามฟีด โปรดแก้ไขที่ปฏิทินต้นทางหรือจัดการการสมัครรับข้อมูลในหน้าการตั้งค่า",
            .vietnamese: "Các tác vụ được nhập từ đăng ký URL sẽ được cập nhật theo nguồn cấp. Hãy thay đổi lịch nguồn hoặc quản lý đăng ký trong Cài đặt.",
            .indonesian: "Tugas dari langganan URL diperbarui oleh feed. Ubah kalender sumber atau kelola langganan di Pengaturan.",
        ],
        "The URL is invalid.": [
            .japanese: "URLが無効です。",
            .korean: "URL이 올바르지 않습니다.",
            .spanishSpain: "La URL no es válida.",
            .spanishMexico: "La URL no es válida.",
            .french: "L'URL n'est pas valide.",
            .german: "Die URL ist ungültig.",
            .thai: "URL ไม่ถูกต้อง",
            .vietnamese: "URL không hợp lệ.",
            .indonesian: "URL tidak valid.",
        ],
        "The calendar file could not be parsed.": [
            .japanese: "カレンダーファイルを解析できませんでした。",
            .korean: "캘린더 파일을 분석할 수 없습니다.",
            .spanishSpain: "No se pudo analizar el archivo de calendario.",
            .spanishMexico: "No se pudo analizar el archivo de calendario.",
            .french: "Le fichier de calendrier n'a pas pu être analysé.",
            .german: "Die Kalenderdatei konnte nicht verarbeitet werden.",
            .thai: "ไม่สามารถแยกวิเคราะห์ไฟล์ปฏิทินได้",
            .vietnamese: "Không thể phân tích tệp lịch.",
            .indonesian: "File kalender tidak dapat diparsing.",
        ],
        "The selected file could not be read.": [
            .japanese: "選択したファイルを読み込めませんでした。",
            .korean: "선택한 파일을 읽을 수 없습니다.",
            .spanishSpain: "No se pudo leer el archivo seleccionado.",
            .spanishMexico: "No se pudo leer el archivo seleccionado.",
            .french: "Le fichier sélectionné n'a pas pu être lu.",
            .german: "Die ausgewählte Datei konnte nicht gelesen werden.",
            .thai: "ไม่สามารถอ่านไฟล์ที่เลือกได้",
            .vietnamese: "Không thể đọc tệp đã chọn.",
            .indonesian: "File yang dipilih tidak dapat dibaca.",
        ],
        "Time": [
            .japanese: "時間",
            .korean: "시간",
            .spanishSpain: "Horario",
            .spanishMexico: "Horario",
            .french: "Horaire",
            .german: "Zeit",
            .thai: "เวลา",
            .vietnamese: "Thời gian",
            .indonesian: "Waktu",
        ],
        "Title": [
            .japanese: "タイトル",
            .korean: "제목",
            .spanishSpain: "Título",
            .spanishMexico: "Título",
            .french: "Titre",
            .german: "Titel",
            .thai: "ชื่อเรื่อง",
            .vietnamese: "Tiêu đề",
            .indonesian: "Judul",
        ],
        "Title cannot be empty, and end time must be later than start time.": [
            .japanese: "タイトルを空にせず、終了時刻を開始時刻より後にしてください。",
            .korean: "제목은 비워 둘 수 없으며 종료 시간은 시작 시간보다 늦어야 합니다.",
            .spanishSpain: "El título no puede estar vacío y la hora de finalización debe ser posterior a la de inicio.",
            .spanishMexico: "El título no puede estar vacío y la hora de finalización debe ser posterior a la de inicio.",
            .french: "Le titre ne peut pas être vide et l'heure de fin doit être postérieure à l'heure de début.",
            .german: "Der Titel darf nicht leer sein und die Endzeit muss nach der Startzeit liegen.",
            .thai: "ชื่อเรื่องต้องไม่ว่าง และเวลาสิ้นสุดต้องช้ากว่าเวลาเริ่ม",
            .vietnamese: "Tiêu đề không được để trống và thời gian kết thúc phải muộn hơn thời gian bắt đầu.",
            .indonesian: "Judul tidak boleh kosong, dan waktu selesai harus lebih lambat dari waktu mulai.",
        ],
        "Turn Off Automatic Sync": [
            .japanese: "自動同期をオフにする",
            .korean: "자동 동기화 끄기",
            .spanishSpain: "Desactivar sincronización automática",
            .spanishMexico: "Desactivar sincronización automática",
            .french: "Désactiver la synchronisation automatique",
            .german: "Automatische Synchronisierung deaktivieren",
            .thai: "ปิดการซิงค์อัตโนมัติ",
            .vietnamese: "Tắt đồng bộ tự động",
            .indonesian: "Matikan sinkronisasi otomatis",
        ],
        "Turn this on to sync data through iCloud on your Apple devices signed in to the same account.": [
            .japanese: "オンにすると、同じアカウントでサインインしているAppleデバイス間でiCloudを通じてデータを同期します。",
            .korean: "이 옵션을 켜면 같은 계정으로 로그인한 Apple 기기 사이에서 iCloud를 통해 데이터가 동기화됩니다.",
            .spanishSpain: "Activa esta opción para sincronizar datos mediante iCloud entre tus dispositivos Apple conectados con la misma cuenta.",
            .spanishMexico: "Activa esta opción para sincronizar datos mediante iCloud entre tus dispositivos Apple conectados con la misma cuenta.",
            .french: "Activez cette option pour synchroniser les données via iCloud entre vos appareils Apple connectés au même compte.",
            .german: "Aktiviere dies, um Daten über iCloud auf deinen Apple-Geräten zu synchronisieren, die mit demselben Account angemeldet sind.",
            .thai: "เปิดตัวเลือกนี้เพื่อซิงค์ข้อมูลผ่าน iCloud ระหว่างอุปกรณ์ Apple ที่ลงชื่อเข้าใช้ด้วยบัญชีเดียวกัน",
            .vietnamese: "Bật mục này để đồng bộ dữ liệu qua iCloud giữa các thiết bị Apple đăng nhập cùng một tài khoản.",
            .indonesian: "Aktifkan ini untuk menyinkronkan data melalui iCloud di perangkat Apple Anda yang masuk dengan akun yang sama.",
        ],
        "Turning off group sync also turns off task and subscription sync.": [
            .japanese: "グループ同期をオフにすると、タスク同期とサブスクリプション同期もオフになります。",
            .korean: "그룹 동기화를 끄면 작업 동기화와 구독 동기화도 함께 꺼집니다.",
            .spanishSpain: "Si desactivas la sincronización de grupos, también se desactivan la sincronización de tareas y de suscripciones.",
            .spanishMexico: "Si desactivas la sincronización de grupos, también se desactivan la sincronización de tareas y de suscripciones.",
            .french: "Désactiver la synchronisation des groupes désactive aussi celle des tâches et des abonnements.",
            .german: "Wenn die Gruppensynchronisierung deaktiviert wird, werden auch Aufgaben- und Abonnement-Synchronisierung deaktiviert.",
            .thai: "เมื่อปิดการซิงค์กลุ่ม การซิงค์งานและการสมัครรับข้อมูลจะถูกปิดด้วย",
            .vietnamese: "Tắt đồng bộ nhóm cũng sẽ tắt đồng bộ tác vụ và đăng ký.",
            .indonesian: "Mematikan sinkronisasi grup juga akan mematikan sinkronisasi tugas dan langganan.",
        ],
        "Untitled": [
            .japanese: "無題",
            .korean: "제목 없음",
            .spanishSpain: "Sin título",
            .spanishMexico: "Sin título",
            .french: "Sans titre",
            .german: "Ohne Titel",
            .thai: "ไม่มีชื่อ",
            .vietnamese: "Không tiêu đề",
            .indonesian: "Tanpa judul",
        ],
        "Use URL Subscription": [
            .japanese: "URLサブスクリプションを使う",
            .korean: "URL 구독 사용",
            .spanishSpain: "Usar suscripción URL",
            .spanishMexico: "Usar suscripción URL",
            .french: "Utiliser un abonnement URL",
            .german: "URL-Abonnement verwenden",
            .thai: "ใช้การสมัครรับข้อมูล URL",
            .vietnamese: "Dùng đăng ký URL",
            .indonesian: "Gunakan langganan URL",
        ],
        "Week": [
            .japanese: "週",
            .korean: "주",
            .spanishSpain: "Semana",
            .spanishMexico: "Semana",
            .french: "Semaine",
            .german: "Woche",
            .thai: "สัปดาห์",
            .vietnamese: "Tuần",
            .indonesian: "Minggu",
        ],
        "When off, liquid in the grid view no longer responds to device movement.": [
            .japanese: "オフにすると、グリッド表示の液体はデバイスの動きに反応しなくなります。",
            .korean: "끄면 그리드 보기의 액체가 더 이상 기기 움직임에 반응하지 않습니다.",
            .spanishSpain: "Cuando está desactivado, el líquido en la vista de cuadrícula deja de responder al movimiento del dispositivo.",
            .spanishMexico: "Cuando está desactivado, el líquido en la vista de cuadrícula deja de responder al movimiento del dispositivo.",
            .french: "Lorsqu'il est désactivé, le liquide dans la vue en grille ne réagit plus aux mouvements de l'appareil.",
            .german: "Wenn dies deaktiviert ist, reagiert die Flüssigkeit in der Rasteransicht nicht mehr auf Gerätebewegungen.",
            .thai: "เมื่อปิด เอฟเฟ็กต์ของเหลวในมุมมองตารางจะไม่ตอบสนองต่อการเคลื่อนไหวของอุปกรณ์อีกต่อไป",
            .vietnamese: "Khi tắt, chất lỏng trong chế độ lưới sẽ không còn phản ứng với chuyển động của thiết bị.",
            .indonesian: "Saat dimatikan, cairan pada tampilan grid tidak lagi merespons gerakan perangkat.",
        ],
        "Year": [
            .japanese: "年",
            .korean: "년",
            .spanishSpain: "Año",
            .spanishMexico: "Año",
            .french: "An",
            .german: "Jahr",
            .thai: "ปี",
            .vietnamese: "Năm",
            .indonesian: "Tahun",
        ],
    ]

    static func localized(_ english: String, for language: AppLanguage) -> String? {
        if language == .russian {
            return AppRussianTranslations.table[english]
        }
        return table[english]?[language]
    }
}

extension AppLanguage {
    static func currentForLocalization(defaults: UserDefaults = DeadlineStorage.sharedDefaults) -> AppLanguage {
        if let storedRaw = defaults.string(forKey: DeadlineStorage.languageSelectionKey),
           let storedLanguage = AppLanguage(rawValue: storedRaw) {
            return storedLanguage
        }
        return detectFromSystem()
    }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .chinese:
            return "简体中文"
        case .japanese:
            return "日本語"
        case .korean:
            return "한국어"
        case .spanishSpain:
            return "Español (España)"
        case .spanishMexico:
            return "Español (México)"
        case .french:
            return "Français"
        case .german:
            return "Deutsch"
        case .thai:
            return "ไทย"
        case .vietnamese:
            return "Tiếng Việt"
        case .indonesian:
            return "Bahasa Indonesia"
        case .russian:
            return "Русский"
        }
    }

    func localizedText(_ english: String, chinese: String) -> String {
        switch self {
        case .english:
            return english
        case .chinese:
            return chinese
        default:
            return AppTranslations.localized(english, for: self) ?? english
        }
    }

    func relativeTimeText(_ phrase: RelativeTimePhrase, duration: String) -> String {
        switch self {
        case .english:
            return phrase == .startsIn ? "Starts in \(duration)" : "Remaining \(duration)"
        case .chinese:
            return phrase == .startsIn ? "距开始 \(duration)" : "剩余 \(duration)"
        case .japanese:
            return phrase == .startsIn ? "開始まで \(duration)" : "残り \(duration)"
        case .korean:
            return phrase == .startsIn ? "시작까지 \(duration)" : "남은 시간 \(duration)"
        case .spanishSpain, .spanishMexico:
            return phrase == .startsIn ? "Empieza en \(duration)" : "Quedan \(duration)"
        case .french:
            return phrase == .startsIn ? "Débute dans \(duration)" : "Reste \(duration)"
        case .german:
            return phrase == .startsIn ? "Beginnt in \(duration)" : "Verbleibend \(duration)"
        case .thai:
            return phrase == .startsIn ? "เริ่มในอีก \(duration)" : "เหลืออีก \(duration)"
        case .vietnamese:
            return phrase == .startsIn ? "Bắt đầu sau \(duration)" : "Còn lại \(duration)"
        case .indonesian:
            return phrase == .startsIn ? "Mulai dalam \(duration)" : "Sisa \(duration)"
        case .russian:
            return phrase == .startsIn ? "Начнётся через \(duration)" : "Осталось \(duration)"
        }
    }

    func editGroupActionTitle(_ group: String) -> String {
        switch self {
        case .english:
            return "Edit \(group)"
        case .chinese:
            return "编辑 \(group)"
        case .japanese:
            return "\(group)を編集"
        case .korean:
            return "\(group) 편집"
        case .spanishSpain, .spanishMexico:
            return "Editar \(group)"
        case .french:
            return "Modifier \(group)"
        case .german:
            return "\(group) bearbeiten"
        case .thai:
            return "แก้ไข \(group)"
        case .vietnamese:
            return "Chỉnh sửa \(group)"
        case .indonesian:
            return "Edit \(group)"
        case .russian:
            return "Изменить \(group)"
        }
    }

    func deleteGroupActionTitle(_ group: String) -> String {
        switch self {
        case .english:
            return "Delete \(group)"
        case .chinese:
            return "删除 \(group)"
        case .japanese:
            return "\(group)を削除"
        case .korean:
            return "\(group) 삭제"
        case .spanishSpain, .spanishMexico:
            return "Eliminar \(group)"
        case .french:
            return "Supprimer \(group)"
        case .german:
            return "\(group) löschen"
        case .thai:
            return "ลบ \(group)"
        case .vietnamese:
            return "Xóa \(group)"
        case .indonesian:
            return "Hapus \(group)"
        case .russian:
            return "Удалить \(group)"
        }
    }

    func editGroupAlertTitle(_ group: String) -> String {
        switch self {
        case .english:
            return "Edit Group: \(group)"
        case .chinese:
            return "编辑分组：\(group)"
        case .japanese:
            return "グループを編集: \(group)"
        case .korean:
            return "그룹 편집: \(group)"
        case .spanishSpain, .spanishMexico:
            return "Editar grupo: \(group)"
        case .french:
            return "Modifier le groupe : \(group)"
        case .german:
            return "Gruppe bearbeiten: \(group)"
        case .thai:
            return "แก้ไขกลุ่ม: \(group)"
        case .vietnamese:
            return "Chỉnh sửa nhóm: \(group)"
        case .indonesian:
            return "Edit grup: \(group)"
        case .russian:
            return "Редактировать группу: \(group)"
        }
    }

    var recurringDeleteThisEventTitle: String {
        switch self {
        case .english:
            return "Only This Event"
        case .chinese:
            return "仅删除本次日程"
        case .japanese:
            return "この予定のみ削除"
        case .korean:
            return "이 일정만 삭제"
        case .spanishSpain, .spanishMexico:
            return "Solo este evento"
        case .french:
            return "Cet événement uniquement"
        case .german:
            return "Nur dieses Ereignis"
        case .thai:
            return "ลบเฉพาะกิจกรรมนี้"
        case .vietnamese:
            return "Chỉ xóa sự kiện này"
        case .indonesian:
            return "Hanya acara ini"
        case .russian:
            return "Только это событие"
        }
    }

    var recurringDeleteFutureEventsTitle: String {
        switch self {
        case .english:
            return "This and Future Events"
        case .chinese:
            return "删除将来所有日程"
        case .japanese:
            return "この予定以降を削除"
        case .korean:
            return "이 일정과 이후 일정 삭제"
        case .spanishSpain, .spanishMexico:
            return "Este y los siguientes eventos"
        case .french:
            return "Cet événement et les suivants"
        case .german:
            return "Dieses und zukünftige Ereignisse"
        case .thai:
            return "ลบกิจกรรมนี้และกิจกรรมถัดไป"
        case .vietnamese:
            return "Xóa sự kiện này và các sự kiện sau"
        case .indonesian:
            return "Acara ini dan berikutnya"
        case .russian:
            return "Это и будущие события"
        }
    }

    var recurringEditThisEventTitle: String {
        switch self {
        case .english:
            return "Only This Event"
        case .chinese:
            return "仅修改本次日程"
        case .japanese:
            return "この予定のみ変更"
        case .korean:
            return "이 일정만 수정"
        case .spanishSpain, .spanishMexico:
            return "Solo este evento"
        case .french:
            return "Cet événement uniquement"
        case .german:
            return "Nur dieses Ereignis"
        case .thai:
            return "แก้ไขเฉพาะกิจกรรมนี้"
        case .vietnamese:
            return "Chỉ sửa sự kiện này"
        case .indonesian:
            return "Hanya acara ini"
        case .russian:
            return "Только это событие"
        }
    }

    var recurringEditFutureEventsTitle: String {
        switch self {
        case .english:
            return "This and Future Events"
        case .chinese:
            return "修改将来所有日程"
        case .japanese:
            return "この予定以降を変更"
        case .korean:
            return "이 일정과 이후 일정 수정"
        case .spanishSpain, .spanishMexico:
            return "Este y los siguientes eventos"
        case .french:
            return "Cet événement et les suivants"
        case .german:
            return "Dieses und zukünftige Ereignisse"
        case .thai:
            return "แก้ไขกิจกรรมนี้และกิจกรรมถัดไป"
        case .vietnamese:
            return "Sửa sự kiện này và các sự kiện sau"
        case .indonesian:
            return "Acara ini dan berikutnya"
        case .russian:
            return "Это и будущие события"
        }
    }

    func conflictDescription(changedFields: String) -> String {
        switch self {
        case .english:
            return "The field(s) \(changedFields) were changed on another device while you were editing. Choose whether to keep your local changes or use the latest iCloud values."
        case .chinese:
            return "你编辑期间，字段 \(changedFields) 已在其他设备上被修改。请选择保留本地修改，或使用最新的云端数据。"
        case .japanese:
            return "編集中にフィールド \(changedFields) が別のデバイスで変更されました。ローカルの変更を保持するか、最新のiCloudデータを使うかを選択してください。"
        case .korean:
            return "편집하는 동안 \(changedFields) 필드가 다른 기기에서 변경되었습니다. 로컬 변경 사항을 유지할지, 최신 iCloud 데이터를 사용할지 선택하세요."
        case .spanishSpain, .spanishMexico:
            return "Mientras editabas, el campo \(changedFields) se modificó en otro dispositivo. Elige si quieres conservar tus cambios locales o usar los valores más recientes de iCloud."
        case .french:
            return "Pendant votre modification, le champ \(changedFields) a été modifié sur un autre appareil. Choisissez entre conserver vos modifications locales ou utiliser les dernières valeurs iCloud."
        case .german:
            return "Während deiner Bearbeitung wurde das Feld \(changedFields) auf einem anderen Gerät geändert. Wähle, ob du deine lokalen Änderungen behalten oder die neuesten iCloud-Werte verwenden möchtest."
        case .thai:
            return "ระหว่างที่คุณแก้ไข ฟิลด์ \(changedFields) ถูกแก้ไขบนอุปกรณ์เครื่องอื่น เลือกว่าจะเก็บการแก้ไขในเครื่องไว้หรือใช้ข้อมูล iCloud ล่าสุด"
        case .vietnamese:
            return "Trong khi bạn chỉnh sửa, trường \(changedFields) đã bị thay đổi trên thiết bị khác. Hãy chọn giữ thay đổi cục bộ hoặc dùng dữ liệu iCloud mới nhất."
        case .indonesian:
            return "Saat Anda mengedit, kolom \(changedFields) telah diubah di perangkat lain. Pilih apakah akan mempertahankan perubahan lokal atau menggunakan nilai iCloud terbaru."
        case .russian:
            return "Во время редактирования на другом устройстве были изменены поля: \(changedFields). Выберите, сохранить локальные изменения или использовать последние значения iCloud."
        }
    }

    private func russianRepeatUnit(for unit: DeadlineRepeatUnit, interval: Int) -> String {
        let singular: String
        let few: String
        let many: String

        switch unit {
        case .day:
            singular = "день"
            few = "дня"
            many = "дней"
        case .week:
            singular = "неделя"
            few = "недели"
            many = "недель"
        case .month:
            singular = "месяц"
            few = "месяца"
            many = "месяцев"
        case .year:
            singular = "год"
            few = "года"
            many = "лет"
        }

        let mod10 = interval % 10
        let mod100 = interval % 100
        if mod10 == 1 && mod100 != 11 {
            return singular
        }
        if (2...4).contains(mod10) && (12...14).contains(mod100) == false {
            return few
        }
        return many
    }

    nonisolated private func russianReminderUnit(for unit: DeadlineReminderUnit, value: Int) -> String {
        let singular: String
        let few: String
        let many: String

        switch unit {
        case .minute:
            singular = "минута"
            few = "минуты"
            many = "минут"
        case .hour:
            singular = "час"
            few = "часа"
            many = "часов"
        case .day:
            singular = "день"
            few = "дня"
            many = "дней"
        }

        let mod10 = value % 10
        let mod100 = value % 100
        if mod10 == 1 && mod100 != 11 {
            return singular
        }
        if (2...4).contains(mod10) && (12...14).contains(mod100) == false {
            return few
        }
        return many
    }

    func repeatUnitTitle(_ unit: DeadlineRepeatUnit, pluralized: Bool) -> String {
        switch self {
        case .english:
            switch unit {
            case .day: return pluralized ? "days" : "day"
            case .week: return pluralized ? "weeks" : "week"
            case .month: return pluralized ? "months" : "month"
            case .year: return pluralized ? "years" : "year"
            }
        case .chinese:
            switch unit {
            case .day: return "天"
            case .week: return "周"
            case .month: return "月"
            case .year: return "年"
            }
        case .japanese:
            switch unit {
            case .day: return "日"
            case .week: return "週間"
            case .month: return "か月"
            case .year: return "年"
            }
        case .korean:
            switch unit {
            case .day: return "일"
            case .week: return "주"
            case .month: return "개월"
            case .year: return "년"
            }
        case .spanishSpain, .spanishMexico:
            switch unit {
            case .day: return pluralized ? "días" : "día"
            case .week: return pluralized ? "semanas" : "semana"
            case .month: return pluralized ? "meses" : "mes"
            case .year: return pluralized ? "años" : "año"
            }
        case .french:
            switch unit {
            case .day: return pluralized ? "jours" : "jour"
            case .week: return pluralized ? "semaines" : "semaine"
            case .month: return "mois"
            case .year: return pluralized ? "ans" : "an"
            }
        case .german:
            switch unit {
            case .day: return pluralized ? "Tage" : "Tag"
            case .week: return pluralized ? "Wochen" : "Woche"
            case .month: return pluralized ? "Monate" : "Monat"
            case .year: return pluralized ? "Jahre" : "Jahr"
            }
        case .thai:
            switch unit {
            case .day: return "วัน"
            case .week: return "สัปดาห์"
            case .month: return "เดือน"
            case .year: return "ปี"
            }
        case .vietnamese:
            switch unit {
            case .day: return "ngày"
            case .week: return "tuần"
            case .month: return "tháng"
            case .year: return "năm"
            }
        case .indonesian:
            switch unit {
            case .day: return "hari"
            case .week: return "minggu"
            case .month: return "bulan"
            case .year: return "tahun"
            }
        case .russian:
            switch unit {
            case .day: return pluralized ? "дней" : "день"
            case .week: return pluralized ? "недель" : "неделя"
            case .month: return pluralized ? "месяцев" : "месяц"
            case .year: return pluralized ? "лет" : "год"
            }
        }
    }

    func repeatIntervalSummary(interval: Int, unit: DeadlineRepeatUnit) -> String {
        switch self {
        case .english:
            return "\(interval) \(repeatUnitTitle(unit, pluralized: interval > 1))"
        case .chinese:
            return "\(interval)\(repeatUnitTitle(unit, pluralized: interval > 1))"
        case .japanese:
            return "\(interval)\(repeatUnitTitle(unit, pluralized: interval > 1))"
        case .korean:
            return "\(interval)\(repeatUnitTitle(unit, pluralized: interval > 1))"
        case .spanishSpain, .spanishMexico:
            return "\(interval) \(repeatUnitTitle(unit, pluralized: interval > 1))"
        case .french:
            return "\(interval) \(repeatUnitTitle(unit, pluralized: interval > 1))"
        case .german:
            return "\(interval) \(repeatUnitTitle(unit, pluralized: interval > 1))"
        case .thai:
            return "\(interval) \(repeatUnitTitle(unit, pluralized: interval > 1))"
        case .vietnamese:
            return "\(interval) \(repeatUnitTitle(unit, pluralized: interval > 1))"
        case .indonesian:
            return "\(interval) \(repeatUnitTitle(unit, pluralized: interval > 1))"
        case .russian:
            return "\(interval) \(russianRepeatUnit(for: unit, interval: interval))"
        }
    }

    func repeatRuleSummary(interval: Int, unit: DeadlineRepeatUnit) -> String {
        if interval == 1 {
            switch self {
            case .english:
                switch unit {
                case .day: return "Every day"
                case .week: return "Every week"
                case .month: return "Every month"
                case .year: return "Every year"
                }
            case .chinese:
                switch unit {
                case .day: return "每天"
                case .week: return "每周"
                case .month: return "每月"
                case .year: return "每年"
                }
            case .japanese:
                switch unit {
                case .day: return "毎日"
                case .week: return "毎週"
                case .month: return "毎月"
                case .year: return "毎年"
                }
            case .korean:
                switch unit {
                case .day: return "매일"
                case .week: return "매주"
                case .month: return "매월"
                case .year: return "매년"
                }
            case .spanishSpain, .spanishMexico:
                switch unit {
                case .day: return "Cada día"
                case .week: return "Cada semana"
                case .month: return "Cada mes"
                case .year: return "Cada año"
                }
            case .french:
                switch unit {
                case .day: return "Chaque jour"
                case .week: return "Chaque semaine"
                case .month: return "Chaque mois"
                case .year: return "Chaque année"
                }
            case .german:
                switch unit {
                case .day: return "Jeden Tag"
                case .week: return "Jede Woche"
                case .month: return "Jeden Monat"
                case .year: return "Jedes Jahr"
                }
            case .thai:
                switch unit {
                case .day: return "ทุกวัน"
                case .week: return "ทุกสัปดาห์"
                case .month: return "ทุกเดือน"
                case .year: return "ทุกปี"
                }
            case .vietnamese:
                switch unit {
                case .day: return "Mỗi ngày"
                case .week: return "Mỗi tuần"
                case .month: return "Mỗi tháng"
                case .year: return "Mỗi năm"
                }
            case .indonesian:
                switch unit {
                case .day: return "Setiap hari"
                case .week: return "Setiap minggu"
                case .month: return "Setiap bulan"
                case .year: return "Setiap tahun"
                }
            case .russian:
                switch unit {
                case .day: return "Каждый день"
                case .week: return "Каждую неделю"
                case .month: return "Каждый месяц"
                case .year: return "Каждый год"
                }
            }
        }

        if interval == 2, unit == .week {
            return localizedText("Every 2 weeks", chinese: "每两周")
        }

        switch self {
        case .english:
            return "Every \(interval) \(repeatUnitTitle(unit, pluralized: true))"
        case .chinese:
            return "每 \(interval) \(repeatUnitTitle(unit, pluralized: true))"
        case .japanese:
            return "\(interval)\(repeatUnitTitle(unit, pluralized: true))ごと"
        case .korean:
            return "\(interval)\(repeatUnitTitle(unit, pluralized: true))마다"
        case .spanishSpain, .spanishMexico:
            return "Cada \(interval) \(repeatUnitTitle(unit, pluralized: true))"
        case .french:
            return "Tous les \(interval) \(repeatUnitTitle(unit, pluralized: true))"
        case .german:
            return "Alle \(interval) \(repeatUnitTitle(unit, pluralized: true))"
        case .thai:
            return "ทุก \(interval) \(repeatUnitTitle(unit, pluralized: true))"
        case .vietnamese:
            return "Mỗi \(interval) \(repeatUnitTitle(unit, pluralized: true))"
        case .indonesian:
            return "Setiap \(interval) \(repeatUnitTitle(unit, pluralized: true))"
        case .russian:
            return "Раз в \(interval) \(russianRepeatUnit(for: unit, interval: interval))"
        }
    }

    nonisolated var reminderTitle: String {
        switch self {
        case .english: return "Reminder"
        case .chinese: return "提醒"
        case .japanese: return "通知"
        case .korean: return "알림"
        case .spanishSpain, .spanishMexico: return "Recordatorio"
        case .french: return "Rappel"
        case .german: return "Erinnerung"
        case .thai: return "การแจ้งเตือน"
        case .vietnamese: return "Nhắc nhở"
        case .indonesian: return "Pengingat"
        case .russian: return "Напоминание"
        }
    }

    nonisolated var addReminderTitle: String {
        switch self {
        case .english: return "Add Reminder"
        case .chinese: return "新建提醒事项"
        case .japanese: return "通知を追加"
        case .korean: return "알림 추가"
        case .spanishSpain, .spanishMexico: return "Agregar recordatorio"
        case .french: return "Ajouter un rappel"
        case .german: return "Erinnerung hinzufügen"
        case .thai: return "เพิ่มการแจ้งเตือน"
        case .vietnamese: return "Thêm nhắc nhở"
        case .indonesian: return "Tambah pengingat"
        case .russian: return "Добавить напоминание"
        }
    }

    nonisolated var deleteReminderTitle: String {
        switch self {
        case .english: return "Delete Reminder"
        case .chinese: return "删除提醒"
        case .japanese: return "通知を削除"
        case .korean: return "알림 삭제"
        case .spanishSpain, .spanishMexico: return "Eliminar recordatorio"
        case .french: return "Supprimer le rappel"
        case .german: return "Erinnerung löschen"
        case .thai: return "ลบการแจ้งเตือน"
        case .vietnamese: return "Xóa nhắc nhở"
        case .indonesian: return "Hapus pengingat"
        case .russian: return "Удалить напоминание"
        }
    }

    nonisolated var noReminderTitle: String {
        switch self {
        case .english: return "No Reminder"
        case .chinese: return "不提醒"
        case .japanese: return "通知なし"
        case .korean: return "알림 없음"
        case .spanishSpain, .spanishMexico: return "Sin recordatorio"
        case .french: return "Aucun rappel"
        case .german: return "Keine Erinnerung"
        case .thai: return "ไม่มีการแจ้งเตือน"
        case .vietnamese: return "Không nhắc nhở"
        case .indonesian: return "Tanpa pengingat"
        case .russian: return "Без напоминания"
        }
    }

    nonisolated func reminderRelationTitle(_ relation: DeadlineReminderRelation) -> String {
        switch self {
        case .english:
            switch relation {
            case .beforeStart: return "Before Start"
            case .afterStart: return "After Start"
            case .beforeEnd: return "Before End"
            }
        case .chinese:
            switch relation {
            case .beforeStart: return "开始前"
            case .afterStart: return "开始后"
            case .beforeEnd: return "结束前"
            }
        case .japanese:
            switch relation {
            case .beforeStart: return "開始前"
            case .afterStart: return "開始後"
            case .beforeEnd: return "終了前"
            }
        case .korean:
            switch relation {
            case .beforeStart: return "시작 전"
            case .afterStart: return "시작 후"
            case .beforeEnd: return "종료 전"
            }
        case .spanishSpain, .spanishMexico:
            switch relation {
            case .beforeStart: return "Antes de empezar"
            case .afterStart: return "Después de empezar"
            case .beforeEnd: return "Antes de terminar"
            }
        case .french:
            switch relation {
            case .beforeStart: return "Avant le début"
            case .afterStart: return "Après le début"
            case .beforeEnd: return "Avant la fin"
            }
        case .german:
            switch relation {
            case .beforeStart: return "Vor Beginn"
            case .afterStart: return "Nach Beginn"
            case .beforeEnd: return "Vor Ende"
            }
        case .thai:
            switch relation {
            case .beforeStart: return "ก่อนเริ่ม"
            case .afterStart: return "หลังเริ่ม"
            case .beforeEnd: return "ก่อนสิ้นสุด"
            }
        case .vietnamese:
            switch relation {
            case .beforeStart: return "Trước khi bắt đầu"
            case .afterStart: return "Sau khi bắt đầu"
            case .beforeEnd: return "Trước khi kết thúc"
            }
        case .indonesian:
            switch relation {
            case .beforeStart: return "Sebelum mulai"
            case .afterStart: return "Setelah mulai"
            case .beforeEnd: return "Sebelum berakhir"
            }
        case .russian:
            switch relation {
            case .beforeStart: return "До начала"
            case .afterStart: return "После начала"
            case .beforeEnd: return "До окончания"
            }
        }
    }

    nonisolated func reminderUnitTitle(_ unit: DeadlineReminderUnit, value: Int) -> String {
        let pluralized = value > 1

        switch self {
        case .english:
            switch unit {
            case .minute: return pluralized ? "minutes" : "minute"
            case .hour: return pluralized ? "hours" : "hour"
            case .day: return pluralized ? "days" : "day"
            }
        case .chinese:
            switch unit {
            case .minute: return "分钟"
            case .hour: return "小时"
            case .day: return "天"
            }
        case .japanese:
            switch unit {
            case .minute: return "分"
            case .hour: return "時間"
            case .day: return "日"
            }
        case .korean:
            switch unit {
            case .minute: return "분"
            case .hour: return "시간"
            case .day: return "일"
            }
        case .spanishSpain, .spanishMexico:
            switch unit {
            case .minute: return pluralized ? "minutos" : "minuto"
            case .hour: return pluralized ? "horas" : "hora"
            case .day: return pluralized ? "días" : "día"
            }
        case .french:
            switch unit {
            case .minute: return pluralized ? "minutes" : "minute"
            case .hour: return pluralized ? "heures" : "heure"
            case .day: return pluralized ? "jours" : "jour"
            }
        case .german:
            switch unit {
            case .minute: return pluralized ? "Minuten" : "Minute"
            case .hour: return pluralized ? "Stunden" : "Stunde"
            case .day: return pluralized ? "Tage" : "Tag"
            }
        case .thai:
            switch unit {
            case .minute: return "นาที"
            case .hour: return "ชั่วโมง"
            case .day: return "วัน"
            }
        case .vietnamese:
            switch unit {
            case .minute: return "phút"
            case .hour: return "giờ"
            case .day: return "ngày"
            }
        case .indonesian:
            switch unit {
            case .minute: return "menit"
            case .hour: return "jam"
            case .day: return "hari"
            }
        case .russian:
            return russianReminderUnit(for: unit, value: value)
        }
    }

    nonisolated func reminderDurationSummary(value: Int, unit: DeadlineReminderUnit) -> String {
        switch self {
        case .chinese, .japanese, .korean:
            return "\(value)\(reminderUnitTitle(unit, value: value))"
        default:
            return "\(value) \(reminderUnitTitle(unit, value: value))"
        }
    }

    nonisolated func reminderSummary(relation: DeadlineReminderRelation, value: Int, unit: DeadlineReminderUnit) -> String {
        let duration = reminderDurationSummary(value: value, unit: unit)

        switch self {
        case .english:
            switch relation {
            case .beforeStart: return "Remind me \(duration) before start"
            case .afterStart: return "Remind me \(duration) after start"
            case .beforeEnd: return "Remind me \(duration) before end"
            }
        case .chinese:
            switch relation {
            case .beforeStart: return "在开始前\(duration)提醒我"
            case .afterStart: return "在开始后\(duration)提醒我"
            case .beforeEnd: return "在结束前\(duration)提醒我"
            }
        case .japanese:
            switch relation {
            case .beforeStart: return "開始\(duration)前に通知"
            case .afterStart: return "開始\(duration)後に通知"
            case .beforeEnd: return "終了\(duration)前に通知"
            }
        case .korean:
            switch relation {
            case .beforeStart: return "시작 \(duration) 전에 알림"
            case .afterStart: return "시작 \(duration) 후에 알림"
            case .beforeEnd: return "종료 \(duration) 전에 알림"
            }
        case .spanishSpain, .spanishMexico:
            switch relation {
            case .beforeStart: return "Recuérdamelo \(duration) antes del inicio"
            case .afterStart: return "Recuérdamelo \(duration) después del inicio"
            case .beforeEnd: return "Recuérdamelo \(duration) antes del final"
            }
        case .french:
            switch relation {
            case .beforeStart: return "Me rappeler \(duration) avant le début"
            case .afterStart: return "Me rappeler \(duration) après le début"
            case .beforeEnd: return "Me rappeler \(duration) avant la fin"
            }
        case .german:
            switch relation {
            case .beforeStart: return "Erinnere mich \(duration) vor Beginn"
            case .afterStart: return "Erinnere mich \(duration) nach Beginn"
            case .beforeEnd: return "Erinnere mich \(duration) vor Ende"
            }
        case .thai:
            switch relation {
            case .beforeStart: return "เตือนฉันก่อนเริ่ม \(duration)"
            case .afterStart: return "เตือนฉันหลังเริ่ม \(duration)"
            case .beforeEnd: return "เตือนฉันก่อนสิ้นสุด \(duration)"
            }
        case .vietnamese:
            switch relation {
            case .beforeStart: return "Nhắc tôi \(duration) trước khi bắt đầu"
            case .afterStart: return "Nhắc tôi \(duration) sau khi bắt đầu"
            case .beforeEnd: return "Nhắc tôi \(duration) trước khi kết thúc"
            }
        case .indonesian:
            switch relation {
            case .beforeStart: return "Ingatkan saya \(duration) sebelum mulai"
            case .afterStart: return "Ingatkan saya \(duration) setelah mulai"
            case .beforeEnd: return "Ingatkan saya \(duration) sebelum berakhir"
            }
        case .russian:
            switch relation {
            case .beforeStart: return "Напомнить мне за \(duration) до начала"
            case .afterStart: return "Напомнить мне через \(duration) после начала"
            case .beforeEnd: return "Напомнить мне за \(duration) до окончания"
            }
        }
    }

    nonisolated func reminderNotificationBody(for reminder: DeadlineReminder) -> String {
        let duration = reminderDurationSummary(value: reminder.value, unit: reminder.unit)

        switch self {
        case .english:
            switch reminder.relation {
            case .beforeStart: return "Starts in \(duration)"
            case .afterStart: return "Started \(duration) ago"
            case .beforeEnd: return "Ends in \(duration)"
            }
        case .chinese:
            switch reminder.relation {
            case .beforeStart: return "距开始\(duration)"
            case .afterStart: return "已开始\(duration)"
            case .beforeEnd: return "距结束\(duration)"
            }
        case .japanese:
            switch reminder.relation {
            case .beforeStart: return "開始まで \(duration)"
            case .afterStart: return "開始から \(duration)"
            case .beforeEnd: return "終了まで \(duration)"
            }
        case .korean:
            switch reminder.relation {
            case .beforeStart: return "시작까지 \(duration)"
            case .afterStart: return "시작 후 \(duration)"
            case .beforeEnd: return "종료까지 \(duration)"
            }
        case .spanishSpain, .spanishMexico:
            switch reminder.relation {
            case .beforeStart: return "Empieza en \(duration)"
            case .afterStart: return "Empezó hace \(duration)"
            case .beforeEnd: return "Termina en \(duration)"
            }
        case .french:
            switch reminder.relation {
            case .beforeStart: return "Débute dans \(duration)"
            case .afterStart: return "A commencé il y a \(duration)"
            case .beforeEnd: return "Se termine dans \(duration)"
            }
        case .german:
            switch reminder.relation {
            case .beforeStart: return "Beginnt in \(duration)"
            case .afterStart: return "Begann vor \(duration)"
            case .beforeEnd: return "Endet in \(duration)"
            }
        case .thai:
            switch reminder.relation {
            case .beforeStart: return "จะเริ่มในอีก \(duration)"
            case .afterStart: return "เริ่มแล้ว \(duration)"
            case .beforeEnd: return "จะสิ้นสุดในอีก \(duration)"
            }
        case .vietnamese:
            switch reminder.relation {
            case .beforeStart: return "Bắt đầu sau \(duration)"
            case .afterStart: return "Đã bắt đầu \(duration)"
            case .beforeEnd: return "Kết thúc sau \(duration)"
            }
        case .indonesian:
            switch reminder.relation {
            case .beforeStart: return "Mulai dalam \(duration)"
            case .afterStart: return "Dimulai \(duration) lalu"
            case .beforeEnd: return "Berakhir dalam \(duration)"
            }
        case .russian:
            switch reminder.relation {
            case .beforeStart: return "Начнётся через \(duration)"
            case .afterStart: return "Началось \(duration) назад"
            case .beforeEnd: return "Закончится через \(duration)"
            }
        }
    }

    func reminderListSummary(_ reminders: [DeadlineReminder]) -> String {
        guard reminders.isEmpty == false else { return noReminderTitle }

        let formatter = ListFormatter()
        formatter.locale = locale
        let summaries = reminders.map { $0.summary(in: self) }
        return formatter.string(from: summaries) ?? summaries.joined(separator: ", ")
    }

    var privacyPolicyContent: PrivacyPolicyContent {
        switch self {
        case .english:
            return PrivacyPolicyContent(
                title: "Privacy Policy",
                effectiveDate: "Effective date: March 20, 2026",
                sections: [
                    PrivacyPolicySection(
                        title: "1. Data Processing",
                        body: "Liquid Deadline does not collect, upload, sell, rent, or share your personal information. Your tasks, categories, descriptions, and settings are stored locally on your device only."
                    ),
                    PrivacyPolicySection(
                        title: "2. Network Services",
                        body: "The app does not require account registration and does not use developer-operated servers to store your task data. If you choose to subscribe to an external calendar URL, the app fetches that feed directly from your device to import or refresh tasks. The developer does not receive or store that calendar data on a server."
                    ),
                    PrivacyPolicySection(
                        title: "3. CloudKit Sync",
                        body: "If you enable synchronization, Liquid Deadline uses Apple's CloudKit framework to sync data across Apple devices signed in to the same iCloud account. The developer does not receive, access, collect, or store your personal data on developer-controlled servers. Sync data is processed through your iCloud account and Apple's CloudKit infrastructure, subject to Apple's applicable terms and privacy practices."
                    ),
                    PrivacyPolicySection(
                        title: "4. Third-Party Sharing",
                        body: "The app does not share your personal information with third parties for advertising, analytics, or profiling."
                    ),
                    PrivacyPolicySection(
                        title: "5. Your Responsibility",
                        body: "You are responsible for how you use this app and for verifying any task, reminder, or deadline information you enter. The developer is not liable for losses, delays, missed deadlines, or other adverse consequences arising from the use of this app, to the extent permitted by applicable law."
                    ),
                    PrivacyPolicySection(
                        title: "6. Contact",
                        body: "If you have privacy questions, contact the developer through the contact method provided on the App Store product page."
                    ),
                ]
            )
        case .chinese:
            return PrivacyPolicyContent(
                title: "隐私政策",
                effectiveDate: "生效日期：2026 年 3 月 20 日",
                sections: [
                    PrivacyPolicySection(
                        title: "1. 数据处理",
                        body: "Liquid Deadline 不会收集、上传、出售、出租或共享你的个人信息。你的事项、分类、描述和设置仅保存在你的设备本地。"
                    ),
                    PrivacyPolicySection(
                        title: "2. 网络服务",
                        body: "本应用无需账号注册，也不会使用开发者自建服务器存储你的任务数据。如果你选择订阅外部日历 URL，应用会仅在你的设备上直接拉取该日历内容，用于导入或刷新事项。开发者不会在服务器端接收或存储这些日历数据。"
                    ),
                    PrivacyPolicySection(
                        title: "3. CloudKit 同步",
                        body: "如果你启用同步功能，Liquid Deadline 会基于 Apple 的 CloudKit 框架，在登录同一 iCloud 账号的 Apple 设备之间同步数据。开发者不会在自有服务器上接收、访问、收集或存储你的个人数据。同步数据通过你的 iCloud 账号与 Apple 提供的 CloudKit 基础设施处理，并受 Apple 相关条款和隐私政策约束。"
                    ),
                    PrivacyPolicySection(
                        title: "4. 第三方共享",
                        body: "本应用不会为了广告、分析或画像目的向第三方共享你的个人信息。"
                    ),
                    PrivacyPolicySection(
                        title: "5. 用户责任",
                        body: "你应自行决定如何使用本应用，并自行核对你录入的事项、提醒和截止时间信息。在适用法律允许的范围内，开发者不对因使用本应用而产生的损失、延误、错过截止时间或其他不良后果承担责任。"
                    ),
                    PrivacyPolicySection(
                        title: "6. 联系方式",
                        body: "如果你对隐私问题有疑问，请通过 App Store 产品页提供的联系方式联系开发者。"
                    ),
                ]
            )
        case .japanese:
            return PrivacyPolicyContent(
                title: "プライバシーポリシー",
                effectiveDate: "施行日: 2026年3月20日",
                sections: [
                    PrivacyPolicySection(
                        title: "1. データの取り扱い",
                        body: "Liquid Deadline は、あなたの個人情報を収集、アップロード、販売、貸与、共有しません。タスク、カテゴリ、説明、設定はすべてあなたのデバイス内にのみ保存されます。"
                    ),
                    PrivacyPolicySection(
                        title: "2. ネットワークサービス",
                        body: "本アプリではアカウント登録は不要で、タスクデータを保存するための開発者運営サーバーも使用しません。外部カレンダー URL を購読する場合、アプリはあなたのデバイスから直接そのカレンダーを取得して、タスクの取り込みや更新を行います。開発者がそのカレンダーデータをサーバー上で受信または保存することはありません。"
                    ),
                    PrivacyPolicySection(
                        title: "3. CloudKit同期",
                        body: "同期機能を有効にした場合、Liquid Deadline は Apple の CloudKit フレームワークを利用し、同じ iCloud アカウントでサインインしている Apple デバイス間でデータを同期します。開発者が管理するサーバー上で、あなたの個人データを受信、アクセス、収集、保存することはありません。同期データは、あなたの iCloud アカウントおよび Apple の CloudKit 基盤を通じて処理され、Apple の関連規約およびプライバシーポリシーが適用されます。"
                    ),
                    PrivacyPolicySection(
                        title: "4. 第三者共有",
                        body: "本アプリは、広告、分析、プロファイリングの目的で個人情報を第三者と共有しません。"
                    ),
                    PrivacyPolicySection(
                        title: "5. 利用者の責任",
                        body: "本アプリの利用方法、および入力したタスク、リマインダー、締切情報の確認は利用者自身の責任です。適用法で認められる範囲において、開発者は本アプリの利用に起因する損失、遅延、締切の逸失、その他の不利益について責任を負いません。"
                    ),
                    PrivacyPolicySection(
                        title: "6. お問い合わせ",
                        body: "プライバシーに関するご質問がある場合は、App Store の製品ページに記載された連絡先から開発者までご連絡ください。"
                    ),
                ]
            )
        case .korean:
            return PrivacyPolicyContent(
                title: "개인정보 처리방침",
                effectiveDate: "시행일: 2026년 3월 20일",
                sections: [
                    PrivacyPolicySection(
                        title: "1. 데이터 처리",
                        body: "Liquid Deadline은 사용자의 개인정보를 수집, 업로드, 판매, 임대 또는 공유하지 않습니다. 작업, 카테고리, 설명 및 설정은 모두 사용자 기기에만 로컬로 저장됩니다."
                    ),
                    PrivacyPolicySection(
                        title: "2. 네트워크 서비스",
                        body: "이 앱은 계정 등록을 요구하지 않으며, 작업 데이터를 저장하기 위해 개발자가 운영하는 서버를 사용하지 않습니다. 외부 캘린더 URL을 구독하면 앱은 사용자 기기에서 해당 캘린더를 직접 가져와 작업을 가져오거나 새로고침합니다. 개발자는 해당 캘린더 데이터를 서버에서 수신하거나 저장하지 않습니다."
                    ),
                    PrivacyPolicySection(
                        title: "3. CloudKit 동기화",
                        body: "동기화 기능을 켜면 Liquid Deadline은 Apple의 CloudKit 프레임워크를 사용하여 동일한 iCloud 계정으로 로그인한 Apple 기기 사이에서 데이터를 동기화합니다. 개발자가 관리하는 서버에서 사용자의 개인 데이터를 수신, 접근, 수집 또는 저장하지 않습니다. 동기화 데이터는 사용자의 iCloud 계정과 Apple의 CloudKit 인프라를 통해 처리되며, Apple의 관련 약관 및 개인정보 처리방침이 적용됩니다."
                    ),
                    PrivacyPolicySection(
                        title: "4. 제3자 공유",
                        body: "이 앱은 광고, 분석 또는 프로파일링 목적으로 사용자의 개인정보를 제3자와 공유하지 않습니다."
                    ),
                    PrivacyPolicySection(
                        title: "5. 사용자 책임",
                        body: "이 앱을 어떻게 사용할지, 그리고 입력한 작업, 알림, 마감 정보를 확인할 책임은 사용자에게 있습니다. 관련 법률이 허용하는 범위 내에서 개발자는 이 앱 사용으로 인해 발생하는 손실, 지연, 마감 누락 또는 기타 불이익에 대해 책임지지 않습니다."
                    ),
                    PrivacyPolicySection(
                        title: "6. 문의",
                        body: "개인정보 관련 문의가 있으면 App Store 제품 페이지에 제공된 연락처를 통해 개발자에게 문의해 주세요."
                    ),
                ]
            )
        case .spanishSpain:
            return PrivacyPolicyContent(
                title: "Política de privacidad",
                effectiveDate: "Fecha de entrada en vigor: 20 de marzo de 2026",
                sections: [
                    PrivacyPolicySection(
                        title: "1. Tratamiento de datos",
                        body: "Liquid Deadline no recopila, sube, vende, alquila ni comparte tu información personal. Tus tareas, categorías, descripciones y ajustes se almacenan únicamente de forma local en tu dispositivo."
                    ),
                    PrivacyPolicySection(
                        title: "2. Servicios de red",
                        body: "La app no requiere registro de cuenta y no utiliza servidores gestionados por el desarrollador para almacenar tus datos de tareas. Si decides suscribirte a una URL de calendario externa, la app descarga ese calendario directamente desde tu dispositivo para importar o actualizar tareas. El desarrollador no recibe ni almacena esos datos de calendario en un servidor."
                    ),
                    PrivacyPolicySection(
                        title: "3. Sincronización con CloudKit",
                        body: "Si activas la sincronización, Liquid Deadline utiliza el framework CloudKit de Apple para sincronizar datos entre dispositivos Apple que hayan iniciado sesión con la misma cuenta de iCloud. El desarrollador no recibe, accede, recopila ni almacena tus datos personales en servidores controlados por el desarrollador. Los datos sincronizados se procesan a través de tu cuenta de iCloud y la infraestructura CloudKit de Apple, y están sujetos a las condiciones y prácticas de privacidad aplicables de Apple."
                    ),
                    PrivacyPolicySection(
                        title: "4. Compartición con terceros",
                        body: "La app no comparte tu información personal con terceros con fines publicitarios, analíticos ni de elaboración de perfiles."
                    ),
                    PrivacyPolicySection(
                        title: "5. Tu responsabilidad",
                        body: "Eres responsable de cómo utilizas esta app y de verificar cualquier tarea, recordatorio o fecha límite que introduzcas. En la medida permitida por la ley aplicable, el desarrollador no será responsable de pérdidas, retrasos, plazos incumplidos u otras consecuencias adversas derivadas del uso de esta app."
                    ),
                    PrivacyPolicySection(
                        title: "6. Contacto",
                        body: "Si tienes preguntas sobre privacidad, ponte en contacto con el desarrollador mediante el método de contacto indicado en la página del producto en App Store."
                    ),
                ]
            )
        case .spanishMexico:
            return PrivacyPolicyContent(
                title: "Política de privacidad",
                effectiveDate: "Fecha de vigencia: 20 de marzo de 2026",
                sections: [
                    PrivacyPolicySection(
                        title: "1. Tratamiento de datos",
                        body: "Liquid Deadline no recopila, sube, vende, renta ni comparte tu información personal. Tus tareas, categorías, descripciones y configuraciones se guardan únicamente de forma local en tu dispositivo."
                    ),
                    PrivacyPolicySection(
                        title: "2. Servicios de red",
                        body: "La app no requiere registro de cuenta y no utiliza servidores administrados por el desarrollador para almacenar tus datos de tareas. Si eliges suscribirte a una URL de calendario externa, la app obtiene ese calendario directamente desde tu dispositivo para importar o actualizar tareas. El desarrollador no recibe ni almacena esos datos de calendario en un servidor."
                    ),
                    PrivacyPolicySection(
                        title: "3. Sincronización con CloudKit",
                        body: "Si activas la sincronización, Liquid Deadline utiliza el framework CloudKit de Apple para sincronizar datos entre dispositivos Apple que hayan iniciado sesión con la misma cuenta de iCloud. El desarrollador no recibe, accede, recopila ni almacena tus datos personales en servidores controlados por el desarrollador. Los datos sincronizados se procesan a través de tu cuenta de iCloud y la infraestructura CloudKit de Apple, y quedan sujetos a los términos y prácticas de privacidad aplicables de Apple."
                    ),
                    PrivacyPolicySection(
                        title: "4. Compartir con terceros",
                        body: "La app no comparte tu información personal con terceros con fines de publicidad, analítica o creación de perfiles."
                    ),
                    PrivacyPolicySection(
                        title: "5. Tu responsabilidad",
                        body: "Eres responsable de cómo usas esta app y de verificar cualquier tarea, recordatorio o fecha límite que ingreses. En la medida permitida por la ley aplicable, el desarrollador no será responsable por pérdidas, retrasos, fechas límite incumplidas u otras consecuencias adversas derivadas del uso de esta app."
                    ),
                    PrivacyPolicySection(
                        title: "6. Contacto",
                        body: "Si tienes preguntas sobre privacidad, ponte en contacto con el desarrollador mediante el método de contacto indicado en la página del producto en App Store."
                    ),
                ]
            )
        case .french:
            return PrivacyPolicyContent(
                title: "Politique de confidentialité",
                effectiveDate: "Date d'effet : 20 mars 2026",
                sections: [
                    PrivacyPolicySection(
                        title: "1. Traitement des données",
                        body: "Liquid Deadline ne collecte, n'envoie, ne vend, ne loue ni ne partage vos informations personnelles. Vos tâches, catégories, descriptions et réglages sont stockés uniquement en local sur votre appareil."
                    ),
                    PrivacyPolicySection(
                        title: "2. Services réseau",
                        body: "L'application ne nécessite pas de création de compte et n'utilise pas de serveurs exploités par le développeur pour stocker vos données de tâches. Si vous choisissez de vous abonner à une URL de calendrier externe, l'application récupère ce calendrier directement depuis votre appareil pour importer ou actualiser des tâches. Le développeur ne reçoit ni ne stocke ces données sur un serveur."
                    ),
                    PrivacyPolicySection(
                        title: "3. Synchronisation CloudKit",
                        body: "Si vous activez la synchronisation, Liquid Deadline utilise le framework CloudKit d'Apple pour synchroniser les données entre les appareils Apple connectés au même compte iCloud. Le développeur ne reçoit pas, n'accède pas, ne collecte pas et ne stocke pas vos données personnelles sur des serveurs contrôlés par le développeur. Les données synchronisées sont traitées via votre compte iCloud et l'infrastructure CloudKit d'Apple, et sont soumises aux conditions et pratiques de confidentialité applicables d'Apple."
                    ),
                    PrivacyPolicySection(
                        title: "4. Partage avec des tiers",
                        body: "L'application ne partage pas vos informations personnelles avec des tiers à des fins publicitaires, analytiques ou de profilage."
                    ),
                    PrivacyPolicySection(
                        title: "5. Votre responsabilité",
                        body: "Vous êtes responsable de votre manière d'utiliser cette application et de vérifier les tâches, rappels ou échéances que vous saisissez. Dans la mesure permise par la loi applicable, le développeur n'est pas responsable des pertes, retards, échéances manquées ou autres conséquences défavorables résultant de l'utilisation de l'application."
                    ),
                    PrivacyPolicySection(
                        title: "6. Contact",
                        body: "Si vous avez des questions relatives à la confidentialité, contactez le développeur via le moyen de contact indiqué sur la page produit de l'App Store."
                    ),
                ]
            )
        case .german:
            return PrivacyPolicyContent(
                title: "Datenschutzerklärung",
                effectiveDate: "Gültig ab: 20. März 2026",
                sections: [
                    PrivacyPolicySection(
                        title: "1. Datenverarbeitung",
                        body: "Liquid Deadline erhebt, lädt, verkauft, vermietet oder teilt Ihre personenbezogenen Daten nicht. Ihre Aufgaben, Kategorien, Beschreibungen und Einstellungen werden ausschließlich lokal auf Ihrem Gerät gespeichert."
                    ),
                    PrivacyPolicySection(
                        title: "2. Netzwerkdienste",
                        body: "Die App erfordert keine Kontoregistrierung und verwendet keine vom Entwickler betriebenen Server, um Ihre Aufgabendaten zu speichern. Wenn Sie einen externen Kalender per URL abonnieren, ruft die App diesen Kalender direkt von Ihrem Gerät ab, um Aufgaben zu importieren oder zu aktualisieren. Der Entwickler empfängt oder speichert diese Kalenderdaten nicht auf einem Server."
                    ),
                    PrivacyPolicySection(
                        title: "3. CloudKit-Synchronisierung",
                        body: "Wenn Sie die Synchronisierung aktivieren, verwendet Liquid Deadline das CloudKit-Framework von Apple, um Daten zwischen Apple-Geräten zu synchronisieren, die mit demselben iCloud-Account angemeldet sind. Der Entwickler empfängt Ihre personenbezogenen Daten nicht, greift nicht darauf zu, erhebt sie nicht und speichert sie nicht auf vom Entwickler kontrollierten Servern. Synchronisierte Daten werden über Ihr iCloud-Konto und Apples CloudKit-Infrastruktur verarbeitet und unterliegen Apples einschlägigen Bedingungen und Datenschutzrichtlinien."
                    ),
                    PrivacyPolicySection(
                        title: "4. Weitergabe an Dritte",
                        body: "Die App gibt Ihre personenbezogenen Daten nicht zu Werbe-, Analyse- oder Profiling-Zwecken an Dritte weiter."
                    ),
                    PrivacyPolicySection(
                        title: "5. Ihre Verantwortung",
                        body: "Sie sind selbst dafür verantwortlich, wie Sie diese App nutzen, und dafür, alle eingegebenen Aufgaben-, Erinnerungs- und Fristinformationen zu prüfen. Soweit gesetzlich zulässig, haftet der Entwickler nicht für Verluste, Verzögerungen, verpasste Fristen oder andere nachteilige Folgen, die aus der Nutzung der App entstehen."
                    ),
                    PrivacyPolicySection(
                        title: "6. Kontakt",
                        body: "Wenn Sie Fragen zum Datenschutz haben, kontaktieren Sie den Entwickler über die auf der App-Store-Produktseite angegebene Kontaktmöglichkeit."
                    ),
                ]
            )
        case .thai:
            return PrivacyPolicyContent(
                title: "นโยบายความเป็นส่วนตัว",
                effectiveDate: "วันที่มีผลบังคับใช้: 20 มีนาคม 2026",
                sections: [
                    PrivacyPolicySection(
                        title: "1. การประมวลผลข้อมูล",
                        body: "Liquid Deadline จะไม่เก็บรวบรวม อัปโหลด ขาย ให้เช่า หรือแบ่งปันข้อมูลส่วนบุคคลของคุณ งาน หมวดหมู่ คำอธิบาย และการตั้งค่าของคุณจะถูกเก็บไว้เฉพาะในอุปกรณ์ของคุณเท่านั้น"
                    ),
                    PrivacyPolicySection(
                        title: "2. บริการเครือข่าย",
                        body: "แอปนี้ไม่ต้องลงทะเบียนบัญชี และไม่ใช้เซิร์ฟเวอร์ที่ผู้พัฒนาดูแลเองในการจัดเก็บข้อมูลงานของคุณ หากคุณเลือกสมัครรับ URL ปฏิทินภายนอก แอปจะดึงปฏิทินนั้นโดยตรงจากอุปกรณ์ของคุณเพื่อใช้ในการนำเข้าหรือรีเฟรชงาน ผู้พัฒนาไม่ได้รับหรือจัดเก็บข้อมูลปฏิทินดังกล่าวบนเซิร์ฟเวอร์"
                    ),
                    PrivacyPolicySection(
                        title: "3. การซิงค์ด้วย CloudKit",
                        body: "หากคุณเปิดใช้การซิงค์ Liquid Deadline จะใช้เฟรมเวิร์ก CloudKit ของ Apple เพื่อซิงค์ข้อมูลระหว่างอุปกรณ์ Apple ที่ลงชื่อเข้าใช้ด้วยบัญชี iCloud เดียวกัน ผู้พัฒนาไม่ได้รับ เข้าถึง เก็บรวบรวม หรือจัดเก็บข้อมูลส่วนบุคคลของคุณบนเซิร์ฟเวอร์ที่ผู้พัฒนาควบคุม ข้อมูลที่ซิงค์จะถูกประมวลผลผ่านบัญชี iCloud ของคุณและโครงสร้างพื้นฐาน CloudKit ของ Apple และอยู่ภายใต้ข้อกำหนดและแนวทางด้านความเป็นส่วนตัวของ Apple"
                    ),
                    PrivacyPolicySection(
                        title: "4. การแบ่งปันกับบุคคลที่สาม",
                        body: "แอปนี้จะไม่แบ่งปันข้อมูลส่วนบุคคลของคุณกับบุคคลที่สามเพื่อวัตถุประสงค์ด้านโฆษณา การวิเคราะห์ หรือการสร้างโปรไฟล์"
                    ),
                    PrivacyPolicySection(
                        title: "5. ความรับผิดชอบของผู้ใช้",
                        body: "คุณเป็นผู้รับผิดชอบต่อวิธีการใช้งานแอปนี้ รวมถึงการตรวจสอบข้อมูลงาน การเตือนความจำ หรือกำหนดเวลาที่คุณป้อน ภายใต้ขอบเขตที่กฎหมายที่ใช้บังคับอนุญาต นักพัฒนาไม่รับผิดชอบต่อความสูญเสีย ความล่าช้า การพลาดกำหนดเวลา หรือผลกระทบเชิงลบอื่นใดที่เกิดจากการใช้แอปนี้"
                    ),
                    PrivacyPolicySection(
                        title: "6. การติดต่อ",
                        body: "หากคุณมีคำถามเกี่ยวกับความเป็นส่วนตัว โปรดติดต่อผู้พัฒนาผ่านช่องทางการติดต่อที่ระบุไว้ในหน้าผลิตภัณฑ์บน App Store"
                    ),
                ]
            )
        case .vietnamese:
            return PrivacyPolicyContent(
                title: "Chính sách quyền riêng tư",
                effectiveDate: "Ngày có hiệu lực: 20 tháng 3 năm 2026",
                sections: [
                    PrivacyPolicySection(
                        title: "1. Xử lý dữ liệu",
                        body: "Liquid Deadline không thu thập, tải lên, bán, cho thuê hoặc chia sẻ thông tin cá nhân của bạn. Các tác vụ, danh mục, mô tả và cài đặt của bạn chỉ được lưu cục bộ trên thiết bị."
                    ),
                    PrivacyPolicySection(
                        title: "2. Dịch vụ mạng",
                        body: "Ứng dụng không yêu cầu đăng ký tài khoản và không sử dụng máy chủ do nhà phát triển vận hành để lưu trữ dữ liệu tác vụ của bạn. Nếu bạn chọn đăng ký một URL lịch bên ngoài, ứng dụng sẽ lấy trực tiếp lịch đó từ thiết bị của bạn để nhập hoặc làm mới tác vụ. Nhà phát triển không nhận hoặc lưu trữ dữ liệu lịch đó trên máy chủ."
                    ),
                    PrivacyPolicySection(
                        title: "3. Đồng bộ qua CloudKit",
                        body: "Nếu bạn bật đồng bộ, Liquid Deadline sử dụng framework CloudKit của Apple để đồng bộ dữ liệu giữa các thiết bị Apple đăng nhập cùng một tài khoản iCloud. Nhà phát triển không nhận, truy cập, thu thập hoặc lưu trữ dữ liệu cá nhân của bạn trên các máy chủ do nhà phát triển kiểm soát. Dữ liệu đồng bộ được xử lý thông qua tài khoản iCloud của bạn và hạ tầng CloudKit của Apple, đồng thời chịu sự điều chỉnh của các điều khoản và chính sách quyền riêng tư hiện hành của Apple."
                    ),
                    PrivacyPolicySection(
                        title: "4. Chia sẻ với bên thứ ba",
                        body: "Ứng dụng không chia sẻ thông tin cá nhân của bạn với bên thứ ba cho mục đích quảng cáo, phân tích hoặc lập hồ sơ."
                    ),
                    PrivacyPolicySection(
                        title: "5. Trách nhiệm của bạn",
                        body: "Bạn chịu trách nhiệm về cách sử dụng ứng dụng này và về việc xác minh bất kỳ tác vụ, lời nhắc hoặc thông tin hạn chót nào bạn nhập. Trong phạm vi pháp luật hiện hành cho phép, nhà phát triển không chịu trách nhiệm cho tổn thất, chậm trễ, bỏ lỡ hạn chót hoặc hậu quả bất lợi khác phát sinh từ việc sử dụng ứng dụng."
                    ),
                    PrivacyPolicySection(
                        title: "6. Liên hệ",
                        body: "Nếu bạn có câu hỏi về quyền riêng tư, vui lòng liên hệ với nhà phát triển bằng phương thức liên hệ được cung cấp trên trang sản phẩm App Store."
                    ),
                ]
            )
        case .russian:
            return PrivacyPolicyContent(
                title: "Политика конфиденциальности",
                effectiveDate: "Дата вступления в силу: 20 марта 2026 г.",
                sections: [
                    PrivacyPolicySection(
                        title: "1. Обработка данных",
                        body: "Liquid Deadline не собирает, не загружает, не продаёт, не сдаёт в аренду и не передаёт вашу личную информацию. Ваши задачи, категории, описания и настройки хранятся только локально на вашем устройстве."
                    ),
                    PrivacyPolicySection(
                        title: "2. Сетевые сервисы",
                        body: "Приложение не требует регистрации аккаунта и не использует серверы, управляемые разработчиком, для хранения ваших данных задач. Если вы подпишетесь на внешний URL календаря, приложение будет загружать этот календарь напрямую с вашего устройства для импорта или обновления задач. Разработчик не получает и не хранит эти данные календаря на сервере."
                    ),
                    PrivacyPolicySection(
                        title: "3. Синхронизация через CloudKit",
                        body: "Если вы включите синхронизацию, Liquid Deadline использует фреймворк Apple CloudKit для синхронизации данных между устройствами Apple, вошедшими в одну и ту же учётную запись iCloud. Разработчик не получает, не имеет доступа, не собирает и не хранит ваши персональные данные на серверах, контролируемых разработчиком. Синхронизируемые данные обрабатываются через вашу учётную запись iCloud и инфраструктуру CloudKit от Apple и подпадают под применимые условия и правила конфиденциальности Apple."
                    ),
                    PrivacyPolicySection(
                        title: "4. Передача третьим лицам",
                        body: "Приложение не передаёт вашу личную информацию третьим лицам в целях рекламы, аналитики или профилирования."
                    ),
                    PrivacyPolicySection(
                        title: "5. Ваша ответственность",
                        body: "Вы самостоятельно определяете, как использовать это приложение, и обязаны проверять введённые вами задачи, напоминания и сведения о сроках. В пределах, разрешённых применимым законодательством, разработчик не несёт ответственности за убытки, задержки, пропущенные сроки или иные неблагоприятные последствия, возникшие при использовании приложения."
                    ),
                    PrivacyPolicySection(
                        title: "6. Контакты",
                        body: "Если у вас есть вопросы о конфиденциальности, свяжитесь с разработчиком по контактам, указанным на странице приложения в App Store."
                    ),
                ]
            )
        case .indonesian:
            return PrivacyPolicyContent(
                title: "Kebijakan Privasi",
                effectiveDate: "Tanggal berlaku: 20 Maret 2026",
                sections: [
                    PrivacyPolicySection(
                        title: "1. Pemrosesan data",
                        body: "Liquid Deadline tidak mengumpulkan, mengunggah, menjual, menyewakan, atau membagikan informasi pribadi Anda. Tugas, kategori, deskripsi, dan pengaturan Anda disimpan hanya secara lokal di perangkat Anda."
                    ),
                    PrivacyPolicySection(
                        title: "2. Layanan jaringan",
                        body: "Aplikasi ini tidak memerlukan pendaftaran akun dan tidak menggunakan server yang dikelola pengembang untuk menyimpan data tugas Anda. Jika Anda memilih berlangganan URL kalender eksternal, aplikasi akan mengambil kalender tersebut langsung dari perangkat Anda untuk mengimpor atau menyegarkan tugas. Pengembang tidak menerima atau menyimpan data kalender tersebut di server."
                    ),
                    PrivacyPolicySection(
                        title: "3. Sinkronisasi CloudKit",
                        body: "Jika Anda mengaktifkan sinkronisasi, Liquid Deadline menggunakan framework CloudKit milik Apple untuk menyinkronkan data di antara perangkat Apple yang masuk dengan akun iCloud yang sama. Pengembang tidak menerima, mengakses, mengumpulkan, atau menyimpan data pribadi Anda di server yang dikendalikan pengembang. Data sinkronisasi diproses melalui akun iCloud Anda dan infrastruktur CloudKit milik Apple, serta tunduk pada syarat dan praktik privasi Apple yang berlaku."
                    ),
                    PrivacyPolicySection(
                        title: "4. Berbagi dengan pihak ketiga",
                        body: "Aplikasi ini tidak membagikan informasi pribadi Anda kepada pihak ketiga untuk tujuan iklan, analitik, atau pembuatan profil."
                    ),
                    PrivacyPolicySection(
                        title: "5. Tanggung jawab Anda",
                        body: "Anda bertanggung jawab atas cara Anda menggunakan aplikasi ini dan untuk memeriksa setiap tugas, pengingat, atau informasi tenggat waktu yang Anda masukkan. Sejauh diizinkan oleh hukum yang berlaku, pengembang tidak bertanggung jawab atas kerugian, keterlambatan, tenggat waktu yang terlewat, atau konsekuensi merugikan lainnya yang timbul dari penggunaan aplikasi ini."
                    ),
                    PrivacyPolicySection(
                        title: "6. Kontak",
                        body: "Jika Anda memiliki pertanyaan terkait privasi, hubungi pengembang melalui metode kontak yang tercantum di halaman produk App Store."
                    ),
                ]
            )
        }
    }
}
