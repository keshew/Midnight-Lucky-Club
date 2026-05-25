import SwiftUI
import UIKit

struct ContentView: View {
    @AppStorage("hasSeenMidnightOnboarding") private var hasSeenOnboarding = false
    @StateObject private var store = ClubStore()
    @State private var showLoading = true

    var body: some View {
        ZStack {
            MidnightGradientBackground()

            Group {
                if showLoading {
                    ClubLoadingView()
                } else if !hasSeenOnboarding {
                    OnboardingView {
                        hasSeenOnboarding = true
                    }
                } else {
                    ClubRootView(store: store)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            guard showLoading else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
                showLoading = false
            }
        }
    }
}

private struct ClubRootView: View {
    @ObservedObject var store: ClubStore

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch store.selectedTab {
                case .club:
                    ClubView(store: store)
                case .sessions:
                    SessionsView(store: store)
                case .charms:
                    CharmsView(store: store)
                case .vault:
                    VaultView(store: store)
                }
            }
            .padding(.bottom, 96)

            CustomClubTabBar(selectedTab: $store.selectedTab)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .sheet(item: $store.selectedMode) { mode in
            GameDetailView(mode: mode, store: store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $store.activeTrialMode) { mode in
            TrialContainerView(mode: mode, store: store)
        }
        .overlay(alignment: .top) {
            if let banner = store.banner {
                BannerView(message: banner.message, style: banner.style)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
            }
        }
    }
}

// MARK: - Screens

private struct ClubView: View {
    @ObservedObject var store: ClubStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                ClubHeader(points: store.clubPoints)

                LuckySessionHeroCard(
                    completed: store.todaySession.completedModeIDs.count,
                    total: store.todaySession.modeIDs.count,
                    action: {
                        guard let next = store.nextSessionMode else {
                            store.presentBanner("Tonight's session is complete.", style: .success)
                            return
                        }
                        store.startTrial(mode: next)
                    }
                )

                HStack(spacing: 10) {
                    StatusMiniCard(title: "Streak", value: "\(store.streak) Night")
                    StatusMiniCard(title: "Rank", value: store.rank)
                    StatusMiniCard(title: "Focus", value: store.focusStateLabel)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Club Games")
                        .font(.custom("AvenirNext-DemiBold", size: 24))
                        .foregroundStyle(.white)
                    Text("\(store.modes.count) tables available")
                        .font(.custom("AvenirNext-Regular", size: 14))
                        .foregroundStyle(Theme.secondaryText)
                }

                LazyVStack(spacing: 13) {
                    ForEach(store.modes) { mode in
                        GameModeCard(
                            mode: mode,
                            isInSession: store.todaySession.modeIDs.contains(mode.id),
                            isDoneInSession: store.todaySession.completedModeIDs.contains(mode.id),
                            bestScore: store.bestScore(for: mode.id)
                        ) {
                            store.selectedMode = mode
                        }
                    }
                }

                Spacer(minLength: 120)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
        }
    }
}

private struct SessionsView: View {
    @ObservedObject var store: ClubStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(title: "Sessions", subtitle: "Your midnight timeline")

                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Session Timeline")
                            .font(.custom("AvenirNext-DemiBold", size: 22))
                            .foregroundStyle(.white)
                        Text("\(store.sessions.count) sessions tracked")
                            .font(.custom("AvenirNext-Regular", size: 14))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }

                if store.sessions.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("No sessions yet")
                                .font(.custom("AvenirNext-DemiBold", size: 20))
                                .foregroundStyle(.white)
                            Text("Complete your first Lucky Session and your timeline will appear here.")
                                .font(.custom("AvenirNext-Regular", size: 14))
                                .foregroundStyle(Theme.secondaryText)
                            NeonButton(title: "Start Tonight's Session") {
                                store.selectedTab = .club
                            }
                            .padding(.top, 6)
                        }
                    }
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(store.sessions) { session in
                            SessionCard(session: session)
                        }
                    }
                }

                Spacer(minLength: 120)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
        }
    }
}

private struct CharmsView: View {
    @ObservedObject var store: ClubStore

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(title: "Charms", subtitle: "Collect midnight symbols")

                GlassCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Charm Collection")
                                .font(.custom("AvenirNext-DemiBold", size: 22))
                                .foregroundStyle(.white)
                            Text("\(store.unlockedCharmCount) / \(store.charms.count) unlocked")
                                .font(.custom("AvenirNext-Regular", size: 14))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "sparkles")
                            .font(.system(size: 25, weight: .semibold))
                            .foregroundStyle(Theme.neonCyan)
                    }
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(store.charms) { charm in
                        CharmCard(charm: charm)
                    }
                }

                Spacer(minLength: 120)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
        }
    }
}

private struct VaultView: View {
    @ObservedObject var store: ClubStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(title: "Vault", subtitle: "Club rewards and streaks")

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Club Balance")
                            .font(.custom("AvenirNext-DemiBold", size: 20))
                            .foregroundStyle(.white)
                        Text("\(store.clubPoints.formatted(.number.grouping(.automatic))) Lucky Stars")
                            .font(.custom("AvenirNext-Bold", size: 28))
                            .foregroundStyle(Theme.champagne)
                        Text("Return every night to keep your streak alive.")
                            .font(.custom("AvenirNext-Regular", size: 14))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Daily Ladder")
                            .font(.custom("AvenirNext-DemiBold", size: 20))
                            .foregroundStyle(.white)
                        Text("Return every night to raise your streak")
                            .font(.custom("AvenirNext-Regular", size: 14))
                            .foregroundStyle(Theme.secondaryText)

                        VStack(spacing: 8) {
                            ForEach(store.dailyLadder) { item in
                                HStack {
                                    Text("Night \(item.night)")
                                        .font(.custom("AvenirNext-Medium", size: 14))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text("+\(item.reward)")
                                        .font(.custom("AvenirNext-DemiBold", size: 15))
                                        .foregroundStyle(Theme.neonCyan)
                                }
                                .padding(.vertical, 2)
                                .opacity(item.night == store.currentLadderNight ? 1 : 0.76)
                            }
                        }

                        GoldButton(title: store.didClaimDailyRewardToday ? "Claimed Tonight" : "Claim Night \(store.currentLadderNight)") {
                            if !store.claimDailyReward() {
                                store.presentBanner("Daily ladder already claimed tonight.", style: .warning)
                            }
                        }
                        .opacity(store.didClaimDailyRewardToday ? 0.65 : 1)
                        .disabled(store.didClaimDailyRewardToday)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Focus Boost")
                            .font(.custom("AvenirNext-DemiBold", size: 20))
                            .foregroundStyle(.white)
                        Text(store.didClaimFocusBoostToday ? "Boost claimed tonight" : "Ready to claim")
                            .font(.custom("AvenirNext-Regular", size: 14))
                            .foregroundStyle(Theme.secondaryText)
                        NeonButton(title: store.didClaimFocusBoostToday ? "Boost Claimed" : "Claim Boost") {
                            if !store.claimFocusBoost() {
                                store.presentBanner("Focus boost already claimed tonight.", style: .warning)
                            }
                        }
                        .opacity(store.didClaimFocusBoostToday ? 0.65 : 1)
                        .disabled(store.didClaimFocusBoostToday)
                    }
                }

                Spacer(minLength: 120)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
        }
    }
}

private struct GameDetailView: View {
    let mode: GameMode
    @ObservedObject var store: ClubStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            MidnightGradientBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mode.name)
                                .font(.custom("AvenirNext-Bold", size: 30))
                                .foregroundStyle(.white)
                            Text("Private Trial")
                                .font(.custom("AvenirNext-Regular", size: 14))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .frame(width: 32, height: 32)
                                .foregroundStyle(.white)
                                .background(Color.white.opacity(0.1), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(mode.description)
                                .font(.custom("AvenirNext-DemiBold", size: 19))
                                .foregroundStyle(.white)
                            Text(mode.detail)
                                .font(.custom("AvenirNext-Regular", size: 14))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }

                    HStack(spacing: 10) {
                        StatTile(title: "Best", value: store.bestScore(for: mode.id) > 0 ? "\(store.bestScore(for: mode.id))" : "-")
                        StatTile(title: "Reward", value: "+\(mode.reward)")
                        StatTile(title: "Difficulty", value: mode.difficulty)
                    }

                    NeonButton(title: "Enter Trial") {
                        dismiss()
                        store.startTrial(mode: mode)
                    }

                    GhostButton(title: "Practice") {
                        dismiss()
                        store.startTrial(mode: mode, isPractice: true)
                    }

                    Text("Skill-based challenge. No bets. No real-money rewards.")
                        .font(.custom("AvenirNext-Medium", size: 13))
                        .foregroundStyle(Theme.mutedText)
                        .padding(.top, 2)
                }
                .padding(20)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Trial Container

