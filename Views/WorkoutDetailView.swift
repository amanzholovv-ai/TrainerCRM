import SwiftUI

struct WorkoutDetailView: View {
    @Binding var workout: Workout
    var clientId: UUID? = nil
    var clientName: String? = nil

    @EnvironmentObject var store: ClientStore
    @State private var showAddExercise = false
    @State private var exerciseToEdit: Exercise? = nil
    @State private var showReschedule = false

    var body: some View {
        List {
            workoutInfoSection
            exercisesSection
        }
        .navigationTitle("Тренировка")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                   
                    Button {
                        showAddExercise = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddExercise) {
            ExerciseFormView { newExercise in
                workout.exercises.append(newExercise)
            }
        }
        .sheet(item: $exerciseToEdit) { exercise in
            ExerciseFormView(existing: exercise) { updated in
                if let idx = workout.exercises.firstIndex(where: { $0.id == updated.id }) {
                    workout.exercises[idx] = updated
                }
            }
        }
    }

    // MARK: - Инфо о тренировке

    private var workoutInfoSection: some View {
        Section("Тренировка") {
            
            DatePicker(
                selection: $workout.date,
                displayedComponents: .date
            ) {
                Image(systemName: "calendar").foregroundColor(.accentColor)
            }

            DatePicker(
                selection: $workout.date,
                displayedComponents: .hourAndMinute
            ) {
                Image(systemName: "clock").foregroundColor(.accentColor)
            }
           
            HStack {
                Image(systemName: "timer").foregroundColor(.accentColor)
                Stepper("\(workout.duration) мин", value: $workout.duration, in: 15...300, step: 15)
            }

            // Статус — меняется через Menu
            HStack {
                Image(systemName: statusIcon).foregroundColor(statusColor)
                Text("Статус")
                Spacer()
                Menu {
                    ForEach(WorkoutStatus.allCases, id: \.self) { s in
                        Button {
                            if let cid = clientId {
                                store.setWorkoutStatus(s, workoutId: workout.id, for: cid)
                            }
                            
                        } label: {
                            HStack {
                                Text(s.rawValue)
                                if workout.status == s { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    Text(workout.status.rawValue)
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.12))
                        .foregroundColor(statusColor)
                        .cornerRadius(20)
                }
            }
        }
    }

    // MARK: - Упражнения

    private var exercisesSection: some View {
        Section {
            if workout.exercises.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "dumbbell")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("Нет упражнений").foregroundColor(.secondary)
                    Button("Добавить упражнение") { showAddExercise = true }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                ForEach(workout.exercises) { exercise in
                    ExerciseRow(exercise: exercise)
                        .contentShape(Rectangle())
                        .onTapGesture { exerciseToEdit = exercise }
                }
                .onDelete { indexSet in
                    workout.exercises.remove(atOffsets: indexSet)
                }
                .onMove { from, to in
                    workout.exercises.move(fromOffsets: from, toOffset: to)
                }
            }
        } header: {
            HStack {
                Text("Упражнения (\(workout.exercises.count))")
                Spacer()
                if !workout.exercises.isEmpty { EditButton().font(.caption) }
            }
        }
    }

    private var statusIcon: String {
        switch workout.status {
        case .planned:   return "clock"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle"
        case .noShow:    return "person.crop.circle.badge.xmark"
        }
    }

    private var statusColor: Color {
        switch workout.status {
        case .planned:   return .blue
        case .completed: return .green
        case .cancelled: return .red
        case .noShow:    return .orange
        }
    }
}

// MARK: - Строка упражнения

struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(exercise.name).font(.headline)
                Spacer()
                if exercise.videoURL != nil {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 18))
                }
            }
            HStack(spacing: 12) {
                Label("\(exercise.sets) подх.", systemImage: "repeat")
                Label("\(exercise.reps) повт.", systemImage: "arrow.up.arrow.down")
                if exercise.weight > 0 {
                    Label(String(format: "%.1f кг", exercise.weight), systemImage: "scalemass")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)

            if !exercise.comment.isEmpty {
                Text(exercise.comment)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Форма добавления / редактирования упражнения

struct ExerciseFormView: View {
    var existing: Exercise? = nil
    var onSave: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var sets = 3
    @State private var reps = 10
    @State private var weight = 20.0
    @State private var comment = ""
    @State private var videoURL = ""

    var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Упражнение") {
                    TextField("Название", text: $name)
                }

                Section("Параметры") {
                    Stepper("Подходы: \(sets)", value: $sets, in: 1...10)
                    Stepper("Повторы: \(reps)", value: $reps, in: 1...50)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Вес")
                            Spacer()
                            Text(weight == 0 ? "Без веса" : String(format: "%.1f кг", weight))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $weight, in: 0...200, step: 2.5)
                    }
                }

                Section("Комментарий тренера") {
                    TextField("Например: спина прямая, колени не заваливать", text: $comment, axis: .vertical)
                        .lineLimit(3...5)
                }

                Section {
                    TextField("https://youtube.com/...", text: $videoURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)

                    if !videoURL.isEmpty, let url = URL(string: videoURL) {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "play.circle.fill").foregroundColor(.red)
                                Text("Открыть видео")
                            }
                        }
                    }
                } header: {
                    Text("Видео (YouTube / ссылка)")
                } footer: {
                    Text("Вставь ссылку на YouTube или другой видеохостинг")
                }
            }
            .navigationTitle(isEditing ? "Редактировать" : "Новое упражнение")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { fillIfEditing() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let exercise = Exercise(
                            id: existing?.id ?? UUID(),
                            name: name.trimmingCharacters(in: .whitespaces),
                            sets: sets,
                            reps: reps,
                            weight: weight,
                            comment: comment.trimmingCharacters(in: .whitespaces),
                            videoURL: videoURL.isEmpty ? nil : videoURL
                        )
                        onSave(exercise)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func fillIfEditing() {
        guard let e = existing else { return }
        name = e.name
        sets = e.sets
        reps = e.reps
        weight = e.weight
        comment = e.comment
        videoURL = e.videoURL ?? ""
    }
}
