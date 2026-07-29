//
//  DeskResetView.swift
//  Iris
//
//  Quick desk reset checklist: monitor height, shoulders, feet, water.
//  All items start unchecked on every open.
//

import SwiftUI

struct DeskResetItem: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
}

struct DeskResetView: View {

    private let items: [DeskResetItem] = [
        .init(icon: "rectangle.and.arrow.up.right.and.arrow.down.left", label: "Monitor at eye level"),
        .init(icon: "figure.arms.open", label: "Shoulders relaxed"),
        .init(icon: "figure.seated.side", label: "Feet flat on the floor"),
        .init(icon: "drop.fill", label: "Water glass filled"),
    ]

    @State private var checked: Set<UUID> = []
    var onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ForEach(items) { item in
                row(item)
            }
            doneButton
        }
        .frame(width: 260)
        .background(Color(hex: 0x141414))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var header: some View {
        HStack {
            Text("DESK RESET")
                .font(.system(size: 10, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(Color(hex: 0x888888))
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private func row(_ item: DeskResetItem) -> some View {
        Button {
            if checked.contains(item.id) {
                checked.remove(item.id)
            } else {
                checked.insert(item.id)
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(checked.contains(item.id) ? Color.irisAccent : Color.white.opacity(0.08))
                        .frame(width: 20, height: 20)
                    if checked.contains(item.id) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                Image(systemName: item.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.irisSecondary)
                    .frame(width: 18)

                Text(item.label)
                    .font(.system(size: 13))
                    .foregroundStyle(checked.contains(item.id) ? .white.opacity(0.5) : .white.opacity(0.85))

                Spacer()
            }
            .frame(height: 40)
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    private var doneButton: some View {
        Button {
            onDone()
        } label: {
            Text(checked.count == items.count ? "All done ✓" : "Close")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