private struct TrialContainerView: View {
    let mode: GameMode
    @ObservedObject var store: ClubStore
    @Environment(\.dismiss) private var dismiss

    @State private var result: TrialResult?

    var body: some View {
        ZStack {
            MidnightGradientBackground()

            if let result {
                TrialResultView(mode: mode, result: result, isPractice: store.activeTrialIsPractice) {
                    store.finishTrial(mode: mode, result: result)
                    dismiss()
                } playAgain: {
                    self.result = nil
                } backToClub: {
                    dismiss()
                }
                .padding(.horizontal, 18)
            } else {
                TrialGameHostView(mode: mode) { finishedResult in
                    result = finishedResult
                } onClose: {
                    dismiss()
                }
            }
        }
        .interactiveDismissDisabled()
    }
}

private struct TrialGameHostView: View {
    let mode: GameMode
    let onComplete: (TrialResult) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(mode.name)
                    .font(.custom("AvenirNext-DemiBold", size: 18))
                    .foregroundStyle(.white)

                Spacer()

                Circle()
                    .fill(Theme.neonCyan.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.neonCyan)
                    )
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)

            switch mode.id {
            case "neon-reflex":
                NeonReflexTrialView(onComplete: onComplete)
            case "clover-shift":
                CloverShiftTrialView(onComplete: onComplete)
            case "ace-memory":
                AceMemoryTrialView(onComplete: onComplete)
            case "signal-rush":
                SignalRushTrialView(onComplete: onComplete)
            case "chip-stack":
                ChipStackTrialView(onComplete: onComplete)
            case "lucky-odd":
                LuckyOddTrialView(onComplete: onComplete)
            case "moonline-timing":
                MoonlineTimingTrialView(onComplete: onComplete)
            case "crown-pulse":
                CrownPulseTrialView(onComplete: onComplete)
            default:
                Text("Mode unavailable")
                    .foregroundStyle(.white)
            }
        }
        .padding(.bottom, 20)
    }
}

private struct TrialResultView: View {
    let mode: GameMode
    let result: TrialResult
    let isPractice: Bool
    let claim: () -> Void
    let playAgain: () -> Void
    let backToClub: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 20)

            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Trial Complete")
                        .font(.custom("AvenirNext-Bold", size: 30))
                        .foregroundStyle(.white)

                    HStack(spacing: 12) {
                        ResultMetric(title: "Score", value: "\(result.score)")
                        ResultMetric(title: "Accuracy", value: "\(result.accuracy)%")
                        ResultMetric(title: "Focus", value: "\(result.focus)%")
                    }

                    HStack(spacing: 12) {
                        ResultMetric(title: "Reflex", value: "\(result.reflex)%")
                        ResultMetric(title: "Memory", value: "\(result.memory)%")
                        ResultMetric(title: "Reward", value: isPractice ? "+0" : "+\(mode.reward)")
                    }
                }
            }

            if !isPractice {
                NeonButton(title: "Claim Reward") {
                    claim()
                }
            }

            GhostButton(title: "Play Again") {
                playAgain()
            }

            GhostButton(title: "Back to Club") {
                backToClub()
            }

            Spacer(minLength: 20)
        }
    }
}

// MARK: - Trials

private struct NeonReflexTrialView: View {
    let onComplete: (TrialResult) -> Void

    @State private var round = 1
    @State private var score = 0
    @State private var hits = 0
    @State private var mistakes = 0
    @State private var state: ReflexState = .waiting
    @State private var flashTime = Date()
    @State private var hint = "Wait for the real flash"
    @State private var taskToken = UUID()

    private let totalRounds = 5

    enum ReflexState {
        case waiting
        case realFlash
        case fakeFlash
    }

    var body: some View {
        VStack(spacing: 18) {
            TrialHeader(round: round, total: totalRounds, score: score)

            Spacer(minLength: 12)

            Button {
                tappedCenter()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 236, height: 236)
                    Circle()
                        .stroke(strokeColor, lineWidth: 6)
                        .frame(width: 220, height: 220)
                        .shadow(color: strokeColor.opacity(0.55), radius: 16)
                    Text(centerTitle)
                        .font(.custom("AvenirNext-DemiBold", size: 24))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)

            Text(hint)
                .font(.custom("AvenirNext-Medium", size: 15))
                .foregroundStyle(Theme.secondaryText)

            Spacer()
        }
        .padding(.horizontal, 18)
        .onAppear { scheduleRound() }
    }

    private var strokeColor: Color {
        switch state {
        case .waiting: return Color.white.opacity(0.25)
        case .realFlash: return Theme.neonCyan
        case .fakeFlash: return Theme.neonPink
        }
    }

    private var centerTitle: String {
        switch state {
        case .waiting: return "Hold"
        case .realFlash: return "Tap"
        case .fakeFlash: return "Fake"
        }
    }

    private func tappedCenter() {
        switch state {
        case .waiting:
            mistakes += 1
            score = max(0, score - 24)
            hint = "Too Early"
            Haptics.warning()
        case .fakeFlash:
            mistakes += 1
            score = max(0, score - 30)
            hint = "False Tap"
            Haptics.warning()
            advanceRound()
        case .realFlash:
            let reactionMS = Int(Date().timeIntervalSince(flashTime) * 1000)
            hits += 1
            let gain = max(70, 180 - min(reactionMS, 500) / 3)
            score += gain
            hint = "Perfect +\(gain)"
            Haptics.success()
            advanceRound()
        }
    }

    private func scheduleRound() {
        state = .waiting
        hint = "Wait for the real flash"
        let token = UUID()
        taskToken = token

        let delay = Double.random(in: 0.8...1.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard token == taskToken else { return }
            let fake = Bool.random() && Bool.random()
            if fake {
                state = .fakeFlash
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    guard token == taskToken else { return }
                    if state == .fakeFlash {
                        hint = "Good Discipline"
                        advanceRound()
                    }
                }
            } else {
                state = .realFlash
                flashTime = Date()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                    guard token == taskToken else { return }
                    if state == .realFlash {
                        mistakes += 1
                        score = max(0, score - 20)
                        hint = "Missed Signal"
                        Haptics.warning()
                        advanceRound()
                    }
                }
            }
        }
    }

    private func advanceRound() {
        if round >= totalRounds {
            finish()
        } else {
            round += 1
            scheduleRound()
        }
    }

    private func finish() {
        let totalAttempts = max(1, hits + mistakes)
        let accuracy = Int(Double(hits) / Double(totalAttempts) * 100)
        let result = TrialResult(
            score: score,
            accuracy: accuracy,
            reflex: min(100, accuracy + 10),
            memory: 58,
            focus: max(60, accuracy)
        )
        onComplete(result)
    }
}

private struct CloverShiftTrialView: View {
    let onComplete: (TrialResult) -> Void

    @State private var round = 1
    @State private var score = 0
    @State private var hits = 0
    @State private var mistakes = 0
    @State private var options: [CloverOption] = []
    @State private var targetIndex = 0

    private let totalRounds = 6

