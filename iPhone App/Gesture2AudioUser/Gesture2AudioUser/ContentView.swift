import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var session: PhoneDebugSession

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    pipelineCard
                    predictionCard
                    moodCard
                    soundscapePreviewCard
                    soundscapeCard
                    imuCard
                    watchCard
                    historyCard
                    logCard
                }
                .padding(18)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Gesture2Audio")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        session.resetSoundscape()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .accessibilityLabel("Reset soundscape")
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live IMU Gesture Demo")
                        .font(.title2.weight(.semibold))
                    Text("Bird and fish classification with layered audio output.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                connectionBadge
            }

            HStack(spacing: 10) {
                statusPill(icon: "waveform.path.ecg", text: session.classifierStatus)
                statusPill(icon: session.isResearchModeEnabled ? "externaldrive.badge.checkmark" : "bolt.horizontal", text: session.isResearchModeEnabled ? "research save on" : "transient mode")
                Toggle(isOn: $session.isAudioEnabled) {
                    Image(systemName: session.isAudioEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }
                .labelsHidden()
                .toggleStyle(.switch)
            }
        }
    }

    private var connectionBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(session.isDirectlyReachable ? .green : (session.isReachable ? .yellow : .orange))
                .frame(width: 9, height: 9)
            Text(session.isDirectlyReachable ? "Connected" : (session.isReachable ? "Syncing" : "Waiting"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.thinMaterial, in: Capsule())
    }

    private var pipelineCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Pipeline", icon: "point.3.connected.trianglepath.dotted")
                HStack(spacing: 8) {
                    pipelineStep("1", "Shake")
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                    pipelineStep("2", "Draw")
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                    pipelineStep("3", "Classify")
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                    pipelineStep("4", "Layer")
                }
            }
        }
    }

    private var moodCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Mood Control", icon: "slider.horizontal.3")
                HStack(spacing: 10) {
                    ForEach(SoundscapeMood.allCases) { mood in
                        Button {
                            session.selectMood(mood)
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: mood.systemImage)
                                    .font(.system(size: 18, weight: .semibold))
                                Text(mood.title)
                                    .font(.caption.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(session.selectedMood == mood ? .white : .primary)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(session.selectedMood == mood ? mood.accentColor : Color(.tertiarySystemGroupedBackground))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var soundscapePreviewCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("HTML Engine", icon: "waveform.and.magnifyingglass")
                SoundscapeWebView(controller: session.soundscape)
                    .frame(minHeight: 220, maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var predictionCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Latest Detection", icon: "scope")

                if let prediction = session.lastPrediction {
                    HStack(alignment: .center, spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(prediction.label == "bird" ? Color.teal.opacity(0.16) : Color.blue.opacity(0.16))
                            Image(systemName: prediction.label == "bird" ? "bird.fill" : "drop.fill")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(prediction.label == "bird" ? .teal : .blue)
                        }
                        .frame(width: 64, height: 64)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(prediction.displayName)
                                .font(.title3.weight(.semibold))
                            Text(prediction.soundLayer)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            ProgressView(value: prediction.confidence)
                                .tint(prediction.label == "bird" ? .teal : .blue)
                        }

                        Spacer()

                        Text("\(Int(round(prediction.confidence * 100)))%")
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                    }
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "applewatch.radiowaves.left.and.right")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Waiting for a captured gesture")
                                .font(.headline)
                            Text("Shake the watch, draw bird or fish, then wait for the result.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var soundscapeCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Soundscape", icon: "music.quarternote.3")

                if session.activeSoundLayers.isEmpty {
                    Text("No layers playing")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(session.activeSoundLayers, id: \.self) { layer in
                        HStack(spacing: 10) {
                            Image(systemName: layer.contains("Bird") ? "bird.fill" : "water.waves")
                                .frame(width: 24)
                                .foregroundStyle(layer.contains("Bird") ? .teal : .blue)
                            Text(layer)
                                .font(.headline)
                            Spacer()
                            Text("Active")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                        }
                        .padding(.vertical, 8)
                    }
                }

                Text(session.soundscape.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !session.soundscape.lastError.isEmpty {
                    Text(session.soundscape.lastError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var imuCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Live IMU", icon: "waveform")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    metric("ax", session.latest.ax)
                    metric("ay", session.latest.ay)
                    metric("az", session.latest.az)
                    metric("gx", session.latest.gx)
                    metric("gy", session.latest.gy)
                    metric("gz", session.latest.gz)
                }
            }
        }
    }

    private var watchCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Watch Capture", icon: "applewatch")
                HStack {
                    Label(session.latest.captureState, systemImage: session.latest.shakeDetected ? "bolt.fill" : "timer")
                        .font(.headline)
                    Spacer()
                    Text(String(format: "%.1fs", session.latest.captureRemaining))
                        .font(.headline.monospacedDigit())
                }
                ProgressView(value: session.latest.captureProgress)
                HStack {
                    Text("Shakes \(session.latest.shakeCount)")
                    Spacer()
                    Text(session.isResearchModeEnabled ? "Watch captures \(session.latest.savedCount)" : "Transient capture mode")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Toggle("Research Save", isOn: $session.isResearchModeEnabled)
                    .font(.caption.weight(.semibold))
            }
        }
    }

    private var historyCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Recent Results", icon: "clock.arrow.circlepath")
                if session.predictionHistory.isEmpty {
                    Text("No classifications yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(session.predictionHistory.prefix(5)) { prediction in
                        HStack {
                            Text(prediction.displayName)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(Int(round(prediction.confidence * 100)))%")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var logCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("System Log", icon: "list.bullet.rectangle")
                ForEach(session.logs.prefix(6).indices, id: \.self) { index in
                    Text(session.logs[index])
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private func sectionTitle(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.headline)
    }

    private func pipelineStep(_ number: String, _ text: String) -> some View {
        VStack(spacing: 4) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor, in: Circle())
            Text(text)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func statusPill(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
    }

    private func metric(_ label: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value, format: .number.precision(.fractionLength(3)))
                .font(.callout.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    ContentView()
        .environmentObject(PhoneDebugSession())
}
