//
//  ContentView.swift
//  ConcurrencyApp
//
//  Created by Kyle O Henderson on 23/08/2024.
//

import SwiftUI

enum AppError: Error {
    case error
}
actor DataInteractor {
    var arr = ["D1", "D2", "D3", "D4"]
    
    func fetchData(key: Int) async throws -> String {
        try await Task.sleep(nanoseconds: 5_000_000_000)
        guard arr.count < key else { throw AppError.error }
        return arr[key]
    }
    
    func fetchAll() async throws -> [String] {
//        try await Task.sleep(nanoseconds: 5_000_000_000)
        return arr
    }
    
    func editData(key: Int, val: String) async throws {
//        try await Task.sleep(nanoseconds: 3_000_000_000)
        print("modified \(key)")
        arr[key] = val
    }
    
    func shuffle() {
        arr.shuffle()
    }
    
    func createList(withLength entries: Int) {
        arr = (0...entries).map { "Item: \($0)" }
    }
}

@MainActor
final class ViewModel: ObservableObject {
    let interactor = DataInteractor()
    
    @Published var data: [String] = [] // sendable
    @Published var shouldBeIsolated: Bool = true
    var count: Int = 100
    @Published var tasksEnabled = true
    
    var taskSet = Set<Task<Void, Never>>()
    init() {
        Task {
            await interactor.createList(withLength: count)
        }
        enableTasks()
    }
    
    func enableTasks() {
        let t1 = Task {
            var timesCalled = 0
            while !Task.isCancelled {
                
//                print("Called \(timesCalled)!")
                timesCalled += 1
                do {
                    let d = try await interactor.fetchAll()
                    if shouldBeIsolated {
                        print("Called \(timesCalled)! Isolated")
                        let parsedData = await doSomeProcessingIsolated(strings: d)
                        data = parsedData
                    } else {
                        print("Called \(timesCalled)! NonIsolated")
                        let parsedData = await doSomeProcessing(strings: d)
                        data = parsedData
                    }
                } catch {
                    data = ["No Data"]
                }
//                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        
        let t2 = Task {
            while !Task.isCancelled {
                let k = Int.random(in: 0...count)
                let s = try? await interactor.fetchData(key: k)
                try? await interactor.editData(key: k, val: "Modified \(s)")
//                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        
        let t3 = Task {
            while !Task.isCancelled {
                let k = Int.random(in: 0...count)
                let s = try? await interactor.fetchData(key: k)
                try? await interactor.editData(key: k, val: "Modified 2 \(s)")
//                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        
        let t4 = Task {
            while !Task.isCancelled {
                await interactor.shuffle()
                
//                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        
        taskSet.insert(t1)
        taskSet.insert(t2)
        taskSet.insert(t3)
        taskSet.insert(t4)
        
        tasksEnabled = true
    }
    
    
   nonisolated func doSomeProcessing(strings: [String]) async -> [String] {
        strings.map {
            "Parsed: \($0)"
        }
    }
    
    func doSomeProcessingIsolated(strings: [String]) async -> [String] {
         strings.map {
             "Parsed: \($0)"
         }
     }
    
    func setItemCount(val: Int) {
        Task {
            await interactor.createList(withLength: val)
            count = val
            data = try! await interactor.fetchAll()
        }
    }
    
    func disableTasks() {
        taskSet.forEach {
            $0.cancel()
        }
        taskSet = []
        tasksEnabled = false
    }
    
}
struct ContentView: View {
    @StateObject private var vm = ViewModel()
    
    @State private var val: Int = 100
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(vm.data, id: \.self) { val in
                    ZStack {
                        RoundedRectangle(cornerSize: CGSize(width: 5, height: 5))
                            .fill(.cyan)
                        Text(val)
                    }.frame(maxWidth: .infinity, minHeight: 60)
                }
            }
        }
        HStack {
            VStack {
                Text("Isolate Parsing")
                Toggle("", isOn: $vm.shouldBeIsolated)
            }
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                if vm.tasksEnabled {
                    Button(action: {
                        vm.disableTasks()
                    }, label: {
                        Text("Disable Tasks")
                    })
                } else {
                    Button(action: {
                        vm.enableTasks()
                    }, label: {
                        Text("Enable Tasks")
                    })
                }
            }
            .padding()
            VStack(alignment: .leading) {
                TextField("item Count", value: $val, format: .number)
                Button(action: { vm.setItemCount(val: val)}, label: { Text("Confirm") })
            }
        }
    }
}

#Preview {
    ContentView()
}