    var body: some View {
        VStack(spacing: 16) {
            TrialHeader(round: round, total: totalRounds, score: score)

            Spacer(minLength: 8)

            Text("Find the mismatch")
                .font(.custom("AvenirNext-DemiBold", size: 22))
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, item in
                    Button {
                        tap(index: index)
                    } label: {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.09))
                            .frame(height: 110)
                            .overlay(
                                Image(systemName: item.symbol)
                                    .font(.system(size: 38, weight: .semibold))
                                    .foregroundStyle(item.color)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)

            Spacer()
        }
        .padding(.horizontal, 18)
        .onAppear { generateRound() }
    }

    private func tap(index: Int) {
        if index == targetIndex {
            hits += 1
            score += 120
            Haptics.success()
        } else {
            mistakes += 1
            score = max(0, score - 25)
            Haptics.warning()
        }

        if round >= totalRounds {
            finish()
        } else {
            round += 1
            generateRound()
        }
    }

    private func generateRound() {
        let palette: [Color] = [Theme.neonCyan, Theme.neonViolet, Theme.neonPink, Theme.champagne]
        let symbols = ["seal.fill", "star.fill", "moon.fill", "suit.club.fill"]
        let baseColor = palette.randomElement() ?? Theme.neonCyan
        let oddColor = palette.filter { $0 != baseColor }.randomElement() ?? Theme.neonPink
        let symbol = symbols.randomElement() ?? "seal.fill"

        var generated = Array(repeating: CloverOption(symbol: symbol, color: baseColor), count: 4)
        targetIndex = Int.random(in: 0..<4)
        generated[targetIndex] = CloverOption(symbol: symbol, color: oddColor)
        options = generated
    }

    private func finish() {
        let accuracy = Int(Double(hits) / Double(max(1, hits + mistakes)) * 100)
        onComplete(
            TrialResult(
                score: score,
                accuracy: accuracy,
                reflex: max(45, accuracy - 10),
                memory: max(65, accuracy),
                focus: min(100, accuracy + 8)
            )
        )
    }
}

private struct AceMemoryTrialView: View {
    let onComplete: (TrialResult) -> Void

    @State private var sequence: [String] = []
    @State private var input: [String] = []
    @State private var highlightingIndex: Int?
    @State private var canInput = false
    @State private var round = 1
    @State private var score = 0
    @State private var successes = 0

    private let symbols = ["star.fill", "moon.fill", "crown.fill", "seal.fill", "diamond.fill"]
    private let totalRounds = 3

    var body: some View {
        VStack(spacing: 16) {
            TrialHeader(round: round, total: totalRounds, score: score)

            Spacer(minLength: 8)

            Text(canInput ? "Repeat the order" : "Watch the sequence")
                .font(.custom("AvenirNext-DemiBold", size: 22))
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                ForEach(Array(sequence.enumerated()), id: \.offset) { index, symbol in
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(highlightingIndex == index ? Theme.neonCyan.opacity(0.6) : Color.white.opacity(0.08))
                        .frame(width: 52, height: 52)
                        .overlay(
                            Image(systemName: symbol)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                        )
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(symbols, id: \.self) { symbol in
                    Button {
                        guard canInput else { return }
                        inputTap(symbol)
                    } label: {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 72)
                            .overlay(
                                Image(systemName: symbol)
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(.white)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .onAppear { newRound() }
    }

    private func newRound() {
        canInput = false
        input = []
        sequence = Array((0..<(round + 2)).map { _ in symbols.randomElement() ?? "star.fill" })
        showSequence(index: 0)
    }

    private func showSequence(index: Int) {
        if index >= sequence.count {
            highlightingIndex = nil
            canInput = true
            return
        }

        highlightingIndex = index
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) {
            highlightingIndex = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                showSequence(index: index + 1)
            }
        }
    }

    private func inputTap(_ symbol: String) {
        input.append(symbol)
        let expected = sequence[input.count - 1]
        if symbol != expected {
            score = max(0, score - 35)
            Haptics.warning()
            advance(correct: false)
            return
        }

        if input.count == sequence.count {
            let gain = 120 + round * 20
            score += gain
            successes += 1
            Haptics.success()
            advance(correct: true)
        }
    }

    private func advance(correct: Bool) {
        canInput = false
        if round >= totalRounds {
            finish()
        } else {
            round += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                newRound()
            }
        }
    }

    private func finish() {
        let accuracy = Int(Double(successes) / Double(totalRounds) * 100)
        onComplete(
            TrialResult(
                score: score,
                accuracy: max(20, accuracy),
                reflex: max(45, accuracy - 15),
                memory: min(100, accuracy + 20),
                focus: min(100, accuracy + 8)
            )
        )
    }
}

private struct SignalRushTrialView: View {
    let onComplete: (TrialResult) -> Void

    @State private var round = 1
    @State private var score = 0
    @State private var hits = 0
    @State private var mistakes = 0
    @State private var options: [SignalOption] = []
    @State private var target = 0

    private let totalRounds = 6

