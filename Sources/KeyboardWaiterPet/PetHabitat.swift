import Foundation

/// 栖息地里的一只：已经发现的物种 + 它最近的状态。
public struct PetInhabitant: Equatable {
    public let speciesID: String
    public let discoveredOn: Int64
    /// 最近的活跃度 0…1，决定它在栖息地里的存在感
    public let vitality: Double
    /// 活跃度太低就是在冬眠——最近没在做这件事了
    public var isDormant: Bool { vitality < 0.25 }
}

/// 还没发现的物种，以及最近离解锁有多近。空槽位是收集系统真正的钩子。
public struct PetPending: Equatable {
    public let speciesID: String
    /// 最近几天达到过的最高强度，0…1
    public let bestStrength: Double
    /// 单日条件已经达成，只差「连续天数」这一步。
    /// 不区分的话，夜行种会显示「最接近 100%」却仍未解锁，看着像 bug。
    public let awaitingStreak: Bool
    /// 够接近了，可以透露方向（但不透露条件本身）
    public let revealsDomain: Bool
}

public struct PetHabitatSnapshot: Equatable {
    public let inhabitants: [PetInhabitant]
    public let pending: [PetPending]
    public let undiscoveredCount: Int
    /// 今天新发现的物种，用来做「发现」提示
    public let newlyDiscovered: [String]
    public let totalSpecies: Int

    public var discoveredCount: Int { inhabitants.count }
}

/// 图鉴解锁 + 栖息地活跃度的计算。纯函数，喂什么数据出什么结果。
public struct PetEcology {
    /// 强度达到这个值算解锁
    public var unlockThreshold: Double = 1.0
    /// 接近到这个程度就透露物种属于哪个方面
    public var domainRevealThreshold: Double = 0.85
    /// 活跃度看最近几天
    public var vitalityWindowDays: Int = 7

    public init() {}

    /// 在给定的观测里找出新解锁的物种。
    /// 只看传入的窗口——调用方负责只传「领养之后、还没评估过」的日子。
    public func newDiscoveries(
        in observations: [PetDayObservation],
        alreadyDiscovered: Set<String>
    ) -> [(speciesID: String, dayStart: Int64)] {
        let sorted = observations.sorted { $0.dayStart < $1.dayStart }
        var found: [(String, Int64)] = []

        for species in PetBestiary.all where !alreadyDiscovered.contains(species.id) {
            let window = species.rule.windowDays

            // 从早到晚逐日推进，第一次达标的那天就是发现日
            for index in sorted.indices {
                let slice = Array(sorted[max(0, index - window + 1)...index])
                guard species.rule.strength(forWindow: slice) >= unlockThreshold else { continue }
                found.append((species.id, sorted[index].dayStart))
                break
            }
        }

        return found
    }

    /// 已发现物种最近的活跃度。
    public func vitality(
        for speciesID: String,
        recentObservations: [PetDayObservation]
    ) -> Double {
        guard let species = PetBestiary.species(id: speciesID) else { return 0 }

        let recent = recentObservations
            .sorted { $0.dayStart < $1.dayStart }
            .suffix(vitalityWindowDays)

        guard !recent.isEmpty else { return 0 }

        let strengths = recent.map { species.rule.strength(for: $0) }
        return strengths.reduce(0, +) / Double(strengths.count)
    }

    /// 未发现物种最近离解锁有多近，从高到低。
    public func pending(
        discoveries: Set<String>,
        recentObservations: [PetDayObservation]
    ) -> [PetPending] {
        PetBestiary.all
            .filter { !discoveries.contains($0.id) }
            .map { species in
                let daily = recentObservations.map { species.rule.strength(for: $0) }.max() ?? 0
                let window = species.rule.strength(forWindow: recentObservations)
                let awaitingStreak = species.rule.windowDays > 1 && daily >= 1 && window < 1
                return PetPending(
                    speciesID: species.id,
                    bestStrength: daily,
                    awaitingStreak: awaitingStreak,
                    revealsDomain: daily >= domainRevealThreshold || awaitingStreak
                )
            }
            .sorted { $0.bestStrength > $1.bestStrength }
    }

    public func snapshot(
        discoveries: [String: Int64],
        recentObservations: [PetDayObservation],
        newlyDiscovered: [String]
    ) -> PetHabitatSnapshot {
        let inhabitants = discoveries
            .map { speciesID, day in
                PetInhabitant(
                    speciesID: speciesID,
                    discoveredOn: day,
                    vitality: vitality(for: speciesID, recentObservations: recentObservations)
                )
            }
            .sorted { lhs, rhs in
                if lhs.vitality == rhs.vitality { return lhs.speciesID < rhs.speciesID }
                return lhs.vitality > rhs.vitality
            }

        return PetHabitatSnapshot(
            inhabitants: inhabitants,
            pending: pending(discoveries: Set(discoveries.keys), recentObservations: recentObservations),
            undiscoveredCount: PetBestiary.all.count - inhabitants.count,
            newlyDiscovered: newlyDiscovered,
            totalSpecies: PetBestiary.all.count
        )
    }
}
