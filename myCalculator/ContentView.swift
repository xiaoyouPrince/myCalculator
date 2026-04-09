//
//  ContentView.swift
//  myCalculator
//
//  Created by 渠晓友 on 2026/4/9.
//

import SwiftUI
import AppKit

struct ContentView: View {
    enum CalendarMode: String, CaseIterable, Identifiable {
        case day = "日"
        case week = "周"
        case month = "月"
        case year = "年"

        var id: String { rawValue }
    }

    @State private var selectedMode: CalendarMode = .month
    @State private var selectedDate: Date = .now
    @State private var daySchedules: [Date: WorkSchedule] = [:]

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedDate: $selectedDate,
                daySchedules: $daySchedules,
                onOpenJSONFile: openPersistedJSONFile
            )
            .frame(minWidth: 260)
            .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 340)
        } detail: {
            VStack(spacing: 0) {
                toolbar
                Divider()
                CalendarContentView(mode: $selectedMode, date: $selectedDate, daySchedules: $daySchedules)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.windowBackgroundColor))
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            daySchedules = WorkScheduleStore.load()
        }
    }

    private func openPersistedJSONFile() {
        let fileURL = WorkScheduleStore.persistedFileURL()
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            WorkScheduleStore.save([:])
        }
        NSWorkspace.shared.open(fileURL)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button("今天") {
                selectedDate = .now
            }
            .buttonStyle(.bordered)

            HStack(spacing: 8) {
                Button {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                } label: {
                    Image(systemName: "chevron.left")
                }

                Button {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.bordered)

            Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                .font(.headline)
                .frame(minWidth: 180, alignment: .leading)

            Spacer()

            Picker("视图模式", selection: $selectedMode) {
                ForEach(CalendarMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }
}

#Preview {
    ContentView()
}