    var body: some View {
        VStack(spacing: 16) {
            TrialHeader(round: round, total: totalRounds, score: score)

            Spacer(minLength: 8)

            Text("True signal only")
                .font(.custom("AvenirNext-DemiBold", size: 22))
                .foregroundStyle(.white)
            Text("Tap the cyan-gold pulse")
                .font(.custom("AvenirNext-Regular", size: 14))
                .foregroundStyle(Theme.secondaryText)

            VStack(spacing: 12) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, item in
                    Button {
                        tap(index)
                    } label: {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(item.gradient)
                            .frame(height: 74)
                            .overlay(
                                HStack {
                                    Text(item.title)
                                        .font(.custom("AvenirNext-DemiBold", size: 17))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Image(systemName: "waveform.path.ecg")
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                                .padding(.horizontal, 14)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .onAppear { generate() }
    }

    private func tap(_ index: Int) {
        if index == target {
            hits += 1
            score += 110
            Haptics.success()
        } else {
            mistakes += 1
            score = max(0, score - 26)
            Haptics.warning()
        }

        if round >= totalRounds {
            finish()
        } else {
            round += 1
            generate()
        }
    }

    private func generate() {
        var generated = [
            SignalOption(title: "Decoy Violet", gradient: LinearGradient(colors: [Theme.neonViolet.opacity(0.65), Color.black.opacity(0.5)], startPoint: .leading, endPoint: .trailing)),
            SignalOption(title: "Decoy Pink", gradient: LinearGradient(colors: [Theme.neonPink.opacity(0.65), Color.black.opacity(0.5)], startPoint: .leading, endPoint: .trailing)),
            SignalOption(title: "Decoy Shadow", gradient: LinearGradient(colors: [Color.gray.opacity(0.5), Color.black.opacity(0.55)], startPoint: .leading, endPoint: .trailing)),
            SignalOption(title: "True Signal", gradient: LinearGradient(colors: [Theme.neonCyan.opacity(0.8), Theme.champagne.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
        ]
        generated.shuffle()
        options = generated
        target = generated.firstIndex(where: { $0.title == "True Signal" }) ?? 0
    }

    private func finish() {
        let accuracy = Int(Double(hits) / Double(max(1, hits + mistakes)) * 100)
        onComplete(
            TrialResult(
                score: score,
                accuracy: accuracy,
                reflex: min(100, accuracy + 8),
                memory: 60,
                focus: min(100, accuracy + 14)
            )
        )
    }
}

private struct ChipStackTrialView: View {
    let onComplete: (TrialResult) -> Void

    @State private var round = 1
    @State private var score = 0
    @State private var items: [Int] = []
    @State private var expectedIndex = 0
    @State private var mistakes = 0

    private let totalRounds = 4

    var body: some View {
        VStack(spacing: 16) {
            TrialHeader(round: round, total: totalRounds, score: score)

            Spacer(minLength: 8)

            Text("Stack in ascending order")
                .font(.custom("AvenirNext-DemiBold", size: 22))
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                ForEach(items, id: \.self) { value in
                    Button {
                        tap(value)
                    } label: {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 74, height: 74)
                            .overlay(
                                Text("\(value)")
                                    .font(.custom("AvenirNext-Bold", size: 28))
                                    .foregroundStyle(.white)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Pick: \(sortedItems[safe: expectedIndex] ?? 0)")
                .font(.custom("AvenirNext-Medium", size: 14))
                .foregroundStyle(Theme.secondaryText)

            Spacer()
        }
        .padding(.horizontal, 18)
        .onAppear { generateRound() }
    }

    private var sortedItems: [Int] {
        items.sorted()
    }

    private func tap(_ value: Int) {
        let expected = sortedItems[safe: expectedIndex] ?? 0
        if value == expected {
            expectedIndex += 1
            score += 90
            Haptics.light()
            if expectedIndex >= items.count {
                Haptics.success()
                if round >= totalRounds {
                    finish()
                } else {
                    round += 1
                    generateRound()
                }
            }
        } else {
            mistakes += 1
            score = max(0, score - 20)
            expectedIndex = 0
            Haptics.warning()
        }
    }

    private func generateRound() {
        expectedIndex = 0
        var set = Set<Int>()
        while set.count < 4 {
            set.insert(Int.random(in: 1...12))
        }
        items = Array(set).shuffled()
    }

    private func finish() {
        let maxMistakes = totalRounds * 2
        let accuracy = max(35, 100 - Int(Double(min(mistakes, maxMistakes)) / Double(maxMistakes) * 100))
        onComplete(
            TrialResult(
                score: score,
                accuracy: accuracy,
                reflex: max(55, accuracy - 5),
                memory: max(65, accuracy),
                focus: max(60, accuracy)
            )
        )
    }
}

private struct LuckyOddTrialView: View {
    let onComplete: (TrialResult) -> Void

    @State private var round = 1
    @State private var score = 0
    @State private var oddIndex = 0
    @State private var totalCells = 30
    @State private var mistakes = 0

    private let totalRounds = 4

    var body: some View {
        VStack(spacing: 14) {
            TrialHeader(round: round, total: totalRounds, score: score)

            Text("Find the rare mark")
                .font(.custom("AvenirNext-DemiBold", size: 22))
                .foregroundStyle(.white)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<totalCells, id: \.self) { idx in
                    Button {
                        tapCell(idx)
                    } label: {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.07))
                            .frame(height: 36)
                            .overlay(
                                Circle()
                                    .fill(idx == oddIndex ? Theme.neonCyan : Theme.neonViolet)
                                    .frame(width: idx == oddIndex ? 12 : 10, height: idx == oddIndex ? 12 : 10)
                                    .opacity(idx == oddIndex ? 1 : 0.8)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 18)
        .onAppear { newRound() }
    }

    private func tapCell(_ index: Int) {
        if index == oddIndex {
            score += 140
            Haptics.success()
            if round >= totalRounds {
                finish()
            } else {
                round += 1
                newRound()
            }
        } else {
            mistakes += 1
            score = max(0, score - 24)
            Haptics.warning()
        }
    }

    private func newRound() {
        totalCells = Int.random(in: 30...42)
        oddIndex = Int.random(in: 0..<totalCells)
    }

    private func finish() {
        let accuracy = max(30, 100 - mistakes * 12)
        onComplete(
            TrialResult(
                score: score,
                accuracy: min(100, accuracy),
                reflex: min(100, accuracy + 4),
                memory: max(50, accuracy - 4),
                focus: min(100, accuracy + 6)
            )
        )
    }
}

private struct MoonlineTimingTrialView: View {
    let onComplete: (TrialResult) -> Void

    @State private var round = 1
    @State private var score = 0
    @State private var markerPosition: CGFloat = .random(in: 0.0...1.0)

    private let totalRounds = 5

    var body: some View {
        VStack(spacing: 18) {
            TrialHeader(round: round, total: totalRounds, score: score)

            Text("Stop inside the gold zone")
                .font(.custom("AvenirNext-DemiBold", size: 22))
                .foregroundStyle(.white)

            GeometryReader { geo in
                let width = geo.size.width - 24
                let zoneStart = width * 0.44
                let zoneWidth = width * 0.12

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 18)

                    Capsule()
                        .fill(Theme.champagne.opacity(0.7))
                        .frame(width: zoneWidth, height: 18)
                        .offset(x: zoneStart)

                    Circle()
                        .fill(Theme.neonCyan)
                        .frame(width: 24, height: 24)
                        .offset(x: max(0, min(width, markerPosition * width)))
                }
                .padding(.horizontal, 12)
                .frame(height: 46)

                VStack {
                    Spacer()
                    NeonButton(title: "Stop") {
                        let position = markerPosition * width
                        let center = zoneStart + zoneWidth / 2
                        let distance = abs(position - center)
                        let gain = max(20, 180 - Int(distance * 2.2))
                        score += gain
                        Haptics.light()
                        advance()
                    }
                    .padding(.horizontal, 12)
                }
            }

            Spacer(minLength: 10)
        }
        .padding(.horizontal, 18)
    }

    private func advance() {
        if round >= totalRounds {
            finish()
        } else {
            round += 1
            markerPosition = .random(in: 0.0...1.0)
        }
    }

    private func finish() {
        let accuracy = min(100, max(30, score / 8))
        onComplete(
            TrialResult(
                score: score,
                accuracy: accuracy,
                reflex: accuracy,
                memory: max(45, accuracy - 15),
                focus: min(100, accuracy + 8)
            )
        )
    }
}

private struct CrownPulseTrialView: View {
    let onComplete: (TrialResult) -> Void

    @State private var score = 0
    @State private var taps = 0
    @State private var good = 0
    @State private var lastTapDate = Date()

    private let totalTaps = 10
    private let beat: Double = 0.85

    var body: some View {
        VStack(spacing: 20) {
            TrialHeader(round: min(taps + 1, totalTaps), total: totalTaps, score: score)

            Text("Tap with the pulse")
                .font(.custom("AvenirNext-DemiBold", size: 22))
                .foregroundStyle(.white)

            Circle()
                .fill(Theme.neonPink.opacity(0.28))
                .frame(width: 220, height: 220)
                .overlay(
                    Circle()
                        .stroke(Theme.neonPink, lineWidth: 5)
                )
                .overlay(
                    Text("Pulse")
                        .font(.custom("AvenirNext-Bold", size: 27))
                        .foregroundStyle(.white)
                )

            NeonButton(title: "Tap") {
                registerTap(now: Date())
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.horizontal, 18)
        .onAppear { lastTapDate = Date() }
    }

    private func registerTap(now: Date) {
        let delta = now.timeIntervalSince(lastTapDate)
        lastTapDate = now
        let distance = abs(delta - beat)
        let normalized = min(1.0, distance / beat)
        let gain = max(20, 130 - Int(normalized * 120))
        if normalized < 0.35 {
            good += 1
            Haptics.success()
        } else {
            Haptics.light()
        }
        score += gain
        taps += 1

        if taps >= totalTaps {
            finish()
        }
    }

    private func finish() {
        let accuracy = Int(Double(good) / Double(max(1, taps)) * 100)
        onComplete(
            TrialResult(
                score: score,
                accuracy: max(30, accuracy),
                reflex: max(55, accuracy),
                memory: 52,
                focus: min(100, accuracy + 12)
            )
        )
    }
}

// MARK: - Onboarding & Loading

private struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private let pages = [
        OnboardingPage(
            title: "Welcome to Midnight Lucky Club",
            subtitle: "A private arcade club for reflex, memory and focus.",
            icon: "moon.stars.fill",
            buttonTitle: "Enter the Club"
        ),
        OnboardingPage(
            title: "Daily Lucky Sessions",
            subtitle: "Complete quick trials every night and build your streak.",
            icon: "sparkles",
            buttonTitle: "Continue"
        ),
        OnboardingPage(
            title: "Collect Lucky Charms",
            subtitle: "Unlock rare club symbols through skill-based play.",
            icon: "crown.fill",
            buttonTitle: "Start Tonight"
        )
    ]

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 20)

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    OnboardingPageView(page: item)
                        .tag(index)
                        .padding(.horizontal, 20)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Theme.neonCyan : Color.white.opacity(0.2))
                        .frame(width: index == page ? 26 : 8, height: 8)
                }
            }

            NeonButton(title: pages[page].buttonTitle) {
                if page < pages.count - 1 {
                    page += 1
                } else {
                    onFinish()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Theme.neonViolet.opacity(0.45), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 120
                            )
                        )
                        .frame(width: 140, height: 140)
                    Image(systemName: page.icon)
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(Theme.neonCyan)
                }

                Text(page.title)
                    .font(.custom("AvenirNext-Bold", size: 31))
                    .foregroundStyle(.white)

                Text(page.subtitle)
                    .font(.custom("AvenirNext-Regular", size: 16))
                    .foregroundStyle(Theme.secondaryText)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 350, alignment: .top)
        }
    }
}

