import SwiftUI

struct ReminderSelection: Identifiable, Equatable {
    let id: UUID
}

extension Binding where Value == [DeadlineReminder] {
    func reminderBinding(for reminderID: UUID) -> Binding<DeadlineReminder> {
        Binding<DeadlineReminder>(
            get: {
                wrappedValue.first(where: { $0.id == reminderID }) ?? .defaultValue
            },
            set: { updatedReminder in
                guard let index = wrappedValue.firstIndex(where: { $0.id == reminderID }) else { return }
                wrappedValue[index] = updatedReminder
            }
        )
    }
}

struct ReminderListEditor: View {
    let language: AppLanguage
    @Binding var reminders: [DeadlineReminder]
    @Binding var selectedReminder: ReminderSelection?

    private let selectableValues = Array(1...999)

    private var remindersEnabledBinding: Binding<Bool> {
        Binding(
            get: { reminders.isEmpty == false },
            set: { isEnabled in
                if isEnabled {
                    if reminders.isEmpty {
                        reminders = [.defaultValue]
                    }
                } else {
                    selectedReminder = nil
                    reminders.removeAll()
                }
            }
        )
    }

    var body: some View {
        Group {
            Toggle(isOn: remindersEnabledBinding) {
                Text(language.reminderTitle)
            }

            if reminders.isEmpty == false {
                ForEach(reminders) { reminder in
                    ReminderSummaryRow(
                        language: language,
                        summary: reminder.summary(in: language),
                        canDelete: reminders.count > 1
                    ) {
                        selectedReminder = ReminderSelection(id: reminder.id)
                    } onDelete: {
                        if selectedReminder?.id == reminder.id {
                            selectedReminder = nil
                        }
                        reminders.removeAll { $0.id == reminder.id }
                    }
                }

                Button {
                    let reminder = DeadlineReminder.defaultValue
                    reminders.append(reminder)
                    selectedReminder = ReminderSelection(id: reminder.id)
                } label: {
                    Label(language.addReminderTitle, systemImage: "plus.circle")
                }
            }
        }
    }
}

private struct ReminderSummaryRow: View {
    let language: AppLanguage
    let summary: String
    let canDelete: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                HStack(spacing: 8) {
                    Text(summary)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if canDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .accessibilityLabel(language.deleteReminderTitle)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ReminderWheelPickerOverlay: View {
    let language: AppLanguage
    @Binding var reminder: DeadlineReminder
    let onDismiss: () -> Void

    private let selectableValues = Array(1...999)

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.16)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 0) {
                HStack {
                    Text(reminder.summary(in: language))
                        .font(.headline)
                    Spacer()
                    Button(language.text("Done", "完成")) {
                        onDismiss()
                    }
                    .bold()
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 8)

                Divider()

                ReminderWheelPickerContent(
                    language: language,
                    reminder: $reminder,
                    selectableValues: selectableValues
                )
                .padding(.horizontal, 6)
                .padding(.vertical, 10)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

private struct ReminderWheelPickerContent: View {
    let language: AppLanguage
    @Binding var reminder: DeadlineReminder
    let selectableValues: [Int]

    var body: some View {
        HStack(spacing: 0) {
            Picker("", selection: $reminder.relation) {
                ForEach(DeadlineReminderRelation.allCases) { relation in
                    Text(relation.title(in: language)).tag(relation)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()

            Picker("", selection: $reminder.value) {
                ForEach(selectableValues, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()

            Picker("", selection: $reminder.unit) {
                ForEach(DeadlineReminderUnit.allCases) { unit in
                    Text(unit.title(in: language, value: reminder.value)).tag(unit)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .frame(height: 180)
    }
}