struct ClubLoadingView: View {
    @State private var progress = 0.0

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.14), lineWidth: 2)
                    .frame(width: 130, height: 130)

                Circle()
                    .trim(from: 0, to: max(progress, 0.04))
                    .stroke(
                        AngularGradient(
                            colors: [Theme.neonViolet, Theme.neonCyan, Theme.neonPink, Theme.neonViolet],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 130, height: 130)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Theme.champagne)
            }
            Text("Midnight Lucky Club")
                .font(.custom("AvenirNext-Bold", size: 31))
                .foregroundStyle(.white)

            Text("Preparing Tonight's Session")
                .font(.custom("AvenirNext-Regular", size: 15))
                .foregroundStyle(Theme.secondaryText)

            Capsule()
                .fill(Color.white.opacity(0.12))
                .frame(width: 220, height: 8)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.neonViolet, Theme.neonCyan], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 220 * progress, height: 8)
                }

            Spacer()
        }
        .onAppear {
            progress = 1
        }
    }
}

// MARK: - Components

private struct ClubHeader: View {
    let points: Int

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Midnight Lucky")
                    .font(.custom("AvenirNext-Bold", size: 32))
                    .foregroundStyle(.white)
                Text("Private Club Arcade")
                    .font(.custom("AvenirNext-Regular", size: 14))
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(points.formatted(.number.grouping(.automatic)))
                    .font(.custom("AvenirNext-Bold", size: 16))
                    .foregroundStyle(.white)
                Text("Lucky Stars")
                    .font(.custom("AvenirNext-Medium", size: 11))
                    .foregroundStyle(Theme.mutedText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(Theme.neonCyan.opacity(0.4), lineWidth: 1))
        }
    }
}

private struct ScreenHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("AvenirNext-Bold", size: 32))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.custom("AvenirNext-Regular", size: 14))
                .foregroundStyle(Theme.secondaryText)
        }
    }
}

private struct LuckySessionHeroCard: View {
    let completed: Int
    let total: Int
    let action: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tonight's Lucky Session")
                            .font(.custom("AvenirNext-Bold", size: 24))
                            .foregroundStyle(.white)
                        Text("Complete \(total) quick trials before midnight. Build your streak and unlock a new charm.")
                            .font(.custom("AvenirNext-Regular", size: 14))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(Theme.champagne)
                }

                HStack {
                    Text("\(completed)/\(total) completed")
                        .font(.custom("AvenirNext-Medium", size: 13))
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text(completed == total ? "Session Complete" : "Private Trial Ready")
                        .font(.custom("AvenirNext-Medium", size: 12))
                        .foregroundStyle(completed == total ? Theme.luckyGreen : Theme.neonCyan)
                }

                ProgressBar(value: Double(completed) / Double(max(total, 1)), tint: Theme.neonCyan)

                NeonButton(title: completed == total ? "Keep the Streak Alive" : "Start Session") {
                    action()
                }
            }
        }
    }
}

private struct StatusMiniCard: View {
    let title: String
    let value: String

    var body: some View {
        GlassCard(cornerRadius: 20, padding: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.custom("AvenirNext-Medium", size: 12))
                    .foregroundStyle(Theme.mutedText)
                Text(value)
                    .font(.custom("AvenirNext-DemiBold", size: 16))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct GameModeCard: View {
    let mode: GameMode
    let isInSession: Bool
    let isDoneInSession: Bool
    let bestScore: Int
    let action: () -> Void

    var body: some View {
        GlassCard(cornerRadius: 24, padding: 14) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(mode.name)
                            .font(.custom("AvenirNext-DemiBold", size: 20))
                            .foregroundStyle(.white)
                        if isInSession {
                            Text(isDoneInSession ? "Done" : "Tonight")
                                .font(.custom("AvenirNext-Medium", size: 10))
                                .foregroundStyle(isDoneInSession ? Theme.luckyGreen : Theme.neonCyan)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.08), in: Capsule())
                        }
                    }

                    Text(mode.description)
                        .font(.custom("AvenirNext-Regular", size: 14))
                        .foregroundStyle(Theme.secondaryText)

                    HStack(spacing: 6) {
                        ForEach(mode.tags, id: \.self) { tag in
                            TagChip(text: tag)
                        }
                    }

                    Text("Best: \(bestScore > 0 ? "\(bestScore)" : "-")   Reward: +\(mode.reward)")
                        .font(.custom("AvenirNext-Medium", size: 13))
                        .foregroundStyle(Theme.mutedText)
                }

                Spacer(minLength: 8)

                Button(action: action) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(colors: [Theme.neonViolet, Theme.neonCyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: Circle()
                        )
                        .shadow(color: Theme.neonViolet.opacity(0.5), radius: 12, y: 6)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SessionCard: View {
    let session: SessionEntry

    var body: some View {
        GlassCard(cornerRadius: 24, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Midnight Session")
                            .font(.custom("AvenirNext-DemiBold", size: 19))
                            .foregroundStyle(.white)
                        Text(session.dateText)
                            .font(.custom("AvenirNext-Regular", size: 13))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Spacer()
                    Text("+\(session.reward)")
                        .font(.custom("AvenirNext-Bold", size: 18))
                        .foregroundStyle(Theme.champagne)
                }

                HStack {
                    SessionStat(title: "Trials", value: "\(session.trialsCompleted)/\(session.trialsTotal)")
                    SessionStat(title: "Best", value: session.bestTrial)
                    SessionStat(title: "Score", value: "\(session.totalScore)")
                }

                ScoreBars(reflex: session.reflex, memory: session.memory, focus: session.focus)
            }
        }
    }
}

private struct ScoreBars: View {
    let reflex: Int
    let memory: Int
    let focus: Int

    var body: some View {
        VStack(spacing: 8) {
            ProgressLine(title: "Reflex", value: reflex, tint: Theme.neonCyan)
            ProgressLine(title: "Memory", value: memory, tint: Theme.neonViolet)
            ProgressLine(title: "Focus", value: focus, tint: Theme.neonPink)
        }
    }
}

private struct ProgressLine: View {
    let title: String
    let value: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.custom("AvenirNext-Medium", size: 12))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 52, alignment: .leading)

            ProgressBar(value: Double(value) / 100, tint: tint)

            Text("\(value)%")
                .font(.custom("AvenirNext-Medium", size: 12))
                .foregroundStyle(Theme.mutedText)
                .frame(width: 38, alignment: .trailing)
        }
        .frame(height: 16)
    }
}

private struct ProgressBar: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width * CGFloat(max(0, min(value, 1)))
            Capsule()
                .fill(Color.white.opacity(0.1))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(tint)
                        .frame(width: width)
                }
        }
        .frame(height: 8)
    }
}

private struct SessionStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("AvenirNext-Medium", size: 11))
                .foregroundStyle(Theme.mutedText)
            Text(value)
                .font(.custom("AvenirNext-DemiBold", size: 13))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CharmCard: View {
    let charm: CharmDisplay

    var body: some View {
        GlassCard(cornerRadius: 22, padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: charm.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(charm.unlocked ? Theme.neonCyan : Theme.mutedText)
                    Spacer()
                    Text(charm.rarity.rawValue)
                        .font(.custom("AvenirNext-Medium", size: 10))
                        .foregroundStyle(charm.rarity.color)
                }

                Text(charm.unlocked ? charm.name : "Locked Charm")
                    .font(.custom("AvenirNext-DemiBold", size: 15))
                    .foregroundStyle(.white)

                Text(charm.unlocked ? charm.unlockRule : "Complete more sessions to reveal")
                    .font(.custom("AvenirNext-Regular", size: 12))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(3)
            }
            .opacity(charm.unlocked ? 1 : 0.82)
            .blur(radius: charm.unlocked ? 0 : 0.35)
            .frame(height: 132, alignment: .top)
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        GlassCard(cornerRadius: 18, padding: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.custom("AvenirNext-Medium", size: 11))
                    .foregroundStyle(Theme.mutedText)
                Text(value)
                    .font(.custom("AvenirNext-DemiBold", size: 14))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct TrialHeader: View {
    let round: Int
    let total: Int
    let score: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Round \(round)/\(total)")
                    .font(.custom("AvenirNext-DemiBold", size: 18))
                    .foregroundStyle(.white)
                Text("Stay sharp")
                    .font(.custom("AvenirNext-Regular", size: 12))
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Text("Score \(score)")
                .font(.custom("AvenirNext-DemiBold", size: 18))
                .foregroundStyle(Theme.neonCyan)
        }
    }
}

private struct ResultMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("AvenirNext-Medium", size: 11))
                .foregroundStyle(Theme.mutedText)
            Text(value)
                .font(.custom("AvenirNext-Bold", size: 16))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TagChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.custom("AvenirNext-Medium", size: 11))
            .foregroundStyle(Theme.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.07), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

private struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 28
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.cardBase)
            )
    }
}

private struct NeonButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("AvenirNext-DemiBold", size: 17))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .background(
                    LinearGradient(colors: [Theme.neonViolet, Theme.neonCyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct GoldButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("AvenirNext-DemiBold", size: 17))
                .foregroundStyle(Color(hex: "#1A1305"))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    LinearGradient(colors: [Color(hex: "#F6C96D"), Color(hex: "#DDA94D")], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct GhostButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("AvenirNext-DemiBold", size: 16))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.11), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct CustomClubTabBar: View {
    @Binding var selectedTab: ClubTab

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ClubTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: .semibold))
                        Text(tab.title)
                            .font(.custom("AvenirNext-Medium", size: 11))
                    }
                    .foregroundStyle(selectedTab == tab ? .white : Theme.mutedText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(selectedTab == tab ? Theme.tabSelected : Theme.tabIdle)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(selectedTab == tab ? Theme.neonCyan.opacity(0.4) : Color.white.opacity(0.07), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.24))
        )
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}

private struct BannerView: View {
    let message: String
    let style: BannerStyle

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: style.icon)
                .foregroundStyle(style.color)
            Text(message)
                .font(.custom("AvenirNext-Medium", size: 14))
                .foregroundStyle(.white)
                .lineLimit(2)
            Spacer(minLength: 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(style.color.opacity(0.45), lineWidth: 1)
        )
    }
}

struct MidnightGradientBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.bgBlack, Theme.bgNavy, Theme.bgViolet], startPoint: .topLeading, endPoint: .bottomTrailing)

            Circle()
                .fill(Theme.neonViolet.opacity(0.14))
                .frame(width: 280, height: 280)
                .offset(x: -90, y: -170)

            Circle()
                .fill(Theme.neonCyan.opacity(0.12))
                .frame(width: 300, height: 300)
                .offset(x: 110, y: 20)

            Circle()
                .fill(Theme.neonPink.opacity(0.1))
                .frame(width: 260, height: 260)
                .offset(x: -10, y: 220)
        }
        .ignoresSafeArea()
    }
}

// MARK: - State & Data

private final class ClubStore: ObservableObject {
    @Published var selectedTab: ClubTab = .club
    @Published var selectedMode: GameMode?
    @Published var activeTrialMode: GameMode?
    @Published var activeTrialIsPractice = false

    @Published var clubPoints: Int = 10_000
    @Published var streak: Int = 1
    @Published var rank: String = "Guest"
    @Published var sessions: [SessionEntry] = []
    @Published var todaySession: DailySession = DailySession.forToday(modes: GameMode.defaultModes)
    @Published var bestScores: [String: Int] = [:]
    @Published var modeCompletionCounts: [String: Int] = [:]
    @Published var unlockedCharmIDs: Set<String> = ["neon-clover"]
    @Published var ladderProgressDay = 1
    @Published var totalDailyClaims = 0
    @Published var lastDailyClaimDateKey: String?
    @Published var lastFocusBoostClaimDateKey: String?
    @Published var banner: BannerMessage?

    let modes: [GameMode] = GameMode.defaultModes
    let dailyLadder = DailyLadderReward.defaultLadder

    private let storageKey = "midnight_lucky_club_state_v2"
    private let persistenceQueue = DispatchQueue(label: "midnight.club.persistence", qos: .utility)
    private var pendingPersistWorkItem: DispatchWorkItem?

    init() {
        loadState()
        refreshDailySessionIfNeeded()
        updateRank()
        evaluateCharms()
    }

    var charms: [CharmDisplay] {
        CharmDefinition.all.map { def in
            CharmDisplay(
                id: def.id,
                name: def.name,
                unlockRule: def.unlockRule,
                icon: def.icon,
                rarity: def.rarity,
                unlocked: unlockedCharmIDs.contains(def.id)
            )
        }
    }

    var unlockedCharmCount: Int {
        unlockedCharmIDs.count
    }

    var currentLadderNight: Int {
        max(1, min(7, ladderProgressDay))
    }

    var didClaimDailyRewardToday: Bool {
        lastDailyClaimDateKey == DateKey.today
    }

    var didClaimFocusBoostToday: Bool {
        lastFocusBoostClaimDateKey == DateKey.today
    }

    var nextSessionMode: GameMode? {
        todaySession.modeIDs.compactMap { id in
            if todaySession.completedModeIDs.contains(id) { return nil }
            return modes.first(where: { $0.id == id })
        }.first
    }

    var focusStateLabel: String {
        if todaySession.completedModeIDs.count == todaySession.modeIDs.count {
            return "Sharp"
        }
        return "Ready"
    }

    func startTrial(mode: GameMode, isPractice: Bool = false) {
        activeTrialIsPractice = isPractice
        activeTrialMode = mode
    }

    func finishTrial(mode: GameMode, result: TrialResult) {
        defer {
            activeTrialMode = nil
            activeTrialIsPractice = false
        }

        bestScores[mode.id] = max(bestScores[mode.id] ?? 0, result.score)

        if activeTrialIsPractice {
            persist()
            presentBanner("Practice complete. No rewards added.", style: .info)
            return
        }

        clubPoints += mode.reward
        modeCompletionCounts[mode.id, default: 0] += 1

        if todaySession.modeIDs.contains(mode.id) && !todaySession.completedModeIDs.contains(mode.id) {
            todaySession.completedModeIDs.append(mode.id)
            todaySession.trialResults.append(.init(modeID: mode.id, result: result))
            presentBanner("\(mode.name) added to tonight's session.", style: .success)
            Haptics.success()
        } else {
            presentBanner("Reward claimed: +\(mode.reward) Lucky Stars", style: .success)
        }

        if todaySession.completedModeIDs.count == todaySession.modeIDs.count {
            completeDailySession()
        }

        evaluateCharms()
        updateRank()
        persist()
    }

    func claimDailyReward() -> Bool {
        refreshDailySessionIfNeeded()
        guard !didClaimDailyRewardToday else { return false }

        let reward = dailyLadder[currentLadderNight - 1].reward
        clubPoints += reward
        totalDailyClaims += 1
        lastDailyClaimDateKey = DateKey.today
        ladderProgressDay = currentLadderNight == 7 ? 1 : currentLadderNight + 1
        presentBanner("Vault Updated · +\(reward) Lucky Stars", style: .success)
        Haptics.success()
        evaluateCharms()
        persist()
        return true
    }

    func claimFocusBoost() -> Bool {
        refreshDailySessionIfNeeded()
        guard !didClaimFocusBoostToday else { return false }
        let reward = 250
        clubPoints += reward
        lastFocusBoostClaimDateKey = DateKey.today
        presentBanner("Focus Boost claimed · +\(reward)", style: .success)
        Haptics.light()
        evaluateCharms()
        persist()
        return true
    }

    func bestScore(for modeID: String) -> Int {
        bestScores[modeID] ?? 0
    }

    func presentBanner(_ message: String, style: BannerStyle) {
        banner = BannerMessage(message: message, style: style)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            if self.banner?.message == message {
                self.banner = nil
            }
        }
    }

    private func completeDailySession() {
        let totalScore = todaySession.trialResults.reduce(0) { $0 + $1.result.score }
        let reflex = Int(todaySession.trialResults.map { $0.result.reflex }.average)
        let memory = Int(todaySession.trialResults.map { $0.result.memory }.average)
        let focus = Int(todaySession.trialResults.map { $0.result.focus }.average)

        let best = todaySession.trialResults.max(by: { $0.result.score < $1.result.score })?.modeID ?? todaySession.modeIDs.first ?? ""
        let bestName = modes.first(where: { $0.id == best })?.name ?? "Neon Reflex"

        let sessionBonus = 1200
        clubPoints += sessionBonus

        let entry = SessionEntry(
            date: Date(),
            trialsCompleted: todaySession.completedModeIDs.count,
            trialsTotal: todaySession.modeIDs.count,
            bestTrial: bestName,
            reward: sessionBonus,
            reflex: reflex,
            memory: memory,
            focus: focus,
            totalScore: totalScore
        )

        sessions.insert(entry, at: 0)
        if sessions.count > 50 {
            sessions = Array(sessions.prefix(50))
        }

        updateStreakOnSessionCompletion()
        presentBanner("Session Complete · +\(sessionBonus) Lucky Stars", style: .success)
        Haptics.success()

        evaluateCharms()
        updateRank()
        persist()
    }

    private func updateStreakOnSessionCompletion() {
        let today = DateKey.today
        if todaySession.lastCompletionDateKey == today {
            return
        }

        if let last = todaySession.lastCompletionDateKey,
           DateKey.daysBetween(last, today) == 1 {
            streak += 1
        } else if todaySession.lastCompletionDateKey == nil {
            streak = max(streak, 1)
        } else {
            streak = 1
        }

        todaySession.lastCompletionDateKey = today
    }

    private func refreshDailySessionIfNeeded() {
        let today = DateKey.today
        if todaySession.dateKey == today { return }

        todaySession = DailySession.forToday(modes: modes)

        if let claimDate = lastDailyClaimDateKey,
           DateKey.daysBetween(claimDate, today) > 1 {
            ladderProgressDay = 1
        }

        persist()
    }

    private func evaluateCharms() {
        let candidates = CharmDefinition.all.filter { !unlockedCharmIDs.contains($0.id) }
        for charm in candidates {
            if charm.isUnlocked(self) {
                unlockedCharmIDs.insert(charm.id)
                presentBanner("Charm unlocked: \(charm.name)", style: .success)
            }
        }
    }

    private func updateRank() {
        let completedSessions = sessions.count
        switch completedSessions {
        case 0...2:
            rank = "Guest"
        case 3...6:
            rank = "Insider"
        case 7...14:
            rank = "High Roller"
        default:
            rank = "Legend"
        }
    }

    private func loadState() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        guard let decoded = try? JSONDecoder().decode(PersistedClubState.self, from: data) else { return }

        clubPoints = decoded.clubPoints
        streak = decoded.streak
        rank = decoded.rank
        sessions = decoded.sessions
        todaySession = decoded.todaySession
        bestScores = decoded.bestScores
        modeCompletionCounts = decoded.modeCompletionCounts
        unlockedCharmIDs = Set(decoded.unlockedCharmIDs)
        ladderProgressDay = decoded.ladderProgressDay
        totalDailyClaims = decoded.totalDailyClaims
        lastDailyClaimDateKey = decoded.lastDailyClaimDateKey
        lastFocusBoostClaimDateKey = decoded.lastFocusBoostClaimDateKey
    }

    private func persist() {
        pendingPersistWorkItem?.cancel()

        let payload = PersistedClubState(
            clubPoints: clubPoints,
            streak: streak,
            rank: rank,
            sessions: sessions,
            todaySession: todaySession,
            bestScores: bestScores,
            modeCompletionCounts: modeCompletionCounts,
            unlockedCharmIDs: Array(unlockedCharmIDs),
            ladderProgressDay: ladderProgressDay,
            totalDailyClaims: totalDailyClaims,
            lastDailyClaimDateKey: lastDailyClaimDateKey,
            lastFocusBoostClaimDateKey: lastFocusBoostClaimDateKey
        )

        let key = storageKey
        let work = DispatchWorkItem {
            guard let data = try? JSONEncoder().encode(payload) else { return }
            UserDefaults.standard.set(data, forKey: key)
        }
        pendingPersistWorkItem = work
        persistenceQueue.asyncAfter(deadline: .now() + 0.2, execute: work)
    }
}

private enum ClubTab: String, CaseIterable, Identifiable {
    case club
    case sessions
    case charms
    case vault

    var id: String { rawValue }

    var title: String {
        switch self {
        case .club: return "Club"
        case .sessions: return "Sessions"
        case .charms: return "Charms"
        case .vault: return "Vault"
        }
    }

    var icon: String {
        switch self {
        case .club: return "moon.stars.fill"
        case .sessions: return "clock.arrow.circlepath"
        case .charms: return "sparkles"
        case .vault: return "lock.shield.fill"
        }
    }
}

private struct GameMode: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let detail: String
    let tags: [String]
    let reward: Int
    let difficulty: String

    static let defaultModes: [GameMode] = [
        .init(id: "neon-reflex", name: "Neon Reflex", description: "Tap the flash at the perfect moment", detail: "Wait for the real flash, react instantly, and avoid fake pulses.", tags: ["Reflex", "Speed"], reward: 350, difficulty: "Sharp"),
        .init(id: "clover-shift", name: "Clover Shift", description: "Spot the color mismatch", detail: "Find the odd symbol while the rule shifts every round.", tags: ["Focus", "Precision"], reward: 420, difficulty: "Alert"),
        .init(id: "ace-memory", name: "Ace Memory", description: "Repeat the glowing card order", detail: "Watch and reproduce each sequence under pressure.", tags: ["Memory", "Pattern"], reward: 460, difficulty: "Rising"),
        .init(id: "signal-rush", name: "Signal Rush", description: "React only to the true signal", detail: "Tap true cyan-gold signals and ignore every decoy.", tags: ["Timing", "Focus"], reward: 390, difficulty: "Quick"),
        .init(id: "chip-stack", name: "Chip Stack", description: "Arrange the glowing marks", detail: "Stack symbols in exact order before the tempo climbs.", tags: ["Order", "Precision"], reward: 500, difficulty: "Steady"),
        .init(id: "lucky-odd", name: "Lucky Odd", description: "Find the rare mark instantly", detail: "Spot the single outlier in dense neon patterns.", tags: ["Vision", "Speed"], reward: 440, difficulty: "Fast"),
        .init(id: "moonline-timing", name: "Moonline Timing", description: "Stop the light inside the zone", detail: "Freeze the moving light in the gold precision zone.", tags: ["Timing", "Control"], reward: 530, difficulty: "Tight"),
        .init(id: "crown-pulse", name: "Crown Pulse", description: "Follow the rhythm of the club", detail: "Tap in sync with the pulse to keep your flow clean.", tags: ["Rhythm", "Focus"], reward: 470, difficulty: "Flow")
    ]
}

private struct TrialResult: Codable {
    let score: Int
    let accuracy: Int
    let reflex: Int
    let memory: Int
    let focus: Int
}

private struct SessionEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let trialsCompleted: Int
    let trialsTotal: Int
    let bestTrial: String
    let reward: Int
    let reflex: Int
    let memory: Int
    let focus: Int
    let totalScore: Int

    init(date: Date, trialsCompleted: Int, trialsTotal: Int, bestTrial: String, reward: Int, reflex: Int, memory: Int, focus: Int, totalScore: Int) {
        self.id = UUID()
        self.date = date
        self.trialsCompleted = trialsCompleted
        self.trialsTotal = trialsTotal
        self.bestTrial = bestTrial
        self.reward = reward
        self.reflex = reflex
        self.memory = memory
        self.focus = focus
        self.totalScore = totalScore
    }

    var dateText: String {
        Self.dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d · HH:mm"
        return formatter
    }()
}

private struct DailySession: Codable {
    let dateKey: String
    let modeIDs: [String]
    var completedModeIDs: [String]
    var trialResults: [SessionTrialResult]
    var lastCompletionDateKey: String?

    static func forToday(modes: [GameMode]) -> DailySession {
        let today = DateKey.today
        var source = modes.map(\.id)

        var selected: [String] = []
        let count = Int.random(in: 3...5)
        for _ in 0..<count {
            if source.isEmpty { break }
            let idx = Int.random(in: 0..<source.count)
            selected.append(source.remove(at: idx))
        }

        return DailySession(
            dateKey: today,
            modeIDs: selected,
            completedModeIDs: [],
            trialResults: [],
            lastCompletionDateKey: nil
        )
    }
}

private struct SessionTrialResult: Codable {
    let modeID: String
    let result: TrialResult
}

private struct PersistedClubState: Codable {
    let clubPoints: Int
    let streak: Int
    let rank: String
    let sessions: [SessionEntry]
    let todaySession: DailySession
    let bestScores: [String: Int]
    let modeCompletionCounts: [String: Int]
    let unlockedCharmIDs: [String]
    let ladderProgressDay: Int
    let totalDailyClaims: Int
    let lastDailyClaimDateKey: String?
    let lastFocusBoostClaimDateKey: String?

    init(
        clubPoints: Int,
        streak: Int,
        rank: String,
        sessions: [SessionEntry],
        todaySession: DailySession,
        bestScores: [String: Int],
        modeCompletionCounts: [String: Int],
        unlockedCharmIDs: [String],
        ladderProgressDay: Int,
        totalDailyClaims: Int,
        lastDailyClaimDateKey: String?,
        lastFocusBoostClaimDateKey: String?
    ) {
        self.clubPoints = clubPoints
        self.streak = streak
        self.rank = rank
        self.sessions = sessions
        self.todaySession = todaySession
        self.bestScores = bestScores
        self.modeCompletionCounts = modeCompletionCounts
        self.unlockedCharmIDs = unlockedCharmIDs
        self.ladderProgressDay = ladderProgressDay
        self.totalDailyClaims = totalDailyClaims
        self.lastDailyClaimDateKey = lastDailyClaimDateKey
        self.lastFocusBoostClaimDateKey = lastFocusBoostClaimDateKey
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clubPoints = try c.decode(Int.self, forKey: .clubPoints)
        streak = try c.decode(Int.self, forKey: .streak)
        rank = try c.decode(String.self, forKey: .rank)
        sessions = try c.decode([SessionEntry].self, forKey: .sessions)
        todaySession = try c.decode(DailySession.self, forKey: .todaySession)
        bestScores = try c.decode([String: Int].self, forKey: .bestScores)
        modeCompletionCounts = try c.decodeIfPresent([String: Int].self, forKey: .modeCompletionCounts) ?? [:]
        unlockedCharmIDs = try c.decode([String].self, forKey: .unlockedCharmIDs)
        ladderProgressDay = try c.decode(Int.self, forKey: .ladderProgressDay)
        totalDailyClaims = try c.decodeIfPresent(Int.self, forKey: .totalDailyClaims) ?? 0
        lastDailyClaimDateKey = try c.decodeIfPresent(String.self, forKey: .lastDailyClaimDateKey)
        lastFocusBoostClaimDateKey = try c.decodeIfPresent(String.self, forKey: .lastFocusBoostClaimDateKey)
    }
}

private struct DailyLadderReward: Identifiable {
    let id = UUID()
    let night: Int
    let reward: Int

    static let defaultLadder: [DailyLadderReward] = [
        .init(night: 1, reward: 500),
        .init(night: 2, reward: 800),
        .init(night: 3, reward: 1100),
        .init(night: 4, reward: 1500),
        .init(night: 5, reward: 2000),
        .init(night: 6, reward: 2600),
        .init(night: 7, reward: 3500)
    ]
}

private enum CharmRarity: String {
    case classic = "Classic"
    case rare = "Rare"
    case signature = "Signature"
    case mythic = "Mythic"

    var color: Color {
        switch self {
        case .classic: return Theme.secondaryText
        case .rare: return Theme.neonCyan
        case .signature: return Theme.neonPink
        case .mythic: return Theme.champagne
        }
    }
}

private struct CharmDefinition {
    let id: String
    let name: String
    let unlockRule: String
    let icon: String
    let rarity: CharmRarity
    let isUnlocked: (ClubStore) -> Bool

    static let all: [CharmDefinition] = [
        .init(id: "neon-clover", name: "Neon Clover", unlockRule: "Complete Clover Shift", icon: "seal.fill", rarity: .classic, isUnlocked: { _ in true }),
        .init(id: "golden-ace", name: "Golden Ace", unlockRule: "Complete 5 Ace Memory trials", icon: "suit.spade.fill", rarity: .rare, isUnlocked: { store in
            return (store.modeCompletionCounts["ace-memory"] ?? 0) >= 5
        }),
        .init(id: "midnight-crown", name: "Midnight Crown", unlockRule: "Finish 3 Lucky Sessions", icon: "crown.fill", rarity: .signature, isUnlocked: { $0.sessions.count >= 3 }),
        .init(id: "crystal-moon", name: "Crystal Moon", unlockRule: "Reach a 3-night streak", icon: "moon.fill", rarity: .rare, isUnlocked: { $0.streak >= 3 }),
        .init(id: "lucky-spark", name: "Lucky Spark", unlockRule: "Score 700+ in Neon Reflex", icon: "sparkle", rarity: .signature, isUnlocked: { ($0.bestScores["neon-reflex"] ?? 0) >= 700 }),
        .init(id: "velvet-key", name: "Velvet Key", unlockRule: "Unlock 6 charms", icon: "key.fill", rarity: .mythic, isUnlocked: { $0.unlockedCharmIDs.count >= 6 }),
        .init(id: "signal-crest", name: "Signal Crest", unlockRule: "Score 600+ in Signal Rush", icon: "antenna.radiowaves.left.and.right", rarity: .rare, isUnlocked: { ($0.bestScores["signal-rush"] ?? 0) >= 600 }),
        .init(id: "cyan-halo", name: "Cyan Halo", unlockRule: "Claim daily ladder 7 times", icon: "circle.hexagongrid.fill", rarity: .classic, isUnlocked: { $0.totalDailyClaims >= 7 })
    ]
}

private struct CharmDisplay: Identifiable {
    let id: String
    let name: String
    let unlockRule: String
    let icon: String
    let rarity: CharmRarity
    let unlocked: Bool
}

private struct OnboardingPage {
    let title: String
    let subtitle: String
    let icon: String
    let buttonTitle: String
}

private struct CloverOption {
    let symbol: String
    let color: Color
}

private struct SignalOption {
    let title: String
    let gradient: LinearGradient
}

private enum BannerStyle {
    case success
    case warning
    case info

    var color: Color {
        switch self {
        case .success: return Theme.luckyGreen
        case .warning: return Theme.champagne
        case .info: return Theme.neonCyan
        }
    }

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

private struct BannerMessage: Identifiable {
    let id = UUID()
    let message: String
    let style: BannerStyle
}

enum Theme {
    static let bgBlack = Color(hex: "#02030A")
    static let bgNavy = Color(hex: "#070B18")
    static let bgViolet = Color(hex: "#130A2A")

    static let neonViolet = Color(hex: "#7A5CFF")
    static let neonCyan = Color(hex: "#23D7FF")
    static let neonPink = Color(hex: "#FF3FA4")
    static let champagne = Color(hex: "#F6C96D")
    static let luckyGreen = Color(hex: "#35E69B")

    static let secondaryText = Color(hex: "#B8BDCA")
    static let mutedText = Color(hex: "#7A8192")

    static let cardBase = Color.white.opacity(0.085)
    static let tabSelected = Color.white.opacity(0.16)
    static let tabIdle = Color.white.opacity(0.06)
}

private enum DateKey {
    static var today: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    static func daysBetween(_ lhs: String, _ rhs: String) -> Int {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"

        guard let d1 = formatter.date(from: lhs), let d2 = formatter.date(from: rhs) else { return 0 }
        let diff = Calendar.current.dateComponents([.day], from: d1, to: d2).day ?? 0
        return diff
    }
}

private enum Haptics {
    static func success() {
        // Disabled for performance-first mode.
    }

    static func warning() {
        // Disabled for performance-first mode.
    }

    static func light() {
        // Disabled for performance-first mode.
    }
}

private extension Collection where Element == Int {
    var average: Double {
        guard !isEmpty else { return 0 }
        return Double(reduce(0, +)) / Double(count)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r, g, b: Double
        if cleaned.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        } else {
            r = 1
            g = 1
            b = 1
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
